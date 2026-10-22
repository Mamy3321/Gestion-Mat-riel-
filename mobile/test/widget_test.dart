import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_materiel/main.dart';

void main() {
  testWidgets('Gestion Matériel démarre', (WidgetTester tester) async {
    await tester.pumpWidget(const GestionMaterielApp());

    expect(
      find.byType(GestionMaterielApp),
      findsOneWidget,
    );
  });
}