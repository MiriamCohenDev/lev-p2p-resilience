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
  String get navHome => 'Home';

  @override
  String get navChat => 'Chat';

  @override
  String get navAid => 'Help';

  @override
  String get welcomeTagline =>
      'A quiet place to talk, and a small net of people nearby.';

  @override
  String get welcomePrivacy =>
      'Everything stays on your device. No account, no sign-up, and no internet connection.';

  @override
  String get welcomeLockTitle => 'Lock with a code';

  @override
  String get welcomeLockWarning =>
      'If you forget the code there is no way to recover it, and the data will be lost. There is no server that can help.';

  @override
  String get lockUnavailable =>
      'Locking with a code is not available in this version yet.';

  @override
  String get welcomeStart => 'Get started';

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String get homePromptMorning => 'How are you feeling this morning?';

  @override
  String get homePromptAfternoon => 'How are you feeling today?';

  @override
  String get homePromptEvening => 'How are you feeling this evening?';

  @override
  String get homeStartChat => 'Start a conversation';

  @override
  String get homeResumeLabel => 'Pick up where you left off';

  @override
  String get conversationsTitle => 'Conversations';

  @override
  String get conversationsNew => 'New conversation';

  @override
  String get conversationsSearchHint => 'Search conversations';

  @override
  String get conversationsEmptyTitle => 'We haven\'t talked yet';

  @override
  String get conversationsEmptyBody =>
      'What you write here is saved encrypted on your device alone, and never leaves it.';

  @override
  String get conversationsSearchEmptyTitle => 'No conversation found';

  @override
  String get conversationsSearchEmptyBody =>
      'You can search for a word from inside the messages too, not only the title.';

  @override
  String get conversationGroupToday => 'Today';

  @override
  String get conversationGroupLastWeek => 'Last 7 days';

  @override
  String get conversationGroupEarlier => 'Earlier';

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
  String stamp(String day, String time) {
    return '$day · $time';
  }

  @override
  String get dayToday => 'Today';

  @override
  String get dayYesterday => 'Yesterday';

  @override
  String get chatTitle => 'Conversation';

  @override
  String get chatInputHint => 'Write here…';

  @override
  String get chatSend => 'Send';

  @override
  String get chatStop => 'Stop';

  @override
  String get chatTyping => 'Writing a reply';

  @override
  String get chatPreparingSession => 'Preparing the conversation…';

  @override
  String get chatPreparingModelTitle => 'Preparing the model';

  @override
  String get chatPreparingModelBody =>
      'This happens once. After it, opening is immediate.';

  @override
  String get chatPreparingModelOffline => 'No internet connection';

  @override
  String get chatTruncatedTitle => 'The reply was cut off';

  @override
  String get chatTruncatedBody =>
      'Something stopped it half-way. The conversation was saved, and you can try again.';

  @override
  String get chatLoadFailed => 'This conversation could not be opened.';

  @override
  String get modelIntegrityTitle => 'We could not load the model';

  @override
  String get modelIntegrityBody =>
      'The model file is not valid, or has changed since it was installed. The copy between devices may have been interrupted.';

  @override
  String get modelIntegrityAction => 'Import the file again';

  @override
  String get modelTooSmallTitle => 'This device is small for the model';

  @override
  String get modelTooSmallBody =>
      'The chat needs free memory that is not here, and it would have stalled. You can try a smaller model if there is one on this device.';

  @override
  String get modelTooSmallAction => 'Choose another model';

  @override
  String get modelUnavailableTitle => 'The chat could not be opened';

  @override
  String get modelUnavailableBody =>
      'The language model is not available on this device. It is installed alongside the application, and without it the conversation cannot run.';

  @override
  String get aidStillWorks => 'Mutual aid keeps working as usual.';

  @override
  String get aidTitle => 'Help';

  @override
  String get aidComingSoonTitle => 'Mutual aid is not built yet';

  @override
  String get aidComingSoonBody =>
      'When it is ready, help requests from nearby will appear here — and all of it will stay on the device.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGroupGeneral => 'General';

  @override
  String get settingsLanguage => 'Interface language';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsFollowDevice => 'Follow the device';

  @override
  String get settingsAppearanceLight => 'Light';

  @override
  String get settingsAppearanceDark => 'Dark';

  @override
  String get languageHebrew => 'עברית';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsGroupModel => 'Language model';

  @override
  String get settingsActiveModel => 'Active model';

  @override
  String settingsModelValue(String family, String language) {
    return '$family · $language';
  }

  @override
  String get settingsModelOnDevice => 'Runs on the device, with no network';

  @override
  String settingsModelOnDeviceWithSize(String size) {
    return '$size GB · runs on the device, with no network';
  }

  @override
  String get settingsGroupPrivacy => 'Privacy';

  @override
  String get settingsLock => 'Lock with a code';

  @override
  String get settingsDeleteAll => 'Delete all data';

  @override
  String get settingsGroupAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get deleteAllTitle => 'Delete all data?';

  @override
  String get deleteAllBody =>
      'Every conversation and request will be erased from this device. There is no way to restore them — there is no server and no backup.';

  @override
  String get deleteAllConfirm => 'Delete';

  @override
  String get deleteAllFailed => 'The data could not be deleted.';

  @override
  String get storageFailedTitle => 'The application could not be opened';

  @override
  String get storageFailedBody =>
      'The encrypted store on this device could not be opened. Restarting sometimes helps; if it keeps happening, the data on this device may no longer be readable — there is no server and no backup to restore it from.';

  @override
  String get retry => 'Try again';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get cancel => 'Cancel';

  @override
  String get back => 'Back';
}
