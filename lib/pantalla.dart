// Pantalla principal de PC (ver docs/boceto-pc.html).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'alarmas.dart';
import 'calendario.dart';
import 'captura.dart';
import 'clima.dart';
import 'datos.dart';
import 'dia.dart';
import 'estilo.dart';
import 'voz.dart';

final captura = FocusNode();

/// Mientras Ajustes graba un atajo, los atajos de la ventana se apagan.
var grabandoAtajo = false;

enum Seccion { inicio, notas, hechas, ajustes }

class Pantalla extends StatefulWidget {
  final Widget ajustes;
  const Pantalla({super.key, required this.ajustes});
  @override
  State<Pantalla> createState() => _PantallaState();
}

class _PantallaState extends State<Pantalla> {
  var seccion = Seccion.inicio;
  final inicio = GlobalKey<_InicioState>();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_tecla);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_tecla);
    super.dispose();
  }

  // Atajos de toda la ventana. Mientras se escribe solo valen Ctrl + K y Esc, para no comerse letras ni flechas.
  bool _tecla(KeyEvent k) {
    if (grabandoAtajo) return false; // Ajustes está grabando un atajo nuevo
    if (k is! KeyDownEvent || !(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    final tecla = k.logicalKey;
    if (HardwareKeyboard.instance.isControlPressed && tecla == LogicalKeyboardKey.keyK) {
      _buscar();
      return true;
    }
    final foco = FocusManager.instance.primaryFocus;
    if (foco?.context?.findAncestorStateOfType<EditableTextState>() != null) {
      if (tecla == LogicalKeyboardKey.escape) foco!.unfocus();
      return false;
    }
    if (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isAltPressed) return false;
    if (tecla == LogicalKeyboardKey.keyN) {
      setState(() => seccion = Seccion.inicio);
      inicio.currentState?.cerrar();
      WidgetsBinding.instance.addPostFrameCallback((_) => captura.requestFocus());
      return true;
    }
    if (seccion == Seccion.inicio && (tecla == LogicalKeyboardKey.arrowLeft || tecla == LogicalKeyboardKey.arrowRight)) {
      inicio.currentState?.moverMes(tecla == LogicalKeyboardKey.arrowLeft ? -1 : 1);
      return true;
    }
    if (tecla == LogicalKeyboardKey.escape) return inicio.currentState?.cerrar() ?? false;
    return false;
  }

  Future<void> _buscar() async {
    final e = await buscar(context);
    if (e == null || !mounted) return;
    final f = proximaFecha(e, soloDia(DateTime.now()));
    setState(() => seccion = e.tipo == Tipo.nota ? Seccion.notas : Seccion.inicio);
    if (e.tipo != Tipo.nota && f != null) WidgetsBinding.instance.addPostFrameCallback((_) => inicio.currentState?.abrir(f));
  }

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
              ColoredBox(color: p.lateral, child: _nav(p)),
              VerticalDivider(width: 1, thickness: 1, color: p.line),
              Expanded(
                child: switch (seccion) {
                  Seccion.inicio => _Inicio(key: inicio, todas: todas, hoy: hoy),
                  Seccion.notas => _Notas(todas: todas, hoy: hoy),
                  Seccion.hechas => _Hechas(todas: todas, hoy: hoy),
                  Seccion.ajustes => Padding(padding: const EdgeInsets.all(32), child: widget.ajustes),
                },
              ),
              VerticalDivider(width: 1, thickness: 1, color: p.line),
              ColoredBox(
                color: p.lateral,
                child: _Tareas(todas: todas, hoy: hoy),
              ),
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
          decoration: on ? BoxDecoration(color: p.dia, borderRadius: BorderRadius.circular(6)) : null,
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
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: _buscar,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Buscar',
                        style: TextStyle(color: p.muted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('Ctrl K', style: TextStyle(fontSize: 11.5, color: p.muted)),
                  ],
                ),
              ),
            ),
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
  const _Inicio({super.key, required this.todas, required this.hoy});
  @override
  State<_Inicio> createState() => _InicioState();
}

class _InicioState extends State<_Inicio> {
  late var mes = DateTime(widget.hoy.year, widget.hoy.month);
  DateTime? abierto; // día con el detalle abierto

  void abrir(DateTime d) => setState(() {
    abierto = d;
    mes = DateTime(d.year, d.month);
  });

  bool cerrar() {
    if (abierto == null) return false;
    setState(() => abierto = null);
    return true;
  }

  void moverMes(int n) => setState(() {
    abierto = null;
    mes = DateTime(mes.year, mes.month + n);
  });

