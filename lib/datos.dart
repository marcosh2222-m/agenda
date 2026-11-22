// Entradas (notas, tareas, eventos, cumpleaños) y su guardado en un JSON local.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

enum Tipo { nota, tarea, evento, cumple }

class Repeticion {
  final String unidad; // dia, semana, mes, anio
  final int cada;
  final List<int> dias; // semana: DateTime.monday..sunday
  final DateTime? fin;
  const Repeticion(this.unidad, {this.cada = 1, this.dias = const [], this.fin});

  Map<String, dynamic> toJson() => {
        'unidad': unidad,
        'cada': cada,
        if (dias.isNotEmpty) 'dias': dias,
        if (fin != null) 'fin': _dia(fin!),
      };
  factory Repeticion.fromJson(Map<String, dynamic> j) => Repeticion(
        j['unidad'],
        cada: j['cada'] ?? 1,
        dias: [...?(j['dias'] as List?)?.cast<int>()],
        fin: j['fin'] == null ? null : DateTime.parse(j['fin']),
      );
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
  // Minutos desde el inicio (fecha a la hora, o a las 00:00 sin hora). -60 = 1 h antes.
  // null = usar las de Ajustes.
  List<int>? alarmas;
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
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toRadixString(36),
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
        alarmas: (j['alarmas'] as List?)?.cast<int>(),
        actualizado: DateTime.parse(j['actualizado']),
        borrado: j['borrado'] ?? false,
      );
}

String _dia(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final entradas = ValueNotifier<List<Entrada>>([]);

/// Nombre de un ThemeMode: system, light o dark. Se guarda junto a las entradas.
final modoTema = ValueNotifier<String>('system');

File archivoDatos = File('${Platform.environment['APPDATA']}\\Agenda\\entradas.json');

Future<void> cargar() async {
  if (!await archivoDatos.exists()) return;
  try {
    final j = jsonDecode(await archivoDatos.readAsString()) as Map<String, dynamic>;
    entradas.value = [for (final e in j['entradas'] as List) Entrada.fromJson(e)];
    modoTema.value = j['tema'] ?? 'system';
  } catch (e) {
    // Archivo roto: apartarlo para no pisarlo al guardar.
    final roto = '${archivoDatos.path}.roto-${DateTime.now().millisecondsSinceEpoch}';
    await archivoDatos.rename(roto);
    debugPrint('[agenda] Datos ilegibles, movidos a $roto: $e');
  }
}

Future<void> guardar() async {
  await archivoDatos.parent.create(recursive: true);
  final tmp = File('${archivoDatos.path}.tmp');
  await tmp.writeAsString(const JsonEncoder.withIndent(' ').convert({
    'version': 1,
    'tema': modoTema.value,
    'entradas': entradas.value,
  }), flush: true);
  await tmp.rename(archivoDatos.path); // escribir aparte y renombrar: un corte no deja el archivo a medias
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
