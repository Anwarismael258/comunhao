import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/formatting.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/section_card.dart';
import '../../church/data/church_repository.dart';
import '../../church/models/church_branding.dart';
import '../../church/models/donation_campaign.dart';
import '../../church/models/member_donation_record.dart';
import '../../church/models/member_wallet_summary.dart';
import '../../church/models/payment_channel.dart';

class DonationsPage extends StatefulWidget {
  const DonationsPage({
    required this.church,
    required this.repository,
    this.financeRepository,
    super.key,
  });

  final ChurchBranding church;
  final ChurchRepository repository;
  final FinanceRepository? financeRepository;

  @override
  State<DonationsPage> createState() => _DonationsPageState();
}

class _DonationsPageState extends State<DonationsPage> {
  late Future<_DonationsData> _dataFuture;
  late final FinanceRepository _financeRepository;
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _depositController = TextEditingController();

  String _donationType = 'tithe';
  String? _selectedCampaignId;
  String _provider = 'mpesa';
  bool _submitting = false;

  PaymentChannel? get _selectedPaymentChannel {
    for (final channel in widget.church.paymentChannels) {
      if (channel.provider.toLowerCase() == _provider) {
        return channel;
      }
    }
    return null;
  }

  List<_ProviderOption> get _providerOptions {
    final configured = widget.church.paymentChannels
        .where((channel) => _supportsWalletProvider(channel.provider))
        .map(
          (channel) => _ProviderOption(
            value: channel.provider.toLowerCase(),
            label:
                channel.provider.toLowerCase() == 'mpesa' ? 'M-Pesa' : 'E-Mola',
          ),
        )
        .toList();

    if (configured.isNotEmpty) {
      return configured;
    }

    return const [
      _ProviderOption(value: 'mpesa', label: 'M-Pesa'),
      _ProviderOption(value: 'emola', label: 'E-Mola'),
    ];
  }

  @override
  void initState() {
    super.initState();
    _financeRepository =
        widget.financeRepository ?? SupabaseFinanceRepository();
    _provider = _providerOptions.first.value;
    _dataFuture = _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  Future<_DonationsData> _load() async {
    final results = await Future.wait<dynamic>([
      widget.repository.fetchActiveCampaigns(widget.church.id),
      widget.repository.fetchOwnDonations(widget.church.id),
      widget.repository.fetchMemberWallet(),
    ]);

    return _DonationsData(
      campaigns: results[0] as List<DonationCampaign>,
      history: results[1] as List<MemberDonationRecord>,
      wallet: results[2] as MemberWalletSummary?,
    );
  }

  Future<void> _depositToWallet(MemberWalletSummary? wallet) async {
    final amount = num.tryParse(
      _depositController.text.trim().replaceAll(',', '.'),
    );
    if (amount == null || amount <= 0) {
      _showMessage('Introduz um valor valido para depositar.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.repository.depositMemberWallet(
        amount: amount,
        provider: wallet?.provider,
      );
      if (!mounted) return;
      _depositController.clear();
      await _refresh();
      _showMessage('Deposito registado na tua carteira.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _dataFuture = _load();
    });
    await _dataFuture;
  }

  Future<void> _submitDonation(List<DonationCampaign> campaigns) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_donationType == 'campaign' && _selectedCampaignId == null) {
      _showMessage('Escolha a campanha que deseja apoiar.');
      return;
    }

