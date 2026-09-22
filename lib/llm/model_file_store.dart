import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:path/path.dart' as p;

import '../features/chat/domain/llm_errors.dart';
import 'model_descriptor.dart';

/// Turns a [ModelDescriptor] into a real file on disk that llama.cpp can open.
///
/// **Why this exists at all.** Phase 2 never read `assetPath`; Phase 3 must.
/// llama.cpp opens (and prefers to `mmap`) a filesystem path, and a Flutter
/// asset is not a file — on Android it is a compressed entry inside the APK.
/// Something therefore has to put the weights somewhere the native library can
/// reach, verify them (§7.5), and do it once rather than on every launch.
///
/// Injectable rather than static so the whole path can be exercised in a host
/// test with a few bytes standing in for a few hundred megabytes.
abstract class ModelFileStore {
  /// The verified on-disk path for [model].
  ///
  /// Throws [ModelUnavailable] if the weights are neither installed nor
  /// bundled, and [ModelIntegrityFailed] if what is on disk is not what the
  /// manifest says it should be.
  Future<String> pathFor(ModelDescriptor model);
}

/// Resolves weights from the app's own directory, falling back to the bundle.
///
/// The order is deliberate and is what makes both distribution stories work
/// from one code path:
///
/// 1. **Already installed** — the common case after first launch, and also the
///    sideload case: a user who cannot afford a 2 GB download inside the
///    installer drops the GGUF into this directory and it is picked up.
/// 2. **Bundled as an asset** — extracted once, then case 1 forever after.
///
/// §7.5 requires the file to be integrity-checked before load, and that check
/// is what makes the two cases safe to treat alike: a sideloaded file gets
/// exactly the same scrutiny as one we shipped.
class InstalledModelFileStore implements ModelFileStore {
  InstalledModelFileStore({
    required this.directory,
    Future<ByteData> Function(String key)? loadAsset,
  }) : _loadAsset = loadAsset ?? rootBundle.load;

  /// Where installed weights live. Created on demand.
  final Directory directory;

  final Future<ByteData> Function(String key) _loadAsset;

  @override
  Future<String> pathFor(ModelDescriptor model) async {
    final target = File(p.join(directory.path, p.basename(model.assetPath)));

    if (await target.exists()) {
      await _verify(target, model);
      return target.path;
    }

    await _extractFromBundle(target, model);
    await _verify(target, model);
    return target.path;
  }

  /// Copies the bundled asset onto disk, atomically.
  ///
  /// Written to a `.part` file and renamed only once the bytes are all there.
  /// A rename is atomic on every platform LEV targets, so a file that exists at
  /// the real path is always a complete one — which is what lets [pathFor] trust
  /// an existing file instead of having to distinguish "installed" from
  /// "interrupted half-way through installing". Without it, a crash during the
  /// first extraction would leave a truncated file that fails its digest on
  /// every subsequent launch, with nothing able to repair it.
  Future<void> _extractFromBundle(File target, ModelDescriptor model) async {
    final ByteData bytes;
    try {
      bytes = await _loadAsset(model.assetPath);
    } on Object catch (error) {
      throw ModelUnavailable(
        'model "${model.id}" has no weights. Expected them at ${target.path}, '
        'or bundled at ${model.assetPath}. Run '
        '`dart run tool/fetch_model.dart` to fetch and verify them, or copy an '
        'existing ${p.basename(model.assetPath)} into ${directory.path}.',
        cause: error,
      );
    }

    await directory.create(recursive: true);
    final part = File('${target.path}.part');
    await part.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
    await part.rename(target.path);
  }

