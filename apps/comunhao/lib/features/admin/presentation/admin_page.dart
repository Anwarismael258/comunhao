import 'package:flutter/material.dart';

import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/section_card.dart';
import '../../church/models/church_branding.dart';
import '../../church/models/church_member.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({
    required this.church,
    required this.currentMember,
    super.key,
  });

  final ChurchBranding church;
  final ChurchMember currentMember;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Painel de ${church.name}')),
      body: ListView(
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
                label: 'Codigo da igreja',
                value: church.codeLabel,
                icon: Icons.key_outlined,
              ),
              MetricCard(
                label: 'Operador atual',
                value: currentMember.roleLabel,
                icon: Icons.admin_panel_settings_outlined,
              ),
              const MetricCard(
                label: 'Papeis suportados',
                value: '5',
                icon: Icons.groups_outlined,
              ),
              MetricCard(
                label: 'Cidade',
                value: church.city ?? '--',
                icon: Icons.location_city_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionCard(
            title: 'Entrada de membros',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.phone_android_outlined),
                  title: Text('Telefone como identificador unico'),
                  subtitle: Text(
                    'O membro instala a Comunhao, escolhe a igreja e cria conta sem email.',
                  ),
                ),
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.sms_outlined),
                  title: Text('Confirmacao por OTP'),
                  subtitle: Text(
                    'Depois do SMS, a conta entra automaticamente na igreja como Membro.',
                  ),
                ),
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.badge_outlined),
                  title: Text('Sem aprovacao manual'),
                  subtitle: Text(
                    'A equipa da igreja gere papeis e estado dos membros depois da entrada.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Branding atual',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.branding_watermark_outlined),
                  title: const Text('Nome do app'),
                  subtitle: Text(church.appName),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Cores'),
                  subtitle: Text(
                    '${church.primaryColor ?? 'sem cor primaria'} / ${church.secondaryColor ?? 'sem cor secundaria'}',
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.support_agent_outlined),
                  title: const Text('Suporte'),
                  subtitle: Text(
                    church.phone ?? church.email ?? 'Sem contacto configurado',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionCard(
            title: 'Gestao da comunidade',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person_remove_outlined),
                  title: Text('Remover membros'),
                  subtitle: Text(
                    'Usa quando alguem sai da igreja ou perde acesso ao app.',
                  ),
                ),
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.block_outlined),
                  title: Text('Bloquear membros'),
                  subtitle: Text(
                    'Mantem o historico, mas corta o acesso de numeros com abuso ou erro.',
                  ),
                ),
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.swap_horiz_outlined),
                  title: Text('Transferir para outra igreja'),
                  subtitle: Text(
                    'Permite mover um membro quando muda de congregacao dentro da rede.',
                  ),
                ),
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.manage_accounts_outlined),
                  title: Text('Alterar funcoes'),
                  subtitle: Text(
                    'Promove entre Membro, Lider, Pastor e Administrador da Igreja.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionCard(
            title: 'Papeis',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Super Admin'),
                  subtitle: Text('Controla a plataforma Comunhao inteira.'),
                ),
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Administrador da Igreja'),
                  subtitle: Text('Gere branding, membros e operacao local.'),
                ),
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Pastor'),
                  subtitle: Text(
                      'Lidera a comunidade e acompanha pedidos sensiveis.'),
                ),
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Lider'),
                  subtitle:
                      Text('Apoia grupos, eventos e comunicacao da igreja.'),
                ),
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Membro'),
                  subtitle:
                      Text('Papel inicial de toda conta criada por telefone.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Pagamentos configurados',
            child: church.paymentChannels.isEmpty
                ? const Text('Ainda nao existem canais configurados.')
                : Column(
                    children: [
                      for (var i = 0;
                          i < church.paymentChannels.length;
                          i++) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.receipt_long_outlined),
                          title: Text(church.paymentChannels[i].label),
                          subtitle: Text(
                            church.paymentChannels[i].accountNumber ??
                                'Sem numero configurado',
                          ),
                        ),
                        if (i != church.paymentChannels.length - 1)
                          const Divider(),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
