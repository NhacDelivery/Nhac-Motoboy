import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac_motoboy/services/api_config.dart';
import 'package:nhac_motoboy/services/session_query_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('deduplica consultas, expira e respeita atualização manual', () async {
    var now = DateTime(2026);
    final cache = SessionQueryCache(clock: () => now);
    addTearDown(cache.dispose);
    var calls = 0;
    final gate = Completer<String>();
    final first = cache.load('perfil', const Duration(minutes: 1), () {
      calls++;
      return gate.future;
    });
    final second = cache.load(
      'perfil',
      const Duration(minutes: 1),
      () async => 'duplicado',
    );
    gate.complete('primeiro');
    expect(await first, 'primeiro');
    expect(await second, 'primeiro');
    expect(calls, 1);
    expect(
      await cache.load(
        'perfil',
        const Duration(minutes: 1),
        () async => 'cache ignorado',
      ),
      'primeiro',
    );
    expect(
      await cache.load(
        'perfil',
        const Duration(minutes: 1),
        () async => 'manual',
        force: true,
      ),
      'manual',
    );
    now = now.add(const Duration(minutes: 2));
    expect(cache.peek<String>('perfil'), isNull);
  });
  test(
    'troca de conta descarta cache e impede repovoamento por resposta antiga',
    () async {
      final cache = SessionQueryCache();
      addTearDown(cache.dispose);
      await ApiConfig.setAuthToken('conta-A');
      final old = Completer<String>();
      final pending = cache.load(
        'historico',
        const Duration(minutes: 1),
        () => old.future,
      );
      await ApiConfig.setAuthToken('conta-B');
      expect(
        await cache.load(
          'historico',
          const Duration(minutes: 1),
          () async => 'dados B',
        ),
        'dados B',
      );
      old.complete('dados A');
      await pending;
      expect(cache.peek<String>('historico'), 'dados B');
      await ApiConfig.limparSessao();
      expect(cache.peek<String>('historico'), isNull);
    },
  );
  test(
    'limita páginas e invalidação descarta resposta de revisão antiga',
    () async {
      final cache = SessionQueryCache(maximumSize: 2);
      addTearDown(cache.dispose);
      for (var i = 0; i < 3; i++) {
        await cache.load('$i', const Duration(minutes: 1), () async => i);
      }
      expect(cache.peek<int>('0'), isNull);
      final old = Completer<int>();
      final pending = cache.load(
        'frete',
        const Duration(minutes: 1),
        () => old.future,
      );
      cache.clear();
      old.complete(10);
      await pending;
      expect(cache.peek<int>('frete'), isNull);
    },
  );
}
