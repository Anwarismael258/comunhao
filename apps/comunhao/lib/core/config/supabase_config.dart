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

  static const churchSlug = String.fromEnvironment(
    'CHURCH_SLUG',
    defaultValue: '',
  );

  static const projectRef = String.fromEnvironment(
    'SUPABASE_PROJECT_REF',
    defaultValue: 'tpmsgvkdjzoidvyiwwfk',
  );
}
