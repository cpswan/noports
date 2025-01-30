import 'package:at_auth/at_auth.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_onboarding_flutter/at_onboarding_services.dart';
import 'package:flutter/material.dart';
import 'package:npt_flutter/constants.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

enum OnboardingStatus {
  preparing,
  otpRequired,
  pendingApproval,
  success,
  denied,
}

class OnboardingApkamDialog extends StatefulWidget {
  const OnboardingApkamDialog({
    required this.atsign,
    required this.atClientPreference,
    super.key,
  });

  final String atsign;
  final AtClientPreference atClientPreference;

  @override
  OnboardingApkamDialogState createState() => OnboardingApkamDialogState();
}

class OnboardingApkamDialogState extends State<OnboardingApkamDialog> {
  String get atsign => widget.atsign;
  AtClientPreference get atClientPreference => widget.atClientPreference;

  static const _kPinLength = 6;

  late OnboardingStatus onboardingStatus;
  late final AtAuthServiceImpl authService;
  late final TextEditingController pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    onboardingStatus = OnboardingStatus.preparing;
    authService = AtAuthServiceImpl(
      atsign,
      atClientPreference,
    );
    init();
  }

  @override
  void dispose() {
    pinController.dispose();
    super.dispose();
  }

  Future<void> _setStateOnStatus(EnrollmentStatus enrollmentStatus) async {
    switch (enrollmentStatus) {
      case EnrollmentStatus.pending:
        setState(() {
          onboardingStatus = OnboardingStatus.otpRequired;
        });
      case EnrollmentStatus.approved:
        await onApproved();
      case EnrollmentStatus.denied:
        await onDenied();
      case EnrollmentStatus.revoked:
        throw UnimplementedError();
      case EnrollmentStatus.expired:
        // TODO: Show some message about how the request has expired.
        print('Original request has expired. Submit again');
        setState(() {
          onboardingStatus = OnboardingStatus.otpRequired;
        });
    }
  }

  Future<void> init() async {
    final sentEnrollRequest = await authService.getSentEnrollmentRequest();
    debugPrint('Sent enroll request: ${sentEnrollRequest?.toJson()}');
    if (sentEnrollRequest != null) {
      // If the request has already been sent, we need to say wait for approval
      setState(() {
        onboardingStatus = OnboardingStatus.pendingApproval;
      });
    }

    final status = await authService.getFinalEnrollmentStatus();
    debugPrint('Enrollment status: $status');

    await _setStateOnStatus(status);
  }

  Future<void> onApproved() async {
    setState(() {
      onboardingStatus = OnboardingStatus.success;
    });
    // Wait for a second to show the success message
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      Navigator.of(context).pop(AtOnboardingResult.success(atsign: atsign));
    }
  }

  Future<void> onDenied() async {
    setState(() {
      onboardingStatus = OnboardingStatus.denied;
    });
    // Wait for a second to show the error message
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      Navigator.of(context).pop(AtOnboardingResult.error(message: 'Enrollment request denied'));
    }
  }

  Future<void> otpSubmit(String otp) async {
    setState(() {
      onboardingStatus = OnboardingStatus.pendingApproval;
    });

    final onboardingService = OnboardingService.getInstance();

    final enrollmentRequest = EnrollmentRequest(
      appName: 'NoPorts',
      // TODO(Zambrella): Set this is as an actual device name
      deviceName: 'DougTest', // Cannot contain spaces!!
      otp: otp,
      namespaces: {
        Constants.namespace!: 'rw',
      },
    );

    debugPrint('About to enroll with $enrollmentRequest');
    try {
      final enrollResponse = await onboardingService.enroll(
        atsign,
        enrollmentRequest,
      ); // AT0011 - Invalid OTP
      debugPrint('Enroll response: $enrollResponse');
    } catch (e, st) {
      debugPrint('Error enrolling: $e');
      debugPrint(st);
    }

    final finalStatus = await authService.getFinalEnrollmentStatus();
    debugPrint('Enrollment status: $finalStatus');

    await _setStateOnStatus(finalStatus);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: switch (onboardingStatus) {
                OnboardingStatus.preparing => const CircularProgressIndicator(
                    key: Key('preparing'),
                  ),
                OnboardingStatus.otpRequired => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Enter your OTP here...'),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 350,
                        child: PinCodeTextField(
                          appContext: context,
                          length: _kPinLength,
                          controller: pinController,
                          autoFocus: true,
                          textCapitalization: TextCapitalization.characters,
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
                            activeFillColor: Colors.white,
                            inactiveFillColor: Colors.white,
                            selectedFillColor: Colors.white,
                            selectedColor: Colors.black,
                            fieldOuterPadding: const EdgeInsets.all(4),
                          ),
                          cursorColor: Colors.black,
                          animationDuration: const Duration(milliseconds: 300),
                          enableActiveFill: true,
                          keyboardType: TextInputType.text,
                          beforeTextPaste: (text) => true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AnimatedBuilder(
                        animation: pinController,
                        builder: (context, _) {
                          return ElevatedButton(
                            onPressed: pinController.text.length == _kPinLength
                                ? () async {
                                    await otpSubmit(pinController.text);
                                  }
                                : null,
                            child: const Text('Submit OTP'),
                          );
                        },
                      ),
                    ],
                  ),
                OnboardingStatus.pendingApproval => const Column(
                    key: Key('activating'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Please approve request in app with manager keys'),
                    ],
                  ),
                OnboardingStatus.success => const Icon(
                    key: Key('success'),
                    Icons.check,
                    color: Colors.green,
                  ),
                OnboardingStatus.denied => const Icon(
                    key: Key('denied'),
                    Icons.close,
                    color: Colors.red,
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }
}
