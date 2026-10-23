import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/utils/formatting.dart';
import '../../../core/widgets/section_card.dart';
import '../../church/data/church_repository.dart';
import '../../church/models/church_branding.dart';
import '../../church/models/church_event.dart';
import '../../church/models/church_member.dart';
import '../../church/models/member_event_registration.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({
    required this.church,
    required this.currentMember,
    required this.repository,
    super.key,
  });

  final ChurchBranding church;
  final ChurchMember currentMember;
  final ChurchRepository repository;

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  late Future<_EventsData> _eventsFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _eventsFuture = _load();
  }

  Future<_EventsData> _load() async {
    final results = await Future.wait<dynamic>([
      widget.repository.fetchUpcomingEvents(widget.church.id),
      widget.repository.fetchOwnEventRegistrations(widget.church.id),
    ]);

    return _EventsData(
      events: results[0] as List<ChurchEvent>,
      registrations: results[1] as List<MemberEventRegistration>,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _eventsFuture = _load();
    });
    await _eventsFuture;
  }

  Future<void> _register(ChurchEvent event) async {
    setState(() => _busy = true);
    try {
      await widget.repository.registerForEvent(event.id);
      if (!mounted) {
        return;
      }
      await _refresh();
      _showMessage('Presenca confirmada para ${event.title}.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('$error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _cancel(ChurchEvent event) async {
    setState(() => _busy = true);
    try {
      await widget.repository.cancelEventRegistration(event.id);
      if (!mounted) {
        return;
      }
      await _refresh();
      _showMessage('Inscricao cancelada.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('$error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _checkInWithQrToken() async {
    final token = await showDialog<String>(
      context: context,
      builder: (context) => const _QrScannerDialog(),
    );

    if (token == null || token.trim().isEmpty) {
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.repository.checkInWithQrPayload(token);
      if (!mounted) {
        return;
      }
      await _refresh();
      _showMessage('Check-in confirmado com sucesso.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('$error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showRegistrationDialog(
    ChurchEvent event,
    MemberEventRegistration registration,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estado: ${registration.statusLabel}'),
            const SizedBox(height: 8),
            Text(
                'Codigo do check-in: ${registration.checkInCode ?? 'A gerar'}'),
            const SizedBox(height: 8),
            const Text(
              'Usa este codigo para QR/check-in rapido no ponto de entrada da igreja.',
            ),
            if (registration.checkedInAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Confirmado em ${formatDateTimeShort(registration.checkedInAt!)}',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_EventsData>(
      future: _eventsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Nao foi possivel carregar os eventos.\n\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final data = snapshot.data ?? const _EventsData.empty();
        final registrationsByEvent = {
          for (final registration in data.registrations)
            registration.eventId: registration,
        };

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SectionCard(
                title: 'Eventos, cultos e check-in',
                subtitle:
                    'Inscricao, confirmacao de presenca e codigo de check-in num unico lugar.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : _checkInWithQrToken,
                      icon: const Icon(Icons.qr_code_scanner_outlined),
                      label: const Text('Ler QR de check-in'),
                    ),
                    const SizedBox(height: 16),
                    if (data.events.isEmpty)
                      const Text('Nenhum evento encontrado.')
                    else
                      Column(
                        children: data.events.map((event) {
                          final registration = registrationsByEvent[event.id];
                          return Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const CircleAvatar(
                                  child: Icon(Icons.event_available_outlined),
                                ),
                                title: Text(event.title),
                                subtitle: Text(
                                  [
                                    event.eventTypeLabel,
                                    formatDateTimeShort(event.startsAt),
                                    if (event.location != null) event.location!,
                                    if (event.description != null &&
                                        event.description!.isNotEmpty)
                                      event.description!,
                                  ].join('\n'),
                                ),
                              ),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  if (registration == null ||
                                      registration.isCancelled)
                                    FilledButton.icon(
                                      onPressed:
                                          _busy ? null : () => _register(event),
                                      icon:
                                          const Icon(Icons.how_to_reg_outlined),
                                      label: Text(
                                        event.registrationRequired
                                            ? 'Inscrever-se'
                                            : 'Confirmar presenca',
                                      ),
                                    )
                                  else ...[
                                    FilledButton.tonalIcon(
                                      onPressed: () => _showRegistrationDialog(
                                        event,
                                        registration,
                                      ),
                                      icon:
                                          const Icon(Icons.qr_code_2_outlined),
                                      label: Text(
                                        registration.isCheckedIn
                                            ? 'Ver check-in'
                                            : 'Codigo check-in',
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed:
                                          _busy ? null : () => _cancel(event),
                                      icon:
                                          const Icon(Icons.event_busy_outlined),
                                      label: const Text('Cancelar'),
                                    ),
                                  ],
                                  if (registration != null)
                                    Chip(label: Text(registration.statusLabel)),
                                  if (event.capacity != null)
                                    Chip(
                                      avatar: const Icon(
                                        Icons.groups_outlined,
                                        size: 18,
                                      ),
                                      label: Text('${event.capacity} vagas'),
                                    ),
                                  if ((event.registrationFeeMzn ?? 0) > 0)
                                    Chip(
                                      avatar: const Icon(
                                        Icons.payments_outlined,
                                        size: 18,
                                      ),
                                      label: Text(
                                        '${event.registrationFeeMzn} MZN - checkout em preparacao',
                                      ),
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
              const SizedBox(height: 20),
              SectionCard(
                title: 'Minhas presencas',
                subtitle:
                    'Historico rapido do que ja foi confirmado por esta conta.',
                child: data.registrations.isEmpty
                    ? const Text('Ainda nao confirmaste presenca em eventos.')
                    : Column(
                        children: data.registrations.map((registration) {
                          final event =
                              data.events.cast<ChurchEvent?>().firstWhere(
                                    (item) => item?.id == registration.eventId,
                                    orElse: () => null,
                                  );
                          return Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const CircleAvatar(
                                  child: Icon(Icons.qr_code_2_outlined),
                                ),
                                title: Text(event?.title ?? 'Evento'),
                                subtitle: Text(
                                  '${registration.statusLabel} - ${registration.checkInCode ?? 'Sem codigo'}',
                                ),
                                trailing: registration.checkedInAt == null
                                    ? null
                                    : Text(
                                        formatDateTimeShort(
                                          registration.checkedInAt!,
                                        ),
                                      ),
                              ),
                              const Divider(),
                            ],
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EventsData {
  const _EventsData({
    required this.events,
    required this.registrations,
  });

  const _EventsData.empty()
      : events = const [],
        registrations = const [];

  final List<ChurchEvent> events;
  final List<MemberEventRegistration> registrations;
}

class _QrScannerDialog extends StatefulWidget {
  const _QrScannerDialog();

  @override
  State<_QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<_QrScannerDialog> {
  final _manualController = TextEditingController();
  bool _handled = false;

  void _finish(String? value) {
    final token = value?.trim();
    if (_handled || token == null || token.isEmpty) {
      return;
    }
    _handled = true;
    Navigator.of(context).pop(token);
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Check-in por QR'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: MobileScanner(
                  onDetect: (capture) {
                    final value = capture.barcodes.isEmpty
                        ? null
                        : capture.barcodes.first.rawValue;
                    _finish(value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _manualController,
              decoration: const InputDecoration(
                labelText: 'Token manual',
                hintText: 'Use se a camera nao estiver disponivel',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () => _finish(_manualController.text),
          icon: const Icon(Icons.qr_code_2_outlined),
          label: const Text('Confirmar token'),
        ),
      ],
    );
  }
}
