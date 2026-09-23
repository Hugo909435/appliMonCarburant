import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/auth_provider.dart';

/// Small account affordance for the Favorites tab: opens the account screen
/// where the user sees which account (if any) is linked, and can link/unlink
/// one so favorites survive a reinstall or new device.
class AccountButton extends ConsumerWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isLinked = ref.read(authServiceProvider).isSignedIn(user);

    return IconButton(
      icon: Icon(
        isLinked ? Icons.account_circle : Icons.account_circle_outlined,
      ),
      tooltip: 'Compte',
      onPressed: () => context.push('/compte'),
    );
  }
}
