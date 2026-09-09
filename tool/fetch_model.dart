// Fetches the GGUF weights named in assets/models/models.json.
//
// **A build-time tool, never part of the app.** It lives under `tool/` and is
// run by a developer preparing a working copy or a release build:
//
//     dart run tool/fetch_model.dart            # fetch anything missing
//     dart run tool/fetch_model.dart --verify   # check what is there, fetch nothing
//     dart run tool/fetch_model.dart --pin      # print the sha256 of what is there
//
// §8 makes a network call at runtime a defect, and this file is why that stays
// true while the weights still have to come from somewhere. `sourceUrl` is read
// here and *only* here — `ModelDescriptor` has no such field, so no code under
// `lib/` can reach it even by accident.
//
// The digest is checked before the file is put in place, so a truncated or
// substituted download never becomes the file the app loads (§7.5).
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const String _manifestPath = 'assets/models/models.json';

Future<void> main(List<String> arguments) async {
  final verifyOnly = arguments.contains('--verify');
  final pin = arguments.contains('--pin');

  final manifest = File(_manifestPath);
  if (!manifest.existsSync()) {
    _fail('no manifest at $_manifestPath — run this from the project root');
  }

  final decoded = jsonDecode(await manifest.readAsString());
  if (decoded is! Map<String, Object?> || decoded['models'] is! List) {
    _fail('$_manifestPath has no "models" array');
  }
  final models = (decoded['models']! as List).cast<Map<String, Object?>>();

  var failures = 0;
  for (final model in models) {
    final id = model['id'] as String? ?? '(unnamed)';
    final assetPath = model['assetPath'] as String?;
    final expected = (model['sha256'] as String? ?? '').toLowerCase();
    final sourceUrl = model['sourceUrl'] as String?;

    if (assetPath == null) {
      stderr.writeln('✗ $id: no assetPath');
      failures++;
      continue;
    }

    final file = File(assetPath);

    if (!file.existsSync()) {
      if (verifyOnly || pin) {
        stderr.writeln('✗ $id: not installed at $assetPath');
        failures++;
        continue;
      }
      if (sourceUrl == null) {
        stderr.writeln('✗ $id: not installed, and the manifest gives no '
            'sourceUrl to fetch it from');
        failures++;
        continue;
      }
      stdout.writeln('↓ $id: fetching from $sourceUrl');
      if (!await _download(sourceUrl, file)) {
        failures++;
        continue;
      }
    }

    final actual = (await sha256.bind(file.openRead()).first).toString();
    final megabytes = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(1);

    if (pin) {
      stdout.writeln('$id  $actual  (${megabytes}MB)');
      stdout.writeln('  → paste that into "sha256" for $id in $_manifestPath');
      continue;
    }

    if (expected.isEmpty) {
      // Not a hard failure: this is the state a developer is in between adding
      // a model and pinning it. It is a failure at release time, and
      // `model_file_store_test.dart` is what enforces that.
      stdout.writeln('⚠ $id: installed (${megabytes}MB) but the manifest pins '
          'no sha256, so §7.5\'s integrity check is disabled for it.');
      stdout.writeln('  → run with --pin and paste the digest into the manifest');
      continue;
    }

    if (actual != expected) {
      stderr.writeln('✗ $id: digest mismatch at $assetPath');
      stderr.writeln('    expected $expected');
      stderr.writeln('    found    $actual');
      failures++;
      continue;
    }

    stdout.writeln('✓ $id: verified (${megabytes}MB)');
  }

  if (failures > 0) exit(1);
}

/// Downloads [url] to [destination], via a `.part` file.
///
/// The rename is the commit: an interrupted download leaves a `.part` behind
/// rather than a truncated file that looks installed. That matters because the
/// app treats a file at the real path as complete — see `InstalledModelFileStore`.
Future<bool> _download(String url, File destination) async {
  await destination.parent.create(recursive: true);
  final part = File('${destination.path}.part');

  final client = HttpClient();
  try {
    var uri = Uri.parse(url);
    HttpClientResponse response;
    // Model hosts redirect to a CDN, sometimes more than once. Followed by hand
    // so a redirect that lands on an error page is reported as such rather than
    // silently written to disk as if it were weights.
    for (var hop = 0;; hop++) {
      if (hop > 5) {
        stderr.writeln('✗ too many redirects fetching $url');
        return false;
      }
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      response = await request.close();
      if (response.isRedirect) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>();
        if (location == null) {
          stderr.writeln('✗ redirect with no Location fetching $url');
          return false;
        }
        uri = uri.resolve(location);
        continue;
      }
      break;
    }

    if (response.statusCode != HttpStatus.ok) {
      stderr.writeln('✗ HTTP ${response.statusCode} fetching $uri');
      await response.drain<void>();
      return false;
    }

    final sink = part.openWrite();
    var received = 0;
    final total = response.contentLength;
    await response.forEach((chunk) {
      received += chunk.length;
      sink.add(chunk);
      if (total > 0 && received % (16 * 1024 * 1024) < chunk.length) {
        stdout.write('\r  ${(received * 100 / total).toStringAsFixed(0)}%');
      }
    });
    await sink.flush();
    await sink.close();
    stdout.writeln('\r  done');

    await part.rename(destination.path);
    return true;
  } on Object catch (error) {
    stderr.writeln('✗ $error');
    if (part.existsSync()) await part.delete();
    return false;
  } finally {
    client.close();
  }
}

Never _fail(String message) {
  stderr.writeln('fetch_model: $message');
  exit(1);
}
