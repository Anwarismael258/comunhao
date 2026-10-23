import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:flutter/material.dart';

class ChurchRequestsPage extends StatefulWidget {
  const ChurchRequestsPage({
    required this.church,
    required this.members,
    required this.readOnly,
    this.repository,
    super.key,
  });

  final ManagedChurch church;
  final List<ManagedMember> members;
  final bool readOnly;
  final CareRepository? repository;

  @override
  State<ChurchRequestsPage> createState() => _ChurchRequestsPageState();
}

class _ChurchRequestsPageState extends State<ChurchRequestsPage>
    with SingleTickerProviderStateMixin {
  late final CareRepository _repository;
  late final TabController _tabController;
  late Future<_RequestsData> _future;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CareRepository();
    _tabController = TabController(length: 3, vsync: this);
    _future = _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_RequestsData> _load() async {
    final results = await Future.wait<dynamic>([
      _repository.fetchChurchJoinRequests(widget.church.id),
      _repository.fetchChurchPastoralRequests(widget.church.id),
      _repository.fetchChurchAdministrativeRequests(widget.church.id),
    ]);
    return _RequestsData(
      joinRequests: results[0] as List<ChurchJoinRequest>,
      pastoralRequests: results[1] as List<PastoralCareRequest>,
      administrativeRequests: results[2] as List<AdministrativeRequest>,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _reviewJoin(
    ChurchJoinRequest request,
    String status, {
    bool requireNotes = false,
  }) async {
    final notes = await _askText(
      title: switch (status) {
        'approved' => 'Aprovar pedido',
        'rejected' => 'Rejeitar pedido',
        'more_information_required' => 'Solicitar informacoes',
        _ => 'Atualizar pedido',
      },
      label: 'Observacao',
      required: requireNotes,
    );
    if (notes == null && requireNotes) {
      return;
    }
    await _repository.reviewJoinRequest(
      requestId: request.id,
      status: status,
      notes: notes,
    );
    await _refresh();
  }

  Future<void> _updatePastoral(PastoralCareRequest request) async {
    String status = request.status;
    String? assignedMembershipId = request.assignedMembershipId;
    final response = TextEditingController();
    final internal = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(request.title),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: const [
                      DropdownMenuItem(value: 'new', child: Text('Pendente')),
                      DropdownMenuItem(
                          value: 'triaged', child: Text('Em analise')),
                      DropdownMenuItem(
                          value: 'assigned',
                          child: Text('Agendado / atribuido')),
                      DropdownMenuItem(
                          value: 'in_contact', child: Text('Em contacto')),
                      DropdownMenuItem(
                          value: 'in_follow_up', child: Text('Em andamento')),
                      DropdownMenuItem(
                          value: 'waiting_member',
                          child: Text('Aguarda membro')),
                      DropdownMenuItem(
                          value: 'resolved', child: Text('Concluido')),
                      DropdownMenuItem(
                          value: 'cancelled', child: Text('Cancelado')),
                    ],
                    onChanged: (value) => setDialogState(() {
                      status = value ?? status;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: assignedMembershipId,
                    decoration: const InputDecoration(labelText: 'Responsavel'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sem atribuicao'),
                      ),
                      ...widget.members
                          .where((member) => const {
                                'pastor',
                                'church_admin',
                                'leader',
                              }.contains(member.role))
                          .map(
                            (member) => DropdownMenuItem<String?>(
                              value: member.membershipId,
                              child: Text(member.fullName),
                            ),
                          ),
                    ],
                    onChanged: (value) => setDialogState(() {
                      assignedMembershipId = value;
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: response,
                    minLines: 2,
                    maxLines: 4,
                    decoration:
                        const InputDecoration(labelText: 'Resposta ao membro'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: internal,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: 'Nota pastoral interna'),
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
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await _repository.updatePastoralRequest(
        requestId: request.id,
        status: status,
        publicResponse: response.text.trim().isEmpty ? null : response.text,
        internalNote: internal.text.trim().isEmpty ? null : internal.text,
        assignedMembershipId: assignedMembershipId,
      );
      await _refresh();
    }
    response.dispose();
    internal.dispose();
  }

  Future<void> _updateAdministrative(AdministrativeRequest request) async {
    final response = await _askText(
      title: 'Concluir pedido administrativo',
      label: 'Resposta ao membro',
      required: true,
    );
    if (response == null) {
      return;
    }
    await _repository.reviewAdministrativeRequest(
      requestId: request.id,
      status: 'completed',
      response: response,
    );
    await _refresh();
  }

  Future<String?> _askText({
    required String title,
    required String label,
    bool required = false,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (required && value.isEmpty) {
                return;
              }
              Navigator.of(context).pop(value);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_RequestsData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data ?? _RequestsData.empty;
        final urgent =
            data.pastoralRequests.where((item) => item.isUrgent).length;
        final unassigned = data.pastoralRequests
            .where((item) => item.assignedMembershipId == null)
            .length;
        final pendingJoin =
            data.joinRequests.where((item) => item.status == 'pending').length;
        final newPastoral =
            data.pastoralRequests.where((item) => item.status == 'new').length;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              WorkspaceSectionCard(
                title: 'Pedidos',
                subtitle: 'O que precisa de acompanhamento pastoral.',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.how_to_reg_outlined, size: 18),
                      label: Text('$pendingJoin entrada(s)'),
                      onPressed: () => _tabController.animateTo(0),
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.volunteer_activism_outlined,
                        size: 18,
                      ),
                      label: Text('$newPastoral pastoral(is)'),
                      onPressed: () => _tabController.animateTo(1),
                    ),
                    ActionChip(
                      avatar:
                          const Icon(Icons.priority_high_outlined, size: 18),
                      label: Text('$urgent urgente(s)'),
                      onPressed: () => _tabController.animateTo(1),
                    ),
                    ActionChip(
                      avatar:
                          const Icon(Icons.person_search_outlined, size: 18),
                      label: Text('$unassigned sem responsável'),
                      onPressed: () => _tabController.animateTo(1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Entrada de membros'),
                  Tab(text: 'Pedidos pastorais'),
                  Tab(text: 'Secretaria/Admin'),
                ],
              ),
              SizedBox(
                height: 620,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _JoinRequestsList(
                      requests: data.joinRequests,
                      readOnly: widget.readOnly,
                      onApprove: (request) => _reviewJoin(request, 'approved'),
                      onReject: (request) => _reviewJoin(
                        request,
                        'rejected',
                        requireNotes: true,
                      ),
                      onMoreInfo: (request) => _reviewJoin(
                        request,
                        'more_information_required',
                        requireNotes: true,
                      ),
                    ),
                    _PastoralRequestsList(
                      requests: data.pastoralRequests,
                      readOnly: widget.readOnly,
                      onOpen: (request) async {
                        await _repository.recordPastoralOpen(request.id);
                        if (mounted) {
                          await _updatePastoral(request);
                        }
                      },
                    ),
                    _AdministrativeRequestsList(
                      requests: data.administrativeRequests,
                      readOnly: widget.readOnly,
                      onComplete: _updateAdministrative,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _JoinRequestsList extends StatelessWidget {
  const _JoinRequestsList({
    required this.requests,
    required this.readOnly,
    required this.onApprove,
    required this.onReject,
    required this.onMoreInfo,
  });

  final List<ChurchJoinRequest> requests;
  final bool readOnly;
  final ValueChanged<ChurchJoinRequest> onApprove;
  final ValueChanged<ChurchJoinRequest> onReject;
  final ValueChanged<ChurchJoinRequest> onMoreInfo;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const _EmptyState(
          message:
              'Ainda nao existem pedidos de ministerio, grupo, voluntariado, batismo ou transferencia.');
    }
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: requests.map((request) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _RequestAvatar(
                    avatarUrl: request.avatarUrl,
                    fallbackIcon: Icons.person_add,
                  ),
                  title: Text(request.requestKindLabel),
                  subtitle: Text(
                    'Membro: ${request.fullName}${request.phone == null ? '' : ' - ${request.phone}'}\n${request.statusLabel}'
                    '${request.neighborhood == null ? '' : '\nBairro: ${request.neighborhood}'}'
                    '${request.previousChurch == null ? '' : '\nIgreja anterior: ${request.previousChurch}'}'
                    '${request.ministryInterest == null ? '' : '\nInteresse: ${request.ministryInterest}'}',
                  ),
                ),
                if (request.reason != null) Text(request.reason!),
                if (request.informationRequested != null) ...[
                  const SizedBox(height: 8),
                  Text(
                      'Informacao solicitada: ${request.informationRequested}'),
                ],
                if (request.memberResponse != null) ...[
                  const SizedBox(height: 8),
                  Text('Resposta do membro: ${request.memberResponse}'),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: readOnly ? null : () => onMoreInfo(request),
                      icon: const Icon(Icons.help_outline),
                      label: const Text('Mais informacoes'),
                    ),
                    FilledButton.icon(
                      onPressed: readOnly ? null : () => onApprove(request),
                      icon: const Icon(Icons.check),
                      label: const Text('Aprovar'),
                    ),
                    OutlinedButton.icon(
                      onPressed: readOnly ? null : () => onReject(request),
                      icon: const Icon(Icons.close),
                      label: const Text('Rejeitar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PastoralRequestsList extends StatelessWidget {
  const _PastoralRequestsList({
    required this.requests,
    required this.readOnly,
    required this.onOpen,
  });

  final List<PastoralCareRequest> requests;
  final bool readOnly;
  final ValueChanged<PastoralCareRequest> onOpen;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const _EmptyState(
          message:
              'Nao existem pedidos pastorais pendentes. Pedidos de oracao, aconselhamento, visita e apoio aparecem aqui.');
    }
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: requests.map((request) {
        return Card(
          color: request.isUrgent
              ? Theme.of(context).colorScheme.errorContainer
              : null,
          child: ListTile(
            leading: _RequestAvatar(
              avatarUrl: request.requesterAvatarUrl,
              fallbackIcon: request.isConfidential
                  ? Icons.lock_outline
                  : Icons.favorite_border,
            ),
            title: Text(request.title),
            subtitle: Text(
              'Membro: ${request.requesterName ?? 'Sem nome'}\n'
              '${request.categoryLabel} - ${request.statusLabel} - ${request.urgencyLabel}'
              '${request.sourceTable == 'prayer_requests' ? ' - Pedido de oracao' : ''}'
              '\n${request.isConfidential ? 'Conteudo confidencial' : request.message}',
            ),
            trailing: OutlinedButton(
              onPressed: readOnly ? null : () => onOpen(request),
              child: const Text('Abrir'),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AdministrativeRequestsList extends StatelessWidget {
  const _AdministrativeRequestsList({
    required this.requests,
    required this.readOnly,
    required this.onComplete,
  });

  final List<AdministrativeRequest> requests;
  final bool readOnly;
  final ValueChanged<AdministrativeRequest> onComplete;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const _EmptyState(
          message:
              'Nao existem pedidos administrativos. Declaracoes, documentos, transferencias e atualizacoes de dados aparecem aqui.');
    }
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: requests.map((request) {
        return Card(
          child: ListTile(
            leading: _RequestAvatar(
              avatarUrl: request.requesterAvatarUrl,
              fallbackIcon: Icons.assignment_outlined,
            ),
            title: Text(request.subject),
            subtitle: Text(
              'Membro: ${request.requesterName ?? 'Sem nome'}\n'
              '${request.typeLabel} - ${request.statusLabel}\n${request.description}',
            ),
            trailing: OutlinedButton(
              onPressed: readOnly ? null : () => onComplete(request),
              child: const Text('Concluir'),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RequestAvatar extends StatelessWidget {
  const _RequestAvatar({
    required this.fallbackIcon,
    this.avatarUrl,
  });

  final String? avatarUrl;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    return ExpandableProfileAvatar(
      avatarUrl: url,
      label: 'Membro',
      fallbackIcon: fallbackIcon,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _RequestsData {
  const _RequestsData({
    required this.joinRequests,
    required this.pastoralRequests,
    required this.administrativeRequests,
  });

  final List<ChurchJoinRequest> joinRequests;
  final List<PastoralCareRequest> pastoralRequests;
  final List<AdministrativeRequest> administrativeRequests;

  static const empty = _RequestsData(
    joinRequests: [],
    pastoralRequests: [],
    administrativeRequests: [],
  );
}
