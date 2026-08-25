/// The safety layer's test corpus (technical-spec §5.2.4).
///
/// §5.2.4 requires this to pass "regardless of which engine is registered",
/// which is why it is plain data checked against plain Dart: no model is
/// consulted, so there is nothing for a model to get wrong.
///
/// Both halves matter, and the negative half more than people expect. A layer
/// that fires on every mention of a hard day is one a person learns to scroll
/// past within a week, at which point it is worse than absent — it looks like
/// care while functioning as noise.
class SafetyCase {
  const SafetyCase(this.text, {required this.expectMatch, this.why = ''});

  final String text;
  final bool expectMatch;
  final String why;

  @override
  String toString() => '"$text" (${expectMatch ? 'must match' : 'must not'})';
}

/// English cases, checked against `assets/prompts/safety_patterns_en.json`.
const List<SafetyCase> englishCorpus = [
  // --- must match ---
  SafetyCase('I want to die', expectMatch: true),
  SafetyCase("I don't want to live anymore", expectMatch: true),
  SafetyCase('I have been thinking about killing myself', expectMatch: true),
  SafetyCase('sometimes I feel suicidal', expectMatch: true),
  SafetyCase(
    'everyone would be better off without me',
    expectMatch: true,
    why: 'passive ideation is still ideation',
  ),
  SafetyCase('I want to hurt myself', expectMatch: true),
  SafetyCase('I have been cutting myself again', expectMatch: true),
  SafetyCase('there is no reason to go on', expectMatch: true),
  SafetyCase('my partner hits me', expectMatch: true),
  SafetyCase('I am afraid for my safety', expectMatch: true),
  SafetyCase(
    'i want to die',
    expectMatch: true,
    why: 'distress is not written in careful prose — matching is case-insensitive',
  ),

  // --- must NOT match ---
  SafetyCase('I had a really hard day', expectMatch: false),
  SafetyCase('I am exhausted and everything feels like too much',
      expectMatch: false),
  SafetyCase('work is killing me', expectMatch: false, why: 'idiom'),
  SafetyCase('I could die of embarrassment', expectMatch: false, why: 'idiom'),
  SafetyCase('this deadline is going to kill me', expectMatch: false),
  SafetyCase('my plant died', expectMatch: false),
  SafetyCase('I want to dye my hair', expectMatch: false, why: 'not "die"'),
  SafetyCase('I feel hopeless about the election', expectMatch: false),
  SafetyCase('I am so tired I want to sleep for a week', expectMatch: false),
  SafetyCase('I want to live somewhere quieter', expectMatch: false),
  SafetyCase('', expectMatch: false),
];

/// Hebrew cases, checked against `assets/prompts/safety_patterns_he.json`.
///
/// The UI is bilingual even while the model is English-only
/// (technical-decisions #11), so a Hebrew-writing user must be caught by this
/// layer — which is precisely why it does not depend on the model.
const List<SafetyCase> hebrewCorpus = [
  // --- must match ---
  SafetyCase('אני רוצה למות', expectMatch: true),
  SafetyCase('אני לא רוצה לחיות יותר', expectMatch: true),
  SafetyCase('חשבתי להתאבד', expectMatch: true),
  SafetyCase('אין לי סיבה לחיות', expectMatch: true),
  SafetyCase('אני רוצה לפגוע בעצמי', expectMatch: true),
  SafetyCase('בן הזוג שלי מכה אותי', expectMatch: true),
  SafetyCase('נמאס לי מהחיים', expectMatch: true),

  // --- must NOT match ---
  SafetyCase('היה לי יום קשה מאוד', expectMatch: false),
  SafetyCase('אני עייף מאוד ורוצה לישון', expectMatch: false),
  SafetyCase('אני רוצה לחיות במקום שקט יותר', expectMatch: false),
  SafetyCase('העבודה הורגת אותי', expectMatch: false, why: 'idiom'),
  SafetyCase('', expectMatch: false),
];
