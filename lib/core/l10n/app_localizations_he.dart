// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => 'LEV';

  @override
  String get navHome => 'בית';

  @override
  String get navChat => 'צ\'אט';

  @override
  String get navAid => 'עזרה';

  @override
  String get welcomeTagline =>
      'מקום שקט לדבר בו, ורשת עזרה קטנה של אנשים לידך.';

  @override
  String get welcomePrivacy =>
      'הכול נשאר על המכשיר שלך. אין חשבון, אין הרשמה, ואין חיבור לאינטרנט.';

  @override
  String get welcomeLockTitle => 'לנעול בקוד';

  @override
  String get welcomeLockWarning =>
      'אם תשכחי את הקוד אין דרך לשחזר אותו, והנתונים יאבדו. אין שרת שיכול לעזור.';

  @override
  String get lockUnavailable => 'נעילה בקוד עדיין לא זמינה בגרסה הזאת.';

  @override
  String get welcomeStart => 'להתחיל';

  @override
  String get homeGreetingMorning => 'בוקר טוב';

  @override
  String get homeGreetingAfternoon => 'צהריים טובים';

  @override
  String get homeGreetingEvening => 'ערב טוב';

  @override
  String get homePromptMorning => 'איך את מרגישה הבוקר?';

  @override
  String get homePromptAfternoon => 'איך את מרגישה היום?';

  @override
  String get homePromptEvening => 'איך את מרגישה הערב?';

  @override
  String get homeStartChat => 'להתחיל שיחה';

  @override
  String get homeResumeLabel => 'להמשיך מאיפה שהפסקת';

  @override
  String get conversationsTitle => 'שיחות';

  @override
  String get conversationsNew => 'שיחה חדשה';

  @override
  String get conversationsSearchHint => 'חיפוש בשיחות';

  @override
  String get conversationsEmptyTitle => 'עוד לא דיברנו';

  @override
  String get conversationsEmptyBody =>
      'מה שתכתבי כאן נשמר מוצפן על המכשיר שלך בלבד, ולא יוצא ממנו לשום מקום.';

  @override
  String get conversationsSearchEmptyTitle => 'לא נמצאה שיחה';

  @override
  String get conversationsSearchEmptyBody =>
      'אפשר לחפש גם מילה מתוך ההודעות עצמן, לא רק מהכותרת.';

  @override
  String get conversationGroupToday => 'היום';

  @override
  String get conversationGroupLastWeek => '7 הימים האחרונים';

  @override
  String get conversationGroupEarlier => 'קודם';

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
  String stamp(String day, String time) {
    return '$day · $time';
  }

  @override
  String get dayToday => 'היום';

  @override
  String get dayYesterday => 'אתמול';

  @override
  String get chatTitle => 'שיחה';

  @override
  String get chatInputHint => 'כתבי כאן…';

  @override
  String get chatSend => 'שליחה';

  @override
  String get chatStop => 'עצירה';

  @override
  String get chatTyping => 'כותב תשובה';

  @override
  String get chatPreparingSession => 'מכינה את השיחה…';

  @override
  String get chatPreparingModelTitle => 'מכינה את המודל';

  @override
  String get chatPreparingModelBody =>
      'זה קורה פעם אחת בלבד. אחרי זה הפתיחה מיידית.';

  @override
  String get chatPreparingModelOffline => 'בלי חיבור לאינטרנט';

  @override
  String get chatTruncatedTitle => 'התשובה נקטעה';

  @override
  String get chatTruncatedBody =>
      'משהו הפסיק את היצירה באמצע. השיחה נשמרה, אפשר לנסות שוב.';

  @override
  String get chatLoadFailed => 'לא הצלחנו לפתוח את השיחה הזאת.';

  @override
  String get modelIntegrityTitle => 'לא הצלחנו לטעון את המודל';

  @override
  String get modelIntegrityBody =>
      'קובץ המודל אינו תקין או השתנה מאז ההתקנה. ייתכן שההעתקה בין המכשירים נקטעה.';

  @override
  String get modelIntegrityAction => 'לייבא את הקובץ מחדש';

  @override
  String get modelTooSmallTitle => 'המכשיר הזה קטן על המודל';

  @override
  String get modelTooSmallBody =>
      'לצ\'אט דרוש זיכרון פנוי שאין כאן, והוא היה נתקע. אפשר לנסות מודל קטן יותר אם קיים כזה במכשיר.';

  @override
  String get modelTooSmallAction => 'לבחור מודל אחר';

  @override
  String get modelUnavailableTitle => 'לא הצלחנו לפתוח את הצ\'אט';

  @override
  String get modelUnavailableBody =>
      'מודל השפה אינו זמין במכשיר הזה. הוא מותקן יחד עם האפליקציה, ובלעדיו השיחה לא יכולה לרוץ.';

  @override
  String get aidStillWorks => 'העזרה ההדדית ממשיכה לעבוד כרגיל.';

  @override
  String get aidTitle => 'עזרה';

  @override
  String get aidComingSoonTitle => 'העזרה ההדדית עדיין לא נבנתה';

  @override
  String get aidComingSoonBody =>
      'כשהיא תהיה מוכנה, כאן יופיעו בקשות עזרה מהסביבה הקרובה — והכול יישאר על המכשיר.';

  @override
  String get settingsTitle => 'הגדרות';

  @override
  String get settingsGroupGeneral => 'כללי';

  @override
  String get settingsLanguage => 'שפת הממשק';

  @override
  String get settingsAppearance => 'מראה';

  @override
  String get settingsFollowDevice => 'לפי המכשיר';

  @override
  String get settingsAppearanceLight => 'בהיר';

  @override
  String get settingsAppearanceDark => 'כהה';

  @override
  String get languageHebrew => 'עברית';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsGroupModel => 'מודל השפה';

  @override
  String get settingsActiveModel => 'המודל הפעיל';

  @override
  String settingsModelValue(String family, String language) {
    return '$family · $language';
  }

  @override
  String get settingsModelOnDevice => 'רץ על המכשיר, בלי רשת';

  @override
  String settingsModelOnDeviceWithSize(String size) {
    return '$size ג\'יגה · רץ על המכשיר, בלי רשת';
  }

  @override
  String get settingsGroupPrivacy => 'פרטיות';

  @override
  String get settingsLock => 'נעילה בקוד';

  @override
  String get settingsDeleteAll => 'מחיקת כל הנתונים';

  @override
  String get settingsGroupAbout => 'אודות';

  @override
  String get settingsVersion => 'גרסה';

  @override
  String get deleteAllTitle => 'למחוק את כל הנתונים?';

  @override
  String get deleteAllBody =>
      'כל השיחות והבקשות יימחקו מהמכשיר. אין דרך לשחזר אותן — אין שרת ואין גיבוי.';

  @override
  String get deleteAllConfirm => 'למחוק';

  @override
  String get deleteAllFailed => 'לא הצלחנו למחוק את הנתונים.';

  @override
  String get storageFailedTitle => 'לא הצלחנו לפתוח את האפליקציה';

  @override
  String get storageFailedBody =>
      'לא הצלחנו לפתוח את המאגר המוצפן במכשיר הזה. לפעמים הפעלה מחדש עוזרת; אם זה חוזר, ייתכן שהנתונים במכשיר כבר לא ניתנים לקריאה — אין שרת ואין גיבוי לשחזר מהם.';

  @override
  String get retry => 'לנסות שוב';

  @override
  String get dismiss => 'סגירה';

  @override
  String get cancel => 'ביטול';

  @override
  String get back => 'חזרה';
}
