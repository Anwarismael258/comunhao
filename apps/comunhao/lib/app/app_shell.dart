import 'dart:async';

import 'package:flutter/material.dart';
import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/admin/presentation/admin_page.dart';
import '../features/bible/presentation/bible_page.dart';
import '../features/church/data/church_repository.dart';
import '../features/church/models/church_branding.dart';
import '../features/church/models/church_member.dart';
import '../features/community/presentation/community_feed_page.dart';
import '../features/donations/presentation/donations_page.dart';
import '../features/events/presentation/events_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/operations/presentation/member_operations_page.dart';
import '../features/prayer/presentation/prayer_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/publications/presentation/publications_page.dart';
import '../features/requests/presentation/member_requests_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.church,
    required this.currentMember,
    required this.repository,
    required this.darkMode,
    required this.onDarkModeChanged,
    required this.onSignOut,
    required this.onDeleteAccount,
    required this.onChangeChurch,
    super.key,
  });

  final ChurchBranding church;
  final ChurchMember currentMember;
  final ChurchRepository repository;
  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onDeleteAccount;
  final Future<void> Function() onChangeChurch;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  RealtimeChannel? _realtimeChannel;
  Timer? _liveRefreshTimer;
  int _selectedIndex = 0;
  int _liveVersion = 0;
  String? _subscriptionStatusOverride;
  static const _bottomPageIndexes = <int>[0, 2, 9, 8];

  static const _sectionTitles = <String>[
    'Início',
    'Dízimos e ofertas',
    'Bíblia',
    'Comunhão',
    'Agenda',
    'Serviço',
    'Oração',
    'Pedidos',
    'Perfil',
    'Comunhão',
  ];

  void _selectPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openAdmin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminPage(
          church: widget.church,
          currentMember: widget.currentMember,
        ),
      ),
    );
  }

  void _openLegalDocuments() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LegalDocumentsPage(),
      ),
    );
  }

  void _openAbout() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ComunhaoAboutPage(
          churchName: widget.church.name,
          churchLogoUrl: widget.church.logoUrl,
        ),
      ),
    );
  }

  Future<void> _handleNotificationTap(
    InternalNotification notification,
  ) async {
    final destination = _memberNotificationDestination(notification);
    if (destination != null) {
      _selectPage(destination);
    }

    final isPublicationComment =
        notification.referenceTable == 'pastoral_publication_comments' ||
            notification.type == 'pastoral_publication_comment' ||
            notification.type == 'publication_comment';
    final publicationId = isPublicationComment
        ? _notificationMetadataId(
              notification,
              const ['publication_id', 'pastoral_publication_id'],
            ) ??
            _notificationTargetId(
              notification,
              tables: const {'pastoral_publications'},
              metadataKeys: const ['publication_id', 'pastoral_publication_id'],
            )
        : _notificationTargetId(
            notification,
            tables: const {
              'pastoral_publications',
              'pastoral_publication_reactions',
            },
            metadataKeys: const ['publication_id', 'pastoral_publication_id'],
          );
    if (publicationId != null) {
      await _openPublicationFromNotification(
        publicationId,
        openComments: isPublicationComment,
      );
      return;
    }

    _showNotificationNavigationMessage(notification);
  }

  int? _memberNotificationDestination(InternalNotification notification) {
    final table = notification.referenceTable;
    final type = notification.type;
    if (type == 'pastoral_publication' ||
        type == 'announcement' ||
        type == 'urgent_notice' ||
        table == 'pastoral_publications') {
      return 3;
    }
    if (type == 'event' || table == 'events') return 4;
    if (type == 'pastoral_request' ||
        type == 'pastoral_request_assigned' ||
        table == 'prayer_requests' ||
        table == 'prayer_request_responses') {
      return 6;
    }
    if (type == 'join_request' ||
        table == 'church_join_requests' ||
        table == 'administrative_requests' ||
        table == 'pastoral_requests') {
      return 7;
    }
    if (type.contains('donation') ||
        type.contains('contribution') ||
        table == 'donations' ||
        table == 'member_wallet_ledger_entries' ||
        table == 'wallet_ledger_entries') {
      return 1;
    }
    if (table == 'community_posts' ||
        table == 'community_post_comments' ||
        table == 'community_post_reactions' ||
        table == 'community_post_saved' ||
        table == 'community_post_shares' ||
        type == 'community_post' ||
        type == 'community_comment' ||
        type == 'community_reaction' ||
        type == 'community_share') {
      return 3;
    }
    if (table == 'ministry_join_requests' ||
        table == 'ministry_members' ||
        table == 'church_groups' ||
        type == 'ministry_invite') {
      return 5;
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

  String? _notificationMetadataId(
    InternalNotification notification,
    List<String> metadataKeys,
  ) {
    for (final key in metadataKeys) {
      final value = notification.metadata[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  Future<void> _openPublicationFromNotification(
    String publicationId, {
    bool openComments = false,
  }) async {
    try {
      final repository = PublicationRepository();
      final publication = await repository.fetchPublication(publicationId);
      if (!mounted || publication == null) {
        _showMessage('Publicacao nao encontrada ou sem permissao.');
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PublicationDetailPage(
            publicationId: publication.id,
            initialPublication: publication,
            repository: repository,
            churchName: widget.church.name,
            churchLogoUrl: widget.church.logoUrl,
            openComments: openComments,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        _showMessage('Nao foi possivel abrir a publicacao: $error');
      }
    }
  }

  void _showNotificationNavigationMessage(InternalNotification notification) {
    final label = notification.referenceId == null
        ? notification.typeLabel
        : '${notification.typeLabel} aberta';
    _showMessage(label);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(_refreshSubscriptionState(showErrors: false));
    _configureRealtime();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.church.id != widget.church.id ||
        oldWidget.currentMember.id != widget.currentMember.id) {
      _disposeRealtime();
      _configureRealtime();
    }
  }

  @override
  void dispose() {
    _disposeRealtime();
    super.dispose();
  }

  void _disposeRealtime() {
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = null;
    final channel = _realtimeChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
      _realtimeChannel = null;
    }
  }

  void _scheduleLiveRefresh() {
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _liveVersion += 1;
      });
    });
  }

  bool get _isChurchSuspended {
    final status = (_subscriptionStatusOverride ??
            widget.church.effectiveSubscriptionStatus)
        .trim();
    return const {'overdue', 'grace_period', 'suspended', 'cancelled'}
        .contains(status);
  }

  Future<void> _refreshSubscriptionState({bool showErrors = true}) async {
    try {
      final row = await Supabase.instance.client.rpc(
        'refresh_church_subscription_state',
        params: {'p_church_id': widget.church.id},
      );
      if (!mounted || row is! Map) {
        return;
      }
      final status = row['subscription_status']?.toString();
      setState(() {
        _subscriptionStatusOverride = status;
        _liveVersion += 1;
      });
    } catch (error) {
      if (mounted && showErrors) {
        _showMessage('Nao foi possivel atualizar agora. Tenta novamente.');
      }
    }
  }

  void _configureRealtime() {
    final channel = Supabase.instance.client.channel(
        'comunhao-member-${widget.currentMember.id}-${widget.church.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'churches',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: widget.church.id,
        ),
        callback: (_) {
          unawaited(_refreshSubscriptionState(showErrors: false));
          _scheduleLiveRefresh();
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'church_subscriptions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'church_id',
          value: widget.church.id,
        ),
        callback: (_) {
          unawaited(_refreshSubscriptionState(showErrors: false));
          _scheduleLiveRefresh();
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'announcements',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'church_id',
          value: widget.church.id,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'events',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'church_id',
          value: widget.church.id,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'donation_campaigns',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'church_id',
          value: widget.church.id,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'donations',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'profile_id',
          value: widget.currentMember.id,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'prayer_requests',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'profile_id',
          value: widget.currentMember.id,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'church_join_requests',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'profile_id',
          value: widget.currentMember.id,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'pastoral_requests',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'profile_id',
          value: widget.currentMember.id,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'administrative_requests',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'profile_id',
          value: widget.currentMember.id,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'church_communications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'church_id',
          value: widget.church.id,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'pastoral_publications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'church_id',
          value: widget.church.id,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'event_registrations',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'profile_id',
          value: widget.currentMember.id,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'operational_tasks',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'church_id',
          value: widget.church.id,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'service_rosters',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'church_id',
          value: widget.church.id,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'ministry_join_requests',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'membership_id',
          value: widget.currentMember.membershipId,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'volunteer_applications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'membership_id',
          value: widget.currentMember.membershipId,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'prayer_request_responses',
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'ministry_members',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'membership_id',
          value: widget.currentMember.membershipId,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'internal_notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient_profile_id',
          value: widget.currentMember.id,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'member_wallet_accounts',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'profile_id',
          value: widget.currentMember.id,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'member_wallet_ledger_entries',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'profile_id',
          value: widget.currentMember.id,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'community_posts',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'church_id',
          value: widget.church.id,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'community_post_comments',
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'community_post_reactions',
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'community_post_shares',
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'community_post_saved',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'profile_id',
          value: widget.currentMember.id,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'community_post_reports',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'reporter_profile_id',
          value: widget.currentMember.id,
        ),
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'pastoral_publication_comments',
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'pastoral_publication_reactions',
        callback: (_) => _scheduleLiveRefresh(),
      )
      ..subscribe();

    _realtimeChannel = channel;
  }

  @override
  Widget build(BuildContext context) {
    if (_isChurchSuspended) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.church.appName),
          actions: [
            IconButton(
              tooltip: 'Sair',
              onPressed: widget.onSignOut,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: _SuspendedChurchNotice(
          churchName: widget.church.name,
          onRefresh: () => _refreshSubscriptionState(),
        ),
      );
    }

    final pages = <Widget>[
      HomePage(
        key: ValueKey('home-$_liveVersion'),
        church: widget.church,
        currentMember: widget.currentMember,
        repository: widget.repository,
        onNavigate: _selectPage,
      ),
      DonationsPage(
        key: ValueKey('donations-$_liveVersion'),
        church: widget.church,
        repository: widget.repository,
      ),
      BiblePage(
        key: ValueKey('bible-$_liveVersion'),
        church: widget.church,
        member: widget.currentMember,
      ),
      CommunityFeedPage(
        key: ValueKey('community-main-$_liveVersion'),
        church: widget.church,
        member: widget.currentMember,
        repository: widget.repository,
      ),
      EventsPage(
        key: ValueKey('events-$_liveVersion'),
        church: widget.church,
        currentMember: widget.currentMember,
        repository: widget.repository,
      ),
      MemberOperationsPage(
        key: ValueKey('operations-$_liveVersion'),
        church: widget.church,
        member: widget.currentMember,
        repository: SupabaseOperationsRepository(),
      ),
      PrayerPage(
        key: ValueKey('prayer-$_liveVersion'),
        church: widget.church,
        currentMember: widget.currentMember,
        repository: widget.repository,
      ),
      MemberRequestsPage(
        key: ValueKey('requests-$_liveVersion'),
        church: widget.church,
        member: widget.currentMember,
      ),
      ProfilePage(
        key: ValueKey('profile-$_liveVersion'),
        church: widget.church,
        member: widget.currentMember,
        darkMode: widget.darkMode,
        onDarkModeChanged: widget.onDarkModeChanged,
        onDeleteAccount: widget.onDeleteAccount,
      ),
      CommunityFeedPage(
        key: ValueKey('community-$_liveVersion'),
        church: widget.church,
        member: widget.currentMember,
        repository: widget.repository,
      ),
      BiblePage(
        key: ValueKey('bible-plan-$_liveVersion'),
        church: widget.church,
        member: widget.currentMember,
        initialTabIndex: 4,
      ),
    ];

    final appBarTitle = _selectedIndex == 0
        ? widget.church.appName
        : _sectionTitles[_selectedIndex];

    return Scaffold(
      appBar: AppBar(
        title: _GreetingTitle(
          title: appBarTitle,
          name: widget.currentMember.fullName,
        ),
        actions: [
          NotificationBell(onNotificationTap: _handleNotificationTap),
          IconButton(
            tooltip: 'Termos e privacidade',
            onPressed: _openLegalDocuments,
            icon: const Icon(Icons.privacy_tip_outlined),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _DrawerHeader(church: widget.church),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Trocar de igreja'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await widget.onChangeChurch();
                },
              ),
              if (widget.currentMember.canAccessAdmin)
                ListTile(
                  leading: const Icon(Icons.dashboard_outlined),
                  title: const Text('Painel administrativo'),
                  subtitle: const Text(
                    'Membros, funcoes e operacao da igreja',
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _openAdmin();
                  },
                ),
              const Divider(),
              _DrawerDestination(
                icon: Icons.home_outlined,
                title: 'Início',
                selected: _selectedIndex == 0,
                onTap: () {
                  Navigator.of(context).pop();
                  _selectPage(0);
                },
              ),
              _DrawerDestination(
                icon: Icons.diversity_3_outlined,
                title: 'Comunhão',
                selected: _selectedIndex == 3,
                onTap: () {
                  Navigator.of(context).pop();
                  _selectPage(3);
                },
              ),
              _DrawerDestination(
                icon: Icons.volunteer_activism_outlined,
                title: 'Oração',
                selected: _selectedIndex == 6,
                onTap: () {
                  Navigator.of(context).pop();
                  _selectPage(6);
                },
              ),
              _DrawerDestination(
                icon: Icons.event_outlined,
                title: 'Agenda',
                selected: _selectedIndex == 4,
                onTap: () {
                  Navigator.of(context).pop();
                  _selectPage(4);
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Text(
                  'Mais',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _DrawerDestination(
                icon: Icons.volunteer_activism_outlined,
                title: 'Dízimos e ofertas',
                selected: _selectedIndex == 1,
                onTap: () {
                  Navigator.of(context).pop();
                  _selectPage(1);
                },
              ),
              _DrawerDestination(
                icon: Icons.library_books_outlined,
                title: 'Bíblia',
                selected: _selectedIndex == 2,
                onTap: () {
                  Navigator.of(context).pop();
                  _selectPage(2);
                },
              ),
              _DrawerDestination(
                icon: Icons.handyman_outlined,
                title: 'Serviço',
                selected: _selectedIndex == 5,
                onTap: () {
                  Navigator.of(context).pop();
                  _selectPage(5);
                },
              ),
              _DrawerDestination(
                icon: Icons.assignment_outlined,
                title: 'Pedidos',
                selected: _selectedIndex == 7,
                onTap: () {
                  Navigator.of(context).pop();
                  _selectPage(7);
                },
              ),
              _DrawerDestination(
                icon: Icons.person_outline,
                title: 'Perfil',
                selected: _selectedIndex == 8,
                onTap: () {
                  Navigator.of(context).pop();
                  _selectPage(8);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Meu papel'),
                subtitle: Text(
                  '${widget.currentMember.roleLabel} - ${widget.currentMember.statusLabel}',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('Codigo da igreja'),
                subtitle: Text(widget.church.codeLabel),
              ),
              ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: const Text('Contacto da igreja'),
                subtitle: Text(
                  widget.church.phone ??
                      widget.church.email ??
                      'Configura o contacto da igreja no Supabase',
                ),
              ),
              const ListTile(
                leading: Icon(Icons.verified_outlined),
                title: Text('Marca da plataforma'),
                subtitle: Text('Powered by DeliGo Triunfal, Lda.'),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Sobre'),
                subtitle: const Text('Comunhão v1.0.0'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openAbout();
                },
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Termos e privacidade'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openLegalDocuments();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sair'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await widget.onSignOut();
                },
              ),
              const ComunhaoFooter(compact: true),
            ],
          ),
        ),
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: _bottomPageIndexes.contains(_selectedIndex)
          ? NavigationBar(
              selectedIndex: _bottomPageIndexes.indexOf(_selectedIndex),
              onDestinationSelected: (index) {
                _selectPage(_bottomPageIndexes[index]);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Início',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: 'Comunhão',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: 'Oração',
                ),
                NavigationDestination(
                  icon: Icon(Icons.more_horiz),
                  selectedIcon: Icon(Icons.more_horiz),
                  label: 'Agenda',
                ),
              ],
            )
          : null,
    );
  }
}

