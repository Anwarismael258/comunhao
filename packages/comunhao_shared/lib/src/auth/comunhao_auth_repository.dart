import 'package:supabase_flutter/supabase_flutter.dart';

abstract class ComunhaoAuthRepository {
  Stream<AuthState> get authStateChanges;
  Session? get currentSession;
  User? get currentUser;

  Future<AuthResponse> signUpWithPhone({
    required String fullName,
    required String phone,
    required String password,
    String? birthDate,
    Map<String, dynamic> metadata,
  });

  Future<AuthResponse> signInWithPhone({
    required String phone,
    required String password,
  });

  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  });

  Future<void> resendPhoneOtp({
    required String phone,
  });

  Future<void> deleteAccount();

  Future<void> signOut();
}

class SupabaseComunhaoAuthRepository implements ComunhaoAuthRepository {
  SupabaseComunhaoAuthRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final Map<String, String> _pendingPasswords = <String, String>{};

  List<String> _phoneCandidates(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return <String>{
      phone.trim(),
      if (digits.isNotEmpty) digits,
      if (digits.isNotEmpty) '+$digits',
    }.where((value) => value.isNotEmpty).toList(growable: false);
  }

  void _rememberPassword(String phone, String password) {
    for (final candidate in _phoneCandidates(phone)) {
      _pendingPasswords[candidate] = password;
    }
  }

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  Session? get currentSession => _client.auth.currentSession;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Future<AuthResponse> signUpWithPhone({
    required String fullName,
    required String phone,
    required String password,
    String? birthDate,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _client.rpc(
      'register_phone_auth_user',
      params: {
        'p_full_name': fullName,
        'p_phone': phone,
        'p_password': password,
        'p_birth_date':
            birthDate == null || birthDate.isEmpty ? null : birthDate,
        'p_metadata': metadata,
      },
    );
    _rememberPassword(phone, password);
    return AuthResponse();
  }

  @override
  Future<AuthResponse> signInWithPhone({
    required String phone,
    required String password,
  }) async {
    _rememberPassword(phone, password);
    Object? lastError;
    for (final candidate in _phoneCandidates(phone)) {
      try {
        return await _client.auth.signInWithPassword(
          phone: candidate,
          password: password,
        );
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ??
        const AuthException('Telefone ou palavra-passe invalida.');
  }

  @override
  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    await _client.rpc(
      'verify_phone_auth_otp',
      params: {
        'p_phone': phone,
        'p_token': token,
      },
    );

    String? password;
    for (final candidate in _phoneCandidates(phone)) {
      password ??= _pendingPasswords[candidate];
    }
    if (password == null || password.isEmpty) {
      throw const AuthException(
        'Numero confirmado com sucesso. Volta a entrar com o teu numero e palavra-passe.',
        code: 'phone_password_required',
      );
    }

    Object? lastError;
    for (final candidate in _phoneCandidates(phone)) {
      try {
        final response = await _client.auth.signInWithPassword(
          phone: candidate,
          password: password,
        );
        for (final key in _phoneCandidates(phone)) {
          _pendingPasswords.remove(key);
        }
        return response;
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ??
        const AuthException('Telefone ou palavra-passe invalida.');
  }

  @override
  Future<void> resendPhoneOtp({
    required String phone,
  }) async {
    await _client.rpc(
      'request_phone_auth_otp',
      params: {
        'p_phone': phone,
        'p_purpose': 'signup',
      },
    );
  }

  @override
  Future<void> deleteAccount() async {
    await _client.rpc('delete_my_account');
    _pendingPasswords.clear();
    await _client.auth.signOut();
  }

  @override
  Future<void> signOut() {
    _pendingPasswords.clear();
    return _client.auth.signOut();
  }
}
