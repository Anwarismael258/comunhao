import 'dart:async';

import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:flutter/material.dart';

import '../widgets/finance_format.dart';

class ChurchContributionsPage extends StatefulWidget {
  const ChurchContributionsPage({
    super.key,
    required this.church,
    required this.repository,
    required this.campaigns,
    required this.currentPhone,
    required this.isReadOnly,
    required this.showMessage,
    required this.onChanged,
  });

  final ManagedChurch church;
  final FinanceRepository repository;
  final List<ManagedCampaign> campaigns;
  final String? currentPhone;
  final bool isReadOnly;
  final void Function(String message) showMessage;
  final Future<void> Function() onChanged;

  @override
  State<ChurchContributionsPage> createState() =>
      _ChurchContributionsPageState();
}

class _ChurchContributionsPageState extends State<ChurchContributionsPage> {
  var _loading = true;
  var _status = 'all';
  List<ChurchContribution> _items = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant ChurchContributionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.church.id != widget.church.id) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await widget.repository.fetchChurchContributions(
        churchId: widget.church.id,
        status: _status == 'all' ? null : _status,
      );
      if (mounted) {
        setState(() => _items = rows);
      }
    } catch (error) {
      widget.showMessage('Nao foi possivel carregar contribuicoes.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createContribution() async {
    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    final proofController = TextEditingController();
    final notesController = TextEditingController();
    final phoneController = TextEditingController(text: widget.currentPhone);
    var type = 'offering';
    var method = 'cash';
    String? campaignId;
    var confirmImmediately = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Registar contribuicao'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(value: 'tithe', child: Text('Dizimo')),
                      DropdownMenuItem(
                          value: 'offering', child: Text('Oferta')),
                      DropdownMenuItem(
                          value: 'campaign', child: Text('Campanha')),
                      DropdownMenuItem(
                          value: 'missions', child: Text('Missoes')),
                      DropdownMenuItem(
                          value: 'construction', child: Text('Construcao')),
                      DropdownMenuItem(
                          value: 'social_support', child: Text('Apoio social')),
                      DropdownMenuItem(value: 'event', child: Text('Evento')),
                      DropdownMenuItem(
                          value: 'special', child: Text('Especial')),
                      DropdownMenuItem(value: 'other', child: Text('Outro')),
                    ],
                    onChanged: (value) => setModalState(() {
                      type = value ?? 'offering';
                    }),
                  ),
                  if (type == 'campaign') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: campaignId,
                      decoration: const InputDecoration(labelText: 'Campanha'),
                      items: widget.campaigns
                          .map(
                            (campaign) => DropdownMenuItem(
                              value: campaign.id,
                              child: Text(campaign.title),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setModalState(() => campaignId = value),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Valor'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(labelText: 'Metodo'),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Numerario')),
                      DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
                      DropdownMenuItem(value: 'emola', child: Text('E-Mola')),
                      DropdownMenuItem(
                          value: 'manual_transfer',
                          child: Text('Transferencia')),
                      DropdownMenuItem(value: 'pos', child: Text('POS')),
                      DropdownMenuItem(value: 'other', child: Text('Outro')),
                    ],
                    onChanged: (value) =>
                        setModalState(() => method = value ?? 'cash'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Telefone'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: referenceController,
                    decoration: const InputDecoration(labelText: 'Referencia'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: proofController,
                    decoration:
                        const InputDecoration(labelText: 'Comprovativo URL'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Observacao interna'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: confirmImmediately,
                    title: const Text('Confirmar imediatamente'),
                    subtitle: const Text(
                      'Use apenas para numerario ou pagamento ja verificado.',
                    ),
                    onChanged: (value) =>
                        setModalState(() => confirmImmediately = value),
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

    if (confirmed != true) {
      return;
    }

    final amount =
        num.tryParse(amountController.text.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      widget.showMessage('Introduz um valor valido.');
      return;
    }
    if (type == 'campaign' && campaignId == null) {
      widget.showMessage('Seleciona a campanha.');
      return;
    }

    try {
      await widget.repository.createChurchContribution(
        churchId: widget.church.id,
        contributionType: type,
        amount: amount,
        method: method,
        provider: method,
        campaignId: campaignId,
        payerPhone: phoneController.text.trim().isEmpty
            ? null
            : phoneController.text.trim(),
        reference: referenceController.text.trim().isEmpty
            ? null
            : referenceController.text.trim(),
        proofUrl: proofController.text.trim().isEmpty
            ? null
            : proofController.text.trim(),
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
        confirmImmediately: confirmImmediately,
        idempotencyKey:
            'church:${widget.church.id}:contribution:${DateTime.now().microsecondsSinceEpoch}',
      );
      widget.showMessage('Contribuicao registada.');
      await _load();
      await widget.onChanged();
    } catch (error) {
      widget.showMessage('$error');
    }
  }

  Future<void> _confirm(ChurchContribution contribution) async {
    try {
      await widget.repository.confirmChurchContribution(
        donationId: contribution.id,
        internalNote: 'Confirmado no painel financeiro.',
        idempotencyKey: 'donation:${contribution.id}:confirm',
      );
      widget.showMessage('Contribuicao confirmada e recibo emitido.');
      await _load();
      await widget.onChanged();
    } catch (error) {
      widget.showMessage('$error');
    }
  }

  Future<void> _reject(ChurchContribution contribution) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeitar contribuicao'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Motivo obrigatorio'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rejeitar'),
          ),
        ],
      ),
    );
    if (confirmed != true || controller.text.trim().isEmpty) {
      return;
    }
    try {
      await widget.repository.rejectChurchContribution(
        donationId: contribution.id,
        reason: controller.text.trim(),
      );
      widget.showMessage('Contribuicao rejeitada.');
      await _load();
      await widget.onChanged();
    } catch (error) {
      widget.showMessage('$error');
    }
  }

  void _showProof(ChurchContribution contribution) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Comprovativo'),
        content: SelectableText(
          contribution.proofUrl?.isNotEmpty == true
              ? contribution.proofUrl!
              : 'Sem comprovativo anexado.',
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
    return WorkspaceSectionCard(
      title: 'Contribuicoes',
      subtitle:
          'Contribuicoes pendentes so entram no saldo depois de confirmacao.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: widget.isReadOnly ? null : _createContribution,
                icon: const Icon(Icons.add_card_outlined),
                label: const Text('Registar contribuicao'),
              ),
              DropdownButton<String>(
                value: _status,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Todos estados')),
                  DropdownMenuItem(value: 'pending', child: Text('Pendentes')),
                  DropdownMenuItem(
                      value: 'confirmed', child: Text('Confirmadas')),
                  DropdownMenuItem(
                      value: 'rejected', child: Text('Rejeitadas')),
                ],
                onChanged: (value) async {
                  setState(() => _status = value ?? 'all');
                  await _load();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_items.isEmpty)
            const Text('Ainda nao existem contribuicoes neste periodo.')
          else
            ..._items.map(
              (item) => Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Icon(
                        item.isConfirmed
                            ? Icons.verified_outlined
                            : Icons.hourglass_empty_outlined,
                      ),
                    ),
                    title: Text('${item.contributorLabel} - ${item.typeLabel}'),
                    subtitle: Text(
                      '${item.methodLabel} - ${item.statusLabel}\n'
                      '${formatFinanceDateTime(item.createdAt)}'
                      '${item.campaignTitle == null ? '' : ' - ${item.campaignTitle}'}'
                      '${item.receiptNumber == null ? '' : '\nRecibo: ${item.receiptNumber}'}',
                    ),
                    trailing: Text(formatFinanceMoney(item.amount)),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showProof(item),
                        icon: const Icon(Icons.attach_file_outlined),
                        label: const Text('Comprovativo'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.isReadOnly || !item.isPending
                            ? null
                            : () => _confirm(item),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Confirmar'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.isReadOnly || !item.isPending
                            ? null
                            : () => _reject(item),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Rejeitar'),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
