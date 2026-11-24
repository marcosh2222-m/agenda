import 'dart:io';

import 'package:agenda/datos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  copias();
  ids();

  test('guardar y cargar devuelve lo mismo', () async {
    final dir = await Directory.systemTemp.createTemp('agenda');
    archivoDatos = File('${dir.path}/entradas.json');
    entradas.value = [
      Entrada(texto: 'nota suelta', tipo: Tipo.nota),
      Entrada(
        texto: 'pastilla',
        tipo: Tipo.tarea,
        fecha: DateTime(2026, 11, 21),
        hora: '08:00',
        importante: true,
        hechas: [DateTime(2026, 11, 21, 8, 5)],
        repeticion: Repeticion('semana', dias: [1, 3], fin: DateTime(2027, 1, 1)),
        alarmas: ['0 08:00', '0 14:00'],
      ),
    ];
    modoTema.value = 'dark';
    await guardar();
    await guardar(); // segunda vez: el rename tiene que pisar el archivo
    final antes = [for (final e in entradas.value) e.toJson()];

    entradas.value = [];
    modoTema.value = 'system';
    await cargar();
    expect([for (final e in entradas.value) e.toJson()], antes);
    expect(modoTema.value, 'dark');
    expect(entradas.value[1].fecha, DateTime(2026, 11, 21));

    await archivoDatos.writeAsString('{roto');
    await cargar();
    expect(await archivoDatos.exists(), isFalse); // apartado, no pisado
    await dir.delete(recursive: true);
  });
}

void copias() {
  test('copia diaria: una por día, quedan las últimas 30', () async {
    final dir = await Directory.systemTemp.createTemp('agenda');
    archivoDatos = File('${dir.path}/entradas.json');
    entradas.value = [];
    await guardar();
    final destino = Directory('${dir.path}/copias')..createSync();
    for (var i = 1; i <= 31; i++) {
      File('${destino.path}/agenda-2026-10-${i.toString().padLeft(2, '0')}.json').writeAsStringSync('{}');
    }
    File('${destino.path}/otro.txt').writeAsStringSync('no se toca');
    carpetaCopias.value = destino.path;
    ultimaCopia = null;

    expect(await copiaDiaria(DateTime(2026, 11, 22, 9)), isNull);
    final nombres = destino.listSync().map((f) => f.uri.pathSegments.last).toList();
    expect(nombres.where((n) => n.startsWith('agenda-')).length, 30);
    expect(nombres, containsAll(['agenda-2026-11-22.json', 'otro.txt']));
    expect(nombres, isNot(contains('agenda-2026-10-01.json')));
    expect(ultimaCopia, '2026-11-22');
    await dir.delete(recursive: true);
    carpetaCopias.value = null;
  });
}

void ids() {
  test('ids distintos aunque se creen en el mismo instante', () {
    final l = [for (var i = 0; i < 1000; i++) Entrada(texto: 'x', tipo: Tipo.nota).id];
    expect(l.toSet().length, 1000);
  });
}
