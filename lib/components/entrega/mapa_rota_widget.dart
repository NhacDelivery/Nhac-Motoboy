import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../globals/theme_colors.dart';
import '../../models/rota_model.dart';

class MapaRotaWidget extends StatelessWidget {
  final RotaModel rota;
  final double? latitude, longitude;
  const MapaRotaWidget({super.key, required this.rota, this.latitude, this.longitude});
  @override
  Widget build(BuildContext context) {
    final origem = LatLng(rota.origem.latitude, rota.origem.longitude);
    final destino = LatLng(rota.destino.latitude, rota.destino.longitude);
    final points = rota.waypoints.map((p) => LatLng(p.latitude, p.longitude)).toList();
    return SizedBox(height: 340, child: FlutterMap(
      key: ValueKey(rota.pedidoId),
      options: MapOptions(initialCameraFit: CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([origem, destino]), padding: const EdgeInsets.all(48), maxZoom: 16)),
      children: [
        if (!const bool.fromEnvironment('E2E_MODE'))
          TileLayer(urlTemplate: const String.fromEnvironment('MAP_TILE_URL',
            defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
            userAgentPackageName: 'br.com.nhac.motoboy', maxNativeZoom: 19),
        if (points.isNotEmpty) PolylineLayer(polylines: [
          Polyline(points: points, color: AppColors.primaria, strokeWidth: 5),
        ]),
        MarkerLayer(markers: [
          Marker(point: origem, child: Tooltip(message: 'Loja', child: Icon(Icons.store, color: AppColors.primaria, size: 36))),
          Marker(point: destino, child: Tooltip(message: 'Cliente', child: Icon(Icons.location_on, color: AppColors.texto, size: 36))),
          if (latitude != null && longitude != null)
            Marker(point: LatLng(latitude!, longitude!), child: Tooltip(message: 'Você', child: Icon(Icons.my_location, color: AppColors.desabilitado, size: 28))),
        ]),
        RichAttributionWidget(attributions: [
          TextSourceAttribution('OpenStreetMap contributors', onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'))),
        ]),
      ],
    ));
  }
}