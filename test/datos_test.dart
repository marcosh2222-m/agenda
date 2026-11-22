import 'dart:io';

import 'package:agenda/datos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
        alarmas: [480, 840],
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
