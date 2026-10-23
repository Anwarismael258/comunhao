import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/web_upload_picker.dart';

enum _CalendarView { day, week, month }

class ChurchCalendarPage extends StatefulWidget {
  const ChurchCalendarPage({
    required this.church,
    required this.events,
    required this.backofficeRepository,
    required this.calendarRepository,
    required this.onChanged,
    super.key,
  });

  final ManagedChurch church;
  final List<ManagedEvent> events;
  final BackofficeRepository backofficeRepository;
  final CalendarRepository calendarRepository;
  final Future<void> Function() onChanged;

  @override
  State<ChurchCalendarPage> createState() => _ChurchCalendarPageState();
}

class _ChurchCalendarPageState extends State<ChurchCalendarPage> {
  static const _mediaBucket = 'pastoral-publications';

  late Future<_CalendarData> _future;
  bool _busy = false;
  _CalendarView _calendarView = _CalendarView.week;
  DateTime _focusedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_CalendarData> _load() async {
    final results = await Future.wait<dynamic>([
      widget.calendarRepository.fetchOccurrences(widget.church.id),
      widget.calendarRepository.fetchBirthdays(widget.church.id),
    ]);
    return _CalendarData(
      occurrences: results[0] as List<CalendarEventOccurrence>,
      birthdays: results[1] as List<ChurchBirthdayMember>,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) {
        return;
      }
      await widget.onChanged();
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
          margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: Duration(seconds: 5),
          content: Text(
            'Não foi possível carregar o calendário. Verifica a ligação e tenta novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openEditor([ManagedEvent? event]) async {
    final titleController = TextEditingController(text: event?.title ?? '');
    final descriptionController =
        TextEditingController(text: event?.description ?? '');
    final locationController =
        TextEditingController(text: event?.location ?? '');
    final imageController =
        TextEditingController(text: event?.coverImageUrl ?? '');
    final feeController = TextEditingController(
      text: event?.registrationFeeMzn == null || event?.registrationFeeMzn == 0
          ? ''
          : '${event?.registrationFeeMzn}',
    );
    final capacityController = TextEditingController(
      text: event?.capacity == null ? '' : '${event?.capacity}',
    );
    var eventType = event?.eventType ?? 'culto';
    var status = event?.status ?? 'published';
    var visibility = event?.visibility ?? 'members';
    var registrationRequired = event?.registrationRequired ?? false;
    var attendanceRequired = event?.attendanceRequired ?? true;
    var isPublic = event?.isPublic ?? false;
    var startsAt =
        event?.startsAt ?? DateTime.now().add(const Duration(days: 1));
    var endsAt = event?.endsAt;
    var recurrenceRule = event?.recurrenceRule;
    var uploadingImage = false;

    bool? saved;
    try {
      saved = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title:
                Text(event == null ? 'Novo culto ou evento' : 'Editar agenda'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Titulo'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: eventType,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: const [
                        DropdownMenuItem(value: 'culto', child: Text('Culto')),
                        DropdownMenuItem(
                            value: 'evento', child: Text('Evento')),
                        DropdownMenuItem(
                            value: 'vigilia', child: Text('Vigilia')),
                        DropdownMenuItem(
                          value: 'estudo_biblico',
                          child: Text('Estudo biblico'),
                        ),
                        DropdownMenuItem(
                          value: 'reuniao',
                          child: Text('Reuniao'),
                        ),
                        DropdownMenuItem(
                          value: 'acao_social',
                          child: Text('Acao social'),
                        ),
                        DropdownMenuItem(
                          value: 'transmissao',
                          child: Text('Transmissao'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => eventType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Descricao'),
                      minLines: 2,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(labelText: 'Local'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: imageController,
                      decoration:
                          const InputDecoration(labelText: 'Imagem/URL'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: uploadingImage
                                ? null
                                : () async {
                                    setDialogState(() => uploadingImage = true);
                                    try {
                                      final url = await _pickAndUploadImage(
                                        folder: 'events',
                                      );
                                      if (url != null) {
                                        imageController.text = url;
                                      }
                                    } catch (error) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                _friendlyUploadError(error)),
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (context.mounted) {
                                        setDialogState(
                                          () => uploadingImage = false,
                                        );
                                      }
                                    }
                                  },
                            icon: uploadingImage
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
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
                                : () => setDialogState(imageController.clear),
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: capacityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Capacidade',
                              hintText: 'Ex.: 120',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: feeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Valor MZN',
                              hintText: '0 para gratuito',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ChoiceChip(
                          label: const Text('Sem recorrencia'),
                          selected: recurrenceRule == null,
                          onSelected: (_) =>
                              setDialogState(() => recurrenceRule = null),
                        ),
                        ChoiceChip(
                          label: const Text('Semanal'),
                          selected: recurrenceRule == 'weekly',
                          onSelected: (_) =>
                              setDialogState(() => recurrenceRule = 'weekly'),
                        ),
                        ChoiceChip(
                          label: const Text('Mensal'),
                          selected: recurrenceRule == 'monthly',
                          onSelected: (_) =>
                              setDialogState(() => recurrenceRule = 'monthly'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 365)),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 730)),
                                initialDate: startsAt,
                              );
                              if (picked == null || !context.mounted) {
                                return;
                              }
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(startsAt),
                              );
                              if (time == null) {
                                return;
                              }
                              setDialogState(() {
                                startsAt = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            },
                            icon: const Icon(Icons.event_outlined),
                            label: Text(_format(startsAt)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => setDialogState(
                              () => endsAt =
                                  startsAt.add(const Duration(hours: 2)),
                            ),
                            icon: const Icon(Icons.schedule_outlined),
                            label: Text(
                              endsAt == null ? 'Definir fim' : _format(endsAt!),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Estado'),
                      items: const [
                        DropdownMenuItem(
                            value: 'draft', child: Text('Rascunho')),
                        DropdownMenuItem(
                          value: 'published',
                          child: Text('Publicado'),
                        ),
                        DropdownMenuItem(
                          value: 'cancelled',
                          child: Text('Cancelado'),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Concluido'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => status = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: visibility,
                      decoration: const InputDecoration(labelText: 'Publico'),
                      items: const [
                        DropdownMenuItem(
                          value: 'members',
                          child: Text('Membros'),
                        ),
                        DropdownMenuItem(value: 'all', child: Text('Todos')),
                        DropdownMenuItem(
                          value: 'leaders',
                          child: Text('Lideres'),
                        ),
                        DropdownMenuItem(
                          value: 'pastors',
                          child: Text('Pastores'),
                        ),
                        DropdownMenuItem(
                          value: 'private',
                          child: Text('Privado'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => visibility = value);
                        }
                      },
                    ),
                    SwitchListTile(
                      value: registrationRequired,
                      onChanged: (value) =>
                          setDialogState(() => registrationRequired = value),
                      title: const Text('Exigir inscricao'),
                    ),
                    SwitchListTile(
                      value: attendanceRequired,
                      onChanged: (value) =>
                          setDialogState(() => attendanceRequired = value),
                      title: const Text('Controlar presencas'),
                    ),
                    SwitchListTile(
                      value: isPublic,
                      onChanged: (value) =>
                          setDialogState(() => isPublic = value),
                      title: const Text('Visivel publicamente'),
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
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.length < 3) {
                    return;
                  }
                  try {
                    await widget.backofficeRepository.saveChurchEvent(
                      eventId: event?.id,
                      churchId: widget.church.id,
                      title: title,
                      eventType: eventType,
                      description: descriptionController.text,
                      location: locationController.text,
                      coverImageUrl: imageController.text,
                      status: status,
                      visibility: visibility,
                      recurrenceRule: recurrenceRule,
                      attendanceRequired: attendanceRequired,
                      isPublic: isPublic,
                      startsAt: startsAt,
                      endsAt: endsAt,
                      registrationRequired: registrationRequired,
                      registrationFeeMzn: num.tryParse(
                        feeController.text.trim().replaceAll(',', '.'),
                      ),
                      capacity: int.tryParse(capacityController.text.trim()),
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_friendlyUploadError(error))),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.save_outlined),
                label: Text(event == null ? 'Publicar' : 'Atualizar'),
              ),
            ],
          ),
        ),
      );
    } catch (error) {
      titleController.dispose();
      descriptionController.dispose();
      locationController.dispose();
      imageController.dispose();
      feeController.dispose();
      capacityController.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyUploadError(error))),
        );
      }
      return;
    }

    if (saved == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              event == null
                  ? 'Culto/evento publicado com sucesso.'
                  : 'Agenda atualizada com sucesso.',
            ),
          ),
        );
      }
      await _run(() async {});
    }
  }

  Future<String?> _pickAndUploadImage({required String folder}) async {
    final nativeFile = await pickUploadFile(
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      accept: 'image/jpeg,image/png,image/webp',
    );
    if (nativeFile != null) {
      return _uploadBytes(
        folder: folder,
        name: nativeFile.name,
        bytes: nativeFile.bytes,
      );
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return null;

    return _uploadBytes(folder: folder, name: file.name, bytes: bytes);
  }

  Future<String> _uploadBytes({
    required String folder,
    required String name,
    required Uint8List bytes,
  }) async {
    final extension = _extensionFor(name);
    final path =
        '${widget.church.id}/$folder/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final client = Supabase.instance.client;
    await client.storage.from(_mediaBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _contentTypeFor(extension)),
        );
    return client.storage.from(_mediaBucket).getPublicUrl(path);
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

  String _friendlyUploadError(Object error) {
    final lower = error.toString().toLowerCase();
    if (lower.contains('lateinitializationerror') ||
        lower.contains('assertion failed')) {
      return 'A tela de agenda ainda estava a inicializar. Atualiza a pagina uma vez e tenta novamente.';
    }
    if (error is MissingPluginException ||
        lower.contains('missingpluginexception')) {
      return 'O seletor de ficheiros ainda nao carregou nesta sessao. Atualiza a pagina e tenta novamente.';
    }
    if (lower.contains('payload too large') ||
        lower.contains('exceeded') ||
        lower.contains('file size') ||
        lower.contains('too large')) {
      return 'A imagem e muito grande. Usa uma imagem ate 5 MB.';
    }
    if (lower.contains('mime') ||
        lower.contains('content type') ||
        lower.contains('not allowed') ||
        lower.contains('unsupported')) {
      return 'Tipo de imagem nao permitido. Usa JPG, PNG ou WEBP.';
    }
    if (lower.contains('jwt') ||
        lower.contains('expired') ||
        lower.contains('not authenticated')) {
      return 'Sessao expirada. Sai e entra novamente para fazer upload.';
    }
    if (lower.contains('row-level security') ||
        lower.contains('unauthorized') ||
        lower.contains('permission')) {
      return 'Sem permissao para guardar a imagem no Storage.';
    }
    return 'Nao foi possivel carregar a imagem agora.';
  }

  Future<void> _deleteEvent(ManagedEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar culto ou evento'),
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
    await _run(() => widget.backofficeRepository.deleteChurchEvent(event.id));
  }

  Future<void> _generateOccurrences(ManagedEvent event) async {
    await _run(() => widget.calendarRepository
        .generateEventOccurrences(event.id)
        .then((_) => null));
  }

  Future<void> _openCheckin(CalendarEventOccurrence occurrence) async {
    String? payload;
    await _run(() async {
      payload = await widget.calendarRepository.openEventCheckin(occurrence.id);
    });
    if (!mounted || payload == null) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check-in aberto'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: payload!,
                version: QrVersions.auto,
                size: 260,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              const Text('Mostre este QR na entrada da igreja.'),
              const SizedBox(height: 8),
              SelectableText(payload!),
            ],
          ),
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

  Future<void> _manualCheckin(ManagedEvent event) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Check-in manual - ${event.title}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration:
                    const InputDecoration(labelText: 'Nome do visitante'),
              ),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefone'),
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Observacoes'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (saved == true) {
      await _run(
        () => widget.calendarRepository.manualCheckInEvent(
          eventId: event.id,
          visitorName: nameController.text,
          visitorPhone: phoneController.text,
          notes: notesController.text,
        ),
      );
    }
  }

  Future<void> _manualChildCheckin(ManagedEvent event) async {
    final childController = TextEditingController();
    final guardianController = TextEditingController();
    final phoneController = TextEditingController();
    final roomController = TextEditingController();
    final notesController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Check-in infantil - ${event.title}'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: childController,
                decoration: const InputDecoration(labelText: 'Nome da crianca'),
              ),
              TextField(
                controller: guardianController,
                decoration:
                    const InputDecoration(labelText: 'Responsavel/guardiao'),
              ),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefone'),
              ),
              TextField(
                controller: roomController,
                decoration: const InputDecoration(labelText: 'Sala/turma'),
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Observacoes'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.child_care_outlined),
            label: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (saved == true) {
      await _run(() async {
        final record = await widget.calendarRepository.manualChildCheckInEvent(
          eventId: event.id,
          childName: childController.text,
          guardianName: guardianController.text,
          guardianPhone: phoneController.text,
          roomName: roomController.text,
          notes: notesController.text,
        );
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Check-in infantil criado. Codigo de retirada: ${record.securityCode}',
            ),
          ),
        );
      });
    }
  }

  Future<void> _showSummary(ManagedEvent event) async {
    final results = await Future.wait<dynamic>([
      widget.calendarRepository.fetchAttendanceSummary(event.id),
      widget.calendarRepository.fetchAttendanceRows(event.id),
    ]);
    final summary = results[0] as EventAttendanceSummary;
    final rows = results[1] as List<EventAttendanceRow>;
    final csv = _attendanceCsv(event, rows);
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Presencas - ${event.title}'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricChip(label: 'Total', value: summary.total),
                    _MetricChip(label: 'Membros', value: summary.members),
                    _MetricChip(label: 'Visitantes', value: summary.visitors),
                    _MetricChip(label: 'Criancas', value: summary.children),
                    _MetricChip(label: 'Manual', value: summary.manual),
                    _MetricChip(label: 'QR', value: summary.qr),
                  ],
                ),
                const SizedBox(height: 16),
                if (rows.isEmpty)
                  const Text('Ainda nao existem presencas para exportar.')
                else
                  Column(
                    children: rows.map((row) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.fact_check_outlined),
                        title: Text(row.name ?? row.participantLabel),
                        subtitle: Text(
                          '${row.participantLabel} - ${row.checkInMethod} - ${_format(row.checkedInAt)}',
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: rows.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: csv));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('CSV copiado para a area de transferencia.'),
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.table_view_outlined),
            label: const Text('Copiar CSV'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _prepareReminders() async {
    await _run(() async {
      final count = await widget.calendarRepository
          .prepareInternalReminders(widget.church.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$count lembretes internos preparados. Canais externos ficam pendentes ate haver provedor real.',
          ),
        ),
      );
    });
  }

  Future<void> _sendBirthdayMessage(ChurchBirthdayMember birthday) async {
    await _run(
      () => widget.calendarRepository.sendBirthdayMessage(
        churchId: widget.church.id,
        profileId: birthday.profileId,
        message:
            'Parabens, ${birthday.fullName}! A Igreja ${widget.church.name} celebra a sua vida e ora por si.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CalendarData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const _CalendarData.empty();
        final occurrencesByEvent = <String, CalendarEventOccurrence>{};
        for (final occurrence in data.occurrences) {
          occurrencesByEvent.putIfAbsent(occurrence.eventId, () => occurrence);
        }
        final visibleEvents = _eventsForCurrentPeriod(widget.events);
        final openCheckins = data.occurrences
            .where((occurrence) => occurrence.checkinOpen)
            .length;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const WorkspaceHero(
              surface: ComunhaoSurface.churchAdmin,
              title: 'Agenda da Igreja',
              subtitle:
                  'Cultos, eventos, presencas por QR, visitantes e aniversarios.',
              icon: Icons.event_available_outlined,
              color: Color(0xFF7C3AED),
            ),
            const SizedBox(height: 12),
            WorkspaceSectionCard(
              title: 'Resumo operacional',
              subtitle:
                  'Estado rapido da agenda, check-in e comunicacoes internas.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _AgendaMetricChip(
                        icon: Icons.event_available_outlined,
                        label: 'Eventos',
                        value: widget.events.length,
                      ),
                      _AgendaMetricChip(
                        icon: Icons.calendar_view_week_outlined,
                        label: 'No periodo',
                        value: visibleEvents.length,
                      ),
                      _AgendaMetricChip(
                        icon: Icons.qr_code_2_outlined,
                        label: 'QR abertos',
                        value: openCheckins,
                      ),
                      _AgendaMetricChip(
                        icon: Icons.cake_outlined,
                        label: 'Aniversarios',
                        value: data.birthdays.length,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _prepareReminders,
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const Text('Preparar lembretes internos'),
                      ),
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _openEditor(),
                        icon: const Icon(Icons.add),
                        label: const Text('Novo culto ou evento'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            WorkspaceSectionCard(
              title: 'Calendario',
              subtitle: 'Visao por dia, semana ou mes para culto e eventos.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SegmentedButton<_CalendarView>(
                        segments: const [
                          ButtonSegment(
                            value: _CalendarView.day,
                            icon: Icon(Icons.today_outlined),
                            label: Text('Dia'),
                          ),
                          ButtonSegment(
                            value: _CalendarView.week,
                            icon: Icon(Icons.view_week_outlined),
                            label: Text('Semana'),
                          ),
                          ButtonSegment(
                            value: _CalendarView.month,
                            icon: Icon(Icons.calendar_month_outlined),
                            label: Text('Mes'),
                          ),
                        ],
                        selected: {_calendarView},
                        onSelectionChanged: (value) =>
                            setState(() => _calendarView = value.first),
                      ),
                      IconButton(
                        tooltip: 'Periodo anterior',
                        onPressed: () => setState(
                          () =>
                              _focusedDate = _focusedDate.subtract(_periodStep),
                        ),
                        icon: const Icon(Icons.chevron_left_outlined),
                      ),
                      Text(
                        _periodLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        tooltip: 'Proximo periodo',
                        onPressed: () => setState(
                          () => _focusedDate = _focusedDate.add(_periodStep),
                        ),
                        icon: const Icon(Icons.chevron_right_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (visibleEvents.isEmpty)
                    const Text('Nao existem eventos neste periodo.')
                  else
                    Column(
                      children: visibleEvents
                          .map(
                            (event) => _CalendarEventTile(
                              event: event,
                              onEdit: _busy ? null : () => _openEditor(event),
                              onSummary:
                                  _busy ? null : () => _showSummary(event),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            WorkspaceSectionCard(
              title: 'Cultos e eventos',
              subtitle: 'Agenda visivel aos membros conforme estado e publico.',
              child: widget.events.isEmpty
                  ? const Text('Ainda nao existem cultos ou eventos reais.')
                  : Column(
                      children: widget.events.map((event) {
                        final occurrence = occurrencesByEvent[event.id];
                        return Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                child: Icon(_iconFor(event.eventType)),
                              ),
                              title: Text(event.title),
                              subtitle: Text(
                                [
                                  '${event.eventTypeLabel} - ${event.statusLabel}',
                                  _format(event.startsAt),
                                  if (event.location != null) event.location!,
                                  if (event.capacity != null)
                                    '${event.capacity} vagas',
                                  if ((event.registrationFeeMzn ?? 0) > 0)
                                    '${event.registrationFeeMzn} MZN',
                                  if (event.recurrenceRule != null)
                                    'Recorrencia: ${event.recurrenceRule}',
                                ].join('\n'),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed:
                                        _busy ? null : () => _openEditor(event),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Editar'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _generateOccurrences(event),
                                    icon: const Icon(Icons.repeat_outlined),
                                    label: const Text('Ocorrencias'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _manualCheckin(event),
                                    icon: const Icon(Icons.how_to_reg_outlined),
                                    label: const Text('Visitante'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _manualChildCheckin(event),
                                    icon: const Icon(Icons.child_care_outlined),
                                    label: const Text('Crianca'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _showSummary(event),
                                    icon: const Icon(Icons.summarize_outlined),
                                    label: const Text('Presencas'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _deleteEvent(event),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Apagar'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (occurrence != null)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Chip(
                                      avatar: const Icon(
                                        Icons.event_repeat_outlined,
                                        size: 18,
                                      ),
                                      label: Text(
                                        'Proxima: ${_format(occurrence.startsAt)}',
                                      ),
                                    ),
                                    FilledButton.tonalIcon(
                                      onPressed: _busy
                                          ? null
                                          : () => _openCheckin(occurrence),
                                      icon:
                                          const Icon(Icons.qr_code_2_outlined),
                                      label: Text(
                                        occurrence.checkinOpen
                                            ? 'Ver QR'
                                            : 'Abrir QR',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const Divider(height: 28),
                          ],
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 20),
            WorkspaceSectionCard(
              title: 'Aniversarios',
              subtitle: 'Membros ativos com aniversario nos proximos dias.',
              child: snapshot.connectionState != ConnectionState.done
                  ? const Center(child: CircularProgressIndicator())
                  : data.birthdays.isEmpty
                      ? const Text('Nenhum aniversario encontrado.')
                      : Column(
                          children: data.birthdays.map((birthday) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                child: Icon(Icons.cake_outlined),
                              ),
                              title: Text(birthday.fullName),
                              subtitle: Text(
                                birthday.daysUntil == 0
                                    ? 'Hoje'
                                    : 'Daqui a ${birthday.daysUntil} dias',
                              ),
                              trailing: FilledButton.tonalIcon(
                                onPressed: _busy
                                    ? null
                                    : () => _sendBirthdayMessage(birthday),
                                icon: const Icon(Icons.notifications_outlined),
                                label: const Text('Avisar'),
                              ),
                            );
                          }).toList(),
                        ),
            ),
          ],
        );
      },
    );
  }

  static IconData _iconFor(String type) => switch (type) {
        'vigilia' => Icons.nightlight_outlined,
        'estudo_biblico' => Icons.menu_book_outlined,
        'acao_social' => Icons.volunteer_activism_outlined,
        'transmissao' => Icons.live_tv_outlined,
        'reuniao' => Icons.groups_2_outlined,
        _ => Icons.church_outlined,
      };

  static String _format(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Duration get _periodStep => switch (_calendarView) {
        _CalendarView.day => const Duration(days: 1),
        _CalendarView.week => const Duration(days: 7),
        _CalendarView.month => const Duration(days: 31),
      };

  String get _periodLabel {
    final (start, end) = _periodBounds();
    if (_calendarView == _CalendarView.day) {
      return _dateOnly(start);
    }
    return '${_dateOnly(start)} - '
        '${_dateOnly(end.subtract(const Duration(days: 1)))}';
  }

  (DateTime, DateTime) _periodBounds() {
    final local =
        DateTime(_focusedDate.year, _focusedDate.month, _focusedDate.day);
    return switch (_calendarView) {
      _CalendarView.day => (local, local.add(const Duration(days: 1))),
      _CalendarView.week => (
          local.subtract(Duration(days: local.weekday - 1)),
          local.subtract(Duration(days: local.weekday - 1)).add(
                const Duration(days: 7),
              )
        ),
      _CalendarView.month => (
          DateTime(local.year, local.month),
          DateTime(local.year, local.month + 1),
        ),
    };
  }

  List<ManagedEvent> _eventsForCurrentPeriod(List<ManagedEvent> events) {
    final (start, end) = _periodBounds();
    final visible = events.where((event) {
      final localStart = event.startsAt.toLocal();
      return !localStart.isBefore(start) && localStart.isBefore(end);
    }).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return visible;
  }

  static String _dateOnly(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }

  static String _csvCell(Object? value) {
    final text = '${value ?? ''}'.replaceAll('"', '""');
    return '"$text"';
  }

  static String _attendanceCsv(
    ManagedEvent event,
    List<EventAttendanceRow> rows,
  ) {
    final lines = <String>[
      [
        'Evento',
        'Nome',
        'Telefone',
        'Tipo',
        'Metodo',
        'Entrada',
        'Saida',
        'Notas',
      ].map(_csvCell).join(','),
      for (final row in rows)
        [
          event.title,
          row.name,
          row.phone,
          row.participantLabel,
          row.checkInMethod,
          _format(row.checkedInAt),
          row.checkedOutAt == null ? '' : _format(row.checkedOutAt!),
          row.notes,
        ].map(_csvCell).join(','),
    ];
    return lines.join('\n');
  }
}

class _CalendarEventTile extends StatelessWidget {
  const _CalendarEventTile({
    required this.event,
    required this.onEdit,
    required this.onSummary,
  });

  final ManagedEvent event;
  final VoidCallback? onEdit;
  final VoidCallback? onSummary;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.event_available_outlined)),
      title: Text(event.title),
      subtitle: Text(
        [
          event.eventTypeLabel,
          _ChurchCalendarPageState._format(event.startsAt),
          if (event.location != null) event.location!,
          if (event.capacity != null) '${event.capacity} vagas',
          if ((event.registrationFeeMzn ?? 0) > 0)
            '${event.registrationFeeMzn} MZN - checkout pendente de provedor real',
        ].join('\n'),
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Editar',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Resumo',
            onPressed: onSummary,
            icon: const Icon(Icons.summarize_outlined),
          ),
        ],
      ),
    );
  }
}

class _AgendaMetricChip extends StatelessWidget {
  const _AgendaMetricChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(label),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(child: Text('$value')),
      label: Text(label),
    );
  }
}

class _CalendarData {
  const _CalendarData({
    required this.occurrences,
    required this.birthdays,
  });

  const _CalendarData.empty()
      : occurrences = const [],
        birthdays = const [];

  final List<CalendarEventOccurrence> occurrences;
  final List<ChurchBirthdayMember> birthdays;
}
