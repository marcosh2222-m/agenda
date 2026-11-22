// Detalle de un día y búsqueda.
import 'package:flutter/material.dart';

import 'alarmas.dart';
import 'calendario.dart';
import 'captura.dart';
import 'clima.dart';
import 'datos.dart';
import 'estilo.dart';

String relativo(DateTime d, DateTime hoy) {
  final n = DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(hoy.year, hoy.month, hoy.day)).inDays;
  return switch (n) {
    0 => 'Hoy',
    1 => 'Mañana',
    -1 => 'Ayer',
    > 0 => 'En $n días',
    _ => 'Hace ${-n} días',
  };
}

String _plural(int n, String uno, String varios) => n == 0 ? '' : '$n ${n == 1 ? uno : varios}';

class DetalleDia extends StatefulWidget {
  final DateTime dia, hoy;
  final List<Entrada> todas;
  final VoidCallback cerrar;
  const DetalleDia({super.key, required this.dia, required this.hoy, required this.todas, required this.cerrar});
  @override
  State<DetalleDia> createState() => _DetalleDiaState();
}

class _DetalleDiaState extends State<DetalleDia> {
  final texto = TextEditingController();
  final foco = FocusNode();

  void agregarFrase() {
    final t = texto.text.trim();
    if (t.isEmpty) return;
    final e = interpretar(t, widget.dia); // "mañana", "el lunes"... cuentan desde este día
    if (e.fecha == null && e.tipo != Tipo.nota) e.fecha = widget.dia;
    agregar(e);
    texto.clear();
    foco.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final d = widget.dia, hoy = widget.hoy;
    final delDia = [
      for (final e in widget.todas)
        if (ocurre(e, d)) e,
    ]..sort((a, b) => (a.hora ?? '99').compareTo(b.hora ?? '99'));
    final cumples = delDia.where((e) => e.tipo == Tipo.cumple).toList();
    final eventos = delDia.where((e) => e.tipo == Tipo.evento).toList();
    final tareas = tareasDelDia(widget.todas, d, hoy);
    final hechas = hechasDelDia(widget.todas, d);
    final resumen = [
      _plural(eventos.length, 'evento', 'eventos'),
      _plural(cumples.length, 'cumpleaños', 'cumpleaños'),
      _plural(tareas.length, 'tarea pendiente', 'tareas pendientes'),
    ].where((s) => s.isNotEmpty).join(' · ');

    Widget grupo(String titulo, List<Entrada> lista, Widget Function(Entrada) fila, {String? vacio}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Text(
            titulo,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.muted),
          ),
        ),
        if (lista.isEmpty && vacio != null) Text(vacio, style: TextStyle(fontSize: 13, color: p.muted)),
        for (final e in lista) fila(e),
      ],
    );

    // Fondo, borde y sombra en la misma caja (con fondo propio, si no la sombra se ve a través).
    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.line),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .07), blurRadius: 28, offset: const Offset(0, 10))],
      ),
      child: Material(
        type: MaterialType.transparency, // para el hover de los botones de adentro
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 14, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          '${nombresDia[d.weekday - 1]} ${d.day} de ${nombresMes[d.month - 1].toLowerCase()}',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          [
                            relativo(d, hoy),
                            if (clima.value[diaClave(d)] case final c?) '${aspecto(c[0].toInt()).$2} ${temperaturas(c)}',
                            resumen.isEmpty ? 'Día libre' : resumen,
                          ].join(' · '),
                          style: TextStyle(fontSize: 12.5, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 18), color: p.muted, tooltip: 'Cerrar (Esc)', onPressed: widget.cerrar),
                ],
              ),
              Divider(height: 20, color: p.line),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          if (cumples.isNotEmpty) grupo('Cumpleaños', cumples, (e) => _fila(p, e)),
                          grupo('Eventos', eventos, (e) => _fila(p, e), vacio: 'Sin eventos.'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      child: ListView(
                        children: [
                          grupo('Tareas', tareas, (e) => _fila(p, e, hecha: false), vacio: 'Nada pendiente.'),
                          if (hechas.isNotEmpty) grupo('Hechas', hechas, (e) => _fila(p, e, hecha: true)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(color: p.panel, borderRadius: BorderRadius.circular(8)),
                child: TextField(
                  controller: texto,
                  focusNode: foco,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'Agregar al ${d.day}/${d.month}… (ej.: turno 15hs)',
                    hintStyle: TextStyle(color: p.muted),
                  ),
                  onSubmitted: (_) => agregarFrase(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// [hecha]: null para eventos y cumpleaños (sin casilla).
  Widget _fila(Paleta p, Entrada e, {bool? hecha}) {
    final d = widget.dia, hoy = widget.hoy;
    final completada = hecha == true ? e.hechas.lastWhere((h) => mismoDia(h, d)) : null;
    final meta = [
      if (e.repeticion != null && e.tipo != Tipo.cumple) textoRepeticion(e.repeticion!),
      if (hecha == false && vencida(e, hoy) && !mismoDia(e.fecha!, d)) 'Vencida · ${fechaCorta(e.fecha!, hoy)}',
      if (completada != null) 'Hecha ${completada.hour.toString().padLeft(2, '0')}:${completada.minute.toString().padLeft(2, '0')}',
    ];
    return ConBorrar(
      entrada: e,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hecha != null) ...[
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(value: hecha, onChanged: (v) => marcar(context, e, d, v!)),
              ),
              const SizedBox(width: 8),
            ],
            Padding(padding: const EdgeInsets.only(top: 7, right: 8), child: punto(colorCat[categoria(e)]!)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 1,
                children: [
                  TextoEditable(
                    entrada: e,
                    texto: tituloLargo(e, d),
                    hora: e.tipo == Tipo.evento ? e.hora : null,
                    estilo: TextStyle(fontSize: 14, decoration: hecha == true ? TextDecoration.lineThrough : null, color: hecha == true ? p.muted : null),
                  ),
                  if (meta.isNotEmpty)
                    Text(meta.join(' · '), style: TextStyle(fontSize: 12, color: meta.any((m) => m.startsWith('Vencida')) ? colorVencida : p.muted)),
                  if (hecha != true) _alarmas(p, e),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? alarmasAbiertas; // id de la entrada con el editor de alarmas abierto

  /// Campana con las alarmas de la entrada; un clic abre el editor.
  Widget _alarmas(Paleta p, Entrada e) {
    final lista = alarmasDe(e);
    final abierto = alarmasAbiertas == e.id;
    void poner(List<String>? a) {
      e.alarmas = a;
      e.actualizado = DateTime.now();
      cambiar();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => setState(() => alarmasAbiertas = abierto ? null : e.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Icon(lista.isEmpty ? Icons.notifications_off_outlined : Icons.notifications_none, size: 13, color: p.muted),
                Text(lista.isEmpty ? 'Sin alarma' : lista.map(textoAlarma).join(', '), style: TextStyle(fontSize: 12, color: p.muted)),
              ],
            ),
          ),
        ),
        if (abierto)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EditorAlarmas(alarmas: lista, cambiar: poner),
                if (e.alarmas != null)
                  TextButton(
                    onPressed: () => poner(null),
                    style: TextButton.styleFrom(foregroundColor: p.muted, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    child: const Text('Usar las de Ajustes', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Ctrl + K: busca en el texto de todas las entradas; devuelve la elegida.
Future<Entrada?> buscar(BuildContext context) =>
    showDialog<Entrada>(context: context, barrierColor: Colors.black.withValues(alpha: .12), builder: (_) => const _Buscar());

class _Buscar extends StatefulWidget {
  const _Buscar();
  @override
  State<_Buscar> createState() => _BuscarState();
}

class _BuscarState extends State<_Buscar> {
  var q = '';

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final hoy = soloDia(DateTime.now());
    final clave = sinTildes(q.trim());
    final lejos = DateTime(9999);
    final res = clave.isEmpty
        ? <Entrada>[]
        : ([
            for (final e in entradas.value)
              if (!e.borrado && sinTildes(e.texto).contains(clave)) e,
          ]..sort((a, b) => (proximaFecha(a, hoy) ?? lejos).compareTo(proximaFecha(b, hoy) ?? lejos)));
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 90),
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.line),
      ),
      child: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
              child: TextField(
                autofocus: true,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  icon: Icon(Icons.search, size: 18, color: p.muted),
                  hintText: 'Buscar en la agenda…',
                  hintStyle: TextStyle(color: p.muted),
                ),
                onChanged: (v) => setState(() => q = v),
                onSubmitted: (_) {
                  if (res.isNotEmpty) Navigator.pop(context, res.first);
                },
              ),
            ),
            if (clave.isNotEmpty) Divider(height: 1, color: p.line),
            if (clave.isNotEmpty && res.isEmpty)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text('Nada con "${q.trim()}".', style: TextStyle(color: p.muted)),
              ),
            if (res.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: [
                    for (final e in res)
                      InkWell(
                        onTap: () => Navigator.pop(context, e),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: punto(e.tipo == Tipo.nota ? colorTipo[Tipo.nota]! : colorCat[categoria(e)]!),
                              ),
                              Expanded(child: Text(tituloLargo(e, proximaFecha(e, hoy) ?? hoy), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              Text(
                                [nombreTipo[e.tipo]!, if (proximaFecha(e, hoy) case final f?) fechaCorta(f, hoy)].join(' · '),
                                style: TextStyle(fontSize: 12, color: p.muted, fontFeatures: tabular),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
