// Captura automática: una frase → Entrada. Reglas fijas, sin internet ni IA (ver docs/CONCEPTO.md).
import 'datos.dart';

const _diaRe = r'(lunes|martes|mi[eé]rcoles|jueves|viernes|s[aá]bado|domingo)s?';
const _dias = {'lunes': 1, 'martes': 2, 'miercoles': 3, 'jueves': 4, 'viernes': 5, 'sabado': 6, 'domingo': 7};
const _meses = {
  'enero': 1, 'febrero': 2, 'marzo': 3, 'abril': 4, 'mayo': 5, 'junio': 6, 'julio': 7, 'agosto': 8,
  'septiembre': 9, 'setiembre': 9, 'octubre': 10, 'noviembre': 11, 'diciembre': 12,
};
const _abrev = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const nombreTipo = {Tipo.nota: 'Nota', Tipo.tarea: 'Tarea', Tipo.evento: 'Evento', Tipo.cumple: 'Cumpleaños'};

String _sinTildes(String s) => s.toLowerCase().replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ú', 'u');
int _nDia(String s) => _dias[_sinTildes(s)]!;
String _hora(int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

/// [tipo] fuerza el tipo (el usuario tocó otro botón); las demás reglas se aplican igual.
Entrada interpretar(String frase, DateTime ahora, {Tipo? tipo}) {
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  var t = ' ${frase.trim()} ';
  DateTime? fecha;
  String? hora;
  Repeticion? rep;
  var importante = false;

  // Busca el patrón; si `usar` lo acepta, lo saca del texto.
  bool saca(String patron, bool Function(RegExpMatch m) usar) {
    for (final m in RegExp(patron, caseSensitive: false, unicode: true).allMatches(t)) {
      if (usar(m)) {
        t = t.replaceRange(m.start, m.end, ' ');
        return true;
      }
    }
    return false;
  }

  final nota = saca(r'^\s*nota:', (_) => true);
  final cumple = RegExp(r'\bcumple(a[ñn]os)?\b', caseSensitive: false).hasMatch(t);
  int? edad; // la que cumple en el próximo cumpleaños
  if (cumple) {
    saca(r'\b(\d{1,3}) a[ñn]os\b', (m) {
      edad = int.parse(m[1]!);
      return true;
    });
  }
  saca(r'\bimportante\b', (_) => importante = true) || saca(r'!+\s*$', (_) => importante = true);

  // Repetición antes que fecha: "todos los lunes" no es "el lunes".
  saca(r'\bcada (\d+) (d[ií]a|semana|mes|a[ñn]o)(s|es)?\b', (m) {
    rep = Repeticion(_unidad(m[2]!), cada: int.parse(m[1]!));
    return true;
  }) ||
      saca(r'\b(todos los d[ií]as|cada d[ií]a|diario|diariamente)\b', (_) {
        rep = const Repeticion('dia');
        return true;
      }) ||
      saca(r'\b(cada|todos los|todas las)\s+(semana|mes|a[ñn]o)(s|es)?\b', (m) {
        rep = Repeticion(_unidad(m[2]!));
        return true;
      }) ||
      saca('\\b(?:cada|todos los|todas las)\\s+($_diaRe(?:\\s*(?:,|y)\\s*$_diaRe)*)\\b', (m) {
        final dias = {for (final d in RegExp(_diaRe, caseSensitive: false, unicode: true).allMatches(m[1]!)) _nDia(d[1]!)}.toList()..sort();
        rep = Repeticion('semana', dias: dias);
        return true;
      });

  bool usarHora(String h, String? m) {
    final hh = int.parse(h), mm = int.parse(m ?? '0');
    if (hh > 23 || mm > 59) return false;
    hora = _hora(hh, mm);
    return true;
  }

  saca(r'\ba las (\d{1,2})(?::(\d{2}))?\s*(?:hs?)?\b', (m) => usarHora(m[1]!, m[2])) ||
      saca(r'\b(\d{1,2}):(\d{2})\s*(?:hs?)?\b', (m) => usarHora(m[1]!, m[2])) ||
      saca(r'\b(\d{1,2})\s*hs?\b', (m) => usarHora(m[1]!, null));

  bool usarFecha(int d, int m, String? anio) {
    var y = anio == null ? null : int.parse(anio);
    if (y != null && y < 100) y += y > ahora.year % 100 ? 1900 : 2000;
    // shortcut: año 0 = cumpleaños sin año conocido; usar un campo propio si hace falta en otro lado.
    final f = DateTime(y ?? (cumple ? 0 : ahora.year), m, d);
    if (f.month != m || f.day != d) return false; // 31/2 y parecidos
    fecha = y == null && !cumple && f.isBefore(hoy) ? DateTime(f.year + 1, m, d) : f;
    return true;
  }

  bool enDias(int n) {
    fecha = hoy.add(Duration(days: n));
    return true;
  }

  saca(r'\bpasado ma[ñn]ana\b', (_) => enDias(2)) ||
      saca(r'\bma[ñn]ana\b', (_) => enDias(1)) ||
      saca(r'\bhoy\b', (_) => enDias(0)) ||
      saca('\\b(?:el |este |pr[oó]ximo )?$_diaRe\\b', (m) {
        final faltan = (_nDia(m[1]!) - hoy.weekday + 7) % 7;
        fecha = hoy.add(Duration(days: faltan == 0 ? 7 : faltan));
        return true;
      }) ||
      saca(r'\b(?:el )?(\d{1,2})/(\d{1,2})(?:/(\d{4}|\d{2}))?\b', (m) => usarFecha(int.parse(m[1]!), int.parse(m[2]!), m[3])) ||
      saca('\\b(?:el )?(\\d{1,2}) de (${_meses.keys.join('|')})(?: de (\\d{4}))?\\b',
          (m) => usarFecha(int.parse(m[1]!), _meses[m[2]!.toLowerCase()]!, m[3]));

  var texto = t.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'^[\s,;.-]+|[\s,;.-]+$'), '');
  if (texto.isEmpty) texto = frase.trim();

  // shortcut: verbo = primera palabra en infinitivo (-ar/-er/-ir); falla con "bar", "taller". Usar lista si molesta.
  final verbo = RegExp(r'^(\p{L}+(ar|er|ir)|ir)$', unicode: true).hasMatch(_sinTildes(texto.split(' ').first));
  tipo ??= nota
      ? Tipo.nota
      : cumple
          ? Tipo.cumple
          : verbo
              ? Tipo.tarea
              : hora != null || rep != null
                  ? Tipo.evento
                  : fecha == null && texto.length > 60
                      ? Tipo.nota
                      : Tipo.tarea;

  if (fecha == null && (tipo == Tipo.evento || (tipo == Tipo.tarea && hora != null))) fecha = hoy;
  if (tipo == Tipo.cumple) rep = const Repeticion('anio');
  final f = fecha;
  if (edad != null && f != null && f.year == 0) {
    final nacio = DateTime(_proximo(f, ahora).year - edad!, f.month, f.day);
    if (nacio.month == f.month) fecha = nacio; // 29/2 en año no bisiesto: queda sin año
  }

  return Entrada(texto: texto, tipo: tipo, fecha: fecha, hora: hora, repeticion: rep, importante: importante);
}

