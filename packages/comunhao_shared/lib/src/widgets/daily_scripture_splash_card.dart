import 'package:flutter/material.dart';

import '../models/daily_scripture_content.dart';
import '../repositories/daily_scripture_repository.dart';

class DailyScriptureSplashCard extends StatefulWidget {
  const DailyScriptureSplashCard({
    super.key,
    this.repository,
    this.churchId,
    this.personName,
    this.logoAssetPath,
    this.compact = false,
  });

  final DailyScriptureRepository? repository;
  final String? churchId;
  final String? personName;
  final String? logoAssetPath;
  final bool compact;

  @override
  State<DailyScriptureSplashCard> createState() =>
      _DailyScriptureSplashCardState();
}

class _DailyScriptureSplashCardState extends State<DailyScriptureSplashCard> {
  late final DailyScriptureRepository _repository;
  late Future<DailyScriptureContent> _future;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DailyScriptureRepository();
    _future = _repository.fetchToday(churchId: widget.churchId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DailyScriptureContent>(
      future: _future,
      builder: (context, snapshot) {
        final content = snapshot.data;
        final loading = snapshot.connectionState != ConnectionState.done;
        final image = _imageForDate(content?.contentDate ?? DateTime.now());

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  image,
                  package: 'comunhao_shared',
                  fit: BoxFit.cover,
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xAA000000),
                        Color(0x77000000),
                        Color(0xDD000000),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(widget.compact ? 18 : 24),
                child: loading || content == null
                    ? _LoadingSplash(compact: widget.compact)
                    : _LoadedSplash(
                        content: content,
                        compact: widget.compact,
                        personName: widget.personName,
                        logoAssetPath: widget.logoAssetPath,
                        onRefresh: () {
                          setState(() {
                            _future = _repository.fetchToday(
                              churchId: widget.churchId,
                            );
                          });
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _imageForDate(DateTime date) {
    final index =
        (date.year * 372 + date.month * 31 + date.day) % _splashImages.length;
    return _splashImages[index];
  }
}

class _LoadedSplash extends StatelessWidget {
  const _LoadedSplash({
    required this.content,
    required this.compact,
    required this.personName,
    required this.logoAssetPath,
    required this.onRefresh,
  });

  final DailyScriptureContent content;
  final bool compact;
  final String? personName;
  final String? logoAssetPath;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = compact ? textTheme.titleLarge : textTheme.headlineSmall;
    final greeting = _greetingFor(personName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (logoAssetPath != null) ...[
              Image.asset(logoAssetPath!, height: 28, width: 28),
              const SizedBox(width: 8),
            ] else
              const Icon(Icons.auto_awesome_outlined, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                greeting,
                style: textTheme.labelLarge?.copyWith(color: Colors.white),
              ),
            ),
            IconButton(
              tooltip: 'Atualizar palavra',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          content.devotionalTitle,
          style: titleStyle?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          content.referenceLabel,
          style: textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '"${content.scriptureText}"',
          maxLines: compact ? 4 : 6,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(
            color: Colors.white,
            height: 1.28,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SplashChip(label: content.referenceLabel),
            _SplashChip(label: content.translationLabel),
            if (content.isCampaignOverride)
              const _SplashChip(label: 'campanha da igreja'),
            if (content.isFallback) const _SplashChip(label: 'cache/fallback'),
          ],
        ),
        if (!compact) ...[
          const SizedBox(height: 14),
          _SplashDetail(
            icon: Icons.psychology_alt_outlined,
            title: 'Reflexão',
            body: content.devotionalReflection,
          ),
          _SplashDetail(
            icon: Icons.flag_outlined,
            title: 'Desafio',
            body: content.practicalApplication,
          ),
          _SplashDetail(
            icon: Icons.volunteer_activism_outlined,
            title: 'Oração',
            body: content.prayer,
          ),
          if (content.meditationQuestion.isNotEmpty)
            _SplashDetail(
              icon: Icons.help_outline,
              title: 'Pergunta',
              body: content.meditationQuestion,
            ),
          if (content.readingPlan.isNotEmpty)
            _SplashDetail(
              icon: Icons.menu_book_outlined,
              title: 'Plano de leitura',
              body: content.readingPlan,
            ),
        ] else ...[
          const SizedBox(height: 12),
          Text(
            content.devotionalSummary,
            style: textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            content.practicalApplication,
            style: textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ],
    );
  }

  String _greetingFor(String? name) {
    final cleanName = name?.trim();
    final firstName = cleanName == null || cleanName.isEmpty
        ? null
        : cleanName.split(RegExp(r'\s+')).first;
    final genericName = firstName == null ||
        const {'membro', 'utilizador', 'usuario', 'user'}
            .contains(firstName.toLowerCase());
    final suffix = genericName ? '' : ', $firstName';
    return 'A paz do Senhor$suffix! Palavra do dia';
  }
}

class _SplashDetail extends StatelessWidget {
  const _SplashDetail({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    if (body.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white, height: 1.35),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingSplash extends StatelessWidget {
  const _LoadingSplash({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: compact ? 180 : 260),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

class _SplashChip extends StatelessWidget {
  const _SplashChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xCCFFFFFF),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

const _splashImages = <String>[
  'assets/splash/aaron-burden-ia0Zxx_sDr8-unsplash.jpg',
  'assets/splash/aaron-burden-lPCu8HnGU2E-unsplash.jpg',
  'assets/splash/aaron-burden-Ncn1jiEe-Wc-unsplash.jpg',
  'assets/splash/adrianna-geo-1rBg5YSi00c-unsplash.jpg',
  'assets/splash/alessandro-bellone-rvJBpwEX-1Y-unsplash.jpg',
  'assets/splash/arleen-wiese-2vbhN2Yjb3A-unsplash.jpg',
  'assets/splash/bisakha-datta-ojs3qF7ba0o-unsplash.jpg',
  'assets/splash/bro-takes-photos-O6khX6-XozY-unsplash.jpg',
  'assets/splash/bruno-van-der-kraan-v2HgNzRDfII-unsplash.jpg',
  'assets/splash/casey-horner-4rDCa5hBlCs-unsplash.jpg',
  'assets/splash/chad-greiter--0gBnnMdQPw-unsplash.jpg',
  'assets/splash/davide-cantelli-H3giJcTw__w-unsplash.jpg',
  'assets/splash/debby-hudson-sgdyBq6kheQ-unsplash.jpg',
  'assets/splash/diana-vargas-ZySVEbGBNxA-unsplash.jpg',
  'assets/splash/edwin-andrade-6liebVeAfrY-unsplash.jpg',
  'assets/splash/ivan-diaz-aMBhrrveocw-unsplash.jpg',
  'assets/splash/james-kovin-ITiJrBI3XnE-unsplash.jpg',
  'assets/splash/james-PT-gOmCUlCY-unsplash.jpg',
  'assets/splash/jeremy-bishop-EwKXn5CapA4-unsplash.jpg',
  'assets/splash/johannes-andersson-UCd78vfC8vU-unsplash.jpg',
  'assets/splash/jonny-swales-fIDIgxZpdSM-unsplash.jpg',
  'assets/splash/karl-fredrickson-JRsZWmRd_Ws-unsplash.jpg',
  'assets/splash/kevin-mueller-8IbeGOj9AGA-unsplash.jpg',
  'assets/splash/keyur-nandaniya-ywPqgpKsXls-unsplash.jpg',
  'assets/splash/mads-schmidt-rasmussen-v0PWN7Z38ag-unsplash.jpg',
  'assets/splash/mariola-grobelska-8a7ZTFKax_I-unsplash.jpg',
  'assets/splash/matthew-stephenson-4TvNUd3nnA8-unsplash.jpg',
  'assets/splash/matthew-stephenson-QT7bP7tMehU-unsplash.jpg',
  'assets/splash/neal-e-johnson-oQC81OHcl4Q-unsplash.jpg',
  'assets/splash/pisit-heng-ci1F55HaVWQ-unsplash.jpg',
  'assets/splash/rob-potter-fJ8gSvKDHUo-unsplash.jpg',
  'assets/splash/rob-potter-HZflGaOEzkI-unsplash.jpg',
  'assets/splash/samuel-mcgarrigle-GVRRtaLj3LU-unsplash.jpg',
  'assets/splash/tom-barrett-hgGplX3PFBg-unsplash.jpg',
  'assets/splash/v2osk-1Z2niiBPg5A-unsplash.jpg',
  'assets/splash/vaishakh-pillai-CvWbabexORY-unsplash.jpg',
];
