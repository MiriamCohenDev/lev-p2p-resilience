import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// The 16 bytes every plain SQLite file starts with. A SQLCipher file starts
/// with its random salt instead, so this is the cheapest possible tell.
const String _sqliteMagic = 'SQLite format 3\x00';

/// A distinctive string written into a message during verification, so that the
/// encryption can be judged from outside the app: if it turns up in the raw
/// bytes of the database file, the file is not encrypted.
///
/// It is stored as the text of a real message rather than in a scratch table —
/// what needs proving is that *user data* is unreadable, so the check should
/// look at user data in its real shape.
const String storageProbeCanary = 'LEV-PLAINTEXT-CANARY-7f3a';

/// Inspects the raw bytes of every database file in [directory] and returns one
/// complaint per sign that user data reached the disk in the clear. Empty means
/// nothing incriminating was found.
///
/// Lives here rather than in the test so that the automated check and the
/// by-hand check in `tool/probe_encrypted_db.dart` cannot drift apart — there is
/// one definition of what counts as a leak.
///
/// Every file is examined, not just the main one: a `-wal` or `-journal` sibling
/// holding a row in the clear would defeat the point entirely.
List<String> plaintextComplaints(
  Directory directory, {
  String canary = storageProbeCanary,
}) {
  final complaints = <String>[];

  for (final file in directory.listSync().whereType<File>()) {
    final name = p.basename(file.path);
    // latin1 maps every byte to a code unit, so a binary file can be scanned as
    // text without a decoder rejecting or dropping anything.
    final text = latin1.decode(file.readAsBytesSync(), allowInvalid: true);

    if (text.startsWith(_sqliteMagic)) {
      complaints.add('$name begins with the plain SQLite header');
    }
    if (text.contains(canary)) {
      complaints.add('$name contains the written value in plaintext');
    }
  }

  return complaints;
}
