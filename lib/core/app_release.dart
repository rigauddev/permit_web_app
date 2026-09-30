/// Informações visíveis da versão distribuída aos usuários.
///
/// Atualize este arquivo e `version` do pubspec.yaml a cada novo lançamento.
abstract final class AppRelease {
  static const version = '1.0.4';
  static const releasedAt = '30 de setembro de 2026';
  static const title = 'Atualização disponível';
  static const description =
      'A nova versão melhora a fiscalização e o acesso à Orla de Guaibim.';

  static const highlights = <String>[
    'Leitura de placa orientada para carro e motocicleta',
    'Cadastro de veículo com tipo de veículo',
    'Consulta de acesso com resultado mais claro para fiscalização',
  ];
}
