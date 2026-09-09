import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he'),
  ];

  /// The application name, shown in the task switcher, the window title and the Home app bar. Latin in both locales — it is the wordmark, not a translated noun
  ///
  /// In en, this message translates to:
  /// **'LEV'**
  String get appTitle;

  /// Bottom navigation / rail destination: the Home screen
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom navigation / rail destination: the supportive conversation
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// Bottom navigation / rail destination: mutual aid
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get navAid;

  /// Tooltip of the desktop bar control that collapses the permanent list column. Desktop only — on mobile the list is a drawer, which closes itself
  ///
  /// In en, this message translates to:
  /// **'Hide the conversation list'**
  String get sideListHide;

  /// Tooltip of the same control once the column is collapsed, when it brings it back
  ///
  /// In en, this message translates to:
  /// **'Show the conversation list'**
  String get sideListShow;

  /// One-line description of what LEV is, on the first-run screen
  ///
  /// In en, this message translates to:
  /// **'A quiet place to talk, and a small net of people nearby.'**
  String get welcomeTagline;

  /// The privacy promise on the first-run screen. Shown in a card, before any decision is asked for
  ///
  /// In en, this message translates to:
  /// **'Everything stays on your device. No account, no sign-up, and no internet connection.'**
  String get welcomePrivacy;

  /// Title of the optional PIN-lock offer on the first-run screen
  ///
  /// In en, this message translates to:
  /// **'Lock with a code'**
  String get welcomeLockTitle;

  /// The warning that goes with the PIN-lock offer. Deliberately in the body of the card, at the same size as the rest of the text, and before the decision — not in small print
  ///
  /// In en, this message translates to:
  /// **'If you forget the code there is no way to recover it, and the data will be lost. There is no server that can help.'**
  String get welcomeLockWarning;

  /// Why the PIN-lock switch is disabled. PIN mode (an Argon2-derived KEK) is not implemented, and a disabled control with no explanation is a broken screen
  ///
  /// In en, this message translates to:
  /// **'Locking with a code is not available in this version yet.'**
  String get lockUnavailable;

  /// The single action on the first-run screen. There is no 'skip' — one screen, one button
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get welcomeStart;

  /// Home greeting before noon. Chosen from the device clock — this is all the application 'knows' about the user, and no personalisation here needs any data
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeGreetingMorning;

  /// Home greeting between noon and evening
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get homeGreetingAfternoon;

  /// Home greeting from the evening onwards, including overnight
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreetingEvening;

  /// The secondary line under the Home greeting, before noon
  ///
  /// In en, this message translates to:
  /// **'How are you feeling this morning?'**
  String get homePromptMorning;

  /// The secondary line under the Home greeting, in the afternoon
  ///
  /// In en, this message translates to:
  /// **'How are you feeling today?'**
  String get homePromptAfternoon;

  /// The secondary line under the Home greeting, in the evening
  ///
  /// In en, this message translates to:
  /// **'How are you feeling this evening?'**
  String get homePromptEvening;

  /// The only filled button on the Home screen. Creates a conversation and opens it
  ///
  /// In en, this message translates to:
  /// **'Start a conversation'**
  String get homeStartChat;

  /// Section label above the card for the most recent conversation
  ///
  /// In en, this message translates to:
  /// **'Pick up where you left off'**
  String get homeResumeLabel;

  /// Header of the conversation list, in the drawer and in the desktop column
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get conversationsTitle;

  /// Button at the top of the conversation list that creates one and opens it
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get conversationsNew;

  /// Placeholder in the conversation-list search field
  ///
  /// In en, this message translates to:
  /// **'Search conversations'**
  String get conversationsSearchHint;

  /// Title of the empty state shown when no conversation has been saved, and inside an open conversation with no messages
  ///
  /// In en, this message translates to:
  /// **'We haven\'t talked yet'**
  String get conversationsEmptyTitle;

  /// Body of the empty conversation state. The promise is repeated at exactly the moment the user is about to write the first thing — which is where the sentence is worth something
  ///
  /// In en, this message translates to:
  /// **'What you write here is saved encrypted on your device alone, and never leaves it.'**
  String get conversationsEmptyBody;

  /// Shown when a search over the conversation list matches nothing. A filtered empty state explains; it gets no action, because there is nothing to do in it but change the search
  ///
  /// In en, this message translates to:
  /// **'No conversation found'**
  String get conversationsSearchEmptyTitle;

  /// Body of the empty search result
  ///
  /// In en, this message translates to:
  /// **'You can search for a word from inside the messages too, not only the title.'**
  String get conversationsSearchEmptyBody;

  /// Time heading in the conversation list. A supportive conversation is remembered by when it happened, not by its title
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get conversationGroupToday;

  /// Time heading in the conversation list
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get conversationGroupLastWeek;

  /// Time heading in the conversation list, for everything older than a week
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get conversationGroupEarlier;

  /// List entry for a conversation with no message in it yet, so it has no derived title. Deliberately different wording from conversationsNew, which is the button that creates one
  ///
  /// In en, this message translates to:
  /// **'Untitled conversation'**
  String get conversationUntitled;

  /// Tooltip and screen-reader label of the button on a conversation row that opens its menu
  ///
  /// In en, this message translates to:
  /// **'Conversation actions'**
  String get conversationActions;

  /// Entry in a conversation row's menu that opens the rename dialog
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get conversationRename;

  /// Title of the rename dialog. A statement of what is being edited rather than a question — unlike deleting, there is nothing here to confirm
  ///
  /// In en, this message translates to:
  /// **'Conversation name'**
  String get conversationRenameTitle;

  /// Placeholder in the rename dialog's text field
  ///
  /// In en, this message translates to:
  /// **'A name you will recognise later'**
  String get conversationRenameHint;

  /// Announced by a screen reader on the rename dialog's disabled save button, saying why it cannot be pressed
  ///
  /// In en, this message translates to:
  /// **'A conversation needs a name.'**
  String get conversationRenameEmpty;

  /// Action that deletes a conversation. Appears twice in one flow — as the menu entry that asks, and as the confirming button in the dialog that follows
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get conversationDelete;

  /// Title of the confirmation dialog before deleting a conversation
  ///
  /// In en, this message translates to:
  /// **'Delete this conversation?'**
  String get conversationDeleteTitle;

  /// Body of the delete-conversation confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Its messages will be erased from this device. This cannot be undone.'**
  String get conversationDeleteBody;

  /// Joins a relative day and a clock time, as shown under a conversation card
  ///
  /// In en, this message translates to:
  /// **'{day} · {time}'**
  String stamp(String day, String time);

  /// Relative day used in a timestamp
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dayToday;

  /// Relative day used in a timestamp
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dayYesterday;

  /// App bar title of the Chat screen when the conversation has no derived title
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get chatTitle;

  /// Placeholder in the chat message field
  ///
  /// In en, this message translates to:
  /// **'Write here…'**
  String get chatInputHint;

  /// Button that sends the typed message
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// Button that stops a reply while it is being written. It replaces Send rather than disappearing: a send button that does nothing is a frozen screen with a nicer coat of paint
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get chatStop;

  /// Announced as a live region while the three dots are showing, so a blind user knows the model is writing
  ///
  /// In en, this message translates to:
  /// **'Writing a reply'**
  String get chatTyping;

  /// The banner shown while a saved conversation's session prefills. Short and expected, so it is a line that hides nothing — the old messages stay visible beneath it
  ///
  /// In en, this message translates to:
  /// **'Preparing the conversation…'**
  String get chatPreparingSession;

  /// Full-screen state while the model is loaded and verified. Long and one-off, which is why it gets a whole screen rather than a line
  ///
  /// In en, this message translates to:
  /// **'Preparing the model'**
  String get chatPreparingModelTitle;

  /// Body of the model preparation screen
  ///
  /// In en, this message translates to:
  /// **'This happens once. After it, opening is immediate.'**
  String get chatPreparingModelBody;

  /// A small line that appears exactly where any other application would be downloading something. It is a chance to prove the promise in real time
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get chatPreparingModelOffline;

  /// Shown inline when generation stopped part-way. Whatever already arrived stays on screen; this says the rest is not coming
  ///
  /// In en, this message translates to:
  /// **'The reply was cut off'**
  String get chatTruncatedTitle;

  /// Body of the truncated-reply notice
  ///
  /// In en, this message translates to:
  /// **'Something stopped it half-way. The conversation was saved, and you can try again.'**
  String get chatTruncatedBody;

  /// Shown when the conversation itself cannot be loaded
  ///
  /// In en, this message translates to:
  /// **'This conversation could not be opened.'**
  String get chatLoadFailed;

  /// The sha256 integrity check failed. Per the spec this must refuse to load rather than trying anyway, and this screen is the expression of that rule
  ///
  /// In en, this message translates to:
  /// **'We could not load the model'**
  String get modelIntegrityTitle;

  /// Body of the model-integrity failure
  ///
  /// In en, this message translates to:
  /// **'The model file is not valid, or has changed since it was installed. The copy between devices may have been interrupted.'**
  String get modelIntegrityBody;

  /// Action offered after a model-integrity failure
  ///
  /// In en, this message translates to:
  /// **'Import the file again'**
  String get modelIntegrityAction;

  /// The min-spec gate refused. Phrased against the pairing, not against the user's device: an error that blames the device and walks away is a dead screen
  ///
  /// In en, this message translates to:
  /// **'This device is small for the model'**
  String get modelTooSmallTitle;

  /// Body of the below-spec device state
  ///
  /// In en, this message translates to:
  /// **'The chat needs free memory that is not here, and it would have stalled. You can try a smaller model if there is one on this device.'**
  String get modelTooSmallBody;

  /// Action offered when the device is below the model's minimum spec
  ///
  /// In en, this message translates to:
  /// **'Choose another model'**
  String get modelTooSmallAction;

  /// Generic model failure: no weights installed, or a manifest that could not be read
  ///
  /// In en, this message translates to:
  /// **'The chat could not be opened'**
  String get modelUnavailableTitle;

  /// Body of the generic model failure
  ///
  /// In en, this message translates to:
  /// **'The language model is not available on this device. It is installed alongside the application, and without it the conversation cannot run.'**
  String get modelUnavailableBody;

  /// The footnote that ends every chat error. Not consolation but an architectural fact: the two capabilities are fully independent, so one failing must never look like the application failing
  ///
  /// In en, this message translates to:
  /// **'Mutual aid keeps working as usual.'**
  String get aidStillWorks;

  /// Title of the mutual-aid screen
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get aidTitle;

  /// Placeholder on the mutual-aid tab. Deliberately not phrased as 'no open requests' — that would be a lie: the feature does not exist, it is not empty
  ///
  /// In en, this message translates to:
  /// **'Mutual aid is not built yet'**
  String get aidComingSoonTitle;

  /// Body of the mutual-aid placeholder
  ///
  /// In en, this message translates to:
  /// **'When it is ready, help requests from nearby will appear here — and all of it will stay on the device.'**
  String get aidComingSoonBody;

  /// Title of the settings screen, and the tooltip of the control that opens it
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings group heading
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGroupGeneral;

  /// Settings row: the UI language. Independent of the model's language, which is English in v1
  ///
  /// In en, this message translates to:
  /// **'Interface language'**
  String get settingsLanguage;

  /// Settings row: light / dark / follow the device
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// The default value of both the language and the appearance rows. It matters in an evening application: someone whose device is dark at night should not have to go looking for a setting
  ///
  /// In en, this message translates to:
  /// **'Follow the device'**
  String get settingsFollowDevice;

  /// Appearance option
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsAppearanceLight;

  /// Appearance option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsAppearanceDark;

  /// The Hebrew language, named in Hebrew in both locales — a language is listed in its own name so a speaker can find it
  ///
  /// In en, this message translates to:
  /// **'עברית'**
  String get languageHebrew;

  /// The English language, named in English in both locales
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Settings group heading
  ///
  /// In en, this message translates to:
  /// **'Language model'**
  String get settingsGroupModel;

  /// Settings row naming the model that is running. The model is shown rather than hidden: this is not technical curiosity, it is what proves the product's central promise, and so it belongs on a screen the user sees
  ///
  /// In en, this message translates to:
  /// **'Active model'**
  String get settingsActiveModel;

  /// The active model's family and the language it speaks
  ///
  /// In en, this message translates to:
  /// **'{family} · {language}'**
  String settingsModelValue(String family, String language);

  /// Subtitle under the active model row, when its file size is not known
  ///
  /// In en, this message translates to:
  /// **'Runs on the device, with no network'**
  String get settingsModelOnDevice;

  /// Subtitle under the active model row, including the installed file's size
  ///
  /// In en, this message translates to:
  /// **'{size} GB · runs on the device, with no network'**
  String settingsModelOnDeviceWithSize(String size);

  /// Settings group heading
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsGroupPrivacy;

  /// Settings row for the optional PIN. Disabled for now — see lockUnavailable
  ///
  /// In en, this message translates to:
  /// **'Lock with a code'**
  String get settingsLock;

  /// Settings row that erases everything. With no server this is the only way to start over, so it has to be easy to find — and behind an explicit confirmation
  ///
  /// In en, this message translates to:
  /// **'Delete all data'**
  String get settingsDeleteAll;

  /// Settings group heading
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsGroupAbout;

  /// Settings row showing the application version
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// The value of the About version row. LEV is handed between devices as a file, so the build number is shown too: it is the only thing that distinguishes two binaries carrying the same version
  ///
  /// In en, this message translates to:
  /// **'{version} (build {build})'**
  String aboutVersionValue(String version, String build);

  /// Announced by a screen reader after the version row's title. A long press is invisible, so a row that carries one has to say so
  ///
  /// In en, this message translates to:
  /// **'Press and hold to copy the version and build number'**
  String get aboutVersionCopyHint;

  /// Snackbar shown after the version row copies itself to the clipboard
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get aboutCopied;

  /// Sub-heading above the four statements about where data lives
  ///
  /// In en, this message translates to:
  /// **'How LEV works'**
  String get aboutHowItWorks;

  /// About statement 1 of 4. Plain fact, not marketing — this section is where the product's central promise is written down
  ///
  /// In en, this message translates to:
  /// **'Conversations and requests are kept on this device alone, in an encrypted database.'**
  String get aboutFactStorage;

  /// About statement 2 of 4
  ///
  /// In en, this message translates to:
  /// **'There is no account and no sign-up. There is no server for information to be sent to.'**
  String get aboutFactNoAccount;

  /// About statement 3 of 4
  ///
  /// In en, this message translates to:
  /// **'The language model runs on the device itself. What is written in the chat does not leave it.'**
  String get aboutFactOnDevice;

  /// About statement 4 of 4. The other half of the promise: no server also means no recovery
  ///
  /// In en, this message translates to:
  /// **'Deleting the application deletes the data. There is no copy anywhere else.'**
  String get aboutFactDeletion;

  /// About row that opens the licence page
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get aboutLicenses;

  /// The legalese line at the head of the licence page. Says outright that the bundled assets are listed, because they are the ones a reader would not expect a licence page to know about
  ///
  /// In en, this message translates to:
  /// **'LEV is distributed under the Apache 2.0 licence. The fonts, the encrypted database and the language model carry licences of their own, and they appear here.'**
  String get aboutLegalese;

  /// Title of the only destructive confirmation in the product, and the only place its red appears
  ///
  /// In en, this message translates to:
  /// **'Delete all data?'**
  String get deleteAllTitle;

  /// Body of the delete-everything confirmation
  ///
  /// In en, this message translates to:
  /// **'Every conversation and request will be erased from this device. There is no way to restore them — there is no server and no backup.'**
  String get deleteAllBody;

  /// The destructive confirm button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAllConfirm;

  /// Shown when erasing the database or its key material failed
  ///
  /// In en, this message translates to:
  /// **'The data could not be deleted.'**
  String get deleteAllFailed;

  /// The encrypted database could not be opened — the key store was unreachable, or the key material is gone. Shown above everything else, because nothing in the application works without storage
  ///
  /// In en, this message translates to:
  /// **'The application could not be opened'**
  String get storageFailedTitle;

  /// Body of the storage failure. It does not promise recovery, because for a lost key there is none
  ///
  /// In en, this message translates to:
  /// **'The encrypted store on this device could not be opened. Restarting sometimes helps; if it keeps happening, the data on this device may no longer be readable — there is no server and no backup to restore it from.'**
  String get storageFailedBody;

  /// Generic action that retries the operation that failed
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// Generic action that acknowledges and hides a message
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// Generic action that abandons a dialog without doing anything
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Generic action that commits what a dialog was opened to change
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Generic action returning to the previous screen
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'he':
      return AppLocalizationsHe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
