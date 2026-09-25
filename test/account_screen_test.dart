import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mon_carburant_app/data/services/auth_service.dart';
import 'package:mon_carburant_app/features/account/account_screen.dart';
import 'package:mon_carburant_app/providers/app_info_provider.dart';
import 'package:mon_carburant_app/providers/auth_provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Service d'authentification de test.
///
/// Il pilote la branche affichée par [linkedTo] au lieu de fabriquer un
/// `User` Firebase : l'écran ne demande au service que *quel* fournisseur est
/// rattaché, jamais l'objet utilisateur lui-même pour décider quoi afficher.
class _FakeAuth implements AuthService {
  _FakeAuth({this.linkedTo});

  SignInProvider? linkedTo;

  /// Erreur à lever à la prochaine tentative de connexion.
  Object? failWith;

  int appleCalls = 0;
  int googleCalls = 0;
  int signOutCalls = 0;

  @override
  SignInProvider? providerOf(User? user) => linkedTo;

  @override
  bool isSignedIn(User? user) => linkedTo != null;

  @override
  Future<void> signInWithApple() async {
    appleCalls++;
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> signInWithGoogleInteractive() async {
    googleCalls++;
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> signOut() async => signOutCalls++;

  int deleteCalls = 0;

  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> ensureSession() async {}

  @override
  Future<void> bootstrap() async {}

  @override
  Future<void> completeGoogleWebSignIn(GoogleSignInAccount account) async {}

  @override
  Stream<GoogleSignInAuthenticationEvent> get googleAuthEvents =>
      const Stream.empty();
}

Future<_FakeAuth> _pumpAccount(
  WidgetTester tester, {
  SignInProvider? linkedTo,
  Object? failWith,
}) async {
  final auth = _FakeAuth(linkedTo: linkedTo)..failWith = failWith;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        // Sans Firebase, le flux réel ne produit jamais rien : on fournit une
        // session anonyme explicite pour que l'écran s'affiche tout de suite.
        currentUserProvider.overrideWith((ref) => Stream<User?>.value(null)),
        // PackageInfo passe par un canal de plateforme, absent en test.
        appVersionProvider.overrideWith((ref) async => 'Version 1.0.0 (1)'),
      ],
      child: const MaterialApp(home: AccountScreen()),
    ),
  );
  await tester.pump();
  return auth;
}

/// `TargetPlatformVariant` pose et retire la surcharge de plateforme autour du
/// corps du test. Le faire à la main dans un `tearDown` échoue : flutter_test
/// vérifie que la surcharge est nulle avant même de lancer les tearDown.
final _apple = TargetPlatformVariant.only(TargetPlatform.iOS);
final _android = TargetPlatformVariant.only(TargetPlatform.android);

