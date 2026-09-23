import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Version affichée en bas de l'écran Compte : c'est la première chose à
/// demander à un utilisateur qui signale un problème, autant qu'il puisse la
/// lire sans quitter l'app.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return 'Version ${info.version} (${info.buildNumber})';
});
