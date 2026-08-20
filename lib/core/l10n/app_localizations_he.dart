// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => 'לב';

  @override
  String get homeTagline => 'מרחב שקט לתמיכה ולעזרה הדדית.';

  @override
  String get homeDescription =>
      'לב פועלת כולה על המכשיר שלך. אפשר לשוחח ולעבד דברים עם עוזר מקומי, או להושיט יד ולקבל עזרה מהסביבה הקרובה. בלי חשבון, בלי שרת, שום דבר לא יוצא מהמכשיר הזה.';

  @override
  String get homeOpenChat => 'התחלת שיחה';

  @override
  String get homeOpenTasks => 'בקשות עזרה';

  @override
  String get chatTitle => 'שיחה';

  @override
  String get chatComingSoon => 'השיחה התומכת עדיין לא נבנתה.';

  @override
  String get tasksTitle => 'בקשות עזרה';

  @override
  String get tasksComingSoon => 'העזרה ההדדית עדיין לא נבנתה.';

  @override
  String get back => 'חזרה';
}
