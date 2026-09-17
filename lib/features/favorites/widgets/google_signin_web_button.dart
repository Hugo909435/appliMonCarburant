import 'package:flutter/widgets.dart';

import 'google_signin_web_button_stub.dart'
    if (dart.library.html) 'google_signin_web_button_web.dart'
    as platform;

/// On web, the Google Identity Services SDK requires its own rendered
/// button (returns null on other platforms, where a normal button that
/// calls `authenticate()` is used instead).
Widget? buildGoogleWebButton() => platform.buildGoogleWebButton();
