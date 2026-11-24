// Qué pasa cada día: ocurrencias de repetidos, tareas pendientes y hechas.
import 'datos.dart';

DateTime soloDia(DateTime d) => DateTime(d.year, d.month, d.day);
bool mismoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
int _n(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000; // sin saltos de horario de verano
bool _bisiesto(int y) => y % 4 == 0 && (y % 100 != 0 || y % 400 == 0);

bool ocurre(Entrada e, DateTime d) {
  final f = e.fecha;
  if (f == null || e.borrado || e.tipo == Tipo.nota) return false;
  if (e.tipo == Tipo.cumple) {
    if (f.month == d.month && f.day == d.day) return true;
    return f.month == 2 && f.day == 29 && d.month == 2 && d.day == 28 && !_bisiesto(d.year);
  }
  final r = e.repeticion;
  if (r == null) return mismoDia(f, d);
  if (_n(d) < _n(f) || (r.fin != null && _n(d) > _n(r.fin!))) return false;
  switch (r.unidad) {
    case 'dia':
      return (_n(d) - _n(f)) % r.cada == 0;
    case 'semana':
      if (!(r.dias.isEmpty ? [f.weekday] : r.dias).contains(d.weekday)) return false;
      final semanas = ((_n(d) - d.weekday) - (_n(f) - f.weekday)) ~/ 7;
      return semanas % r.cada == 0;
    case 'mes':
      // shortcut: el día 31 no cae en meses cortos; pasarlo al último día si alguien lo pide.
      return d.day == f.day && ((d.year - f.year) * 12 + d.month - f.month) % r.cada == 0;
    default:
      return d.month == f.month && d.day == f.day && (d.year - f.year) % r.cada == 0;
  }
}

/// Tarea simple: hecha para siempre. Repetitiva: hecha solo ese día.
bool hecha(Entrada e, DateTime d) => e.repeticion == null ? e.hechas.isNotEmpty : e.hechas.any((h) => mismoDia(h, d));

bool vencida(Entrada e, DateTime hoy) =>
    e.tipo == Tipo.tarea && e.repeticion == null && e.fecha != null && (e.hechas.isEmpty || marcando.contains(e.id)) && _n(e.fecha!) < _n(hoy);

enum Categoria { evento, cumple, imp, tarea }

Categoria categoria(Entrada e) => switch (e.tipo) {
  Tipo.evento => Categoria.evento,
  Tipo.cumple => Categoria.cumple,
  _ => e.importante ? Categoria.imp : Categoria.tarea,
};

/// Lo que se muestra en un día: sin notas, sin tareas hechas ni tareas repetitivas comunes (llenarían todos los días).
List<Entrada> delDia(List<Entrada> todas, DateTime d) => [
  for (final e in todas)
    if (ocurre(e, d) && !(e.tipo == Tipo.tarea && (hecha(e, d) || (e.repeticion != null && !e.importante)))) e,
]..sort((a, b) => (a.hora ?? '99').compareTo(b.hora ?? '99'));

/// Barra derecha: importantes arriba, después repetitivas y con fecha por fecha, al final sin fecha.
List<Entrada> pendientes(List<Entrada> todas) {
  String clave(Entrada e) => e.repeticion != null ? '0' : e.fecha?.toIso8601String() ?? '9';
  return [
    for (final e in todas)
      if (e.tipo == Tipo.tarea && !e.borrado && (e.repeticion != null || e.hechas.isEmpty || marcando.contains(e.id))) e,
  ]..sort((a, b) => a.importante != b.importante ? (a.importante ? -1 : 1) : clave(a).compareTo(clave(b)));
}

/// Detalle de un día: tareas que tocan ese día y siguen pendientes; el día de hoy suma las vencidas.
List<Entrada> tareasDelDia(List<Entrada> todas, DateTime d, DateTime hoy) => [
  for (final e in todas)
    if (e.tipo == Tipo.tarea && !e.borrado && ((ocurre(e, d) && (!hecha(e, d) || marcando.contains(e.id))) || (mismoDia(d, hoy) && vencida(e, hoy)))) e,
]..sort((a, b) => a.importante != b.importante ? (a.importante ? -1 : 1) : (a.hora ?? '99').compareTo(b.hora ?? '99'));

/// Tareas completadas ese día (cualquiera, con o sin fecha).
List<Entrada> hechasDelDia(List<Entrada> todas, DateTime d) => [
  for (final e in todas)
    if (e.tipo == Tipo.tarea && !e.borrado && !marcando.contains(e.id) && e.hechas.any((h) => mismoDia(h, d))) e,
];

/// Para saltar a una entrada desde la búsqueda: su fecha, o la próxima vez que ocurre si se repite.
DateTime? proximaFecha(Entrada e, DateTime hoy) {
  final f = e.fecha;
  if (f == null || (e.repeticion == null && e.tipo != Tipo.cumple)) return f;
  for (var i = 0; i <= 400; i++) {
    final d = DateTime(hoy.year, hoy.month, hoy.day + i);
    if (ocurre(e, d)) return d;
  }
  return f;
}

/// Marca o desmarca la tarea en el día [d] (hoy, desde la barra derecha).
void completar(Entrada e, DateTime d, bool si) {
  if (e.repeticion == null) {
    e.hechas = si ? [DateTime.now()] : [];
  } else {
    e.hechas = [...e.hechas.where((h) => !mismoDia(h, d)), if (si) mismoDia(d, DateTime.now()) ? DateTime.now() : d];
  }
  e.actualizado = DateTime.now();
}
