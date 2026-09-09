import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_info.dart';
import '../../../core/di/llm_providers.dart';
import '../../../core/di/prompt_providers.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lev_widgets.dart';
import 'model_labels.dart';

/// The last section of the settings screen — and the only place two obligations
/// can be met.
///
/// **Legal.** The font, the model, SQLCipher and every pub package carry
/// licences that oblige the product to show a notice. LEV is handed between
/// devices as a file rather than installed from a store (technical-decisions
/// #2), so there is no listing anywhere to carry that notice instead: it has to
/// be inside the product or it does not exist. `showLicensePage` collects pub
/// packages by itself; the three bundled **assets** reach it through
/// `LevAssetLicenses`, registered in `main()`.
///
/// **Product.** "Everything on the device, no account, no network" is the whole
/// claim, and until now it was made in passing — on the first-run screen, once,
/// and under the model row as half a line. Here it is written down in four
/// sentences that stay put. There is no privacy policy behind a link, because
/// this is an app with no network and a link is a dead button (#25).
///
/// **A section, not a screen.** No route of its own: Settings stays the single
/// place this is reached from, and a destination in the bar for a page nobody
/// opens twice would cost a permanent tab (#22).
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    // The support resource is localised for the person in front of the screen,
    // and this is the only place the real locale is known — the same override
    // the chat screen makes, for the same reason (#24).
    return ProviderScope(
      overrides: [
        safetyLocaleProvider.overrideWithValue(Localizations.localeOf(context)),
      ],
      child: const _AboutBody(),
    );
  }
}

class _AboutBody extends StatelessWidget {
  const _AboutBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LevSectionLabel(l10n.settingsGroupAbout),
        const Padding(
          padding: EdgeInsetsDirectional.only(bottom: LevSpace.md),
          child: LevBrandLine(),
        ),
        LevListGroup(children: [const _VersionRow()]),
        LevSectionLabel(l10n.aboutHowItWorks),
        // Four sentences, and that is the whole of the text. Anything added
        // here is marketing, and marketing is what this section exists instead
        // of.
        LevFactList([
          l10n.aboutFactStorage,
          l10n.aboutFactNoAccount,
          l10n.aboutFactOnDevice,
          l10n.aboutFactDeletion,
        ]),
        const SizedBox(height: LevSpace.lg),
        const LevListGroup(
          children: [_ModelAttributionRow(), _LicencesRow(), _SupportRow()],
        ),
      ],
    );
  }
}

/// The version and the build number, copyable.
///
/// The build number is here because of how LEV is distributed. With no store,
/// no update check and no crash reporting, a bug report arrives as a sentence
/// somebody typed — and two people can be holding the same version at different
/// builds. A long press puts the exact pair on the clipboard, which is the
/// difference between a report that names a binary and one that guesses at it.
///
/// A long press is invisible, so the row says so in its semantics hint. That is
/// not a nicety: for a screen-reader user it is the only way to learn the
/// action is there at all.
class _VersionRow extends StatelessWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return LevListRow(
      title: l10n.settingsVersion,
      value: l10n.aboutVersionValue(AppInfo.version, AppInfo.buildNumber),
      // Latin and digits inside a Hebrew row: without this the parentheses
      // resolve to the ambient direction and the value reads back-to-front.
      valueDirection: TextDirection.ltr,
      semanticsHint: l10n.aboutVersionCopyHint,
      onLongPress: () => _copy(context, l10n),
      showDivider: false,
    );
  }

  Future<void> _copy(BuildContext context, AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(const ClipboardData(text: AppInfo.buildStamp));
    messenger.showSnackBar(SnackBar(content: Text(l10n.aboutCopied)));
  }
}

/// The active model, and the attribution its licence requires.
///
/// Read from `activeModelProvider` — the provider that already feeds the model
/// row further up this screen. Two views of one fact, not two facts: a second
/// source here would be a screen that can disagree with itself about which
/// model is running.
///
/// The attribution is the manifest's own string, shown verbatim and **not**
/// translated. It is a notice a licence asked for, not interface copy, and a
/// second model arrives with a licence of its own — which §5.3 makes a manifest
/// entry rather than a code change.
class _ModelAttributionRow extends ConsumerWidget {
  const _ModelAttributionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final model = ref.watch(activeModelProvider).value;

    // Written exactly as the model group above writes it, through one shared
    // formatter. The two rows are two views of one fact, and a screen that
    // describes the same model differently in two places reads as a screen that
    // is unsure which one is running.
    return LevListRow(
      title: l10n.settingsActiveModel,
      value: model == null
          ? l10n.modelUnavailableTitle
          : l10n.settingsModelValue(
              modelFamilyLabel(model.family),
              modelLanguageLabel(l10n, model.language),
            ),
      subtitle: model?.attribution,
    );
  }
}

class _LicencesRow extends StatelessWidget {
  const _LicencesRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return LevListRow(
      title: l10n.aboutLicenses,
      onTap: () => showLicensePage(
        context: context,
        applicationName: l10n.appTitle,
        applicationVersion:
            l10n.aboutVersionValue(AppInfo.version, AppInfo.buildNumber),
        // The mark, through LevLogo like every other appearance of it.
        applicationIcon: const Padding(
          padding: EdgeInsetsDirectional.all(LevSpace.sm),
          child: LevLogo.mark(height: 44),
        ),
        applicationLegalese: l10n.aboutLegalese,
      ),
    );
  }
}

/// The support line's name and number, from `assets/support/<lang>.json`.
///
/// Loaded, never typed into the code: the number is reviewed on a schedule and
/// has to be fixable without a rebuild (#24). It is the same asset the safety
/// layer's card reads, through the same provider.
///
/// Here it is not a distress card — no amber, no filled button, none of the
/// card's urgency. It is a number that is simply always in the product, which
/// is a different thing and has to look like one.
class _SupportRow extends ConsumerWidget {
  const _SupportRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resource = ref.watch(supportResourceProvider).value;
    // Nothing at all until it loads, and nothing if it cannot be read. The
    // chat's card is where a missing asset must never swallow the message; a
    // row on a settings screen is not that moment, and half a row with no
    // number would be worse than none.
    if (resource == null) return const SizedBox.shrink();

    return LevContactRow(
      title: resource.serviceName,
      phone: resource.phone,
      callLabel: resource.callLabel,
      onCall: _call,
      showDivider: false,
    );
  }

  /// The same `tel:` mechanism the support card uses, and the only action here.
  ///
  /// Failure is swallowed: a desktop with no dialler should show the number and
  /// do nothing when the control is pressed. The number is selectable either
  /// way, which is what the row is for.
  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } on Object {
      return;
    }
  }
}
