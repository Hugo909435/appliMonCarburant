import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// OAuth client id for the Firebase "moncarburant-89937" project's Web app.
/// Required on web only: Android and iOS resolve their client id from
/// google-services.json / GoogleService-Info.plist instead (on iOS through
/// the GIDClientID key, filled in by tool/ios_apply_google_config.sh).
const _webGoogleClientId =
    '567705907889-oegjqglbensq2q55ao3n86i56hldhks5.apps.googleusercontent.com';

/// Identity providers the app can attach to an account, in addition to the
/// anonymous session everyone starts with.
enum SignInProvider {
  google('google.com', 'Google'),
  apple('apple.com', 'Apple');

  const SignInProvider(this.id, this.label);

  /// Firebase's `providerId`.
  final String id;

  /// Name shown to the user.
  final String label;
}

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleSignInReady = false;

  /// Whether "Sign in with Apple" can be offered here. Apple's App Store
  /// guideline 4.8 only applies to Apple platforms, and the native flow only
  /// exists there — elsewhere it would mean a web redirect nobody asked for.
  static bool get isAppleSignInSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Signs in anonymously if needed, and gets Google Sign-In ready for later
  /// use. Called once at app startup; never blocks the UI on failure.
  Future<void> bootstrap() async {
    try {
      await _ensureGoogleSignInInitialized();
    } catch (e) {
      debugPrint('Initialisation Google Sign-In échouée: $e');
    }
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInReady) return;
    await _googleSignIn.initialize(
      clientId: kIsWeb ? _webGoogleClientId : null,
    );
    _googleSignInReady = true;
  }

  /// Web only: the rendered Google button drives sign-in itself and reports
  /// completion through this stream (see google_signin_web_button.dart).
  Stream<GoogleSignInAuthenticationEvent> get googleAuthEvents =>
      _googleSignIn.authenticationEvents;

  /// Mobile: triggers the interactive Google sign-in UI directly.
  Future<void> signInWithGoogleInteractive() async {
    final account = await _googleSignIn.authenticate();
    await completeGoogleWebSignIn(account);
  }

  /// Attaches [account] (from either the web button or the mobile flow) to
  /// the current session.
  Future<void> completeGoogleWebSignIn(GoogleSignInAccount account) async {
    await _linkOrSwitch(
      GoogleAuthProvider.credential(idToken: account.authentication.idToken),
    );
  }

  /// Native "Sign in with Apple". Only call where [isAppleSignInSupported].
  Future<void> signInWithApple() async {
    // Apple signs the nonce into the identity token; Firebase re-hashes the
    // raw value and compares. Without it the token could be replayed.
    final rawNonce = _newNonce();
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
    );

    await _linkOrSwitch(
      OAuthProvider(
        SignInProvider.apple.id,
      ).credential(idToken: appleCredential.identityToken, rawNonce: rawNonce),
    );

    // Apple ne transmet le nom qu'à la toute première autorisation : s'il
    // n'est pas enregistré maintenant, il est définitivement perdu.
    final givenName = appleCredential.givenName;
    final familyName = appleCredential.familyName;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null &&
        (user.displayName ?? '').isEmpty &&
        (givenName != null || familyName != null)) {
      final name = [givenName, familyName].whereType<String>().join(' ').trim();
      if (name.isNotEmpty) {
        await user.updateDisplayName(name);
      }
    }
  }

  /// Links [credential] to the current (anonymous) user so their favorites
  /// carry over, or switches to the pre-existing account and merges favorites
  /// if that identity is already tied to a different UID (e.g. signing in
  /// again after a reinstall on a new device).
  Future<void> _linkOrSwitch(AuthCredential credential) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    try {
      await currentUser?.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'credential-already-in-use') rethrow;
      await _switchToExistingAccount(credential, currentUser);
    }
  }

  Future<void> _switchToExistingAccount(
    AuthCredential credential,
    User? abandonedUser,
  ) async {
    final abandonedUid = abandonedUser?.uid;
    var abandonedFavorites = const <String>{};
    if (abandonedUid != null) {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(abandonedUid)
          .get();
      abandonedFavorites =
          ((snap.data()?['favoriteStationIds'] as List?) ?? const [])
              .cast<String>()
              .toSet();
    }

    await FirebaseAuth.instance.signInWithCredential(credential);
    final newUid = FirebaseAuth.instance.currentUser!.uid;

    if (abandonedFavorites.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(newUid).set({
        'favoriteStationIds': FieldValue.arrayUnion(
          abandonedFavorites.toList(),
        ),
      }, SetOptions(merge: true));
    }
    if (abandonedUid != null && abandonedUid != newUid) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(abandonedUid)
          .delete();
    }
  }

  /// Detaches the federated identity and returns to a fresh anonymous
  /// session. Favorites stay attached to the account and reappear on the next
  /// sign-in with it.
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      // Apple has no equivalent "sign out" to call, and Google throws if it
      // was never initialized — neither should keep the user signed in.
      debugPrint('Déconnexion Google ignorée: $e');
    }
    await FirebaseAuth.instance.signInAnonymously();
  }

  /// The provider backing [user]'s account, or null for an anonymous session.
  SignInProvider? providerOf(User? user) {
    for (final provider in SignInProvider.values) {
      if (user?.providerData.any((p) => p.providerId == provider.id) ?? false) {
        return provider;
      }
    }
    return null;
  }

  /// Whether favorites are synced to a real account rather than to this
  /// install's throwaway anonymous session.
  bool isSignedIn(User? user) => providerOf(user) != null;

  /// Cryptographically random string used to bind the Apple identity token to
  /// this one sign-in attempt.
  String _newNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }
}
