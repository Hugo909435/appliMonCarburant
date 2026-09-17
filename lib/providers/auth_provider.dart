import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/platform_support.dart';
import '../data/services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final currentUserProvider = StreamProvider<User?>((ref) {
  if (!isFirebaseSupported) return const Stream<User?>.empty();
  return FirebaseAuth.instance.authStateChanges();
});

/// Fire-and-forget: kicks off anonymous sign-in (and Google Sign-In init)
/// as soon as the app starts, without blocking the first frame.
final authBootstrapProvider = FutureProvider<void>((ref) async {
  if (!isFirebaseSupported) return;
  await ref.read(authServiceProvider).bootstrap();
});
