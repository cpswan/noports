import 'dart:convert';

import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/util/activate_util.dart';
import 'package:npt_flutter/widgets/spinner.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class ActivateAtsignDialog extends StatefulWidget {
  final pinLength = 4;
  final String registrarUrl;
  final String apiKey;
  final String atSign;
  final AtOnboardingConfig config;
  const ActivateAtsignDialog({
    super.key,
    required this.atSign,
    required this.apiKey,
    required this.config,
    required this.registrarUrl,
  });

  @override
  State<ActivateAtsignDialog> createState() => _ActivateAtsignDialogState();
}

enum ActivationStatus {
  preparing, // contacting the registrar to send an OTP
  otpWait, // Waiting for user to enter OTP
  activating, // OTP received, trying to activate
}

class _ActivateAtsignDialogState extends State<ActivateAtsignDialog> {
  late final ActivateUtil util;
  ActivationStatus status = ActivationStatus.preparing;
  TextEditingController pinController = TextEditingController();
  FocusNode pinFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    util = ActivateUtil(
      registrarUrl: widget.registrarUrl,
      apiKey: widget.apiKey,
    );
    _getPinCode();
  }

  final strings = AppLocalizations.of(App.navState.currentContext!)!;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Center(
        child: switch (status) {
          ActivationStatus.preparing => Text(strings.activationStatusPreparing),
          ActivationStatus.otpWait => Text(strings.activationStatusOtpWait),
          ActivationStatus.activating => Text(strings.activationStatusActivating),
        },
      ),
      content: SizedBox(
        height: 80,
        width: 400,
        child: switch (status) {
          ActivationStatus.preparing || ActivationStatus.activating => const Spinner(),
          ActivationStatus.otpWait => SizedBox(
              height: 80,
              child: Column(
                children: [
                  PinCodeTextField(
                    focusNode: pinFocusNode,
                    appContext: context,
                    length: widget.pinLength,
                    controller: pinController,
                    onChanged: (value) {
                      setState(() {
                        pinController.text = value.toUpperCase();
                      });
                    },
                    // Styling
                    animationType: AnimationType.fade,
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.box,
                      borderRadius: BorderRadius.circular(5),
                      fieldHeight: 50,
                      fieldWidth: 40,
                      activeFillColor: Colors.white,
                      inactiveFillColor: Colors.white,
                    ),
                    cursorColor: Colors.black,
                    animationDuration: const Duration(milliseconds: 300),
                    enableActiveFill: true,
                    keyboardType: TextInputType.number,
                    boxShadows: const [
                      BoxShadow(
                        offset: Offset(0, 1),
                        color: Colors.black12,
                        blurRadius: 10,
                      )
                    ],
                    beforeTextPaste: (text) => true,
                  ),
                ],
              ),
            ),
        },
      ),
      actions: switch (status) {
        ActivationStatus.preparing => [cancelButton],
        ActivationStatus.otpWait => [cancelButton, resendPinButton, confirmPinButton],
        // Don't allow the user to cancel activate as this opens up a bunch of
        // edge cases around navigation and onboarding state
        ActivationStatus.activating => [],
      },
    );
  }

  Future<void> _getPinCode() async {
    var res = await util.registrarApiRequest(
      NoPortsActivateApiEndpoints.login,
      {'atsign': widget.atSign},
    );

    if (res.statusCode == 200 && jsonDecode(res.body)["message"] == "Sent Successfully") {
      setState(() {
        status = ActivationStatus.otpWait;
      });
    } else {
      if (!mounted) return;
      if (status == ActivationStatus.preparing) {
        Navigator.of(context).pop(AtOnboardingResult.error(message: "@${jsonDecode(res.body)["message"]}"));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            strings.errorOtpRequestFailed,
          ),
        ),
      );
    }
    if (!pinFocusNode.hasFocus) {
      pinFocusNode.requestFocus();
    }
  }

  Widget get cancelButton => TextButton(
        key: const Key("NoPortsActivateCancelButton"),
        child: Text(strings.cancel),
        onPressed: () {
          Navigator.of(context).pop(AtOnboardingResult.cancelled());
        },
      );

  Widget get resendPinButton => TextButton(
        key: const Key("NoPortsActivateResendButton"),
        onPressed: _getPinCode,
        child: Text(strings.resendPin),
      );

  Widget get confirmPinButton => TextButton(
        key: const Key("NoPortsActivateConfirmButton"),
        onPressed: pinController.text.length < 4
            ? null // disable the button when pin isn't complete
            : () async {
                setState(() {
                  status = ActivationStatus.activating;
                });

                var (:cramkey, :errorMessage) = await util.verifyActivation(
                  atsign: widget.atSign,
                  otp: pinController.text,
                );

                if (cramkey == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.red,
                      content: Text(
                        strings.errorOtpVerificationFailed,
                      ),
                    ),
                  );
                  setState(() {
                    pinController = TextEditingController(); // controller was disposed, make a new one
                    status = ActivationStatus.otpWait;
                  });
                  return;
                }

                var result = await util.onboardFromCramKey(
                  atsign: widget.atSign,
                  cramkey: cramkey,
                  config: widget.config,
                );

                if (!mounted) return;
                Navigator.of(context).pop(result);
              },
        child: Text(strings.confirm),
      );
}
