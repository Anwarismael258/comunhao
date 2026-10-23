import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:flutter/material.dart';

import '../../operations/presentation/church_operations_page.dart';

class ChurchErpPage extends StatelessWidget {
  const ChurchErpPage({
    required this.church,
    required this.members,
    required this.ministries,
    required this.assets,
    required this.backofficeRepository,
    required this.operationsRepository,
    required this.readOnly,
    required this.onChanged,
    super.key,
    this.branchReportingRepository,
  });

  final ManagedChurch church;
  final List<ManagedMember> members;
  final List<ChurchMinistry> ministries;
  final List<ChurchAsset> assets;
  final BackofficeRepository backofficeRepository;
  final OperationsRepository operationsRepository;
  final BranchReportingRepository? branchReportingRepository;
  final bool readOnly;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final branchRepository =
        branchReportingRepository ?? SupabaseBranchReportingRepository();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const Material(
            child: TabBar(
              tabs: [
                Tab(icon: Icon(Icons.account_tree_outlined), text: 'Sede'),
                Tab(icon: Icon(Icons.apps_outlined), text: 'Operacoes'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _OrganizationDashboardTab(
                  church: church,
                  repository: branchRepository,
                  readOnly: readOnly,
                  onChanged: onChanged,
                ),
                ChurchOperationsPage(
                  church: church,
                  members: members,
                  ministries: ministries,
                  assets: assets,
                  backofficeRepository: backofficeRepository,
                  operationsRepository: operationsRepository,
                  readOnly: readOnly,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizationDashboardTab extends StatefulWidget {
  const _OrganizationDashboardTab({
    required this.church,
    required this.repository,
    required this.readOnly,
    required this.onChanged,
  });

  final ManagedChurch church;
  final BranchReportingRepository repository;
  final bool readOnly;
  final Future<void> Function() onChanged;

  @override
  State<_OrganizationDashboardTab> createState() =>
      _OrganizationDashboardTabState();
}

class _OrganizationDashboardTabState extends State<_OrganizationDashboardTab> {
  late Future<OrganizationDashboard> _future;
  bool _includeDemo = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<OrganizationDashboard> _load() {
    return widget.repository.fetchDashboard(
      churchId: widget.church.id,
      includeDemo: _includeDemo,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await widget.onChanged();
      if (mounted) {
        await _refresh();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(error))),
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
    return FutureBuilder<OrganizationDashboard>(
      future: _future,
      builder: (context, snapshot) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const WorkspaceHero(
              surface: ComunhaoSurface.churchAdmin,
              title: 'Painel consolidado',
              subtitle:
                  'Sede, congregacoes, metas, alertas e relatorios executivos da organizacao.',
              icon: Icons.account_tree_outlined,
              color: Color(0xFFB57EDC),
            ),
            SwitchListTile(
              title: const Text('Incluir dados de demonstracao'),
              value: _includeDemo,
              onChanged: _busy
                  ? null
                  : (value) {
                      setState(() {
                        _includeDemo = value;
                        _future = _load();
                      });
                    },
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState != ConnectionState.done)
              const Center(child: CircularProgressIndicator())
            else if (snapshot.hasError)
              _StateBox(
                title: 'Painel indisponivel',
                message: _friendlyError(snapshot.error!),
              )
            else if (snapshot.data != null) ...[
              _actions(snapshot.data!),
              const SizedBox(height: 16),
              _metrics(snapshot.data!),
              const SizedBox(height: 16),
              _branches(snapshot.data!),
              const SizedBox(height: 16),
              _goals(snapshot.data!),
              const SizedBox(height: 16),
              _alerts(snapshot.data!),
              const SizedBox(height: 16),
              _reports(snapshot.data!),
            ],
          ],
        );
      },
    );
  }

  Widget _actions(OrganizationDashboard dashboard) {
    final blocked = _busy || widget.readOnly;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: blocked ? null : _openBranchDialog,
          icon: const Icon(Icons.add_business_outlined),
          label: const Text('Criar congregacao'),
        ),
        FilledButton.icon(
          onPressed: blocked || dashboard.units.length < 2
              ? null
              : () => _openTransferDialog(dashboard.units),
          icon: const Icon(Icons.compare_arrows_outlined),
          label: const Text('Transferir membro'),
        ),
        OutlinedButton.icon(
          onPressed: blocked ? null : _refresh,
          icon: const Icon(Icons.refresh_outlined),
          label: const Text('Atualizar'),
        ),
      ],
    );
  }

