import 'package:flutter/material.dart';

import '../../../core/utils/formatting.dart';
import '../../../core/widgets/section_card.dart';
import '../../church/data/church_repository.dart';
import '../../church/models/church_branding.dart';
import '../../church/models/church_member.dart';
import '../../church/models/member_prayer_request.dart';
import '../../church/models/prayer_response.dart';

class PrayerPage extends StatefulWidget {
  const PrayerPage({
    required this.church,
    required this.currentMember,
    required this.repository,
    super.key,
  });

  final ChurchBranding church;
  final ChurchMember currentMember;
  final ChurchRepository repository;

  @override
  State<PrayerPage> createState() => _PrayerPageState();
}

class _PrayerPageState extends State<PrayerPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  late Future<_PrayerData> _requestsFuture;
  String _visibility = 'private';
  bool _allowResponses = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _requestsFuture = _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<_PrayerData> _load() async {
    final results = await Future.wait<dynamic>([
      widget.repository.fetchOwnPrayerRequests(widget.church.id),
      widget.repository.fetchPrayerFeed(widget.church.id),
    ]);

    return _PrayerData(
      ownRequests: results[0] as List<MemberPrayerRequest>,
      communityRequests: results[1] as List<MemberPrayerRequest>,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _requestsFuture = _load();
    });
    await _requestsFuture;
  }

  Future<void> _submitPrayerRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.repository.createPrayerRequest(
        churchId: widget.church.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        visibility: _visibility,
        anonymousRequest: _visibility == 'anonymous',
        allowResponses: _allowResponses,
      );
      if (!mounted) {
        return;
      }
      _titleController.clear();
      _descriptionController.clear();
      await _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido de oracao enviado.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('permission') || message.contains('row-level')) {
      return 'Não tens permissão para concluir esta ação. Entra novamente ou fala com a igreja.';
    }
    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('timeout')) {
      return 'Sem ligação no momento. Verifica a internet e tenta novamente.';
    }
    if (message.contains('duplicate') || message.contains('already exists')) {
      return 'Este pedido já foi registado.';
    }
    return 'Não foi possível enviar o pedido agora. Tenta novamente.';
  }

  Future<void> _openPrayerResponses(MemberPrayerRequest request) async {
    final responseController = TextEditingController();
    Future<List<PrayerResponse>> responsesFuture =
        widget.repository.fetchPrayerResponses(request.id);
    bool sending = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(request.title),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${request.visibilityLabel} - ${request.statusLabel}',
                  ),
                  const SizedBox(height: 8),
                  Text(request.description),
                  const SizedBox(height: 16),
                  FutureBuilder<List<PrayerResponse>>(
                    future: responsesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final responses =
                          snapshot.data ?? const <PrayerResponse>[];
                      if (snapshot.hasError) {
                        return Text(
                            'Falha ao carregar respostas.\n\n${snapshot.error}');
                      }
                      if (responses.isEmpty) {
                        return const Text(
                          'Ainda nao existem respostas para este pedido.',
                        );
                      }

                      return Column(
                        children: responses.map((response) {
                          final authorLabel = response.responderProfileId ==
                                  widget.currentMember.id
                              ? 'Tu'
                              : 'Comunidade';
                          return Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const CircleAvatar(
                                  child: Icon(Icons.forum_outlined),
                                ),
                                title: Text(authorLabel),
                                subtitle: Text(
                                  '${formatDateTimeShort(response.createdAt)}\n${response.body}',
                                ),
                              ),
                              const Divider(),
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
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Responder oracao',
                      ),
                    ),
                  ],
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
              FilledButton(
                onPressed: sending
                    ? null
                    : () async {
                        final value = responseController.text.trim();
                        if (value.length < 3) {
                          return;
                        }
                        setDialogState(() => sending = true);
                        try {
                          await widget.repository.createPrayerResponse(
                            prayerRequestId: request.id,
                            body: value,
                          );
                          responseController.clear();
                          responsesFuture = widget.repository
                              .fetchPrayerResponses(request.id);
                          setDialogState(() {});
                          await _refresh();
                        } finally {
                          if (context.mounted) {
                            setDialogState(() => sending = false);
                          }
                        }
                      },
                child: Text(sending ? 'A enviar...' : 'Responder'),
              ),
          ],
        ),
      ),
    );

    responseController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PrayerData>(
      future: _requestsFuture,
      builder: (context, snapshot) {
        final ownRequests =
            snapshot.data?.ownRequests ?? const <MemberPrayerRequest>[];
        final communityRequests =
            snapshot.data?.communityRequests ?? const <MemberPrayerRequest>[];

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SectionCard(
                title: 'Novo pedido',
                subtitle:
                    'Privado, publico ou anonimo. A comunidade pode responder quando fizer sentido.',
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Titulo'),
                        validator: (value) {
                          if (value == null || value.trim().length < 3) {
                            return 'Introduz um titulo valido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        minLines: 3,
                        maxLines: 5,
                        decoration:
                            const InputDecoration(labelText: 'Descricao'),
                        validator: (value) {
                          if (value == null || value.trim().length < 5) {
                            return 'Descreve melhor o teu pedido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _visibility,
                        decoration:
                            const InputDecoration(labelText: 'Visibilidade'),
                        items: const [
                          DropdownMenuItem(
                            value: 'private',
                            child: Text('Privado'),
                          ),
                          DropdownMenuItem(
                            value: 'public',
                            child: Text('Publico'),
                          ),
                          DropdownMenuItem(
                            value: 'anonymous',
                            child: Text('Anonimo'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _visibility = value ?? 'private';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: _allowResponses,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Permitir respostas'),
                        subtitle: Text(
                          _allowResponses
                              ? 'A comunidade ou lideranca pode responder neste pedido.'
                              : 'O pedido sera apenas acompanhado, sem respostas publicas.',
                        ),
                        onChanged: (value) {
                          setState(() {
                            _allowResponses = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _submitting ? null : _submitPrayerRequest,
                          icon: const Icon(Icons.favorite_border),
                          label: Text(
                            _submitting ? 'A ENVIAR...' : 'ENVIAR PEDIDO',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SectionCard(
                title: 'Meus pedidos',
                subtitle: 'Historico pessoal de oracao desta conta.',
                child: snapshot.connectionState != ConnectionState.done
                    ? const Center(child: CircularProgressIndicator())
                    : snapshot.hasError
                        ? Text(
                            'Falha ao carregar pedidos.\n\n${snapshot.error}')
                        : ownRequests.isEmpty
                            ? const Text('Ainda nao enviaste nenhum pedido.')
                            : Column(
                                children: ownRequests.map((request) {
                                  return Column(
                                    children: [
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: CircleAvatar(
                                          child: Icon(
                                            request.visibility == 'anonymous'
                                                ? Icons.visibility_off_outlined
                                                : request.isPrivate
                                                    ? Icons.lock_outline
                                                    : Icons.favorite_border,
                                          ),
                                        ),
                                        title: Text(request.title),
                                        subtitle: Text(
                                          '${request.visibilityLabel} - ${request.statusLabel}\n${request.description}',
                                        ),
                                      ),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: [
                                          if (request.allowResponses)
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _openPrayerResponses(request),
                                              icon: const Icon(
                                                Icons.forum_outlined,
                                              ),
                                              label: Text(
                                                request.responseCount == 0
                                                    ? 'Respostas'
                                                    : 'Respostas (${request.responseCount})',
                                              ),
                                            ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                    ],
                                  );
                                }).toList(),
                              ),
              ),
              const SizedBox(height: 20),
              SectionCard(
                title: 'Comunidade em oracao',
                subtitle:
                    'Pedidos publicos e anonimos onde a igreja pode responder.',
                child: snapshot.connectionState != ConnectionState.done
                    ? const Center(child: CircularProgressIndicator())
                    : snapshot.hasError
                        ? Text(
                            'Falha ao carregar comunidade.\n\n${snapshot.error}')
                        : communityRequests.isEmpty
                            ? const Text('Ainda nao existem pedidos visiveis.')
                            : Column(
                                children: communityRequests
                                    .where(
                                  (request) =>
                                      request.visibility != 'private' ||
                                      request.isMine(widget.currentMember.id),
                                )
                                    .map((request) {
                                  final authorLabel =
                                      request.isMine(widget.currentMember.id)
                                          ? 'Tu'
                                          : request.visibility == 'anonymous'
                                              ? 'Pedido anonimo'
                                              : 'Comunidade';

                                  return Column(
                                    children: [
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: CircleAvatar(
                                          child: Icon(
                                            request.visibility == 'anonymous'
                                                ? Icons.visibility_off_outlined
                                                : Icons.favorite_border,
                                          ),
                                        ),
                                        title: Text(request.title),
                                        subtitle: Text(
                                          '$authorLabel - ${request.visibilityLabel} - ${request.statusLabel}\n${request.description}',
                                        ),
                                      ),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: [
                                          if (request.allowResponses)
                                            FilledButton.tonalIcon(
                                              onPressed: () =>
                                                  _openPrayerResponses(request),
                                              icon: const Icon(
                                                Icons.reply_outlined,
                                              ),
                                              label: const Text('Responder'),
                                            ),
                                          Chip(
                                            label: Text(
                                              formatDateTimeShort(
                                                request.createdAt,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
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

class _PrayerData {
  const _PrayerData({
    required this.ownRequests,
    required this.communityRequests,
  });

  final List<MemberPrayerRequest> ownRequests;
  final List<MemberPrayerRequest> communityRequests;
}
