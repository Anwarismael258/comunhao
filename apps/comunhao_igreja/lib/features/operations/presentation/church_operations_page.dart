import 'dart:typed_data';

import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/web_upload_picker.dart';

class ChurchOperationsPage extends StatefulWidget {
  const ChurchOperationsPage({
    required this.church,
    required this.members,
    required this.ministries,
    required this.assets,
    required this.backofficeRepository,
    required this.operationsRepository,
    required this.readOnly,
    required this.onChanged,
    super.key,
  });

  final ManagedChurch church;
  final List<ManagedMember> members;
  final List<ChurchMinistry> ministries;
  final List<ChurchAsset> assets;
  final BackofficeRepository backofficeRepository;
  final OperationsRepository operationsRepository;
  final bool readOnly;
  final Future<void> Function() onChanged;

  @override
  State<ChurchOperationsPage> createState() => _ChurchOperationsPageState();
}

class _ChurchOperationsPageState extends State<ChurchOperationsPage> {
  late Future<OperationsSnapshot> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = widget.operationsRepository.fetchSnapshot(widget.church.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.operationsRepository.fetchSnapshot(widget.church.id);
    });
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
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
            margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
            duration: Duration(seconds: 5),
            content: Text(
              'Não foi possível concluir a operação. Verifica a ligação e tenta novamente.',
            ),
          ),
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
    return FutureBuilder<OperationsSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const WorkspaceHero(
              surface: ComunhaoSurface.churchAdmin,
              title: 'ERP Operacional',
              subtitle:
                  'Ministerios, grupos, tarefas, escalas, patrimonio, manutencoes, documentos, compras e stock.',
              icon: Icons.account_tree_outlined,
              color: Color(0xFF7C3AED),
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState != ConnectionState.done)
              const Center(child: CircularProgressIndicator())
            else if (snapshot.hasError)
              _ErrorBox(
                  message:
                      'Nao foi possivel carregar operacoes: ${snapshot.error}')
            else if (data != null) ...[
              _MetricsGrid(metrics: data.metrics),
              const SizedBox(height: 16),
              _actionBar(),
              const SizedBox(height: 16),
              DefaultTabController(
                length: 5,
                child: Column(
                  children: [
                    const Material(
                      child: TabBar(
                        isScrollable: true,
                        tabs: [
                          Tab(
                            icon: Icon(Icons.groups_2_outlined),
                            text: 'Pessoas',
                          ),
                          Tab(
                            icon: Icon(Icons.task_alt_outlined),
                            text: 'Tarefas',
                          ),
                          Tab(
                            icon: Icon(Icons.event_note_outlined),
                            text: 'Escalas',
                          ),
                          Tab(
                            icon: Icon(Icons.inventory_2_outlined),
                            text: 'Recursos',
                          ),
                          Tab(
                            icon: Icon(Icons.shopping_cart_outlined),
                            text: 'Compras',
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 980,
                      child: TabBarView(
                        children: [
                          ListView(
                            padding: const EdgeInsets.only(top: 16),
                            children: [
                              _ministriesSection(),
                              const SizedBox(height: 16),
                              _groupsSection(data.groups),
                            ],
                          ),
                          ListView(
                            padding: const EdgeInsets.only(top: 16),
                            children: [_tasksSection(data.tasks)],
                          ),
                          ListView(
                            padding: const EdgeInsets.only(top: 16),
                            children: [_rostersSection(data.rosters)],
                          ),
                          ListView(
                            padding: const EdgeInsets.only(top: 16),
                            children: [
                              _assetsSection(),
                              const SizedBox(height: 16),
                              _maintenanceSection(data.maintenance),
                              const SizedBox(height: 16),
                              _documentsSection(data.documents),
                              const SizedBox(height: 16),
                              _inventorySection(data.inventory),
                            ],
                          ),
                          ListView(
                            padding: const EdgeInsets.only(top: 16),
                            children: [_purchasesSection(data.purchases)],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _actionBar() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: _blocked ? null : _openMinistryDialog,
          icon: const Icon(Icons.group_work_outlined),
          label: const Text('Ministerio'),
        ),
        FilledButton.icon(
          onPressed: _blocked ? null : _openGroupDialog,
          icon: const Icon(Icons.groups_2_outlined),
          label: const Text('Grupo'),
        ),
        FilledButton.icon(
          onPressed: _blocked ? null : _openTaskDialog,
          icon: const Icon(Icons.task_alt_outlined),
          label: const Text('Tarefa'),
        ),
        FilledButton.icon(
          onPressed:
              _blocked || widget.members.isEmpty ? null : _openRosterDialog,
          icon: const Icon(Icons.event_note_outlined),
          label: const Text('Escala'),
        ),
        FilledButton.icon(
          onPressed: _blocked ? null : _openAssetDialog,
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Patrimonio'),
        ),
        FilledButton.icon(
          onPressed: _blocked ? null : _openMaintenanceDialog,
          icon: const Icon(Icons.build_outlined),
          label: const Text('Manutencao'),
        ),
        FilledButton.icon(
          onPressed: _blocked ? null : _openDocumentDialog,
          icon: const Icon(Icons.description_outlined),
          label: const Text('Documento'),
        ),
        FilledButton.icon(
          onPressed:
              _blocked || widget.members.isEmpty ? null : _openPurchaseDialog,
          icon: const Icon(Icons.shopping_cart_outlined),
          label: const Text('Compra'),
        ),
        FilledButton.icon(
          onPressed: _blocked ? null : _openInventoryDialog,
          icon: const Icon(Icons.warehouse_outlined),
          label: const Text('Stock'),
        ),
      ],
    );
  }

  bool get _blocked => _busy || widget.readOnly;

  Widget _ministriesSection() {
    return WorkspaceSectionCard(
      title: 'Ministerios e equipas',
      subtitle: 'Lideranca, membros e responsabilidades internas.',
      child: widget.ministries.isEmpty
          ? const Text('Ainda nao existem ministerios cadastrados.')
          : Column(
              children: widget.ministries
                  .map(
                    (ministry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                          child: Icon(Icons.group_work_outlined)),
                      title: Text(ministry.name),
                      subtitle: Text(
                        '${ministry.active ? 'Ativo' : 'Inativo'} - ${ministry.memberCount} membro(s)'
                        '${ministry.leaderName == null ? '' : '\nLider: ${ministry.leaderName}'}',
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _groupsSection(List<ChurchGroup> groups) {
    return _listSection(
      title: 'Grupos e celulas',
      subtitle: 'Grupos disponiveis, lideranca, local e horario.',
      empty: 'Nenhum grupo foi criado.',
      children: groups
          .map(
            (group) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.groups_2_outlined)),
              title: Text(group.name),
              subtitle: Text(
                '${group.groupTypeLabel} - ${group.status}'
                '${group.location == null ? '' : '\n${group.location}'}'
                '${group.usualDay == null ? '' : '\n${group.usualDay} ${group.usualTime ?? ''}'}',
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _tasksSection(List<OperationalTask> tasks) {
    return _listSection(
      title: 'Tarefas',
      subtitle: 'Lista operacional com estado, prioridade e progresso.',
      empty: 'Nao existem tarefas atribuidas.',
      children: tasks
          .map(
            (task) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.task_alt_outlined)),
              title: Text(task.title),
              subtitle: Text(
                  '${task.statusLabel} - ${task.priority} - ${task.progressPercent}%'),
            ),
          )
          .toList(),
    );
  }

  Widget _rostersSection(List<ServiceRoster> rosters) {
    return _listSection(
      title: 'Escalas de servico',
      subtitle: 'Pessoas escaladas e confirmacoes.',
      empty: 'Nao existem escalas configuradas.',
      children: rosters
          .map(
            (roster) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const CircleAvatar(child: Icon(Icons.event_note_outlined)),
              title: Text(roster.roleTitle),
              subtitle: Text(
                '${_format(roster.startsAt)} - ${roster.status}'
                '${roster.assignedName == null ? '' : '\n${roster.assignedName}'}',
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _assetsSection() {
    return WorkspaceSectionCard(
      title: 'Patrimonio',
      subtitle: 'Bens, equipamentos e responsaveis.',
      child: widget.assets.isEmpty
          ? const Text('Nenhum bem patrimonial foi registado.')
          : Column(
              children: widget.assets
                  .map(
                    (asset) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                          child: Icon(Icons.inventory_2_outlined)),
                      title: Text(asset.name),
                      subtitle: Text(
                        '${asset.categoryLabel} - ${asset.quantity} un - ${asset.conditionLabel}'
                        '${asset.location == null ? '' : '\n${asset.location}'}',
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _maintenanceSection(List<MaintenanceRequest> items) {
    return _listSection(
      title: 'Manutencao',
      subtitle: 'Preventiva e corretiva sem pagamento automatico.',
      empty: 'Nao existem manutencoes pendentes.',
      children: items
          .map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.build_outlined)),
              title: Text(item.problem),
              subtitle: Text('${item.status} - ${item.priority}'),
            ),
          )
          .toList(),
    );
  }

  Widget _documentsSection(List<ChurchDocument> items) {
    return _listSection(
      title: 'Documentos',
      subtitle: 'Biblioteca interna e validade.',
      empty: 'Nenhum documento esta proximo do vencimento.',
      children: items
          .map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const CircleAvatar(child: Icon(Icons.description_outlined)),
              title: Text(item.title),
              subtitle: Text('${item.documentType} - ${item.confidentiality}'
                  '${item.validUntil == null ? '' : '\nValido ate ${_date(item.validUntil!)}'}'),
            ),
          )
          .toList(),
    );
  }

  Widget _purchasesSection(List<PurchaseRequest> items) {
    return _listSection(
      title: 'Pedidos de compra',
      subtitle: 'Aprovacao antes de qualquer despesa.',
      empty: 'Nao existem compras pendentes.',
      children: items
          .map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const CircleAvatar(child: Icon(Icons.shopping_cart_outlined)),
              title: Text(item.itemName),
              subtitle: Text('${item.quantity} un - ${item.status}'),
            ),
          )
          .toList(),
    );
  }

  Widget _inventorySection(List<InventoryItem> items) {
    return _listSection(
      title: 'Consumiveis',
      subtitle: 'Entradas, saidas e alerta de stock baixo.',
      empty: 'Nao existem itens de stock registados.',
      children: items
          .map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Icon(item.lowStock
                    ? Icons.warning_amber_outlined
                    : Icons.warehouse_outlined),
              ),
              title: Text(item.name),
              subtitle: Text(
                  '${item.quantityCurrent} ${item.unit} - minimo ${item.quantityMinimum}'),
            ),
          )
          .toList(),
    );
  }

  Widget _listSection({
    required String title,
    required String subtitle,
    required String empty,
    required List<Widget> children,
  }) {
    return WorkspaceSectionCard(
      title: title,
      subtitle: subtitle,
      child: children.isEmpty ? Text(empty) : Column(children: children),
    );
  }

  Future<void> _openMinistryDialog() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final leader =
        widget.members.isEmpty ? null : widget.members.first.membershipId;
    final result = await _simpleDialog(
      title: 'Novo ministerio',
      fields: [
        _textField(name, 'Nome'),
        _textField(description, 'Descricao'),
      ],
    );
    if (result == true && name.text.trim().isNotEmpty) {
      await _run(
        () => widget.backofficeRepository.saveChurchMinistry(
          churchId: widget.church.id,
          name: name.text,
          description: description.text,
          leaderMembershipId: leader,
          active: true,
          memberMembershipIds: [if (leader != null) leader],
        ),
      );
    }
  }

  Future<void> _openGroupDialog() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final location = TextEditingController();
    final result = await _simpleDialog(
      title: 'Novo grupo',
      fields: [
        _textField(name, 'Nome'),
        _textField(description, 'Descricao'),
        _textField(location, 'Local'),
      ],
    );
    if (result == true && name.text.trim().isNotEmpty) {
      await _run(
        () => widget.operationsRepository.saveGroup(
          churchId: widget.church.id,
          name: name.text,
          groupType: 'cell',
          description: description.text,
          location: location.text,
        ),
      );
    }
  }

  Future<void> _openTaskDialog() async {
    final title = TextEditingController();
    final description = TextEditingController();
    final result = await _simpleDialog(
      title: 'Nova tarefa',
      fields: [
        _textField(title, 'Titulo'),
        _textField(description, 'Descricao')
      ],
    );
    if (result == true && title.text.trim().isNotEmpty) {
      await _run(
        () => widget.operationsRepository.saveTask(
          churchId: widget.church.id,
          title: title.text,
          description: description.text,
          priority: 'normal',
          status: 'todo',
          dueAt: DateTime.now().add(const Duration(days: 7)),
        ),
      );
    }
  }

  Future<void> _openRosterDialog() async {
    final role = TextEditingController();
    final location = TextEditingController();
    final memberId = widget.members.first.membershipId;
    final result = await _simpleDialog(
      title: 'Nova escala',
      fields: [_textField(role, 'Funcao'), _textField(location, 'Local')],
    );
    if (result == true && role.text.trim().isNotEmpty) {
      await _run(
        () => widget.operationsRepository.saveRoster(
          churchId: widget.church.id,
          roleTitle: role.text,
          assignedMembershipId: memberId,
          startsAt: DateTime.now().add(const Duration(days: 3)),
          location: location.text,
        ),
      );
    }
  }

  Future<void> _openAssetDialog() async {
    final name = TextEditingController();
    final location = TextEditingController();
    final result = await _simpleDialog(
      title: 'Novo patrimonio',
      fields: [_textField(name, 'Nome'), _textField(location, 'Local')],
    );
    if (result == true && name.text.trim().isNotEmpty) {
      await _run(
        () => widget.backofficeRepository.saveChurchAsset(
          churchId: widget.church.id,
          category: 'outro',
          name: name.text,
          quantity: 1,
          itemCondition: 'good',
          location: location.text,
        ),
      );
    }
  }

  Future<void> _openMaintenanceDialog() async {
    final problem = TextEditingController();
    final result = await _simpleDialog(
      title: 'Nova manutencao',
      fields: [_textField(problem, 'Problema')],
    );
    if (result == true && problem.text.trim().isNotEmpty) {
      await _run(
        () => widget.operationsRepository.saveMaintenance(
          churchId: widget.church.id,
          problem: problem.text,
          priority: 'normal',
          expectedAt: DateTime.now().add(const Duration(days: 5)),
        ),
      );
    }
  }

  Future<void> _openDocumentDialog() async {
    final title = TextEditingController();
    final result = await _simpleDialog(
      title: 'Novo documento',
      fields: [_textField(title, 'Titulo')],
    );
    if (result == true && title.text.trim().isNotEmpty) {
      (String, Uint8List)? selected;
      try {
        selected = await _pickChurchDocument();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível concluir a operação. Verifica a ligação e tenta novamente.',
              ),
            ),
          );
        }
        return;
      }
      if (selected == null) return;
      final (name, bytes) = selected;

      await _run(
        () async {
          final storagePath = await _uploadChurchDocument(name, bytes);
          try {
            await widget.operationsRepository.saveDocument(
              churchId: widget.church.id,
              title: title.text,
              documentType: 'document',
              validUntil: DateTime.now().add(const Duration(days: 30)),
              confidentiality: 'internal',
              storageBucket: _churchDocumentsBucket,
              storagePath: storagePath,
            );
          } catch (_) {
            try {
              await Supabase.instance.client.storage
                  .from(_churchDocumentsBucket)
                  .remove([storagePath]);
            } catch (_) {
              // The retry-safe central registry can reconcile an orphan later.
            }
            rethrow;
          }
        },
      );
    }
  }

  static const _churchDocumentsBucket = 'church-documents';
  static const _maxDocumentBytes = 10 * 1024 * 1024;
  static const _documentExtensions = <String>[
    'pdf',
    'png',
    'jpg',
    'jpeg',
    'doc',
    'docx',
  ];

  Future<(String, Uint8List)?> _pickChurchDocument() async {
    final webFile = await pickUploadFile(
      allowedExtensions: _documentExtensions,
      accept:
          'application/pdf,image/png,image/jpeg,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    final selected = webFile == null
        ? await _pickNativeDocument()
        : (webFile.name, webFile.bytes);
    if (selected == null) return null;

    final (name, bytes) = selected;
    if (bytes.length > _maxDocumentBytes) {
      throw StateError('O documento deve ter no maximo 10 MB.');
    }
    if (!_documentExtensions.contains(_extensionFor(name))) {
      throw StateError('Usa PDF, PNG, JPG, DOC ou DOCX.');
    }
    return selected;
  }

  Future<(String, Uint8List)?> _pickNativeDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _documentExtensions,
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return null;
    return (file.name, bytes);
  }

  Future<String> _uploadChurchDocument(String name, Uint8List bytes) async {
    final extension = _extensionFor(name);
    final path =
        '${widget.church.id}/documents/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await Supabase.instance.client.storage
        .from(_churchDocumentsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions:
              FileOptions(contentType: _documentContentType(extension)),
        );
    return path;
  }

  String _extensionFor(String name) {
    final lower = name.toLowerCase();
    for (final extension in _documentExtensions) {
      if (lower.endsWith('.$extension')) {
        return extension == 'jpeg' ? 'jpg' : extension;
      }
    }
    return '';
  }

  String _documentContentType(String extension) {
    return switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' => 'image/jpeg',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'application/octet-stream',
    };
  }

  Future<void> _openPurchaseDialog() async {
    final item = TextEditingController();
    final result = await _simpleDialog(
      title: 'Novo pedido de compra',
      fields: [_textField(item, 'Item')],
    );
    if (result == true && item.text.trim().isNotEmpty) {
      await _run(
        () => widget.operationsRepository.savePurchaseRequest(
          churchId: widget.church.id,
          requestedByMembershipId: widget.members.first.membershipId,
          itemName: item.text,
          quantity: 1,
        ),
      );
    }
  }

  Future<void> _openInventoryDialog() async {
    final name = TextEditingController();
    final result = await _simpleDialog(
      title: 'Novo item de stock',
      fields: [_textField(name, 'Nome')],
    );
    if (result == true && name.text.trim().isNotEmpty) {
      await _run(
        () => widget.operationsRepository.saveInventoryItem(
          churchId: widget.church.id,
          name: name.text,
          unit: 'un',
          quantityCurrent: 0,
          quantityMinimum: 5,
        ),
      );
    }
  }

  Widget _textField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Future<bool?> _simpleDialog({
    required String title,
    required List<Widget> fields,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: fields)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  static String _format(DateTime value) {
    final local = value.toLocal();
    return '${_two(local.day)}/${_two(local.month)}/${local.year} ${_two(local.hour)}:${_two(local.minute)}';
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    return '${_two(local.day)}/${_two(local.month)}/${local.year}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final OperationalMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Ministerios', metrics.ministriesActive, Icons.group_work_outlined),
      ('Grupos', metrics.groupsActive, Icons.groups_2_outlined),
      ('Tarefas', metrics.tasksPending, Icons.task_alt_outlined),
      ('Atrasadas', metrics.tasksOverdue, Icons.warning_amber_outlined),
      ('Escalas', metrics.rostersPending, Icons.event_note_outlined),
      ('Manutencao', metrics.maintenancePending, Icons.build_outlined),
      ('Docs', metrics.documentsExpiring, Icons.description_outlined),
      ('Stock baixo', metrics.stockLow, Icons.warehouse_outlined),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: items
          .map(
            (item) => WorkspaceMetricCard(
              label: item.$1,
              value: '${item.$2}',
              icon: item.$3,
            ),
          )
          .toList(),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return WorkspaceSectionCard(
      title: 'Erro',
      subtitle: 'Operacoes internas',
      child: Text(message),
    );
  }
}
