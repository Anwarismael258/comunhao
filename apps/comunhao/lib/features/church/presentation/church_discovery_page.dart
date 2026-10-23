import 'package:flutter/material.dart';

import '../data/church_repository.dart';
import '../models/church_branding.dart';

class ChurchDiscoveryPage extends StatefulWidget {
  const ChurchDiscoveryPage({
    required this.repository,
    required this.onMembershipChanged,
    required this.onSignOut,
    super.key,
  });

  final ChurchRepository repository;
  final Future<void> Function() onMembershipChanged;
  final Future<void> Function() onSignOut;

  @override
  State<ChurchDiscoveryPage> createState() => _ChurchDiscoveryPageState();
}

class _ChurchDiscoveryPageState extends State<ChurchDiscoveryPage> {
  final _queryController = TextEditingController();
  Future<List<ChurchBranding>>? _churches;
  bool _busy = false;
  ChurchBranding? _selectedChurch;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _search() {
    setState(() {
      _churches = widget.repository.fetchChurches(query: _queryController.text);
    });
  }

  Future<void> _join(ChurchBranding church) async {
    setState(() => _busy = true);
    try {
      final membership = await widget.repository.requestMembership(church.id);
      if (!mounted) return;
      final pending = membership.status == 'pending';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(pending
            ? 'A sua solicitacao esta pendente.'
            : 'Agora faz parte de ${church.name}.'),
      ));
      await widget.onMembershipChanged();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Nao foi possivel solicitar a entrada. Confirma a internet ou tenta novamente.'),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptInvite() async {
    final controller = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Aceitar convite'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Codigo do convite',
            hintText: 'Introduza o codigo recebido',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Aceitar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (token == null || token.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.repository.acceptInvite(token);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Convite aceite com sucesso.')),
      );
      await widget.onMembershipChanged();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('O convite e invalido, expirou ou ja foi utilizado.'),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF06275D), Color(0xFFFBF7EC), Color(0xFFFFFDF8)],
              stops: [0, .20, 1],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(
                          onPressed: _busy ? null : _acceptInvite,
                          child: const Text('Tenho um convite')),
                      TextButton(
                          onPressed: _busy ? null : widget.onSignOut,
                          child: const Text('Sair')),
                    ]),
                    const Text('Powered by DeliGo Triunfal, Lda.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Image.asset('assets/branding/comunhao.png', height: 84),
                    const SizedBox(height: 8),
                    Text('Encontre a sua igreja',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF082A62))),
                    const SizedBox(height: 6),
                    const Text(
                        'Procure pelo nome ou localização para continuar',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _queryController,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: 'Nome da igreja, cidade ou bairro',
                        prefixIcon:
                            const Icon(Icons.search, color: Color(0xFF082A62)),
                        suffixIcon: IconButton(
                            icon: const Icon(Icons.search), onPressed: _search),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: .94),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide:
                                const BorderSide(color: Color(0xFF123979))),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                        child: FutureBuilder<List<ChurchBranding>>(
                      future: _churches,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done)
                          return const Center(
                              child: CircularProgressIndicator());
                        final churches =
                            snapshot.data ?? const <ChurchBranding>[];
                        if (churches.isEmpty)
                          return const Center(
                              child: Text('Nenhuma igreja encontrada.'));
                        return ListView.separated(
                          itemCount: churches.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final church = churches[index];
                            final selected = _selectedChurch?.id == church.id;
                            return Material(
                              color: Colors.white.withValues(alpha: .94),
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: _busy
                                    ? null
                                    : () => setState(
                                        () => _selectedChurch = church),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                          color: selected
                                              ? const Color(0xFFD89A26)
                                              : const Color(0x33253B66),
                                          width: selected ? 2 : 1)),
                                  child: Row(children: [
                                    const CircleAvatar(
                                        backgroundColor: Color(0xFFFFF5DE),
                                        child: Icon(Icons.church_outlined,
                                            color: Color(0xFF082A62))),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(church.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF082A62))),
                                          const SizedBox(height: 4),
                                          Text([
                                            church.locationLabel,
                                            'Verificada'
                                          ]
                                              .where(
                                                  (value) => value.isNotEmpty)
                                              .join(' • ')),
                                        ])),
                                    Icon(
                                        selected
                                            ? Icons.check_circle
                                            : Icons.chevron_right,
                                        color: selected
                                            ? const Color(0xFFD89A26)
                                            : const Color(0xFF082A62)),
                                  ]),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    )),
                    const SizedBox(height: 12),
                    OutlinedButton(
                        onPressed: _busy ? null : _acceptInvite,
                        child: const Text('A minha igreja não aparece')),
                    const SizedBox(height: 10),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy || _selectedChurch == null
                              ? null
                              : () => _join(_selectedChurch!),
                          child: const Text('CONTINUAR'),
                        )),
                    const SizedBox(height: 8),
                    const Text(
                        'Depois de selecionar, poderá entrar ou criar a sua conta de membro',
                        textAlign: TextAlign.center),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

class ChurchSwitcherPage extends StatelessWidget {
  const ChurchSwitcherPage({
    required this.repository,
    required this.userId,
    required this.onChurchSelected,
    super.key,
  });

  final ChurchRepository repository;
  final String userId;
  final Future<void> Function(ChurchBranding church) onChurchSelected;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Trocar de igreja')),
        body: FutureBuilder<List<ChurchBranding>>(
          future: repository.fetchChurchesForUser(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final churches = snapshot.data ?? const <ChurchBranding>[];
            if (churches.isEmpty) {
              return const Center(
                  child:
                      Text('Nao existem outras igrejas ativas nesta conta.'));
            }
            return ListView.builder(
              itemCount: churches.length,
              itemBuilder: (context, index) {
                final church = churches[index];
                return ListTile(
                  leading:
                      const CircleAvatar(child: Icon(Icons.church_outlined)),
                  title: Text(church.name),
                  subtitle: Text(church.locationLabel),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await onChurchSelected(church);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                );
              },
            );
          },
        ),
      );
}