  @override
  // Todo entra en la ventana: los 7 días toman 2/5 del alto y el mes el resto; lo que no cabe en un día se desplaza dentro de él.
  // El detalle de un día se abre encima de los dos.
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(36, 24, 36, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Captura(),
        const SizedBox(height: 20),
        Expanded(
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tituloSeccion(context, 'Próximos 7 días'),
                  Expanded(flex: 2, child: _semana(context)),
                  const SizedBox(height: 24),
                  tituloSeccion(context, '${nombresMes[mes.month - 1]} ${mes.year}', extra: _flechas(Paleta.of(context))),
                  Expanded(flex: 3, child: _mes(context)),
                ],
              ),
              if (abierto case final d?)
                Positioned.fill(
                  child: DetalleDia(key: ValueKey(d), dia: d, hoy: widget.hoy, todas: widget.todas, cerrar: cerrar),
                ),
            ],
          ),
        ),
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

  Widget _dia(Paleta p, DateTime d, bool esHoy) => _clic(d, _diaCuerpo(p, d, esHoy));

  /// Ícono y "26° / 15°"; nada si no hay ciudad o no hay pronóstico para ese día.
  Widget _climaDia(Paleta p, DateTime d) => ValueListenableBuilder(
    valueListenable: clima,
    builder: (context, porDia, _) {
      final c = porDia[diaClave(d)];
      if (c == null) return const SizedBox.shrink();
      final (icono, palabra) = aspecto(c[0].toInt());
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Tooltip(
          message: palabra,
          child: Row(
            spacing: 5,
            children: [
              Icon(icono, size: 14, color: p.muted),
              Flexible(
                child: Text(
                  temperaturas(c),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(fontSize: 12, color: p.muted, fontFeatures: tabular),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _clic(DateTime d, Widget w) => InkWell(borderRadius: BorderRadius.circular(8), onTap: () => abrir(d), child: w);

  Widget _diaCuerpo(Paleta p, DateTime d, bool esHoy) {
    final items = delDia(widget.todas, d).where((e) => categoria(e) != Categoria.tarea);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
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
                esHoy ? 'Hoy' : diasCortos[d.weekday - 1],
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: esHoy ? p.accent : p.text),
              ),
              const SizedBox(width: 6),
              Text(
                '${d.day}',
                style: TextStyle(fontSize: 13, color: esHoy ? p.accent : p.muted, fontFeatures: tabular),
              ),
            ],
          ),
          _climaDia(p, d),
          const SizedBox(height: 10),
          for (final e in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 6, right: 5), child: punto(colorCat[categoria(e)]!, 5)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e.hora != null)
                          Text(
                            e.hora!,
                            style: TextStyle(fontSize: 11.5, height: 1.35, color: p.muted, fontFeatures: tabular),
                          ),
                        Text(tituloCorto(e, d), style: const TextStyle(fontSize: 12.5, height: 1.35)),
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
    Widget boton(IconData i, String tip, int n) =>
        IconButton(icon: Icon(i, size: 18), color: p.muted, tooltip: tip, visualDensity: VisualDensity.compact, onPressed: () => moverMes(n));
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
            for (final d in diasCortos)
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

  Widget _celda(Paleta p, DateTime d) => _clic(d, _celdaCuerpo(p, d));

  Widget _celdaCuerpo(Paleta p, DateTime d) {
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
                  fontFeatures: tabular,
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
                            Row(mainAxisSize: MainAxisSize.min, spacing: 3, children: [for (var i = 0; i < (n > 2 ? 1 : n); i++) punto(colorCat[c]!)]),
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

/// Cajita flotante del atajo global: solo la captura. Enter guarda y cierra; Esc cierra sin guardar.
class Cajita extends StatefulWidget {
  final VoidCallback cerrar;
  const Cajita({super.key, required this.cerrar});
  @override
  State<Cajita> createState() => _CajitaState();
}

/// Abre en Nota; Tab cambia a eventos y tareas.
class _CajitaState extends State<Cajita> {
  var nota = true;

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    Widget modo(String t, bool esNota) => InkWell(
      onTap: () => setState(() => nota = esNota),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: nota == esNota ? p.text : Colors.transparent)),
        ),
        child: Text(t, style: TextStyle(fontSize: 12.5, color: nota == esNota ? p.text : p.muted)),
      ),
    );
    return Scaffold(
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): widget.cerrar,
          const SingleActivator(LogicalKeyboardKey.tab): () => setState(() => nota = !nota),
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Row(
                  spacing: 14,
                  children: [
                    modo('Nota', true),
                    modo('Evento o tarea', false),
                    Text('Tab cambia', style: TextStyle(fontSize: 11.5, color: p.muted)),
                  ],
                ),
              ),
              Captura(alGuardar: widget.cerrar, nota: nota),
            ],
          ),
        ),
      ),
    );
  }
}

class Captura extends StatefulWidget {
  final VoidCallback? alGuardar; // la cajita flotante se cierra al guardar
  final bool nota; // guarda el texto tal cual como nota, sin buscar fechas ni horas
  const Captura({super.key, this.alGuardar, this.nota = false});
  @override
  State<Captura> createState() => _CapturaState();
}

class _CapturaState extends State<Captura> {
  final texto = TextEditingController();
  Tipo? forzado;
  String? aviso;

