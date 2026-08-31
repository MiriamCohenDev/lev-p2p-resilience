import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'app_localizations.dart';

/// How LEV writes times and dates.
///
/// All of it goes through [AppLocalizations] and `intl` rather than through
/// hardcoded patterns, so a date reads correctly in Hebrew as well as in
/// English (#11) — including the fact that Hebrew reads the clock left to right
/// inside a right-to-left line.

/// Which greeting Home shows, from the device clock.
///
/// This is the whole of what the application "knows" about the user. There is no
/// personalisation here that needs any data, which is the point.
enum LevPartOfDay { morning, afternoon, evening }

LevPartOfDay partOfDay(DateTime now) {
  if (now.hour < 12) return LevPartOfDay.morning;
  if (now.hour < 17) return LevPartOfDay.afternoon;
  return LevPartOfDay.evening;
}

extension LevGreetings on AppLocalizations {
  String greetingFor(LevPartOfDay part) => switch (part) {
        LevPartOfDay.morning => homeGreetingMorning,
        LevPartOfDay.afternoon => homeGreetingAfternoon,
        LevPartOfDay.evening => homeGreetingEvening,
      };

  String promptFor(LevPartOfDay part) => switch (part) {
        LevPartOfDay.morning => homePromptMorning,
        LevPartOfDay.afternoon => homePromptAfternoon,
        LevPartOfDay.evening => homePromptEvening,
      };
}

/// "Yesterday · 22:40", or a medium date for anything older.
String formatStamp(BuildContext context, DateTime at, {DateTime? now}) {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toString();
  final today = _startOfDay(now ?? DateTime.now());
  final day = _startOfDay(at);

  final label = switch (today.difference(day).inDays) {
    0 => l10n.dayToday,
    1 => l10n.dayYesterday,
    _ => DateFormat.MMMd(locale).format(at),
  };

  return l10n.stamp(label, DateFormat.Hm(locale).format(at));
}

/// The heading a conversation belongs under in the history list.
///
/// Grouped by time rather than alphabetically: a supportive conversation is
/// remembered by *when* it happened, not by the title derived from its first
/// sentence.
String conversationGroupHeading(
  BuildContext context,
  DateTime at, {
  DateTime? now,
}) {
  final l10n = AppLocalizations.of(context);
  final days = _startOfDay(now ?? DateTime.now())
      .difference(_startOfDay(at))
      .inDays;

  if (days <= 0) return l10n.conversationGroupToday;
  if (days <= 7) return l10n.conversationGroupLastWeek;
  return l10n.conversationGroupEarlier;
}

/// Midnight local time, so "yesterday" means the calendar day and not
/// twenty-four hours — the two disagree for most of any given evening.
DateTime _startOfDay(DateTime at) => DateTime(at.year, at.month, at.day);
