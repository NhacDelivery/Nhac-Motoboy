import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../services/api_config.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    );

    _animationController.forward().then((_) {
      Future.delayed(const Duration(seconds: 1), () async {
        if (!mounted) return;
        if (ApiConfig.temSessaoSalva) {
          context.go('/home-motoca');
        } else {
          context.go('/');
        }
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE7E5),
      body: Center(
        child: Lottie.asset(
          'assets/animations/nhac-intro.json',
          controller: _animationController,
          onLoaded: (composition) {
            _animationController.duration = composition.duration * 0.4;
          },
        ),
      ),
    );
  }
}
