import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:comunhao_shared/comunhao_shared.dart'
    show ComunhaoFooter, LegalDocumentsPage;

import '../../../core/utils/phone_utils.dart';
import '../../auth/data/auth_repository.dart';
import '../../church/data/church_repository.dart';
import '../../church/models/church_branding.dart';

enum _AuthStage { chooseChurch, credentials, otp }

enum _AuthMode { signup, login }

class AuthFlowPage extends StatefulWidget {
  const AuthFlowPage({
    required this.churchRepository,
    required this.authRepository,
    required this.onChurchSelected,
    this.selectedChurch,
    super.key,
  });

  final ChurchRepository churchRepository;
  final AuthRepository authRepository;
  final ChurchBranding? selectedChurch;
  final ValueChanged<ChurchBranding> onChurchSelected;

  @override
  State<AuthFlowPage> createState() => _AuthFlowPageState();
}

class _AuthFlowPageState extends State<AuthFlowPage> {
  final _searchController = TextEditingController();
  final _codeController = TextEditingController();
  final _signupNameController = TextEditingController();
  final _signupPhoneController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupConfirmPasswordController = TextEditingController();
  final _loginPhoneController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  final _birthDateController = TextEditingController();

  final _signupFormKey = GlobalKey<FormState>();
  final _loginFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  late Future<List<ChurchBranding>> _churchesFuture;

  _AuthStage _stage = _AuthStage.chooseChurch;
  _AuthMode _mode = _AuthMode.signup;
  ChurchBranding? _activeChurch;
  String? _pendingPhone;
  bool _busy = false;
  bool _showLoginPassword = false;
  bool _showSignupPassword = false;

  @override
  void initState() {
    super.initState();
    _activeChurch = widget.selectedChurch;
    // The first member screen must always be church discovery.  After the
    // member chooses a church, the existing account/create-account form is
    // shown for that church.
    _stage = _activeChurch == null
        ? _AuthStage.chooseChurch
        : _AuthStage.credentials;
    _churchesFuture = widget.churchRepository.fetchChurches();
  }

