import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permit_web_app/core/orla_api_service.dart';
import 'package:permit_web_app/presentation/pages/orla_page.dart';

class FakeOrlaApi extends OrlaApiService {
  FakeOrlaApi({this.staff = false, this.manager = false, this.full = false});
  final bool staff;
  final bool manager;
  final bool full;
  @override
  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    if (path == '/me') {
      return {
        'is_staff': staff,
        'can_manage': manager,
        'vehicle_limit': 2,
        'vehicles':
            full
                ? List.generate(
                  2,
                  (i) => {
                    'id': i,
                    'plate': 'ABC123$i',
                    'brand': 'Fiat',
                    'model': 'Uno',
                    'color': 'Branco',
                    'inside': false,
                    'authorized': true,
                  },
                )
                : [],
        'responsible_secretarias': ['DMTRAN', 'Guarda Municipal'],
      };
    }
    if (path.startsWith('/users')) {
      return [
        {'id': 1, 'name': 'Maria', 'vehicle_limit': 2, 'vehicles': []},
      ];
    }
    throw StateError('Unexpected request: $method $path');
  }
}

void main() {
  testWidgets('cidadão vê cadastro e não vê fiscalização', (tester) async {
    await tester.pumpWidget(MaterialApp(home: OrlaPage(api: FakeOrlaApi())));
    await tester.pumpAndSettle();
    expect(find.text('0 de 2 veículos cadastrados'), findsOneWidget);
    expect(find.text('Cadastrar veículo'), findsOneWidget);
    expect(find.text('Escanear QR Code'), findsNothing);
    expect(find.text('Alterar limite'), findsNothing);
    await tester.tap(find.text('Cadastrar veículo'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar cadastro permanente'), findsOneWidget);
    await tester.tap(find.text('Confirmar cadastro permanente'));
    await tester.pumpAndSettle();
    expect(find.text('Placa inválida'), findsOneWidget);
    expect(find.text('Informe a marca'), findsOneWidget);
    expect(find.text('Informe o modelo'), findsOneWidget);
    expect(find.text('Informe a cor'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
  });
  testWidgets('limite atingido desabilita cadastro', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OrlaPage(api: FakeOrlaApi(full: true))),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Cadastrar veículo'),
    );
    expect(button.onPressed, isNull);
  });
  testWidgets('operador tem consulta e scanner sem alteração de limite', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: OrlaPage(api: FakeOrlaApi(staff: true))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('Escanear QR Code'), findsOneWidget);
    expect(find.text('Consultar placa'), findsOneWidget);
    expect(find.text('Alterar limite'), findsNothing);
    expect(find.text('Cadastrar veículo'), findsNothing);
  });
  testWidgets('gestor da fiscalização pode ajustar limite', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OrlaPage(api: FakeOrlaApi(staff: true, manager: true))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alterar limite'), findsOneWidget);
  });
}
