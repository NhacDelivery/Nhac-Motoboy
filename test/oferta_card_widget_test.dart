import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac_motoboy/components/entrega/oferta_card.dart';
import 'fixtures.dart';

void main() {
  testWidgets('oferta mostra prazo de 90 segundos e permite aceitar', (tester) async {
    var aceites = 0;
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(home: Scaffold(body: OfertaCard(
        oferta: offer(), busy: false,
        aceitar: () => aceites++, recusar: () {},
      ))),
    ));
    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator));
    expect(indicator.value, greaterThan(0));
    expect(indicator.value, lessThanOrEqualTo(1));
    await tester.tap(find.text('Aceitar corrida'));
    expect(aceites, 1);
  });
}
