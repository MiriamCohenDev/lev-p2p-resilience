// Developer tool: reveals this device's DEK so `lev.db` can be opened in
// DB Browser for SQLCipher.
//
//   flutter run -t tool/show_db_key.dart -d windows
//   flutter run -t tool/show_db_key.dart -d emulator-5554
//
// It unwraps the real DEK through the real `KeyManager`, which is why it has to
// be a Flutter app rather than a `dart run` script: reading the OS secure store
// needs platform channels.
//
// **This deliberately breaks the rule the rest of the codebase keeps.** Every
// other path treats the DEK as something that never leaves the process —
// `logStatements` is forced off in `encrypted_database_opener.dart` precisely so
// the key cannot reach a log. Revealing it is the price of using an external
// viewer, and it is why the key goes to the screen by default and only reaches
// the console if asked for explicitly:
//
//   flutter run -t tool/show_db_key.dart -d windows --dart-define=LEV_PRINT_KEY=true
//
// Anything holding this key can read every conversation on the device. Nothing
// under tool/ is reachable from `lib/main.dart`, so this never ships in a build.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lev/core/crypto/key_material.dart';
import 'package:lev/core/di/crypto_providers.dart';
import 'package:lev/core/di/db_providers.dart';

/// Whether the full key may also go to stdout. Off unless asked for.
const bool _printKey = bool.fromEnvironment('LEV_PRINT_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: _KeyApp()));
}

class _KeyApp extends StatelessWidget {
  const _KeyApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'LEV database key',
        theme: ThemeData.dark(),
        home: const _KeyScreen(),
      );
}

class _KeyScreen extends ConsumerStatefulWidget {
  const _KeyScreen();

  @override
  ConsumerState<_KeyScreen> createState() => _KeyScreenState();
}

class _KeyScreenState extends ConsumerState<_KeyScreen> {
  String? _path;
  String? _key;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = await ref.read(appDatabaseFileProvider.future);
      final dek = await ref.read(keyManagerProvider).obtainDek();
      // toSqlCipherKey yields `x'<hex>'`; DB Browser wants the same bytes with a
      // `0x` prefix instead, then rebuilds the `x'…'` form itself.
      final sqlCipherKey = toSqlCipherKey(dek);
      wipe(dek);
      final hex = sqlCipherKey.substring(2, sqlCipherKey.length - 1);

      if (!mounted) return;
      setState(() {
        _path = file.path;
        _key = '0x$hex';
      });

      debugPrint('database: ${file.path}');
      debugPrint(
        _printKey
            ? 'raw key : 0x$hex'
            : 'raw key : 0x${hex.substring(0, 6)}… '
                '(shown in full in the window; pass '
                '--dart-define=LEV_PRINT_KEY=true to print it here)',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
      debugPrint('could not obtain the DEK: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final key = _key;

    return Scaffold(
      appBar: AppBar(title: const Text('LEV database key')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: switch ((error, key)) {
          (final Object e, _) => SelectableText('Could not obtain the DEK.\n\n$e'),
          (_, null) => const Center(child: CircularProgressIndicator()),
          (_, final String k) => ListView(
              children: [
                const Text(
                  'Anything holding this key can read every conversation on '
                  'this device. Close this window when you are done.',
                ),
                const SizedBox(height: 24),
                const Text('Database file'),
                SelectableText(_path!),
                const SizedBox(height: 24),
                const Text('Raw key — paste into DB Browser for SQLCipher'),
                SelectableText(
                  k,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: k));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Key copied')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy key'),
                ),
                const SizedBox(height: 32),
                const Text(
                  'In the encryption dialog choose "Raw key" and SQLCipher 4 '
                  'defaults:\n'
                  '  page size      4096\n'
                  '  KDF iterations 256000\n'
                  '  HMAC algorithm SHA512\n'
                  '  KDF algorithm  SHA512\n\n'
                  'Open a copy of the file, not the original — DB Browser '
                  'writes to what it opens.',
                ),
              ],
            ),
        },
      ),
    );
  }
}