  @override
  void didUpdateWidget(covariant AuthFlowPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedChurch?.id != oldWidget.selectedChurch?.id) {
      _activeChurch = widget.selectedChurch;
      if (_pendingPhone == null) {
        _stage = _activeChurch == null
            ? _AuthStage.chooseChurch
            : _AuthStage.credentials;
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _codeController.dispose();
    _signupNameController.dispose();
    _signupPhoneController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    _loginPhoneController.dispose();
    _loginPasswordController.dispose();
    _otpController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  List<ChurchBranding> _filterChurches(List<ChurchBranding> churches) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return churches;
    }

    return churches.where((church) {
      return church.name.toLowerCase().contains(query) ||
          church.slug.toLowerCase().contains(query) ||
          church.codeLabel.toLowerCase().contains(query) ||
          church.locationLabel.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _selectChurch(ChurchBranding church) async {
    widget.onChurchSelected(church);
    setState(() {
      _activeChurch = church;
      _stage = _AuthStage.credentials;
      _mode = _AuthMode.signup;
      _pendingPhone = null;
      _otpController.clear();
    });
  }

  Future<void> _chooseBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(1930),
      lastDate: DateTime(now.year - 8),
    );

    if (picked != null) {
      _birthDateController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _lookupCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showMessage('Introduz o codigo da igreja.');
      return;
    }

    setState(() => _busy = true);
    try {
      final church = await widget.churchRepository.fetchChurchByCode(code);
      if (!mounted) return;
      if (church == null) {
        _showMessage('Nao encontrei nenhuma igreja com esse codigo.');
      } else {
        Navigator.of(context).pop();
        await _selectChurch(church);
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _submitSignup() async {
    if (!_signupFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _busy = true);
    try {
      final normalizedPhone = normalizePhone(_signupPhoneController.text);
      final response = await widget.authRepository.signUpWithPhone(
        fullName: _signupNameController.text.trim(),
        phone: normalizedPhone,
        password: _signupPasswordController.text,
        birthDate: _birthDateController.text.trim().isEmpty
            ? null
            : _birthDateController.text.trim(),
      );

      if (!mounted) return;

      if (response.session != null) {
        _showMessage('Conta criada e autenticada com sucesso.');
        return;
      }

      setState(() {
        _pendingPhone = normalizedPhone;
        _stage = _AuthStage.otp;
      });
      _showMessage(
          'Enviamos um codigo SMS para ${maskPhone(normalizedPhone)}.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _busy = true);
    try {
      final normalizedPhone = normalizePhone(_loginPhoneController.text);
      await widget.authRepository.signInWithPhone(
        phone: normalizedPhone,
        password: _loginPasswordController.text,
      );
    } catch (error) {
      if (!mounted) return;

      final message = _friendlyError(error);
      if (message.toLowerCase().contains('phone_not_confirmed') ||
          message.toLowerCase().contains('phone not confirmed')) {
        setState(() {
          _pendingPhone = normalizePhone(_loginPhoneController.text);
          _stage = _AuthStage.otp;
        });
      }
      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (!_otpFormKey.currentState!.validate() || _pendingPhone == null) {
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.authRepository.verifyPhoneOtp(
        phone: _pendingPhone!,
        token: _otpController.text.trim(),
      );
      if (!mounted) return;
      _showMessage('Numero confirmado com sucesso.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_pendingPhone == null) {
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.authRepository.resendPhoneOtp(phone: _pendingPhone!);
      if (!mounted) return;
      _showMessage('Codigo reenviado para ${maskPhone(_pendingPhone!)}.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _scanChurchQr() async {
    final code = await showDialog<String>(
      context: context,
      builder: (context) => const _ChurchQrScannerDialog(),
    );
    if (!mounted || code == null || code.trim().isEmpty) return;

    _codeController.text = code.trim();
    await _lookupCode();
  }

  void _showCodeDialog() {
    _codeController.clear();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Introduzir codigo da igreja'),
        content: TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Codigo da igreja',
            hintText: 'Ex: VIDA123',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _busy ? null : _lookupCode,
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  void _openLegalDocuments() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LegalDocumentsPage(),
      ),
    );
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('phone_provider_disabled')) {
      return 'O provedor de SMS ainda nao esta configurado no Supabase. Liga um provider de SMS para enviar OTP.';
    }
    if (lower.contains('sms_send_failed')) {
      return 'Nao foi possivel enviar o SMS agora. Tenta novamente.';
    }
    if (lower.contains('otp_expired') || lower.contains('token has expired')) {
      return 'O codigo expirou. Pede um novo SMS.';
    }
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials')) {
      return 'Nao foi possivel entrar: confirma o telefone e a palavra-passe. Se acabaste de criar a conta, confirma primeiro o codigo OTP.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('ja existe uma conta com este numero')) {
      return 'Este numero ja esta registado. Usa a opcao Entrar com a palavra-passe original; nao e possivel criar uma segunda conta com o mesmo telefone.';
    }
    if (lower.contains('numero de telefone invalido')) {
      return 'O numero de telefone nao e valido. Usa um numero mocambicano com 9 digitos, por exemplo 84xxxxxxx ou 87xxxxxxx.';
    }
    if (lower.contains('palavra-passe deve ter pelo menos 6')) {
      return 'A palavra-passe precisa de pelo menos 6 caracteres.';
    }
    if (lower.contains('codigo otp invalido')) {
      return 'O codigo OTP nao confere. Verifica os 6 digitos ou pede um novo codigo.';
    }
    if (lower.contains('nenhum codigo ativo')) {
      return 'Nao existe um OTP ativo para este numero. Pede um novo codigo e introduz o mais recente.';
    }
    if (lower.contains('postgrestexception') || lower.contains('pgrst')) {
      return 'A conta foi recebida, mas os dados da igreja nao puderam ser carregados. Atualiza a pagina; se continuar, a equipa precisa sincronizar o cadastro desta conta.';
    }
    return raw.replaceFirst('AuthException(message: ', '').replaceAll(')', '');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF07265A), Color(0xFFFBF7EC), Color(0xFFFFFDF8)],
            stops: [0, .24, 1],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: switch (_stage) {
                        _AuthStage.chooseChurch => _buildChooseChurch(),
                        _AuthStage.credentials => _buildCredentials(),
                        _AuthStage.otp => _buildOtpVerification(),
                      },
                    ),
                  ),
                ),
              ),
            ),
            if (_busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x55000000),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChooseChurch() {
    return FutureBuilder<List<ChurchBranding>>(
      future: _churchesFuture,
      builder: (context, snapshot) {
        final churches = snapshot.data ?? const <ChurchBranding>[];
        final filteredChurches = _filterChurches(churches);

        return ListView(
          key: const ValueKey('choose-church'),
          shrinkWrap: true,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Image.asset(
                'assets/branding/comunhao.png',
                height: 110,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Bem-vindo à Comunhao',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Escolha a sua igreja',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Pesquisar igreja',
              ),
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState != ConnectionState.done)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError)
              _InfoCard(
                title: 'Nao foi possivel carregar as igrejas',
                body: _friendlyError(snapshot.error!),
              )
            else ...[
              if (filteredChurches.isEmpty)
                const _InfoCard(
                  title: 'Nenhuma igreja encontrada',
                  body:
                      'Tenta outro nome, usa o codigo da igreja ou liga o QR Code numa proxima versao.',
                )
              else
                ...filteredChurches.map(
                  (church) => Card(
                    child: ListTile(
                      onTap: () => _selectChurch(church),
                      leading: _ChurchSearchAvatar(church: church),
                      title: Text(
                        church.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          if (church.locationLabel.isNotEmpty)
                            church.locationLabel,
                          'Codigo: ${church.codeLabel}',
                          '${church.activeMemberCount} membro(s) ativo(s)',
                        ].join(' • '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            const Center(child: Text('ou')),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : _scanChurchQr,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Ler QR Code'),
            ),
            const SizedBox(height: 12),
            const Center(child: Text('ou')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showCodeDialog,
              icon: const Icon(Icons.key_outlined),
              label: const Text('Introduzir código da igreja'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _openLegalDocuments,
              icon: const Icon(Icons.privacy_tip_outlined),
              label: const Text('Termos e privacidade'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCredentials() {
    return ListView(
      key: const ValueKey('credentials'),
      shrinkWrap: true,
      children: [
        const SizedBox(height: 12),
        const Text('Powered by DeliGo Triunfal, Lda.',
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Center(child: Image.asset('assets/branding/comunhao.png', height: 104)),
        const SizedBox(height: 12),
        Text('Bem-vindo ao Comunhao',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900, color: const Color(0xFF082A62))),
        const SizedBox(height: 6),
        const Text('Conecte-se a sua igreja e fortaleça a sua fé',
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .94),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFF123979), width: 1.4),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x26082A62),
                  blurRadius: 22,
                  offset: Offset(0, 10))
            ],
          ),
          child: Column(children: [
            SegmentedButton<_AuthMode>(
              segments: const [
                ButtonSegment<_AuthMode>(
                    value: _AuthMode.login, label: Text('Entrar')),
                ButtonSegment<_AuthMode>(
                    value: _AuthMode.signup, label: Text('Criar conta')),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) =>
                  setState(() => _mode = selection.first),
            ),
            const SizedBox(height: 20),
            if (_mode == _AuthMode.signup)
              _buildSignupForm()
            else
              _buildLoginForm(),
          ]),
        ),
        const SizedBox(height: 18),
        Center(
            child: TextButton.icon(
          onPressed: _openLegalDocuments,
          icon: const Icon(Icons.shield_outlined, color: Color(0xFFC98918)),
          label: const Text('Acesso seguro • Conta Triunfal'),
        )),
        const ComunhaoFooter(compact: true),
      ],
    );
  }

  Widget _buildSignupForm() {
    return Form(
      key: _signupFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nome Completo'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _signupNameController,
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.trim().length < 5) {
                return 'Introduz o nome completo.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          const Text('Número de Telefone'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _signupPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '+258 84 123 4567'),
            validator: (value) {
              try {
                normalizePhone(value ?? '');
                return null;
              } catch (error) {
                return error.toString().replaceFirst('FormatException: ', '');
              }
            },
          ),
          const SizedBox(height: 16),
          const Text('Palavra-passe'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _signupPasswordController,
            obscureText: !_showSignupPassword,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline),
              hintText: 'Crie a sua palavra-passe',
              suffixIcon: IconButton(
                icon: Icon(_showSignupPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () =>
                    setState(() => _showSignupPassword = !_showSignupPassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.length < 6) {
                return 'A palavra-passe deve ter pelo menos 6 caracteres.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          const Text('Confirmar Palavra-passe'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _signupConfirmPasswordController,
            obscureText: !_showSignupPassword,
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.lock_outline),
                hintText: 'Confirme a palavra-passe'),
            validator: (value) {
              if (value != _signupPasswordController.text) {
                return 'As palavras-passe nao coincidem.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          const Text('Data de nascimento (opcional)'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _birthDateController,
            readOnly: true,
            onTap: _chooseBirthDate,
            decoration: const InputDecoration(
              hintText: 'AAAA-MM-DD',
              suffixIcon: Icon(Icons.calendar_month_outlined),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submitSignup,
              child: const Text('CRIAR CONTA'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sem email. A conta sera confirmada por SMS. Depois, escolha como deseja comecar no Comunhao.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Número de Telefone'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _loginPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '+258 84 123 4567'),
            validator: (value) {
              try {
                normalizePhone(value ?? '');
                return null;
              } catch (error) {
                return error.toString().replaceFirst('FormatException: ', '');
              }
            },
          ),
          const SizedBox(height: 16),
          const Text('Palavra-passe'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _loginPasswordController,
            obscureText: !_showLoginPassword,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline),
              hintText: 'Digite a sua palavra-passe',
              suffixIcon: IconButton(
                icon: Icon(_showLoginPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () =>
                    setState(() => _showLoginPassword = !_showLoginPassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Introduz a palavra-passe.';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submitLogin,
              child: const Text('ENTRAR COMO MEMBRO'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpVerification() {
    final church = _activeChurch;
    return ListView(
      key: const ValueKey('otp'),
      shrinkWrap: true,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() {
                  _stage = _AuthStage.credentials;
                  _otpController.clear();
                });
              },
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Text(
                church?.name ?? 'Verificar telefone',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Introduz o codigo SMS enviado para ${_pendingPhone == null ? '' : maskPhone(_pendingPhone!)}.',
        ),
        const SizedBox(height: 20),
        Form(
          key: _otpFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Código SMS'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().length < 6) {
                    return 'Introduz o codigo de 6 digitos.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _verifyOtp,
                  child: const Text('CONFIRMAR NÚMERO'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _busy ? null : _resendOtp,
                  child: const Text('REENVIAR CÓDIGO'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChurchQrScannerDialog extends StatefulWidget {
  const _ChurchQrScannerDialog();

  @override
  State<_ChurchQrScannerDialog> createState() => _ChurchQrScannerDialogState();
}

class _ChurchQrScannerDialogState extends State<_ChurchQrScannerDialog> {
  bool _handled = false;

  void _handleCapture(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .whereType<String>()
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (value.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ler QR Code da igreja'),
      content: SizedBox(
        width: 420,
        height: 320,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: MobileScanner(onDetect: _handleCapture),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

class _ChurchSearchAvatar extends StatelessWidget {
  const _ChurchSearchAvatar({required this.church});

  final ChurchBranding church;

  @override
  Widget build(BuildContext context) {
    final logo = church.logoUrl?.trim();
    final initial = church.name.trim().isEmpty
        ? 'I'
        : church.name.trim().characters.first.toUpperCase();
    if (logo == null || logo.isEmpty) {
      return CircleAvatar(child: Text(initial));
    }
    if (logo.startsWith('assets/')) {
      return CircleAvatar(backgroundImage: AssetImage(logo));
    }
    return CircleAvatar(
      backgroundImage: NetworkImage(logo),
      onBackgroundImageError: (_, __) {},
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }
}
