import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3.x keeps `Override` out of the main entry point.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/app.dart';
import 'package:lev/core/db/app_database.dart';
import 'package:lev/core/di/chat_providers.dart';
import 'package:lev/core/di/llm_providers.dart';
import 'package:lev/core/di/prompt_providers.dart';
import 'package:lev/core/l10n/app_localizations.dart';
import 'package:lev/features/chat/data/asset_safety_checker.dart';
import 'package:lev/features/chat/data/drift_chat_repository.dart';
import 'package:lev/features/chat/data/system_prompt.dart';
import 'package:lev/features/chat/data/fake_llm_service.dart';
import 'package:lev/features/chat/domain/chat_repository.dart';
import 'package:lev/features/chat/domain/llm_service.dart';
import 'package:lev/llm/model_descriptor.dart';

/// A whole chat stack with no device under it.
///
/// The database is in-memory and unencrypted: what these tests exercise is the
/// chat, and that the file on disk is encrypted is already proven by
/// `test/core/db/encrypted_database_test.dart` and the on-device tests. The one
/// thing reproduced from the real opener is `PRAGMA foreign_keys`, without which
/// the message → conversation constraint would be documentation.
class ChatHarness {
  ChatHarness({
    FakeEngineMode mode = FakeEngineMode.normal,
    Duration tokenDelay = Duration.zero,
    Duration prefillDelay = Duration.zero,
    List<String>? replies,
    int contextTokens = 4096,
  }) : model = _model(contextTokens) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    database = AppDatabase(
      NativeDatabase.memory(
        setup: (db) => db.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
    repository = DriftChatRepository(database.chatDao);
    engine = FakeLlmService(
      mode: mode,
      tokenDelay: tokenDelay,
      prefillDelay: prefillDelay,
      replies: replies,
    );
  }

  late final AppDatabase database;
  late final ChatRepository repository;
  late final FakeLlmService engine;

  /// The descriptor the chat runs under.
  ///
  /// The context window is a constructor parameter so a test can squeeze the
  /// budget and make the rolling summary (§5.2.3) actually trigger, instead of
  /// having to write a conversation thousands of tokens long to reach it.
  final ModelDescriptor model;

  static ModelDescriptor _model(int contextTokens) => ModelDescriptor(
        id: 'test-model',
        family: 'qwen',
        assetPath: 'assets/models/none.gguf',
        sha256: '',
        language: 'en',
        minRamMb: 0,
        contextTokens: contextTokens,
        replyTokenReserve: contextTokens ~/ 8,
        stopTokens: const ['<|im_end|>'],
        quantization: 'Q4_K_M',
      );

  /// The default descriptor, for tests that only need its id.
  static final ModelDescriptor defaultModel = _model(4096);

  /// A short stand-in for `assets/prompts/system_prompt.md`.
  ///
  /// Fixed and tiny on purpose. The real prompt is a thousand-odd tokens, which
  /// would make every budget assertion here depend on the current wording of a
  /// document that is meant to be edited freely. The real file is parsed and
  /// checked by `test/features/chat/data/system_prompt_test.dart`.
  static const SystemPrompt systemPrompt = SystemPrompt(
    version: 'test-1.0.0',
    text: 'You are LEV. Be calm and honest.',
  );

  /// A stand-in pattern list, matching one unmistakable phrase.
  static const String safetyPatterns = '''
{
  "locale": "en",
  "supportMessage": "Please reach out to someone who can be with you.",
  "patterns": [{"id": "test-distress", "pattern": "\\\\bwant to die\\\\b"}]
}
''';

  /// Replaces every binding the chat resolves, so nothing reaches a platform
  /// channel or a real file.
  ///
  /// The prompt assets are substituted rather than loaded, and not only for
  /// determinism: `rootBundle` caches the `Future` it returns, and a cached
  /// asset future does not resolve again in a later test's `fake_async` zone —
  /// so the first test in a file would load it and every test after would hang
  /// waiting on it. `test/llm/model_registry_test.dart` reads the real manifest
  /// once, which is where asset loading belongs.
  List<Override> get overrides => [
        chatRepositoryProvider.overrideWith((ref) async => repository),
        llmServiceProvider.overrideWith((ref) async {
          await engine.loadModel(model);
          return engine as LlmService;
        }),
        activeModelProvider.overrideWith((ref) async => model),
        systemPromptProvider.overrideWith((ref) async => systemPrompt),
        safetyCheckerProvider.overrideWith(
          (ref) async => AssetSafetyChecker.parse(safetyPatterns),
        ),
      ];

  /// Every conversation on disk, tombstones included, read in one shot.
  ///
  /// Widget tests must not reach for `watchConversations().first`: awaiting it
  /// cancels the subscription underneath, and a stream cancel does not resolve
  /// under `fake_async` (see [unmount]), so the test hangs instead of failing.
  Future<List<ConversationRow>> conversations() =>
      database.select(database.conversations).get();

  Future<void> dispose() => database.close();

  /// Pumps the whole app, router included.
  ///
  /// Needed by anything that navigates: `context.go` asserts on a `GoRouter` in
  /// the tree, so a screen that opens another one cannot be tested under a bare
  /// `MaterialApp`.
  Future<void> pumpApp(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: const LevApp()),
    );
    await tester.pumpAndSettle();
  }

  /// Unmounts the tree and lets Drift's stream cleanup run.
  ///
  /// Cancelling a Drift query stream schedules a zero-duration timer, and the
  /// cancel itself is asynchronous. The test framework unmounts the tree and
  /// pumps *once* before asserting no timers are pending, which is one turn too
  /// early: the cancel has not completed yet, so the timer is created after that
  /// pump and the test fails with "a Timer is still pending". Doing the unmount
  /// here, inside the test body, gives the cleanup somewhere to land.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  /// Pumps [child] with localizations and the harness's overrides in place.
  ///
  /// Pass `settle: false` to assert on a transient state — a prefill or a
  /// half-streamed reply — which by definition is gone once the tree settles.
  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget child, {
    Locale locale = const Locale('en'),
    bool settle = true,
  }) async {
    final scope = ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
    await tester.pumpWidget(scope);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
  }
}

/// `testWidgets` with a [ChatHarness] built for it and torn down after it.
///
/// The teardown is the reason this exists rather than an `addTearDown` in each
/// test: [ChatHarness.unmount] has to run *inside* the test body, and a wrapper
/// is the only way to guarantee that without relying on fifteen call sites to
/// remember it.
void chatWidgetTest(
  String description,
  Future<void> Function(WidgetTester tester, ChatHarness harness) body, {
  FakeEngineMode mode = FakeEngineMode.normal,
  Duration tokenDelay = Duration.zero,
  Duration prefillDelay = Duration.zero,
  List<String>? replies,
  int contextTokens = 4096,
}) {
  testWidgets(description, (tester) async {
    final harness = ChatHarness(
      mode: mode,
      tokenDelay: tokenDelay,
      prefillDelay: prefillDelay,
      replies: replies,
      contextTokens: contextTokens,
    );
    try {
      await body(tester, harness);
    } finally {
      await harness.unmount(tester);
      await harness.dispose();
    }
  });
}
