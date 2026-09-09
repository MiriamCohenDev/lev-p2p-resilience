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
| `LevBrandLine` | שורת המותג בראש סקציית "אודות" |
| `LevFactList` | ארבע ההצהרות ב"איך LEV עובד" |
| `LevContactRow` | שורת ער"ן — מספר בר-בחירה + חיוג |
| `showLevDestructiveDialog` | אישור מחיקת כל הנתונים |
| `LevShell` | מעטפת הניווט — מובייל ודסקטופ |
| `LevConversationList` | רשימת השיחות — במגירה ובעמודה הקבועה |

**מסך שכותב לעצמו `Container` עם צבע הוא סטייה מהמערכת.** אם רכיב חסר — להוסיף אותו כאן, לא לאלתר במסך.

---

## שתי החלטות שהקוד מממש

**`LevShell` — נקודת מעבר 900px.** מתחת לזה: `NavigationBar` תחתון + `Scaffold.drawer` לרשימות. מעליה: `NavigationRail` + עמודת רשימה קבועה. אותם מסכים בדיוק ממלאים את שתי הפריסות — אין שני עצי widgets לתחזק.

**`LevConversationList` — widget אחד, שתי התנהגויות.** בדיקת `Scaffold.maybeOf(context)?.hasDrawer` קובעת אם בחירת שיחה סוגרת מגירה או לא. זה כל ההבדל בין המגירה במובייל לעמודה בדסקטופ.

---

## ניווט ומבנה מסכים — סקציית "אודות"

**"אודות" היא הסקציה האחרונה במסך ההגדרות. היא איננה מסך.** אין לה route,
אין לה לשונית בסרגל הניווט, ואין לה כרטיס במסך הבית. ההגדרות נשארות הנקודה
היחידה שממנה מגיעים אליה — שלוש היעדים בסרגל הם קבועים (#22), ולשונית רביעית
עבור דף שאיש לא פותח פעמיים היא לשונית שנלקחת ממשהו אחר.

לסקציה שתי מטרות, ושתיהן מחייבות:

1. **משפטית.** הפונטים, המודל ו-SQLCipher נושאים רישיונות שמחייבים הצגת הודעה.
   LEV מופצת בהעברת קבצים ולא דרך חנות (#2), ולכן אין דף חנות שיישא אותה —
   היא בתוך המוצר או שאיננה. `showLicensePage` אוסף חבילות pub בלבד ולא מכיר
   נכסים; ארבעת הנכסים מגיעים אליו דרך `LevAssetLicenses`, שנרשם ב-`main()`.
2. **מוצרית.** ההבטחה "הכול על המכשיר, בלי חשבון, בלי רשת" מקבלת מקום קבוע
   שכתוב בו במפורש. **אין מדיניות פרטיות בקישור** — זו אפליקציה בלי רשת,
   וקישור הוא כפתור מת (#25).

**המבנה, בסדר הזה:**

| # | מה | רכיב |
|---|---|---|
| 1 | שורת מותג — `LevLogo.horizontal(height: 20)`, מרוכז | `LevBrandLine` |
| 2 | גרסה + build; לחיצה ארוכה מעתיקה ללוח | `LevListRow` |
| 3 | "איך LEV עובד" + **ארבע** ההצהרות | `LevSectionLabel` + `LevFactList` |
| 4 | המודל הפעיל + שורת ה-attribution שהרישיון דורש | `LevListRow` |
| 5 | "רישיונות קוד פתוח" → `showLicensePage` | `LevListRow` |
| 6 | ער"ן — שם ומספר מ-`assets/support/<lang>.json` | `LevContactRow` |

**מה אסור לשנות בלי לחשוב:**

- **ארבע ההצהרות הן כל הטקסט בסקציה.** כל תוספת היא טקסט שיווקי, וטקסט שיווקי
  הוא בדיוק מה שהסקציה הזאת קיימת במקומו.
- **שורת ה-attribution נטענת מ-`assets/models/models.json`** (השדה `attribution`)
  ומוצגת מילה במילה. היא **אינה מתורגמת** — זו הודעה שרישיון דרש, לא טקסט ממשק,
  ומודל שני מגיע עם רישיון משלו, וזו רשומה במניפסט ולא שינוי קוד (§5.3).
- **מספר ער"ן נטען מהנכס, לעולם לא מוקלד בקוד.** הוא נבדק לפי לוח זמנים
  (`reviewedOn`) וחייב להיות ניתן לתיקון בלי build מחדש.
- **אין אדום בסקציה.** האדום ההרסני מגיע לפקד אחד במוצר (#21).
- **שורת המותג היא `LevLogo.horizontal`, לא הסמל + `Text('LEV')`.** לוקאפ מורכב
  ביד מציב את הוורדמארק בפונט הממשק — בדיוק מה ש-#28 הוציא מהסרגלים. המילה
  שייכת ללוגו ולפונט שלו, ויש וריאנט שמצייר בדיוק את זה. זה **המקום היחיד
  בתוך האפליקציה** שבו המילה מופיעה.
- **לחיצה ארוכה היא בלתי-נראית**, ולכן שורת הגרסה מכריזה עליה ב-`semanticsHint`.
  שורה עם `onLongPress` בלי hint היא פעולה שקורא-מסך לא יכול לגלות שקיימת.

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
