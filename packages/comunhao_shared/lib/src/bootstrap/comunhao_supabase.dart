import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

Future<void> initializeComunhaoSupabase() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseConfig.validateEnvironment();

  try {
    Supabase.instance.client;
    return;
  } catch (_) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      postgrestOptions: const PostgrestClientOptions(
        schema: SupabaseConfig.schema,
      ),
    );
  }
}
