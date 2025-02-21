import 'package:flutter/material.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/custom_container.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class BackupKeyAlertDialog extends StatelessWidget {
  const BackupKeyAlertDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sizes.p10),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            dense: false,
            title: const Text(
              'Backup atKeys',
              softWrap: false,
            ),
            leading: Icon(PhosphorIcons.download()),
            trailing: const Text(
              'Recommended',
              style: TextStyle(color: AppColor.primaryColor),
            ),
          ),
          const CustomContainer.background(
            child: Text(
              'Your atKeys (cryptographic keys) will be used to pair your atSign with this and other devices in the future. \n\n If you don\'t save your atKeys now, you can do so anytime from the Settings menu.',
            ),
          ),
          gapH10,
          CustomContainer.background(
              child: Column(
            children: [
              ListTile(
                leading: Icon(
                  PhosphorIcons.info(),
                  color: AppColor.primaryColor,
                ),
                title: const Text('What is an atKey?', style: TextStyle(color: AppColor.primaryColor)),
                trailing: Icon(
                  PhosphorIcons.caretDown(),
                  color: AppColor.primaryColor,
                ),
              ),
            ],
          ))
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('OK'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Back Up Now'),
        ),
      ],
    );
  }
}
