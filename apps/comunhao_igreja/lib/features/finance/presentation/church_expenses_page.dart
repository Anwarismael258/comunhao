import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:flutter/material.dart';

import '../widgets/finance_format.dart';

class ChurchExpensesPage extends StatelessWidget {
  const ChurchExpensesPage({
    super.key,
    required this.church,
    required this.repository,
    required this.expenses,
    required this.isReadOnly,
    required this.showMessage,
    required this.onChanged,
  });

  final ManagedChurch church;
  final BackofficeRepository repository;
  final List<ChurchExpense> expenses;
  final bool isReadOnly;
  final void Function(String message) showMessage;
  final Future<void> Function() onChanged;

  Future<void> _openEditor(BuildContext context,
      [ChurchExpense? current]) async {
    final titleController = TextEditingController(text: current?.title ?? '');
    final amountController =
        TextEditingController(text: current?.amount.toString() ?? '');
    final vendorController =
        TextEditingController(text: current?.vendorName ?? '');
    final referenceController =
        TextEditingController(text: current?.paymentReference ?? '');
    final proofController =
        TextEditingController(text: current?.proofUrl ?? '');
    final costCenterController =
        TextEditingController(text: current?.costCenter ?? '');
    final notesController = TextEditingController(text: current?.notes ?? '');
    var category = current?.category ?? 'operacional';
    var method = current?.paymentMethod ?? 'cash';
    var status = current?.status ?? 'pending_approval';
    var spentAt = current?.spentAt ?? DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(current == null ? 'Nova despesa' : 'Editar despesa'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: const [
                      DropdownMenuItem(value: 'agua', child: Text('Agua')),
                      DropdownMenuItem(
                          value: 'energia', child: Text('Energia')),
                      DropdownMenuItem(value: 'renda', child: Text('Renda')),
                      DropdownMenuItem(
                          value: 'salario', child: Text('Salarios')),
                      DropdownMenuItem(
                          value: 'transporte', child: Text('Transporte')),
                      DropdownMenuItem(
                          value: 'construcao', child: Text('Obras')),
                      DropdownMenuItem(
                          value: 'equipamentos', child: Text('Equipamentos')),
                      DropdownMenuItem(
                          value: 'acao_social', child: Text('Apoio social')),
                      DropdownMenuItem(
                          value: 'missoes', child: Text('Missoes')),
                      DropdownMenuItem(value: 'evento', child: Text('Eventos')),
                      DropdownMenuItem(
                          value: 'comunicacao', child: Text('Comunicacao')),
                      DropdownMenuItem(
                          value: 'manutencao', child: Text('Manutencao')),
                      DropdownMenuItem(
                          value: 'alimentacao', child: Text('Alimentacao')),
                      DropdownMenuItem(
                          value: 'seguranca', child: Text('Seguranca')),
                      DropdownMenuItem(value: 'outro', child: Text('Outro')),
                    ],
                    onChanged: (value) =>
                        setModalState(() => category = value ?? 'operacional'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Descricao'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Valor'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: vendorController,
                    decoration: const InputDecoration(
                        labelText: 'Fornecedor/beneficiario'),
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
                          value: 'bank', child: Text('Conta bancaria')),
                      DropdownMenuItem(value: 'pos', child: Text('POS')),
                      DropdownMenuItem(value: 'other', child: Text('Outro')),
                    ],
                    onChanged: (value) =>
                        setModalState(() => method = value ?? 'cash'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: const [
                      DropdownMenuItem(value: 'draft', child: Text('Rascunho')),
                      DropdownMenuItem(
                          value: 'pending_approval',
                          child: Text('Aguardando aprovacao')),
                      DropdownMenuItem(
                          value: 'approved', child: Text('Aprovada')),
                      DropdownMenuItem(value: 'paid', child: Text('Paga')),
                      DropdownMenuItem(
                          value: 'rejected', child: Text('Rejeitada')),
                      DropdownMenuItem(
                          value: 'cancelled', child: Text('Cancelada')),
                    ],
                    onChanged: (value) => setModalState(
                        () => status = value ?? 'pending_approval'),
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
                    controller: costCenterController,
                    decoration:
                        const InputDecoration(labelText: 'Centro de custo'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: spentAt,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setModalState(() => spentAt = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              spentAt.hour,
                              spentAt.minute,
                            ));
                      }
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(formatFinanceDate(spentAt)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Notas'),
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
              child: const Text('Registar despesa'),
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
    if (titleController.text.trim().length < 3 ||
        amount == null ||
        amount <= 0) {
      showMessage('Preenche uma despesa valida.');
      return;
    }

    try {
      await repository.saveChurchExpense(
        expenseId: current?.id,
        churchId: church.id,
        category: category,
        title: titleController.text.trim(),
        amount: amount,
        spentAt: spentAt,
        notes: notesController.text.trim(),
        vendorName: vendorController.text.trim(),
        paymentMethod: method,
        paymentReference: referenceController.text.trim(),
        proofUrl: proofController.text.trim(),
        costCenter: costCenterController.text.trim(),
        status: status,
      );
      showMessage('Despesa registada com sucesso.');
      await onChanged();
    } catch (error) {
      showMessage('$error');
    }
  }

  Future<void> _delete(BuildContext context, ChurchExpense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar despesa'),
        content: Text('Pretendes apagar "${expense.title}"?'),
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
    await repository.deleteChurchExpense(expense.id);
    showMessage('Despesa apagada.');
    await onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return WorkspaceSectionCard(
      title: 'Despesas',
      subtitle: 'Despesas pendentes nao reduzem o saldo disponivel.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            onPressed: isReadOnly ? null : () => _openEditor(context),
            icon: const Icon(Icons.add_card_outlined),
            label: const Text('Nova despesa'),
          ),
          const SizedBox(height: 16),
          if (expenses.isEmpty)
            const Text('Nao existem despesas registadas.')
          else
            ...expenses.map(
              (expense) => Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Icon(
                        expense.affectsBalance
                            ? Icons.receipt_long_outlined
                            : Icons.pending_actions_outlined,
                      ),
                    ),
                    title: Text(expense.title),
                    subtitle: Text(
                      '${expense.categoryLabel} - ${expense.statusLabel}\n'
                      '${formatFinanceDate(expense.spentAt)}'
                      '${expense.vendorName == null ? '' : ' - ${expense.vendorName}'}',
                    ),
                    trailing: Text(formatFinanceMoney(expense.amount)),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: isReadOnly
                            ? null
                            : () => _openEditor(context, expense),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            isReadOnly ? null : () => _delete(context, expense),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Apagar'),
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
