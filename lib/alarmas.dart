// Alarmas: cuándo suena cada entrada. La app queda en la bandeja y revisa cada 30 s qué avisar;
// no se programan en Windows, así posponer y las perdidas por suspensión son simples.
// shortcut: con la app cerrada (Salir) no suena nada; programar en Windows si hiciera falta.
import 'calendario.dart';
import 'captura.dart';
import 'datos.dart';

// Código de una alarma, en texto para que el JSON se lea:
//   "antes 60"  → 60 min antes de la hora de la entrada (sin hora no suena)
//   "0 09:00"   → ese día a las 09:00
//   "-1 20:00"  → el día anterior a las 20:00

String _dos(int n) => n.toString().padLeft(2, '0');

DateTime? momento(String a, DateTime dia, String? hora) {
  final p = a.split(' ');
  if (p[0] == 'antes') {
    if (hora == null) return null;
    return DateTime(dia.year, dia.month, dia.day, int.parse(hora.substring(0, 2)), int.parse(hora.substring(3)) - int.parse(p[1]));
  }
  final hm = p[1].split(':');
  return DateTime(dia.year, dia.month, dia.day + int.parse(p[0]), int.parse(hm[0]), int.parse(hm[1]));
}

String textoAlarma(String a) {
  final p = a.split(' ');
  if (p[0] == 'antes') {
    final n = int.parse(p[1]);
    return n == 0 ? 'a la hora' : (n % 60 == 0 ? '${n ~/ 60} h antes' : '$n min antes');
  }
  final d = int.parse(p[0]);
  return switch (d) {
    0 => p[1],
    -1 => 'día anterior ${p[1]}',
    _ => '${-d} días antes ${p[1]}',
  };
}

/// Lo que se escribe → código: "30 min antes", "1 h antes", "a la hora", "09:00", "9hs", "día anterior 20:00".
String? leerAlarma(String s) {
  var t = sinTildes(s.trim());
  if (RegExp(r'^(a la hora|en el momento)$').hasMatch(t)) return 'antes 0';
  final antes = RegExp(r'^(\d+)\s*(m|min|mins|minutos?|h|hs|horas?)\s*antes$').firstMatch(t);
  if (antes != null) {
    final n = int.parse(antes[1]!);
    return 'antes ${antes[2]!.startsWith('m') ? n : n * 60}';
  }
  final anterior = RegExp(r'\b(el |del )?dia anterior\b').hasMatch(t);
  t = t.replaceAll(RegExp(r'\b(el |del )?dia anterior\b'), '').trim();
  final hm = RegExp(r'^(?:a las\s*)?(\d{1,2})(?::(\d{2}))?\s*(?:hs?)?$').firstMatch(t);
  if (hm == null) return null;
  final h = int.parse(hm[1]!), m = int.parse(hm[2] ?? '0');
  if (h > 23 || m > 59) return null;
  return '${anterior ? -1 : 0} ${_dos(h)}:${_dos(m)}';
}

/// Qué valor por defecto de Ajustes le toca; null = ninguno (notas, tareas sin hora).
String? claveDefecto(Entrada e) => switch (e.tipo) {
  Tipo.cumple => 'cumple',
  Tipo.evento => e.hora != null ? 'evento' : 'eventoSinHora',
  Tipo.tarea => e.hora != null ? 'tarea' : null,
  Tipo.nota => null,
};

List<String> alarmasDe(Entrada e) => e.alarmas ?? alarmasDefecto.value[claveDefecto(e)] ?? const [];

class Aviso {
  final Entrada entrada;
  final DateTime dia, cuando; // dia: la ocurrencia; cuando: el momento en que suena
  const Aviso(this.entrada, this.dia, this.cuando);
}

