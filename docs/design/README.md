בס"ד

# LEV — מסירת העיצוב לקוד (שלב 7)

מה שיש כאן הוא התרגום של מערכת העיצוב ל-Flutter: הערכה, ספריית הרכיבים, מעטפת הניווט הרספונסיבית, ומשאבי שכבת הבטיחות.

> **חשוב:** הקוד נכתב מול Flutter 3.x / Material 3 אבל **לא עבר קומפילציה כאן** — בסביבה שבה נכתב אין Flutter SDK. הדבר הראשון לעשות איתו הוא `flutter analyze`, ולתקן מה שיצוף. חתימות API של Flutter משתנות בין גרסאות; במיוחד `Color.withValues` (3.27+), `MediaQuery.maybeDisableAnimationsOf`, ו-`CardThemeData`.

---

## מבנה

```
lib/core/
  theme/app_theme.dart          הטוקנים: LevColors, LevSpace, LevRadius, LevMotion, LevTheme
  widgets/lev_widgets.dart        ספריית הרכיבים
  layout/lev_shell.dart           LevShell (רספונסיבי) + LevConversationList
  support/support_resources.dart  טעינת משאבי שכבת הבטיחות מנכס
assets/
  support/he.json  en.json        מסר התמיכה + מספר הטלפון + תאריך בדיקה
```

## התקנה

ב-`pubspec.yaml`:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/support/
    - assets/branding/
  fonts:
    - family: IBMPlexSansHebrew
      fonts:
        - asset: assets/fonts/IBMPlexSansHebrew-Light.ttf
          weight: 300
        - asset: assets/fonts/IBMPlexSansHebrew-Regular.ttf
          weight: 400
        - asset: assets/fonts/IBMPlexSansHebrew-Medium.ttf
          weight: 500
        - asset: assets/fonts/IBMPlexSansHebrew-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/IBMPlexSansHebrew-Bold.ttf
          weight: 700
