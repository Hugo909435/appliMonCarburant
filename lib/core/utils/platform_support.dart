import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// True on native Windows desktop, where Firebase is not initialized.
bool get isWindowsDesktop => !kIsWeb && Platform.isWindows;

/// True everywhere Firebase Auth/Firestore are wired up (Android, iOS, Web).
bool get isFirebaseSupported => !isWindowsDesktop;

/// True where Crashlytics has a native implementation. It has none on the web
/// or on Windows, and calling it there throws at startup.
bool get isCrashReportingSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);
