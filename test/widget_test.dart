import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permit_web_app/main.dart';

void main() {
  testWidgets('mostra tela de login', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    expect(find.text('Escolha o tipo de acesso'), findsOneWidget);
    expect(find.text('Cidadão'), findsOneWidget);
    expect(find.text('Prefeitura'), findsOneWidget);

    await tester.tap(find.text('Cidadão'));
    await tester.pumpAndSettle();

    expect(find.text('Acesso ao sistema'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
