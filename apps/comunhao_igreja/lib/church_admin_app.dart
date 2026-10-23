import 'dart:async';

import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/web_upload_picker.dart';
import 'features/publications/presentation/church_publications_page.dart';
import 'features/members/presentation/church_members_page.dart';
import 'features/requests/presentation/church_requests_page.dart';
import 'features/finance/presentation/church_finance_page.dart';
import 'features/finance/presentation/church_subscription_page.dart';
import 'features/calendar/presentation/church_calendar_page.dart';
import 'features/community/presentation/church_community_moderation_page.dart';
import 'features/organization/presentation/church_erp_page.dart';
import 'features/publications/presentation/native_auto_media_stub.dart'
    if (dart.library.html) 'features/publications/presentation/native_auto_media_web.dart';

enum _AuthMode { signup, login }

enum _AuthStage { credentials, otp }

class ChurchAdminApp extends StatefulWidget {
  const ChurchAdminApp({
    super.key,
    this.authRepository,
    this.backofficeRepository,
    this.financeRepository,
    this.calendarRepository,
    this.operationsRepository,
  });

  final ComunhaoAuthRepository? authRepository;
  final BackofficeRepository? backofficeRepository;
  final FinanceRepository? financeRepository;
  final CalendarRepository? calendarRepository;
  final OperationsRepository? operationsRepository;

  @override
  State<ChurchAdminApp> createState() => _ChurchAdminAppState();
}

