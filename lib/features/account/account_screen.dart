import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../providers/auth_provider.dart';
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

  Future<void> _signInMobile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).signInWithGoogleInteractive();
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
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isLinked = ref.read(authServiceProvider).isLinkedWithGoogle(user);

    return Scaffold(
      appBar: AppBar(title: const Text('Compte')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ...isLinked ? _linkedContent(context, user) : _signInContent(context),
          const SizedBox(height: 32),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.directions_car_outlined),
            title: const Text('Mon véhicule'),
            subtitle: const Text('Consommation et taille du plein'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/vehicule'),
          ),
        ],
      ),
    );
  }

  List<Widget> _linkedContent(BuildContext context, User? user) {
    return [
      Row(
        children: [
          const Icon(Icons.account_circle, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.email ?? 'Compte Google',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text('Connecté avec Google'),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      const Text(
        'Vos favoris sont synchronisés sur tous les appareils connectés '
        'avec ce compte.',
      ),
      const SizedBox(height: 24),
      OutlinedButton.icon(
        onPressed: () => ref.read(authServiceProvider).signOutOfGoogle(),
        icon: const Icon(Icons.logout),
        label: const Text('Se déconnecter'),
      ),
    ];
  }

  List<Widget> _signInContent(BuildContext context) {
    return [
      const Icon(Icons.account_circle_outlined, size: 40),
      const SizedBox(height: 16),
      const Text(
        "Vous utilisez l'app sans compte. Connectez-vous avec Google pour "
        'retrouver vos favoris sur tous vos appareils.',
      ),
      const SizedBox(height: 16),
      if (_webButton != null)
        _webButton
      else
        FilledButton.icon(
          onPressed: _loading ? null : _signInMobile,
          icon: const Icon(Icons.login),
          label: const Text('Continuer avec Google'),
        ),
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
