import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/features/chat/domain/llm_errors.dart';
import 'package:lev/llm/model_descriptor.dart';
import 'package:lev/llm/model_file_store.dart';
import 'package:lev/llm/model_registry.dart';
import 'package:path/path.dart' as p;

/// Stands in for a GGUF. The store never parses the file, only moves and hashes
/// it, so a few bytes exercise exactly the same paths as a few hundred megabytes.
final Uint8List _weights = Uint8List.fromList(utf8.encode('GGUF pretend weights'));
final String _weightsDigest = sha256.convert(_weights).toString();

ModelDescriptor _descriptor({String sha256 = ''}) => ModelDescriptor(
      id: 'qwen-en-q4',
      family: 'qwen',
      assetPath: 'assets/models/qwen-en-q4.gguf',
      sha256: sha256,
      language: 'en',
      minRamMb: 1536,
      contextTokens: 4096,
      replyTokenReserve: 512,
      stopTokens: const ['<|im_end|>'],
      quantization: 'Q4_K_M',
    );

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('lev_models_test');
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  InstalledModelFileStore storeWith({
    Future<ByteData> Function(String key)? loadAsset,
  }) =>
      InstalledModelFileStore(
        directory: directory,
        loadAsset: loadAsset ??
            (_) async => ByteData.sublistView(_weights),
      );

  test('extracts the bundled asset onto disk and returns its path', () async {
    final path = await storeWith().pathFor(_descriptor(sha256: _weightsDigest));

    expect(p.basename(path), 'qwen-en-q4.gguf');
    expect(File(path).readAsBytesSync(), _weights);
  });

  test('reuses an already-installed file instead of extracting again', () async {
    final target = File(p.join(directory.path, 'qwen-en-q4.gguf'))
      ..writeAsBytesSync(_weights);

    var assetReads = 0;
    final path = await storeWith(
      loadAsset: (_) async {
        assetReads++;
        return ByteData.sublistView(_weights);
      },
    ).pathFor(_descriptor(sha256: _weightsDigest));

    expect(path, target.path);
    // The point of installing once. On a phone this is the difference between
    // paying a several-hundred-megabyte copy on first launch and on every launch.
    expect(assetReads, 0);
  });

  test('picks up a sideloaded file nobody bundled', () async {
    // The distribution story for a model too large to ship inside the installer:
    // a person drops the GGUF into the directory and it is used, having passed
    // exactly the same integrity check as one we shipped.
    File(p.join(directory.path, 'qwen-en-q4.gguf')).writeAsBytesSync(_weights);

    final path = await storeWith(
      loadAsset: (_) async => throw StateError('not bundled in this build'),
    ).pathFor(_descriptor(sha256: _weightsDigest));

    expect(File(path).existsSync(), isTrue);
  });

  test('refuses weights that do not match the pinned digest (§7.5)', () async {
    File(p.join(directory.path, 'qwen-en-q4.gguf'))
        .writeAsBytesSync(utf8.encode('a different model entirely'));

    await expectLater(
      storeWith().pathFor(_descriptor(sha256: _weightsDigest)),
      throwsA(isA<ModelIntegrityFailed>()),
    );
  });

  test('reports missing weights as unavailable, not as corrupt', () async {
    // The two are opposite states and the caller treats them differently: one is
    // an installation step that has not happened, the other is a file that must
    // not be trusted.
    await expectLater(
      storeWith(
        loadAsset: (_) async => throw StateError('no such asset'),
      ).pathFor(_descriptor(sha256: _weightsDigest)),
      throwsA(
        isA<ModelUnavailable>().having(
          (e) => e.message,
          'message',
          allOf(contains('qwen-en-q4.gguf'), contains('fetch_model')),
        ),
      ),
    );
  });

  test('leaves no file behind when extraction produces the wrong bytes',
      () async {
    // A truncated extraction that landed at the real path would fail its digest
    // on every subsequent launch with nothing able to repair it. The `.part`
    // rename is what makes a file at the real path always a complete one.
    final store = storeWith(
      loadAsset: (_) async =>
          ByteData.sublistView(Uint8List.fromList(utf8.encode('truncat'))),
    );

    await expectLater(
      store.pathFor(_descriptor(sha256: _weightsDigest)),
      throwsA(isA<ModelIntegrityFailed>()),
    );
    expect(File('${p.join(directory.path, 'qwen-en-q4.gguf')}.part').existsSync(),
        isFalse);
  });

  test('an unpinned digest skips the check — and never reaches a release',
      () async {
    // Deliberate hole: a developer evaluating a model has no digest yet. The
    // guard is that `assertPinned` fails, and the shipped manifest is checked
    // against it below.
    final path = await storeWith().pathFor(_descriptor());
    expect(File(path).existsSync(), isTrue);

    expect(
      () => assertPinned([_descriptor()]),
      throwsA(isA<StateError>()),
    );
    expect(() => assertPinned([_descriptor(sha256: _weightsDigest)]),
        returnsNormally);
  });

  test('the shipped manifest pins a digest for every model', () async {
    // §7.5's integrity check is only a control if the manifest actually pins
    // something to check against. This is the test that turns "we should pin the
    // digest" into a release gate.
    //
    // Skipped while no weights are installed, because the digest cannot be
    // computed for a file nobody has fetched — see technical-decisions #19.
    final manifest = File('assets/models/models.json');
    final registry = ModelRegistry.parse(await manifest.readAsString());

    final weightsPresent = registry.models
        .every((m) => File(m.assetPath).existsSync());
    if (!weightsPresent) {
      markTestSkipped(
        'no GGUF installed — run `dart run tool/fetch_model.dart` first',
      );
      return;
    }

    expect(() => assertPinned(registry.models), returnsNormally);
  });
}
