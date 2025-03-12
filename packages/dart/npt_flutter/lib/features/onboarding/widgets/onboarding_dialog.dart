import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/svg.dart';
import 'package:npt_flutter/features/onboarding/onboarding.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';
import 'package:npt_flutter/features/onboarding/widgets/at_directory_selector.dart';
import 'package:npt_flutter/features/onboarding/widgets/atsign_selector.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/form_validator.dart';
import 'package:npt_flutter/widgets/custom_container.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class OnboardingDialog extends StatefulWidget {
  const OnboardingDialog({required this.options, super.key});
  final Map<String, AtsignInformation> options;

  @override
  State<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<OnboardingDialog> {
  bool visibility = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width * 0.60;
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sizes.p10),
      ),
      content: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(Sizes.p20),
          child: Column(
            spacing: Sizes.p10,
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomContainer.background(
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.selectorTitleAtsign,
                      style: titleStyle!.copyWith(color: Colors.black),
                    ),
                    Text(
                      strings.selectorSubTitleAtsign,
                    ),
                    gapH16,
                    AtsignSelector(
                      options: widget.options,
                    ),
                  ],
                ),
              ),
              CustomContainer.background(
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          PhosphorIcons.info(),
                          color: AppColor.primaryColor,
                        ),
                        gapW14,
                        Text(strings.whatIsClientAtsign, style: const TextStyle(color: AppColor.primaryColor)),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              visibility = !visibility;
                            });
                          },
                          icon: Icon(PhosphorIcons.caretDown()),
                          color: AppColor.primaryColor,
                        )
                      ],
                    ),
                    visibility ? gapH14 : gap0,
                    Visibility(
                      maintainAnimation: true,
                      maintainState: true,
                      visible: visibility,
                      child: Row(
                        children: [
                          CustomContainer.foreground(
                            padding: Sizes.p16,
                            width: width / 2,
                            child: Column(
                              children: [
                                Text(
                                  strings.clientAtsignDescription,
                                  textAlign: TextAlign.center,
                                  style: titleStyle.copyWith(
                                      fontSize: Sizes.p18, color: Colors.black, fontWeight: FontWeight.w500),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(strings.myNoPortsMsg),
                                    IconButton(
                                      icon: Icon(
                                        PhosphorIcons.arrowUpRight(),
                                        color: AppColor.primaryColor,
                                      ),
                                      onPressed: () {},
                                    ),
                                  ],
                                ),
                                Material(
                                  elevation: 5,
                                  child: SvgPicture.asset(
                                    'assets/my_noports.svg',
                                    height: 70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              CustomContainer.background(
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.selectorTitleRootDomain,
                      style: titleStyle.copyWith(color: Colors.black),
                    ),
                    Text(strings.selectorSubTitleRootDomain),
                    gapH16,
                    AtDirectorySelector(
                      options: widget.options,
                    ),
                  ],
                ),
              ),
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
      ),
    );
  }
}
