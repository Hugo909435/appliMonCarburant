import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/stations_provider.dart';

/// Petite gélule posée sur la carte qui dit où en sont les prix : mise à
/// jour en cours, hors ligne, ou échec du dernier téléchargement. Invisible
/// quand tout est à jour. Un toucher explique ce qui se passe.
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(stationsSyncProvider);
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: sync == StationsSync.idle
            ? const SizedBox.shrink()
            : Padding(
                key: ValueKey(sync),
                padding: const EdgeInsets.only(bottom: 8),
                child: _Pill(sync: sync, onTap: () => _explain(context, ref)),
              ),
      ),
    );
  }

  void _explain(BuildContext context, WidgetRef ref) {
    // Relu au toucher : l'état a pu changer depuis le dernier rendu.
    final sync = ref.read(stationsSyncProvider);
    final since = formatRelativeDate(ref.read(lastUpdateProvider));
    final (message, retry) = switch (sync) {
      StationsSync.updating => (
        'Téléchargement des derniers prix publiés par le gouvernement. '
            'Les prix affichés (${since.toLowerCase()}) seront remplacés '
            'dans quelques secondes.',
        false,
      ),
      StationsSync.offline => (
        'Pas de connexion internet. Les prix affichés datent du dernier '
            'téléchargement (${since.toLowerCase()}) et se mettront à jour '
            'tout seuls dès que le réseau reviendra.',
        false,
      ),
      StationsSync.failed => (
        'Les derniers prix n\'ont pas pu être téléchargés. Les prix '
            'affichés datent de la dernière mise à jour '
            '(${since.toLowerCase()}). Nouvel essai automatique dans '
            'quelques minutes.',
        true,
      ),
      StationsSync.idle => ('Prix à jour (${since.toLowerCase()}).', false),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          action: retry
              ? SnackBarAction(
                  label: 'Réessayer',
                  onPressed: () =>
                      ref.read(stationsProvider.notifier).refresh(),
                )
              : null,
        ),
      );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.sync, required this.onTap});

  final StationsSync sync;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (Widget leading, String label, Color color) = switch (sync) {
      StationsSync.updating => (
        const SizedBox.square(
          dimension: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.8,
            color: AppColors.primary,
          ),
        ),
        'Mise à jour des prix…',
        AppColors.primary,
      ),
      StationsSync.offline => (
        const Icon(Icons.cloud_off_rounded, size: 15, color: AppColors.bad),
        'Hors ligne',
        AppColors.bad,
      ),
      _ => (
        const Icon(Icons.sync_problem_rounded, size: 15, color: AppColors.bad),
        'Prix non mis à jour',
        AppColors.bad,
      ),
    };
    return Center(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  leading,
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: color, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
