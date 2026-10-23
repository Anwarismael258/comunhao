import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/formatting.dart';
import '../../../core/widgets/section_card.dart';
import '../../church/data/church_repository.dart';
import '../../church/models/church_branding.dart';
import '../../church/models/church_member.dart';
import '../../church/models/member_wallet_summary.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.church,
    required this.member,
    required this.darkMode,
    required this.onDarkModeChanged,
    required this.onDeleteAccount,
    super.key,
  });

  final ChurchBranding church;
  final ChurchMember member;
  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final Future<void> Function() onDeleteAccount;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _notificationsKey = 'member_pref_notifications';
  static const _eventsKey = 'member_pref_events';

  bool _receiveNotifications = true;
  bool _receiveEventAlerts = true;
  bool _uploadingPhoto = false;
  bool _deletingAccount = false;
  bool _updatingName = false;
  late String _memberName;
  String? _avatarUrl;
  late Future<MemberWalletSummary?> _walletFuture;

  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _memberName = widget.member.fullName;
    _avatarUrl = widget.member.avatarUrl;
    _walletFuture = _loadWallet();
    _loadPreferences();
  }

  Future<MemberWalletSummary?> _loadWallet() async {
    try {
      final row = await Supabase.instance.client.rpc(
        'get_member_wallet_summary',
      );
      if (row is Map) {
        return MemberWalletSummary.fromMap(Map<String, dynamic>.from(row));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.member.avatarUrl != widget.member.avatarUrl) {
      _avatarUrl = widget.member.avatarUrl;
    }
    if (oldWidget.member.fullName != widget.member.fullName &&
        _memberName == oldWidget.member.fullName) {
      _memberName = widget.member.fullName;
    }
  }

  Future<void> _loadPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _receiveNotifications = preferences.getBool(_notificationsKey) ?? true;
      _receiveEventAlerts = preferences.getBool(_eventsKey) ?? true;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(key, value);
  }

  Future<void> _pickProfilePhoto() async {
    if (_uploadingPhoto) {
      return;
    }

    setState(() => _uploadingPhoto = true);
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 86,
        maxWidth: 1200,
      );
      if (image == null) {
        return;
      }

      final bytes = await image.readAsBytes();
      final extension = _extensionFor(image.name);
      final storagePath =
          '${widget.member.churchId}/profiles/${widget.member.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final contentType = _contentTypeFor(extension);
      final client = Supabase.instance.client;

      await client.storage.from('profile-media').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );
      await client.rpc(
        'update_my_profile_avatar',
        params: {
          'p_avatar_storage_path': storagePath,
          'p_avatar_url': null,
        },
      );

      final signedUrl = await client.storage
          .from('profile-media')
          .createSignedUrl(storagePath, 60 * 60);

      if (!mounted) {
        return;
      }
      setState(() => _avatarUrl = signedUrl);
      _showMessage('Foto de perfil atualizada.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_friendlyPhotoError(error));
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  String _extensionFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  String _contentTypeFor(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  String _friendlyPhotoError(Object error) {
    final lower = error.toString().toLowerCase();
    if (lower.contains('row-level security') ||
        lower.contains('permission') ||
        lower.contains('unauthorized')) {
      return 'Sem permissao para guardar a foto. Aplica a migration de storage e tenta novamente.';
    }
    if (lower.contains('profile_not_found')) {
      return 'Perfil nao encontrado para atualizar a foto.';
    }
    if (error is MissingPluginException ||
        lower.contains('missingpluginexception')) {
      return 'O seletor de ficheiros ainda nao carregou nesta sessao. Atualiza a pagina e tenta novamente.';
    }
    return 'Nao foi possivel atualizar a foto agora.';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _editMemberName() async {
    if (_updatingName) {
      return;
    }
    final controller = TextEditingController(text: _memberName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar nome'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome do membro'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName == _memberName) {
      return;
    }
    if (newName.length < 2) {
      _showMessage('Introduz um nome valido.');
      return;
    }

    setState(() => _updatingName = true);
    try {
      await SupabaseChurchRepository().updateMyProfileName(newName);
      if (!mounted) {
        return;
      }
      setState(() => _memberName = newName);
      _showMessage('Nome atualizado.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('Nao foi possivel atualizar o nome agora.');
    } finally {
      if (mounted) {
        setState(() => _updatingName = false);
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    if (_deletingAccount) return;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar conta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta acao remove o teu acesso, termina a sessao e anonimiza o perfil. Se tiveres saldo disponivel, ele sera transferido para a conta da igreja/admin antes da conta ser apagada.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Escreve APAGAR para confirmar',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Apagar conta'),
          ),
        ],
      ),
    );
    final phrase = controller.text.trim().toUpperCase();
    controller.dispose();
    if (confirmed != true) return;
    if (phrase != 'APAGAR') {
      _showMessage('Escreve APAGAR para confirmar.');
      return;
    }
    setState(() => _deletingAccount = true);
    try {
      await widget.onDeleteAccount();
    } catch (_) {
      if (!mounted) return;
      setState(() => _deletingAccount = false);
      _showMessage('Nao foi possivel apagar a conta agora.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final church = widget.church;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SectionCard(
          title: 'Perfil do membro',
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _avatarUrl != null && _avatarUrl!.isNotEmpty
                    ? CircleAvatar(
                        radius: 28,
                        backgroundImage: NetworkImage(_avatarUrl!),
                      )
                    : const CircleAvatar(
                        radius: 28,
                        child: Icon(Icons.person),
                      ),
                title: Text(_memberName),
                subtitle: Text('${member.roleLabel} - ${church.name}'),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _updatingName ? null : _editMemberName,
                    icon: _updatingName
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit_outlined),
                    label: const Text('Editar nome'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _uploadingPhoto ? null : _pickProfilePhoto,
                    icon: _uploadingPhoto
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_library_outlined),
                    label: const Text('Alterar foto'),
                  ),
                ],
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_outlined),
                title: Text(member.codeLabel),
                subtitle: const Text('Codigo do membro'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.groups_2_outlined),
                title: Text(member.ministriesLabel),
                subtitle: Text(member.ministryRoleLabel),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_outlined),
                title: Text(member.phone ?? 'Sem telefone confirmado'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(member.statusLabel),
                subtitle: const Text('Estado atual da conta na comunidade'),
              ),
              if (member.birthDateLabel != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cake_outlined),
                  title: Text(member.birthDateLabel!),
                  subtitle: const Text('Data de nascimento'),
                ),
              if (member.baptismDateLabel != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.water_drop_outlined),
                  title: Text(member.baptismDateLabel!),
                  subtitle: const Text('Data de baptismo'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionCard(
          title: 'Conta Comunhao',
          subtitle:
              'Saldo depositado usando o telefone cadastrado. Podes usar este saldo para dizimos, ofertas e campanhas.',
          child: FutureBuilder<MemberWalletSummary?>(
            future: _walletFuture,
            builder: (context, snapshot) {
              final wallet = snapshot.data;
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (wallet == null) {
                return const Text('Saldo indisponivel neste momento.');
              }
              return Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: Text(
                      formatMoney(
                        wallet.availableBalance,
                        wallet.currency,
                      ),
                    ),
                    subtitle: const Text('Saldo disponivel'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone_android_outlined),
                    title: Text(wallet.phone ?? 'Sem telefone associado'),
                    subtitle: Text('Carteira ${wallet.providerLabel}'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.savings_outlined),
                    title: Text(
                      formatMoney(wallet.totalReceived, wallet.currency),
                    ),
                    subtitle: const Text('Total depositado'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.hourglass_bottom_outlined),
                    title: Text(
                      formatMoney(wallet.pendingBalance, wallet.currency),
                    ),
                    subtitle: const Text('Saldo pendente em confirmacao'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.payments_outlined),
                    title: Text(
                      formatMoney(wallet.totalContributed, wallet.currency),
                    ),
                    subtitle: const Text('Total usado em contribuicoes'),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        SectionCard(
          title: 'Identidade digital',
          subtitle:
              'Base pronta para QR Code de acesso, check-in de eventos e validacao da conta.',
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.qr_code_2_outlined),
                        SizedBox(width: 8),
                        Text(
                          'Identidade QR-ready',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Membro: ${member.codeLabel}'),
                    const SizedBox(height: 6),
                    Text('Igreja: ${church.codeLabel}'),
                    const SizedBox(height: 6),
                    Text('Payload: ${church.slug}:${member.codeLabel}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.key_outlined),
                title: Text(church.codeLabel),
                subtitle: const Text('Codigo da igreja associado a tua conta'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text('${church.paymentChannels.length} canais ativos'),
                subtitle: const Text(
                  'Metodos disponiveis para dizimos, ofertas e campanhas',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionCard(
          title: 'Igreja atual',
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.church_outlined),
                title: Text(church.name),
                subtitle: Text(
                  church.locationLabel.isEmpty
                      ? 'Sem local definido'
                      : church.locationLabel,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.support_agent_outlined),
                title: Text(
                  church.phone ?? church.email ?? 'Sem contacto configurado',
                ),
                subtitle: const Text('Contacto principal da igreja'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.workspace_premium_outlined),
                title: Text(church.subscriptionStatusLabel),
                subtitle: Text(
                  church.subscriptionPlanCode == null
                      ? 'Plano ainda nao definido'
                      : 'Plano ${church.subscriptionPlanCode!.toUpperCase()}',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionCard(
          title: 'Preferencias',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  widget.darkMode
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                ),
                value: widget.darkMode,
                onChanged: widget.onDarkModeChanged,
                title: const Text('Modo escuro'),
                subtitle: const Text('Usar cores escuras neste app.'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _receiveNotifications,
                onChanged: (value) {
                  setState(() {
                    _receiveNotifications = value;
                  });
                  _savePreference(_notificationsKey, value);
                },
                title: const Text('Receber notificacoes'),
                subtitle: const Text(
                  'Novos eventos, mensagens e confirmacoes da igreja.',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _receiveEventAlerts,
                onChanged: (value) {
                  setState(() {
                    _receiveEventAlerts = value;
                  });
                  _savePreference(_eventsKey, value);
                },
                title: const Text('Receber avisos de eventos'),
                subtitle: const Text(
                  'Alertas de cultos, congressos, vigilias e encontros.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionCard(
          title: 'Zona de risco',
          subtitle:
              'Ao apagar, qualquer saldo disponivel sera transferido para a conta da igreja/admin. Esta acao exige confirmacao.',
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: _deletingAccount ? null : _confirmDeleteAccount,
              icon: _deletingAccount
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever_outlined),
              label: const Text('Apagar minha conta'),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SectionCard(
          title: 'Sobre',
          subtitle: 'Comunhão v1.0.0',
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline),
                title: const Text('Sobre o Comunhão'),
                subtitle: const Text('Powered by DeliGo Triunfal, Lda.'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ComunhaoAboutPage(
                        churchName: church.name,
                        churchLogoUrl: church.logoUrl,
                      ),
                    ),
                  );
                },
              ),
              const ComunhaoFooter(compact: true),
            ],
          ),
        ),
      ],
    );
  }
}
