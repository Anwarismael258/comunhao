import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../../church/models/church_branding.dart';
import '../../church/models/church_member.dart';

class MemberOperationsPage extends StatefulWidget {
  const MemberOperationsPage({
    required this.church,
    required this.member,
    required this.repository,
    super.key,
  });

  final ChurchBranding church;
  final ChurchMember member;
  final OperationsRepository repository;

  @override
  State<MemberOperationsPage> createState() => _MemberOperationsPageState();
}

class _MemberOperationsPageState extends State<MemberOperationsPage> {
  late Future<MemberOperationsSnapshot> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<MemberOperationsSnapshot> _load() {
    return widget.repository.fetchMemberOperations(
      churchId: widget.church.id,
      membershipId: widget.member.membershipId,
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
      if (!mounted) {
        return;
      }
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MemberOperationsSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Nao foi possivel carregar a area de servico.\n\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SectionCard(
                title: 'Meu servico na igreja',
                subtitle:
                    'Ministerios, grupos, tarefas, escalas e candidaturas.',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Metric(
                      icon: Icons.group_work_outlined,
                      label: 'Ministerios',
                      value: widget.member.ministries.length,
                    ),
                    _Metric(
                      icon: Icons.groups_2_outlined,
                      label: 'Grupos',
                      value: data.groups.length,
                    ),
                    _Metric(
                      icon: Icons.task_alt_outlined,
                      label: 'Tarefas',
                      value: data.tasks.length,
                    ),
                    _Metric(
                      icon: Icons.event_note_outlined,
                      label: 'Escalas',
                      value: data.rosters.length,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Meus ministerios',
                subtitle: 'Equipas onde esta conta ja participa.',
                child: widget.member.ministries.isEmpty
                    ? const Text('Ainda nao estas ligado a um ministerio.')
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.member.ministries
                            .map((name) => Chip(label: Text(name)))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 16),
              _groups(data.groups),
              const SizedBox(height: 16),
              _tasks(data.tasks),
              const SizedBox(height: 16),
              _rosters(data.rosters),
              const SizedBox(height: 16),
              _joinRequests(data.joinRequests),
              const SizedBox(height: 16),
              _opportunities(data),
            ],
          ),
        );
      },
    );
  }

  Widget _groups(List<ChurchGroup> groups) {
    return SectionCard(
      title: 'Meus grupos',
      subtitle: 'Celulas, equipas e turmas visiveis para membros.',
      child: groups.isEmpty
          ? const Text('Nenhum grupo disponivel para esta igreja.')
          : Column(
              children: groups
                  .map(
                    (group) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(child: Icon(Icons.groups_2)),
                      title: Text(group.name),
                      subtitle: Text(
                        [
                          group.groupTypeLabel,
                          if (group.location != null) group.location!,
                          if (group.usualDay != null)
                            '${group.usualDay} ${group.usualTime ?? ''}',
                        ].join('\n'),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _tasks(List<OperationalTask> tasks) {
    return SectionCard(
      title: 'Minhas tarefas',
      subtitle: 'Tarefas atribuídas ou colaborativas.',
      child: tasks.isEmpty
          ? const Text('Nao existem tarefas atribuidas a ti.')
          : Column(
              children: tasks
                  .map(
                    (task) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(child: Icon(Icons.task_alt)),
                      title: Text(task.title),
                      subtitle: Text(
                        '${task.statusLabel} - ${task.priority} - ${task.progressPercent}%',
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _rosters(List<ServiceRoster> rosters) {
    return SectionCard(
      title: 'Minhas escalas',
      subtitle: 'Confirma ou recusa a tua disponibilidade.',
      child: rosters.isEmpty
          ? const Text('Nao tens escalas pendentes.')
          : Column(
              children: rosters
                  .map(
                    (roster) => Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.event_note_outlined),
                          ),
                          title: Text(roster.roleTitle),
                          subtitle: Text(
                            '${_format(roster.startsAt)} - ${roster.statusLabel}'
                            '${roster.location == null ? '' : '\n${roster.location}'}',
                          ),
                        ),
                        if (roster.status == 'pending_confirmation')
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: _busy
                                      ? null
                                      : () => _respondRoster(
                                            roster,
                                            'confirmed',
                                          ),
                                  icon: const Icon(Icons.check_outlined),
                                  label: const Text('Confirmar'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _respondRoster(
                                            roster,
                                            'declined',
                                          ),
                                  icon: const Icon(Icons.close_outlined),
                                  label: const Text('Recusar'),
                                ),
                              ],
                            ),
                          ),
                        const Divider(),
                      ],
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _joinRequests(List<MinistryJoinRequest> requests) {
    return SectionCard(
      title: 'Candidaturas a ministerios',
      subtitle: 'Pede entrada numa equipa ou acompanha pedidos anteriores.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : _openJoinRequestDialog,
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Pedir entrada'),
          ),
          const SizedBox(height: 12),
          if (requests.isEmpty)
            const Text('Ainda nao tens candidaturas registadas.')
          else
            ...requests.map(
              (request) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.how_to_reg_outlined),
                ),
                title: Text(
                  request.ministryName ?? request.groupName ?? 'Candidatura',
                ),
                subtitle: Text(request.statusLabel),
              ),
            ),
        ],
      ),
    );
  }

  Widget _opportunities(MemberOperationsSnapshot data) {
    final applicationIds =
        data.applications.map((item) => item.opportunityId).toSet();
    return SectionCard(
      title: 'Oportunidades de voluntariado',
      subtitle: 'Servicos abertos pela igreja para membros.',
      child: data.opportunities.isEmpty
          ? const Text('Nao existem oportunidades abertas agora.')
          : Column(
              children: data.opportunities.map((opportunity) {
                final applied = applicationIds.contains(opportunity.id);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.volunteer_activism_outlined),
                  ),
                  title: Text(opportunity.title),
                  subtitle: Text(
                    [
                      if (opportunity.ministryName != null)
                        opportunity.ministryName!,
                      if (opportunity.location != null) opportunity.location!,
                      if (opportunity.slots != null)
                        '${opportunity.slots} vaga(s)',
                    ].join('\n'),
                  ),
                  trailing: applied
                      ? const Chip(label: Text('Candidatado'))
                      : FilledButton.tonalIcon(
                          onPressed: _busy
                              ? null
                              : () => _applyOpportunity(opportunity),
                          icon: const Icon(Icons.send_outlined),
                          label: const Text('Candidatar'),
                        ),
                );
              }).toList(),
            ),
    );
  }

  Future<void> _openJoinRequestDialog() async {
    final interest = TextEditingController();
    final experience = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pedir entrada em ministerio'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: interest,
                decoration: const InputDecoration(
                  labelText: 'Ministerio/equipa de interesse',
                ),
              ),
              TextField(
                controller: experience,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Experiencia ou disponibilidade',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.send_outlined),
            label: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (saved == true) {
      await _run(
        () => widget.repository.createMinistryJoinRequest(
          churchId: widget.church.id,
          membershipId: widget.member.membershipId,
          interest: interest.text,
          experience: experience.text,
        ),
      );
    }
  }

  Future<void> _applyOpportunity(VolunteerOpportunity opportunity) async {
    await _run(
      () => widget.repository.applyToVolunteerOpportunity(
        opportunityId: opportunity.id,
        membershipId: widget.member.membershipId,
      ),
    );
  }

  Future<void> _respondRoster(ServiceRoster roster, String status) async {
    await _run(
      () => widget.repository.respondToRoster(
        rosterId: roster.id,
        status: status,
      ),
    );
  }

  static String _format(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text('$label: $value'),
    );
  }
}
