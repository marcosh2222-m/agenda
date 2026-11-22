// Entradas (notas, tareas, eventos, cumpleaños) y su guardado en un JSON local.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'captura.dart';

enum Tipo { nota, tarea, evento, cumple }

class Repeticion {
  final String unidad; // dia, semana, mes, anio
  final int cada;
  final List<int> dias; // semana: DateTime.monday..sunday
  final DateTime? fin;
  const Repeticion(this.unidad, {this.cada = 1, this.dias = const [], this.fin});

  Map<String, dynamic> toJson() => {'unidad': unidad, 'cada': cada, if (dias.isNotEmpty) 'dias': dias, if (fin != null) 'fin': _dia(fin!)};
  factory Repeticion.fromJson(Map<String, dynamic> j) =>
      Repeticion(j['unidad'], cada: j['cada'] ?? 1, dias: [...?(j['dias'] as List?)?.cast<int>()], fin: j['fin'] == null ? null : DateTime.parse(j['fin']));
}

class Entrada {
  final String id;
  String texto;
  Tipo tipo;
  DateTime? fecha; // solo el día
  String? hora; // "HH:mm"
  bool importante;
  List<DateTime> hechas;
  Repeticion? repeticion;
  // Códigos de alarma ("antes 60", "0 09:00", "-1 20:00", ver alarmas.dart). null = usar las de Ajustes.
  List<String>? alarmas;
  DateTime actualizado;
  bool borrado;

