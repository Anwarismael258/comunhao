import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> comunhaoFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  if (kIsWeb) return;
  await Firebase.initializeApp();
}

Future<void> initializeFirebasePush({required String appCode}) async {
  if (kIsWeb) return;

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(
    comunhaoFirebaseMessagingBackgroundHandler,
  );

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );
  await messaging.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  await _saveToken(appCode);
  FirebaseMessaging.instance.onTokenRefresh.listen(
    (token) => _upsertToken(appCode: appCode, token: token),
  );
  Supabase.instance.client.auth.onAuthStateChange.listen((_) {
    _saveToken(appCode);
  });
}

Future<void> _saveToken(String appCode) async {
  final token = await FirebaseMessaging.instance.getToken();
  if (token == null || token.isEmpty) return;
  await _upsertToken(appCode: appCode, token: token);
}

Future<void> _upsertToken({
  required String appCode,
  required String token,
}) async {
  final client = Supabase.instance.client;
  final profileId = client.auth.currentUser?.id;
  if (profileId == null || profileId.isEmpty) return;

  try {
    await client.from('push_device_tokens').upsert(
      {
        'profile_id': profileId,
        'app_code': appCode,
        'platform': defaultTargetPlatform.name,
        'token': token,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'token',
    );
  } catch (_) {
    // The app must keep working even before the push token migration is applied.
  }
}
