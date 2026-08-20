import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/app.dart';
import 'package:lev/core/l10n/app_localizations.dart';
import 'package:lev/features/chat/presentation/chat_screen.dart';
import 'package:lev/features/home/presentation/home_screen.dart';
import 'package:lev/features/mutual_aid/presentation/tasks_screen.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: LevApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('Home navigates to Chat and back', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text(l10n.homeOpenChat));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Home navigates to Tasks and back', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text(l10n.homeOpenTasks));
    await tester.pumpAndSettle();
    expect(find.byType(TasksScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
