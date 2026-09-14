// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lev/core/di/chat_providers.dart';
import 'package:lev/core/di/db_providers.dart';
import 'package:lev/core/di/llm_providers.dart';
import 'package:lev/core/di/prompt_providers.dart';
import 'package:lev/features/chat/domain/llm_errors.dart';
import 'package:lev/features/chat/domain/message_role.dart';
import 'package:lev/features/chat/presentation/chat_notifier.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'chat_eval_cases.dart';

/// **The chat evaluation: the 20 fixed messages, sent the way a user sends them.**
///
/// For comparing system-prompt versions and models on the replies they actually
/// produce. Each message goes through the real chain, nothing substituted:
/// a new conversation, exactly as `startConversation` creates it → the real
/// `ChatNotifier`, as the chat screen holds it → `send`, which is what the
/// composer's send button calls → the safety layer, the system prompt asset,
/// the prompt builder and llama.cpp with the installed weights. The reply
/// recorded is the one stored in the conversation, which is the text the user
/// is left looking at.
///
/// Each message opens its **own** conversation, like a user starting a new chat
/// for it, so no reply is coloured by an earlier case.
///
/// The one thing overridden is *where* the database lives: a temporary
/// directory, deleted afterwards, so twenty evaluation conversations never land
/// in the real history. It is still encrypted through the real key manager.
///
/// Run with:
///
///     flutter test integration_test/chat_eval_test.dart -d windows
///
/// Output: `build/chat_eval/<model>__<prompt-version>__<timestamp>.json`,
/// rewritten after every case so a run stopped midway still leaves a usable
/// file. Each reply is also printed as it arrives, and the whole file is printed
/// at the end. To keep results somewhere `flutter clean` cannot reach, add
/// `--dart-define=CHAT_EVAL_OUT_DIR=<absolute directory>`.
///
/// The prompt version and the model are read from what was actually loaded —
/// the front matter of `assets/prompts/system_prompt.md` and the model the
/// registry selected — not typed in by hand, so a result cannot be mislabelled.
///
/// Skips, like `llm_generation_test.dart`, when no weights are installed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory databaseDirectory;
  late ProviderContainer container;
  ModelUnavailable? noWeights;

  late File outputFile;
  final results = <Map<String, Object?>>[];
  final failedIds = <int>[];

  setUpAll(() async {
    databaseDirectory = await Directory.systemTemp.createTemp('lev_chat_eval_');
    container = ProviderContainer(
      overrides: [
        appDatabaseFileProvider.overrideWith(
          (ref) async => File(p.join(databaseDirectory.path, 'lev.db')),
        ),
      ],
      // A model that fails to load should fail the run now, not be retried
      // quietly in the background while every case waits on it.
      retry: (_, _) => null,
    );

    try {
      await container.read(llmServiceProvider.future);
    } on ModelUnavailable catch (error) {
      noWeights = error;
      return;
    }

    final model = await container.read(activeModelProvider.future);
    final prompt = await container.read(systemPromptProvider.future);
    final stamp = _timestamp(DateTime.now());
    outputFile = File(p.join(
      (await _outputDirectory()).path,
      '${_forFilename(model.id)}__${_forFilename(prompt.version)}__$stamp.json',
    ));
    outputFile.parent.createSync(recursive: true);

    print('chat eval · model ${model.id} · system prompt ${prompt.version}');
    print('writing to ${outputFile.path}');
  });

  tearDownAll(() async {
    // Closes the database and releases the model.
    container.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    try {
      databaseDirectory.deleteSync(recursive: true);
    } on FileSystemException {
      // A handle still closing on Windows. It is in the temp directory, and
      // encrypted; not worth failing a finished run over.
    }

    if (results.isEmpty) return;
    final succeeded = results.length - failedIds.length;
    print('\n===== chat eval results =====');
    print(_encoder.convert(results));
    print('===== end of results =====');
    print('Finished: $succeeded succeeded, ${failedIds.length} failed'
        '${failedIds.isEmpty ? '' : ' (ids ${failedIds.join(', ')})'}. '
        'Output: ${outputFile.path}');
  });

  final runDate = _date(DateTime.now());

  for (final testCase in chatEvalCases) {
    testWidgets('case ${testCase.id} · ${testCase.category}', (_) async {
      if (noWeights != null) {
        markTestSkipped('no GGUF installed — $noWeights');
        return;
      }

      final model = await container.read(activeModelProvider.future);
      final prompt = await container.read(systemPromptProvider.future);
      final label = '[${testCase.id}/${chatEvalCases.length}] '
          'id=${testCase.id} (${testCase.category})';
      final stopwatch = Stopwatch()..start();

      _Turn turn;
      try {
        turn = await _sendAsTheUserDoes(container, testCase.message);
      } on Object catch (error) {
        turn = _Turn(reply: '', safetyCardShown: false, failure: error);
      }
      stopwatch.stop();

      final failure = turn.failure ??
          (turn.reply.isEmpty ? 'the chat stored no reply' : null);
      if (failure != null) failedIds.add(testCase.id);

      results.add({
        'date': runDate,
        'system_prompt_version': prompt.version,
        'model': model.id,
        'test_case_id': testCase.id,
        'category': testCase.category,
        'output_text': failure == null ? turn.reply : '[EVAL ERROR] $failure',
        'safety_card_shown': turn.safetyCardShown,
      });
      outputFile.writeAsStringSync(_encoder.convert(results), flush: true);

      final seconds = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1);
      if (failure == null) {
        print('$label -> done (${seconds}s)'
            '${turn.safetyCardShown ? ' · safety card shown' : ''}\n'
            '${turn.reply}\n');
      } else {
        print('$label -> FAILED: $failure\n');
      }

      expect(failure, isNull, reason: 'case ${testCase.id}');
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}

/// What one message produced, as the user would be left seeing it.
class _Turn {
  const _Turn({
    required this.reply,
    required this.safetyCardShown,
    this.failure,
  });

  final String reply;
  final bool safetyCardShown;
  final Object? failure;
}

/// Sends [text] down the same path the chat screen does, in a new conversation.
Future<_Turn> _sendAsTheUserDoes(
  ProviderContainer container,
  String text,
) async {
  // What `startConversation` does when a new chat is opened.
  final repository = await container.read(chatRepositoryProvider.future);
  final model = await container.read(activeModelProvider.future);
  final conversation = await repository.createConversation(modelId: model.id);

  // The open chat screen watching the conversation. The notifier is
  // autoDispose, so without a listener it — and its session — would be
  // released before the reply arrived.
  final provider = chatNotifierProvider(conversation.id);
  final screen = container.listen(provider, (_, _) {});
  try {
    await container.read(provider.future);

    // The composer trims and hands the text to `notifier.send`.
    await container.read(provider.notifier).send(text.trim());

    // `send` returns as the stream ends, one step before the reply is stored
    // and the screen returns to rest. Wait for rest, as the user would.
    while (container.read(provider).value?.isTyping ?? false) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    final state = container.read(provider).requireValue;
    final replies = (await repository.messagesOf(conversation.id))
        .where((message) => message.role == MessageRole.assistant);

    return _Turn(
      reply: replies.isEmpty ? '' : replies.last.text,
      safetyCardShown: state.safetyNotice != null,
      failure: state.failure,
    );
  } finally {
    // Leaving the conversation, which disposes its session.
    screen.close();
  }
}

const _encoder = JsonEncoder.withIndent('  ');

const String _outputDirectoryDefine = String.fromEnvironment(
  'CHAT_EVAL_OUT_DIR',
);

/// `build/chat_eval/` in the project, when the app runs from inside it.
///
/// On desktop the test launches the app out of `build/<platform>/…`, so walking
/// up from the executable reaches the project. A phone has no project
/// directory; the file stays on the device and the printed results are the
/// copy that reaches the console.
Future<Directory> _outputDirectory() async {
  if (_outputDirectoryDefine.isNotEmpty) {
    return Directory(_outputDirectoryDefine);
  }

  var directory = File(Platform.resolvedExecutable).parent;
  while (true) {
    if (File(p.join(directory.path, 'pubspec.yaml')).existsSync()) {
      return Directory(p.join(directory.path, 'build', 'chat_eval'));
    }
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }

  final documents = await getApplicationDocumentsDirectory();
  return Directory(p.join(documents.path, 'chat_eval'));
}

String _forFilename(String label) {
  final safe = label.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return safe.isEmpty ? 'unnamed' : safe;
}

String _two(int n) => n.toString().padLeft(2, '0');

String _date(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)}';

String _timestamp(DateTime t) =>
    '${t.year}${_two(t.month)}${_two(t.day)}-'
    '${_two(t.hour)}${_two(t.minute)}${_two(t.second)}';
