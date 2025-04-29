import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/onboarding/onboarding.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';
import 'package:npt_flutter/features/onboarding/widgets/at_directory_selector.dart';
import 'package:npt_flutter/features/onboarding/widgets/atsign_selector.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/form_validator.dart';
import 'package:npt_flutter/widgets/custom_container.dart';

class OnboardingDialog extends StatelessWidget {
  const OnboardingDialog({required this.options, super.key});
  final Map<String, AtsignInformation> options;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width * 0.50;
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sizes.p10),
      ),
      content: Padding(
        padding: const EdgeInsets.all(Sizes.p20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: width,
              child: CustomContainer.background(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(strings.selectorTitleAtsign),
                    gapH16,
                    AtsignSelector(
                      options: options,
                    ),
                    gapH16,
                    Text(strings.selectorTitleRootDomain),
                    AtDirectorySelector(
                      options: options,
                    ),
                  ],
                ),
              ),
            ),
            gapH10,
            BlocBuilder<OnboardingCubit, OnboardingState>(builder: (context, state) {
              return SizedBox(
                width: width,
                child: CustomContainer.background(
                    child: Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                      },
                      child: Text(strings.cancel),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: FormValidator.validateRequiredAtsignField(state.atSign) == null
                          ? () {
                              Navigator.of(context).pop(true);
                            }
                          : null,
                      child: Text(strings.next),
                    ),
                  ],
                )),
              );
            })
          ],
        ),
      ),
    );
  }
}
