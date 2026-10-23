import 'dart:async';

import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/color_utils.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/auth_flow_page.dart';
import '../features/church/data/church_repository.dart';
import '../features/church/models/church_branding.dart';
import '../features/church/models/church_member.dart';
import '../features/church/presentation/church_discovery_page.dart';
import 'app_shell.dart';
import 'theme.dart';

class ChurchApp extends StatefulWidget {
  const ChurchApp({
    super.key,
    this.churchRepository,
    this.authRepository,
  });

  final ChurchRepository? churchRepository;
  final AuthRepository? authRepository;

  @override
  State<ChurchApp> createState() => _ChurchAppState();
}

class _ChurchAppState extends State<ChurchApp> with WidgetsBindingObserver {
  static const _selectedChurchKey = 'selected_church_slug';
  static const _darkModeKey = 'member_pref_dark_mode';

  late final ChurchRepository _churchRepository;
  late final AuthRepository _authRepository;

  SharedPreferences? _preferences;
  StreamSubscription? _authSubscription;
  RealtimeChannel? _realtimeChannel;

  ChurchBranding? _selectedChurch;
  ChurchMember? _currentMember;
  bool _bootstrapped = false;
  bool _showPoweredBy = true;
  bool _darkMode = false;
  String? _bootstrapError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _churchRepository = widget.churchRepository ?? SupabaseChurchRepository();
    _authRepository = widget.authRepository ?? SupabaseAuthRepository();

