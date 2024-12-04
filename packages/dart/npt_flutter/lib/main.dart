import 'dart:io';

import 'package:flutter/material.dart';
import 'package:npt_flutter/constants.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var windowOptions = WindowOptions(
    title: "NoPorts Desktop",
    minimumSize: Constants.kWindowsMinWindowSize,
    skipTaskbar: Platform.isWindows,
    alwaysOnTop: true,
  );
  windowManager.ensureInitialized();
  windowManager.waitUntilReadyToShow(windowOptions);
  runApp(const App());
}
