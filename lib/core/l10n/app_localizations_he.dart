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
  String get conversationsTitle => 'שיחות';

  @override
  String get conversationsEmpty => 'עדיין אין שיחות. אפשר להתחיל מתי שנוח לך.';

  @override
  String get conversationsNew => 'שיחה חדשה';

  @override
  String get conversationUntitled => 'שיחה ללא כותרת';

  @override
  String get conversationDelete => 'מחיקה';

  @override
  String get conversationDeleteTitle => 'למחוק את השיחה הזאת?';

  @override
  String get conversationDeleteBody =>
      'ההודעות שלה יימחקו מהמכשיר הזה. אי אפשר לבטל את הפעולה.';

  @override
  String get chatTitle => 'שיחה';

  @override
  String get chatInputHint => 'כתיבת הודעה';

  @override
  String get chatSend => 'שליחה';

  @override
  String get chatStop => 'עצירה';

  @override
  String get chatTyping => 'לב כותבת…';

  @override
  String get chatPreparing => 'מכינה את השיחה…';

  @override
  String get chatEmpty => 'אפשר לכתוב כל מה שעל הלב.';

  @override
  String get chatFailed => 'לא הצלחנו לסיים את התשובה.';

  @override
  String get chatLoadFailed => 'לא הצלחנו לפתוח את השיחה הזאת.';

  @override
  String get retry => 'לנסות שוב';

  @override
  String get dismiss => 'סגירה';

  @override
  String get cancel => 'ביטול';

  @override
  String get tasksTitle => 'בקשות עזרה';

  @override
  String get tasksComingSoon => 'העזרה ההדדית עדיין לא נבנתה.';

  @override
  String get back => 'חזרה';
}
