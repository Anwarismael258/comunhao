import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:comunhao/app/app.dart';
import 'package:comunhao/features/auth/data/auth_repository.dart';
import 'package:comunhao/features/church/data/church_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the configured church authentication shell', (tester) async {
    await tester.pumpWidget(
      ChurchApp(
        churchRepository: DemoChurchRepository(),
        authRepository: DemoAuthRepository(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bem-vindo'), findsWidgets);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Criar conta'), findsOneWidget);
  });
}