  Future<void> guardarFrase() async {
    if (texto.text.trim().isEmpty) return;
    final e = widget.nota ? Entrada(texto: formatear(texto.text.trim(), Tipo.nota), tipo: Tipo.nota) : interpretar(texto.text, DateTime.now(), tipo: forzado);
    await agregar(e);
    texto.clear();
    if (widget.alGuardar case final cerrar?) {
      setState(() => forzado = null);
      return cerrar();
    }
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
    final e = texto.text.trim().isEmpty || widget.nota ? null : interpretar(texto.text, DateTime.now(), tipo: forzado); // la nota no se interpreta
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(6, 8, 8, 8),
          decoration: BoxDecoration(color: p.panel, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              _microfono(p),
              Expanded(
                child: TextField(
                  focusNode: captura,
                  autofocus: widget.alGuardar != null,
                  controller: texto,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: widget.nota ? 'Escribí una nota…' : 'Escribí algo: reunión con Juan viernes 10hs, cumple de Ana 14/3…',
                    hintStyle: TextStyle(color: p.muted),
                  ),
                  onChanged: (_) => setState(() => aviso = null),
                  onSubmitted: (_) => guardarFrase(),
                ),
              ),
              if (!widget.nota)
                for (final t in [Tipo.tarea, Tipo.evento, Tipo.cumple, Tipo.nota]) _tipo(p, t, e?.tipo == t),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 0, 0),
          child: SizedBox(
            height: 18,
            child: ValueListenableBuilder(
              valueListenable: avisoVoz,
              builder: (context, voz, _) => Text(
                voz ?? aviso ?? (e == null ? '' : describir(e, DateTime.now()).join('   ·   ')),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: voz == null && aviso != null ? colorTipo[Tipo.evento] : p.muted),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Micrófono: dicta en español con Whisper; lo dictado se suma a lo que haya escrito.
  Widget _microfono(Paleta p) => ListenableBuilder(
    listenable: Listenable.merge([estadoVoz, progresoVoz]),
    builder: (context, _) {
      Widget girando([double? v]) => SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(value: v, strokeWidth: 2, color: p.muted),
      );
      final (icono, ayuda) = switch (estadoVoz.value) {
        EstadoVoz.listo => (Icon(Icons.mic_none, size: 18, color: p.muted), 'Dictar en español'),
        EstadoVoz.descargando => (girando(progresoVoz.value), 'Descargando el reconocimiento de voz (157 MB, una sola vez)…'),
        EstadoVoz.grabando => (Icon(Icons.stop_circle_outlined, size: 20, color: colorCat[Categoria.imp]), 'Terminar de dictar'),
        EstadoVoz.transcribiendo => (girando(), 'Pasando a texto…'),
      };
      return IconButton(
        icon: icono,
        tooltip: ayuda,
        visualDensity: VisualDensity.compact,
        onPressed: () async {
          final dicho = await tocarMicrofono();
          if (dicho == null || dicho.isEmpty || !mounted) return;
          texto.text = [texto.text.trim(), dicho].where((s) => s.isNotEmpty).join(' ');
          texto.selection = TextSelection.collapsed(offset: texto.text.length);
          setState(() => aviso = null);
          captura.requestFocus();
        },
      );
    },
  );

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
              punto(c),
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
            tituloSeccion(context, 'Tareas'),
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
        ? [
            textoRepeticion(e.repeticion!),
            if (e.hora != null) e.hora!,
            if (e.alarmas case final a? when a.isNotEmpty && e.hora == null) a.map(textoAlarma).join(', '),
            if (hechaHoy) 'hecha hoy',
          ].join(' · ')
        : f == null
        ? null
        : [venc ? 'Vencida · ${fechaCorta(f, hoy)}' : (mismoDia(f, hoy) ? 'Hoy' : fechaCorta(f, hoy)), if (e.hora != null) e.hora!].join(' · ');
    void tocar() => marcar(context, e, hoy, !hechaHoy);

    return ConBorrar(
      entrada: e,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: tocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(value: hechaHoy, onChanged: (_) => tocar()),
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
                              child: Padding(padding: const EdgeInsets.only(left: 7), child: punto(colorCat[Categoria.imp]!)),
                            ),
                        ],
                      ),
                    ),
                    if (meta != null) Text(meta, style: TextStyle(fontSize: 12, color: venc ? colorVencida : p.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Notas y Hechas ----------

Widget _pagina(BuildContext context, String t, List<Widget> filas, String vacio) => ListView(
  padding: const EdgeInsets.fromLTRB(36, 24, 36, 24),
  children: [
    tituloSeccion(context, t),
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
          style: TextStyle(fontSize: 12, color: p.muted, fontFeatures: tabular),
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
        ConBorrar(
          entrada: e,
          child: _filaLista(
            p,
            inicio: Padding(padding: const EdgeInsets.only(top: 7), child: punto(colorTipo[Tipo.nota]!)),
            texto: TextoEditable(entrada: e, texto: e.texto),
            fin: fechaCorta(e.fecha ?? e.actualizado, hoy),
          ),
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
            child: SizedBox(width: 20, height: 20, child: Checkbox(value: true, onChanged: (_) => marcar(context, e, h, false))),
          ),
          texto: Text(
            e.texto,
            style: TextStyle(decoration: TextDecoration.lineThrough, color: p.muted),
          ),
          fin: '${fechaCorta(h, hoy)}  ${hm(h)}',
          tocar: () => marcar(context, e, h, false),
        ),
    ], 'Todavía no completaste ninguna tarea.');
  }
}
