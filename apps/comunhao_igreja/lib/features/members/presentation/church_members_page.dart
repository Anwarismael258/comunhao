import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:flutter/material.dart';

class ChurchMembersPage extends StatefulWidget {
  const ChurchMembersPage({
    required this.members,
    required this.pendingJoinRequests,
    required this.readOnly,
    required this.onManageMember,
    super.key,
  });

  final List<ManagedMember> members;
  final int pendingJoinRequests;
  final bool readOnly;
  final ValueChanged<ManagedMember> onManageMember;

  @override
  State<ChurchMembersPage> createState() => _ChurchMembersPageState();
}

class _ChurchMembersPageState extends State<ChurchMembersPage> {
  final _searchController = TextEditingController();
  String _status = 'all';
  String _role = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ManagedMember> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    return widget.members.where((member) {
      final matchesQuery = query.isEmpty ||
          member.fullName.toLowerCase().contains(query) ||
          (member.phone ?? '').contains(query);
      final matchesStatus = _status == 'all' || member.status == _status;
      final matchesRole = _role == 'all' || member.role == _role;
      return matchesQuery && matchesStatus && matchesRole;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final members = _filtered;
    final active =
        widget.members.where((item) => item.status == 'active').length;
    final visitors =
        widget.members.where((item) => item.status == 'visitor').length;
    final inactive =
        widget.members.where((item) => item.status == 'inactive').length;
    final birthdays =
        widget.members.where((item) => item.birthDate != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkspaceSectionCard(
          title: 'Membros',
          subtitle:
              'Lista da igreja com estado, papel, contacto e acompanhamento.',
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              WorkspaceMetricCard(
                label: 'Total',
                value: widget.members.length.toString(),
                icon: Icons.groups_outlined,
              ),
              WorkspaceMetricCard(
                label: 'Ativos',
                value: active.toString(),
                icon: Icons.verified_user_outlined,
              ),
              WorkspaceMetricCard(
                label: 'Visitantes',
                value: visitors.toString(),
                icon: Icons.person_add_alt_1_outlined,
              ),
              WorkspaceMetricCard(
                label: 'Inativos',
                value: inactive.toString(),
                icon: Icons.person_off_outlined,
              ),
              WorkspaceMetricCard(
                label: 'Aniversariantes',
                value: birthdays.toString(),
                icon: Icons.cake_outlined,
              ),
              WorkspaceMetricCard(
                label: 'Pedidos pendentes',
                value: widget.pendingJoinRequests.toString(),
                icon: Icons.how_to_reg_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        WorkspaceSectionCard(
          title: 'Filtros',
          subtitle: 'Procura por nome ou telefone e filtra por estado ou role.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Pesquisar',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todos')),
                    DropdownMenuItem(value: 'active', child: Text('Ativo')),
                    DropdownMenuItem(
                        value: 'visitor', child: Text('Visitante')),
                    DropdownMenuItem(
                        value: 'candidate', child: Text('Candidato')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inativo')),
                    DropdownMenuItem(
                        value: 'transferred', child: Text('Transferido')),
                    DropdownMenuItem(
                        value: 'suspended', child: Text('Suspenso')),
                    DropdownMenuItem(
                        value: 'archived', child: Text('Arquivado')),
                  ],
                  onChanged: (value) =>
                      setState(() => _status = value ?? 'all'),
                ),
              ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todas')),
                    DropdownMenuItem(value: 'pastor', child: Text('Pastor')),
                    DropdownMenuItem(
                        value: 'church_admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'leader', child: Text('Lider')),
                    DropdownMenuItem(value: 'member', child: Text('Membro')),
                  ],
                  onChanged: (value) => setState(() => _role = value ?? 'all'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (members.isEmpty)
          const WorkspaceSectionCard(
            title: 'Nenhum membro encontrado',
            subtitle: 'Nenhum membro corresponde aos filtros selecionados.',
            child: Text('Limpa os filtros ou aprova novos pedidos de entrada.'),
          )
        else
          WorkspaceSectionCard(
            title: 'Lista de membros',
            subtitle: '${members.length} resultado(s)',
            child: Column(
              children: members.map((member) {
                return Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(member.fullName),
                      subtitle: Text(
                        '${member.roleLabel} - ${member.statusLabel}'
                        '${member.phone == null ? '' : '\n${member.phone}'}'
                        '${member.neighborhood == null ? '' : ' - ${member.neighborhood}'}',
                      ),
                      trailing: Text(
                        member.totalContributed > 0
                            ? '${member.totalContributed} MZN'
                            : '',
                      ),
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: widget.readOnly
                              ? null
                              : () => widget.onManageMember(member),
                          icon: const Icon(Icons.manage_accounts_outlined),
                          label: const Text('Gerir'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showProfile(context, member),
                          icon: const Icon(Icons.badge_outlined),
                          label: const Text('Perfil'),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  void _showProfile(BuildContext context, ManagedMember member) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(member.fullName),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Telefone: ${member.phone ?? 'Sem telefone'}'),
                const SizedBox(height: 8),
                Text('Estado: ${member.statusLabel}'),
                const SizedBox(height: 8),
                Text('Role: ${member.roleLabel}'),
                if (member.neighborhood != null) ...[
                  const SizedBox(height: 8),
                  Text('Bairro: ${member.neighborhood}'),
                ],
                if (member.entryDate != null) ...[
                  const SizedBox(height: 8),
                  Text('Entrada: ${_date(member.entryDate!)}'),
                ],
                const Divider(height: 24),
                Text('Total contribuido: ${member.totalContributed} MZN'),
                const SizedBox(height: 8),
                Text(
                    'Contribuicoes pendentes: ${member.pendingContributions} MZN'),
                const Divider(height: 24),
                const Text(
                  'Dados pastorais confidenciais nao aparecem neste perfil geral.',
                ),
              ],
            ),
          ),
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

  String _date(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}
