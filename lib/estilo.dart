// Colores, tema y piezas visuales compartidas.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'alarmas.dart';
import 'calendario.dart';
import 'datos.dart';

class Paleta {
  final Color bg, line, text, muted, panel, hover, accent, dia, lateral;
  const Paleta(this.bg, this.line, this.text, this.muted, this.panel, this.hover, this.accent, this.dia, this.lateral);
  // panel tiñe apenas la captura, dia es el beige de los 7 días, lateral el tono de las barras.
  // muted pasa 4.5:1 sobre bg, dia y lateral.
  static const claro = Paleta(
    Color(0xFFFAF7F2),
    Color(0xFFECE6DC),
    Color(0xFF2F2A23),
    Color(0xFF6A6156),
    Color(0xFFF2EDE4),
    Color(0xFFF4EFE7),
    Color(0xFFB0643A),
    Color(0xFFEEE6D8),
    Color(0xFFF2ECE2),
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
    Color(0xFF151311),
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
const colorVencida = Color(0xFF9A6E4C);
const nombresMes = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
const diasCortos = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const tabular = [FontFeature.tabularFigures()];

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
    // Avisos con "Deshacer": invertidos respecto al fondo, el acento del otro modo para que contraste.
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      width: 460,
      elevation: 0,
      backgroundColor: p.text,
      contentTextStyle: TextStyle(fontFamily: 'Segoe UI', fontSize: 13.5, color: p.bg),
      actionTextColor: identical(p, Paleta.oscuro) ? Paleta.claro.accent : Paleta.oscuro.accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(color: p.text, borderRadius: BorderRadius.circular(6)),
      textStyle: TextStyle(fontFamily: 'Segoe UI', fontSize: 12, color: p.bg),
    ),
  );
}

const nombresDia = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

/// Texto con hora y título que se edita con un clic: Enter guarda, Esc cancela, clic afuera guarda.
class TextoEditable extends StatefulWidget {
  final Entrada entrada;
  final String texto; // lo que se muestra (puede sumar la edad); se edita entrada.texto
  final String? hora;
  final TextStyle? estilo;
  const TextoEditable({super.key, required this.entrada, required this.texto, this.hora, this.estilo});
  @override
  State<TextoEditable> createState() => _TextoEditableState();
}

class _TextoEditableState extends State<TextoEditable> {
  TextEditingController? editor;

  void guardarTexto() {
    final t = editor?.text.trim() ?? '';
    final e = widget.entrada;
    if (t.isNotEmpty && t != e.texto) {
      e.texto = t;
      e.actualizado = DateTime.now();
      cambiar();
    }
    setState(() => editor = null);
  }

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final ed = editor;
    if (ed != null) {
      return Focus(
        onKeyEvent: (_, k) {
          if (k is KeyDownEvent && k.logicalKey == LogicalKeyboardKey.escape) {
            setState(() => editor = null);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: ed,
          autofocus: true,
          style: widget.estilo,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 2),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: p.line)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: p.accent)),
          ),
          onSubmitted: (_) => guardarTexto(),
          onTapOutside: (_) => guardarTexto(),
        ),
      );
    }
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: GestureDetector(
        onTap: () => setState(() => editor = TextEditingController(text: widget.entrada.texto)),
        child: Text.rich(
          TextSpan(
            children: [
              if (widget.hora != null)
                TextSpan(
                  text: '${widget.hora}  ',
                  style: TextStyle(color: p.muted, fontFeatures: tabular),
                ),
              TextSpan(text: widget.texto),
            ],
          ),
          style: widget.estilo,
        ),
      ),
    );
  }
}

/// Fila que muestra una × para borrar al pasar el mouse.
class ConBorrar extends StatefulWidget {
  final Entrada entrada;
  final Widget child;
  const ConBorrar({super.key, required this.entrada, required this.child});
  @override
  State<ConBorrar> createState() => _ConBorrarState();
}

