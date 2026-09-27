import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Wrapper fino sobre o pacote geolocator.
///
/// Antes desta classe, a posição do motoboy era duas constantes fixas no
/// Marco Zero de São Paulo (EntregaProvider._latitudeAtual/_longitudeAtual) —
/// o pubspec.yaml nem tinha o pacote geolocator como dependência. Isso fazia
/// o raio de 7 km do despacho (DespachoService, backend) nunca corresponder
/// à posição real do entregador.
class LocationService {
  /// Solicita a permissão de localização e verifica se o serviço de GPS do
  /// aparelho está ligado. Deve ser chamado antes de qualquer tentativa de
  /// leitura de posição — normalmente ao entrar ONLINE.
  ///
  /// Retorna null se tudo estiver ok, ou uma mensagem pronta pra exibir ao
  /// usuário explicando por que a localização não está disponível.
  Future<String?> solicitarPermissao({bool request = true}) async {
    final servicoAtivo = await Geolocator.isLocationServiceEnabled();
    if (!servicoAtivo) {
      return 'Ative o GPS do aparelho para ficar online e receber corridas.';
    }

    LocationPermission permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied && request) {
      permissao = await Geolocator.requestPermission();
    }

    if (permissao == LocationPermission.denied) {
      return 'É preciso permitir o acesso à localização para ficar online.';
    }
    if (permissao == LocationPermission.deniedForever) {
      return 'Permissão de localização negada permanentemente. Habilite em Ajustes > Apps > Nhac Motoboy > Permissões.';
    }
    return null;
  }

  /// Uma leitura pontual de posição, com timeout curto — usada no envio
  /// imediato ao entrar online, antes do stream contínuo estabilizar.
  Future<Position?> obterPosicaoAtual() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Erro ao obter posição GPS atual: $e');
      return null;
    }
  }

  /// Stream contínuo de posições. distanceFilter evita gastar bateria/dados
  /// mandando atualização a cada centímetro — só emite quando o motoboy se
  /// move pelo menos 25 metros, o que já é mais que suficiente para o raio de
  /// despacho de quilômetros e para o polling de rota do mapa.
  Stream<Position> streamDePosicao() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      ),
    );
  }
}
