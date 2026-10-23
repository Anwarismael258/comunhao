enum ComunhaoSurface { member, churchAdmin, superAdmin }

extension ComunhaoSurfaceX on ComunhaoSurface {
  String get appName => switch (this) {
        ComunhaoSurface.member => 'Comunhao',
        ComunhaoSurface.churchAdmin => 'Comunhao Igreja',
        ComunhaoSurface.superAdmin => 'Comunhao Super Admin',
      };

  String get audienceLabel => switch (this) {
        ComunhaoSurface.member => 'Membros',
        ComunhaoSurface.churchAdmin => 'Pastores e administradores',
        ComunhaoSurface.superAdmin => 'Equipa central',
      };

  String get summary => switch (this) {
        ComunhaoSurface.member =>
          'Entrada por igreja, comunidade, doacoes e eventos.',
        ComunhaoSurface.churchAdmin =>
          'Registro da igreja, operacao local, membros e pagamentos.',
        ComunhaoSurface.superAdmin =>
          'Aprovacao de igrejas, governanca da plataforma e suporte.',
      };
}