  /// §7.5's integrity check — hashed once per installed file, not once per
  /// launch, and never on the main isolate (technical-decisions #36).
  ///
  /// Streamed rather than read whole: hashing by loading the file into memory
  /// would cost as much RAM as the model itself, on the one device class §8
  /// says is already tight. `sha256.bind` consumes the stream in blocks and
  /// holds only its own state.
  ///
  /// An empty `sha256` in the manifest skips the check — that is how a
  /// developer points the manifest at a model they are evaluating without
  /// having to compute a digest first. It is a deliberate hole, and
  /// [assertPinned] is what stops it reaching a release.
  Future<void> _verify(File target, ModelDescriptor model) async {
    if (model.sha256.isEmpty) return;

    final expected = model.sha256.toLowerCase();
    final stat = await target.stat();
    final receipt = _receiptFor(target);
    if (await _receiptStillHolds(receipt, expected, stat)) return;

    final actual = await _hashOffThread(target.path);
    if (actual != expected) {
      // A receipt that outlived the file it vouched for would let the next
      // launch trust these bytes. Whatever else is true, this file is not the
      // one the manifest describes, so nothing may vouch for it.
      if (await receipt.exists()) await receipt.delete();
      throw ModelIntegrityFailed(
        'the weights at ${target.path} do not match the digest the manifest '
        'pins for model "${model.id}": expected ${model.sha256}, found $actual. '
        'The file is corrupt or is not the model it claims to be. Delete it and '
        'reinstall rather than loading it.',
      );
    }
    await _writeReceipt(receipt, expected, stat);
  }

  /// Where the proof that [target] was hashed once already is kept.
  File _receiptFor(File target) => File('${target.path}.verified');

  /// Whether the recorded proof still describes the file on disk.
  ///
  /// Size and modification time together are what make the receipt refer to
  /// *these* bytes rather than to the path. Replace the GGUF — the sideload
  /// case §7.5 exists for — and both move, so the hash runs again. The digest
  /// is stored too, so changing the pin in the manifest re-verifies rather
  /// than silently accepting a file that was checked against the old one.
  ///
  /// Any failure to read it answers "no". Re-hashing costs seconds; trusting a
  /// receipt we could not parse costs the check itself.
  Future<bool> _receiptStillHolds(
    File receipt,
    String expected,
    FileStat stat,
  ) async {
    if (!await receipt.exists()) return false;
    try {
      final record = jsonDecode(await receipt.readAsString());
      if (record is! Map<String, dynamic>) return false;
      return record['sha256'] == expected &&
          record['sizeBytes'] == stat.size &&
          record['modifiedAtMicros'] == stat.modified.microsecondsSinceEpoch;
    } on Object {
      return false;
    }
  }

  Future<void> _writeReceipt(
    File receipt,
    String expected,
    FileStat stat,
  ) async {
    // A half-written receipt does not parse, and an unparseable receipt is
    // simply re-earned by hashing — so there is nothing here to make atomic.
    await receipt.writeAsString(
      jsonEncode({
        'sha256': expected,
        'sizeBytes': stat.size,
        'modifiedAtMicros': stat.modified.microsecondsSinceEpoch,
      }),
      flush: true,
    );
  }
}

/// Hashes [path] on an isolate of its own.
///
/// `sha256.bind` yields between blocks, so on paper it shares the thread
/// politely — but it is still several hundred megabytes of work on whichever
/// isolate calls it, and since #35 that call happens while the application is
/// starting. On Android that was measurable and then some: dropped frames
/// through the whole of startup, and on a 2 GB emulator an ANR that took the
/// system UI down with it. Off the main isolate, the cost is real but nothing
/// waits on it except the model.
Future<String> _hashOffThread(String path) => Isolate.run(() async {
      final digest = await sha256.bind(File(path).openRead()).first;
      return digest.toString();
    });

/// Fails unless every model in [models] pins a digest.
///
/// Called from a test, not from the app. The skip-on-empty rule in [_verify] is
/// a development convenience, and a development convenience that can ship is
/// just a missing security control — §7.5 asks for the check precisely so a
/// tampered GGUF is caught, and an unpinned entry silently disables it.
void assertPinned(Iterable<ModelDescriptor> models) {
  final unpinned = models.where((m) => m.sha256.isEmpty).map((m) => m.id);
  if (unpinned.isNotEmpty) {
    throw StateError(
      'these models pin no sha256 in assets/models/models.json, so §7.5\'s '
      'integrity check would be skipped for them: ${unpinned.join(', ')}',
    );
  }
}
