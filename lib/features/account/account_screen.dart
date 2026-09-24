import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../data/services/auth_service.dart';
import '../../providers/app_info_provider.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/settings_group.dart';
import '../favorites/widgets/google_signin_web_button.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _webAuthSub;
  // Built once: google_sign_in_web's renderButton() mounts a fresh platform
  // view each call, so calling it again on every build() stacks duplicates.
  late final Widget? _webButton = kIsWeb ? buildGoogleWebButton() : null;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _webAuthSub = ref
          .read(authServiceProvider)
          .googleAuthEvents
          .listen(_onWebAuthEvent);
    }
  }

  Future<void> _onWebAuthEvent(GoogleSignInAuthenticationEvent event) async {
    if (event is! GoogleSignInAuthenticationEventSignIn) return;
    try {
      await ref.read(authServiceProvider).completeGoogleWebSignIn(event.user);
    } catch (e) {
      if (mounted) setState(() => _error = 'La connexion a échoué. Réessayez.');
    }
  }

  /// Runs [action] with the spinner on, turning any failure into a message
  /// the user can act on. A cancelled sign-in is silent: the user chose it.
  Future<void> _runSignIn(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } on SignInWithAppleAuthorizationException catch (e) {
      if (mounted && e.code != AuthorizationErrorCode.canceled) {
        setState(() => _error = 'La connexion a échoué. Réessayez.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'La connexion a échoué. Réessayez.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _webAuthSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authServiceProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final provider = auth.providerOf(user);

    return Scaffold(
      appBar: AppBar(title: const Text('Compte')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: provider != null
                    ? _linkedContent(context, user, provider)
                    : _signInContent(context),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const SectionTitle('Réglages'),
          SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.directions_car_outlined,
                title: 'Mon véhicule',
                subtitle: 'Consommation et taille du plein',
                onTap: () => context.push('/vehicule'),
              ),
              SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Confidentialité',
                subtitle: 'Données collectées et vos droits',
                onTap: () => context.push('/confidentialite'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              ref.watch(appVersionProvider).valueOrNull ?? '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _linkedContent(
    BuildContext context,
    User? user,
    SignInProvider provider,
  ) {
    final name = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : user?.email ?? 'Compte ${provider.label}';
    return [
      Row(
        children: [
          _Avatar(initial: name.characters.first.toUpperCase()),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  'Connecté avec ${provider.label}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      const Text(
        'Vos favoris sont synchronisés sur tous les appareils connectés '
        'avec ce compte.',
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: () => ref.read(authServiceProvider).signOut(),
        icon: const Icon(Icons.logout),
        label: const Text('Se déconnecter'),
      ),
    ];
  }

  List<Widget> _signInContent(BuildContext context) {
    final auth = ref.read(authServiceProvider);
    return [
      const Align(alignment: Alignment.centerLeft, child: _Avatar()),
      const SizedBox(height: 16),
      Text(
        'Retrouvez vos favoris partout',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 4),
      const Text(
        "Vous utilisez l'app sans compte. Connectez-vous pour retrouver vos "
        'favoris sur tous vos appareils.',
      ),
      const SizedBox(height: 20),
      if (AuthService.isAppleSignInSupported) ...[
        // Apple impose l'aspect de son bouton (forme, logo, libellé) et veut
        // le voir au moins aussi en évidence que les connexions tierces —
        // d'où sa place en premier.
        SignInWithAppleButton(
          text: 'Se connecter avec Apple',
          height: 48,
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          style: Theme.of(context).brightness == Brightness.dark
              ? SignInWithAppleButtonStyle.white
              : SignInWithAppleButtonStyle.black,
          onPressed: _loading ? () {} : () => _runSignIn(auth.signInWithApple),
        ),
        const SizedBox(height: 12),
      ],
      if (_webButton != null)
        _webButton
      else
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _loading
                ? null
                : () => _runSignIn(auth.signInWithGoogleInteractive),
            icon: const Icon(Icons.login),
            label: const Text('Continuer avec Google'),
          ),
        ),
      if (_loading) ...[
        const SizedBox(height: 16),
        const Center(child: CircularProgressIndicator()),
      ],
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
    ];
  }
}

/// Pastille ronde du profil : l'initiale du compte, ou une silhouette tant
/// que l'on n'est pas connecté.
class _Avatar extends StatelessWidget {
  const _Avatar({this.initial});

  final String? initial;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 26,
      backgroundColor: initial == null
          ? scheme.surfaceContainer
          : scheme.primary,
      child: initial == null
          ? Icon(Icons.person_rounded, color: scheme.onSurface, size: 26)
          : Text(
              initial!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}