String _unidad(String s) => switch (_sinTildes(s)) { 'dia' => 'dia', 'semana' => 'semana', 'mes' => 'mes', _ => 'anio' };

/// Etiquetas para mostrar debajo de la captura mientras se escribe.
List<String> describir(Entrada e, DateTime ahora) {
  final f = e.fecha;
  final r = e.repeticion;
  return [
    if (e.importante) 'importante',
    if (f != null && e.tipo == Tipo.cumple) '${f.day}/${f.month}',
    if (f != null && e.tipo == Tipo.cumple && f.year != 0) 'cumple ${_proximo(f, ahora).year - f.year}',
    if (f != null && e.tipo != Tipo.cumple) '${_abrev[f.weekday - 1]} ${f.day}/${f.month}${f.year != ahora.year ? '/${f.year}' : ''}',
    if (e.hora != null) e.hora!,
    if (r != null && e.tipo != Tipo.cumple)
      r.dias.isNotEmpty
          ? 'todos los ${[for (final d in r.dias) _abrev[d - 1]].join(', ')}'
          : r.cada > 1
              ? 'cada ${r.cada} ${const {'dia': 'días', 'semana': 'semanas', 'mes': 'meses', 'anio': 'años'}[r.unidad]}'
              : const {'dia': 'todos los días', 'semana': 'todas las semanas', 'mes': 'todos los meses', 'anio': 'todos los años'}[r.unidad]!,
  ];
}

DateTime _proximo(DateTime f, DateTime ahora) {
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final este = DateTime(hoy.year, f.month, f.day);
  return este.isBefore(hoy) ? DateTime(hoy.year + 1, f.month, f.day) : este;
}
