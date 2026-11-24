// Versión para el celular (Android): pestañas abajo, mes plegable, 7 días en tarjetas y captura abajo.
// Todo usa el mismo margen de 16 px (ver `celular` en estilo.dart) para que las pestañas queden alineadas.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'calendario.dart';
import 'captura.dart';
import 'clima.dart';
import 'datos.dart';
import 'dia.dart';
import 'estilo.dart';
import 'pantalla.dart';
import 'sincronizar.dart';

const _margen = 16.0;

Future<void> mainMovil() async {
  archivoDatos = File('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}entradas.json');
  await cargar();
  runApp(const AppMovil());
  iniciarSincronizacion();
  actualizarClima(); // sin esperar: sin internet queda el último guardado
}

class AppMovil extends StatelessWidget {
  const AppMovil({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: modoTema,
    builder: (_, modo, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: tema(Brightness.light),
      darkTheme: tema(Brightness.dark),
      themeMode: ThemeMode.values.asNameMap()[modo] ?? ThemeMode.system,
      home: const PantallaMovil(),
    ),
  );
}

/// Abre una pantalla completa (Hechas) o el detalle de un día, que trae su propio encabezado.
void abrirPagina(BuildContext context, Widget Function(List<Entrada> todas, DateTime hoy) cuerpo) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => Scaffold(
        body: SafeArea(
          child: ValueListenableBuilder(valueListenable: entradas, builder: (_, todas, _) => cuerpo(todas, soloDia(DateTime.now()))),
        ),
      ),
    ),
  );
}

void abrirDia(BuildContext context, DateTime d) => abrirPagina(
  context,
  (todas, hoy) => Padding(
    padding: const EdgeInsets.all(8),
    child: DetalleDia(dia: d, hoy: hoy, todas: todas, cerrar: () => Navigator.pop(context)),
  ),
);

class PantallaMovil extends StatefulWidget {
  const PantallaMovil({super.key});
  @override
  State<PantallaMovil> createState() => _PantallaMovilState();
}

