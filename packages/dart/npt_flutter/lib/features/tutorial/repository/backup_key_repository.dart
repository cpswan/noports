import 'dart:convert';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/constants.dart';

class TutorialRepository {
  bool _fromJson(Map<String, dynamic> json) => json['status'];
  Map<String, dynamic> _toJson(bool status) => {'status': status};

  Future<bool> getBackupKeyStatus() async {
    AtClient atClient = AtClientManager.getInstance().atClient;
    String? atSign = atClient.getCurrentAtSign();
    var key = AtKey.self('key_backup.app_metadata', namespace: Constants.namespace);
    if (atSign != null) key.sharedBy(atSign);

    try {
      final value = await atClient.get(key.build());
      return _fromJson(jsonDecode(value.value));
    } catch (e) {
      App.log('[ERROR] getbackupKeyStatus() failed: $e'.loggable);
      return false;
    }
  }

  Future<bool> putBackupKeyStatus(bool status) async {
    AtClient atClient = AtClientManager.getInstance().atClient;
    String? atSign = atClient.getCurrentAtSign();
    var key = AtKey.self(
      'key_backup.app_metadata',
      namespace: Constants.namespace,
    );
    if (atSign != null) key.sharedBy(atSign);

    try {
      return await atClient.put(key.build(), jsonEncode(_toJson(status)));
    } catch (e) {
      App.log('[ERROR] getbackupKeyStatus() failed: $e'.loggable);
      return false;
    }
  }
}