class _ChurchAdminAppState extends State<ChurchAdminApp>
    with WidgetsBindingObserver {
  static const _mediaBucket = 'pastoral-publications';
  static const _applicationBrandingBucket = 'church-application-branding';
  static const _darkModeKey = 'church_admin_pref_dark_mode';

  late final ComunhaoAuthRepository _authRepository;
  late final BackofficeRepository _backofficeRepository;
  late final FinanceRepository _financeRepository;
  late final CalendarRepository _calendarRepository;
  late final OperationsRepository _operationsRepository;

  final _signupFormKey = GlobalKey<FormState>();
  final _loginFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _applicationFormKey = GlobalKey<FormState>();
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  final _signupNameController = TextEditingController();
  final _signupChurchNameController = TextEditingController();
  final _signupPhoneController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupConfirmPasswordController = TextEditingController();
  final _loginPhoneController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  final _memberSearchController = TextEditingController();

  final _churchNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _countryController = TextEditingController(text: 'Mozambique');
  final _churchPhoneController = TextEditingController();
  final _churchEmailController = TextEditingController();
  final _logoUrlController = TextEditingController();
  final _primaryColorController = TextEditingController();
  final _secondaryColorController = TextEditingController();
  final _taglineController = TextEditingController();
  final _mpesaController = TextEditingController();
  final _emolaController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankAccountNameController = TextEditingController();
  final _bankAccountNumberController = TextEditingController();

  StreamSubscription? _authSubscription;
  RealtimeChannel? _realtimeChannel;
  Timer? _realtimeRefreshTimer;
  String? _realtimeChurchId;

  _AuthMode _authMode = _AuthMode.signup;
  _AuthStage _authStage = _AuthStage.credentials;
  String? _pendingPhone;
  String? _loadedApplicationId;
  bool _bootstrapped = false;
  bool _busy = false;
  bool _showLoginPassword = false;
  bool _showSignupPassword = false;
  bool _darkMode = false;
  bool _refreshInProgress = false;
  bool _refreshQueued = false;
  bool _suspendRealtimeRefresh = false;
  int _selectedIndex = 0;
  static const _mainNavIndexes = <int>[0, 1, 6, 2, 5, 8];
  String? _pendingCheckoutPlanCode;
  List<String> _platformRoles = const [];
  List<ChurchApplication> _applications = const [];
  List<ManagedChurch> _managedChurches = const [];
  List<ManagedMember> _churchMembers = const [];
  List<ManagedAnnouncement> _announcements = const [];
  List<ManagedCampaign> _campaigns = const [];
  List<ManagedEvent> _events = const [];
  List<PastoralPublication> _publications = const [];
  List<ManagedPrayerRequest> _prayerRequests = const [];
  List<ChurchCommunication> _communications = const [];
  List<ChurchMinistry> _ministries = const [];
  List<ChurchAsset> _assets = const [];
  List<ChurchVisitor> _visitors = const [];
  List<ChurchExpense> _expenses = const [];
  List<SubscriptionPlan> _plans = const [];
  List<ChurchSubscriptionRequest> _subscriptionRequests = const [];
  List<WalletProviderSummary> _walletDashboard = const [];
  List<WalletLedgerEntry> _walletLedger = const [];
  List<WalletWithdrawalRequest> _walletWithdrawals = const [];
  List<String> _partialLoadWarnings = const [];
  String? _loadError;

  Object? get _currentUser => _authRepository.currentUser;
  String? get _currentUserId => _authRepository.currentUser?.id;
  String? get _currentPhone => _authRepository.currentUser?.phone;
  ChurchApplication? get _activeApplication =>
      _applications.isEmpty ? null : _applications.first;
  ManagedChurch? get _managedChurch {
    return _selectManagedChurch(_managedChurches);
  }

  BuildContext get _dialogContext => _navigatorKey.currentContext ?? context;

  ManagedChurch? _selectManagedChurch(List<ManagedChurch> churches) {
    if (churches.isEmpty) {
      return null;
    }
    final sorted = [...churches]..sort((a, b) =>
        _managedChurchPriority(a).compareTo(_managedChurchPriority(b)));
    return sorted.first;
  }

  int _managedChurchPriority(ManagedChurch church) {
    var score = 100;
    final name = church.name.trim().toLowerCase();
    final slug = church.slug.trim().toLowerCase();
    final joinCode = (church.joinCode ?? '').trim().toUpperCase();
    if (name == 'igreja vida nova') {
      score -= 50;
    } else if (name == 'vida nova') {
      score -= 40;
    } else if (name.contains('vida nova')) {
      score -= 20;
    }
    if (slug == 'vida-nova' || slug == 'igreja-vida-nova') {
      score -= 30;
    }
    if (joinCode == 'VIDA123') {
      score -= 20;
    }
    if (church.subscription != null) {
      score -= 5;
    }
    return score;
  }

  ChurchSubscription? get _subscription => _managedChurch?.subscription;
  bool get _isChurchReadOnly => _subscription?.isReadOnlyForChurchAdmin == true;
  bool get _isSubscriptionLocked =>
      _subscription?.requiresPaymentForChurchAdmin == true;
  String? get _accountPhone => _currentPhone ?? _pendingPhone;
  String get _currentDisplayName {
    final profileId = _currentUserId;
    if (profileId != null) {
      for (final member in _churchMembers) {
        if (member.profileId == profileId &&
            member.fullName.trim().isNotEmpty) {
          return member.fullName.trim();
        }
      }
    }
    final pastorName = _activeApplication?.pastorName?.trim();
    if (pastorName != null && pastorName.isNotEmpty) {
      return pastorName;
    }
    return _currentPhone ?? 'pastor';
  }

  int get _activeMemberCount =>
      _churchMembers.where((member) => member.status == 'active').length;
  int get _blockedMemberCount =>
      _churchMembers.where((member) => member.status == 'blocked').length;
  int get _pastorCount => _churchMembers
      .where((member) => member.status == 'active' && member.role == 'pastor')
      .length;
  int get _upcomingEventCount =>
      _events.where((event) => event.startsAt.isAfter(DateTime.now())).length;
  int get _publishedAnnouncementCount => _announcements
      .where((announcement) => announcement.publishedAt != null)
      .length;
  int get _recentPrayerCount => _prayerRequests.length;
  int get _queuedCommunicationCount =>
      _communications.where((item) => item.status == 'queued').length;
  int get _activeMinistryCount =>
      _ministries.where((ministry) => ministry.active).length;
  int get _assetItemCount =>
      _assets.fold(0, (sum, asset) => sum + asset.quantity);
  int get _visitorCount => _visitors.length;
  num get _expenseMonthTotal {
    final now = DateTime.now();
    return _expenses.where((expense) {
      final spent = expense.spentAt.toLocal();
      return spent.year == now.year && spent.month == now.month;
    }).fold<num>(0, (sum, expense) => sum + expense.amount);
  }

  List<ManagedMember> get _birthdayMembers {
    final now = DateTime.now();
    return _churchMembers.where((member) {
      final birthDate = member.birthDate;
      if (birthDate == null) {
        return false;
      }
      final next = _nextBirthday(birthDate, now);
      return next.difference(DateTime(now.year, now.month, now.day)).inDays <=
          31;
    }).toList(growable: false);
  }

  bool _isManagementRole(String role) {
    return role == 'pastor' || role == 'church_admin';
  }

  int get _activeManagerCount => _churchMembers
      .where((member) =>
          member.status == 'active' && _isManagementRole(member.role))
      .length;
  num get _walletMonthRevenue =>
      _walletDashboard.fold(0, (sum, item) => sum + item.incomingMonth);
  num get _walletAvailableBalance =>
      _walletDashboard.fold(0, (sum, item) => sum + item.balance);
  int get _churchHealthScore {
    var score = 100;
    if (_isChurchReadOnly) {
      score -= 35;
    }
    if (_blockedMemberCount > 0) {
      score -= 10;
    }
    if (_recentPrayerCount > 5) {
      score -= 8;
    }
    if (_queuedCommunicationCount > 0) {
      score -= 5;
    }
    if (_walletWithdrawals.any((item) => item.status == 'pending')) {
      score -= 7;
    }
    return score.clamp(0, 100);
  }

  String get _churchHealthLabel {
    final score = _churchHealthScore;
    if (score >= 85) {
      return 'Saudavel';
    }
    if (score >= 65) {
      return 'Atencao';
    }
    return 'Critico';
  }

  Color _churchHealthColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final score = _churchHealthScore;
    if (score >= 85) {
      return scheme.primary;
    }
    if (score >= 65) {
      return Colors.orange;
    }
    return scheme.error;
  }

  List<_ChurchHealthItem> get _churchHealthItems {
    final items = <_ChurchHealthItem>[];
    if (_isChurchReadOnly) {
      items.add(
        const _ChurchHealthItem(
          icon: Icons.lock_outline,
          title: 'Modo leitura',
          description: 'A subscricao precisa de regularizacao.',
          severity: _ChurchHealthSeverity.warning,
        ),
      );
    }
    if (_blockedMemberCount > 0) {
      items.add(
        _ChurchHealthItem(
          icon: Icons.block_outlined,
          title: 'Membros bloqueados',
          description: '$_blockedMemberCount membro(s) precisam de revisao.',
          severity: _ChurchHealthSeverity.warning,
        ),
      );
    }
    if (_queuedCommunicationCount > 0) {
      items.add(
        _ChurchHealthItem(
          icon: Icons.schedule_send_outlined,
          title: 'Comunicacoes na fila',
          description:
              '$_queuedCommunicationCount comunicacao(oes) aguardam envio.',
          severity: _ChurchHealthSeverity.info,
        ),
      );
    }
    if (items.isEmpty) {
      items.add(
        const _ChurchHealthItem(
          icon: Icons.verified_outlined,
          title: 'Operacao estavel',
          description: 'Nao existem bloqueios operacionais visiveis.',
          severity: _ChurchHealthSeverity.good,
        ),
      );
    }
    return items;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authRepository = widget.authRepository ?? SupabaseComunhaoAuthRepository();
    _backofficeRepository =
        widget.backofficeRepository ?? SupabaseBackofficeRepository();
    _financeRepository =
        widget.financeRepository ?? SupabaseFinanceRepository();
    _calendarRepository =
        widget.calendarRepository ?? SupabaseCalendarRepository();
    _operationsRepository =
        widget.operationsRepository ?? SupabaseOperationsRepository();
    _authSubscription = _authRepository.authStateChanges.listen((_) async {
      if (!mounted) {
        return;
      }
      if (_authRepository.currentUser == null) {
        _disposeRealtime();
        setState(() {
          _authStage = _AuthStage.credentials;
          _pendingPhone = null;
          _plans = const [];
          _clearLoadedWorkspace();
          _busy = false;
          _refreshInProgress = false;
          _refreshQueued = false;
          _suspendRealtimeRefresh = false;
        });
      } else {
        await _refreshData();
      }
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _disposeRealtime();
    WidgetsBinding.instance.removeObserver(this);
    _signupNameController.dispose();
    _signupChurchNameController.dispose();
    _signupPhoneController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    _loginPhoneController.dispose();
    _loginPasswordController.dispose();
    _otpController.dispose();
    _memberSearchController.dispose();
    _churchNameController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _countryController.dispose();
    _churchPhoneController.dispose();
    _churchEmailController.dispose();
    _logoUrlController.dispose();
    _primaryColorController.dispose();
    _secondaryColorController.dispose();
    _taglineController.dispose();
    _mpesaController.dispose();
    _emolaController.dispose();
    _bankNameController.dispose();
    _bankAccountNameController.dispose();
    _bankAccountNumberController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentUser != null) {
      unawaited(_refreshData());
    }
  }

  Future<void> _bootstrap() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _darkMode = preferences.getBool(_darkModeKey) ?? false;
      if (_currentUser != null) {
        await _refreshData();
      }
    } catch (error) {
      _loadError = '$error';
    } finally {
      if (mounted) {
        setState(() {
          _bootstrapped = true;
        });
      }
    }
  }

  Future<void> _setDarkMode(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_darkModeKey, value);
    if (!mounted) {
      return;
    }
    setState(() {
      _darkMode = value;
    });
  }

  Future<void> _refreshData() async {
    if (_currentUser == null) {
      return;
    }
    if (!await _ensureActiveSession()) {
      return;
    }
    if (_refreshInProgress) {
      _refreshQueued = true;
      return;
    }
    _refreshInProgress = true;

    setState(() {
      _loadError = null;
      _partialLoadWarnings = const [];
    });

    final warnings = <String>[];

    try {
      final roles = await _loadPart<List<String>>(
        'Papeis da conta',
        _backofficeRepository.fetchCurrentPlatformRoles,
        const [],
        warnings,
      );
      final applications = await _loadPart<List<ChurchApplication>>(
        'Pedido da igreja',
        _backofficeRepository.fetchOwnChurchApplications,
        const [],
        warnings,
      );
      final managedChurches = await _loadPart<List<ManagedChurch>>(
        'Igreja aprovada',
        _backofficeRepository.fetchManagedChurches,
        const [],
        warnings,
      );
      final plans = await _loadPart<List<SubscriptionPlan>>(
        'Planos de subscricao',
        _backofficeRepository.fetchSubscriptionPlans,
        const [],
        warnings,
      );

      List<ManagedMember> churchMembers = const [];
      List<ManagedAnnouncement> announcements = const [];
      List<ManagedCampaign> campaigns = const [];
      List<ManagedEvent> events = const [];
      List<PastoralPublication> publications = const [];
      List<ManagedPrayerRequest> prayerRequests = const [];
      List<ChurchCommunication> communications = const [];
      List<ChurchMinistry> ministries = const [];
      List<ChurchAsset> assets = const [];
      List<ChurchVisitor> visitors = const [];
      List<ChurchExpense> expenses = const [];
      List<ChurchSubscriptionRequest> requests = const [];
      List<WalletProviderSummary> walletDashboard = const [];
      List<WalletLedgerEntry> walletLedger = const [];
      List<WalletWithdrawalRequest> walletWithdrawals = const [];
      final selectedChurch = _selectManagedChurch(managedChurches);
      if (selectedChurch != null) {
        final churchId = selectedChurch.id;
        final churchData = await Future.wait<dynamic>([
          _loadPart<List<ManagedMember>>(
            'Membros',
            () => _backofficeRepository.fetchChurchMembers(churchId),
            const [],
            warnings,
          ),
          _loadPart<List<ManagedAnnouncement>>(
            'Publicacoes',
            () => _backofficeRepository.fetchChurchAnnouncements(churchId),
            const [],
            warnings,
          ),
          _loadPart<List<ManagedCampaign>>(
            'Campanhas',
            () => _backofficeRepository.fetchChurchCampaigns(churchId),
            const [],
            warnings,
          ),
          _loadPart<List<ManagedEvent>>(
            'Agenda',
            () => _backofficeRepository.fetchChurchEvents(churchId),
            const [],
            warnings,
          ),
          _loadPart<List<PastoralPublication>>(
            'Pastorais',
            () => PublicationRepository().fetchManagedPublications(churchId),
            const [],
            warnings,
          ),
          _loadPart<List<ManagedPrayerRequest>>(
            'Pedidos de oracao',
            () => _backofficeRepository.fetchChurchPrayerRequests(
              churchId,
              limit: 5,
            ),
            const [],
            warnings,
          ),
          _loadPart<List<ChurchCommunication>>(
            'Comunicacoes',
            () => _backofficeRepository.fetchChurchCommunications(churchId),
            const [],
            warnings,
          ),
          _loadPart<List<ChurchMinistry>>(
            'Ministerios',
            () => _backofficeRepository.fetchChurchMinistries(churchId),
            const [],
            warnings,
            reportWarning: false,
          ),
          _loadPart<List<ChurchAsset>>(
            'Patrimonio',
            () => _backofficeRepository.fetchChurchAssets(churchId),
            const [],
            warnings,
          ),
          _loadPart<List<ChurchVisitor>>(
            'Visitantes',
            () => _backofficeRepository.fetchChurchVisitors(churchId),
            const [],
            warnings,
          ),
          _loadPart<List<ChurchExpense>>(
            'Despesas',
            () => _backofficeRepository.fetchChurchExpenses(churchId),
            const [],
            warnings,
          ),
          _loadPart<List<ChurchSubscriptionRequest>>(
            'Pedidos de subscricao',
            () =>
                _backofficeRepository.fetchChurchSubscriptionRequests(churchId),
            const [],
            warnings,
            reportWarning: false,
          ),
          _loadPart<List<WalletProviderSummary>>(
            'Saldos da carteira',
            () => _financeRepository.fetchWalletDashboard(
              ownerType: 'church',
              churchId: churchId,
            ),
            const [],
            warnings,
          ),
          _loadPart<List<WalletLedgerEntry>>(
            'Historico da carteira',
            () => _financeRepository.fetchWalletLedger(
              ownerType: 'church',
              churchId: churchId,
              limit: 25,
            ),
            const [],
            warnings,
          ),
          _loadPart<List<WalletWithdrawalRequest>>(
            'Levantamentos',
            () => _financeRepository.fetchWithdrawalRequests(
              ownerType: 'church',
              churchId: churchId,
              limit: 25,
            ),
            const [],
            warnings,
          ),
        ]);
        churchMembers = churchData[0] as List<ManagedMember>;
        announcements = churchData[1] as List<ManagedAnnouncement>;
        campaigns = churchData[2] as List<ManagedCampaign>;
        events = churchData[3] as List<ManagedEvent>;
        publications = churchData[4] as List<PastoralPublication>;
        prayerRequests = churchData[5] as List<ManagedPrayerRequest>;
        communications = churchData[6] as List<ChurchCommunication>;
        ministries = churchData[7] as List<ChurchMinistry>;
        assets = churchData[8] as List<ChurchAsset>;
        visitors = churchData[9] as List<ChurchVisitor>;
        expenses = churchData[10] as List<ChurchExpense>;
        requests = churchData[11] as List<ChurchSubscriptionRequest>;
        walletDashboard = churchData[12] as List<WalletProviderSummary>;
        walletLedger = churchData[13] as List<WalletLedgerEntry>;
        walletWithdrawals = churchData[14] as List<WalletWithdrawalRequest>;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _platformRoles = roles;
        _applications = applications;
        _managedChurches = managedChurches;
        _churchMembers = churchMembers;
        _announcements = announcements;
        _campaigns = campaigns;
        _events = events;
        _publications = publications;
        _prayerRequests = prayerRequests;
        _communications = communications;
        _ministries = ministries;
        _assets = assets;
        _visitors = visitors;
        _expenses = expenses;
        _plans = plans;
        _subscriptionRequests = requests;
        _walletDashboard = walletDashboard;
        _walletLedger = walletLedger;
        _walletWithdrawals = walletWithdrawals;
        _partialLoadWarnings = List.unmodifiable(warnings);
      });

      _hydrateApplicationForm(_activeApplication);
      _configureRealtime(_managedChurch?.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = _friendlyError(error);
      });
    } finally {
      _refreshInProgress = false;
      if (_refreshQueued && mounted && _currentUser != null) {
        _refreshQueued = false;
        unawaited(_refreshData());
      }
    }
  }

  Future<T> _loadPart<T>(
    String label,
    Future<T> Function() loader,
    T fallback,
    List<String> warnings, {
    bool reportWarning = true,
  }) async {
    try {
      return await loader();
    } catch (error) {
      if (reportWarning) {
        warnings.add('$label: ${_friendlyError(error)}');
      }
      return fallback;
    }
  }

  Future<bool> _ensureActiveSession() async {
    final userId = _currentUserId;
    if (userId == null) {
      return false;
    }
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('full_name, phone')
          .eq('id', userId)
          .maybeSingle();
      final profile = row == null ? null : Map<String, dynamic>.from(row);
      final fullName = (profile?['full_name'] as String?)?.trim();
      final phone = (profile?['phone'] as String?)?.trim();
      final deleted = profile == null ||
          fullName == 'Conta apagada' ||
          phone == null ||
          phone.isEmpty;
      if (!deleted) {
        return true;
      }
    } catch (_) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    _forceRegistrationScreen();
    try {
      await _authRepository.signOut();
    } catch (_) {}
    return false;
  }

  void _disposeRealtime() {
    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = null;
    _realtimeChurchId = null;
    final channel = _realtimeChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
      _realtimeChannel = null;
    }
  }

  void _scheduleRealtimeRefresh() {
    if (_currentUser == null || _suspendRealtimeRefresh) {
      return;
    }
    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _currentUser != null) {
        unawaited(_refreshData());
      }
    });
  }

  void _configureRealtime(String? churchId) {
    final profileId = _currentUserId;
    if (_currentUser == null || profileId == null) {
      return;
    }
    if (_realtimeChannel != null && _realtimeChurchId == churchId) {
      return;
    }

    _disposeRealtime();

    final channel = Supabase.instance.client
        .channel('comunhao-igreja-$profileId-${churchId ?? 'pending'}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'church_applications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'pastor_profile_id',
          value: profileId,
        ),
        callback: (_) => _scheduleRealtimeRefresh(),
      );

    if (churchId != null && churchId.isNotEmpty) {
      channel
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'memberships',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'announcements',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'donation_campaigns',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'donations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'prayer_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'prayer_request_responses',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'church_join_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'pastoral_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'administrative_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'church_communications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'church_ministries',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'ministry_members',
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'church_assets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'church_visitors',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'church_expenses',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'church_subscription_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
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
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'wallet_ledger_entries',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'wallet_withdrawal_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'pastoral_publications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'pastoral_publication_comments',
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'pastoral_publication_reactions',
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'community_posts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'community_post_comments',
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'community_post_reactions',
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'community_post_shares',
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'community_post_reports',
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'community_member_warnings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'comunhao',
          table: 'internal_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_profile_id',
            value: profileId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        );
    }

    channel.subscribe();
    _realtimeChannel = channel;
    _realtimeChurchId = churchId;
  }

  void _hydrateApplicationForm(ChurchApplication? application) {
    if (application == null) {
      if (_loadedApplicationId == null) {
        return;
      }
      _loadedApplicationId = null;
      _churchNameController.clear();
      _cityController.clear();
      _provinceController.clear();
      _countryController.text = 'Mozambique';
      _churchPhoneController.clear();
      _churchEmailController.clear();
      _logoUrlController.clear();
      _primaryColorController.clear();
      _secondaryColorController.clear();
      _taglineController.clear();
      _mpesaController.clear();
      _emolaController.clear();
      _bankNameController.clear();
      _bankAccountNameController.clear();
      _bankAccountNumberController.clear();
      return;
    }

    if (_loadedApplicationId == application.id) {
      return;
    }

    _loadedApplicationId = application.id;
    _churchNameController.text = application.churchName;
    _cityController.text = application.city;
    _provinceController.text = application.province ?? '';
    _countryController.text = application.country;
    _churchPhoneController.text = application.phone;
    _churchEmailController.text = application.email ?? '';
    _logoUrlController.text = application.logoUrl ?? '';
    _primaryColorController.text = application.primaryColor ?? '';
    _secondaryColorController.text = application.secondaryColor ?? '';
    _taglineController.text = application.tagline ?? '';
    _mpesaController.text = application.mpesa ?? '';
    _emolaController.text = application.emola ?? '';
    _bankNameController.text = application.bankName ?? '';
    _bankAccountNameController.text = application.bankAccountName ?? '';
    _bankAccountNumberController.text = application.bankAccountNumber ?? '';
  }

  Future<void> _signOut() async {
    await _authRepository.signOut();
  }

  void _clearLoadedWorkspace() {
    _platformRoles = const [];
    _applications = const [];
    _managedChurches = const [];
    _churchMembers = const [];
    _announcements = const [];
    _campaigns = const [];
    _events = const [];
    _publications = const [];
    _prayerRequests = const [];
    _communications = const [];
    _ministries = const [];
    _assets = const [];
    _visitors = const [];
    _expenses = const [];
    _subscriptionRequests = const [];
    _walletDashboard = const [];
    _walletLedger = const [];
    _walletWithdrawals = const [];
    _partialLoadWarnings = const [];
    _loadError = null;
  }

  Future<void> _deleteAccount() async {
    _showMessage('A abrir confirmacao para apagar a conta...');
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: _dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('Apagar conta do pastor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta acao remove o teu acesso, termina a sessao e anonimiza o teu perfil. Se tiveres saldo disponivel na conta Comunhao, ele sera transferido para a conta da igreja/admin antes da conta ser apagada.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Escreve APAGAR para confirmar',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Apagar conta'),
          ),
        ],
      ),
    );
    final phrase = controller.text.trim().toUpperCase();
    controller.dispose();
    if (confirmed != true) return;
    if (phrase != 'APAGAR') {
      _showMessage('Escreve APAGAR para confirmar.');
      return;
    }
    setState(() => _busy = true);
    try {
      _suspendRealtimeRefresh = true;
      _disposeRealtime();
      await _authRepository.deleteAccount();
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _selectedIndex = 0;
        _clearLoadedWorkspace();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _suspendRealtimeRefresh = false;
      });
      _showMessage(_friendlyError(error));
    }
  }

  Future<void> _deleteChurch() async {
    final church = _managedChurch;
    if (church == null) {
      _showMessage('A igreja ainda nao foi carregada.');
      return;
    }
    _showMessage('A abrir confirmacao para apagar a igreja...');
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: _dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('Apagar igreja'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esta acao vai apagar "${church.name}", todos os dados ligados a esta igreja e a tua conta de pastor. Os membros ativos recebem uma notificacao antes da remocao.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Depois da confirmacao, a sessao termina e o app volta apenas para a tela de cadastro.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Escreve APAGAR IGREJA para confirmar',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Apagar igreja'),
          ),
        ],
      ),
    );
    final phrase = controller.text.trim().toUpperCase();
    controller.dispose();
    if (confirmed != true) return;
    if (phrase != 'APAGAR IGREJA') {
      _showMessage('Escreve APAGAR IGREJA para confirmar.');
      return;
    }

    setState(() => _busy = true);
    var churchDeleted = false;
    try {
      _suspendRealtimeRefresh = true;
      _disposeRealtime();
      _scaffoldMessengerKey.currentState?.clearSnackBars();
      await _backofficeRepository.deleteManagedChurch(church.id);
      churchDeleted = true;
      if (!mounted) {
        return;
      }
      _forceRegistrationScreen();
      await Future<void>.delayed(Duration.zero);
      if (!mounted) {
        return;
      }
      await _authRepository.signOut();
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
    } catch (error) {
      if (mounted) {
        if (churchDeleted) {
          _forceRegistrationScreen();
          try {
            await _authRepository.signOut();
          } catch (_) {}
          return;
        }
        setState(() {
          _busy = false;
          _suspendRealtimeRefresh = false;
        });
        _showMessage(
            'Nao foi possivel apagar a igreja: ${_friendlyError(error)}');
      }
    }
  }

  void _forceRegistrationScreen() {
    _scaffoldMessengerKey.currentState?.clearSnackBars();
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    setState(() {
      _selectedIndex = 0;
      _authMode = _AuthMode.signup;
      _authStage = _AuthStage.credentials;
      _pendingPhone = null;
      _busy = false;
      _suspendRealtimeRefresh = true;
      _refreshInProgress = false;
      _refreshQueued = false;
      _clearLoadedWorkspace();
    });
  }

  Future<void> _startNewApplicationFromRejected() async {
    final current = _activeApplication;
    if (current == null) {
      return;
    }

    setState(() => _loadedApplicationId = null);
    _hydrateApplicationForm(
      ChurchApplication(
        pastorProfileId: current.pastorProfileId,
        churchName: current.churchName,
        city: current.city,
        province: current.province,
        country: current.country,
        phone: current.phone,
        email: current.email,
        applicantRole: current.applicantRole,
        logoUrl: current.logoUrl,
        primaryColor: current.primaryColor,
        secondaryColor: current.secondaryColor,
        tagline: current.tagline,
        mpesa: current.mpesa,
        emola: current.emola,
        bankName: current.bankName,
        bankAccountName: current.bankAccountName,
        bankAccountNumber: current.bankAccountNumber,
      ),
    );
  }

  Future<void> _submitSignup() async {
    if (!_signupFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _busy = true);
    try {
      final normalizedPhone = normalizePhone(_signupPhoneController.text);
      final churchName = _signupChurchNameController.text.trim();
      final pastorName = _signupNameController.text.trim();
      final response = await _authRepository.signUpWithPhone(
        fullName: pastorName,
        phone: normalizedPhone,
        password: _signupPasswordController.text,
        metadata: {
          'church_name': churchName,
          'pastor_name': pastorName,
        },
      );
      _churchNameController.text = churchName;
      _churchPhoneController.text = normalizedPhone;

      if (!mounted) {
        return;
      }

      if (response.session != null) {
        _showMessage('Conta criada com sucesso.');
        await _refreshData();
        return;
      }

      setState(() {
        _pendingPhone = normalizedPhone;
        _authStage = _AuthStage.otp;
      });
      _showMessage(
          'Enviamos um codigo SMS para ${maskPhone(normalizedPhone)}.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _busy = true);
    try {
      final normalizedPhone = normalizePhone(_loginPhoneController.text);
      await _authRepository.signInWithPhone(
        phone: normalizedPhone,
        password: _loginPasswordController.text,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = _friendlyError(error);
      if (message.toLowerCase().contains('phone_not_confirmed') ||
          message.toLowerCase().contains('phone not confirmed')) {
        setState(() {
          _pendingPhone = normalizePhone(_loginPhoneController.text);
          _authStage = _AuthStage.otp;
        });
      }
      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (!_otpFormKey.currentState!.validate() || _pendingPhone == null) {
      return;
    }

    setState(() => _busy = true);
    try {
      await _authRepository.verifyPhoneOtp(
        phone: _pendingPhone!,
        token: _otpController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      _showMessage('Numero confirmado com sucesso.');
      await _refreshData();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_pendingPhone == null) {
      return;
    }

    setState(() => _busy = true);
    try {
      await _authRepository.resendPhoneOtp(phone: _pendingPhone!);
      if (!mounted) {
        return;
      }
      _showMessage('Codigo reenviado para ${maskPhone(_pendingPhone!)}.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _saveChurchApplication({required bool submitAfter}) async {
    if (!_applicationFormKey.currentState!.validate()) {
      return;
    }

    final current = _activeApplication;
    final createNew = current == null || current.status == 'rejected';
    final accountPhone = normalizePhone(
      _accountPhone ?? _signupPhoneController.text,
    );
    final paymentProvider = _providerForPhone(accountPhone);

    setState(() => _busy = true);
    try {
      final draft = ChurchApplication(
        id: createNew ? null : current.id,
        churchName: _churchNameController.text.trim(),
        city: _cityController.text.trim(),
        province: _provinceController.text.trim().isEmpty
            ? null
            : _provinceController.text.trim(),
        country: _countryController.text.trim().isEmpty
            ? 'Mozambique'
            : _countryController.text.trim(),
        phone: accountPhone,
        email: null,
        applicantRole: 'pastor',
        logoUrl: _logoUrlController.text.trim().isEmpty
            ? null
            : _logoUrlController.text.trim(),
        primaryColor: _primaryColorController.text.trim().isEmpty
            ? null
            : _primaryColorController.text.trim(),
        secondaryColor: _secondaryColorController.text.trim().isEmpty
            ? null
            : _secondaryColorController.text.trim(),
        tagline: null,
        mpesa: paymentProvider == 'mpesa' ? accountPhone : null,
        emola: paymentProvider == 'emola' ? accountPhone : null,
        bankName: null,
        bankAccountName: null,
        bankAccountNumber: null,
      );

      final saved = await _backofficeRepository.saveChurchApplication(draft);
      if (submitAfter) {
        await _backofficeRepository.submitChurchApplication(saved.id!);
      }

      if (!mounted) {
        return;
      }

      await _refreshData();
      _showMessage(
        submitAfter
            ? 'A sua igreja foi enviada para aprovacao. Recebera uma notificacao assim que for analisada.'
            : 'Rascunho guardado com sucesso.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _manageMember(ManagedMember member) async {
    if (_managedChurch == null) {
      return;
    }
    if (_isChurchReadOnly) {
      _showMessage(
        'A igreja esta em modo leitura enquanto a subscricao estiver suspensa.',
      );
      return;
    }
    if (member.profileId == _currentUserId) {
      _showMessage(
        'Por seguranca, altera a tua propria conta apenas pelo backend ou com outro administrador ativo.',
      );
      return;
    }

    var role = member.role;
    var status = member.status;

    final confirmed = await showDialog<bool>(
      context: _dialogContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(member.fullName),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.phone ?? 'Sem telefone'),
                const SizedBox(height: 8),
                Text('Estado atual: ${member.statusLabel}'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Papel'),
                  items: const [
                    DropdownMenuItem(
                      value: 'pastor',
                      child: Text('Pastor'),
                    ),
                    DropdownMenuItem(
                      value: 'church_admin',
                      child: Text('Administrador da Igreja'),
                    ),
                    DropdownMenuItem(
                      value: 'leader',
                      child: Text('Lider'),
                    ),
                    DropdownMenuItem(
                      value: 'member',
                      child: Text('Membro'),
                    ),
                  ],
                  onChanged: (value) {
                    setModalState(() {
                      role = value ?? member.role;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: const [
                    DropdownMenuItem(
                      value: 'active',
                      child: Text('Ativo'),
                    ),
                    DropdownMenuItem(
                      value: 'blocked',
                      child: Text('Bloqueado'),
                    ),
                    DropdownMenuItem(
                      value: 'removed',
                      child: Text('Removido'),
                    ),
                    DropdownMenuItem(
                      value: 'transferred',
                      child: Text('Transferido'),
                    ),
                  ],
                  onChanged: (value) {
                    setModalState(() {
                      status = value ?? member.status;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      return;
    }

    if (role == member.role && status == member.status) {
      _showMessage('Nenhuma alteracao foi feita.');
      return;
    }

    final wouldRemoveLastManager = member.isActive &&
        _isManagementRole(member.role) &&
        _activeManagerCount <= 1 &&
        (status != 'active' || !_isManagementRole(role));
    if (wouldRemoveLastManager) {
      _showMessage(
        'Esta igreja precisa de pelo menos um pastor ou administrador ativo.',
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await _backofficeRepository.updateChurchMember(
        membershipId: member.membershipId,
        role: role,
        status: status,
      );
      if (!mounted) {
        return;
      }
      await _refreshData();
      _showMessage('Membro atualizado com sucesso.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<DateTime?> _pickDateTime({
    required DateTime initialValue,
    required String helpText,
  }) async {
    final date = await showDatePicker(
      context: _dialogContext,
      initialDate: initialValue,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: helpText,
    );
    if (date == null || !mounted) {
      return null;
    }

    final time = await showTimePicker(
      context: _dialogContext,
      initialTime: TimeOfDay.fromDateTime(initialValue),
      helpText: helpText,
    );
    if (time == null) {
      return null;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _openAnnouncementEditor([ManagedAnnouncement? current]) async {
    final church = _managedChurch;
    if (!_canEditChurch(church)) {
      return;
    }
    final editableChurch = church!;

    final titleController = TextEditingController(text: current?.title ?? '');
    final bodyController = TextEditingController(text: current?.body ?? '');
    final imageController =
        TextEditingController(text: current?.imageUrl ?? '');
    var uploadingImage = false;
    var pinned = current?.pinned ?? false;
    var published = current?.isPublished ?? true;

    final confirmed = await showDialog<bool>(
      context: _dialogContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(current == null ? 'Novo anuncio' : 'Editar anuncio'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Titulo'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: bodyController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Mensagem'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.event_available_outlined),
                          label: const Text('Lembrete do culto'),
                          onPressed: () {
                            setModalState(() {
                              titleController.text = 'Lembrete do culto';
                              bodyController.text =
                                  'Nao te esquecas do nosso culto. Vem com a tua familia e convida alguem.';
                              published = true;
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.groups_outlined),
                          label: const Text('Mensagem aos lideres'),
                          onPressed: () {
                            setModalState(() {
                              titleController.text = 'Mensagem aos lideres';
                              bodyController.text =
                                  'Lideres, por favor acompanhem as atividades e mantenham as equipas informadas.';
                              published = true;
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.volunteer_activism_outlined),
                          label: const Text('Campanha de solidariedade'),
                          onPressed: () {
                            setModalState(() {
                              titleController.text =
                                  'Campanha de solidariedade';
                              bodyController.text =
                                  'Estamos unidos para apoiar familias que precisam. Participa com amor e generosidade.';
                              published = true;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: imageController,
                    decoration: const InputDecoration(labelText: 'Imagem/URL'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: uploadingImage
                              ? null
                              : () async {
                                  setModalState(() => uploadingImage = true);
                                  try {
                                    final url = await _pickAndUploadImage(
                                      churchId: editableChurch.id,
                                      folder: 'announcements',
                                    );
                                    if (url != null) {
                                      imageController.text = url;
                                    }
                                  } catch (error) {
                                    if (context.mounted) {
                                      _showMessage(_friendlyError(error));
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setModalState(
                                        () => uploadingImage = false,
                                      );
                                    }
                                  }
                                },
                          icon: uploadingImage
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.photo_library_outlined),
                          label: const Text('Imagem da galeria'),
                        ),
                      ),
                      if (imageController.text.trim().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Remover imagem',
                          onPressed: uploadingImage
                              ? null
                              : () => setModalState(imageController.clear),
                          icon: const Icon(Icons.close_outlined),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: pinned,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fixar no topo'),
                    onChanged: (value) {
                      setModalState(() {
                        pinned = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    value: published,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Publicar imediatamente'),
                    onChanged: (value) {
                      setModalState(() {
                        published = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(published ? 'Publicar' : 'Guardar rascunho'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      titleController.dispose();
      bodyController.dispose();
      imageController.dispose();
      return;
    }

    final title = titleController.text.trim();
    final body = bodyController.text.trim();
    final imageUrl = imageController.text.trim();
    titleController.dispose();
    bodyController.dispose();
    imageController.dispose();

    if (title.length < 3 || body.length < 5) {
      _showMessage('Preenche um titulo e uma mensagem validos.');
      return;
    }

    setState(() => _busy = true);
    try {
      await _backofficeRepository.saveChurchAnnouncement(
        announcementId: current?.id,
        churchId: editableChurch.id,
        title: title,
        body: body,
        imageUrl: imageUrl,
        pinned: pinned,
        publishedAt:
            published ? (current?.publishedAt ?? DateTime.now()) : null,
      );
      if (!mounted) {
        return;
      }
      await _refreshData();
      _showMessage(
        published
            ? 'Anuncio publicado com sucesso.'
            : 'Anuncio guardado como rascunho.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteAnnouncement(ManagedAnnouncement announcement) async {
    if (!_canEditChurch(_managedChurch)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: _dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('Apagar anuncio'),
        content: Text('Pretendes apagar "${announcement.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _busy = true);
    try {
      await _backofficeRepository.deleteChurchAnnouncement(announcement.id);
      if (!mounted) {
        return;
      }
      await _refreshData();
      _showMessage('Anuncio apagado.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openEventEditor([ManagedEvent? current]) async {
    final church = _managedChurch;
    if (!_canEditChurch(church)) {
      return;
    }
    final editableChurch = church!;

    final titleController = TextEditingController(text: current?.title ?? '');
    final descriptionController =
        TextEditingController(text: current?.description ?? '');
    final locationController =
        TextEditingController(text: current?.location ?? '');
    final imageController =
        TextEditingController(text: current?.coverImageUrl ?? '');
    final capacityController = TextEditingController(
      text: current?.capacity?.toString() ?? '',
    );
    var eventType = current?.eventType ?? 'culto';
    var startsAt = current?.startsAt.add(const Duration()) ??
        DateTime.now().add(const Duration(days: 1));
    DateTime? endsAt = current?.endsAt;
    var registrationRequired = current?.registrationRequired ?? false;
    var uploadingImage = false;

    final confirmed = await showDialog<bool>(
      context: _dialogContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(current == null ? 'Novo evento' : 'Editar evento'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: eventType,
                    decoration:
                        const InputDecoration(labelText: 'Tipo de evento'),
                    items: const [
                      DropdownMenuItem(value: 'culto', child: Text('Culto')),
                      DropdownMenuItem(
                        value: 'congresso',
                        child: Text('Congresso'),
                      ),
                      DropdownMenuItem(
                          value: 'vigilia', child: Text('Vigilia')),
                      DropdownMenuItem(
                          value: 'batismo', child: Text('Batismo')),
                      DropdownMenuItem(
                        value: 'casamento',
                        child: Text('Casamento'),
                      ),
                      DropdownMenuItem(
                        value: 'conferencia',
                        child: Text('Conferencia'),
                      ),
                      DropdownMenuItem(value: 'ensaio', child: Text('Ensaio')),
                      DropdownMenuItem(
                          value: 'reuniao', child: Text('Reuniao')),
                      DropdownMenuItem(value: 'outro', child: Text('Outro')),
                    ],
                    onChanged: (value) {
                      setModalState(() {
                        eventType = value ?? 'culto';
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Titulo'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Descricao'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'Local'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: imageController,
                    decoration: const InputDecoration(labelText: 'Imagem/URL'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: uploadingImage
                              ? null
                              : () async {
                                  setModalState(() => uploadingImage = true);
                                  try {
                                    final url = await _pickAndUploadImage(
                                      churchId: editableChurch.id,
                                      folder: 'events',
                                    );
                                    if (url != null) {
                                      imageController.text = url;
                                    }
                                  } catch (error) {
                                    if (context.mounted) {
                                      _showMessage(_friendlyError(error));
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setModalState(
                                        () => uploadingImage = false,
                                      );
                                    }
                                  }
                                },
                          icon: uploadingImage
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.photo_library_outlined),
                          label: const Text('Imagem da galeria'),
                        ),
                      ),
                      if (imageController.text.trim().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Remover imagem',
                          onPressed: uploadingImage
                              ? null
                              : () => setModalState(imageController.clear),
                          icon: const Icon(Icons.close_outlined),
                        ),
                      ],
                    ],
                  ),
                  if (imageController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: Image.network(
                          imageController.text.trim(),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Text('Imagem sera carregada pela URL.'),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await _pickDateTime(
                              initialValue: startsAt,
                              helpText: 'Escolher inicio',
                            );
                            if (picked == null) {
                              return;
                            }
                            setModalState(() {
                              startsAt = picked;
                            });
                          },
                          icon: const Icon(Icons.schedule_outlined),
                          label: Text(_formatDateTime(startsAt)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await _pickDateTime(
                              initialValue: endsAt ??
                                  startsAt.add(const Duration(hours: 2)),
                              helpText: 'Escolher fim',
                            );
                            if (picked == null) {
                              return;
                            }
                            setModalState(() {
                              endsAt = picked;
                            });
                          },
                          icon: const Icon(Icons.event_available_outlined),
                          label: Text(
                            endsAt == null
                                ? 'Fim opcional'
                                : _formatDateTime(endsAt!),
                          ),
                        ),
                      ),
                      if (endsAt != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            setModalState(() {
                              endsAt = null;
                            });
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: registrationRequired,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Exigir inscricao'),
                    onChanged: (value) {
                      setModalState(() {
                        registrationRequired = value;
                      });
                    },
                  ),
                  if (registrationRequired) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: capacityController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Capacidade'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Publicar evento'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      titleController.dispose();
      descriptionController.dispose();
      locationController.dispose();
      imageController.dispose();
      capacityController.dispose();
      return;
    }

    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final location = locationController.text.trim();
    final imageUrl = imageController.text.trim();
    final capacity = int.tryParse(capacityController.text.trim());
    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    imageController.dispose();
    capacityController.dispose();

    if (title.length < 3) {
      _showMessage('Introduz um titulo valido para o evento.');
      return;
    }

    setState(() => _busy = true);
    try {
      await _backofficeRepository.saveChurchEvent(
        eventId: current?.id,
        churchId: editableChurch.id,
        title: title,
        eventType: eventType,
        description: description.isEmpty ? null : description,
        location: location.isEmpty ? null : location,
        status: 'published',
        visibility: 'members',
        coverImageUrl: imageUrl.isEmpty ? null : imageUrl,
        startsAt: startsAt,
        endsAt: endsAt,
        registrationRequired: registrationRequired,
        capacity: registrationRequired ? capacity : null,
      );
      if (!mounted) {
        return;
      }
      await _refreshData();
      _showMessage('Evento publicado com sucesso.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteEvent(ManagedEvent event) async {
    if (!_canEditChurch(_managedChurch)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: _dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('Apagar evento'),
        content: Text('Pretendes apagar "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _busy = true);
    try {
      await _backofficeRepository.deleteChurchEvent(event.id);
      if (!mounted) {
        return;
      }
      await _refreshData();
      _showMessage('Evento apagado.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('phone_provider_disabled')) {
      return 'O provedor de SMS ainda nao esta configurado no Supabase.';
    }
    if (lower.contains('sms_send_failed')) {
      return 'Nao foi possivel enviar o SMS agora.';
    }
    if (lower.contains('otp_expired') || lower.contains('token has expired')) {
      return 'O codigo expirou. Pede um novo SMS e usa apenas o codigo mais recente.';
    }
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials')) {
      return 'Nao foi possivel entrar: confirma o telefone e a palavra-passe. Se acabaste de criar a conta, confirma primeiro o codigo OTP.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('ja existe uma conta com este numero')) {
      return 'Este numero ja esta registado. Para cadastrar uma nova igreja, usa um numero ainda sem conta; uma conta de membro nao pode ser reutilizada como novo pastor.';
    }
    if (lower.contains('numero de telefone invalido')) {
      return 'O numero de telefone nao e valido. Usa um numero mocambicano com 9 digitos, por exemplo 84xxxxxxx ou 87xxxxxxx.';
    }
    if (lower.contains('palavra-passe deve ter pelo menos 6')) {
      return 'A palavra-passe precisa de pelo menos 6 caracteres.';
    }
    if (lower.contains('codigo otp invalido')) {
      return 'O codigo OTP nao confere. Verifica os 6 digitos ou pede um novo codigo.';
    }
    if (lower.contains('nenhum codigo ativo')) {
      return 'Nao existe um OTP ativo para este numero. Pede um novo codigo e introduz o mais recente.';
    }
    if (lower.contains('insufficient balance')) {
      return 'Saldo insuficiente para esse levantamento.';
    }
    if (lower.contains('read-only')) {
      return 'A igreja esta em modo leitura enquanto a subscricao estiver suspensa.';
    }
    if (lower.contains('lateinitializationerror') ||
        lower.contains('assertion failed')) {
      return 'A tela ainda estava a inicializar. Atualiza a pagina uma vez e tenta novamente.';
    }
    if (error is MissingPluginException ||
        lower.contains('missingpluginexception')) {
      return 'O seletor de ficheiros ainda nao carregou nesta sessao. Atualiza a pagina e tenta novamente.';
    }
    if (lower.contains('payload too large') ||
        lower.contains('exceeded') ||
        lower.contains('file size') ||
        lower.contains('too large')) {
      return 'O ficheiro e muito grande. Usa uma imagem ate 5 MB, ou video/audio/documento ate 100 MB nas publicacoes.';
    }
    if (lower.contains('mime') ||
        lower.contains('content type') ||
        lower.contains('not allowed') ||
        lower.contains('unsupported')) {
      return 'Tipo de ficheiro nao permitido. Usa JPG, PNG, WEBP, MP3, M4A, MP4, PDF, DOC ou DOCX.';
    }
    if (lower.contains('jwt') ||
        lower.contains('expired') ||
        lower.contains('not authenticated')) {
      return 'Sessao expirada. Sai e entra novamente para fazer upload.';
    }
    if (lower.contains('row-level security') ||
        lower.contains('permission denied') ||
        lower.contains('42501')) {
      return 'Sem permissao para guardar nesta igreja. Confirma se a tua conta esta como pastor ou administrador ativo.';
    }
    if (lower.contains('column') ||
        lower.contains('schema cache') ||
        lower.contains('pgrst204') ||
        lower.contains('42703')) {
      return 'O app esta mais novo que o schema do Supabase. A gravação basica foi tentada; se continuar a falhar, aplica as ultimas migrations.';
    }
    if (lower.contains('postgrestexception') ||
        lower.contains('postgres') ||
        lower.contains('pgrst')) {
      return 'Nao foi possivel sincronizar alguns dados agora. Atualiza a pagina e tenta novamente.';
    }
    return raw.replaceFirst('AuthException(message: ', '').replaceAll(')', '');
  }

  bool _canEditChurch(ManagedChurch? church) {
    if (church == null) {
      _showMessage('A igreja ainda nao foi carregada. Atualiza a pagina.');
      return false;
    }
    if (_isChurchReadOnly) {
      _showMessage(
        'A igreja estava em modo leitura. Atualiza acesso para sincronizar o trial reativado.',
      );
      return false;
    }
    return true;
  }

  void _showMessage(String message) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _runUiAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyError(error));
    }
  }

  Future<void> _editChurchName(ManagedChurch church) async {
    final controller = TextEditingController(text: church.name);
    final newName = await showDialog<String>(
      context: _dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('Editar nome da igreja'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome da igreja'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName == church.name) {
      return;
    }
    if (newName.length < 2) {
      _showMessage('Introduz um nome valido para a igreja.');
      return;
    }

    try {
      await _backofficeRepository.updateManagedChurchName(
        churchId: church.id,
        name: newName,
      );
      _showMessage('Nome da igreja atualizado.');
      await _refreshData();
    } catch (error) {
      _showMessage(_friendlyError(error));
    }
  }

  Future<void> _editChurchProfile(ManagedChurch church) async {
    final nameController = TextEditingController(text: church.name);
    final phoneController = TextEditingController(
      text: church.phone ?? _activeApplication?.phone ?? _currentPhone ?? '',
    );
    final emailController = TextEditingController(
      text: church.email ?? _activeApplication?.email ?? '',
    );
    final taglineController = TextEditingController(
      text: church.tagline ?? _activeApplication?.tagline ?? '',
    );
    final logoController = TextEditingController(text: church.logoUrl ?? '');
    final primaryController = TextEditingController(
      text: church.primaryColor ?? '#0F766E',
    );
    final secondaryController = TextEditingController(
      text: church.secondaryColor ?? '#115E59',
    );

    final saved = await showDialog<bool>(
      context: _dialogContext,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Editar perfil da igreja'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ApplicationLogoPicker(
                      logoUrl: logoController.text.trim(),
                      onPickGallery: _busy
                          ? null
                          : () async {
                              final url = await _pickManagedChurchLogo(
                                church,
                                ImageSource.gallery,
                              );
                              if (url != null && context.mounted) {
                                setDialogState(() => logoController.text = url);
                              }
                            },
                      onPickCamera: _busy
                          ? null
                          : () async {
                              final url = await _pickManagedChurchLogo(
                                church,
                                ImageSource.camera,
                              );
                              if (url != null && context.mounted) {
                                setDialogState(() => logoController.text = url);
                              }
                            },
                      onClear: () =>
                          setDialogState(() => logoController.clear()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration:
                          const InputDecoration(labelText: 'Nome da igreja'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: taglineController,
                      decoration:
                          const InputDecoration(labelText: 'Frase/slogan'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration:
                          const InputDecoration(labelText: 'Telefone publico'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          const InputDecoration(labelText: 'Email publico'),
                    ),
                    const SizedBox(height: 16),
                    _ColorSelector(
                      title: 'Cor primaria',
                      controller: primaryController,
                      fallback: '#0F766E',
                      onChanged: () => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    _ColorSelector(
                      title: 'Cor secundaria',
                      controller: secondaryController,
                      fallback: '#115E59',
                      onChanged: () => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        if (name.length < 2) {
                          _showMessage('Introduz um nome valido.');
                          return;
                        }
                        try {
                          await _backofficeRepository
                              .updateManagedChurchProfile(
                            churchId: church.id,
                            name: name,
                            phone: phoneController.text,
                            email: emailController.text,
                            tagline: taglineController.text,
                            logoUrl: logoController.text,
                            primaryColor: primaryController.text,
                            secondaryColor: secondaryController.text,
                          );
                          if (context.mounted) {
                            Navigator.of(context).pop(true);
                          }
                        } catch (error) {
                          _showMessage(_friendlyError(error));
                        }
                      },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    taglineController.dispose();
    logoController.dispose();
    primaryController.dispose();
    secondaryController.dispose();

    if (saved == true) {
      _showMessage('Perfil da igreja atualizado.');
      await _refreshData();
    }
  }

  Future<String?> _pickManagedChurchLogo(
    ManagedChurch church,
    ImageSource source,
  ) async {
    setState(() => _busy = true);
    try {
      final selected = source == ImageSource.gallery
          ? await _pickGalleryImage()
          : await _pickCameraImage(
              imageQuality: 86,
              maxWidth: 1200,
              maxHeight: 1200,
            );
      if (selected == null) return null;
      final (name, bytes) = selected;
      if (bytes.length > 5 * 1024 * 1024) {
        throw StateError('O logotipo deve ter no maximo 5 MB.');
      }
      final extension = _extensionFor(name);
      final path =
          '${church.id}/profile/logo-${DateTime.now().millisecondsSinceEpoch}.$extension';
      final client = Supabase.instance.client;
      await client.storage.from(_applicationBrandingBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: _contentTypeFor(extension)),
          );
      return client.storage.from(_applicationBrandingBucket).getPublicUrl(path);
    } catch (error) {
      if (mounted) {
        _showMessage(_friendlyError(error));
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _handleNotificationTap(
    InternalNotification notification,
  ) async {
    final destination = _pastorNotificationDestination(notification);
    if (destination != null) {
      setState(() => _selectedIndex = destination);
      await _refreshData();
    }

    final prayerRequestId = _notificationTargetId(
      notification,
      tables: const {'pastoral_requests', 'prayer_requests'},
      metadataKeys: const ['prayer_request_id', 'pastoral_request_id'],
    );
    if (prayerRequestId != null) {
      final matches =
          _prayerRequests.where((request) => request.id == prayerRequestId);
      if (matches.isNotEmpty) {
        await _openPrayerRequest(matches.first);
        return;
      }
    }

    final memberId = _notificationTargetId(
      notification,
      tables: const {'memberships', 'profiles'},
      metadataKeys: const ['profile_id', 'member_id', 'membership_id'],
    );
    if (memberId != null && _selectedIndex == 3) {
      final matches = _churchMembers.where(
        (member) =>
            member.profileId == memberId || member.membershipId == memberId,
      );
      if (matches.isNotEmpty) {
        await _manageMember(matches.first);
        return;
      }
    }

    _showMessage(_pastorNotificationMessage(notification));
  }

  int? _pastorNotificationDestination(InternalNotification notification) {
    final table = notification.referenceTable;
    final type = notification.type;
    if (type == 'church_approved' || type == 'subscription_payment_confirmed') {
      return 0;
    }
    if (type == 'church_rejected' ||
        type == 'church_corrections_requested' ||
        table == 'church_applications') {
      return 1;
    }
    if (type == 'join_request' ||
        type == 'pastoral_request' ||
        type == 'pastoral_request_assigned' ||
        type == 'administrative_request' ||
        table == 'church_join_requests' ||
        table == 'pastoral_requests' ||
        table == 'administrative_requests' ||
        table == 'prayer_requests') {
      return 2;
    }
    if (type == 'new_member' || table == 'memberships' || table == 'profiles') {
      return 3;
    }
    if (type == 'event' ||
        table == 'events' ||
        table == 'event_registrations') {
      return 4;
    }
    if (type.contains('donation') ||
        type.contains('contribution') ||
        type.contains('withdrawal') ||
        type.contains('expense') ||
        table == 'church_wallet_ledger_entries' ||
        table == 'wallet_withdrawal_requests' ||
        table == 'donations' ||
        table == 'church_contributions') {
      return 5;
    }
    if (type == 'pastoral_publication' ||
        type == 'announcement' ||
        type == 'urgent_notice' ||
        table == 'pastoral_publications' ||
        table == 'pastoral_publication_comments' ||
        table == 'community_posts' ||
        table == 'community_post_comments' ||
        table == 'community_post_shares' ||
        table == 'community_post_reports') {
      return 6;
    }
    if (table == 'church_groups' ||
        table == 'ministry_join_requests' ||
        table == 'ministry_members' ||
        type == 'ministry_invite') {
      return 7;
    }
    return null;
  }

  String? _notificationTargetId(
    InternalNotification notification, {
    required Set<String> tables,
    required List<String> metadataKeys,
  }) {
    if (notification.referenceTable != null &&
        tables.contains(notification.referenceTable) &&
        notification.referenceId != null &&
        notification.referenceId!.isNotEmpty) {
      return notification.referenceId;
    }
    for (final key in metadataKeys) {
      final value = notification.metadata[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  String _pastorNotificationMessage(InternalNotification notification) {
    return switch (_selectedIndex) {
      0 => 'Dashboard aberto para ${notification.typeLabel}.',
      1 => 'Formulario/estado da igreja aberto.',
      2 => 'Lista de pedidos aberta.',
      3 => 'Lista de membros aberta.',
      4 => 'Agenda aberta.',
      5 => 'Historico financeiro aberto.',
      6 => 'Area de publicacoes aberta.',
      7 => 'ERP/ministerios aberto.',
      _ => notification.typeLabel,
    };
  }

  Future<void> _openPrayerRequest(ManagedPrayerRequest request) async {
    final responseController = TextEditingController();
    Future<List<ManagedPrayerResponse>> responsesFuture =
        _backofficeRepository.fetchPrayerRequestResponses(request.id);
    bool sending = false;

    await showDialog<void>(
      context: _dialogContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(request.title),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(request.visibilityLabel)),
                        Chip(label: Text(request.statusLabel)),
                        Chip(label: Text(_formatDateTime(request.createdAt))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(request.requesterLabel),
                      subtitle: Text(
                        request.anonymousRequest
                            ? 'O membro pediu para nao mostrar o nome.'
                            : request.requesterPhone ?? 'Sem telefone visivel',
                      ),
                    ),
                    const Divider(height: 24),
                    Text(
                      request.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Respostas',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<ManagedPrayerResponse>>(
                      future: responsesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError) {
                          return Text(
                            'Falha ao carregar respostas.\n\n${snapshot.error}',
                          );
                        }
                        final responses =
                            snapshot.data ?? const <ManagedPrayerResponse>[];
                        if (responses.isEmpty) {
                          return const Text(
                            'Ainda nao existe resposta pastoral para este pedido.',
                          );
                        }

                        return Column(
                          children: responses.map((response) {
                            return Column(
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.forum_outlined),
                                  ),
                                  title: Text(response.responderLabel),
                                  subtitle: Text(
                                    '${_formatDateTime(response.createdAt)}\n${response.body}',
                                  ),
                                ),
                                const Divider(height: 20),
                              ],
                            );
                          }).toList(),
                        );
                      },
                    ),
                    if (request.allowResponses) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: responseController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Resposta pastoral',
                          hintText:
                              'Escreva uma mensagem de apoio, acompanhamento ou orientacao.',
                        ),
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Este pedido foi enviado sem respostas abertas.',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
              if (request.allowResponses)
                FilledButton.icon(
                  onPressed: sending
                      ? null
                      : () async {
                          final body = responseController.text.trim();
                          if (body.length < 3) {
                            _showMessage('Escreve uma resposta valida.');
                            return;
                          }
                          setDialogState(() => sending = true);
                          try {
                            await _backofficeRepository.respondToPrayerRequest(
                              prayerRequestId: request.id,
                              body: body,
                            );
                            responseController.clear();
                            responsesFuture = _backofficeRepository
                                .fetchPrayerRequestResponses(request.id);
                            setDialogState(() {});
                            await _refreshData();
                            _showMessage('Resposta enviada ao membro.');
                          } catch (error) {
                            _showMessage(_friendlyError(error));
                          } finally {
                            if (context.mounted) {
                              setDialogState(() => sending = false);
                            }
                          }
                        },
                  icon: const Icon(Icons.send_outlined),
                  label: Text(sending ? 'A enviar...' : 'Responder'),
                ),
            ],
          );
        },
      ),
    );

    responseController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final church = _managedChurch;
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'Comunhão Igreja',
      debugShowCheckedModeBanner: false,
      theme: _buildChurchAdminTheme(
        primaryColor: church?.primaryColor,
        secondaryColor: church?.secondaryColor,
      ),
      darkTheme: _buildChurchAdminTheme(
        primaryColor: church?.primaryColor,
        secondaryColor: church?.secondaryColor,
        brightness: Brightness.dark,
      ),
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => EnvironmentBanner(
        child: church == null
            ? child ?? const SizedBox.shrink()
            : ChurchIdentityFrame(
                primaryColor: _colorFromHex(church.primaryColor ?? '#0F766E'),
                secondaryColor: church.secondaryColor == null ||
                        church.secondaryColor!.trim().isEmpty
                    ? null
                    : _colorFromHex(church.secondaryColor!),
                child: child ?? const SizedBox.shrink(),
              ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: _GreetingTitle(
            title: _currentUser == null ? 'Comunhão Igreja' : _titleForTab(),
            name: _currentDisplayName,
          ),
          actions: [
            IconButton(
              tooltip: _darkMode ? 'Usar modo claro' : 'Usar modo escuro',
              onPressed: () => _setDarkMode(!_darkMode),
              icon: Icon(
                _darkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
            ),
            IconButton(
              tooltip: 'Termos e privacidade',
              onPressed: () {
                _navigatorKey.currentState?.push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LegalDocumentsPage(),
                  ),
                );
              },
              icon: const Icon(Icons.privacy_tip_outlined),
            ),
            IconButton(
              tooltip: 'Sobre',
              onPressed: () {
                final church = _managedChurch;
                _navigatorKey.currentState?.push(
                  MaterialPageRoute<void>(
                    builder: (_) => ComunhaoAboutPage(
                      churchName: church?.name,
                      churchLogoUrl: church?.logoUrl,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.info_outline),
            ),
            if (_currentUser != null)
              NotificationBell(onNotificationTap: _handleNotificationTap),
            if (_currentUser != null)
              IconButton(
                onPressed: _refreshInProgress ? null : _refreshData,
                icon: _refreshInProgress
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            if (_currentUser != null)
              IconButton(
                onPressed: _busy ? null : _signOut,
                icon: const Icon(Icons.logout),
              ),
          ],
        ),
        body: Stack(
          children: [
            if (!_bootstrapped)
              const Center(child: CircularProgressIndicator())
            else if (_currentUser == null)
              _buildAuthBody()
            else if (_isSubscriptionLocked)
              _buildSubscriptionLockBody()
            else
              _buildBackofficeBody(),
            if (_busy)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 3),
              ),
          ],
        ),
        bottomNavigationBar: _currentUser == null || _isSubscriptionLocked
            ? null
            : LayoutBuilder(
                builder: (context, constraints) => NavigationBar(
                  labelBehavior: constraints.maxWidth < 560
                      ? NavigationDestinationLabelBehavior.onlyShowSelected
                      : NavigationDestinationLabelBehavior.alwaysShow,
                  selectedIndex: _mainNavIndexes.contains(_selectedIndex)
                      ? _mainNavIndexes.indexOf(_selectedIndex)
                      : 0,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedIndex = _mainNavIndexes[index];
                    });
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: 'Visão',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.add_circle_outline),
                      selectedIcon: Icon(Icons.add_circle),
                      label: 'Publicar',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.diversity_3_outlined),
                      selectedIcon: Icon(Icons.diversity_3),
                      label: 'Comunhão',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.assignment_outlined),
                      selectedIcon: Icon(Icons.assignment),
                      label: 'Pedidos',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      selectedIcon: Icon(Icons.account_balance_wallet),
                      label: 'Financeiro',
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  String _titleForTab() {
    return switch (_selectedIndex) {
      1 => 'Publicar',
      2 => 'Pedidos Pastorais',
      3 => 'Membros',
      4 => 'Agenda',
      5 => 'Financeiro',
      6 => 'Comunhão',
      7 => 'ERP da Igreja',
      _ => 'Comunhão Igreja',
    };
  }

  Widget _buildAuthBody() {
    if (_authStage == _AuthStage.otp) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(20),
            shrinkWrap: true,
            children: [
              const WorkspaceHero(
                surface: ComunhaoSurface.churchAdmin,
                title: 'Comunhao Igreja',
                subtitle:
                    'Cria a tua conta, confirma o telefone e regista a tua igreja.',
                icon: Icons.church_outlined,
                color: Color(0xFF0F766E),
              ),
              const SizedBox(height: 24),
              WorkspaceSectionCard(
                title: 'Confirmacao por SMS',
                subtitle: 'Sem email. O telefone e o identificador da conta.',
                child: Form(
                  key: _otpFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Introduz o codigo enviado para ${_pendingPhone == null ? '' : maskPhone(_pendingPhone!)}.',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Codigo SMS',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length < 6) {
                            return 'Introduz o codigo de 6 digitos.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy ? null : _verifyOtp,
                          child: const Text('CONFIRMAR NUMERO'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _busy ? null : _resendOtp,
                          child: const Text('REENVIAR CODIGO'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _authStage = _AuthStage.credentials;
                            _otpController.clear();
                          });
                        },
                        child: const Text('Voltar'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF07265A), Color(0xFFFBF7EC), Color(0xFFFFFDF8)],
          stops: [0, .24, 1],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(20),
            shrinkWrap: true,
            children: [
              const Text('Powered by DeliGo Triunfal, Lda.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 14),
              Center(
                  child:
                      Image.asset('assets/branding/comunhao.png', height: 104)),
              const SizedBox(height: 14),
              Text('Acesso da Igreja',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF082A62))),
              const SizedBox(height: 6),
              const Text('Entre para gerir a sua comunidade',
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(26),
                  border:
                      Border.all(color: const Color(0xFF123979), width: 1.4),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x26082A62),
                        blurRadius: 22,
                        offset: Offset(0, 10))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<_AuthMode>(
                      segments: const [
                        ButtonSegment<_AuthMode>(
                          value: _AuthMode.signup,
                          label: Text('Criar conta'),
                        ),
                        ButtonSegment<_AuthMode>(
                          value: _AuthMode.login,
                          label: Text('Entrar'),
                        ),
                      ],
                      selected: {_authMode},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _authMode = selection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    if (_authMode == _AuthMode.signup)
                      _buildSignupForm()
                    else
                      _buildLoginForm(),
                    const SizedBox(height: 12),
                    const Center(
                        child: Text(
                            'O registo da igreja sera sujeito a verificacao.')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignupForm() {
    return Form(
      key: _signupFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _signupChurchNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Nome da igreja',
                prefixIcon: Icon(Icons.church_outlined)),
            validator: (value) {
              if (value == null || value.trim().length < 3) {
                return 'Introduz o nome da igreja.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _signupNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nome do pastor responsavel',
              helperText: 'Fica visivel como responsavel abaixo da igreja.',
            ),
            validator: (value) {
              if (value == null || value.trim().length < 3) {
                return 'Introduz o nome do pastor responsavel.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _signupPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Numero do gestor',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '+258 84 123 4567'),
            validator: (value) {
              try {
                normalizePhone(value ?? '');
                return null;
              } catch (error) {
                return error.toString().replaceFirst('FormatException: ', '');
              }
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _signupPasswordController,
            obscureText: !_showSignupPassword,
            decoration: InputDecoration(
                labelText: 'Palavra-passe',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                    icon: Icon(_showSignupPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => setState(
                        () => _showSignupPassword = !_showSignupPassword))),
            validator: (value) {
              if (value == null || value.length < 6) {
                return 'A palavra-passe deve ter pelo menos 6 caracteres.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _signupConfirmPasswordController,
            obscureText: !_showSignupPassword,
            decoration:
                const InputDecoration(labelText: 'Confirmar palavra-passe'),
            validator: (value) {
              if (value != _signupPasswordController.text) {
                return 'As palavras-passe nao coincidem.';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submitSignup,
              child: const Text('REGISTAR UMA NOVA IGREJA'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _loginPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Numero do gestor',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '+258 84 123 4567'),
            validator: (value) {
              try {
                normalizePhone(value ?? '');
                return null;
              } catch (error) {
                return error.toString().replaceFirst('FormatException: ', '');
              }
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _loginPasswordController,
            obscureText: !_showLoginPassword,
            decoration: InputDecoration(
                labelText: 'Palavra-passe',
                prefixIcon: const Icon(Icons.lock_outline),
                hintText: 'Digite a sua palavra-passe',
                suffixIcon: IconButton(
                    icon: Icon(_showLoginPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => setState(
                        () => _showLoginPassword = !_showLoginPassword))),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Introduz a palavra-passe.';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submitLogin,
              child: const Text('ENTRAR COMO IGREJA'),
            ),
          ),
          const ComunhaoFooter(compact: true),
        ],
      ),
    );
  }

  Widget _buildBackofficeBody() {
    final pages = [
      _buildOverviewTab(),
      _buildPublishTab(),
      _buildRequestsTab(),
      _buildMembersTab(),
      _buildCalendarTab(),
      _buildWalletTab(),
      _buildPublicationsTab(),
      _buildSubscriptionTab(),
    ];

    if (_selectedIndex == 2 ||
        _selectedIndex == 4 ||
        _selectedIndex == 6 ||
        _selectedIndex == 7) {
      return Column(
        children: [
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: _ErrorCard(message: _loadError!),
            ),
          if (_partialLoadWarnings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _buildPartialSyncCard(),
            ),
          Expanded(child: pages[_selectedIndex]),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_loadError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _ErrorCard(message: _loadError!),
          ),
        if (_partialLoadWarnings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildPartialSyncCard(),
          ),
        pages[_selectedIndex],
      ],
    );
  }

  Widget _buildSubscriptionLockBody() {
    final church = _managedChurch;
    if (church == null) {
      return _buildBackofficeBody();
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        WorkspaceHero(
          surface: ComunhaoSurface.churchAdmin,
          title: church.name,
          subtitle:
              'Sua igreja encontra-se com a subscricao expirada. Para continuar a utilizar a Comunhao, renove um dos planos abaixo.',
          icon: Icons.workspace_premium_outlined,
          color: const Color(0xFF0F766E),
        ),
        const SizedBox(height: 20),
        if (_subscription != null) ...[
          _SubscriptionStatusCard(subscription: _subscription!),
          const SizedBox(height: 16),
        ],
        ChurchSubscriptionPage(
          church: church,
          repository: _backofficeRepository,
          plans: _plans,
          requests: _subscriptionRequests,
          currentPhone: _currentPhone,
          showMessage: _showMessage,
          onChanged: _refreshData,
          initialCheckoutPlanCode: _pendingCheckoutPlanCode,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _busy ? null : _signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sair'),
        ),
      ],
    );
  }

  Widget _buildPartialSyncCard() {
    final visibleWarnings = _partialLoadWarnings.take(3).toList();
    final hiddenCount = _partialLoadWarnings.length - visibleWarnings.length;
    return WorkspaceSectionCard(
      title: 'Dados parcialmente sincronizados',
      subtitle:
          'A igreja continua carregada. Apenas alguns modulos ainda nao responderam agora.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...visibleWarnings.map(
            (warning) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.info_outline, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(warning)),
                ],
              ),
            ),
          ),
          if (hiddenCount > 0)
            Text(
                'Mais $hiddenCount modulo(s) serao atualizados ao recarregar.'),
        ],
      ),
    );
  }

  Widget _buildRequestsTab() {
    final church = _managedChurch;
    if (church == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: WorkspaceSectionCard(
            title: 'Igreja ainda nao carregada',
            subtitle:
                'Quando a Igreja Vida Nova estiver sincronizada, esta aba mostra pedidos de entrada, pedidos pastorais e acompanhamento.',
            child: Text(
              'Se a igreja ja foi aprovada, atualiza a pagina ou confirma a ligacao ao Supabase.',
            ),
          ),
        ),
      );
    }

    return ChurchRequestsPage(
      church: church,
      members: _churchMembers,
      readOnly: _isChurchReadOnly,
    );
  }

  Widget _buildPublishTab() {
    final church = _managedChurch;
    if (church == null) {
      return _buildApplicationTab();
    }
    final recentItems = _buildPastorRecentItems();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WorkspaceHero(
          surface: ComunhaoSurface.churchAdmin,
          title: 'Publicar',
          subtitle:
              'Cria mensagens que chegam aos membros e acompanha comentários, améns e partilhas.',
          icon: Icons.add_circle_outline,
          color: Color(0xFF0F766E),
        ),
        const SizedBox(height: 20),
        WorkspaceSectionCard(
          title: 'O que deseja publicar?',
          subtitle:
              'Escolha uma ação. Tudo que for publicado aparece nas publicações recentes dos membros.',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 640;
              final actions = [
                _PastorPublishAction(
                  icon: Icons.campaign_outlined,
                  title: 'Novo anúncio',
                  description: 'Aviso curto, comunicado ou informação urgente.',
                  label: 'Anunciar',
                  onTap: () => _runUiAction(() => _openAnnouncementEditor()),
                ),
                _PastorPublishAction(
                  icon: Icons.event_available_outlined,
                  title: 'Novo evento/culto',
                  description:
                      'Culto, congresso, vigília, batismo, reunião ou encontro.',
                  label: 'Publicar evento',
                  onTap: () => _runUiAction(() => _openEventEditor()),
                ),
                _PastorPublishAction(
                  icon: Icons.library_books_outlined,
                  title: 'Nova publicação',
                  description:
                      'Pregação, devocional, estudo bíblico, vídeo, áudio ou documento.',
                  label: 'Publicar mensagem',
                  onTap: () => _runUiAction(
                    () => _openPastoralPublicationEditor(),
                  ),
                ),
                _PastorPublishAction(
                  icon: Icons.volunteer_activism_outlined,
                  title: 'Nova campanha',
                  description:
                      'Campanha financeira ou de apoio com imagem e meta.',
                  label: 'Criar campanha',
                  onTap: () => _runUiAction(() => _openCampaignEditor()),
                ),
              ];

              if (compact) {
                return Column(
                  children: actions
                      .map(
                        (action) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: action,
                        ),
                      )
                      .toList(),
                );
              }
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: actions
                    .map(
                      (action) => SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: action,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        WorkspaceSectionCard(
          title: 'Publicações da igreja',
          subtitle:
              'Últimas mensagens criadas pela igreja, com a mesma conversa que os membros veem.',
          child: recentItems.isEmpty
              ? const Text('Ainda não existem publicações da igreja.')
              : Column(
                  children: recentItems
                      .take(6)
                      .map(
                        (item) => _PastorRecentItemTile(
                          item: item,
                          church: church,
                          readOnly: _isChurchReadOnly,
                          onChanged: _refreshData,
                          onMessage: _showMessage,
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 16),
        WorkspaceSectionCard(
          title: 'Acompanhar resposta',
          subtitle:
              'Depois de publicar, veja rapidamente a resposta da comunidade.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _selectedIndex = 6),
                icon: const Icon(Icons.diversity_3_outlined),
                label: const Text('Ver Comunhão'),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _selectedIndex = 2),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Ver pedidos'),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _selectedIndex = 4),
                icon: const Icon(Icons.event_outlined),
                label: const Text('Abrir agenda'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMembersTab() {
    return ChurchMembersPage(
      members: _churchMembers,
      pendingJoinRequests: 0,
      readOnly: _isChurchReadOnly,
      onManageMember: _manageMember,
    );
  }

  Widget _buildCalendarTab() {
    final church = _managedChurch;
    if (church == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('A agenda aparece depois da igreja ser aprovada.'),
        ),
      );
    }

    return ChurchCalendarPage(
      church: church,
      events: _events,
      backofficeRepository: _backofficeRepository,
      calendarRepository: _calendarRepository,
      onChanged: _refreshData,
    );
  }

  Widget _buildPublicationsTab() {
    final church = _managedChurch;
    if (church == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: WorkspaceSectionCard(
            title: 'Igreja ainda nao carregada',
            subtitle:
                'As publicacoes ficam disponiveis assim que a igreja aprovada for sincronizada.',
            child: Text(
              'O pastor podera criar pregacoes, devocionais, estudos e avisos.',
            ),
          ),
        ),
      );
    }

    return ChurchCommunityModerationPage(
      church: church,
      readOnly: _isChurchReadOnly,
      members: _churchMembers,
      announcements: _announcements,
      events: _events,
      campaigns: _campaigns,
      publications: _publications,
      prayerRequests: _prayerRequests,
    );
  }

  Future<void> _openPastoralPublicationEditor([
    PastoralPublication? publication,
  ]) async {
    final church = _managedChurch;
    if (church == null || _isChurchReadOnly) {
      return;
    }
    final draft = await showDialog<PublicationDraft>(
      context: _dialogContext,
      barrierDismissible: false,
      builder: (context) => PublicationEditorDialog(
        churchId: church.id,
        publication: publication,
      ),
    );
    if (!mounted || draft == null) {
      return;
    }
    try {
      await PublicationRepository().savePublication(draft);
      if (!mounted) return;
      await _refreshData();
      if (!mounted) return;
      _showMessage(
        draft.status == 'published'
            ? 'Publicacao publicada.'
            : 'Publicacao guardada.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('Nao foi possivel guardar a publicacao agora.');
    }
  }

  List<_PastorRecentItem> _buildPastorRecentItems() {
    final churchLogoUrl = _managedChurch?.logoUrl;
    final publicationsById = {
      for (final publication in _publications) publication.id: publication,
    };
    final mirroredPublicationIds = <String>{
      ..._announcements
          .map((item) => item.pastoralPublicationId)
          .whereType<String>(),
      ..._events.map((item) => item.pastoralPublicationId).whereType<String>(),
      ..._campaigns
          .map((item) => item.pastoralPublicationId)
          .whereType<String>(),
    };
    final items = <_PastorRecentItem>[
      ..._publications.where((publication) {
        return !mirroredPublicationIds.contains(publication.id);
      }).map(
        (publication) => _PastorRecentItem(
          id: 'publication-${publication.id}',
          publication: publication,
          title: publication.title,
          body: publication.summary?.trim().isNotEmpty == true
              ? publication.summary!.trim()
              : publication.content,
          typeLabel: publication.typeLabel,
          statusLabel: publication.statusLabel,
          icon: _iconForPastoralType(publication.publicationType),
          createdAt: publication.createdAt,
          imageUrl: publication.coverImageUrl,
          authorAvatarUrl: publication.authorAvatarUrl ?? churchLogoUrl,
        ),
      ),
      ..._announcements.map(
        (announcement) => _PastorRecentItem(
          id: 'announcement-${announcement.id}',
          publication: publicationsById[announcement.pastoralPublicationId],
          title: announcement.title,
          body: announcement.body,
          typeLabel: announcement.pinned ? 'Anuncio fixado' : 'Anuncio',
          statusLabel: announcement.isPublished ? 'Publicado' : 'Rascunho',
          icon: announcement.pinned
              ? Icons.push_pin_outlined
              : Icons.campaign_outlined,
          createdAt: announcement.createdAt,
          imageUrl: announcement.imageUrl,
          authorAvatarUrl: churchLogoUrl,
        ),
      ),
      ..._events.map(
        (event) => _PastorRecentItem(
          id: 'event-${event.id}',
          publication: publicationsById[event.pastoralPublicationId],
          title: event.title,
          body: [
            event.eventTypeLabel,
            'Marcado para ${_formatDateTime(event.startsAt)}',
            if (event.location?.trim().isNotEmpty == true) event.location!,
            if (event.description?.trim().isNotEmpty == true)
              event.description!,
          ].join('\n'),
          typeLabel: event.eventTypeLabel,
          statusLabel: event.statusLabel,
          icon: Icons.event_available_outlined,
          createdAt: event.createdAt,
          imageUrl: event.coverImageUrl,
          authorAvatarUrl: churchLogoUrl,
        ),
      ),
      ..._campaigns.map(
        (campaign) => _PastorRecentItem(
          id: 'campaign-${campaign.id}',
          publication: publicationsById[campaign.pastoralPublicationId],
          title: campaign.title,
          body: [
            if (campaign.description?.trim().isNotEmpty == true)
              campaign.description!,
            '${campaign.progressPercent}% - ${_formatMoney(campaign.raisedAmount)} arrecadado',
            if (campaign.targetAmount != null)
              'Meta: ${_formatMoney(campaign.targetAmount!)}',
          ].join('\n'),
          typeLabel: 'Campanha',
          statusLabel: campaign.statusLabel,
          icon: Icons.volunteer_activism_outlined,
          createdAt: campaign.createdAt,
          imageUrl: campaign.imageUrl,
          authorAvatarUrl: churchLogoUrl,
        ),
      ),
    ];
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  IconData _iconForPastoralType(String type) => switch (type) {
        'sermon' => Icons.record_voice_over_outlined,
        'devotional' => Icons.wb_sunny_outlined,
        'bible_study' => Icons.menu_book_outlined,
        'video' => Icons.play_circle_outline,
        'audio' => Icons.headphones_outlined,
        'document' => Icons.description_outlined,
        'live_stream' => Icons.live_tv_outlined,
        'urgent_notice' => Icons.priority_high_outlined,
        _ => Icons.article_outlined,
      };

  Widget _buildOverviewTab() {
    final church = _managedChurch;
    final application = _activeApplication;
    final subscription = _subscription;
    final recentItems = _buildPastorRecentItems();
    if (church != null) {
      final commentCount = _publications.fold<int>(
        0,
        (sum, item) => sum + item.commentCount,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChurchIdentityBanner(
            churchName: church.name,
            logoUrl: church.logoUrl,
            primaryColor: _colorFromHex(church.primaryColor ?? '#0F766E'),
            secondaryColor: church.secondaryColor == null ||
                    church.secondaryColor!.trim().isEmpty
                ? null
                : _colorFromHex(church.secondaryColor!),
            subtitle: 'Publicar, responder e acompanhar a comunidade.',
          ),
          const SizedBox(height: 16),
          if (subscription != null && subscription.effectiveStatus == 'trial')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TrialCountdownBanner(subscription: subscription),
            ),
          WorkspaceSectionCard(
            title: 'Criar para a comunidade',
            subtitle:
                'Tudo que publicar aparece para os membros em tempo real.',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () =>
                      _runUiAction(() => _openAnnouncementEditor()),
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('Anúncio'),
                ),
                FilledButton.icon(
                  onPressed: () => _runUiAction(() => _openEventEditor()),
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('Evento/culto'),
                ),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _runUiAction(() => _openCampaignEditor()),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Campanha'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () =>
                          _runUiAction(() => _openPastoralPublicationEditor()),
                  icon: const Icon(Icons.library_books_outlined),
                  label: const Text('Publicação'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          WorkspaceSectionCard(
            title: commentCount + _recentPrayerCount == 0
                ? 'Tudo em ordem'
                : 'Precisa de atenção',
            subtitle: 'Comentários, pedidos, agenda e saldo.',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _PastorFocusChip(
                  icon: Icons.chat_bubble_outline,
                  label: 'Comentários',
                  value: '$commentCount',
                  onTap: () => setState(() => _selectedIndex = 6),
                ),
                _PastorFocusChip(
                  icon: Icons.volunteer_activism_outlined,
                  label: 'Pedidos',
                  value: '$_recentPrayerCount',
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
                _PastorFocusChip(
                  icon: Icons.event_available_outlined,
                  label: 'Agenda',
                  value: '$_upcomingEventCount',
                  onTap: () => setState(() => _selectedIndex = 4),
                ),
                _PastorFocusChip(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Saldo',
                  value: _formatMoney(_walletAvailableBalance),
                  onTap: () => setState(() => _selectedIndex = 5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          WorkspaceSectionCard(
            title: 'Publicações recentes',
            subtitle: 'Últimos conteúdos publicados pela igreja.',
            child: recentItems.isEmpty
                ? const Text('Ainda não existem publicações recentes.')
                : Column(
                    children: recentItems
                        .take(6)
                        .map(
                          (item) => _PastorRecentItemTile(
                            item: item,
                            church: church,
                            readOnly: _isChurchReadOnly,
                            onChanged: _refreshData,
                            onMessage: _showMessage,
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (church != null)
          ChurchIdentityBanner(
            churchName: church.name,
            logoUrl: church.logoUrl,
            primaryColor: _colorFromHex(church.primaryColor ?? '#0F766E'),
            secondaryColor: church.secondaryColor == null ||
                    church.secondaryColor!.trim().isEmpty
                ? null
                : _colorFromHex(church.secondaryColor!),
            subtitle: 'Visão da igreja, publicações e cuidado pastoral.',
          )
        else
          const WorkspaceHero(
            surface: ComunhaoSurface.churchAdmin,
            title: 'Comunhao Igreja',
            subtitle: 'Registo, aprovacao e plano da igreja.',
            icon: Icons.church_outlined,
            color: Color(0xFF0F766E),
          ),
        const SizedBox(height: 20),
        if (subscription != null && subscription.effectiveStatus == 'trial')
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _TrialCountdownBanner(subscription: subscription),
          ),
        WorkspaceSectionCard(
          title: 'Acoes rapidas',
          subtitle:
              'Estes botoes criam conteudo real da Igreja Vida Nova e sincronizam com o app dos membros.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => _runUiAction(() => _openAnnouncementEditor()),
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Novo anuncio'),
              ),
              FilledButton.icon(
                onPressed: () => _runUiAction(() => _openEventEditor()),
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('Novo evento'),
              ),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _runUiAction(() => _openCampaignEditor()),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Nova campanha'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () =>
                        _runUiAction(() => _openPastoralPublicationEditor()),
                icon: const Icon(Icons.library_books_outlined),
                label: const Text('Nova publicacao'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        WorkspaceSectionCard(
          title: 'Hoje para responder',
          subtitle:
              'O essencial da interação entre igreja e membros, sem procurar em várias telas.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _PastorFocusChip(
                icon: Icons.chat_bubble_outline,
                label: 'Comentários',
                value:
                    '${_publications.fold<int>(0, (sum, item) => sum + item.commentCount)}',
                onTap: () => setState(() => _selectedIndex = 6),
              ),
              _PastorFocusChip(
                icon: Icons.volunteer_activism_outlined,
                label: 'Pedidos',
                value: '$_recentPrayerCount',
                onTap: () => setState(() => _selectedIndex = 2),
              ),
              _PastorFocusChip(
                icon: Icons.event_available_outlined,
                label: 'Agenda',
                value: '$_upcomingEventCount',
                onTap: () => setState(() => _selectedIndex = 4),
              ),
              _PastorFocusChip(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Saldo',
                value: _formatMoney(_walletAvailableBalance),
                onTap: () => setState(() => _selectedIndex = 5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        DailyScriptureSplashCard(
          churchId: church?.id,
          logoAssetPath: 'assets/branding/comunhao.png',
          compact: true,
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            WorkspaceMetricCard(
              label: 'Papel atual',
              value: church?.role.toUpperCase() ??
                  (_platformRoles.isEmpty ? 'PASTOR' : _platformRoles.first),
              icon: Icons.badge_outlined,
            ),
            WorkspaceMetricCard(
              label: 'Membros ativos',
              value: '$_activeMemberCount',
              icon: Icons.groups_outlined,
            ),
            WorkspaceMetricCard(
              label: 'Pastores',
              value: '$_pastorCount',
              icon: Icons.church_outlined,
            ),
            WorkspaceMetricCard(
              label: 'Plano',
              value: subscription?.planLabel ?? 'SEM PLANO',
              icon: Icons.workspace_premium_outlined,
            ),
            WorkspaceMetricCard(
              label: 'Eventos',
              value: '$_upcomingEventCount',
              icon: Icons.event_outlined,
            ),
            WorkspaceMetricCard(
              label: 'Pedidos de oracao',
              value: '$_recentPrayerCount',
              icon: Icons.favorite_border,
            ),
            WorkspaceMetricCard(
              label: 'Envios na fila',
              value: '$_queuedCommunicationCount',
              icon: Icons.send_outlined,
            ),
            WorkspaceMetricCard(
              label: 'Visitantes',
              value: '$_visitorCount',
              icon: Icons.person_add_alt_1_outlined,
            ),
            WorkspaceMetricCard(
              label: 'Receitas do mes',
              value: _formatMoney(_walletMonthRevenue),
              icon: Icons.payments_outlined,
            ),
            WorkspaceMetricCard(
              label: 'Despesas do mes',
              value: _formatMoney(_expenseMonthTotal),
              icon: Icons.receipt_long_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (church != null) ...[
          WorkspaceSectionCard(
            title: church.name,
            subtitle: 'A tua igreja ja esta aprovada e ativa na plataforma.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.qr_code_outlined),
                  title: const Text('Codigo da igreja'),
                  subtitle: Text(church.joinCode ?? 'Ainda a ser gerado'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Cidade'),
                  subtitle: Text(church.city ?? 'Sem cidade'),
                ),
                if (subscription != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_clock_outlined),
                    title: const Text('Estado de acesso'),
                    subtitle: Text(
                      subscription.isReadOnlyForChurchAdmin
                          ? 'Painel em modo leitura ate regularizacao.'
                          : 'Acesso total ao painel da igreja.',
                    ),
                  ),
              ],
            ),
          ),
          if (subscription != null) ...[
            const SizedBox(height: 16),
            _SubscriptionStatusCard(subscription: subscription),
          ],
          const SizedBox(height: 16),
          WorkspaceSectionCard(
            title: 'Saude da igreja',
            subtitle:
                'Prioridades operacionais para manter membros, eventos, comunicacao e carteira em dia.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ChurchHealthScoreCard(
                  score: _churchHealthScore,
                  label: _churchHealthLabel,
                  color: _churchHealthColor(context),
                ),
                const SizedBox(height: 16),
                ..._churchHealthItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ChurchHealthTile(item: item),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WorkspaceSectionCard(
            title: 'Vida da comunidade',
            subtitle:
                'Aniversarios, ministerios ativos e visitantes recentes num unico bloco.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.cake_outlined, size: 18),
                      label: Text(
                          '${_birthdayMembers.length} aniversarios proximos'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.groups_2_outlined, size: 18),
                      label: Text('$_activeMinistryCount ministerios ativos'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                      label: Text('$_assetItemCount itens em patrimonio'),
                    ),
                  ],
                ),
                if (_birthdayMembers.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Proximos aniversarios',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ..._birthdayMembers.map(
                    (member) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.cake_outlined),
                      ),
                      title: Text(member.fullName),
                      subtitle: Text(
                        '${member.roleLabel} • ${_formatBirthday(member.birthDate!)}',
                      ),
                    ),
                  ),
                ],
                if (_visitors.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Visitantes recentes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ..._visitors.take(3).map(
                        (visitor) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_add_alt_1_outlined),
                          ),
                          title: Text(visitor.fullName),
                          subtitle: Text(
                            '${visitor.statusLabel} • ${_formatDate(visitor.firstVisitAt)}',
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          WorkspaceSectionCard(
            title: 'Publicacoes recentes',
            subtitle:
                'Anuncios, eventos, campanhas e pastorais em ordem de criacao, igual ao app dos membros.',
            child: recentItems.isEmpty
                ? const Text('Ainda nao existem publicacoes recentes.')
                : Column(
                    children: recentItems
                        .take(12)
                        .map(
                          (item) => _PastorRecentItemTile(
                            item: item,
                            church: church,
                            readOnly: _isChurchReadOnly,
                            onChanged: _refreshData,
                            onMessage: _showMessage,
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),
          WorkspaceSectionCard(
            title: 'Comunicacao da igreja',
            subtitle:
                '$_publishedAnnouncementCount anuncios publicados aparecem automaticamente no app do membro.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openAnnouncementEditor(),
                      icon: const Icon(Icons.campaign_outlined),
                      label: const Text('Novo anuncio'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_announcements.isEmpty)
                  const Text('Ainda nao existem anuncios criados.')
                else
                  Column(
                    children: _announcements.take(3).map((announcement) {
                      return Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              child: Icon(
                                announcement.pinned
                                    ? Icons.push_pin_outlined
                                    : Icons.campaign_outlined,
                              ),
                            ),
                            title: Text(announcement.title),
                            subtitle: Text(
                              '${announcement.isPublished ? 'Publicado' : 'Rascunho'} • ${_formatDateTime(announcement.createdAt)}\n${announcement.body}',
                            ),
                          ),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _openAnnouncementEditor(
                                          announcement,
                                        ),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Editar'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _deleteAnnouncement(announcement),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Apagar'),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                        ],
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WorkspaceSectionCard(
            title: 'Agenda da igreja',
            subtitle:
                'Cultos, congressos, vigílias e outros eventos saem daqui para o app do membro.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openEventEditor(),
                      icon: const Icon(Icons.event_available_outlined),
                      label: const Text('Novo evento'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_events.isEmpty)
                  const Text('Ainda nao existem eventos criados.')
                else
                  Column(
                    children: _events.take(4).map((event) {
                      return Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              child: Icon(Icons.event_outlined),
                            ),
                            title: Text(event.title),
                            subtitle: Text(
                              '${event.eventTypeLabel} • ${_formatDateTime(event.startsAt)}${event.location == null ? '' : '\n${event.location}'}${event.description == null ? '' : '\n${event.description}'}',
                            ),
                          ),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _openEventEditor(event),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Editar'),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    _busy ? null : () => _deleteEvent(event),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Apagar'),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                        ],
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WorkspaceSectionCard(
            title: 'Pedidos de oracao recentes',
            subtitle:
                'Pedidos enviados pelos membros aparecem aqui com nome, data, mensagem e resposta pastoral.',
            child: _prayerRequests.isEmpty
                ? const Text('Ainda nao existem pedidos de oracao.')
                : Column(
                    children: _prayerRequests.map((request) {
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  child: Icon(
                                    request.isPrivate
                                        ? Icons.lock_outline
                                        : Icons.favorite_border,
                                  ),
                                ),
                                title: Text(request.title),
                                subtitle: Text(
                                  '${request.requesterLabel} - ${_formatDateTime(request.createdAt)}\n${request.description}',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Chip(
                                  label: Text(request.statusLabel),
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(label: Text(request.visibilityLabel)),
                                  if (request.allowResponses)
                                    const Chip(label: Text('Aceita resposta')),
                                  FilledButton.tonalIcon(
                                    onPressed: () =>
                                        _openPrayerRequest(request),
                                    icon: const Icon(Icons.mark_chat_read),
                                    label: const Text('Abrir e responder'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ] else if (application != null) ...[
          WorkspaceSectionCard(
            title: application.churchName,
            subtitle: 'O teu pedido ja existe e esta a ser acompanhado aqui.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.pending_actions_outlined),
                  title: const Text('Estado atual'),
                  subtitle: Text(application.statusLabel),
                ),
                if (application.reviewNotes != null &&
                    application.reviewNotes!.trim().isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.sticky_note_2_outlined),
                    title: const Text('Observacao da equipa Comunhao'),
                    subtitle: Text(application.reviewNotes!),
                  ),
              ],
            ),
          ),
        ] else
          const WorkspaceSectionCard(
            title: 'Sem pedido criado',
            subtitle:
                'Usa o separador Pedido para registar a igreja e envia-la para aprovacao.',
            child: Text(
              'Preenche os dados da igreja, metodos de pagamento e branding. O estado inicial sera pendente.',
            ),
          ),
      ],
    );
  }

  Widget _buildApplicationTab() {
    final church = _managedChurch;
    final application = _activeApplication;

    if (church != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkspaceSectionCard(
            title: 'Perfil e aprovacao da igreja',
            subtitle: 'Registo oficial, aprovacao, codigo, contacto e plano.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${church.name} ja esta ativa na app Comunhao. A operacao diaria fica nas abas Pedidos, Membros, Agenda, Financeiro, Publicacoes e ERP.',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _editChurchName(church),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar nome da igreja'),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () => _editChurchProfile(church),
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Editar perfil completo'),
                ),
                const SizedBox(height: 12),
                Text('Codigo da igreja: ${church.joinCode ?? 'A gerar'}'),
                const SizedBox(height: 8),
                Text('Cidade: ${church.city ?? 'Sem cidade'}'),
                const SizedBox(height: 8),
                Text(
                  'Telefone: ${_activeApplication?.phone ?? _currentPhone ?? 'Sem telefone'}',
                ),
                const SizedBox(height: 8),
                Text('Plano atual: ${_subscription?.planLabel ?? 'Sem plano'}'),
              ],
            ),
          ),
          if (_subscription != null) ...[
            const SizedBox(height: 16),
            _SubscriptionStatusCard(subscription: _subscription!),
          ],
          if (_plans.isNotEmpty) ...[
            const SizedBox(height: 16),
            _PlanCatalogCard(
              plans: _plans,
              currentPlanCode: _subscription?.planCode,
              onOpenCheckout: (plan) => setState(() {
                _pendingCheckoutPlanCode = plan.code;
                _selectedIndex = 5;
              }),
            ),
          ],
          if (_subscription?.isReadOnlyForChurchAdmin == true) ...[
            const SizedBox(height: 16),
            const WorkspaceSectionCard(
              title: 'Modo leitura',
              subtitle:
                  'A subscricao esta suspensa ou cancelada. Os dados continuam guardados.',
              child: Text(
                'Efetua o pagamento e aguarda a reativacao pela equipa Comunhao para voltar a editar.',
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildPastorAccountDangerCard(),
        ],
      );
    }

    if (application != null && application.status == 'submitted') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkspaceSectionCard(
            title: 'Pedido enviado',
            subtitle:
                'A sua igreja foi enviada para aprovacao. Recebera uma notificacao assim que for analisada.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(application.churchName),
                const SizedBox(height: 8),
                Text('Cidade: ${application.city}'),
                const SizedBox(height: 8),
                Text('Estado: ${application.statusLabel}'),
                if (application.submittedAt != null) ...[
                  const SizedBox(height: 8),
                  Text('Enviado em: ${_formatDate(application.submittedAt!)}'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildPastorAccountDangerCard(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (application != null &&
            application.reviewNotes != null &&
            application.reviewNotes!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: WorkspaceSectionCard(
              title: 'Observacao da revisao',
              subtitle: application.statusLabel,
              child: Text(application.reviewNotes!),
            ),
          ),
        WorkspaceSectionCard(
          title: application == null ? 'Registrar igreja' : 'Editar pedido',
          subtitle:
              'Preenche a base do pedido. A igreja nasce pendente e so entra na plataforma depois da aprovacao.',
          child: Form(
            key: _applicationFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _churchNameController,
                  decoration:
                      const InputDecoration(labelText: 'Nome da igreja'),
                  validator: (value) {
                    if (value == null || value.trim().length < 4) {
                      return 'Introduz o nome da igreja.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: 'Cidade'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Introduz a cidade.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _provinceController,
                  decoration: const InputDecoration(labelText: 'Provincia'),
                ),
                const SizedBox(height: 16),
                _ApplicationLogoPicker(
                  logoUrl: _logoUrlController.text.trim(),
                  onPickGallery: _busy
                      ? null
                      : () => _pickApplicationLogo(ImageSource.gallery),
                  onPickCamera: _busy
                      ? null
                      : () => _pickApplicationLogo(ImageSource.camera),
                  onClear: () => setState(_logoUrlController.clear),
                ),
                const SizedBox(height: 16),
                _ColorSelector(
                  title: 'Cor primaria',
                  controller: _primaryColorController,
                  fallback: '#0F766E',
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 12),
                _ColorSelector(
                  title: 'Cor secundaria',
                  controller: _secondaryColorController,
                  fallback: '#115E59',
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 16),
                _AutoPaymentMethodCard(
                  phone: _accountPhone ?? _signupPhoneController.text,
                  provider: _providerForPhoneOrNull(
                    _accountPhone ?? _signupPhoneController.text,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _saveChurchApplication(submitAfter: false),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar rascunho'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _busy
                          ? null
                          : () => _saveChurchApplication(submitAfter: true),
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Enviar para aprovacao'),
                    ),
                    if (application != null && application.status == 'rejected')
                      OutlinedButton.icon(
                        onPressed:
                            _busy ? null : _startNewApplicationFromRejected,
                        icon: const Icon(Icons.refresh_outlined),
                        label: const Text('Novo pedido'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildPastorAccountDangerCard(),
      ],
    );
  }

  Widget _buildPastorAccountDangerCard() {
    final church = _managedChurch;
    return WorkspaceSectionCard(
      title: 'Zona de risco',
      subtitle:
          'Acoes permanentes para a conta do pastor e para a igreja selecionada.',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: _deleteAccount,
            icon: const Icon(Icons.person_remove_outlined),
            label: const Text('Apagar minha conta'),
          ),
          if (church != null)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: _deleteChurch,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Apagar igreja'),
            ),
        ],
      ),
    );
  }

  String _providerForPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final local = digits.startsWith('258') ? digits.substring(3) : digits;
    if (local.startsWith('87')) {
      return 'emola';
    }
    return 'mpesa';
  }

  String? _providerForPhoneOrNull(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return null;
    }
    try {
      return _providerForPhone(normalizePhone(phone));
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickApplicationLogo(ImageSource source) async {
    final userId = _currentUserId;
    if (userId == null) {
      _showMessage('Cria ou entra na conta antes de carregar o logotipo.');
      return;
    }
    setState(() => _busy = true);
    try {
      final selected = source == ImageSource.gallery
          ? await _pickGalleryImage()
          : await _pickCameraImage(
              imageQuality: 86,
              maxWidth: 1200,
              maxHeight: 1200,
            );
      if (selected == null) return;
      final (name, bytes) = selected;
      if (bytes.length > 5 * 1024 * 1024) {
        throw StateError('O logotipo deve ter no maximo 5 MB.');
      }
      final extension = _extensionFor(name);
      final path =
          '$userId/applications/logo-${DateTime.now().millisecondsSinceEpoch}.$extension';
      final client = Supabase.instance.client;
      await client.storage.from(_applicationBrandingBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: _contentTypeFor(extension)),
          );
      final url =
          client.storage.from(_applicationBrandingBucket).getPublicUrl(path);
      if (!mounted) {
        return;
      }
      setState(() => _logoUrlController.text = url);
    } catch (error) {
      if (mounted) {
        _showMessage(_friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openCampaignEditor([ManagedCampaign? current]) async {
    final church = _managedChurch;
    if (church == null) {
      _showMessage('A igreja ainda nao foi carregada. Atualiza a pagina.');
      return;
    }
    if (_isChurchReadOnly) {
      _showMessage(
        'A igreja esta em modo leitura. Regulariza a subscricao para criar campanhas.',
      );
      return;
    }

    final titleController = TextEditingController(text: current?.title ?? '');
    final descriptionController =
        TextEditingController(text: current?.description ?? '');
    final imageController =
        TextEditingController(text: current?.imageUrl ?? '');
    final targetController =
        TextEditingController(text: current?.targetAmount?.toString() ?? '');
    var uploadingImage = false;

    final saved = await showDialog<bool>(
      context: _dialogContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(current == null ? 'Nova campanha' : 'Editar campanha'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Titulo'),
                  ),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Descricao'),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Meta MZN'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: imageController,
                    decoration: const InputDecoration(labelText: 'Imagem/URL'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: uploadingImage
                              ? null
                              : () async {
                                  setModalState(() => uploadingImage = true);
                                  try {
                                    final url = await _pickAndUploadImage(
                                      churchId: church.id,
                                      folder: 'campaigns',
                                    );
                                    if (url != null) {
                                      imageController.text = url;
                                    }
                                  } catch (error) {
                                    if (context.mounted) {
                                      _showMessage(_friendlyError(error));
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setModalState(
                                          () => uploadingImage = false);
                                    }
                                  }
                                },
                          icon: uploadingImage
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.photo_library_outlined),
                          label: const Text('Galeria'),
                        ),
                      ),
                      if (imageController.text.trim().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Remover imagem',
                          onPressed: uploadingImage
                              ? null
                              : () => setModalState(imageController.clear),
                          icon: const Icon(Icons.close_outlined),
                        ),
                      ],
                    ],
                  ),
                  if (imageController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageController.text.trim(),
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 80,
                          alignment: Alignment.center,
                          color:
                              Theme.of(context).colorScheme.surfaceContainerLow,
                          child: const Text('Imagem sera carregada pela URL.'),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.save_outlined),
              label: Text(current == null ? 'Publicar campanha' : 'Atualizar'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) {
      titleController.dispose();
      descriptionController.dispose();
      imageController.dispose();
      targetController.dispose();
      return;
    }

    if (titleController.text.trim().length < 3) {
      titleController.dispose();
      descriptionController.dispose();
      imageController.dispose();
      targetController.dispose();
      _showMessage('Introduz um titulo valido para a campanha.');
      return;
    }

    setState(() => _busy = true);
    try {
      await _backofficeRepository.saveChurchCampaign(
        campaignId: current?.id,
        churchId: church.id,
        title: titleController.text,
        description: descriptionController.text,
        imageUrl: imageController.text,
        targetAmount: num.tryParse(targetController.text.replaceAll(',', '.')),
        startAt: current?.startAt ?? DateTime.now(),
        endAt: current?.endAt,
        active: true,
        status: current?.status == 'draft' ? 'published' : 'active',
      );
      if (!mounted) {
        return;
      }
      await _refreshData();
      _showMessage('Campanha publicada com sucesso.');
    } catch (error) {
      if (mounted) {
        _showMessage(_friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<String?> _pickAndUploadImage({
    required String churchId,
    required String folder,
  }) async {
    final selected = await _pickGalleryImage();
    if (selected == null) return null;
    final (name, bytes) = selected;
    if (bytes.length > 5 * 1024 * 1024) {
      throw StateError(
        'A imagem ainda ficou maior que 5 MB. Escolhe uma imagem menor.',
      );
    }

    final extension = _extensionFor(name);
    final path =
        '$churchId/$folder/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final client = Supabase.instance.client;
    await client.storage.from(_mediaBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _contentTypeFor(extension)),
        );
    return client.storage.from(_mediaBucket).getPublicUrl(path);
  }

  Future<(String, Uint8List)?> _pickGalleryImage() async {
    final nativeFile = await pickUploadFile(
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      accept: 'image/jpeg,image/png,image/webp',
    );
    if (nativeFile != null) {
      return (nativeFile.name, nativeFile.bytes);
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return null;
    return (file.name, bytes);
  }

  Future<(String, Uint8List)?> _pickCameraImage({
    required int imageQuality,
    required double maxWidth,
    required double maxHeight,
  }) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: imageQuality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    if (file == null) return null;
    return (file.name, await file.readAsBytes());
  }

  String _extensionFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  String _contentTypeFor(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  Future<void> _archiveCampaign(ManagedCampaign campaign) async {
    if (_isChurchReadOnly) {
      _showMessage(
        'A igreja esta em modo leitura. Regulariza a subscricao para encerrar campanhas.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await _backofficeRepository.archiveChurchCampaign(campaign.id);
      if (!mounted) {
        return;
      }
      await _refreshData();
      _showMessage('Campanha arquivada.');
    } catch (error) {
      if (mounted) {
        _showMessage(_friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _buildWalletTab() {
    final church = _managedChurch;
    if (church == null) {
      return const WorkspaceSectionCard(
        title: 'Igreja ainda nao carregada',
        subtitle:
            'A carteira da igreja aparece assim que a igreja aprovada for sincronizada.',
        child: Text(
          'Quando a Igreja Vida Nova carregar, vais ver saldos, contribuicoes, despesas, levantamentos e plano.',
        ),
      );
    }

    return ChurchFinancePage(
      church: church,
      financeRepository: _financeRepository,
      backofficeRepository: _backofficeRepository,
      walletDashboard: _walletDashboard,
      walletLedger: _walletLedger,
      withdrawals: _walletWithdrawals,
      expenses: _expenses,
      campaigns: _campaigns,
      plans: _plans,
      subscriptionRequests: _subscriptionRequests,
      currentPhone: _currentPhone,
      isReadOnly: _isChurchReadOnly,
      showMessage: _showMessage,
      onChanged: _refreshData,
      onEditCampaign: _openCampaignEditor,
      onArchiveCampaign: _archiveCampaign,
      initialCheckoutPlanCode: _pendingCheckoutPlanCode,
    );
  }

  Widget _buildSubscriptionTab() {
    final church = _managedChurch;

    if (church == null) {
      return const WorkspaceSectionCard(
        title: 'Igreja ainda nao carregada',
        subtitle:
            'As operacoes ERP aparecem quando a igreja aprovada for sincronizada.',
        child: Text(
          'Se a igreja ja foi aprovada, atualiza a pagina ou confirma a ligacao ao Supabase.',
        ),
      );
    }

    return ChurchErpPage(
      church: church,
      members: _churchMembers,
      ministries: _ministries,
      assets: _assets,
      backofficeRepository: _backofficeRepository,
      operationsRepository: _operationsRepository,
      readOnly: _isChurchReadOnly,
      onChanged: _refreshData,
    );
  }
}

class _PastorRecentItem {
  const _PastorRecentItem({
    required this.id,
    required this.title,
    required this.body,
    required this.typeLabel,
    required this.statusLabel,
    required this.icon,
    required this.createdAt,
    this.publication,
    this.imageUrl,
    this.authorAvatarUrl,
  });

  final String id;
  final String title;
  final String body;
  final String typeLabel;
  final String statusLabel;
  final IconData icon;
  final DateTime createdAt;
  final PastoralPublication? publication;
  final String? imageUrl;
  final String? authorAvatarUrl;
}

class _PastorPublishAction extends StatelessWidget {
  const _PastorPublishAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                foregroundColor: color,
                child: Icon(icon),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(description),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.arrow_forward_outlined),
                  label: Text(label),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PastorFocusChip extends StatelessWidget {
  const _PastorFocusChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return ActionChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text('$label: $value'),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: color.withValues(alpha: 0.26)),
    );
  }
}

class _PastorRecentItemTile extends StatelessWidget {
  const _PastorRecentItemTile({
    required this.item,
    required this.church,
    required this.readOnly,
    required this.onChanged,
    required this.onMessage,
  });

  final _PastorRecentItem item;
  final ManagedChurch church;
  final bool readOnly;
  final Future<void> Function() onChanged;
  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl?.trim();
    final videoUrl = item.publication?.videoUrl?.trim();
    final audioUrl = item.publication?.audioUrl?.trim();
    final documentUrl = item.publication?.documentUrl?.trim();
    final authorAvatarUrl = item.authorAvatarUrl?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (videoUrl != null && videoUrl.isNotEmpty) ...[
            NativeAutoMedia(
              url: videoUrl,
              kind: NativeAutoMediaKind.video,
              height: 280,
              viewKey: 'dashboard-video-${item.id}',
            ),
            const SizedBox(height: 10),
          ] else if (audioUrl != null && audioUrl.isNotEmpty) ...[
            NativeAutoMedia(
              url: audioUrl,
              kind: NativeAutoMediaKind.audio,
              height: 120,
              viewKey: 'dashboard-audio-${item.id}',
            ),
            const SizedBox(height: 10),
          ] else if (imageUrl != null && imageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 180,
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (documentUrl != null && documentUrl.isNotEmpty) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: const Text('Documento anexado'),
              subtitle: Text(
                documentUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 6),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundImage:
                  authorAvatarUrl == null || authorAvatarUrl.isEmpty
                      ? null
                      : NetworkImage(authorAvatarUrl),
              child: authorAvatarUrl == null || authorAvatarUrl.isEmpty
                  ? Icon(item.icon)
                  : null,
            ),
            title: Text(item.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _PastorRecentBadge(label: item.typeLabel, icon: item.icon),
                    _PastorRecentBadge(
                      label: item.statusLabel,
                      icon: Icons.info_outline,
                      muted: true,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Publicado ${_formatDateTime(item.createdAt)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                if (item.body.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (item.publication != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: PastoralPublicationSocialPanel(
                publication: item.publication!,
                repository: PublicationRepository(),
                churchName: church.name,
                churchLogoUrl: church.logoUrl,
                readOnly: readOnly,
                onChanged: onChanged,
                onMessage: onMessage,
              ),
            ),
          ],
          const Divider(height: 18),
        ],
      ),
    );
  }
}

class _PastorRecentBadge extends StatelessWidget {
  const _PastorRecentBadge({
    required this.label,
    required this.icon,
    this.muted = false,
  });

  final String label;
  final IconData icon;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = muted
        ? theme.colorScheme.onSurfaceVariant
        : pastorTypeBadgeColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

Color pastorTypeBadgeColor(String label) {
  final normalized = label.toLowerCase();
  if (normalized.contains('culto')) return Colors.indigo.shade700;
  if (normalized.contains('congresso')) return Colors.deepPurple.shade700;
  if (normalized.contains('vigilia') || normalized.contains('vigília')) {
    return Colors.blueGrey.shade700;
  }
  if (normalized.contains('batismo')) return Colors.cyan.shade800;
  if (normalized.contains('casamento')) return Colors.pink.shade700;
  if (normalized.contains('conferencia') ||
      normalized.contains('conferência')) {
    return Colors.orange.shade800;
  }
  if (normalized.contains('ensaio')) return Colors.teal.shade700;
  if (normalized.contains('reuniao') || normalized.contains('reunião')) {
    return Colors.brown.shade700;
  }
  if (normalized.contains('campanha')) return Colors.green.shade700;
  if (normalized.contains('pregacao') || normalized.contains('pregação')) {
    return Colors.red.shade700;
  }
  if (normalized.contains('devocional')) return Colors.amber.shade800;
  if (normalized.contains('estudo')) return Colors.lightBlue.shade800;
  if (normalized.contains('palavra pastoral')) return Colors.purple.shade700;
  if (normalized.contains('aviso urgente')) return Colors.deepOrange.shade800;
  if (normalized.contains('video') || normalized.contains('vídeo')) {
    return Colors.redAccent.shade700;
  }
  if (normalized.contains('audio') || normalized.contains('áudio')) {
    return Colors.green.shade800;
  }
  if (normalized.contains('documento')) return Colors.blue.shade800;
  if (normalized.contains('transmissao') ||
      normalized.contains('transmissão') ||
      normalized.contains('live')) {
    return Colors.red.shade900;
  }
  if (normalized.contains('comunicado')) return Colors.blueGrey.shade800;
  if (normalized.contains('lideranca') || normalized.contains('liderança')) {
    return Colors.deepPurple.shade600;
  }
  if (normalized.contains('testemunho')) return Colors.lime.shade900;
  return Colors.blueGrey.shade700;
}

class _TrialCountdownBanner extends StatelessWidget {
  const _TrialCountdownBanner({required this.subscription});

  final ChurchSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final trialEndsAt = subscription.trialEndsAt;
    if (trialEndsAt == null) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final remaining = trialEndsAt.difference(now);
    final daysLeft = remaining.inDays + (remaining.inHours % 24 > 0 ? 1 : 0);
    final label = daysLeft <= 0
        ? 'A subscricao experimental termina hoje.'
        : daysLeft == 1
            ? 'A subscricao experimental termina amanha.'
            : 'Faltam $daysLeft dias para terminar o periodo experimental.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionStatusCard extends StatelessWidget {
  const _SubscriptionStatusCard({required this.subscription});

  final ChurchSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final helperText = switch (subscription.effectiveStatus) {
      'trial' => subscription.trialEndsAt == null
          ? 'Trial Plus ativo.'
          : 'Trial Plus ate ${_formatDate(subscription.trialEndsAt!)}.',
      'grace_period' => subscription.effectiveDeadline == null
          ? 'Periodo de tolerancia ativo.'
          : 'Periodo de tolerancia ate ${_formatDate(subscription.effectiveDeadline!)}.',
      'suspended' =>
        'A subscricao da sua igreja encontra-se suspensa. Efetue o pagamento para reativar todos os servicos.',
      'cancelled' =>
        'A subscricao foi cancelada. A equipa Comunhao pode reativar sem perder dados.',
      _ => subscription.effectiveDeadline == null
          ? 'Subscricao ativa.'
          : 'Subscricao ativa ate ${_formatDate(subscription.effectiveDeadline!)}.',
    };

    return WorkspaceSectionCard(
      title: 'Plano ${subscription.planLabel}',
      subtitle: 'Estado: ${subscription.statusLabel}',
      child: Text(helperText),
    );
  }
}

class _PlanCatalogCard extends StatelessWidget {
  const _PlanCatalogCard({
    required this.plans,
    required this.currentPlanCode,
    required this.onOpenCheckout,
  });

  final List<SubscriptionPlan> plans;
  final String? currentPlanCode;
  final ValueChanged<SubscriptionPlan> onOpenCheckout;

  @override
  Widget build(BuildContext context) {
    final ordered = [...plans]
      ..sort((a, b) => a.priceMzn.compareTo(b.priceMzn));
    return WorkspaceSectionCard(
      title: 'Planos disponiveis',
      subtitle:
          'Toca num plano para confirmar o valor e seguir para o checkout.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;
          final cardWidth = isNarrow
              ? constraints.maxWidth
              : ((constraints.maxWidth - 24) / 3).clamp(220.0, 360.0);
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ordered.map((plan) {
              final selected = plan.code == currentPlanCode;
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onOpenCheckout(plan),
                child: SizedBox(
                  width: cardWidth,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
                        width: selected ? 2 : 1,
                      ),
                      color: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surface,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                plan.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (selected) const Chip(label: Text('Atual')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          plan.isPaid ? plan.priceLabel : 'Gratuito',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(plan.description ?? 'Plano Comunhao'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              label: Text(
                                plan.memberLimit == null
                                    ? 'Membros ilimitados'
                                    : 'Ate ${plan.memberLimit} membros',
                              ),
                            ),
                            Chip(label: Text(plan.adminLimitLabel)),
                            Chip(label: Text('${plan.billingCycleDays} dias')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...plan.features.take(4).map((feature) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    size: 18),
                                const SizedBox(width: 6),
                                Expanded(child: Text(feature)),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => onOpenCheckout(plan),
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Pagar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _ChurchHealthScoreCard extends StatelessWidget {
  const _ChurchHealthScoreCard({
    required this.score,
    required this.label,
    required this.color,
  });

  final int score;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        color: color.withValues(alpha: 0.08),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 64,
            width: 64,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 7,
                  backgroundColor: color.withValues(alpha: 0.16),
                  color: color,
                ),
                Center(
                  child: Text(
                    '$score',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Score calculado com acesso, membros, eventos, carteira e comunicacao.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChurchHealthTile extends StatelessWidget {
  const _ChurchHealthTile({required this.item});

  final _ChurchHealthItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.color(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            foregroundColor: color,
            child: Icon(item.icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(item.description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChurchHealthSeverity { good, info, warning, critical }

class _ChurchHealthItem {
  const _ChurchHealthItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.severity,
  });

  final IconData icon;
  final String title;
  final String description;
  final _ChurchHealthSeverity severity;

  Color color(BuildContext context) {
    return switch (severity) {
      _ChurchHealthSeverity.good => const Color(0xFF047857),
      _ChurchHealthSeverity.info => Theme.of(context).colorScheme.primary,
      _ChurchHealthSeverity.warning => const Color(0xFFB45309),
      _ChurchHealthSeverity.critical => Theme.of(context).colorScheme.error,
    };
  }
}

class _ApplicationLogoPicker extends StatelessWidget {
  const _ApplicationLogoPicker({
    required this.logoUrl,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onClear,
  });

  final String logoUrl;
  final VoidCallback? onPickGallery;
  final VoidCallback? onPickCamera;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl.isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Logotipo',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  height: 64,
                  width: 64,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: hasLogo
                      ? Image.network(
                          logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.church_outlined),
                        )
                      : const Icon(Icons.church_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onPickGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galeria'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onPickCamera,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Camara'),
                      ),
                      if (hasLogo)
                        IconButton(
                          tooltip: 'Remover logotipo',
                          onPressed: onClear,
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorSelector extends StatelessWidget {
  const _ColorSelector({
    required this.title,
    required this.controller,
    required this.fallback,
    required this.onChanged,
  });

  final String title;
  final TextEditingController controller;
  final String fallback;
  final VoidCallback onChanged;

  static const _colors = [
    '#0F766E',
    '#2563EB',
    '#7C3AED',
    '#B45309',
    '#047857',
    '#BE123C',
    '#111827',
    '#F59E0B',
  ];

  @override
  Widget build(BuildContext context) {
    final value = controller.text.trim().isEmpty ? fallback : controller.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _colors.map((hex) {
            final selected = value.toUpperCase() == hex;
            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                controller.text = hex;
                onChanged();
              },
              child: Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _colorFromHex(hex),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).dividerColor,
                    width: selected ? 3 : 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: '$title em HEX',
            hintText: fallback,
          ),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}

class _AutoPaymentMethodCard extends StatelessWidget {
  const _AutoPaymentMethodCard({
    required this.phone,
    required this.provider,
  });

  final String? phone;
  final String? provider;

  @override
  Widget build(BuildContext context) {
    final providerLabel = switch (provider) {
      'emola' => 'e-Mola',
      'mpesa' => 'M-Pesa',
      _ => 'A identificar depois do telefone',
    };
    return ListTile(
      contentPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      leading: const Icon(Icons.payments_outlined),
      title: const Text('Metodo de pagamento automatico'),
      subtitle: Text(
        '$providerLabel${phone == null || phone!.isEmpty ? '' : ' - $phone'}',
      ),
    );
  }
}

class _GreetingTitle extends StatelessWidget {
  const _GreetingTitle({
    required this.title,
    required this.name,
  });

  final String title;
  final String name;

  String get _firstName {
    final clean = name.trim();
    if (clean.isEmpty) return 'pastor';
    return clean.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          'A paz do Senhor, $_firstName!',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message),
      ),
    );
  }
}

ThemeData _buildChurchAdminTheme({
  String? primaryColor,
  String? secondaryColor,
  Brightness brightness = Brightness.light,
}) {
  final primary = _colorFromHex(primaryColor ?? '#0F766E');
  final secondary = secondaryColor == null || secondaryColor.trim().isEmpty
      ? null
      : _colorFromHex(secondaryColor);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: brightness,
  ).copyWith(
    secondary: secondary,
  );
  final baseTheme =
      brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
  final textTheme = GoogleFonts.interTextTheme(baseTheme.textTheme).copyWith(
    displayLarge: GoogleFonts.caveat(
      fontSize: 44,
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    ),
    displayMedium: GoogleFonts.caveat(
      fontSize: 38,
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    ),
    headlineSmall: GoogleFonts.inter(
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    ),
    titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600),
    labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
  );

  return ThemeData(
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? const Color(0xFF0F1412)
        : const Color(0xFFF7F9F8),
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: brightness == Brightness.dark
          ? const Color(0xFF0F1412)
          : const Color(0xFFF7F9F8),
      foregroundColor: brightness == Brightness.dark
          ? colorScheme.onSurface
          : colorScheme.primary,
      titleTextStyle: GoogleFonts.inter(
        color: brightness == Brightness.dark
            ? colorScheme.onSurface
            : colorScheme.primary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: brightness == Brightness.dark
          ? colorScheme.surfaceContainerLow
          : Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: brightness == Brightness.dark
              ? colorScheme.outlineVariant.withValues(alpha: 0.5)
              : const Color(0xFFE5EDE8),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: colorScheme.primaryContainer,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
    ),
    chipTheme: ChipThemeData(
      selectedColor: colorScheme.secondaryContainer,
      secondarySelectedColor: colorScheme.secondaryContainer,
      checkmarkColor: colorScheme.onSecondaryContainer,
      labelStyle: TextStyle(color: colorScheme.onSurface),
    ),
  );
}

Color _colorFromHex(String value) {
  final cleaned = value.replaceAll('#', '').trim();
  final padded = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
  return Color(int.tryParse(padded, radix: 16) ?? 0xFF0F766E);
}

DateTime _nextBirthday(DateTime birthDate, DateTime now) {
  DateTime buildForYear(int year) {
    if (birthDate.month == 2 && birthDate.day == 29) {
      final isLeapYear =
          (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return DateTime(year, 2, isLeapYear ? 29 : 28);
    }
    return DateTime(year, birthDate.month, birthDate.day);
  }

  var next = buildForYear(now.year);
  if (!next.isAfter(now)) {
    next = buildForYear(now.year + 1);
  }
  return next;
}

String _formatBirthday(DateTime birthDate) {
  final next = _nextBirthday(birthDate, DateTime.now());
  final month = next.month.toString().padLeft(2, '0');
  final day = next.day.toString().padLeft(2, '0');
  return '$day/$month';
}

String _formatMoney(num value) {
  final normalized =
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  return 'MZN $normalized';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${_formatDate(local)} $hour:$minute';
}
