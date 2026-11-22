// Pantalla principal de PC (ver docs/boceto-pc.html).
import 'package:flutter/material.dart';

import 'calendario.dart';
import 'captura.dart';
import 'datos.dart';

final captura = FocusNode();

class Paleta {
  final Color bg, line, text, muted, panel, hover, accent, dia;
  const Paleta(this.bg, this.line, this.text, this.muted, this.panel, this.hover, this.accent, this.dia);
  // Un solo fondo; panel tiñe apenas la captura, dia es el beige de los 7 días. muted pasa 4.5:1 sobre bg y sobre dia.
  static const claro = Paleta(
    Color(0xFFFAF7F2),
    Color(0xFFECE6DC),
    Color(0xFF2F2A23),
    Color(0xFF6A6156),
    Color(0xFFF2EDE4),
    Color(0xFFF4EFE7),
    Color(0xFFB0643A),
    Color(0xFFEEE6D8),
  );
  static const oscuro = Paleta(
    Color(0xFF1B1916),
    Color(0xFF2E2A25),
    Color(0xFFECE5D8),
    Color(0xFFA39889),
    Color(0xFF24211D),
    Color(0xFF262320),
    Color(0xFFE09668),
    Color(0xFF292520),
  );
  static Paleta of(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? oscuro : claro;
}

const colorTipo = {Tipo.tarea: Color(0xFF5B8FD6), Tipo.evento: Color(0xFF4F9E63), Tipo.cumple: Color(0xFF8E6FD1), Tipo.nota: Color(0xFFE08A3C)};
const colorCat = {
  Categoria.evento: Color(0xFF4F9E63),
  Categoria.cumple: Color(0xFF8E6FD1),
  Categoria.imp: Color(0xFFD9564C),
  Categoria.tarea: Color(0xFF5B8FD6),
};
const _vencida = Color(0xFF9A6E4C);
const _meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _tabular = [FontFeature.tabularFigures()];

ThemeData tema(Brightness b) {
  final p = b == Brightness.dark ? Paleta.oscuro : Paleta.claro;
  final base = ThemeData(
    brightness: b,
    fontFamily: 'Segoe UI',
    colorScheme: ColorScheme.fromSeed(seedColor: p.accent, brightness: b, primary: p.accent),
  );
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    hoverColor: p.hover,
    splashFactory: NoSplash.splashFactory,
    textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    textSelectionTheme: TextSelectionThemeData(cursorColor: p.accent, selectionColor: p.accent.withValues(alpha: .25)),
    scrollbarTheme: ScrollbarThemeData(thickness: const WidgetStatePropertyAll(4), thumbColor: WidgetStatePropertyAll(p.line)),
    checkboxTheme: CheckboxThemeData(
      shape: const CircleBorder(),
      side: BorderSide(color: p.muted, width: 1.2),
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : Colors.transparent),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

Widget _seccion(BuildContext c, String t, {Widget? extra}) => Padding(
  padding: const EdgeInsets.only(bottom: 14),
  child: Row(
    children: [
      Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      const Spacer(),
      ?extra,
    ],
  ),
);

Widget _punto(Color c, [double t = 6]) => Container(
  width: t,
  height: t,
  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
);

enum Seccion { inicio, notas, hechas, ajustes }

class Pantalla extends StatefulWidget {
  final Widget ajustes;
  const Pantalla({super.key, required this.ajustes});
  @override
  State<Pantalla> createState() => _PantallaState();
}

class _PantallaState extends State<Pantalla> {
  var seccion = Seccion.inicio;

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    return Scaffold(
      body: ValueListenableBuilder(
        valueListenable: entradas,
        builder: (context, todas, _) {
          final hoy = soloDia(DateTime.now());
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _nav(p),
              VerticalDivider(width: 1, thickness: 1, color: p.line),
              Expanded(
                child: switch (seccion) {
                  Seccion.inicio => _Inicio(todas: todas, hoy: hoy),
                  Seccion.notas => _Notas(todas: todas, hoy: hoy),
                  Seccion.hechas => _Hechas(todas: todas, hoy: hoy),
                  Seccion.ajustes => Padding(padding: const EdgeInsets.all(32), child: widget.ajustes),
                },
              ),
              VerticalDivider(width: 1, thickness: 1, color: p.line),
              _Tareas(todas: todas, hoy: hoy),
            ],
          );
        },
      ),
    );
  }

  Widget _nav(Paleta p) {
    Widget item(Seccion s, String t) {
      final on = seccion == s;
      return InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() => seccion = s),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: on ? BoxDecoration(color: p.panel, borderRadius: BorderRadius.circular(6)) : null,
          child: Text(
            t,
            style: TextStyle(color: on ? p.text : p.muted, fontWeight: on ? FontWeight.w600 : null),
          ),
        ),
      );
    }

    return SizedBox(
      width: 168,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 26, 14, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 2,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(10, 0, 0, 24),
              child: Text('Agenda', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            item(Seccion.inicio, 'Inicio'),
            item(Seccion.notas, 'Notas'),
            item(Seccion.hechas, 'Hechas'),
            const Spacer(),
            item(Seccion.ajustes, 'Ajustes'),
          ],
        ),
      ),
    );
  }
}

