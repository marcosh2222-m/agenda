// Sincronización entre la PC y el celular por la carpeta oculta de la app en Google Drive.
// Se sincronizan las entradas; las preferencias (tema, alarmas por defecto, ciudad) son de cada equipo.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'datos.dart';
import 'drive.dart';
import 'estilo.dart';
import 'google.dart';

/// Une las entradas de este equipo con las del otro: por id gana la que se modificó último (`actualizado`).
/// Las borradas se conservan como borradas, así el borrado también llega al otro equipo.
/// shortcut: si se edita la misma entrada en los dos equipos antes de sincronizar, gana la última; sumar aviso si molesta.
List<Entrada> fusionar(List<Entrada> locales, List<Entrada> remotas) {
  final porId = {for (final e in locales) e.id: e};
  for (final r in remotas) {
    final l = porId[r.id];
    if (l == null) {
      porId[r.id] = r;
      continue;
    }
    // Con la misma hora decide el contenido, para que los dos equipos elijan igual y no se pisen para siempre.
    final orden = r.actualizado.compareTo(l.actualizado);
    if (orden > 0 || (orden == 0 && jsonEncode(r).compareTo(jsonEncode(l)) > 0)) l.copiarDe(r);
  }
  return porId.values.toList();
}

String _foto(List<Entrada> l) => ([for (final e in l) jsonEncode(e)]..sort()).join('\n');

List<Entrada> _leer(String texto) {
  final j = jsonDecode(texto) as Map<String, dynamic>;
  // Una versión más nueva puede tener datos que esta no conoce: mejor no pisarlos.
  if ((j['version'] as int) > versionDatos) throw 'el otro equipo usa una versión más nueva de la agenda; actualizá esta';
  return [for (final e in j['entradas'] as List) Entrada.fromJson(e)];
}

/// Baja, une y sube solo si hay diferencias. Si falla la bajada, no toca los datos de acá ni los de Drive.
Future<void> sincronizarCon(Drive drive) async {
  final ids = await drive.archivos();
  final copias = [for (final id in ids) _leer(await drive.bajar(id))];

  final antes = _foto(entradas.value);
  final unidas = copias.fold(entradas.value, fusionar);
  if (_foto(unidas) != antes) {
    entradas.value = [...unidas];
    await guardar();
  }

  final ahora = _foto(entradas.value);
  final contenido = jsonEncode({'version': versionDatos, 'entradas': entradas.value});
  if (ids.isEmpty) return drive.crear(contenido);
  if (_foto(_leer(await drive.bajar(ids.first))) != ahora) await drive.actualizar(ids.first, contenido);
}

final estadoSync = ValueNotifier<String>('');
Timer? _pronto;
final sesionVencida = ValueNotifier(false); // Google pide conectar de nuevo
Drive nube = Drive(tokenGoogle); // los tests usan un servidor local
Future<void>? _enCurso;
var _otraVez = false;

/// Si ya hay una en curso, al terminar se hace otra: la primera pudo empezar antes del último cambio.
Future<void> sincronizar() {
  if (_enCurso != null) _otraVez = true;
  return _enCurso ??= _sincronizar().whenComplete(() => _enCurso = null);
}

Future<void> _sincronizar() async {
  do {
    _otraVez = false;
    if (cuentaGoogle.value == null) return;
    estadoSync.value = 'Sincronizando…';
    try {
      await sincronizarCon(nube);
      final t = DateTime.now();
      estadoSync.value = 'Sincronizado a las ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      sesionVencida.value = false;
    } catch (e) {
      estadoSync.value = 'No se pudo sincronizar: $e';
      sesionVencida.value = e is SesionVencida;
    }
  } while (_otraVez);
}

/// Al abrir, 5 s después de cada cambio, al ocultar la app o volver a ella y cada 5 min.
void iniciarSincronizacion() {
  entradas.addListener(() {
    if (cuentaGoogle.value == null) return;
    _pronto?.cancel();
    _pronto = Timer(const Duration(seconds: 5), sincronizar);
  });
  Timer.periodic(const Duration(minutes: 5), (_) => sincronizar());
  AppLifecycleListener(onResume: sincronizar, onHide: sincronizar);
  sincronizar();
}

Future<void> _conectar() async {
  estadoSync.value = 'Esperando que aceptes en Google…';
  try {
    await conectarGoogle();
    cuentaGoogle.value = await nube.cuenta();
    await guardar();
    await sincronizar();
  } catch (e) {
    estadoSync.value = 'No se pudo conectar: $e';
  }
}

Future<void> _desconectar() async {
  await olvidarGoogle();
  cuentaGoogle.value = null;
  sesionVencida.value = false;
  estadoSync.value = '';
  await guardar();
}

/// Fila de Ajustes (PC y celular): cuenta, estado y botones.
class FilaGoogle extends StatelessWidget {
  final TextStyle? estiloTitulo;
  const FilaGoogle({super.key, this.estiloTitulo});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([cuentaGoogle, estadoSync, sesionVencida]),
    builder: (context, _) {
      final cuenta = cuentaGoogle.value, estado = estadoSync.value;
      final detalle = [
        if (!googleConfigurado) 'Esta versión se compiló sin las credenciales de Google' else cuenta ?? 'Los mismos datos en la PC y el celular',
        if (estado.isNotEmpty) estado,
      ].join('\n');
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text('Sincronizar con Google', style: estiloTitulo ?? const TextStyle(fontSize: 16)),
                  Text(detalle, style: TextStyle(fontSize: 12.5, color: Paleta.of(context).muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (cuenta == null || sesionVencida.value)
              OutlinedButton(onPressed: googleConfigurado ? _conectar : null, child: const Text('Conectar'))
            else ...[
              IconButton(icon: const Icon(Icons.sync, size: 20), tooltip: 'Sincronizar ahora', onPressed: sincronizar),
              TextButton(onPressed: _desconectar, child: const Text('Desconectar')),
            ],
          ],
        ),
      );
    },
  );
}
