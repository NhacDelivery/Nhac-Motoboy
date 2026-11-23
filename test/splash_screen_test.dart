import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:nhac_motoboy/globals/router.dart';
import 'package:nhac_motoboy/pages/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SplashScreen', () {
    testWidgets('renderiza com fundo #FFE7E5 e Lottie da intro', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsOneWidget);
      final scaffold = tester.widget<Scaffold>(scaffoldFinder);
      expect(scaffold.backgroundColor, const Color(0xFFFFE7E5));

      final lottieFinder = find.byType(Lottie);
      expect(lottieFinder, findsOneWidget);
      final lottie = tester.widget<Lottie>(lottieFinder);
      expect(lottie.composition, isNull); // antes de carregar
    });

    test('appRouter inicia com initialLocation /splash', () {
      expect(appRouter.routeInformationProvider.value.uri.path, '/splash');
    });
  });
}
