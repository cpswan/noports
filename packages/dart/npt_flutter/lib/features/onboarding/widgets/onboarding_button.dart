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

enum _OnboardingButtonStatus {
  ready,
  picking,
  processingFile,
}

class _OnboardingButtonState extends State<OnboardingButton> {
  _OnboardingButtonStatus buttonStatus = _OnboardingButtonStatus.ready;

  // TODO: when an atSign is being onboarded
  // make this button go into a loading state or show some visual indication
  // for progress for the loading screen
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return switch (buttonStatus) {
      _OnboardingButtonStatus.ready => ElevatedButton.icon(
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
        ),
      _OnboardingButtonStatus.picking => const Text("Waiting for file to be picked"),
      _OnboardingButtonStatus.processingFile => const Text("Processing file"),
    };
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
            content: Text(
              onboardingResult?.message ?? AppLocalizations.of(context)!.onboardingError,
            ),
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
      return AtOnboardingResult.error(
        message: "Failed to retrieve the atserver status",
      );
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
        result ??= AtOnboardingResult.error(
          message: "There was an error activating your atSign, please try again later.\n"
              "If the issue persists, please contact support",
        );
      case AtSignStatus.activated:
        // NOTE: for now this is hard coded to do atKey file upload
        // Later on, we can add the APKAM flow, and will need to make some
        // UX decisions about how the user picks which they want to do
        Stream<FileUploadStatus> statusStream = util.uploadAtKeysFile(atsign);
        result = await handleFileUploadStatusStream(statusStream, atsign);
      case AtSignStatus.notFound:
        result = AtOnboardingResult.error(
          message: "The atSign you have requested, doesn't exist in this root domain",
        );
      case AtSignStatus.unavailable:
        result = AtOnboardingResult.error(
          message: "The atSign is unavailable, make sure you have internet connectivity",
        );
      case null: // This case should never happen, treat it as an error
      case AtSignStatus.error:
        result = AtOnboardingResult.error(
          message: "Failed to retrieve the atserver status",
        );
    }
    return result;
  }

  Future<AtOnboardingResult?> handleFileUploadStatusStream(Stream<FileUploadStatus> statusStream, String atsign) async {
    AtOnboardingResult? result;
    outer:
    await for (FileUploadStatus status in statusStream) {
      // Don't return from inside this switch other wise the buttonStatus
      // won't be reset to ready state
      switch (status) {
        case ErrorIncorrectKeyFile():
          result = AtOnboardingResult.error(
            message: "Invalid atKeys file detected",
          );
          break outer;
        case ErrorAtSignMismatch():
          result = AtOnboardingResult.error(
            message: "The atKeys file you uploaded did not match the atSign requested",
          );
          break outer;
        case ErrorFailedFileProcessing():
          result = AtOnboardingResult.error(
            message: "Failed to process the atKeys file",
          );
          break outer;
        case ErrorAtServerUnreachable():
          result = AtOnboardingResult.error(
            message: "Unable to connect to the atServer, make sure you have a stable internet connection",
          );
          break outer;
        case ErrorAuthFailed():
          result = AtOnboardingResult.error(
            message: "Authentication failed",
          );
          break outer;
        case ErrorAuthTimeout():
          result = AtOnboardingResult.error(
            message: "Authentication timed out",
          );
          break outer;
        case ErrorPairedAtsign _:
          result = AtOnboardingResult.error(
            message: "The atSign ${status.atSign ?? atsign} is already paired, please contact support.",
          );
          break outer;
        case FilePickingInProgress():
          setState(() {
            buttonStatus = _OnboardingButtonStatus.picking;
          });
          break; // don't break outer, this is a mid progress update
        case ProcessingAesKeyInProgress():
          setState(() {
            buttonStatus = _OnboardingButtonStatus.processingFile;
          });
          break; // don't break outer, this is a mid progress update

        // We don't really need to handle these
        case FilePickingDone():
        case ProcessingAesKeyDone():
          break;

        case FilePickingCanceled():
          result = AtOnboardingResult.cancelled();
          break outer;
        case FileUploadAuthSuccess _:
          result = AtOnboardingResult.success(atsign: status.atSign ?? atsign);
          break outer;
      }
    }
    setState(() {
      buttonStatus = _OnboardingButtonStatus.ready;
    });
    return result;
  }
}