```

ב-`app.dart`:

```dart
MaterialApp(
  theme: LevTheme.light,
  darkTheme: LevTheme.dark,
  themeMode: ThemeMode.system,   // בהמשך: מהעדפה שנשמרת במסד המוצפן
  locale: const Locale('he'),
  supportedLocales: const [Locale('he'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
)
```

---

## הרכיבים

| Widget | מחליף את |
|---|---|
| `LevButton` | כל כפתור. `kind`: primary / secondary / destructive |
| `LevStatusPill` | תגית סטטוס של בקשה |
| `LevCard` | כרטיס בקשה, כרטיס שיחה אחרונה |
| `LevBubble` | הודעה בצ'אט (`fromUser`) |
| `LevTypingIndicator` | שלוש הנקודות |
| `LevBanner` | שורת ה-prefill |
| `LevEmptyState` | כל מצב ריק וכל מסך שגיאה |
| `LevSupportCard` | מסר שכבת הבטיחות |
| `LevSegmented` | בורר המסננים במסך העזרה |
| `LevListRow` | שורה במסך ההגדרות |
| `showLevDestructiveDialog` | אישור מחיקת כל הנתונים |
| `LevShell` | מעטפת הניווט — מובייל ודסקטופ |
| `LevConversationList` | רשימת השיחות — במגירה ובעמודה הקבועה |

**מסך שכותב לעצמו `Container` עם צבע הוא סטייה מהמערכת.** אם רכיב חסר — להוסיף אותו כאן, לא לאלתר במסך.

---

## שתי החלטות שהקוד מממש

**`LevShell` — נקודת מעבר 900px.** מתחת לזה: `NavigationBar` תחתון + `Scaffold.drawer` לרשימות. מעליה: `NavigationRail` + עמודת רשימה קבועה. אותם מסכים בדיוק ממלאים את שתי הפריסות — אין שני עצי widgets לתחזק.

**`LevConversationList` — widget אחד, שתי התנהגויות.** בדיקת `Scaffold.maybeOf(context)?.hasDrawer` קובעת אם בחירת שיחה סוגרת מגירה או לא. זה כל ההבדל בין המגירה במובייל לעמודה בדסקטופ.

---

## שכבת הבטיחות — מה אסור לשנות בלי לחשוב

`LevSupportCard` מוצג **לצד** התשובה של המודל, לעולם לא במקומה, ולעולם לא כדיאלוג מודאלי. הנימוק באפיון: הבטחה שתלויה באיכות ה-inference של מודל 4-ביט על טלפון ישן איננה הבטחה.

הפעולה היחידה בכרטיס היא `tel:`. **לא קישור לאתר** — זו אפליקציה בלי רשת, וקישור הוא כפתור מת. הרכיב לא מכיר את `url_launcher`: הוא מקבל `onCall` והמסך מחליט.

הטקסט לא מבטיח שהשיחה חסויה או אנונימית. זה משתנה בין שירותים ובין נסיבות, ואסור להבטיח את זה בשם גורם אחר.

`assets/support/he.json` נושא `reviewedOn`. **לבדוק את המספר מול מקור רשמי לפני כל שחרור ולעדכן את התאריך.** המספר הנוכחי (ער"ן, 1201) נבדק ב-2026-08-30.

---

## רשימת בדיקה לפני סיום

### נגישות
- [ ] `flutter run` עם TalkBack/VoiceOver: כל כפתור מכריז מה הוא ומה יקרה.
- [ ] כפתור מושבת מכריז **למה** הוא מושבת (`disabledHint`) — במיוחד "שיתוף עם מכשיר קרוב".
- [ ] ניווט מקלדת מלא בדסקטופ ב-Tab בלבד, עם טבעת מיקוד נראית בכל עצירה.
- [ ] `MediaQuery.textScalerOf` ב-200%: אין טקסט חתוך ואין כפתור שנשבר. לבדוק במיוחד את `LevSegmented` ואת התגיות.
- [ ] כל אזור מגע ≥ 48dp.
- [ ] `LevBanner` ו-`LevTypingIndicator` מוכרזים כ-`liveRegion` — משתמשת עיוורת יודעת שהמודל כותב.
- [ ] הפחתת אנימציות מכובדת (`disableAnimations`) — שלוש הנקודות קופאות ולא נעלמות.

### RTL
- [ ] לחפש בקוד `EdgeInsets.only(left:` / `right:` — אמור להיות אפס תוצאות.
- [ ] לחפש `Alignment.centerLeft` / `centerRight` — להחליף ב-`AlignmentDirectional`.
- [ ] המגירה נפתחת מ**ימין**.
- [ ] בועת המשתמשת בשמאל, בועת המודל בימין — כמו בכל אפליקציית הודעות בעברית.
- [ ] מספרים ומחרוזות באנגלית (שם המודל, גרסה, 1201) לא שוברים את כיוון השורה. לבדוק עם `Directionality` מקומי היכן שצריך.
- [ ] להריץ את כל המסכים גם ב-`Locale('en')` ולוודא שכלום לא נשבר לכיוון השני.

### ניגודיות
- [ ] כל הצירופים נמדדו ועוברים AA — ראו את טבלת הפלטה במסמך מערכת העיצוב. לבדוק מחדש כל צבע חדש שנוסף.
- [ ] מצב כהה ובהיר, שניהם.

### התנהגות
- [ ] פתיחת שיחה שמורה: `LevBanner` מופיע, ההודעות הישנות נראות מיד, השורה נעלמת כשה-session מוכן.
- [ ] כשל טעינת מודל: `LevEmptyState` עם `tone: warning`, ותמיד עם `footnote` שאומר שהעזרה ההדדית עובדת.
- [ ] המסך צר (חלון דסקטופ מוקטן מתחת ל-900): הפריסה עוברת למובייל בלי לאבד מצב.
