import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:flutter/material.dart';

import '../../church/models/church_branding.dart';
import '../../church/models/church_member.dart';

class MemberRequestsPage extends StatefulWidget {
  const MemberRequestsPage({
    required this.church,
    required this.member,
    this.repository,
    super.key,
  });

  final ChurchBranding church;
  final ChurchMember member;
  final CareRepository? repository;

  @override
  State<MemberRequestsPage> createState() => _MemberRequestsPageState();
}

class _MemberRequestsPageState extends State<MemberRequestsPage>
    with SingleTickerProviderStateMixin {
  late final CareRepository _repository;
  late final TabController _tabController;
  late Future<_MemberRequestsData> _future;

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

  Future<_MemberRequestsData> _load() async {
    final results = await Future.wait<dynamic>([
      _repository.fetchOwnJoinRequests(widget.church.id),
      _repository.fetchOwnPastoralRequests(widget.church.id),
      _repository.fetchOwnAdministrativeRequests(widget.church.id),
    ]);
    return _MemberRequestsData(
      joinRequests: results[0] as List<ChurchJoinRequest>,
      pastoralRequests: results[1] as List<PastoralCareRequest>,
      administrativeRequests: results[2] as List<AdministrativeRequest>,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MemberRequestsData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data ?? _MemberRequestsData.empty;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _RequestsHero(
                churchName: widget.church.name,
                onJoin: () => _tabController.animateTo(0),
                onPastoral: () => _tabController.animateTo(1),
                onAdministrative: () => _tabController.animateTo(2),
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Ministerios e grupos'),
                  Tab(text: 'Pedido pastoral'),
                  Tab(text: 'Administrativo'),
                ],
              ),
              SizedBox(
                height: 720,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _JoinRequestMemberTab(
                      church: widget.church,
                      member: widget.member,
                      requests: data.joinRequests,
                      repository: _repository,
                      onChanged: _refresh,
                    ),
                    _PastoralRequestMemberTab(
                      church: widget.church,
                      requests: data.pastoralRequests,
                      repository: _repository,
                      onChanged: _refresh,
                    ),
                    _AdministrativeRequestMemberTab(
                      church: widget.church,
                      requests: data.administrativeRequests,
                      repository: _repository,
                      onChanged: _refresh,
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

class _JoinRequestMemberTab extends StatefulWidget {
  const _JoinRequestMemberTab({
    required this.church,
    required this.member,
    required this.requests,
    required this.repository,
    required this.onChanged,
  });

  final ChurchBranding church;
  final ChurchMember member;
  final List<ChurchJoinRequest> requests;
  final CareRepository repository;
  final Future<void> Function() onChanged;

  @override
  State<_JoinRequestMemberTab> createState() => _JoinRequestMemberTabState();
}

class _JoinRequestMemberTabState extends State<_JoinRequestMemberTab> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _neighborhood = TextEditingController();
  final _previous = TextEditingController();
  final _reason = TextEditingController();
  final _ministry = TextEditingController();
  final _observation = TextEditingController();
  String _entryType = 'ministry';
  String _ministryOption = 'not_sure';
  bool _consent = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.text = widget.member.fullName;
    _phone.text = widget.member.phone ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _neighborhood.dispose();
    _previous.dispose();
    _reason.dispose();
    _ministry.dispose();
    _observation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().length < 3 ||
        _phone.text.trim().isEmpty ||
        !_consent) {
      _message('Preenche nome, telefone e consentimento.');
      return;
    }
    final selectedEntry = _entryTypeLabel(_entryType);
    final selectedMinistry = _ministryOptionLabel(_ministryOption);
    final typedMinistry = _ministry.text.trim();
    final ministryInterest = typedMinistry.isEmpty
        ? selectedMinistry
        : '$selectedMinistry - $typedMinistry';
    final reason = [
      'Tipo de pedido: $selectedEntry',
      if (_reason.text.trim().isNotEmpty) _reason.text.trim(),
    ].join('\n');
    setState(() => _busy = true);
    try {
      await widget.repository.createJoinRequest(
        churchId: widget.church.id,
        requestKind: _entryType,
        fullName: _name.text,
        phone: _phone.text,
        neighborhood: _neighborhood.text,
        previousChurch: _previous.text,
        reason: reason,
        ministryInterest: ministryInterest,
        observation: _observation.text,
        consent: _consent,
      );
      await widget.onChanged();
      _message('Pedido enviado para a igreja.');
    } catch (error) {
      _message('Nao foi possivel enviar o pedido: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _entryTypeLabel(String value) {
    return switch (value) {
      'ministry' => 'Entrada em ministerio',
      'group' => 'Entrada em grupo/celula',
      'volunteer' => 'Servir como voluntario',
      'baptism' => 'Preparacao para batismo',
      'transfer' => 'Transferencia de igreja',
      _ => 'Outro pedido de entrada',
    };
  }

  String _ministryOptionLabel(String value) {
    return switch (value) {
      'worship' => 'Louvor',
      'intercession' => 'Intercessao',
      'evangelism' => 'Evangelismo',
      'children' => 'Criancas',
      'youth' => 'Jovens',
      'women' => 'Mulheres',
      'men' => 'Homens',
      'couples' => 'Casais',
      'media' => 'Midia e comunicacao',
      'reception' => 'Recepcao',
      'cells' => 'Celulas',
      'not_sure' => 'Ainda nao sei',
      _ => 'Outro',
    };
  }

  Future<void> _respond(ChurchJoinRequest request) async {
    final controller = TextEditingController();
    final response = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Responder pedido'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration:
              const InputDecoration(labelText: 'Informacoes adicionais'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (response == null || response.isEmpty) {
      return;
    }
    await widget.repository.respondJoinRequest(
      requestId: request.id,
      response: response,
    );
    await widget.onChanged();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        const _InfoCard(
          title: 'Ministerios, grupos e servico',
          message:
              'Como ja es membro desta igreja, usa esta area para pedir entrada em ministerios, grupos, celulas, voluntariado, batismo ou transferencia. O pedido aparece no app do pastor.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _entryType,
                  decoration: const InputDecoration(
                    labelText: 'O que deseja pedir?',
                    prefixIcon: Icon(Icons.route_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'ministry',
                      child: Text('Entrar num ministerio'),
                    ),
                    DropdownMenuItem(
                      value: 'group',
                      child: Text('Entrar num grupo/celula'),
                    ),
                    DropdownMenuItem(
                      value: 'volunteer',
                      child: Text('Servir como voluntario'),
                    ),
                    DropdownMenuItem(
                      value: 'baptism',
                      child: Text('Preparacao para batismo'),
                    ),
                    DropdownMenuItem(
                      value: 'transfer',
                      child: Text('Transferencia de igreja'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _entryType = value ?? 'ministry'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _ministryOption,
                  decoration: const InputDecoration(
                    labelText: 'Ministerio, grupo ou area',
                    prefixIcon: Icon(Icons.groups_2_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'not_sure', child: Text('Ainda nao sei')),
                    DropdownMenuItem(value: 'worship', child: Text('Louvor')),
                    DropdownMenuItem(
                        value: 'intercession', child: Text('Intercessao')),
                    DropdownMenuItem(
                        value: 'evangelism', child: Text('Evangelismo')),
                    DropdownMenuItem(
                        value: 'children', child: Text('Criancas')),
                    DropdownMenuItem(value: 'youth', child: Text('Jovens')),
                    DropdownMenuItem(value: 'women', child: Text('Mulheres')),
                    DropdownMenuItem(value: 'men', child: Text('Homens')),
                    DropdownMenuItem(value: 'couples', child: Text('Casais')),
                    DropdownMenuItem(
                        value: 'media', child: Text('Midia e comunicacao')),
                    DropdownMenuItem(
                        value: 'reception', child: Text('Recepcao')),
                    DropdownMenuItem(value: 'cells', child: Text('Celulas')),
                    DropdownMenuItem(value: 'other', child: Text('Outro')),
                  ],
                  onChanged: (value) =>
                      setState(() => _ministryOption = value ?? 'not_sure'),
                ),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                ),
                TextField(
                  controller: _neighborhood,
                  decoration:
                      const InputDecoration(labelText: 'Bairro ou zona'),
                ),
                TextField(
                  controller: _previous,
                  decoration:
                      const InputDecoration(labelText: 'Igreja anterior'),
                ),
                TextField(
                  controller: _reason,
                  decoration:
                      const InputDecoration(labelText: 'Motivo do pedido'),
                ),
                TextField(
                  controller: _ministry,
                  decoration: const InputDecoration(
                      labelText: 'Detalhe adicional da area escolhida'),
                ),
                TextField(
                  controller: _observation,
                  decoration: const InputDecoration(labelText: 'Observacao'),
                ),
                SwitchListTile(
                  value: _consent,
                  title: const Text('Autorizo o tratamento dos meus dados'),
                  onChanged: (value) => setState(() => _consent = value),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: const Icon(Icons.how_to_reg_outlined),
                    label: const Text('Enviar pedido'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.requests.isEmpty)
          const _MemberEmpty(
            message: 'Ainda nao existem pedidos de ministerio ou grupo.',
          )
        else
          ...widget.requests.map(
            (request) => Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(Icons.how_to_reg_outlined),
                    title: Text(request.fullName),
                    subtitle: Text(
                      '${request.requestKindLabel} - ${request.statusLabel}${request.informationRequested == null ? '' : '\nPedido: ${request.informationRequested}'}${request.decisionReason == null ? '' : '\nDecisao: ${request.decisionReason}'}',
                    ),
                    trailing: request.canMemberRespond
                        ? TextButton(
                            onPressed: () => _respond(request),
                            child: const Text('Responder'),
                          )
                        : null,
                  ),
                  if (request.reviewNotes != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _ResponseNote(message: request.reviewNotes!),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ResponseNote extends StatelessWidget {
  const _ResponseNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('Resposta da igreja: $message'),
    );
  }
}

class _PastoralRequestMemberTab extends StatefulWidget {
  const _PastoralRequestMemberTab({
    required this.church,
    required this.requests,
    required this.repository,
    required this.onChanged,
  });

  final ChurchBranding church;
  final List<PastoralCareRequest> requests;
  final CareRepository repository;
  final Future<void> Function() onChanged;

  @override
  State<_PastoralRequestMemberTab> createState() =>
      _PastoralRequestMemberTabState();
}

class _PastoralRequestMemberTabState extends State<_PastoralRequestMemberTab> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  final _availability = TextEditingController();
  String _category = 'prayer';
  String _urgency = 'normal';
  String _privacy = 'pastor_only';
  String _contact = 'phone';
  bool _consentForwarding = false;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _availability.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().length < 3 || _message.text.trim().length < 5) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repository.createPastoralRequest(
        churchId: widget.church.id,
        category: _category,
        title: _title.text,
        message: _message.text,
        urgency: _urgency,
        privacyLevel: _privacy,
        preferredContact: _contact,
        contactAvailability: _availability.text,
        consentForwarding: _consentForwarding,
      );
      _title.clear();
      _message.clear();
      _availability.clear();
      await widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido pastoral enviado.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nao foi possivel enviar: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        const _InfoCard(
          title: 'Pedido pastoral',
          message:
              'Envie aqui pedidos de oracao, aconselhamento, visita, apoio social ou conversa com o pastor. A igreja recebe no app do pastor.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: const [
                    DropdownMenuItem(value: 'prayer', child: Text('Oracao')),
                    DropdownMenuItem(
                        value: 'counseling', child: Text('Aconselhamento')),
                    DropdownMenuItem(value: 'visit', child: Text('Visita')),
                    DropdownMenuItem(
                        value: 'social_support', child: Text('Apoio social')),
                    DropdownMenuItem(value: 'baptism', child: Text('Batismo')),
                    DropdownMenuItem(
                        value: 'marriage', child: Text('Casamento')),
                    DropdownMenuItem(value: 'funeral', child: Text('Funeral')),
                  ],
                  onChanged: (value) =>
                      setState(() => _category = value ?? 'prayer'),
                ),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Assunto'),
                ),
                TextField(
                  controller: _message,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Mensagem'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _urgency,
                  decoration: const InputDecoration(labelText: 'Urgencia'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Baixa')),
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'high', child: Text('Alta')),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
                  ],
                  onChanged: (value) =>
                      setState(() => _urgency = value ?? 'normal'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _privacy,
                  decoration: const InputDecoration(labelText: 'Privacidade'),
                  items: const [
                    DropdownMenuItem(
                        value: 'pastor_only', child: Text('Somente pastor')),
                    DropdownMenuItem(
                        value: 'assigned_leader',
                        child: Text('Pastor e lider designado')),
                    DropdownMenuItem(
                        value: 'pastoral_team', child: Text('Equipa pastoral')),
                  ],
                  onChanged: (value) =>
                      setState(() => _privacy = value ?? 'pastor_only'),
                ),
                TextField(
                  controller: _availability,
                  decoration:
                      const InputDecoration(labelText: 'Disponibilidade'),
                ),
                SwitchListTile(
                  value: _consentForwarding,
                  title:
                      const Text('Autorizo encaminhamento quando necessario'),
                  onChanged: (value) =>
                      setState(() => _consentForwarding = value),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: const Icon(Icons.volunteer_activism_outlined),
                    label: const Text('Enviar pedido pastoral'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.requests.isEmpty)
          const _MemberEmpty(
              message: 'Nao existem pedidos pastorais pendentes.')
        else
          ...widget.requests.map(
            (request) => Card(
              child: ListTile(
                leading: Icon(
                  request.isConfidential
                      ? Icons.lock_outline
                      : Icons.favorite_border,
                ),
                title: Text(request.title),
                subtitle: Text(
                  '${request.statusLabel} - ${request.urgencyLabel}'
                  '${request.latestPublicResponse == null ? '' : '\nResposta: ${request.latestPublicResponse}'}',
                ),
                isThreeLine: request.latestPublicResponse != null,
              ),
            ),
          ),
      ],
    );
  }
}

class _AdministrativeRequestMemberTab extends StatefulWidget {
  const _AdministrativeRequestMemberTab({
    required this.church,
    required this.requests,
    required this.repository,
    required this.onChanged,
  });

  final ChurchBranding church;
  final List<AdministrativeRequest> requests;
  final CareRepository repository;
  final Future<void> Function() onChanged;

  @override
  State<_AdministrativeRequestMemberTab> createState() =>
      _AdministrativeRequestMemberTabState();
}

class _AdministrativeRequestMemberTabState
    extends State<_AdministrativeRequestMemberTab> {
  final _subject = TextEditingController();
  final _description = TextEditingController();
  String _type = 'member_statement';
  bool _busy = false;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_subject.text.trim().length < 3 ||
        _description.text.trim().length < 5) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repository.createAdministrativeRequest(
        churchId: widget.church.id,
        requestType: _type,
        subject: _subject.text,
        description: _description.text,
      );
      _subject.clear();
      _description.clear();
      await widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido administrativo enviado.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nao foi possivel criar pedido: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        const _InfoCard(
          title: 'Pedido administrativo',
          message:
              'Use para declaracoes, documentos, atualizacao de dados, transferencia ou pedidos de secretaria.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(
                        value: 'member_statement', child: Text('Declaracao')),
                    DropdownMenuItem(
                        value: 'data_update',
                        child: Text('Atualizacao de dados')),
                    DropdownMenuItem(
                        value: 'ministry_entry',
                        child: Text('Entrada em ministerio')),
                    DropdownMenuItem(
                        value: 'group_entry', child: Text('Entrada em grupo')),
                    DropdownMenuItem(
                        value: 'transfer', child: Text('Transferencia')),
                    DropdownMenuItem(
                        value: 'document', child: Text('Documento')),
                    DropdownMenuItem(value: 'other', child: Text('Outro')),
                  ],
                  onChanged: (value) =>
                      setState(() => _type = value ?? 'other'),
                ),
                TextField(
                  controller: _subject,
                  decoration: const InputDecoration(labelText: 'Assunto'),
                ),
                TextField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Descricao'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: const Icon(Icons.assignment_outlined),
                    label: const Text('Criar pedido administrativo'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.requests.isEmpty)
          const _MemberEmpty(message: 'Nao existem pedidos administrativos.')
        else
          ...widget.requests.map(
            (request) => Card(
              child: ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: Text(request.subject),
                subtitle: Text(
                  '${request.typeLabel} - ${request.statusLabel}'
                  '${request.response == null ? '' : '\nResposta: ${request.response}'}',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RequestsHero extends StatelessWidget {
  const _RequestsHero({
    required this.churchName,
    required this.onJoin,
    required this.onPastoral,
    required this.onAdministrative,
  });

  final String churchName;
  final VoidCallback onJoin;
  final VoidCallback onPastoral;
  final VoidCallback onAdministrative;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.assignment_turned_in_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedidos para $churchName',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'O que enviares aqui aparece no app da igreja para o pastor ou equipa administrativa acompanhar.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 720;
                final actions = [
                  _RequestShortcut(
                    icon: Icons.how_to_reg_outlined,
                    title: 'Ministerios e grupos',
                    subtitle: 'Servir, celula, batismo ou transferencia',
                    onTap: onJoin,
                  ),
                  _RequestShortcut(
                    icon: Icons.volunteer_activism_outlined,
                    title: 'Pedido pastoral',
                    subtitle: 'Oracao, visita, aconselhamento ou apoio',
                    onTap: onPastoral,
                  ),
                  _RequestShortcut(
                    icon: Icons.assignment_outlined,
                    title: 'Pedido administrativo',
                    subtitle: 'Documento, dados, declaracao ou secretaria',
                    onTap: onAdministrative,
                  ),
                ];
                if (narrow) {
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
                return Row(
                  children: actions
                      .map(
                        (action) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: action,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestShortcut extends StatelessWidget {
  const _RequestShortcut({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(title),
        subtitle: Text(message),
      ),
    );
  }
}

class _MemberEmpty extends StatelessWidget {
  const _MemberEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(message),
      ),
    );
  }
}

class _MemberRequestsData {
  const _MemberRequestsData({
    required this.joinRequests,
    required this.pastoralRequests,
    required this.administrativeRequests,
  });

  final List<ChurchJoinRequest> joinRequests;
  final List<PastoralCareRequest> pastoralRequests;
  final List<AdministrativeRequest> administrativeRequests;

  static const empty = _MemberRequestsData(
    joinRequests: [],
    pastoralRequests: [],
    administrativeRequests: [],
  );
}
