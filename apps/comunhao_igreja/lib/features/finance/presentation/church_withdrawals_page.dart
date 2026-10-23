import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:flutter/material.dart';

import '../widgets/finance_format.dart';

class ChurchWithdrawalsPage extends StatelessWidget {
  const ChurchWithdrawalsPage({
    super.key,
    required this.church,
    required this.repository,
    required this.withdrawals,
    required this.destinationPhone,
    required this.isReadOnly,
    required this.showMessage,
    required this.onChanged,
  });

  final ManagedChurch church;
  final FinanceRepository repository;
  final List<WalletWithdrawalRequest> withdrawals;
  final String? destinationPhone;
  final bool isReadOnly;
  final void Function(String message) showMessage;
  final Future<void> Function() onChanged;

  Future<void> _request(BuildContext context) async {
    final amountController = TextEditingController();
    final allowedDestination = destinationPhone?.trim() ?? '';
    final destinationController =
        TextEditingController(text: allowedDestination);
    final notesController = TextEditingController();
    var provider = _providerFor(allowedDestination);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Solicitar levantamento'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone_iphone_outlined),
                  title: const Text('Numero autorizado'),
                  subtitle: Text(
                    allowedDestination.isEmpty
                        ? 'Sem telefone da igreja carregado'
                        : allowedDestination,
                  ),
                  trailing: Chip(label: Text(_providerLabel(provider))),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Valor que pretende levantar',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: destinationController,
                  keyboardType: TextInputType.phone,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Destino do levantamento',
                    helperText:
                        'Por seguranca, so pode levantar para o numero que cadastrou a igreja.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Motivo'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'O pedido fica pendente. A operadora e detetada automaticamente pelo numero autorizado.',
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
              child: const Text('Levantar'),
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
      showMessage('Introduz um valor valido.');
      return;
    }
    if (allowedDestination.isEmpty) {
      showMessage('Nao foi encontrado o telefone autorizado da igreja.');
      return;
    }

    try {
      await repository.createWithdrawalRequest(
        ownerType: 'church',
        churchId: church.id,
        provider: provider,
        amount: amount,
        destinationNumber: allowedDestination,
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      );
      showMessage('Pedido de levantamento registado.');
      await onChanged();
    } catch (error) {
      showMessage('$error');
    }
  }

  String _providerFor(String phone) {
    final normalized = phone.replaceAll(RegExp(r'\D'), '');
    final local = normalized.length > 9
        ? normalized.substring(normalized.length - 9)
        : normalized;
    if (local.startsWith('84') || local.startsWith('85')) {
      return 'mpesa';
    }
    if (local.startsWith('86') || local.startsWith('87')) {
      return 'emola';
    }
    return 'mpesa';
  }

  String _providerLabel(String provider) {
    return switch (provider) {
      'emola' => 'E-Mola',
      _ => 'M-Pesa',
    };
  }

  @override
  Widget build(BuildContext context) {
    return WorkspaceSectionCard(
      title: 'Levantamentos',
      subtitle:
          'Levantamentos usam reserva e nao viram pagos sem processamento real.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            onPressed: isReadOnly ? null : () => _request(context),
            icon: const Icon(Icons.outbox_outlined),
            label: const Text('Levantar'),
          ),
          const SizedBox(height: 16),
          if (withdrawals.isEmpty)
            const Text('Nao ha levantamentos pendentes.')
          else
            ...withdrawals.map(
              (request) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.account_balance_wallet_outlined),
                ),
                title: Text(
                  '${request.providerLabel} - ${formatFinanceMoney(request.amount)}',
                ),
                subtitle: Text(
                  '${request.statusLabel} - ${request.destinationNumber}\n'
                  '${request.destinationHolder ?? 'Titular por confirmar'} - ${formatFinanceDate(request.createdAt)}',
                ),
                trailing: Text(request.statusLabel),
              ),
            ),
        ],
      ),
    );
  }
}