class _ConBorrarState extends State<ConBorrar> {
  var encima = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => encima = true),
    onExit: (_) => setState(() => encima = false),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: widget.child),
        AnimatedOpacity(
          opacity: encima ? 1 : 0,
          duration: const Duration(milliseconds: 120),
          child: IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: 'Eliminar',
            color: Paleta.of(context).muted,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(minimumSize: const Size(28, 28), padding: EdgeInsets.zero),
            onPressed: () => borrar(context, widget.entrada),
          ),
        ),
      ],
    ),
  );
}

/// Alarmas editables: cada una con su ×, y una caja para agregar ("30 min antes", "09:00", "día anterior 20:00").
class EditorAlarmas extends StatefulWidget {
  final List<String> alarmas;
  final ValueChanged<List<String>> cambiar;
  const EditorAlarmas({super.key, required this.alarmas, required this.cambiar});
  @override
  State<EditorAlarmas> createState() => _EditorAlarmasState();
}

class _EditorAlarmasState extends State<EditorAlarmas> {
  final texto = TextEditingController();
  String? error;

  void agregarAlarma() {
    final a = leerAlarma(texto.text);
    if (a == null) {
      setState(() => error = texto.text.trim().isEmpty ? null : 'No entendí "${texto.text.trim()}"');
      return;
    }
    if (!widget.alarmas.contains(a)) widget.cambiar([...widget.alarmas, a]);
    texto.clear();
    setState(() => error = null);
  }

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final a in widget.alarmas)
              Container(
                padding: const EdgeInsets.fromLTRB(10, 3, 5, 3),
                decoration: BoxDecoration(color: p.panel, borderRadius: BorderRadius.circular(99)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    Text(textoAlarma(a), style: const TextStyle(fontSize: 12.5)),
                    IconButton(
                      icon: const Icon(Icons.close, size: 13),
                      tooltip: 'Quitar',
                      color: p.muted,
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(minimumSize: const Size(22, 22), padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      onPressed: () => widget.cambiar([...widget.alarmas]..remove(a)),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: 210,
              child: TextField(
                controller: texto,
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: widget.alarmas.isEmpty ? 'Sin alarma · agregar: 09:00, 1 h antes…' : 'Agregar otra…',
                  hintStyle: TextStyle(color: p.muted),
                ),
                onSubmitted: (_) => agregarAlarma(),
              ),
            ),
          ],
        ),
        if (error != null) Text(error!, style: TextStyle(fontSize: 12, color: colorCat[Categoria.imp])),
      ],
    );
  }
}

void avisar(BuildContext c, String mensaje, VoidCallback deshacer) {
  final m = ScaffoldMessenger.of(c);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(mensaje, maxLines: 1, overflow: TextOverflow.ellipsis),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(label: 'Deshacer', onPressed: deshacer),
    ),
  );
}

/// Borrado lógico (queda en el archivo para la sincronización futura), con Deshacer.
void borrar(BuildContext c, Entrada e) {
  void poner(bool b) {
    e.borrado = b;
    e.actualizado = DateTime.now();
    cambiar();
  }

  poner(true);
  avisar(c, 'Eliminado: ${e.texto}', () => poner(false));
}

/// Completa o desmarca una tarea en el día [d], con Deshacer.
void marcar(BuildContext c, Entrada e, DateTime d, bool si) {
  final antes = [...e.hechas];
  completar(e, d, si);
  cambiar();
  avisar(c, si ? 'Hecha: ${e.texto}' : 'Vuelve a pendiente: ${e.texto}', () {
    e.hechas = antes;
    e.actualizado = DateTime.now();
    cambiar();
  });
}

Widget tituloSeccion(BuildContext c, String t, {Widget? extra}) => Padding(
  padding: const EdgeInsets.only(bottom: 14),
  child: Row(
    children: [
      Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      const Spacer(),
      ?extra,
    ],
  ),
);

Widget punto(Color c, [double t = 6]) => Container(
  width: t,
  height: t,
  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
);