    final amount = num.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    if (amount == null || amount <= 0) {
      _showMessage('Introduz um valor valido.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await _financeRepository.recordMemberDonation(
        churchId: widget.church.id,
        donationType: _donationType,
        amount: amount,
        provider: _provider,
        campaignId: _selectedCampaignId,
      );
      if (!mounted) {
        return;
      }
      _amountController.clear();
      if (_donationType == 'campaign' && campaigns.isNotEmpty) {
        setState(() {
          _selectedCampaignId = campaigns.first.id;
        });
      }
      await _refresh();
      _showMessage(
        'Contribuicao enviada. Aguarda confirmacao financeira da igreja.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  bool _supportsWalletProvider(String provider) {
    return provider.toLowerCase() == 'mpesa' ||
        provider.toLowerCase() == 'emola';
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.contains('active members')) {
      return 'So membros ativos podem registar dizimos e ofertas.';
    }
    if (raw.contains('read-only')) {
      return 'A igreja esta temporariamente em modo leitura.';
    }
    if (raw.contains('Campaign not found')) {
      return 'A campanha escolhida ja nao esta disponivel.';
    }
    return raw;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showReceipt(MemberDonationRecord donation) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recibo digital'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Codigo: ${donation.receiptCode}'),
            const SizedBox(height: 8),
            Text('Tipo: ${donation.donationTypeLabel}'),
            const SizedBox(height: 8),
            Text('Valor: ${formatMoney(donation.amount, donation.currency)}'),
            const SizedBox(height: 8),
            Text('Operadora: ${donation.providerLabel}'),
            const SizedBox(height: 8),
            Text('Estado: ${donation.statusLabel}'),
            const SizedBox(height: 8),
            Text('Data: ${formatDateTimeShort(donation.createdAt)}'),
            if (donation.campaignTitle != null) ...[
              const SizedBox(height: 8),
              Text('Campanha: ${donation.campaignTitle}'),
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
    return FutureBuilder<_DonationsData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        final campaigns =
            snapshot.data?.campaigns ?? const <DonationCampaign>[];
        final history =
            snapshot.data?.history ?? const <MemberDonationRecord>[];
        final wallet = snapshot.data?.wallet;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  MetricCard(
                    label: 'Total registado',
                    value: formatMoney(
                      history.fold<num>(0, (sum, item) => sum + item.amount),
                      widget.church.defaultCurrency,
                    ),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  MetricCard(
                    label: 'Recibos',
                    value: history.length.toString().padLeft(2, '0'),
                    icon: Icons.receipt_long_outlined,
                  ),
                  MetricCard(
                    label: 'Campanhas',
                    value: campaigns.length.toString().padLeft(2, '0'),
                    icon: Icons.campaign_outlined,
                  ),
                  MetricCard(
                    label: 'Canais ativos',
                    value: widget.church.paymentChannels.length
                        .toString()
                        .padLeft(2, '0'),
                    icon: Icons.payments_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _MemberWalletCard(
                wallet: wallet,
                controller: _depositController,
                busy: _submitting,
                onDeposit: () => _depositToWallet(wallet),
              ),
              const SizedBox(height: 20),
              SectionCard(
                title: 'Carteira do membro',
                subtitle:
                    'Escolha o tipo de contribuicao, a operadora e o valor. O pedido fica pendente ate confirmacao financeira.',
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _donationType,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: const [
                          DropdownMenuItem(
                            value: 'tithe',
                            child: Text('Dizimo'),
                          ),
                          DropdownMenuItem(
                            value: 'offering',
                            child: Text('Oferta'),
                          ),
                          DropdownMenuItem(
                            value: 'campaign',
                            child: Text('Campanha'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _donationType = value ?? 'tithe';
                            if (_donationType != 'campaign') {
                              _selectedCampaignId = null;
                            } else if (campaigns.isNotEmpty) {
                              _selectedCampaignId = campaigns.first.id;
                            }
                          });
                        },
                      ),
                      if (_donationType == 'campaign') ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: campaigns.any(
                            (item) => item.id == _selectedCampaignId,
                          )
                              ? _selectedCampaignId
                              : null,
                          decoration:
                              const InputDecoration(labelText: 'Campanha'),
                          items: campaigns
                              .map(
                                (campaign) => DropdownMenuItem(
                                  value: campaign.id,
                                  child: Text(campaign.title),
                                ),
                              )
                              .toList(),
                          onChanged: campaigns.isEmpty
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedCampaignId = value;
                                  });
                                },
                        ),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _provider,
                        decoration: const InputDecoration(
                          labelText: 'Forma de pagamento',
                        ),
                        items: _providerOptions
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.value,
                                child: Text(item.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _provider = value ?? _provider;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _CheckoutPreview(
                        provider: _provider,
                        channel: _selectedPaymentChannel,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(labelText: 'Valor (MZN)'),
                        validator: (value) {
                          final amount = num.tryParse(
                            (value ?? '').trim().replaceAll(',', '.'),
                          );
                          if (amount == null || amount <= 0) {
                            return 'Introduz um valor valido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _submitting
                              ? null
                              : () => _submitDonation(campaigns),
                          icon: const Icon(Icons.volunteer_activism_outlined),
                          label: Text(
                            _submitting
                                ? 'A ENVIAR...'
                                : 'ENVIAR PARA CONFIRMACAO',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SectionCard(
                title: 'Canais de pagamento',
                subtitle:
                    'Os numeros e instrucoes abaixo ja podem mudar por igreja no Supabase.',
                child: widget.church.paymentChannels.isEmpty
                    ? const Text(
                        'Ainda nao existem canais de pagamento configurados.',
                      )
                    : Column(
                        children: [
                          for (var i = 0;
                              i < widget.church.paymentChannels.length;
                              i++) ...[
                            _PaymentTile(
                              channel: widget.church.paymentChannels[i],
                            ),
                            if (i != widget.church.paymentChannels.length - 1)
                              const Divider(),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 20),
              SectionCard(
                title: 'Campanhas ativas',
                child: snapshot.connectionState != ConnectionState.done
                    ? const Center(child: CircularProgressIndicator())
                    : snapshot.hasError
                        ? Text(
                            'Falha ao carregar campanhas.\n\n${snapshot.error}',
                          )
                        : campaigns.isEmpty
                            ? const Text('Nenhuma campanha ativa encontrada.')
                            : Column(
                                children: [
                                  for (var i = 0;
                                      i < campaigns.length;
                                      i++) ...[
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const CircleAvatar(
                                        child: Icon(
                                          Icons.volunteer_activism_outlined,
                                        ),
                                      ),
                                      title: Text(campaigns[i].title),
                                      subtitle: Text(
                                        [
                                          campaigns[i].description ??
                                              'Sem descricao.',
                                          'Arrecadado: ${formatMoney(campaigns[i].raisedAmount, widget.church.defaultCurrency)}',
                                          '${campaigns[i].contributorCount} contribuinte(s)',
                                        ].join('\n'),
                                      ),
                                      trailing: Text(
                                        '${campaigns[i].progressPercent}%',
                                      ),
                                    ),
                                    LinearProgressIndicator(
                                      value: campaigns[i].progress,
                                    ),
                                    if (i != campaigns.length - 1)
                                      const Divider(),
                                  ],
                                ],
                              ),
              ),
              const SizedBox(height: 20),
              SectionCard(
                title: 'Meu historico',
                subtitle:
                    'Todos os teus dizimos, ofertas e campanhas registados para consulta.',
                child: history.isEmpty
                    ? const Text('Ainda nao existem contribuicoes registadas.')
                    : Column(
                        children: [
                          for (var i = 0; i < history.length; i++) ...[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                child: Icon(Icons.receipt_long_outlined),
                              ),
                              title: Text(history[i].donationTypeLabel),
                              subtitle: Text(
                                '${history[i].providerLabel} - ${history[i].statusLabel} - ${formatDateTimeShort(history[i].createdAt)}${history[i].campaignTitle == null ? '' : '\n${history[i].campaignTitle}'}',
                              ),
                              trailing: Text(
                                formatMoney(
                                  history[i].amount,
                                  history[i].currency,
                                ),
                              ),
                              onTap: () => _showReceipt(history[i]),
                            ),
                            if (i != history.length - 1) const Divider(),
                          ],
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

class _DonationsData {
  const _DonationsData({
    required this.campaigns,
    required this.history,
    this.wallet,
  });

  final List<DonationCampaign> campaigns;
  final List<MemberDonationRecord> history;
  final MemberWalletSummary? wallet;
}

class _MemberWalletCard extends StatelessWidget {
  const _MemberWalletCard({
    required this.wallet,
    required this.controller,
    required this.busy,
    required this.onDeposit,
  });

  final MemberWalletSummary? wallet;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onDeposit;

  @override
  Widget build(BuildContext context) {
    final phone = wallet?.phone ?? 'Numero registado';
    final provider = wallet?.providerLabel ?? 'Automatico';
    final currency = wallet?.currency ?? 'MZN';
    final balance = wallet?.availableBalance ?? 0;

    return SectionCard(
      title: 'Minha conta Comunhao',
      subtitle:
          'Depositos entram pela carteira ligada ao numero registado no app.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      formatMoney(balance, currency),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text('$provider - $phone'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Valor para depositar (MZN)',
              prefixIcon: Icon(Icons.add_card_outlined),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : onDeposit,
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Depositar na minha conta'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderOption {
  const _ProviderOption({required this.value, required this.label});

  final String value;
  final String label;
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.channel});

  final PaymentChannel channel;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Icon(_iconForProvider(channel.provider)),
      ),
      title: Text(channel.label),
      subtitle: Text(
        [
          if (channel.accountName != null) channel.accountName!,
          if (channel.accountNumber != null) channel.accountNumber!,
          if (channel.instructions != null) channel.instructions!,
        ].join('\n'),
      ),
      trailing: channel.isPrimary ? const Chip(label: Text('Principal')) : null,
    );
  }

  IconData _iconForProvider(String provider) {
    switch (provider.toLowerCase()) {
      case 'mpesa':
        return Icons.phone_android_outlined;
      case 'emola':
        return Icons.sim_card_outlined;
      case 'bank':
        return Icons.account_balance_outlined;
      default:
        return Icons.payments_outlined;
    }
  }
}

class _CheckoutPreview extends StatelessWidget {
  const _CheckoutPreview({
    required this.provider,
    required this.channel,
  });

  final String provider;
  final PaymentChannel? channel;

  String get _providerLabel => provider == 'emola' ? 'E-Mola' : 'M-Pesa';

  IconData get _providerIcon =>
      provider == 'emola' ? Icons.sim_card_outlined : Icons.phone_android;

  @override
  Widget build(BuildContext context) {
    final accountNumber = channel?.accountNumber ?? 'Numero por configurar';
    final accountName = channel?.accountName ?? 'Igreja';
    final instructions = channel?.instructions ??
        'Transfere para o numero da igreja e guarda o codigo da transacao.';

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_providerIcon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Checkout $_providerLabel',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Chip(label: Text('Manual')),
              ],
            ),
            const SizedBox(height: 12),
            Text('Destino: $accountNumber'),
            const SizedBox(height: 4),
            Text('Conta: $accountName'),
            const SizedBox(height: 8),
            Text(instructions),
            const Divider(height: 24),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.credit_card_outlined),
              title: Text('Visa / Cartao'),
              subtitle: Text('Em breve no checkout online.'),
              trailing: Chip(label: Text('Indisponivel')),
            ),
          ],
        ),
      ),
    );
  }
}