class _SuspendedChurchNotice extends StatelessWidget {
  const _SuspendedChurchNotice({
    required this.churchName,
    required this.onRefresh,
  });

  final String churchName;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_clock_outlined,
                  size: 56,
                  color: colors.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'A $churchName encontra-se temporariamente com a subscricao expirada.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Os servicos digitais serao reativados assim que a igreja renovar a subscricao.\n\nEm caso de duvidas, contacte a lideranca da igreja.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Atualizar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerDestination extends StatelessWidget {
  const _DrawerDestination({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: selected,
      onTap: onTap,
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
    if (clean.isEmpty) return 'membro';
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

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.church});

  final ChurchBranding church;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: DrawerHeader(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (church.logoUrl != null && church.logoUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: church.logoUrl!.startsWith('assets/')
                    ? Image.asset(
                        church.logoUrl!,
                        height: 44,
                        width: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _LogoFallback(church: church),
                      )
                    : Image.network(
                        church.logoUrl!,
                        height: 44,
                        width: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _LogoFallback(church: church),
                      ),
              )
            else
              _LogoFallback(church: church),
            const SizedBox(height: 10),
            Text(
              church.appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              church.tagline ?? 'Powered by Comunhao',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFD7E7E0)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback({required this.church});

  final ChurchBranding church;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.white,
      foregroundColor: Theme.of(context).colorScheme.primary,
      child: Text(
        church.name.isEmpty ? 'C' : church.name.substring(0, 1).toUpperCase(),
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
