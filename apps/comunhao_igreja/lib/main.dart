import 'package:flutter/widgets.dart';
import 'package:comunhao_shared/comunhao_shared.dart';

import 'church_admin_app.dart';
import 'firebase_push_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeComunhaoSupabase();
  await initializeFirebasePush(appCode: 'church');
  runApp(const ChurchAdminApp());
}
