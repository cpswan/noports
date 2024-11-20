import 'dart:developer';

import 'package:at_contacts_flutter/at_contacts_flutter.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_onboarding_flutter/at_onboarding_screens.dart';
import 'package:at_onboarding_flutter/at_onboarding_services.dart';
import 'package:at_server_status/at_server_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/constants.dart';
import 'package:npt_flutter/features/onboarding/onboarding.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_util.dart';
import 'package:npt_flutter/features/onboarding/widgets/onboarding_dialog.dart';
import 'package:npt_flutter/routes.dart';

import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

Future<AtClientPreference> loadAtClientPreference(String rootDomain) async {
  var dir = await getApplicationSupportDirectory();

  return AtClientPreference()
    ..rootDomain = rootDomain
    ..namespace = Constants.namespace
    ..hiveStoragePath = dir.path
    ..commitLogPath = dir.path
    ..isLocalStoreRequired = true;
}

class OnboardingButton extends StatefulWidget {
  const OnboardingButton({
    super.key,
  });

  @override
  State<OnboardingButton> createState() => _OnboardingButtonState();
}

class _OnboardingButtonState extends State<OnboardingButton> {
  //
  BuildContext get appContext => App.navState.currentContext!;

  // TODO: when an atSign is being onboarded
  // make this button go into a loading state or show some visual indication
  // for progress for the loading screen
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return ElevatedButton.icon(
      onPressed: () async {
        bool shouldOnboard = await selectAtsign();
        if (shouldOnboard && context.mounted) {
          var atsignInformation = context.read<OnboardingCubit>().state;
          onboard(atsign: atsignInformation.atSign, rootDomain: atsignInformation.rootDomain);
        }
      },
      icon: PhosphorIcon(PhosphorIcons.arrowUpRight()),
      label: Text(
        strings.getStarted,
      ),
      iconAlignment: IconAlignment.end,
    );
  }

  Future<bool> selectAtsign() async {
    var options = await getAtsignEntries();
    if (!mounted) return false;

    final cubit = context.read<OnboardingCubit>();
    String atsign = cubit.state.atSign;
    String? rootDomain = cubit.state.rootDomain;

    if (options.isEmpty) {
      atsign = "";
    } else if (atsign.isEmpty) {
      atsign = options.keys.first;
    }
    if (options.keys.contains(atsign)) {
      rootDomain = options[atsign]?.rootDomain;
    } else {
      rootDomain = Constants.getRootDomains(context).keys.first;
    }

    cubit.setState(atSign: atsign, rootDomain: rootDomain);
    final results = await showDialog(
      context: context,
      builder: (BuildContext context) => OnboardingDialog(options: options),
    );
    return results ?? false;
  }

  Future<void> onboard({required String atsign, required String rootDomain, bool isFromInitState = false}) async {
    var atSigns = await KeyChainManager.getInstance().getAtSignListFromKeychain();
    var config = AtOnboardingConfig(
      atClientPreference: await loadAtClientPreference(rootDomain),
      rootEnvironment: RootEnvironment.Production,
      domain: rootDomain,
      appAPIKey: Constants.appAPIKey,
    );

    var util = NoPortsOnboardingUtil(config);
    AtOnboardingResult? onboardingResult;

    if (!mounted) return;

    if (atSigns.contains(atsign)) {
      onboardingResult = await AtOnboarding.onboard(
        atsign: atsign,
        context: context,
        config: util.config,
      );
    } else {
      onboardingResult = await handleAtsignByStatus(atsign, util);
    }

    if (!mounted) return;
    // FIXME: determine why SnackBars aren't being rendered in this context
    // maybe related to the popped atSign selector context being dropped from
    // the tree
    switch (onboardingResult?.status ?? AtOnboardingResultStatus.cancel) {
      case AtOnboardingResultStatus.success:
        await initializeContactsService(rootDomain: rootDomain);
        postOnboard(onboardingResult!.atsign!, rootDomain);
        final result = await saveAtsignInformation(
          AtsignInformation(
            atSign: onboardingResult.atsign!,
            rootDomain: rootDomain,
          ),
        );
        log('atsign result is:$result');

        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(Routes.dashboard);

        break;
      case AtOnboardingResultStatus.error:
        if (isFromInitState) break;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(AppLocalizations.of(context)!.onboardingError),
          ),
        );
        break;
      case AtOnboardingResultStatus.cancel:
        break;
    }
  }

  Future<AtOnboardingResult?> handleAtsignByStatus(String atsign, NoPortsOnboardingUtil util) async {
    AtStatus status;
    try {
      status = await util.atServerStatus(atsign);
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          // TODO: new localization string
          // "Failed to retrieve the atserver status"
          content: Text(AppLocalizations.of(context)!.onboardingError),
        ),
      );
      return null;
    }
    AtOnboardingResult? result;
    if (!mounted) return null;

    switch (status.status()) {
      // Automatically start activation with the already entered atSign
      case AtSignStatus.teapot:
        result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AtOnboardingActivateScreen(
              hideReferences: true,
              atSign: atsign,
              config: util.config,
            ),
          ),
        );
        if (result == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              // TODO: new localization string
              // "There was an error activating your atSign, please try again later."
              // "If the issue persists, please contact support"
              content: Text(AppLocalizations.of(context)!.onboardingError),
            ),
          );
        }
      case AtSignStatus.activated:
        // NOTE: for now this is hard coded to do atKey file upload
        // Later on, we can add the APKAM flow, and will need to make some
        // UX decisions about how the user picks which they want to do
        Stream<FileUploadStatus> statusStream = util.uploadAtKeysFile(atsign);
        result = await handleFileUploadStatusStream(statusStream, atsign);
      case AtSignStatus.notFound:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            // TODO: new localization string
            // "The atSign you have requested, doesn't exist in this root domain"
            content: Text(AppLocalizations.of(context)!.onboardingError),
          ),
        );
      case AtSignStatus.unavailable:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            // TODO: new localization string
            // "The atSign is unavailable, make sure you have internet connectivity"
            content: Text(AppLocalizations.of(context)!.onboardingError),
          ),
        );
      case null: // This case should never happen, treat it as an error
      case AtSignStatus.error:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            // TODO: new localization string
            // "Failed to retrieve the atserver status"
            content: Text(AppLocalizations.of(context)!.onboardingError),
          ),
        );
    }
    return result;
  }

  Future<AtOnboardingResult?> handleFileUploadStatusStream(Stream<FileUploadStatus> statusStream, String atsign) async {
    AtOnboardingResult? result;
    await for (FileUploadStatus status in statusStream) {
      /// TODO some nice progress notifications:
      /// Example implementation:
      /// https://github.com/atsign-foundation/at_widgets/blob/b4006854fa93c21eeb5bcea41044787bdf0f6f32/packages/at_onboarding_flutter/lib/src/screen/at_onboarding_home_screen.dart#L659
      switch (status) {
        case ErrorIncorrectKeyFile():
          result = AtOnboardingResult.error(
            message: "Invalid atKeys file detected",
          );
        case ErrorAtSignMismatch():
          result = AtOnboardingResult.error(
            message: "The atKeys file you uploaded did not match the atSign requested",
          );
        case ErrorFailedFileProcessing():
          return AtOnboardingResult.error(
            message: "Failed to process the atKeys file",
          );
        case ErrorAtServerUnreachable():
          result = AtOnboardingResult.error(
            message: "Unable to connect to the atServer, make sure you have a stable internet connection",
          );
        case ErrorAuthFailed():
          result = AtOnboardingResult.error(
            message: "Authentication failed",
          );
        case ErrorAuthTimeout():
          result = AtOnboardingResult.error(
            message: "Authentication timed out",
          );
        case ErrorPairedAtsign _:
          result = AtOnboardingResult.error(
            message: "The atSign ${status.atSign ?? atsign} is already paired, please contact support.",
          );
        // We may not want to do anything in these cases...
        // If we want to show some visual indications of progress, we can
        // but it's not necessary
        case FilePickingInProgress():
        case FilePickingDone():
        case ProcessingAesKeyInProgress():
        case ProcessingAesKeyDone():
          break;

        case FilePickingCanceled():
          return AtOnboardingResult.cancelled();
        case FileUploadAuthSuccess _:
          return AtOnboardingResult.success(atsign: status.atSign ?? atsign);
      }
    }
    return result;
  }
}