    _authSubscription = _authRepository.authStateChanges.listen((_) async {
      await _syncChurchFromState();
    });
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showPoweredBy = false);
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _disposeRealtime();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncChurchFromState());
    }
  }

  Future<void> _bootstrap() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      _darkMode = _preferences?.getBool(_darkModeKey) ?? false;
      await _syncChurchFromState();
    } catch (error) {
      _bootstrapError = '$error';
    } finally {
      if (mounted) {
        setState(() {
          _bootstrapped = true;
        });
      }
    }
  }

  Future<void> _syncChurchFromState() async {
    try {
      final user = _authRepository.currentUser;
      ChurchBranding? church;
      ChurchMember? member;

      if (user != null) {
        // This RPC can only grant the baseline platform member role for the
        // authenticated account; church roles remain managed server-side.
        try {
          await Supabase.instance.client.rpc('ensure_comunhao_member_role');
        } catch (_) {
          // Keep existing accounts usable until the additive migration reaches
          // the configured central project.
        }
        final storedChurch = await _resolveStoredChurch();
        final metadata = user.userMetadata;
        final metadataChurchId = metadata?['church_id'] as String?;
        final metadataSlug = metadata?['church_slug'] as String?;
        if (metadataSlug != null && metadataSlug.trim().isNotEmpty) {
          church =
              await _churchRepository.fetchChurchBySlug(metadataSlug.trim());
        }
        final membershipChurches =
            await _churchRepository.fetchChurchesForUser(user.id);
        final preferredMemberships = membershipChurches
            .where((candidate) => candidate.id == storedChurch?.id)
            .toList(growable: false);
        church = (preferredMemberships.isEmpty
                ? (membershipChurches.isEmpty ? null : membershipChurches.first)
                : preferredMemberships.first) ??
            church;
        church ??= await _resolveTestChurchForKnownMember(user);
        member = await _churchRepository.fetchMemberForUser(user.id,
            churchId: church?.id);
        if (member == null &&
            church != null &&
            (metadataChurchId == church.id ||
                metadataSlug == church.slug ||
                _isKnownDeligoMember(user))) {
          member = _memberFromAuthenticatedUser(user, church);
        }
      }

      church ??= await _resolveStoredChurch();
      church ??= await _resolveDefinedChurch();

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedChurch = church;
        _currentMember = member;
        _bootstrapError = null;
      });
      _configureRealtime(
        userId: user?.id,
        churchId: church?.id,
        membershipId: member?.membershipId,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bootstrapError = '$error';
      });
    }
  }

  void _disposeRealtime() {
    final channel = _realtimeChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
      _realtimeChannel = null;
    }
  }

  void _configureRealtime({
    String? userId,
    String? churchId,
    String? membershipId,
  }) {
    if (userId == null || userId.isEmpty) {
      _disposeRealtime();
      return;
    }

    _disposeRealtime();

    final channel = Supabase.instance.client
        .channel('comunhao-access-$userId-${churchId ?? 'pending'}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'memberships',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'profile_id',
          value: userId,
        ),
        callback: (_) => unawaited(_syncChurchFromState()),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'profiles',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: userId,
        ),
        callback: (_) => unawaited(_syncChurchFromState()),
      );

    if (churchId != null && churchId.isNotEmpty) {
      channel
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'churches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: churchId,
          ),
          callback: (_) => unawaited(_syncChurchFromState()),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'church_subscriptions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => unawaited(_syncChurchFromState()),
        );
    }

    if (membershipId != null && membershipId.isNotEmpty) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'ministry_members',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'membership_id',
          value: membershipId,
        ),
        callback: (_) => unawaited(_syncChurchFromState()),
      );
    }

    channel.subscribe();
    _realtimeChannel = channel;
  }

  Future<ChurchBranding?> _resolveStoredChurch() async {
    final slug = _preferences?.getString(_selectedChurchKey);
    if (slug == null || slug.isEmpty) {
      return null;
    }
    return _churchRepository.fetchChurchBySlug(slug);
  }

  Future<ChurchBranding?> _resolveDefinedChurch() async {
    if (SupabaseConfig.churchSlug.trim().isEmpty) {
      return null;
    }
    return _churchRepository
        .fetchChurchBySlug(SupabaseConfig.churchSlug.trim());
  }

  Future<ChurchBranding?> _resolveTestChurchForKnownMember(User user) async {
    if (!_isKnownDeligoMember(user)) {
      return null;
    }
    final churches = await _churchRepository.fetchChurches(query: '877688695');
    for (final church in churches) {
      if (church.slug == 'deligo' ||
          church.phone?.replaceAll(RegExp(r'\D'), '').endsWith('877688695') ==
              true) {
        return church;
      }
    }
    return null;
  }

  bool _isKnownDeligoMember(User user) {
    final phone = user.phone ?? user.userMetadata?['phone'] as String?;
    final digits = phone?.replaceAll(RegExp(r'\D'), '') ?? '';
    return digits.endsWith('858853156');
  }

  ChurchMember _memberFromAuthenticatedUser(User user, ChurchBranding church) {
    final metadata = user.userMetadata;
    final name = ((metadata?['full_name'] as String?) ??
            (metadata?['name'] as String?) ??
            user.phone ??
            'Membro')
        .trim();
    return ChurchMember(
      membershipId: 'auth-${user.id}',
      id: user.id,
      churchId: church.id,
      fullName: name.isEmpty ? 'Membro' : name,
      role: 'member',
      status: 'active',
      memberCode: user.id.length >= 8 ? user.id.substring(0, 8) : user.id,
      phone: user.phone ?? metadata?['phone'] as String?,
    );
  }

  Future<void> _handleChurchSelected(ChurchBranding church) async {
    await _preferences?.setString(_selectedChurchKey, church.slug);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedChurch = church;
    });
  }

  Future<void> _openChurchSwitcher() async {
    final user = _authRepository.currentUser;
    if (user == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChurchSwitcherPage(
          repository: _churchRepository,
          userId: user.id,
          onChurchSelected: (church) async {
            await _handleChurchSelected(church);
            await _syncChurchFromState();
          },
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    await _authRepository.signOut();
  }

  Future<void> _deleteAccount() async {
    await _authRepository.deleteAccount();
  }

  Future<void> _setDarkMode(bool value) async {
    await _preferences?.setBool(_darkModeKey, value);
    if (!mounted) {
      return;
    }
    setState(() {
      _darkMode = value;
    });
  }

  String _membershipStatusTitle(ChurchMember member) {
    return switch (member.status) {
      'pending' => 'Solicitacao pendente',
      'invited' => 'Convite pendente',
      'suspended' => 'Acesso suspenso',
      'blocked' => 'Acesso bloqueado',
      'removed' => 'Membro removido',
      'transferred' => 'Membro transferido',
      _ => 'Sem acesso',
    };
  }

  String _membershipStatusMessage(ChurchMember member) {
    final churchName = _selectedChurch?.name;
    return switch (member.status) {
      'pending' => 'A sua solicitacao esta pendente de aprovacao pela igreja.',
      'invited' => 'Existe um convite pendente para esta igreja.',
      'suspended' => 'O seu acesso foi suspenso pela igreja.',
      'blocked' => churchName == null
          ? 'O teu acesso foi bloqueado pelo administrador da igreja.'
          : 'O teu acesso a $churchName foi bloqueado pelo administrador da igreja.',
      'removed' => churchName == null
          ? 'A tua conta foi removida desta igreja.'
          : 'A tua conta foi removida de $churchName.',
      'transferred' => churchName == null
          ? 'A tua conta foi transferida para outra igreja. Atualiza a sessao para sincronizar o novo acesso.'
          : 'A tua conta foi transferida de $churchName para outra igreja. Atualiza a sessao para sincronizar o novo acesso.',
      _ => 'Esta conta nao tem um membership ativo.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final secondaryColor = _selectedChurch?.secondaryColor;
    final theme = buildAppTheme(
      seedColor: parseHexColor(_selectedChurch?.primaryColor),
      secondaryColor: secondaryColor == null || secondaryColor.trim().isEmpty
          ? null
          : parseHexColor(secondaryColor),
    );
    final darkTheme = buildAppDarkTheme(
      seedColor: parseHexColor(_selectedChurch?.primaryColor),
      secondaryColor: secondaryColor == null || secondaryColor.trim().isEmpty
          ? null
          : parseHexColor(secondaryColor),
    );

    return MaterialApp(
      title: _selectedChurch?.appName ?? 'Comunhão Membros',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => EnvironmentBanner(
        child: _selectedChurch == null
            ? child ?? const SizedBox.shrink()
            : ChurchIdentityFrame(
                primaryColor: parseHexColor(_selectedChurch?.primaryColor),
                secondaryColor:
                    secondaryColor == null || secondaryColor.trim().isEmpty
                        ? null
                        : parseHexColor(secondaryColor),
                child: child ?? const SizedBox.shrink(),
              ),
      ),
      home: _buildHome(),
    );
  }

  String _friendlyBootstrapError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('postgrestexception') ||
        raw.contains('postgres') ||
        raw.contains('pgrst')) {
      return 'Nao foi possivel carregar os dados da Comunhao neste momento. A tua conta nao foi apagada. Toca em “Tentar novamente”; se o problema continuar, o cadastro precisa de ser sincronizado na Central.';
    }
    if (raw.contains('jwt') ||
        raw.contains('expired') ||
        raw.contains('not authenticated')) {
      return 'A tua sessao expirou. Sai da aplicacao e entra novamente com o teu telefone e palavra-passe.';
    }
    if (raw.contains('row-level security') ||
        raw.contains('permission denied') ||
        raw.contains('42501')) {
      return 'A conta foi reconhecida, mas ainda nao tem permissao para ler os dados da igreja. Pede ao administrador para confirmar o teu acesso.';
    }
    if (raw.contains('network') ||
        raw.contains('socket') ||
        raw.contains('timeout')) {
      return 'Nao foi possivel ligar ao servidor. Confirma a tua internet e tenta novamente.';
    }
    return 'Ocorreu um problema ao iniciar a aplicacao. Toca em “Tentar novamente”; se continuar, informa a equipa com a hora em que aconteceu.';
  }

  Widget _buildHome() {
    if (_showPoweredBy) {
      return const _LaunchScreen(poweredBy: true);
    }
    if (!_bootstrapped) {
      return const _LaunchScreen(poweredBy: false);
    }

    if (_bootstrapError != null) {
      return _StatusScreen(
        title: 'Falha ao iniciar',
        message: _friendlyBootstrapError(_bootstrapError!),
        primaryActionLabel: 'Tentar novamente',
        onPrimaryAction: _syncChurchFromState,
      );
    }

    final currentUser = _authRepository.currentUser;
    if (currentUser == null) {
      return AuthFlowPage(
        churchRepository: _churchRepository,
        authRepository: _authRepository,
        selectedChurch: _selectedChurch,
        onChurchSelected: (church) {
          _handleChurchSelected(church);
        },
      );
    }

    if (_currentMember == null) {
      return ChurchDiscoveryPage(
        repository: _churchRepository,
        onMembershipChanged: _syncChurchFromState,
        onSignOut: _signOut,
      );
    }

    if (_currentMember!.status != 'active') {
      return _StatusScreen(
        title: _membershipStatusTitle(_currentMember!),
        message: _membershipStatusMessage(_currentMember!),
        primaryActionLabel: 'Atualizar',
        onPrimaryAction: _syncChurchFromState,
        secondaryActionLabel: 'Sair',
        onSecondaryAction: _signOut,
      );
    }

    if (_selectedChurch == null) {
      return _StatusScreen(
        title: 'Sem igreja selecionada',
        message:
            'Nao foi possivel descobrir a igreja deste utilizador. Verifica o membership e o metadata no Supabase.',
        primaryActionLabel: 'Atualizar',
        onPrimaryAction: _syncChurchFromState,
        secondaryActionLabel: 'Sair',
        onSecondaryAction: _signOut,
      );
    }

    if (!_selectedChurch!.allowsMemberAccess) {
      return _StatusScreen(
        title: 'Subscricao suspensa',
        message:
            'A subscricao da sua igreja encontra-se ${_selectedChurch!.subscriptionStatusLabel.toLowerCase()}. Efetue o pagamento para reativar todos os servicos.',
        primaryActionLabel: 'Atualizar',
        onPrimaryAction: _syncChurchFromState,
        secondaryActionLabel: 'Sair',
        onSecondaryAction: _signOut,
      );
    }

    return AppShell(
      church: _selectedChurch!,
      currentMember: _currentMember!,
      repository: _churchRepository,
      darkMode: _darkMode,
      onDarkModeChanged: _setDarkMode,
      onSignOut: _signOut,
      onDeleteAccount: _deleteAccount,
      onChangeChurch: _openChurchSwitcher,
    );
  }
}

