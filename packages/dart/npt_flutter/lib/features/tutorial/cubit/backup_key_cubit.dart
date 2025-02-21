import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/tutorial/repository/backup_key_repository.dart';

class BackupKeyCubit extends Cubit<bool> {
  BackupKeyCubit() : super(false);

  Future<void> getBackupKeyStatus() async {
    final result = await TutorialRepository().getBackupKeyStatus();
    emit(result);
    App.log('BackupKeyCubit: getBackupKeyStatus: $result'.loggable);
  }

  Future<void> putBackupKeyStatus(bool status) async {
    final result = await TutorialRepository().putBackupKeyStatus(status);
    emit(result);
    App.log('BackupKeyCubit: getBackupKeyStatus: $result'.loggable);
  }
}