void main() {
  group('règle 4.8 de l’App Store', () {
    testWidgets(
      'sur iOS, « Se connecter avec Apple » est proposé, et avant Google',
      (tester) async {
        await _pumpAccount(tester);

        final apple = find.byType(SignInWithAppleButton);
        final google = find.text('Continuer avec Google');
        expect(apple, findsOneWidget);
        expect(google, findsOneWidget);
        // Apple exige que sa connexion ne soit pas reléguée sous les autres.
        expect(
          tester.getTopLeft(apple).dy,
          lessThan(tester.getTopLeft(google).dy),
        );
      },
      variant: _apple,
    );

    testWidgets('le bouton Apple porte le libellé imposé, en français', (
      tester,
    ) async {
      await _pumpAccount(tester);

      expect(find.text('Se connecter avec Apple'), findsOneWidget);
    }, variant: _apple);

    testWidgets('hors plateformes Apple, seul Google est proposé', (
      tester,
    ) async {
      await _pumpAccount(tester);

      expect(find.byType(SignInWithAppleButton), findsNothing);
      expect(find.text('Continuer avec Google'), findsOneWidget);
    }, variant: _android);
  });

  group('session anonyme', () {
    testWidgets('l’app est présentée comme utilisable sans compte', (
      tester,
    ) async {
      await _pumpAccount(tester);

      expect(
        find.textContaining("Vous utilisez l'app sans compte"),
        findsOneWidget,
      );
      expect(find.text('Se déconnecter'), findsNothing);
    });

    testWidgets('toucher le bouton Apple déclenche la connexion', (
      tester,
    ) async {
      final auth = await _pumpAccount(tester);

      await tester.tap(find.byType(SignInWithAppleButton));
      await tester.pump();

      expect(auth.appleCalls, 1);
    }, variant: _apple);

    testWidgets('toucher le bouton Google déclenche la connexion', (
      tester,
    ) async {
      final auth = await _pumpAccount(tester);

      await tester.tap(find.text('Continuer avec Google'));
      await tester.pump();

      expect(auth.googleCalls, 1);
    }, variant: _android);
  });

  group('échecs de connexion', () {
    testWidgets('une panne affiche un message actionnable', (tester) async {
      await _pumpAccount(tester, failWith: Exception('réseau'));

      await tester.tap(find.byType(SignInWithAppleButton));
      await tester.pumpAndSettle();

      expect(find.text('La connexion a échoué. Réessayez.'), findsOneWidget);
    }, variant: _apple);

    testWidgets('un abandon volontaire n’affiche aucune erreur', (
      tester,
    ) async {
      // L'utilisateur qui ferme la feuille Apple n'a pas subi de panne :
      // lui montrer « la connexion a échoué » serait un contresens.
      await _pumpAccount(
        tester,
        failWith: const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.canceled,
          message: 'annulé par l’utilisateur',
        ),
      );

      await tester.tap(find.byType(SignInWithAppleButton));
      await tester.pumpAndSettle();

      expect(find.text('La connexion a échoué. Réessayez.'), findsNothing);
    }, variant: _apple);

    testWidgets('une erreur Apple non annulée reste signalée', (tester) async {
      await _pumpAccount(
        tester,
        failWith: const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.failed,
          message: 'échec',
        ),
      );

      await tester.tap(find.byType(SignInWithAppleButton));
      await tester.pumpAndSettle();

      expect(find.text('La connexion a échoué. Réessayez.'), findsOneWidget);
    }, variant: _apple);
  });

  group('session connectée', () {
    testWidgets('le fournisseur rattaché est nommé', (tester) async {
      await _pumpAccount(tester, linkedTo: SignInProvider.apple);

      expect(find.text('Connecté avec Apple'), findsOneWidget);
      expect(find.text('Se déconnecter'), findsOneWidget);
      expect(find.byType(SignInWithAppleButton), findsNothing);
      expect(find.text('Continuer avec Google'), findsNothing);
    });

    testWidgets('Google est nommé de la même façon', (tester) async {
      await _pumpAccount(tester, linkedTo: SignInProvider.google);

      expect(find.text('Connecté avec Google'), findsOneWidget);
    });

    testWidgets('la synchronisation des favoris est expliquée', (tester) async {
      await _pumpAccount(tester, linkedTo: SignInProvider.google);

      expect(
        find.textContaining('Vos favoris sont synchronisés'),
        findsOneWidget,
      );
    });

    testWidgets('se déconnecter appelle le service', (tester) async {
      final auth = await _pumpAccount(tester, linkedTo: SignInProvider.google);

      await tester.tap(find.text('Se déconnecter'));
      await tester.pump();

      expect(auth.signOutCalls, 1);
    });
  });

  // Règle 5.1.1(v) de l'App Store : un compte créé dans l'app doit pouvoir y
  // être supprimé.
  group('suppression du compte', () {
    testWidgets('rien n’est supprimé sans confirmation', (tester) async {
      final auth = await _pumpAccount(tester, linkedTo: SignInProvider.apple);

      await tester.tap(find.text('Supprimer mon compte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(auth.deleteCalls, 0);
    });

    testWidgets('confirmer appelle le service', (tester) async {
      final auth = await _pumpAccount(tester, linkedTo: SignInProvider.apple);

      await tester.tap(find.text('Supprimer mon compte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(auth.deleteCalls, 1);
      expect(find.text('Compte supprimé.'), findsOneWidget);
    });

    testWidgets('renoncer à confirmer son identité n’affiche aucune erreur', (
      tester,
    ) async {
      await _pumpAccount(
        tester,
        linkedTo: SignInProvider.apple,
        failWith: const AccountDeletionCancelled(),
      );

      await tester.tap(find.text('Supprimer mon compte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('La suppression a échoué'), findsNothing);
      expect(find.text('Compte supprimé.'), findsNothing);
    });

    testWidgets('une panne est signalée', (tester) async {
      await _pumpAccount(
        tester,
        linkedTo: SignInProvider.google,
        failWith: Exception('hors ligne'),
      );

      await tester.tap(find.text('Supprimer mon compte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('La suppression a échoué'), findsOneWidget);
    });
  });

  group('accès annexes', () {
    testWidgets('la politique de confidentialité est atteignable', (
      tester,
    ) async {
      // Apple exige une politique de confidentialité ; la laisser accessible
      // depuis l'app évite d'avoir à la chercher pendant la revue.
      await _pumpAccount(tester);

      expect(find.text('Confidentialité'), findsOneWidget);
      expect(find.text('Mon véhicule'), findsOneWidget);
    });

    testWidgets('la version est affichée, pour le support', (tester) async {
      await _pumpAccount(tester);
      await tester.pump();
      // Tout en bas de l'écran, sous les réglages.
      await tester.scrollUntilVisible(find.text('Version 1.0.0 (1)'), 200);

      expect(find.text('Version 1.0.0 (1)'), findsOneWidget);
    });
  });
}