// ---------- Inicio ----------

class _Inicio extends StatefulWidget {
  final List<Entrada> todas;
  final DateTime hoy;
  const _Inicio({required this.todas, required this.hoy});
  @override
  State<_Inicio> createState() => _InicioState();
}

class _InicioState extends State<_Inicio> {
  late var mes = DateTime(widget.hoy.year, widget.hoy.month);

  @override
  // Todo entra en la ventana: los 7 días toman 2/5 del alto y el mes el resto; lo que no cabe en un día se desplaza dentro de él.
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(36, 24, 36, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Captura(),
        const SizedBox(height: 20),
        _seccion(context, 'Próximos 7 días'),
        Expanded(flex: 2, child: _semana(context)),
        const SizedBox(height: 24),
        _seccion(context, '${_meses[mes.month - 1]} ${mes.year}', extra: _flechas(Paleta.of(context))),
        Expanded(flex: 3, child: _mes(context)),
      ],
    ),
  );

  Widget _semana(BuildContext context) {
    final p = Paleta.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _dia(p, DateTime(widget.hoy.year, widget.hoy.month, widget.hoy.day + i), i == 0)),
        ],
      ],
    );
  }

  Widget _dia(Paleta p, DateTime d, bool esHoy) {
    final items = delDia(widget.todas, d).where((e) => categoria(e) != Categoria.tarea);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: p.dia,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: esHoy ? p.accent.withValues(alpha: .55) : Colors.transparent),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                esHoy ? 'Hoy' : _dias[d.weekday - 1],
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: esHoy ? p.accent : p.text),
              ),
              const SizedBox(width: 6),
              Text(
                '${d.day}',
                style: TextStyle(fontSize: 13, color: esHoy ? p.accent : p.muted, fontFeatures: _tabular),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final e in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 6, right: 7), child: _punto(colorCat[categoria(e)]!, 5)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e.hora != null)
                          Text(
                            e.hora!,
                            style: TextStyle(fontSize: 11.5, height: 1.35, color: p.muted, fontFeatures: _tabular),
                          ),
                        Text(titulo(e, d), style: const TextStyle(fontSize: 12.5, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _flechas(Paleta p) {
    final actual = mes.year == widget.hoy.year && mes.month == widget.hoy.month;
    Widget boton(IconData i, String tip, int n) => IconButton(
      icon: Icon(i, size: 18),
      color: p.muted,
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      onPressed: () => setState(() => mes = DateTime(mes.year, mes.month + n)),
    );
    return Row(
      children: [
        if (!actual)
          TextButton(
            onPressed: () => setState(() => mes = DateTime(widget.hoy.year, widget.hoy.month)),
            style: TextButton.styleFrom(foregroundColor: p.muted, visualDensity: VisualDensity.compact),
            child: const Text('Hoy', style: TextStyle(fontSize: 12.5)),
          ),
        boton(Icons.chevron_left, 'Mes anterior', -1),
        boton(Icons.chevron_right, 'Mes siguiente', 1),
      ],
    );
  }

  Widget _mes(BuildContext context) {
    final p = Paleta.of(context);
    final atras = 1 - mes.weekday; // la grilla arranca el lunes
    return Column(
      children: [
        Row(
          children: [
            for (final d in _dias)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 4, 8),
                  child: Text(d, style: TextStyle(fontSize: 12, color: p.muted)),
                ),
              ),
          ],
        ),
        for (var semana = 0; semana < 6; semana++)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: p.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (var i = 0; i < 7; i++) Expanded(child: _celda(p, DateTime(mes.year, mes.month, 1 + atras + semana * 7 + i)))],
              ),
            ),
          ),
      ],
    );
  }

  Widget _celda(Paleta p, DateTime d) {
    final esHoy = mismoDia(d, widget.hoy);
    final delMes = d.month == mes.month;
    final cuenta = <Categoria, int>{};
    for (final e in delDia(widget.todas, d)) {
      cuenta.update(categoria(e), (n) => n + 1, ifAbsent: () => 1);
    }
    return Opacity(
      opacity: delMes ? 1 : .4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
        // Número y puntos en una línea: la fila sirve aunque la ventana sea baja.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: esHoy ? BoxDecoration(color: p.accent, shape: BoxShape.circle) : null,
              child: Text(
                '${d.day}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontFeatures: _tabular,
                  color: esHoy ? (identical(p, Paleta.oscuro) ? p.bg : Colors.white) : (delMes ? p.text : p.muted), // contraste sobre el acento
                  fontWeight: esHoy ? FontWeight.w600 : null,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 6, top: 9),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final c in Categoria.values)
                      if (cuenta[c] case final n?)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(mainAxisSize: MainAxisSize.min, spacing: 3, children: [for (var i = 0; i < (n > 2 ? 1 : n); i++) _punto(colorCat[c]!)]),
                            if (n > 2) Text('$n', style: TextStyle(fontSize: 9.5, height: 1.3, color: p.muted)),
                          ],
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Captura extends StatefulWidget {
  const _Captura();
  @override
  State<_Captura> createState() => _CapturaState();
}