class _PantallaMovilState extends State<PantallaMovil> {
  var pestana = 0;
  final focoNota = FocusNode(); // la captura de Notas: así no comparte foco con la de Inicio durante el fundido

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: entradas,
          builder: (context, todas, _) {
            final hoy = soloDia(DateTime.now());
            return fundido(context, pestana, switch (pestana) {
              0 => InicioMovil(todas: todas, hoy: hoy),
              1 => ListaTareas(todas: todas, hoy: hoy, ancho: null),
              _ => Column(
                children: [
                  Expanded(
                    child: PaginaNotas(todas: todas, hoy: hoy),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(_margen, 0, _margen, 8),
                    child: Captura(nota: true, foco: focoNota),
                  ),
                ],
              ),
            });
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: pestana,
        // "Más" no es una pestaña: abre la ventanita encima de los tres puntos.
        onDestinationSelected: (i) => i == 3 ? _abrirMas(context) : setState(() => pestana = i),
        backgroundColor: p.lateral,
        indicatorColor: p.dia,
        height: 64,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'Tareas'),
          NavigationDestination(icon: Icon(Icons.sticky_note_2_outlined), label: 'Notas'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Más'),
        ],
      ),
    );
  }

  /// Ventanita anclada encima de "Más": Buscar, Hechas y los ajustes.
  void _abrirMas(BuildContext context) {
    final abajo = 64 + MediaQuery.paddingOf(context).bottom + 8;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withValues(alpha: .18),
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (_, animacion, _, hijo) {
        final curva = CurvedAnimation(parent: animacion, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curva,
          child: ScaleTransition(scale: Tween(begin: .94, end: 1.0).animate(curva), alignment: Alignment.bottomRight, child: hijo),
        );
      },
      pageBuilder: (ventana, _, _) {
        final p = Paleta.of(ventana);
        return Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.fromLTRB(_margen, 0, 8, abajo),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 360, maxHeight: MediaQuery.sizeOf(ventana).height * .72),
              child: Material(
                color: p.bg,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: p.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: _Mas(
                  buscar: () async {
                    Navigator.pop(ventana);
                    final e = await buscar(context);
                    if (e == null || !context.mounted) return;
                    if (e.tipo == Tipo.nota) return setState(() => pestana = 2);
                    if (proximaFecha(e, soloDia(DateTime.now())) case final f?) abrirDia(context, f);
                  },
                  hechas: () {
                    Navigator.pop(ventana);
                    abrirPagina(context, (todas, hoy) => PaginaHechas(todas: todas, hoy: hoy));
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Contenido de la ventanita de "Más": accesos arriba y los ajustes del celular debajo.
class _Mas extends StatelessWidget {
  final VoidCallback buscar, hechas;
  const _Mas({required this.buscar, required this.hechas});

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    Widget acceso(IconData icono, String texto, VoidCallback tocar) => InkWell(
      onTap: tocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _margen, vertical: 12),
        child: Row(
          spacing: 12,
          children: [
            Icon(icono, size: 20, color: p.muted),
            Text(texto),
          ],
        ),
      ),
    );
    Widget etiqueta(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(_margen, 18, _margen, 8),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
    );

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        acceso(Icons.search, 'Buscar', buscar),
        acceso(Icons.task_alt, 'Hechas', hechas),
        Divider(height: 12, color: p.line),
        etiqueta('Apariencia'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _margen),
          child: ValueListenableBuilder(
            valueListenable: modoTema,
            builder: (_, modo, _) => SegmentedButton<String>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: 'system', label: Text('Sistema')),
                ButtonSegment(value: 'light', label: Text('Claro')),
                ButtonSegment(value: 'dark', label: Text('Oscuro')),
              ],
              selected: {modo},
              onSelectionChanged: (s) {
                modoTema.value = s.first;
                guardar();
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        const FilaGoogle(estiloTitulo: TextStyle(fontWeight: FontWeight.w600)),
        etiqueta('Ciudad para el clima'),
        ValueListenableBuilder(
          valueListenable: ciudad,
          builder: (context, c, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: _margen),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    c == null ? 'Sin ciudad' : '${c['nombre']} · ${c['detalle']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: p.muted),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final elegida = await elegirCiudad(context);
                    if (elegida == null) return;
                    ciudad.value = {'nombre': elegida.nombre, 'detalle': elegida.detalle, 'lat': elegida.lat, 'lon': elegida.lon};
                    clima.value = {}; // el pronóstico de la ciudad anterior ya no sirve
                    await guardar();
                    await actualizarClima(forzar: true);
                  },
                  child: Text(c == null ? 'Elegir' : 'Cambiar'),
                ),
              ],
            ),
          ),
        ),
        etiqueta('Alarmas por defecto'),
        ValueListenableBuilder(
          valueListenable: alarmasDefecto,
          builder: (context, defecto, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (clave, nombre) in const [
                ('evento', 'Eventos con hora'),
                ('eventoSinHora', 'Eventos sin hora'),
                ('cumple', 'Cumpleaños'),
                ('tarea', 'Tareas con hora'),
              ])
                Padding(
                  padding: const EdgeInsets.fromLTRB(_margen, 0, _margen, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(nombre, style: TextStyle(fontSize: 13, color: p.muted)),
                      EditorAlarmas(
                        alarmas: defecto[clave] ?? const [],
                        cambiar: (l) {
                          alarmasDefecto.value = {...defecto, clave: l};
                          guardar();
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Inicio del celular: mes plegado (una semana) o abierto, los 7 días en tarjetas y la captura abajo.
class InicioMovil extends StatefulWidget {
  final List<Entrada> todas;
  final DateTime hoy;
  const InicioMovil({super.key, required this.todas, required this.hoy});
  @override
  State<InicioMovil> createState() => _InicioMovilState();
}

class _InicioMovilState extends State<InicioMovil> {
  var mesAbierto = false;
  late var mes = DateTime(widget.hoy.year, widget.hoy.month);

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _mes(p),
        Divider(height: 1, color: p.line),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: clima,
            builder: (_, porDia, _) => ListView(
              padding: const EdgeInsets.fromLTRB(_margen, 12, _margen, 12),
              children: [for (var i = 0; i < 7; i++) _dia(p, DateTime(widget.hoy.year, widget.hoy.month, widget.hoy.day + i), i, porDia)],
            ),
          ),
        ),
        const Padding(padding: EdgeInsets.fromLTRB(_margen, 0, _margen, 8), child: Captura()),
      ],
    );
  }

  Widget _mes(Paleta p) {
    final h = widget.hoy;
    // Plegado: la semana de hoy. Abierto: las 6 semanas del mes elegido.
    final inicio = mesAbierto ? DateTime(mes.year, mes.month, 2 - mes.weekday) : DateTime(h.year, h.month, h.day - h.weekday + 1);
    final semanas = mesAbierto ? 6 : 1;
    final titulo = mesAbierto ? mes : DateTime(h.year, h.month);
    return Padding(
      padding: const EdgeInsets.fromLTRB(_margen, 2, 4, 8), // el título queda a la altura de "Tareas" y "Notas"
      child: Column(
        children: [
          Row(
            children: [
              Text('${nombresMes[titulo.month - 1]} ${titulo.year}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (mesAbierto) ...[
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  color: p.muted,
                  tooltip: 'Mes anterior',
                  onPressed: () => setState(() => mes = DateTime(mes.year, mes.month - 1)),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  color: p.muted,
                  tooltip: 'Mes siguiente',
                  onPressed: () => setState(() => mes = DateTime(mes.year, mes.month + 1)),
                ),
              ],
              IconButton(
                icon: Icon(mesAbierto ? Icons.expand_less : Icons.expand_more),
                color: p.muted,
                tooltip: mesAbierto ? 'Ver solo esta semana' : 'Ver el mes',
                onPressed: () => setState(() {
                  mesAbierto = !mesAbierto;
                  mes = DateTime(h.year, h.month);
                }),
              ),
            ],
          ),
          AnimatedSize(
            duration: mov(context, 260),
            curve: llegada,
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(right: _margen - 4),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final d in diasCortos)
                        Expanded(
                          child: Center(
                            child: Text(d, style: TextStyle(fontSize: 11.5, color: p.muted)),
                          ),
                        ),
                    ],
                  ),
                  for (var s = 0; s < semanas; s++)
                    Row(
                      children: [for (var i = 0; i < 7; i++) Expanded(child: _celda(p, DateTime(inicio.year, inicio.month, inicio.day + s * 7 + i), titulo))],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _celda(Paleta p, DateTime d, DateTime delMes) {
    final esHoy = mismoDia(d, widget.hoy);
    final cuenta = <Categoria, int>{};
    for (final e in delDia(widget.todas, d)) {
      cuenta.update(categoria(e), (n) => n + 1, ifAbsent: () => 1);
    }
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => abrirDia(context, d),
      child: Opacity(
        opacity: !mesAbierto || d.month == delMes.month ? 1 : .4,
        child: SizedBox(
          height: 46,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 4,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: esHoy ? BoxDecoration(color: p.accent, shape: BoxShape.circle) : null,
                child: Text(
                  '${d.day}',
                  style: TextStyle(
                    fontSize: 13,
                    fontFeatures: tabular,
                    color: esHoy ? (identical(p, Paleta.oscuro) ? p.bg : Colors.white) : null,
                    fontWeight: esHoy ? FontWeight.w600 : null,
                  ),
                ),
              ),
              SizedBox(
                height: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 3,
                  children: [
                    for (final c in Categoria.values)
                      if (cuenta.containsKey(c)) punto(colorCat[c]!, 5),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tarjeta de un día: encabezado con el clima, eventos y cumpleaños, y las tareas con su casilla.
  Widget _dia(Paleta p, DateTime d, int i, Map<String, List<num>> porDia) {
    final hoy = widget.hoy;
    final agenda = delDia(widget.todas, d).where((e) => e.tipo != Tipo.tarea).toList();
    // Las tareas que se repiten aparecen solo hoy: en los demás días llenarían todas las tarjetas.
    final tareas = tareasDelDia(widget.todas, d, hoy).where((e) => i == 0 || e.repeticion == null).toList();
    final nombre = switch (i) {
      0 => 'Hoy',
      1 => 'Mañana',
      _ => nombresDia[d.weekday - 1],
    };
    final c = porDia[diaClave(d)];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: p.dia,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: i == 0 ? p.accent.withValues(alpha: .55) : Colors.transparent),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => abrirDia(context, d),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      nombre,
                      style: TextStyle(fontWeight: FontWeight.w600, color: i == 0 ? p.accent : null),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${d.day}/${d.month}',
                      style: TextStyle(color: p.muted, fontFeatures: tabular),
                    ),
                    const Spacer(),
                    if (c != null) ...[
                      Icon(aspecto(c[0].toInt()).$1, size: 15, color: p.muted),
                      const SizedBox(width: 5),
                      Text(
                        temperaturas(c),
                        style: TextStyle(fontSize: 12.5, color: p.muted, fontFeatures: tabular),
                      ),
                    ],
                  ],
                ),
                if (agenda.isEmpty && tareas.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Día libre', style: TextStyle(fontSize: 13, color: p.muted)),
                  ),
                for (final e in agenda)
                  Aterriza(
                    entrada: e,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          SizedBox(width: 22, child: Center(child: punto(colorCat[categoria(e)]!))),
                          const SizedBox(width: 8),
                          if (e.hora != null)
                            Text(
                              '${e.hora}  ',
                              style: TextStyle(color: p.muted, fontFeatures: tabular),
                            ),
                          Expanded(child: Text(tituloLargo(e, d), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                  ),
                for (final e in tareas)
                  Aterriza(
                    entrada: e,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(value: marcando.contains(e.id), onChanged: (v) => marcar(context, e, d, v!)),
                          ),
                          const SizedBox(width: 8),
                          if (e.hora != null)
                            Text(
                              '${e.hora}  ',
                              style: TextStyle(color: p.muted, fontFeatures: tabular),
                            ),
                          Expanded(child: Text(e.texto, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          if (e.importante) Padding(padding: const EdgeInsets.only(left: 6), child: punto(colorCat[Categoria.imp]!)),
                          if (vencida(e, hoy)) Text('  vencida', style: TextStyle(fontSize: 12, color: colorVencida)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
