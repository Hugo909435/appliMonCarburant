import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// OAuth client id for the Firebase "moncarburant-89937" project's Web app.
/// Required on web only: Android/iOS resolve their client id from
/// google-services.json / GoogleService-Info.plist instead.
const _webGoogleClientId =
    '567705907889-oegjqglbensq2q55ao3n86i56hldhks5.apps.googleusercontent.com';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleSignInReady = false;

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

  /// Links [account] to the current (anonymous) user so their favorites
  /// carry over, or switches to the pre-existing account and merges
  /// favorites if that Google account is already tied to a different UID
  /// (e.g. signing in again after a reinstall on a new device).
  Future<void> completeGoogleWebSignIn(GoogleSignInAccount account) async {
    final credential = GoogleAuthProvider.credential(
      idToken: account.authentication.idToken,
    );
    final currentUser = FirebaseAuth.instance.currentUser;
    try {
      await currentUser?.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'credential-already-in-use') rethrow;
      await _switchToExistingGoogleAccount(credential, currentUser);
    }
  }

  Future<void> _switchToExistingGoogleAccount(
    OAuthCredential credential,
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

  /// Detaches the Google identity and returns to a fresh anonymous session.
  /// Favorites stay attached to the Google account and reappear on the next
  /// sign-in with it.
  Future<void> signOutOfGoogle() async {
    await FirebaseAuth.instance.signOut();
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signInAnonymously();
  }

  bool isLinkedWithGoogle(User? user) =>
      user?.providerData.any((p) => p.providerId == 'google.com') ?? false;
}
