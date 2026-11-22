// Clima de los próximos 7 días con Open-Meteo (gratis, sin cuenta ni clave).
// Sin conexión se muestra el último pronóstico guardado.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'datos.dart';
import 'estilo.dart';

/// Ciudad candidata de la búsqueda.
typedef Ciudad = ({String nombre, String detalle, double lat, double lon});

Future<Map<String, dynamic>> _json(Uri uri) async {
  final cliente = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final r = await (await cliente.getUrl(uri)).close();
    if (r.statusCode != 200) throw 'Open-Meteo respondió ${r.statusCode}';
    return jsonDecode(await r.transform(utf8.decoder).join()) as Map<String, dynamic>;
  } finally {
    cliente.close();
  }
}

List<Ciudad> parsearCiudades(Map<String, dynamic> j) => [
  for (final c in (j['results'] as List? ?? []).cast<Map<String, dynamic>>())
    (
      nombre: c['name'] as String,
      detalle: [c['admin1'], c['country']].whereType<String>().join(', '),
      lat: (c['latitude'] as num).toDouble(),
      lon: (c['longitude'] as num).toDouble(),
    ),
];

Future<List<Ciudad>> buscarCiudades(String nombre) async =>
    parsearCiudades(await _json(Uri.https('geocoding-api.open-meteo.com', '/v1/search', {'name': nombre.trim(), 'count': '6', 'language': 'es'})));

/// "2026-11-22" → [código WMO, máxima, mínima].
Map<String, List<num>> parsearPronostico(Map<String, dynamic> j) {
  final d = j['daily'] as Map<String, dynamic>;
  final dias = (d['time'] as List).cast<String>();
  return {
    for (var i = 0; i < dias.length; i++)
      if (d['weather_code'][i] != null) dias[i]: [d['weather_code'][i] as num, d['temperature_2m_max'][i] as num, d['temperature_2m_min'][i] as num],
  };
}

/// Pide el pronóstico si hay ciudad y el guardado tiene más de 3 horas (o [forzar]). Sin internet deja el anterior.
DateTime? _fallo;

Future<String?> actualizarClima({bool forzar = false}) async {
  final c = ciudad.value;
  if (c == null) return null;
  final ultima = climaActualizado == null ? null : DateTime.tryParse(climaActualizado!);
  if (!forzar && ultima != null && DateTime.now().difference(ultima) < const Duration(hours: 3)) return null;
  if (!forzar && _fallo != null && DateTime.now().difference(_fallo!) < const Duration(minutes: 15)) return null; // sin internet: no reintentar cada 30 s
  try {
    final j = await _json(
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '${c['lat']}',
        'longitude': '${c['lon']}',
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
        'timezone': 'auto',
        'forecast_days': '7',
      }),
    );
    clima.value = parsearPronostico(j);
    _fallo = null;
    climaActualizado = DateTime.now().toIso8601String();
    await guardar();
    return null;
  } catch (e) {
    _fallo = DateTime.now();
    return 'No se pudo actualizar el clima: $e';
  }
}

/// Códigos WMO de Open-Meteo → ícono y palabra.
(IconData, String) aspecto(int codigo) => switch (codigo) {
  0 || 1 => (Icons.wb_sunny_outlined, 'Soleado'),
  2 => (Icons.filter_drama_outlined, 'Parcialmente nublado'),
  3 => (Icons.cloud_outlined, 'Nublado'),
  45 || 48 => (Icons.foggy, 'Niebla'),
  >= 51 && <= 67 || >= 80 && <= 82 => (Icons.water_drop_outlined, 'Lluvia'),
  >= 71 && <= 77 || 85 || 86 => (Icons.ac_unit, 'Nieve'),
  >= 95 => (Icons.thunderstorm_outlined, 'Tormenta'),
  _ => (Icons.cloud_outlined, 'Nublado'),
};

/// "26° / 15°"
String temperaturas(List<num> c) => '${c[1].round()}° / ${c[2].round()}°';

/// Diálogo para elegir la ciudad: se escribe, Enter busca, un clic elige.
Future<Ciudad?> elegirCiudad(BuildContext context) => showDialog<Ciudad>(context: context, builder: (_) => const _ElegirCiudad());

class _ElegirCiudad extends StatefulWidget {
  const _ElegirCiudad();
  @override
  State<_ElegirCiudad> createState() => _ElegirCiudadState();
}

class _ElegirCiudadState extends State<_ElegirCiudad> {
  List<Ciudad>? encontradas;
  String? error;
  var buscando = false;

  Future<void> buscar(String nombre) async {
    if (nombre.trim().isEmpty) return;
    setState(() => buscando = true);
    try {
      final l = await buscarCiudades(nombre);
      if (!mounted) return;
      setState(() {
        encontradas = l;
        error = l.isEmpty ? 'No encontré "${nombre.trim()}".' : null;
      });
    } catch (e) {
      if (mounted) setState(() => error = 'Sin conexión para buscar ciudades.');
    } finally {
      if (mounted) setState(() => buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    return Dialog(
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.line),
      ),
      child: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  icon: buscando
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.muted))
                      : Icon(Icons.search, size: 18, color: p.muted),
                  hintText: 'Tu ciudad y Enter…',
                  hintStyle: TextStyle(color: p.muted),
                ),
                onSubmitted: buscar,
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Text(error!, style: TextStyle(color: p.muted)),
              ),
            for (final c in encontradas ?? <Ciudad>[])
              InkWell(
                onTap: () => Navigator.pop(context, c),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  child: Row(
                    children: [
                      Text(c.nombre),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.detalle,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: p.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (encontradas?.isNotEmpty ?? false) const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
