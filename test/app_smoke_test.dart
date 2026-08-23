import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/app.dart';
import 'package:lev/core/l10n/app_localizations.dart';
import 'package:lev/features/home/presentation/home_screen.dart';

void main() {
  testWidgets('app boots to the Home screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LevApp()));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.homeTagline), findsOneWidget);
    expect(find.text(l10n.homeOpenChat), findsOneWidget);
    expect(find.text(l10n.homeOpenTasks), findsOneWidget);
  });
}
