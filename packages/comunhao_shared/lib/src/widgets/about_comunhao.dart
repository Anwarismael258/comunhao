import 'package:flutter/material.dart';

const comunhaoVersionName = '1.0.0';
const comunhaoBuildNumber = '1';
const comunhaoReleaseDate = 'Julho de 2026';
const comunhaoCompanyName = 'DeliGo Triunfal, Lda.';
const comunhaoLocation = 'Maputo • Moçambique';
const comunhaoPrimaryContact = 'Anwar Abubacar Ismael';
const comunhaoContacts = '+258 84 113 0015 • +258 87 768 8695';

class ComunhaoFooter extends StatelessWidget {
  const ComunhaoFooter({
    this.compact = false,
    super.key,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compact ? 8 : 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Comunhão v$comunhaoVersionName',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Powered by $comunhaoCompanyName',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 4),
            Text(
              '© 2026 $comunhaoCompanyName. Todos os direitos reservados.',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ComunhaoAboutPage extends StatelessWidget {
  const ComunhaoAboutPage({
    this.churchName,
    this.churchLogoUrl,
    super.key,
  });

  final String? churchName;
  final String? churchLogoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cleanChurch = churchName?.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: churchLogoUrl?.trim().isNotEmpty == true
                      ? NetworkImage(churchLogoUrl!)
                      : null,
                  child: churchLogoUrl?.trim().isNotEmpty == true
                      ? null
                      : Icon(
                          Icons.church_outlined,
                          color: theme.colorScheme.onPrimaryContainer,
                          size: 38,
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Comunhão',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (cleanChurch != null && cleanChurch.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Igreja: $cleanChurch',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Versão: $comunhaoVersionName (Build $comunhaoBuildNumber)',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _AboutTile(
            icon: Icons.business_outlined,
            title: 'Desenvolvido e mantido por',
            subtitle: comunhaoCompanyName,
          ),
          const _AboutTile(
            icon: Icons.calendar_today_outlined,
            title: 'Data da versão',
            subtitle: comunhaoReleaseDate,
          ),
          const _AboutTile(
            icon: Icons.person_outline,
            title: 'Contacto',
            subtitle: '$comunhaoPrimaryContact\n$comunhaoContacts',
          ),
          const _AboutTile(
            icon: Icons.location_on_outlined,
            title: 'Localização',
            subtitle: comunhaoLocation,
          ),
          const _AboutTile(
            icon: Icons.verified_outlined,
            title: 'Direitos',
            subtitle:
                '© 2026 DeliGo Triunfal, Lda.\nTodos os direitos reservados.',
          ),
          const _AboutTile(
            icon: Icons.code_outlined,
            title: 'Licenças Open Source',
            subtitle:
                'O Comunhão usa tecnologias open source licenciadas pelos respetivos autores.',
          ),
          const SizedBox(height: 16),
          const ComunhaoFooter(),
        ],
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
