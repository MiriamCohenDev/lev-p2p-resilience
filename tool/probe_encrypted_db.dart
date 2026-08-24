// Writes one SQLCipher-encrypted probe database and inspects its raw bytes, so
// that "the file really is encrypted" can be checked by hand rather than taken
// on faith from a green test.
//
//   dart run tool/probe_encrypted_db.dart [output-directory]
//
// It goes through the app's real opener (`encryptedExecutor`), so what lands on
// disk is byte-for-byte the kind of file the app writes. The one thing it does
// differently: the DEK is minted here with `DartSecureRandom` instead of being
// unwrapped by `KeyManager`, because reading the OS secure store needs a running
// Flutter app. That substitution is upstream of everything checked below — the
// encryption sees 32 random bytes either way.
//
// See docs/technical-decisions.md #13.
import 'dart:io';

import 'package:lev/core/crypto/key_material.dart';
import 'package:lev/core/db/app_database.dart';
import 'package:lev/core/db/encrypted_database_opener.dart';
import 'package:lev/core/db/plaintext_audit.dart';
import 'package:lev/features/chat/data/drift_chat_repository.dart';
import 'package:lev/features/chat/domain/message.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final directory = Directory(args.isEmpty ? p.join('build', 'probe') : args[0])
    ..createSync(recursive: true);
  final file = File(p.join(directory.path, 'lev.db'));
  if (file.existsSync()) file.deleteSync();

  final database = AppDatabase(
    encryptedExecutor(
      file: file,
      dek: DartSecureRandom().nextBytes(keyLengthBytes),
    ),
  );

  // A real conversation and a real message, through the repository — so the
  // bytes examined below are user data in the shape the app actually stores it.
  final repository = DriftChatRepository(database.chatDao);
  final conversation = await repository.createConversation(title: 'probe');
  await repository.append(
    Message.fromUserInput(
      conversationId: conversation.id,
      text: 'sensitive $storageProbeCanary payload',
    ),
  );
  await database.close();

  stdout.writeln('wrote ${file.absolute.path}');
  stdout.writeln('  (the key is not printed, and never is)');
  stdout.writeln('');

  // The same detector the test suite uses, so the two cannot drift apart.
  final complaints = plaintextComplaints(directory);
  for (final complaint in complaints) {
    stdout.writeln('  FAIL  $complaint');
  }

  if (complaints.isEmpty) {
    stdout.writeln('  PASS  no plain SQLite header in any file written');
    stdout.writeln('  PASS  the written value appears nowhere in the raw bytes');
    stdout.writeln('');
    stdout.writeln('encrypted.');
  } else {
    stdout.writeln('');
    stdout.writeln('NOT ENCRYPTED — check hooks.user_defines.sqlite3.source '
        'in pubspec.yaml');
  }

  stdout.writeln('');
  stdout.writeln('Still to do by hand, because this script cannot prove a '
      'negative about itself:');
  stdout.writeln('  python -c "import sqlite3,sys; '
      "sqlite3.connect(sys.argv[1]).execute('select count(*) from sqlite_master')\" "
      '${file.absolute.path}');
  stdout.writeln('    => expect: sqlite3.DatabaseError: file is not a database');

  exitCode = complaints.isEmpty ? 0 : 1;
}