  Entrada({
    String? id,
    required this.texto,
    required this.tipo,
    this.fecha,
    this.hora,
    this.importante = false,
    List<DateTime>? hechas,
    this.repeticion,
    this.alarmas,
    DateTime? actualizado,
    this.borrado = false,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toRadixString(36),
       hechas = hechas ?? [],
       actualizado = actualizado ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'texto': texto,
    'tipo': tipo.name,
    if (fecha != null) 'fecha': _dia(fecha!),
    if (hora != null) 'hora': hora,
    if (importante) 'importante': true,
    if (hechas.isNotEmpty) 'hechas': [for (final h in hechas) h.toIso8601String()],
    if (repeticion != null) 'repeticion': repeticion!.toJson(),
    if (alarmas != null) 'alarmas': alarmas,
    'actualizado': actualizado.toIso8601String(),
    if (borrado) 'borrado': true,
  };

  factory Entrada.fromJson(Map<String, dynamic> j) => Entrada(
    id: j['id'],
    texto: j['texto'],
    tipo: Tipo.values.byName(j['tipo']),
    fecha: j['fecha'] == null ? null : DateTime.parse(j['fecha']),
    hora: j['hora'],
    importante: j['importante'] ?? false,
    hechas: [for (final h in (j['hechas'] as List? ?? [])) DateTime.parse(h)],
    repeticion: j['repeticion'] == null ? null : Repeticion.fromJson(j['repeticion']),
    alarmas: (j['alarmas'] as List?)?.cast<String>(),
    actualizado: DateTime.parse(j['actualizado']),
    borrado: j['borrado'] ?? false,
  );
}

String _dia(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final entradas = ValueNotifier<List<Entrada>>([]);

/// Nombre de un ThemeMode: system, light o dark. Se guarda junto a las entradas.
final modoTema = ValueNotifier<String>('system');

/// Alarmas por defecto de cada tipo (Ajustes); cada entrada puede tener las suyas.
const alarmasDeFabrica = {
  'evento': ['antes 60'], // evento con hora: 1 h antes
  'eventoSinHora': ['0 09:00'],
  'cumple': ['-1 20:00', '0 09:00'],
  'tarea': ['antes 0'], // tarea con hora: a esa hora
};

/// Atajo global para abrir la agenda (JSON de HotKey); null = Ctrl + Alt + Espacio.
final atajoGuardado = ValueNotifier<Map<String, dynamic>?>(null);

final alarmasDefecto = ValueNotifier<Map<String, List<String>>>(Map.of(alarmasDeFabrica));

/// Carpeta para la copia diaria (puede ser de OneDrive); null = sin copias.
final carpetaCopias = ValueNotifier<String?>(null);
String? ultimaCopia, ultimoResumen; // días ("2026-11-22") de la última copia y del último resumen

File archivoDatos = File('${Platform.environment['APPDATA']}\\Agenda\\entradas.json');

const _version = 2; // 2: textos con formato (mayúscula inicial; cumpleaños guardan solo el nombre)

Future<void> cargar() async {
  if (!await archivoDatos.exists()) return;
  int version;
  try {
    final j = jsonDecode(await archivoDatos.readAsString()) as Map<String, dynamic>;
    entradas.value = [for (final e in j['entradas'] as List) Entrada.fromJson(e)];
    modoTema.value = j['tema'] ?? 'system';
    if (j['atajo'] case Map m) atajoGuardado.value = m.cast<String, dynamic>();
    if (j['alarmas'] case Map m) alarmasDefecto.value = {...alarmasDeFabrica, for (final k in m.keys) k as String: (m[k] as List).cast<String>()};
    carpetaCopias.value = j['carpetaCopias'];
    ultimaCopia = j['ultimaCopia'];
    ultimoResumen = j['ultimoResumen'];
    version = j['version'] ?? 1;
  } catch (e) {
    // Archivo roto: apartarlo para no pisarlo al guardar.
    final roto = '${archivoDatos.path}.roto-${DateTime.now().millisecondsSinceEpoch}';
    await archivoDatos.rename(roto);
    debugPrint('[agenda] Datos ilegibles, movidos a $roto: $e');
    return;
  }
  if (version < 2) {
    entradas.value.forEach(migrarTexto);
    await guardar();
  }
}

Future<void> guardar() async {
  await archivoDatos.parent.create(recursive: true);
  final tmp = File('${archivoDatos.path}.tmp');
  await tmp.writeAsString(
    const JsonEncoder.withIndent(' ').convert({
      'version': _version,
      'tema': modoTema.value,
      'alarmas': alarmasDefecto.value,
      'atajo': atajoGuardado.value,
      'carpetaCopias': carpetaCopias.value,
      'ultimaCopia': ultimaCopia,
      'ultimoResumen': ultimoResumen,
      'entradas': entradas.value,
    }),
    flush: true,
  );
  await tmp.rename(archivoDatos.path); // escribir aparte y renombrar: un corte no deja el archivo a medias
}

String diaClave(DateTime d) => _dia(d);

/// Copia del archivo de datos, una vez por día, a la carpeta elegida; quedan las últimas 30.
/// Devuelve null si no tocaba o salió bien, o el error para mostrar en Ajustes.
Future<String?> copiaDiaria(DateTime ahora) async {
  final carpeta = carpetaCopias.value;
  final hoy = _dia(ahora);
  if (carpeta == null || ultimaCopia == hoy || !await archivoDatos.exists()) return null;
  try {
    final dir = await Directory(carpeta).create(recursive: true);
    await archivoDatos.copy('${dir.path}${Platform.pathSeparator}agenda-$hoy.json');
    final copias = [
      for (final f in dir.listSync())
        if (f is File && RegExp(r'agenda-\d{4}-\d{2}-\d{2}\.json$').hasMatch(f.path)) f,
    ]..sort((a, b) => a.path.compareTo(b.path)); // el nombre lleva la fecha: orden alfabético = cronológico
    for (final f in copias.length > 30 ? copias.sublist(0, copias.length - 30) : <File>[]) {
      await f.delete();
    }
    ultimaCopia = hoy;
    await guardar();
    return null;
  } catch (e) {
    return 'No se pudo copiar a $carpeta: $e';
  }
}

/// Después de modificar una entrada en el lugar: avisa a la pantalla y guarda.
Future<void> cambiar() async {
  entradas.value = [...entradas.value];
  await guardar();
}

Future<void> agregar(Entrada e) async {
  entradas.value = [...entradas.value, e];
  await guardar();
}
