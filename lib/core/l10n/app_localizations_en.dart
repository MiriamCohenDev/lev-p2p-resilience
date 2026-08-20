// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LEV';

  @override
  String get homeTagline => 'A quiet space for support and mutual aid.';

  @override
  String get homeDescription =>
      'LEV runs entirely on your device. Talk things through with a local assistant, or lend and receive a hand nearby. No account, no server, nothing leaves this device.';

  @override
  String get homeOpenChat => 'Start a conversation';

  @override
  String get homeOpenTasks => 'Help requests';

  @override
  String get chatTitle => 'Conversation';

  @override
  String get chatComingSoon => 'The supportive chat is not built yet.';

  @override
  String get tasksTitle => 'Help requests';

  @override
  String get tasksComingSoon => 'Mutual aid is not built yet.';

  @override
  String get back => 'Back';
}
