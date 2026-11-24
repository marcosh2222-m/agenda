import 'dart:io';

import 'package:agenda/voz.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('limpia marcas de silencio y ruido de Whisper', () {
    expect(limpiarTranscripcion(' Llamar a mamá mañana a las diez.\n'), 'Llamar a mamá mañana a las diez.');
    expect(limpiarTranscripcion('[BLANK_AUDIO]'), '');
    expect(limpiarTranscripcion(' (música) Comprar pan [Risas] '), 'Comprar pan');
  });

  test('una descarga alterada se descarta; la original queda', () async {
    HttpOverrides.global = null;
    final dir = await Directory.systemTemp.createTemp('agenda');
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    s.listen((p) => (p.response..write('programa')).close());
    final url = 'http://127.0.0.1:${s.port}/x', destino = File('${dir.path}/x.zip');
    await expectLater(descargar(url, '0' * 64, destino, 0, 1), throwsA(contains('no coincide')));
    expect(dir.listSync(), isEmpty);
    await descargar(url, '${sha256.convert('programa'.codeUnits)}', destino, 0, 1);
    expect(await destino.readAsString(), 'programa');
    await s.close(force: true);
    await dir.delete(recursive: true);
  });

  test('descomprime un zip en una carpeta con espacios y símbolos', () async {
    final dir = await Directory.systemTemp.createTemp(r"agenda $a ' b");
    final origen = File('${dir.path}/hola.txt')..writeAsStringSync('hola');
    final zip = File('${dir.path}/z.zip');
    final tar = '${Platform.environment['SystemRoot']}\\System32\\tar.exe';
    await Process.run(tar, ['-a', '-cf', zip.path, '-C', dir.path, 'hola.txt']);
    await origen.delete();
    final r = await descomprimir(zip, Directory('${dir.path}/sale'));
    expect([r.exitCode, File('${dir.path}/sale/hola.txt').readAsStringSync()], [0, 'hola']);
    await dir.delete(recursive: true);
  }, skip: !Platform.isWindows);
}
