import 'package:flutter_test/flutter_test.dart';

import 'package:comunhao_shared/comunhao_shared.dart';

void main() {
  test('surface metadata stays stable', () {
    expect(ComunhaoSurface.member.appName, 'Comunhao');
    expect(ComunhaoSurface.superAdmin.audienceLabel, 'Equipa central');
  });
}
