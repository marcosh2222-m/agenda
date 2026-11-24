import 'dart:convert';
import 'dart:io';

import 'package:agenda/datos.dart';
import 'package:agenda/drive.dart';
import 'package:agenda/google.dart';
import 'package:agenda/sincronizar.dart';
import 'package:flutter_test/flutter_test.dart';

/// Imita lo que se usa de Drive: listar, bajar, crear (multipart) y actualizar (media).
class DriveFalso {
  final archivos = <String, String>{};
  final pedidos = <String>[];
  String valido = 'token-1';
  int? falla; // responde este código a todo
  late HttpServer servidor;

  Future<void> abrir() async {
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    servidor.listen((p) async {
      final cuerpo = await utf8.decodeStream(p);
      pedidos.add('${p.method} ${p.uri.path}');
      final r = p.response;
      if (p.headers.value('authorization') != 'Bearer $valido') {
        r.statusCode = 401;
      } else if (falla != null) {
        r.statusCode = falla!;
      } else if (p.method == 'GET' && p.uri.path == '/drive/v3/files') {
        expect(p.uri.queryParameters['spaces'], 'appDataFolder');
        r.write(
          jsonEncode({
            'files': [
              for (final id in archivos.keys) {'id': id},
            ],
          }),
        );
      } else if (p.method == 'GET') {
        r.add(utf8.encode(archivos[p.uri.pathSegments.last]!));
      } else if (p.method == 'POST') {
        final partes = cuerpo.split('--agenda-limite-7f3c9b');
        expect(jsonDecode(partes[1].split('\r\n\r\n')[1]), {
          'name': 'agenda.json',
          'parents': ['appDataFolder'],
        });
        archivos['id${archivos.length + 1}'] = partes[2].split('\r\n\r\n')[1].trim();
        r.write('{}');
      } else {
        archivos[p.uri.pathSegments.last] = cuerpo;
        r.write('{}');
      }
      await r.close();
    });
  }

  Drive cliente([String token = 'token-1']) =>
      Drive(({bool renovar = false}) async => renovar ? valido : token, base: Uri.parse('http://127.0.0.1:${servidor.port}'));
}

Entrada e(String id, String texto, int minuto, {bool borrado = false}) =>
    Entrada(id: id, texto: texto, tipo: Tipo.tarea, actualizado: DateTime(2026, 11, 24, 10, minuto), borrado: borrado);