  Widget _metrics(OrganizationDashboard dashboard) {
    final revenue = dashboard.metric('monthly_revenue');
    final expenses = dashboard.metric('monthly_expenses');
    final net = revenue - expenses;

    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width > 900 ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        WorkspaceMetricCard(
          label: 'Unidades',
          value: '${dashboard.metric('total_churches').toInt()}',
          icon: Icons.apartment_outlined,
        ),
        WorkspaceMetricCard(
          label: 'Membros ativos',
          value: '${dashboard.metric('total_members').toInt()}',
          icon: Icons.groups_outlined,
        ),
        WorkspaceMetricCard(
          label: 'Receitas do mes',
          value: _money(revenue),
          icon: Icons.trending_up_outlined,
        ),
        WorkspaceMetricCard(
          label: 'Resultado liquido',
          value: _money(net),
          icon: Icons.account_balance_wallet_outlined,
        ),
        WorkspaceMetricCard(
          label: 'Campanhas ativas',
          value: '${dashboard.metric('active_campaigns').toInt()}',
          icon: Icons.volunteer_activism_outlined,
        ),
        WorkspaceMetricCard(
          label: 'Tarefas atrasadas',
          value: '${dashboard.metric('overdue_tasks').toInt()}',
          icon: Icons.warning_amber_outlined,
        ),
        WorkspaceMetricCard(
          label: 'Alertas abertos',
          value: '${dashboard.metric('open_alerts').toInt()}',
          icon: Icons.notifications_active_outlined,
        ),
        WorkspaceMetricCard(
          label: 'Metas em risco',
          value: '${dashboard.metric('goals_at_risk').toInt()}',
          icon: Icons.flag_outlined,
        ),
      ],
    );
  }

  Widget _branches(OrganizationDashboard dashboard) {
    return WorkspaceSectionCard(
      title: 'Filiais e congregacoes',
      subtitle: 'Hierarquia, pastor responsavel e membros por unidade.',
      child: dashboard.units.isEmpty
          ? const Text('Ainda nao existem congregacoes cadastradas.')
          : Column(
              children: dashboard.units
                  .map(
                    (unit) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Icon(unit.parentChurchId == null
                            ? Icons.church_outlined
                            : Icons.apartment_outlined),
                      ),
                      title: Text(unit.name),
                      subtitle: Text(
                        '${unit.typeLabel} - ${unit.unitStatus}'
                        '${unit.city == null ? '' : '\n${unit.city}, ${unit.province ?? ''}'}'
                        '${unit.pastorName == null ? '' : '\nPastor: ${unit.pastorName}'}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${unit.memberCount}'),
                          const Text('membros'),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _goals(OrganizationDashboard dashboard) {
    return WorkspaceSectionCard(
      title: 'Metas e objetivos',
      subtitle:
          'Meta versus resultado, sem somar demo quando o filtro desliga.',
      child: dashboard.goals.isEmpty
          ? const Text('Nenhuma meta foi definida para este periodo.')
          : Column(
              children: dashboard.goals
                  .map(
                    (goal) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.flag_outlined),
                      ),
                      title: Text(goal.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${goal.currentValue}/${goal.targetValue} ${goal.unit} - ${goal.status}',
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(value: goal.progress),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _alerts(OrganizationDashboard dashboard) {
    return WorkspaceSectionCard(
      title: 'Alertas executivos',
      subtitle: 'Riscos e pendencias que precisam de acompanhamento.',
      child: dashboard.alerts.isEmpty
          ? const Text('Nao existem alertas executivos ativos.')
          : Column(
              children: dashboard.alerts
                  .map(
                    (alert) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Icon(_alertIcon(alert.severity)),
                      ),
                      title: Text(alert.title),
                      subtitle:
                          Text('${alert.severity} - ${alert.description}'),
                      trailing: alert.status == 'resolved'
                          ? const Icon(Icons.check_circle_outline)
                          : TextButton(
                              onPressed: _busy || widget.readOnly
                                  ? null
                                  : () => _resolveAlert(alert),
                              child: const Text('Resolver'),
                            ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _reports(OrganizationDashboard dashboard) {
    return WorkspaceSectionCard(
      title: 'Relatorios executivos',
      subtitle: 'Exportacao registada com auditoria e filtros do backend.',
      child: dashboard.reports.isEmpty
          ? const Text('Ainda nao ha dados suficientes para este relatorio.')
          : Column(
              children: dashboard.reports
                  .map(
                    (report) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.description_outlined),
                      ),
                      title: Text(report.title),
                      subtitle: Text(
                        '${_date(report.periodStart)} - ${_date(report.periodEnd)}'
                        '${report.isDemo ? '\nDemo' : ''}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: _busy
                            ? null
                            : (format) => _run(
                                  () => widget.repository.registerReportExport(
                                    reportId: report.id,
                                    format: format,
                                    containsSensitiveData: report.sensitive,
                                  ),
                                ),
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'pdf', child: Text('PDF')),
                          PopupMenuItem(value: 'csv', child: Text('CSV')),
                          PopupMenuItem(value: 'excel', child: Text('Excel')),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Future<void> _openBranchDialog() async {
    final nameController = TextEditingController();
    final cityController =
        TextEditingController(text: widget.church.city ?? '');
    final provinceController = TextEditingController(text: 'Maputo');
    final pastorPhoneController = TextEditingController();
    String unitType = 'congregation';
    String status = 'active';
    bool isDemo = true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nova congregacao'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: unitType,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(
                      value: 'congregation',
                      child: Text('Congregacao'),
                    ),
                    DropdownMenuItem(value: 'branch', child: Text('Filial')),
                    DropdownMenuItem(
                      value: 'preaching_point',
                      child: Text('Ponto de pregacao'),
                    ),
                    DropdownMenuItem(value: 'mission', child: Text('Missao')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => unitType = value ?? unitType),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Ativa')),
                    DropdownMenuItem(
                      value: 'preparation',
                      child: Text('Em preparacao'),
                    ),
                    DropdownMenuItem(
                      value: 'reorganization',
                      child: Text('Em reorganizacao'),
                    ),
                    DropdownMenuItem(
                      value: 'suspended',
                      child: Text('Suspensa'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? status),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(labelText: 'Cidade'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: provinceController,
                  decoration: const InputDecoration(labelText: 'Provincia'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pastorPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone do pastor existente',
                  ),
                ),
                SwitchListTile(
                  value: isDemo,
                  title: const Text('Dados de demonstracao'),
                  onChanged: (value) => setDialogState(() => isDemo = value),
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
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || nameController.text.trim().isEmpty) {
      return;
    }

    await _run(
      () => widget.repository.createBranch(
        parentChurchId: widget.church.id,
        name: nameController.text.trim(),
        unitType: unitType,
        city: cityController.text.trim(),
        province: provinceController.text.trim(),
        pastorPhone: pastorPhoneController.text.trim(),
        unitStatus: status,
        isDemo: isDemo,
      ),
    );
  }

  Future<void> _openTransferDialog(List<ChurchBranchUnit> units) async {
    final memberController = TextEditingController(text: '827688695');
    final reasonController = TextEditingController();
    String destinationId = units
        .firstWhere(
          (unit) => unit.id != widget.church.id,
          orElse: () => units.first,
        )
        .id;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Transferir membro'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: memberController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefone'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: destinationId,
                decoration:
                    const InputDecoration(labelText: 'Congregacao destino'),
                items: units
                    .where((unit) => unit.id != widget.church.id)
                    .map(
                      (unit) => DropdownMenuItem(
                        value: unit.id,
                        child: Text(unit.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setDialogState(
                    () => destinationId = value ?? destinationId),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Motivo'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Solicitar'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) {
      return;
    }

    await _run(
      () => widget.repository.createTransferRequest(
        memberPhone: memberController.text.trim(),
        originChurchId: widget.church.id,
        destinationChurchId: destinationId,
        reason: reasonController.text.trim(),
        isDemo: true,
      ),
    );
  }

  Future<void> _resolveAlert(ExecutiveAlert alert) async {
    await _run(
      () => widget.repository.resolveAlert(
        alertId: alert.id,
        resolution: 'Resolvido pelo painel da sede.',
      ),
    );
  }
}

class _StateBox extends StatelessWidget {
  const _StateBox({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return WorkspaceSectionCard(
      title: title,
      subtitle: message,
      child: const Text('Atualiza a pagina ou tenta novamente depois.'),
    );
  }
}

IconData _alertIcon(String severity) {
  return switch (severity) {
    'critical' => Icons.report_outlined,
    'high' => Icons.warning_amber_outlined,
    'low' => Icons.info_outline,
    _ => Icons.notifications_active_outlined,
  };
}

String _money(num value) => '${value.toStringAsFixed(2)} MZN';

String _date(DateTime value) {
  if (value.millisecondsSinceEpoch == 0) {
    return '-';
  }
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _friendlyError(Object error) {
  final raw = error.toString();
  final lower = raw.toLowerCase();
  if (lower.contains('not allowed')) {
    return 'Esta conta nao tem permissao para esta acao.';
  }
  if (lower.contains('profile not found')) {
    return 'Nao encontrei um perfil com esse telefone.';
  }
  if (lower.contains('postgrest') ||
      lower.contains('postgres') ||
      lower.contains('pgrst')) {
    return 'Nao foi possivel sincronizar o painel executivo agora.';
  }
  return raw;
}