class _CapturaState extends State<_Captura> {
  final texto = TextEditingController();
  Tipo? forzado;
  String? aviso;

  Future<void> guardarFrase() async {
    if (texto.text.trim().isEmpty) return;
    final e = interpretar(texto.text, DateTime.now(), tipo: forzado);
    await agregar(e);
    texto.clear();
    setState(() {
      forzado = null;
      aviso = e.tipo == Tipo.nota ? 'Guardado en Notas' : 'Guardado';
    });
    captura.requestFocus(); // Enter quita el foco; dejarlo para seguir escribiendo
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => aviso = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final e = texto.text.trim().isEmpty ? null : interpretar(texto.text, DateTime.now(), tipo: forzado);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: BoxDecoration(color: p.panel, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  focusNode: captura,
                  controller: texto,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'Escribí algo: reunión con Juan viernes 10hs, cumple de Ana 14/3…',
                    hintStyle: TextStyle(color: p.muted),
                  ),
                  onChanged: (_) => setState(() => aviso = null),
                  onSubmitted: (_) => guardarFrase(),
                ),
              ),
              for (final t in [Tipo.tarea, Tipo.evento, Tipo.cumple, Tipo.nota]) _tipo(p, t, e?.tipo == t),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 0, 0),
          child: SizedBox(
            height: 18,
            child: Text(
              aviso ?? (e == null ? '' : describir(e, DateTime.now()).join('   ·   ')),
              style: TextStyle(fontSize: 12.5, color: aviso != null ? colorTipo[Tipo.evento] : p.muted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tipo(Paleta p, Tipo t, bool on) {
    final c = colorTipo[t]!;
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () {
          setState(() => forzado = t);
          captura.requestFocus();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: on ? c.withValues(alpha: .16) : null, borderRadius: BorderRadius.circular(99)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              _punto(c),
              Text(
                nombreTipo[t]!,
                style: TextStyle(fontSize: 12.5, color: on ? p.text : p.muted, fontWeight: on ? FontWeight.w600 : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Barra derecha ----------

class _Tareas extends StatefulWidget {
  final List<Entrada> todas;
  final DateTime hoy;
  const _Tareas({required this.todas, required this.hoy});
  @override
  State<_Tareas> createState() => _TareasState();
}

class _TareasState extends State<_Tareas> {
  var filtro = 'Todas';

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final hoy = widget.hoy;
    final filtros = <String, bool Function(Entrada)>{
      'Todas': (_) => true,
      'Importantes': (e) => e.importante,
      'Con fecha': (e) => e.fecha != null && e.repeticion == null,
      'Repetitivas': (e) => e.repeticion != null,
      'Sin fecha': (e) => e.fecha == null,
      'Vencidas': (e) => vencida(e, hoy),
    };
    final lista = pendientes(widget.todas).where(filtros[filtro]!).toList();

    return SizedBox(
      width: 300,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _seccion(context, 'Tareas'),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final f in filtros.keys)
                  InkWell(
                    onTap: () => setState(() => filtro = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: f == filtro ? p.text : Colors.transparent)),
                      ),
                      child: Text(f, style: TextStyle(fontSize: 12.5, color: f == filtro ? p.text : p.muted)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: lista.isEmpty
                  ? Text('Nada pendiente.', style: TextStyle(color: p.muted, fontSize: 13))
                  : ListView(children: [for (final e in lista) _fila(p, e)]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fila(Paleta p, Entrada e) {
    final hoy = widget.hoy;
    final hechaHoy = e.repeticion != null && hecha(e, hoy);
    final venc = vencida(e, hoy);
    final f = e.fecha;
    final meta = e.repeticion != null
        ? [textoRepeticion(e.repeticion!), if (e.hora != null) e.hora!, if (hechaHoy) 'hecha hoy'].join(' · ')
        : f == null
        ? null
        : [venc ? 'Vencida · ${fechaCorta(f, hoy)}' : (mismoDia(f, hoy) ? 'Hoy' : fechaCorta(f, hoy)), if (e.hora != null) e.hora!].join(' · ');
    void marcar() {
      completar(e, hoy, !hechaHoy);
      cambiar();
    }

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: marcar,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(value: hechaHoy, onChanged: (_) => marcar()),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 1,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: e.texto,
                          style: hechaHoy ? TextStyle(decoration: TextDecoration.lineThrough, color: p.muted) : null,
                        ),
                        if (e.importante)
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(padding: const EdgeInsets.only(left: 7), child: _punto(colorCat[Categoria.imp]!)),
                          ),
                      ],
                    ),
                  ),
                  if (meta != null) Text(meta, style: TextStyle(fontSize: 12, color: venc ? _vencida : p.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Notas y Hechas ----------

Widget _pagina(BuildContext context, String t, List<Widget> filas, String vacio) => ListView(
  padding: const EdgeInsets.fromLTRB(36, 24, 36, 24),
  children: [
    _seccion(context, t),
    if (filas.isEmpty) Text(vacio, style: TextStyle(color: Paleta.of(context).muted)),
    ...filas,
  ],
);

Widget _filaLista(Paleta p, {required Widget inicio, required Widget texto, required String fin, VoidCallback? tocar}) => InkWell(
  onTap: tocar,
  child: Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: p.line)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        inicio,
        const SizedBox(width: 12),
        Expanded(child: texto),
        Text(
          fin,
          style: TextStyle(fontSize: 12, color: p.muted, fontFeatures: _tabular),
        ),
      ],
    ),
  ),
);

class _Notas extends StatelessWidget {
  final List<Entrada> todas;
  final DateTime hoy;
  const _Notas({required this.todas, required this.hoy});

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final notas = todas.where((e) => e.tipo == Tipo.nota && !e.borrado).toList()..sort((a, b) => b.actualizado.compareTo(a.actualizado));
    return _pagina(context, 'Notas', [
      for (final e in notas)
        _filaLista(
          p,
          inicio: Padding(padding: const EdgeInsets.only(top: 7), child: _punto(colorTipo[Tipo.nota]!)),
          texto: Text(e.texto),
          fin: fechaCorta(e.fecha ?? e.actualizado, hoy),
        ),
    ], 'Sin notas. Escribí "nota: …" en la captura.');
  }
}

class _Hechas extends StatelessWidget {
  final List<Entrada> todas;
  final DateTime hoy;
  const _Hechas({required this.todas, required this.hoy});

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final hechas = [
      for (final e in todas)
        if (e.tipo == Tipo.tarea && !e.borrado)
          for (final h in e.hechas) (e, h),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    String hm(DateTime h) => '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';
    return _pagina(context, 'Hechas', [
      for (final (e, h) in hechas)
        _filaLista(
          p,
          inicio: Tooltip(
            message: 'Volver a pendiente',
            child: SizedBox(width: 20, height: 20, child: Checkbox(value: true, onChanged: (_) => _deshacer(e, h))),
          ),
          texto: Text(
            e.texto,
            style: TextStyle(decoration: TextDecoration.lineThrough, color: p.muted),
          ),
          fin: '${fechaCorta(h, hoy)}  ${hm(h)}',
          tocar: () => _deshacer(e, h),
        ),
    ], 'Todavía no completaste ninguna tarea.');
  }

  void _deshacer(Entrada e, DateTime h) {
    completar(e, h, false);
    cambiar();
  }
}
