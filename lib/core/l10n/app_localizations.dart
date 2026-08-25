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

  /// The application name, shown in the task switcher and app bars
  ///
  /// In en, this message translates to:
  /// **'LEV'**
  String get appTitle;

  /// One-line summary of LEV's purpose, shown on the Home screen
  ///
  /// In en, this message translates to:
  /// **'A quiet space for support and mutual aid.'**
  String get homeTagline;

  /// Short paragraph on the Home screen describing what LEV is
  ///
  /// In en, this message translates to:
  /// **'LEV runs entirely on your device. Talk things through with a local assistant, or lend and receive a hand nearby. No account, no server, nothing leaves this device.'**
  String get homeDescription;

  /// Home screen button that navigates to the conversation list
  ///
  /// In en, this message translates to:
  /// **'Start a conversation'**
  String get homeOpenChat;

  /// Home screen button that navigates to the Tasks screen
  ///
  /// In en, this message translates to:
  /// **'Help requests'**
  String get homeOpenTasks;

  /// App bar title of the conversation list screen
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get conversationsTitle;

  /// Shown on the conversation list when nothing has been saved yet
  ///
  /// In en, this message translates to:
  /// **'No conversations yet. Start one whenever you are ready.'**
  String get conversationsEmpty;

  /// Button that creates a conversation and opens it
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get conversationsNew;

  /// List entry for a conversation with no message in it yet, so it has no derived title. Deliberately different wording from conversationsNew, which is the button that creates one
  ///
  /// In en, this message translates to:
  /// **'Untitled conversation'**
  String get conversationUntitled;

  /// Action that deletes a conversation
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

  /// App bar title of the Chat screen when the conversation has no derived title
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get chatTitle;

  /// Placeholder in the chat message field
  ///
  /// In en, this message translates to:
  /// **'Write a message'**
  String get chatInputHint;

  /// Button that sends the typed message
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// Button that stops a reply while it is being written
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get chatStop;

  /// Shown while the assistant's reply is streaming in
  ///
  /// In en, this message translates to:
  /// **'LEV is writing…'**
  String get chatTyping;

  /// Shown while the conversation is being prefilled, before it can be used
  ///
  /// In en, this message translates to:
  /// **'Preparing the conversation…'**
  String get chatPreparing;

  /// Shown in an open conversation that has no messages yet
  ///
  /// In en, this message translates to:
  /// **'Say whatever is on your mind.'**
  String get chatEmpty;

  /// Shown when generation fails part-way; anything already written stays on screen
  ///
  /// In en, this message translates to:
  /// **'The reply could not be finished.'**
  String get chatFailed;

  /// Shown when the conversation itself cannot be loaded
  ///
  /// In en, this message translates to:
  /// **'This conversation could not be opened.'**
  String get chatLoadFailed;

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

  /// App bar title of the Tasks screen
  ///
  /// In en, this message translates to:
  /// **'Help requests'**
  String get tasksTitle;

  /// Placeholder shown on the Tasks screen until the feature is implemented
  ///
  /// In en, this message translates to:
  /// **'Mutual aid is not built yet.'**
  String get tasksComingSoon;

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
