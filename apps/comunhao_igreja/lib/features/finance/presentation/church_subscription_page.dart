import 'dart:async';

import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/finance_format.dart';

class ChurchSubscriptionPage extends StatefulWidget {
  const ChurchSubscriptionPage({
    super.key,
    required this.church,
    required this.repository,
    required this.plans,
    required this.requests,
    required this.currentPhone,
    required this.showMessage,
    required this.onChanged,
    this.initialCheckoutPlanCode,
  });

  final ManagedChurch church;
  final BackofficeRepository repository;
  final List<SubscriptionPlan> plans;
  final List<ChurchSubscriptionRequest> requests;
  final String? currentPhone;
  final void Function(String message) showMessage;
  final Future<void> Function() onChanged;
  final String? initialCheckoutPlanCode;

  @override
  State<ChurchSubscriptionPage> createState() => _ChurchSubscriptionPageState();
}

class _ChurchSubscriptionPageState extends State<ChurchSubscriptionPage> {
  String? _openedInitialPlanCode;

  ChurchSubscription? get _subscription => widget.church.subscription;
  ChurchSubscriptionRequest? get _latestRequest =>
      widget.requests.isEmpty ? null : widget.requests.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openInitialCheckout());
  }

  @override
  void didUpdateWidget(covariant ChurchSubscriptionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCheckoutPlanCode != widget.initialCheckoutPlanCode) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _openInitialCheckout());
    }
  }

  void _openInitialCheckout() {
    final planCode = widget.initialCheckoutPlanCode;
    if (!mounted ||
        planCode == null ||
        planCode.isEmpty ||
        _openedInitialPlanCode == planCode) {
      return;
    }
    SubscriptionPlan? selectedPlan;
    for (final plan in widget.plans) {
      if (plan.code == planCode) {
        selectedPlan = plan;
        break;
      }
    }
    if (selectedPlan == null) {
      return;
    }
    _openedInitialPlanCode = planCode;
    unawaited(_openCheckout(context, selectedPlan));
  }

  Future<void> _openCheckout(
    BuildContext context,
    SubscriptionPlan plan,
  ) async {
    final payerPhone = widget.currentPhone?.trim() ?? '';
    final provider = _providerForPhone(payerPhone);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Pagar ${plan.name}'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CheckoutSummary(plan: plan),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: formatFinanceMoney(plan.priceMzn),
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Valor que pretende pagar',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone_android_outlined),
                    title: Text(
                        payerPhone.isEmpty ? 'Telefone da conta' : payerPhone),
                    subtitle: Text(
                        'Operadora detectada automaticamente: ${_providerLabel(provider)}'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                      'O pagamento será feito com o mesmo número usado no cadastro da igreja.'),
                  const Text(
                    'O sistema valida automaticamente o valor esperado. Se o valor recebido nao condizer, o pagamento e cancelado.',
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
              child: const Text('Pagar agora'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      if (payerPhone.isEmpty) {
        throw StateError(
            'A conta da igreja não tem um número de telefone válido.');
      }
      await widget.repository.requestSubscriptionPlan(
        churchId: widget.church.id,
        planCode: plan.code,
        paymentProvider: provider,
        payerPhone: payerPhone.isEmpty ? null : payerPhone,
        paymentReference: null,
        paymentNotes: null,
      );
      final checkout = await widget.repository.createPaysuiteCheckout(
        amountMzn: plan.priceMzn,
        provider: provider,
        phone: payerPhone,
        description: 'Subscrição Comunhão ${plan.name}',
      );
      final checkoutUrl = checkout['checkout_url']?.toString();
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw StateError('A PaySuite não devolveu o checkout.');
      }
      final opened = await launchUrl(Uri.parse(checkoutUrl),
          mode: LaunchMode.externalApplication);
      if (!opened) {
        throw StateError('Não foi possível abrir o checkout PaySuite.');
      }
      widget.showMessage(
          'Checkout PaySuite aberto para ${_providerLabel(provider)}.');
      await widget.onChanged();
    } catch (error) {
      widget.showMessage('$error');
    }
  }

  String _providerForPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final local = digits.startsWith('258') ? digits.substring(3) : digits;
    return local.startsWith('87') ? 'emola' : 'mpesa';
  }

  String _providerLabel(String provider) =>
      provider == 'emola' ? 'E-Mola' : 'M-Pesa';

  @override
  Widget build(BuildContext context) {
    final subscription = _subscription;
    return WorkspaceSectionCard(
      title: 'Plano de subscricao',
      subtitle: subscription == null
          ? 'Escolhe um plano e confirma o valor no checkout.'
          : 'Plano atual: ${subscription.planLabel} - ${subscription.statusLabel}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subscription != null) ...[
            Text(
              subscription.effectiveDeadline == null
                  ? 'Estado atual: ${subscription.statusLabel}.'
                  : 'Estado atual: ${subscription.statusLabel}. Valido ate ${formatFinanceDate(subscription.effectiveDeadline!)}.',
            ),
            const SizedBox(height: 12),
          ],
          if (_latestRequest?.isPending == true)
            const Chip(
              avatar: Icon(Icons.hourglass_empty_outlined, size: 18),
              label: Text('Existe um pedido pendente de confirmacao'),
            ),
          const SizedBox(height: 16),
          ...widget.plans.map(
            (plan) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _latestRequest?.isPending == true
                    ? null
                    : () => _openCheckout(context, plan),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(plan.description ?? 'Plano ${plan.name}'),
                        const SizedBox(height: 8),
                        Text(
                          plan.priceLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(plan.adminLimitLabel),
                        const SizedBox(height: 8),
                        ...plan.features
                            .take(6)
                            .map((feature) => Text('- $feature')),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _latestRequest?.isPending == true
                              ? null
                              : () => _openCheckout(context, plan),
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('Pagar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.requests.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Historico de pagamentos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...widget.requests.map(
              (request) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(request.planLabel),
                subtitle: Text(
                  '${request.statusLabel} - ${formatFinanceDate(request.requestedAt)}\n'
                  '${request.paymentProviderLabel} - ${formatFinanceMoney(request.expectedAmountMzn ?? 0)}'
                  '${request.paymentReference == null ? '' : '\nRef: ${request.paymentReference}'}',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckoutSummary extends StatelessWidget {
  const _CheckoutSummary({required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    const fee = 0;
    final total = plan.priceMzn + fee;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Beneficiario: Comunhao'),
            const SizedBox(height: 6),
            Text('Plano: ${plan.name}'),
            const SizedBox(height: 6),
            Text('Valor: ${formatFinanceMoney(plan.priceMzn)}'),
            const SizedBox(height: 6),
            Text('Taxa: ${formatFinanceMoney(fee)}'),
            const Divider(),
            Text(
              'Total: ${formatFinanceMoney(total)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
