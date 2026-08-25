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
  String get conversationsTitle => 'Conversations';

  @override
  String get conversationsEmpty =>
      'No conversations yet. Start one whenever you are ready.';

  @override
  String get conversationsNew => 'New conversation';

  @override
  String get conversationUntitled => 'Untitled conversation';

  @override
  String get conversationDelete => 'Delete';

  @override
  String get conversationDeleteTitle => 'Delete this conversation?';

  @override
  String get conversationDeleteBody =>
      'Its messages will be erased from this device. This cannot be undone.';

  @override
  String get chatTitle => 'Conversation';

  @override
  String get chatInputHint => 'Write a message';

  @override
  String get chatSend => 'Send';

  @override
  String get chatStop => 'Stop';

  @override
  String get chatTyping => 'LEV is writing…';

  @override
  String get chatPreparing => 'Preparing the conversation…';

  @override
  String get chatEmpty => 'Say whatever is on your mind.';

  @override
  String get chatFailed => 'The reply could not be finished.';

  @override
  String get chatLoadFailed => 'This conversation could not be opened.';

  @override
  String get retry => 'Try again';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get cancel => 'Cancel';

  @override
  String get tasksTitle => 'Help requests';

  @override
  String get tasksComingSoon => 'Mutual aid is not built yet.';

  @override
  String get back => 'Back';
}
