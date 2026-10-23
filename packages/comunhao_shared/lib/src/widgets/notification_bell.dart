import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/internal_notification.dart';
import '../repositories/notification_repository.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({
    super.key,
    this.repository,
    this.onNotificationTap,
    this.minimumBadgeCount = 0,
  });

  final NotificationRepository? repository;
  final FutureOr<void> Function(InternalNotification notification)?
      onNotificationTap;
  final int minimumBadgeCount;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  late final NotificationRepository _repository;
  RealtimeChannel? _realtimeChannel;
  Timer? _reloadTimer;
  int _unreadCount = 0;
  bool _loading = true;
  bool _hasLoadedUnreadCount = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? NotificationRepository();
    _loadUnreadCount();
    _configureRealtime();
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    final channel = _realtimeChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    super.dispose();
  }

  void _configureRealtime() {
    final profileId = Supabase.instance.client.auth.currentUser?.id;
    if (profileId == null || profileId.isEmpty) {
      return;
    }

    _realtimeChannel =
        Supabase.instance.client.channel('notification-bell-$profileId')
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'comunhao',
            table: 'internal_notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'recipient_profile_id',
              value: profileId,
            ),
            callback: (_) => _scheduleUnreadRefresh(playAlert: true),
          )
          ..subscribe();
  }

  void _scheduleUnreadRefresh({bool playAlert = false}) {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        _loadUnreadCount(playAlert: playAlert);
      }
    });
  }

  Future<void> _loadUnreadCount({bool playAlert = false}) async {
    try {
      final count = await _repository.fetchUnreadCount();
      final shouldAlert =
          playAlert && _hasLoadedUnreadCount && count > _unreadCount;
      if (mounted) {
        setState(() {
          _unreadCount = count;
          _loading = false;
          _hasLoadedUnreadCount = true;
        });
        if (shouldAlert) {
          await SystemSound.play(SystemSoundType.alert);
          await HapticFeedback.mediumImpact();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _unreadCount = 0;
          _loading = false;
          _hasLoadedUnreadCount = true;
        });
      }
    }
  }

  Future<void> _openNotifications() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return _NotificationSheet(
          repository: _repository,
          onNotificationTap: widget.onNotificationTap,
        );
      },
    );
    await _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final badgeCount = _unreadCount < widget.minimumBadgeCount
        ? widget.minimumBadgeCount
        : _unreadCount;
    return IconButton(
      tooltip: 'Notificacoes',
      onPressed: _loading ? null : _openNotifications,
      icon: Badge.count(
        count: badgeCount,
        isLabelVisible: badgeCount > 0,
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _NotificationSheet extends StatefulWidget {
  const _NotificationSheet({
    required this.repository,
    required this.onNotificationTap,
  });

  final NotificationRepository repository;
  final FutureOr<void> Function(InternalNotification notification)?
      onNotificationTap;

  @override
  State<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<_NotificationSheet> {
  late Future<List<InternalNotification>> _future;
  bool _markingAllRead = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchNotifications();
  }

  void _reload() {
    setState(() {
      _future = widget.repository.fetchNotifications();
    });
  }

  Future<void> _markAllRead() async {
    setState(() => _markingAllRead = true);
    try {
      await widget.repository.markAllRead();
      await HapticFeedback.selectionClick();
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todas as notificacoes foram lidas.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _markingAllRead = false);
      }
    }
  }

  Future<void> _openNotification(InternalNotification notification) async {
    if (notification.isRead) {
      await _navigate(notification);
      return;
    }
    await widget.repository.markRead(notification.id);
    _reload();
    await _navigate(notification);
  }

  Future<void> _navigate(InternalNotification notification) async {
    final handler = widget.onNotificationTap;
    if (handler == null) {
      return;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
    await handler(notification);
  }

  Future<void> _archive(InternalNotification notification) async {
    await widget.repository.archive(notification.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notificacoes',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _markingAllRead ? null : _markAllRead,
                    icon: const Icon(Icons.done_all),
                    label: Text(_markingAllRead ? 'A marcar...' : 'Ler todos'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<InternalNotification>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _SheetMessage(
                      icon: Icons.error_outline,
                      title: 'Nao foi possivel carregar',
                      message: snapshot.error.toString(),
                    );
                  }

                  final notifications = snapshot.data ?? const [];
                  if (notifications.isEmpty) {
                    return const _SheetMessage(
                      icon: Icons.notifications_none,
                      title: 'Sem notificacoes',
                      message: 'Quando houver novidades, elas aparecem aqui.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _NotificationTile(
                        notification: notification,
                        onTap: () => _openNotification(notification),
                        onArchive: () => _archive(notification),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onArchive,
  });

  final InternalNotification notification;
  final VoidCallback onTap;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final unreadColor = colorScheme.primary.withAlpha(20);

    return Material(
      color: notification.isRead ? colorScheme.surface : unreadColor,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: notification.isRead
              ? colorScheme.surface
              : colorScheme.primaryContainer,
          child: Icon(
            _iconFor(notification.type),
            color: notification.isRead
                ? colorScheme.onSurfaceVariant
                : colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          notification.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _MetaChip(label: notification.typeLabel),
                  if (notification.churchName != null)
                    _MetaChip(label: notification.churchName!),
                  if (notification.priority != 'normal')
                    _MetaChip(label: notification.priorityLabel),
                ],
              ),
            ],
          ),
        ),
        trailing: IconButton(
          tooltip: 'Arquivar',
          onPressed: onArchive,
          icon: const Icon(Icons.archive_outlined),
        ),
      ),
    );
  }

  static IconData _iconFor(String type) {
    return switch (type) {
      'join_request' => Icons.group_add_outlined,
      'donation_pending' ||
      'donation_confirmed' ||
      'donation_rejected' ||
      'contribution_confirmed' ||
      'contribution_rejected' ||
      'expense_pending_approval' ||
      'withdrawal_requested' ||
      'withdrawal_paid' ||
      'subscription_payment_confirmed' =>
        Icons.payments_outlined,
      'pastoral_request' => Icons.volunteer_activism_outlined,
      'pastoral_request_assigned' => Icons.assignment_ind_outlined,
      'administrative_request' => Icons.assignment_outlined,
      'event' => Icons.event_outlined,
      'campaign' => Icons.flag_outlined,
      'announcement' => Icons.campaign_outlined,
      'pastoral_publication' => Icons.library_books_outlined,
      'urgent_notice' => Icons.priority_high_outlined,
      'church_application_submitted' ||
      'church_approved' ||
      'church_corrections_requested' ||
      'church_rejected' =>
        Icons.church_outlined,
      _ => Icons.notifications_outlined,
    };
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
