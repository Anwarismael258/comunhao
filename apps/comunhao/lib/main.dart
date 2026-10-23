import 'package:flutter/material.dart';
import 'package:comunhao_shared/comunhao_shared.dart';

import 'app/app.dart';
import 'firebase_push_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeComunhaoSupabase();
  await initializeFirebasePush(appCode: 'members');

  runApp(const ChurchApp());
}
