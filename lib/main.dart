import 'dart:async';

import 'package:flutter/material.dart';
import 'services/push_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'controllers/cadastro_controller.dart';
import 'controllers/entrega_provider.dart';
import 'controllers/user_provider.dart';
import 'globals/router.dart';
import 'globals/app_theme.dart';
import 'services/api_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restaura o token de sessão salvo (SharedPreferences) antes de montar o
  // app: sem isso, appRouter.redirect (ver router.dart) avaliaria a rota
  // inicial com ApiConfig.authToken ainda nulo mesmo que a pessoa já
  // estivesse logada, e ela cairia sempre na tela de boas-vindas.
  await ApiConfig.init();

  // Push/Firebase não pode bloquear a abertura do app. Em aparelhos com
  // configuração Firebase incompleta ou serviço indisponível, a tela de
  // autenticação ainda precisa aparecer normalmente.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CadastroController()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => EntregaProvider()),
      ],
      child: const MeuApp(),
    ),
  );

  unawaited(
    PushService.shared.init().catchError((Object error) {
      debugPrint('Falha ao inicializar notificações: $error');
    }),
  );
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Nhac Motoboy',
          theme: nhacTheme,
          routerConfig: appRouter,
        );
      },
    );
  }
}
