import 'dart:io';

import 'package:agenda/clima.dart';
import 'package:agenda/datos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pronóstico de Open-Meteo', () {
    final p = parsearPronostico({
      'daily': {
        'time': ['2026-11-22', '2026-11-23', '2026-11-24'],
        'weather_code': [3, 61, null], // sin dato: ese día no se muestra
        'temperature_2m_max': [13.6, 9.1, null],
        'temperature_2m_min': [7.1, 5.0, null],
      },
    });
    expect(p.keys, ['2026-11-22', '2026-11-23']);
    expect([temperaturas(p['2026-11-22']!), aspecto(p['2026-11-23']![0].toInt()).$2], ['14° / 7°', 'Lluvia']);
  });

  test('ciudades homónimas con provincia y país', () {
    final c = parsearCiudades({
      'results': [
        {'name': 'Madrid', 'admin1': 'Comunidad Autónoma de Madrid', 'country': 'España', 'latitude': 40.4165, 'longitude': -3.70256},
        {'name': 'Madrid', 'country': 'Colombia', 'latitude': 4.73, 'longitude': -74.26},
      ],
    });
    expect([c[0].detalle, c[1].detalle, c[1].lat], ['Comunidad Autónoma de Madrid, España', 'Colombia', 4.73]);
    expect(parsearCiudades({}), isEmpty); // sin resultados la API no manda "results"
  });

  test('íconos por código', () {
    expect(
      [
        for (final c in [0, 2, 3, 45, 63, 81, 73, 95]) aspecto(c).$1,
      ],
      [
        Icons.wb_sunny_outlined,
        Icons.filter_drama_outlined,
        Icons.cloud_outlined,
        Icons.foggy,
        Icons.water_drop_outlined,
        Icons.water_drop_outlined,
        Icons.ac_unit,
        Icons.thunderstorm_outlined,
      ],
    );
  });

  test('la ciudad y el último pronóstico se guardan', () async {
    final dir = await Directory.systemTemp.createTemp('agenda');
    archivoDatos = File('${dir.path}/entradas.json');
    entradas.value = [];
    ciudad.value = {'nombre': 'Madrid', 'detalle': 'España', 'lat': 40.4, 'lon': -3.7};
    clima.value = {
      '2026-11-22': [3, 13.6, 7.1],
    };
    climaActualizado = '2026-11-22T09:00:00.000';
    await guardar();
    ciudad.value = null;
    clima.value = {};
    climaActualizado = null;
    await cargar();
    expect(
      [ciudad.value?['nombre'], clima.value['2026-11-22'], climaActualizado],
      [
        'Madrid',
        [3, 13.6, 7.1],
        '2026-11-22T09:00:00.000',
      ],
    );
    await dir.delete(recursive: true);
  });
}
