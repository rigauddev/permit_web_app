/// Informações visíveis da versão distribuída aos usuários.
///
/// Atualize este arquivo e `version` do pubspec.yaml a cada novo lançamento.
abstract final class AppRelease {
  static const version = '1.0.2';
  static const releasedAt = '30 de setembro de 2026';
  static const title = 'Atualização disponível';
  static const description =
      'Esta versão melhora a distribuição do aplicativo e o acesso à Orla de Guaibim.';

  static const highlights = <String>[
    'Download do APK identificado com a versão do aplicativo',
    'Cadastro de veículo com tipo de veículo',
    'Consulta de acesso com resultado mais claro para fiscalização',
  ];
}
