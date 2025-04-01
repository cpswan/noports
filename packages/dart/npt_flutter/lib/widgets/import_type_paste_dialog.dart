import 'package:flutter/material.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/export.dart';

class ImportTypePasteDialog extends StatefulWidget {
  const ImportTypePasteDialog({required this.profileFileType, super.key});

  final ExportableProfileFiletype profileFileType;

  @override
  State<ImportTypePasteDialog> createState() => _ImportTypePasteDialogState();
}

class _ImportTypePasteDialogState extends State<ImportTypePasteDialog> {
  final TextEditingController _controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: widget.profileFileType == ExportableProfileFiletype.json
          ? const Text("JSON Profile")
          : const Text("YAML Yaml"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: Sizes.p20,
        children: [
          widget.profileFileType == ExportableProfileFiletype.json
              ? const Text("Paste your json content here")
              : const Text("Paste your yaml content here"),
          SizedBox(
            width: Sizes.p600,
            height: Sizes.p400,
            child: TextField(
              controller: _controller,
              maxLines: 15,
              minLines: 15,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(_controller.text);
          },
          child: const Text("Create Profile"),
        ),
      ],
    );
  }
}
