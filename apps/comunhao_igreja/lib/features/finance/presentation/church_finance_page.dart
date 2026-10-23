import 'dart:async';

import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:flutter/material.dart';

import 'church_contributions_page.dart';
import 'church_expenses_page.dart';
import 'church_subscription_page.dart';
import 'church_withdrawals_page.dart';
import '../widgets/finance_format.dart';

class ChurchFinancePage extends StatefulWidget {
  const ChurchFinancePage({
    super.key,
    required this.church,
    required this.financeRepository,
    required this.backofficeRepository,
    required this.walletDashboard,
    required this.walletLedger,
    required this.withdrawals,
    required this.expenses,
    required this.campaigns,
    required this.plans,
    required this.subscriptionRequests,
    required this.currentPhone,
    required this.isReadOnly,
    required this.showMessage,
    required this.onChanged,
    required this.onEditCampaign,
    required this.onArchiveCampaign,
    this.initialCheckoutPlanCode,
  });

  final ManagedChurch church;
  final FinanceRepository financeRepository;
  final BackofficeRepository backofficeRepository;
  final List<WalletProviderSummary> walletDashboard;
  final List<WalletLedgerEntry> walletLedger;
  final List<WalletWithdrawalRequest> withdrawals;
  final List<ChurchExpense> expenses;
  final List<ManagedCampaign> campaigns;
  final List<SubscriptionPlan> plans;
  final List<ChurchSubscriptionRequest> subscriptionRequests;
  final String? currentPhone;
  final bool isReadOnly;
  final void Function(String message) showMessage;
  final Future<void> Function() onChanged;
  final void Function(ManagedCampaign campaign) onEditCampaign;
  final void Function(ManagedCampaign campaign) onArchiveCampaign;
  final String? initialCheckoutPlanCode;

  @override
  State<ChurchFinancePage> createState() => _ChurchFinancePageState();
}