void main() {
  late Directory dir;
  late DriveFalso drive;

  setUp(() async {
    HttpOverrides.global = null;
    dir = await Directory.systemTemp.createTemp('agenda');
    archivoDatos = File('${dir.path}/entradas.json');
    archivoToken = File('${dir.path}/google.token');
    entradas.value = [];
    drive = DriveFalso();
    await drive.abrir();
  });
  tearDown(() async {
    await drive.servidor.close(force: true);
    await dir.delete(recursive: true);
  });

  Map<String, String> textos() => {for (final x in entradas.value) x.id: x.texto};

  test('la PC y el celular terminan con lo mismo, y sin cambios no se sube nada', () async {
    final pc = [e('a', 'Pan', 0), e('b', 'Año nuevo: mañana', 1)];
    final celular = [e('a', 'Pan integral', 5), e('c', 'Médico', 2)];
    entradas.value = pc;
    await sincronizarCon(drive.cliente()); // primera vez: crea el archivo
    entradas.value = celular;
    await sincronizarCon(drive.cliente());
    final esperado = {'a': 'Pan integral', 'b': 'Año nuevo: mañana', 'c': 'Médico'};
    expect(textos(), esperado);
    entradas.value = pc;
    await sincronizarCon(drive.cliente());
    expect(textos(), esperado);
    expect(jsonDecode(await archivoDatos.readAsString())['entradas'], hasLength(3)); // quedó guardado

    drive.pedidos.clear();
    await sincronizarCon(drive.cliente());
    expect(drive.pedidos.any((p) => p.startsWith('PATCH') || p.startsWith('POST')), isFalse);
    expect(drive.archivos, hasLength(1));
  });

  test('un borrado llega al otro equipo y no revive', () async {
    entradas.value = [e('a', 'Pan', 0)];
    await sincronizarCon(drive.cliente());
    entradas.value = [e('a', 'Pan', 3, borrado: true)];
    await sincronizarCon(drive.cliente());
    entradas.value = [e('a', 'Pan', 0)];
    await sincronizarCon(drive.cliente());
    expect(entradas.value.single.borrado, isTrue);
  });

  test('si ambos crearon su archivo a la vez, se juntan los dos', () async {
    String copia(Entrada x) => jsonEncode({
      'version': versionDatos,
      'entradas': [x],
    });
    drive.archivos.addAll({'id1': copia(e('a', 'Uno', 0)), 'id2': copia(e('b', 'Dos', 0))});
    await sincronizarCon(drive.cliente());
    expect(textos(), {'a': 'Uno', 'b': 'Dos'});
    expect((jsonDecode(drive.archivos['id1']!)['entradas'] as List), hasLength(2));
  });

  test('misma hora y distinto contenido: los dos equipos eligen lo mismo', () async {
    entradas.value = [e('a', 'Azul', 0)];
    await sincronizarCon(drive.cliente());
    entradas.value = [e('a', 'Rojo', 0)];
    await sincronizarCon(drive.cliente());
    final elegido = textos();
    entradas.value = [e('a', 'Azul', 0)];
    await sincronizarCon(drive.cliente());
    expect(textos(), elegido);
  });

  test('lo que viene de afuera no cambia el objeto que la pantalla tiene abierto', () async {
    final abierta = e('a', 'Pan', 0);
    drive.archivos['id1'] = jsonEncode({
      'version': versionDatos,
      'entradas': [e('a', 'Pan integral', 9)],
    });
    entradas.value = [abierta];
    await sincronizarCon(drive.cliente());
    expect([identical(entradas.value.single, abierta), abierta.texto], [true, 'Pan integral']);
  });

  group('nada se pisa si algo falla:', () {
    for (final (caso, contenido) in [
      ('copia ilegible', '{roto'),
      ('versión más nueva', '{"version": 99, "entradas": []}'),
      ('entrada inválida', '{"version": 2, "entradas": [{"id": "x"}]}'),
    ]) {
      test(caso, () async {
        drive.archivos['id1'] = contenido;
        entradas.value = [e('a', 'Pan', 0)];
        await expectLater(sincronizarCon(drive.cliente()), throwsA(anything));
        expect(
          [textos(), drive.archivos['id1']],
          [
            {'a': 'Pan'},
            contenido,
          ],
        );
      });
    }

    test('Drive caído', () async {
      drive.falla = 503;
      entradas.value = [e('a', 'Pan', 0)];
      await expectLater(sincronizarCon(drive.cliente()), throwsA(contains('503')));
      expect(textos(), {'a': 'Pan'});
    });
  });

  test('token vencido: pide otro una sola vez', () async {
    await sincronizarCon(drive.cliente('vencido'));
    expect(drive.archivos, hasLength(1));
    final d = drive.cliente('vencido');
    drive.valido = 'otro';
    final malo = Drive(({bool renovar = false}) async => 'siempre-malo', base: d.base);
    drive.pedidos.clear();
    await expectLater(malo.archivos(), throwsA(contains('401')));
    expect(drive.pedidos, hasLength(2));
  });

  test('guardados a la vez no se pisan', () async {
    entradas.value = [for (var i = 0; i < 50; i++) e('$i', 'Tarea $i', 0)];
    await Future.wait([for (var i = 0; i < 20; i++) guardar()]);
    expect(jsonDecode(await archivoDatos.readAsString())['entradas'], hasLength(50));
  });

  test('actualizado viaja en UTC', () {
    final x = e('a', 'Pan', 0);
    expect(x.toJson()['actualizado'], endsWith('Z'));
    expect(Entrada.fromJson(x.toJson()).actualizado, x.actualizado);
  });

  test('PKCE: ejemplo del RFC 7636', () {
    expect(desafio('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'), 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
  });

  test('la vuelta del navegador solo vale con el estado de este intento', () async {
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final codigo = esperarCodigo(s, 'bueno');
    Future<int> pedir(String q) async {
      final c = HttpClient();
      final r = await (await c.getUrl(Uri.parse('http://127.0.0.1:${s.port}$q'))).close();
      await r.drain<void>();
      c.close();
      return r.statusCode;
    }

    expect(await pedir('/?code=robado&state=otro'), 404);
    expect(await pedir('/favicon.ico'), 404);
    expect(await pedir('/?code=mio&state=bueno'), 200);
    expect(await codigo, 'mio');
    await s.close(force: true);
  });

  test('la sesión se guarda cifrada y se recupera', () {
    final claro = utf8.encode('1//token-de-prueba');
    final cifrado = dpapi(claro, cifrar: true);
    expect(utf8.decode(cifrado, allowMalformed: true), isNot(contains('token-de-prueba')));
    expect(dpapi(cifrado, cifrar: false), claro);
    expect(() => dpapi([1, 2, 3], cifrar: false), throwsA(anything));
  }, skip: !Platform.isWindows);

  test('olvidar la sesión borra el archivo', () async {
    await archivoToken.writeAsString('x');
    await olvidarGoogle();
    expect(await archivoToken.exists(), isFalse);
  }, skip: !Platform.isWindows);
}
