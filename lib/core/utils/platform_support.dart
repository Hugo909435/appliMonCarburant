import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// True on native Windows desktop, where Firebase is not initialized.
bool get isWindowsDesktop => !kIsWeb && Platform.isWindows;

/// True everywhere Firebase Auth/Firestore are wired up (Android, iOS, Web).
bool get isFirebaseSupported => !isWindowsDesktop;