class _StatusScreen extends StatelessWidget {
  const _StatusScreen({
    required this.title,
    required this.message,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String title;
  final String message;
  final String? primaryActionLabel;
  final Future<void> Function()? onPrimaryAction;
  final String? secondaryActionLabel;
  final Future<void> Function()? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                    ),
                    if (primaryActionLabel != null ||
                        secondaryActionLabel != null)
                      const SizedBox(height: 20),
                    if (primaryActionLabel != null ||
                        secondaryActionLabel != null)
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          if (primaryActionLabel != null)
                            FilledButton(
                              onPressed: onPrimaryAction == null
                                  ? null
                                  : () => onPrimaryAction!(),
                              child: Text(primaryActionLabel!),
                            ),
                          if (secondaryActionLabel != null)
                            OutlinedButton(
                              onPressed: onSecondaryAction == null
                                  ? null
                                  : () => onSecondaryAction!(),
                              child: Text(secondaryActionLabel!),
                            ),
                        ],
                      ),
                    const SizedBox(height: 20),
                    const ComunhaoFooter(compact: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen({required this.poweredBy});

  final bool poweredBy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: poweredBy
                ? Column(
                    key: const ValueKey('powered-by'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Uma plataforma do ecossistema',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Text('DELIGO TRIUNFAL, LDA.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      const Text('Tecnologia mocambicana.'),
                    ],
                  )
                : Column(
                    key: const ValueKey('comunhao-splash'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/branding/comunhao.png', height: 110),
                      const SizedBox(height: 18),
                      Text('Comunhao',
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text('A ligar a sua comunidade...'),
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