class _ChurchFinancePageState extends State<ChurchFinancePage> {
  ChurchFinanceSnapshot _snapshot = ChurchFinanceSnapshot.empty();
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSnapshot());
  }

  @override
  void didUpdateWidget(covariant ChurchFinancePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.church.id != widget.church.id ||
        oldWidget.walletLedger.length != widget.walletLedger.length ||
        oldWidget.expenses.length != widget.expenses.length ||
        oldWidget.withdrawals.length != widget.withdrawals.length) {
      unawaited(_loadSnapshot());
    }
  }

  Future<void> _loadSnapshot() async {
    setState(() => _loading = true);
    try {
      final snapshot =
          await widget.financeRepository.fetchChurchFinanceSnapshot(
        churchId: widget.church.id,
      );
      if (mounted) {
        setState(() => _snapshot = snapshot);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _snapshot = ChurchFinanceSnapshot.empty());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _changed() async {
    await widget.onChanged();
    await _loadSnapshot();
  }

  WalletProviderSummary _walletFor(String provider) {
    return widget.walletDashboard.firstWhere(
      (item) => item.provider == provider,
      orElse: () => WalletProviderSummary(
        provider: provider,
        balance: 0,
        totalCredits: 0,
        totalDebits: 0,
        incomingToday: 0,
        incomingMonth: 0,
      ),
    );
  }

  num _creditTotalFor(String entryType) {
    return widget.walletLedger
        .where((entry) =>
            entry.isCredit &&
            entry.status == 'posted' &&
            entry.entryType == entryType)
        .fold<num>(0, (sum, entry) => sum + entry.amount);
  }

  num get _otherCreditTotal {
    const known = {'tithe', 'offering', 'campaign'};
    return widget.walletLedger
        .where((entry) =>
            entry.isCredit &&
            entry.status == 'posted' &&
            !known.contains(entry.entryType))
        .fold<num>(0, (sum, entry) => sum + entry.amount);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      key: ValueKey('finance-tabs-${widget.initialCheckoutPlanCode ?? 'home'}'),
      length: 5,
      initialIndex: widget.initialCheckoutPlanCode == null ? 0 : 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkspaceSectionCard(
            title: 'Financeiro da Igreja',
            subtitle: widget.isReadOnly
                ? 'Modo leitura ativo enquanto a subscricao estiver suspensa.'
                : 'Saldos separados: membro, igreja e plataforma nunca se misturam.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loading) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                ],
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    Builder(
                      builder: (context) => OutlinedButton.icon(
                        onPressed: () =>
                            DefaultTabController.of(context).animateTo(2),
                        icon: const Icon(Icons.outbox_outlined),
                        label: const Text('Levantar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount:
                      MediaQuery.of(context).size.width < 720 ? 2 : 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.45,
                  children: [
                    WorkspaceMetricCard(
                      label: 'Saldo disponivel',
                      value: formatFinanceMoney(_snapshot.availableBalance),
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    WorkspaceMetricCard(
                      label: 'Saldo pendente',
                      value: formatFinanceMoney(_snapshot.pendingBalance),
                      icon: Icons.hourglass_empty_outlined,
                    ),
                    WorkspaceMetricCard(
                      label: 'Recebido hoje',
                      value: formatFinanceMoney(_snapshot.receivedToday),
                      icon: Icons.today_outlined,
                    ),
                    WorkspaceMetricCard(
                      label: 'Receitas do mes',
                      value: formatFinanceMoney(_snapshot.monthRevenue),
                      icon: Icons.trending_up_outlined,
                    ),
                    WorkspaceMetricCard(
                      label: 'Despesas do mes',
                      value: formatFinanceMoney(_snapshot.monthExpenses),
                      icon: Icons.receipt_long_outlined,
                    ),
                    WorkspaceMetricCard(
                      label: 'Resultado liquido',
                      value: formatFinanceMoney(_snapshot.monthNet),
                      icon: Icons.insights_outlined,
                    ),
                    WorkspaceMetricCard(
                      label: 'Total levantado',
                      value: formatFinanceMoney(_snapshot.totalWithdrawn),
                      icon: Icons.outbox_outlined,
                    ),
                    WorkspaceMetricCard(
                      label: 'Pendencias',
                      value:
                          '${_snapshot.pendingContributions}/${_snapshot.pendingWithdrawals}',
                      icon: Icons.pending_actions_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: Icon(Icons.person_outline, size: 18),
                      label: Text('Carteira pessoal: historico do membro'),
                    ),
                    Chip(
                      avatar: Icon(Icons.church_outlined, size: 18),
                      label: Text('Carteira da igreja: saldo operacional'),
                    ),
                    Chip(
                      avatar:
                          Icon(Icons.admin_panel_settings_outlined, size: 18),
                      label: Text('Carteira da plataforma: super admin'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WorkspaceSectionCard(
            title: 'Saldos por operadora',
            subtitle: 'Cada operadora tem historico e saldo proprio.',
            child: Column(
              children: [
                _WalletProviderTile(summary: _walletFor('mpesa')),
                const Divider(),
                _WalletProviderTile(summary: _walletFor('emola')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WorkspaceSectionCard(
            title: 'Saldos por tipo de contribuicao',
            subtitle:
                'Separacao operacional para dizimos, ofertas, campanhas e outras entradas confirmadas.',
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.of(context).size.width < 720 ? 2 : 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                WorkspaceMetricCard(
                  label: 'Dizimos',
                  value: formatFinanceMoney(_creditTotalFor('tithe')),
                  icon: Icons.volunteer_activism_outlined,
                ),
                WorkspaceMetricCard(
                  label: 'Ofertas',
                  value: formatFinanceMoney(_creditTotalFor('offering')),
                  icon: Icons.favorite_border,
                ),
                WorkspaceMetricCard(
                  label: 'Campanhas',
                  value: formatFinanceMoney(_creditTotalFor('campaign')),
                  icon: Icons.flag_outlined,
                ),
                WorkspaceMetricCard(
                  label: 'Outras entradas',
                  value: formatFinanceMoney(_otherCreditTotal),
                  icon: Icons.add_card_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WorkspaceSectionCard(
            title: 'Historico financeiro',
            subtitle:
                'Entradas e saidas confirmadas, com o membro que enviou quando houver contribuicao.',
            child: widget.walletLedger.isEmpty
                ? const Text('Sem movimentos financeiros por agora.')
                : Column(
                    children: widget.walletLedger.take(8).map((entry) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Icon(
                            entry.isCredit
                                ? Icons.south_west_outlined
                                : Icons.north_east_outlined,
                          ),
                        ),
                        title: Text(entry.entryTypeLabel),
                        subtitle: Text(
                          '${entry.senderLabel}\n'
                          '${entry.description ?? 'Movimento financeiro'} - ${formatFinanceDateTime(entry.createdAt)}',
                        ),
                        trailing: Text(
                          '${entry.isCredit ? '+' : '-'}${formatFinanceMoney(entry.amount)}',
                          style: TextStyle(
                            color: entry.isCredit
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 16),
          WorkspaceSectionCard(
            title: 'Campanhas de contribuicao',
            subtitle: widget.campaigns.isEmpty
                ? 'Cria campanhas como construcao, missoes ou apoio social.'
                : 'O progresso vem de contribuicoes confirmadas.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.campaigns.isEmpty)
                  const Text(
                    'Ainda nao existem campanhas criadas. Cria uma nova campanha no Dashboard/Visao.',
                  )
                else
                  ...widget.campaigns.map(
                    (campaign) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.flag_outlined),
                          ),
                          title: Text(campaign.title),
                          subtitle: Text(
                            '${campaign.statusLabel} - Meta: ${formatFinanceMoney(campaign.targetAmount ?? 0)}\n'
                            'Arrecadado: ${formatFinanceMoney(campaign.raisedAmount)} - ${campaign.contributorCount} contribuinte(s)',
                          ),
                          trailing: Text('${campaign.progressPercent}%'),
                        ),
                        LinearProgressIndicator(value: campaign.progress),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: widget.isReadOnly
                                  ? null
                                  : () => widget.onEditCampaign(campaign),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Editar'),
                            ),
                            OutlinedButton.icon(
                              onPressed: widget.isReadOnly || !campaign.active
                                  ? null
                                  : () => widget.onArchiveCampaign(campaign),
                              icon: const Icon(Icons.archive_outlined),
                              label: const Text('Apagar/encerrar'),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Contribuicoes'),
              Tab(text: 'Despesas'),
              Tab(text: 'Levantamentos'),
              Tab(text: 'Subscricao'),
              Tab(text: 'Relatorios'),
            ],
          ),
          SizedBox(
            height: 900,
            child: TabBarView(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 16),
                  child: ChurchContributionsPage(
                    church: widget.church,
                    repository: widget.financeRepository,
                    campaigns: widget.campaigns,
                    currentPhone: widget.currentPhone,
                    isReadOnly: widget.isReadOnly,
                    showMessage: widget.showMessage,
                    onChanged: _changed,
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 16),
                  child: ChurchExpensesPage(
                    church: widget.church,
                    repository: widget.backofficeRepository,
                    expenses: widget.expenses,
                    isReadOnly: widget.isReadOnly,
                    showMessage: widget.showMessage,
                    onChanged: _changed,
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 16),
                  child: ChurchWithdrawalsPage(
                    church: widget.church,
                    repository: widget.financeRepository,
                    withdrawals: widget.withdrawals,
                    destinationPhone: widget.currentPhone,
                    isReadOnly: widget.isReadOnly,
                    showMessage: widget.showMessage,
                    onChanged: _changed,
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 16),
                  child: ChurchSubscriptionPage(
                    church: widget.church,
                    repository: widget.backofficeRepository,
                    plans: widget.plans,
                    requests: widget.subscriptionRequests,
                    currentPhone: widget.currentPhone,
                    showMessage: widget.showMessage,
                    onChanged: _changed,
                    initialCheckoutPlanCode: widget.initialCheckoutPlanCode,
                  ),
                ),
                const SingleChildScrollView(
                  padding: EdgeInsets.only(top: 16),
                  child: WorkspaceSectionCard(
                    title: 'Relatorios financeiros',
                    subtitle:
                        'Diario, semanal, mensal, anual, por membro, campanha, metodo e categoria.',
                    child: Text(
                      'Exportacao PDF/CSV deve ser ligada a partir do ledger e dos filtros aplicados. Sem dados confirmados, nenhum relatorio simula saldo.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletProviderTile extends StatelessWidget {
  const _WalletProviderTile({required this.summary});

  final WalletProviderSummary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const CircleAvatar(
            child: Icon(Icons.account_balance_wallet_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Recebido no mes: ${formatFinanceMoney(summary.incomingMonth)}',
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                formatFinanceMoney(summary.balance),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
