class SupabaseConfig {
  static const environment = String.fromEnvironment(
    'COMUNHAO_ENV',
    defaultValue: 'production',
  );

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://tpmsgvkdjzoidvyiwwfk.supabase.co',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_VPBqfA_NVrvTs3fRqA49iw_NdOhXRTC',
  );

  static const schema = 'comunhao';

  static const churchSlug = String.fromEnvironment(
    'CHURCH_SLUG',
    defaultValue: '',
  );

  static const projectRef = String.fromEnvironment(
    'SUPABASE_PROJECT_REF',
    defaultValue: 'tpmsgvkdjzoidvyiwwfk',
  );

  static const allowStagingProductionUrl = bool.fromEnvironment(
    'COMUNHAO_ALLOW_STAGING_PRODUCTION_URL',
    defaultValue: false,
  );

  static bool get isProduction => environment == 'production';
  static bool get isStaging => environment == 'staging';
  static bool get isDevelopment => environment == 'development';

  static String get maskedProjectRef {
    if (projectRef.length <= 8) {
      return projectRef;
    }
    return '${projectRef.substring(0, 4)}...${projectRef.substring(projectRef.length - 4)}';
  }

  static void validateEnvironment() {
    if (url.trim().isEmpty || publishableKey.trim().isEmpty) {
      throw StateError(
          'Supabase URL e publishable key devem estar configurados.');
    }

    final normalizedEnv = environment.trim().toLowerCase();
    if (!const {'development', 'staging', 'production'}
        .contains(normalizedEnv)) {
      throw StateError('COMUNHAO_ENV invalido: $environment.');
    }

    if (normalizedEnv == 'staging' &&
        !allowStagingProductionUrl &&
        url.contains('dxofxuajsrocbxdmekfx.supabase.co')) {
      throw StateError(
        'Build de staging bloqueado: SUPABASE_URL aponta para o backend de producao conhecido.',
      );
    }
  }
}
