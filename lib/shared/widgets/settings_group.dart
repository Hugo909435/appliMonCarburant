import 'package:flutter/material.dart';

/// Petit titre de section, au-dessus d'une carte ou d'un groupe de réglages.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(letterSpacing: -0.1),
      ),
    );
  }
}

/// Lignes de réglage réunies dans une même carte, séparées par un filet
/// discret — plutôt qu'une pile de lignes tracées sur le fond.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 60),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Une ligne de [SettingsGroup] : icône dans une pastille, titre, sous-titre
/// et chevron.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      shape: const RoundedRectangleBorder(),
      contentPadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 19, color: scheme.onSurface),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: scheme.onSurface.withValues(alpha: 0.4),
      ),
      onTap: onTap,
    );
  }
}