/// Alarmas que suenan en (desde, hasta]; las tareas ya hechas ese día no suenan.
List<Aviso> avisosEntre(List<Entrada> todas, DateTime desde, DateTime hasta) {
  final avisos = <Aviso>[];
  // Una alarma puede caer días antes de su ocurrencia ("día anterior"): mirar un margen alrededor.
  for (
    var d = DateTime(desde.year, desde.month, desde.day - 1);
    !d.isAfter(DateTime(hasta.year, hasta.month, hasta.day + 2));
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    for (final e in todas) {
      if (!ocurre(e, d) || (e.tipo == Tipo.tarea && hecha(e, d))) continue;
      for (final a in alarmasDe(e)) {
        final m = momento(a, d, e.hora);
        if (m != null && m.isAfter(desde) && !m.isAfter(hasta)) avisos.add(Aviso(e, d, m));
      }
    }
  }
  return avisos..sort((a, b) => a.cuando.compareTo(b.cuando));
}

/// Avisos pospuestos desde la notificación. shortcut: en memoria, se pierden al cerrar la app.
final pospuestas = <Aviso>[];

/// Qué avisar entre la revisión anterior y ahora. Lo atrasado más de 5 min (PC suspendida) va a "perdidas".
({List<Aviso> ahora, List<Aviso> perdidas}) revisar(List<Entrada> todas, DateTime desde, DateTime hasta) {
  if (hasta.difference(desde) > const Duration(hours: 24)) desde = hasta.subtract(const Duration(hours: 24));
  final vencidas = pospuestas.where((a) => !a.cuando.isAfter(hasta)).toList();
  pospuestas.removeWhere(vencidas.contains);
  final todos = [
    ...avisosEntre(todas, desde, hasta),
    for (final a in vencidas)
      if (!a.entrada.borrado && !(a.entrada.tipo == Tipo.tarea && hecha(a.entrada, a.dia))) a,
  ];
  final limite = hasta.subtract(const Duration(minutes: 5));
  return (
    ahora: [
      for (final a in todos)
        if (a.cuando.isAfter(limite)) a,
    ],
    perdidas: [
      for (final a in todos)
        if (!a.cuando.isAfter(limite)) a,
    ],
  );
}

/// Resumen al prender la PC: "Hoy: 2 eventos, 3 tareas · Mañana cumple Ana".
String resumenDelDia(List<Entrada> todas, DateTime ahora) {
  final hoy = soloDia(ahora), manana = DateTime(hoy.year, hoy.month, hoy.day + 1);
  String plural(int n, String uno, String varios) => '$n ${n == 1 ? uno : varios}';
  final eventos = todas.where((e) => e.tipo == Tipo.evento && ocurre(e, hoy)).length;
  final tareas = tareasDelDia(todas, hoy, hoy).length;
  String cumples(DateTime d) => [
    for (final e in todas)
      if (e.tipo == Tipo.cumple && ocurre(e, d)) e.texto,
  ].join(', ');
  final hoyTexto = [if (eventos > 0) plural(eventos, 'evento', 'eventos'), if (tareas > 0) plural(tareas, 'tarea', 'tareas')].join(', ');
  return [
    'Hoy: ${hoyTexto.isEmpty ? 'día libre' : hoyTexto}',
    if (cumples(hoy) case final c when c.isNotEmpty) 'Hoy cumple $c',
    if (cumples(manana) case final c when c.isNotEmpty) 'Mañana cumple $c',
  ].join(' · ');
}

/// Título y texto de la notificación.
(String, String) textoAviso(Aviso a, DateTime ahora) {
  final e = a.entrada, d = a.dia;
  final hoy = soloDia(ahora);
  final cuando = mismoDia(d, hoy) ? 'Hoy' : (mismoDia(d, DateTime(hoy.year, hoy.month, hoy.day + 1)) ? 'Mañana' : fechaCorta(d, hoy));
  final f = e.fecha;
  final cumple29 = e.tipo == Tipo.cumple && f != null && f.month == 2 && f.day == 29 && d.day == 28 ? ' (cumple el 29/2)' : '';
  return (tituloLargo(e, d), [cuando, ?e.hora].join(' · ') + cumple29);
}
