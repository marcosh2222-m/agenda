import 'dart:io';

import 'package:agenda/captura.dart';
import 'package:agenda/datos.dart';
import 'package:agenda/dia.dart';
import 'package:agenda/estilo.dart';
import 'package:agenda/pantalla.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  cajita();

  testWidgets('detalle del día, borrar con Deshacer y atajos', (t) async {
    archivoDatos = File('${Directory.systemTemp.createTempSync('agenda').path}/entradas.json'); // nunca el archivo real
    final ahora = DateTime.now();
    entradas.value = [interpretar('dentista mañana 10hs', ahora), interpretar('comprar pan hoy', ahora)];
    final dentista = entradas.value.first;
    t.view.physicalSize = const Size(1440, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: tema(Brightness.light),
        home: const Pantalla(ajustes: SizedBox()),
      ),
    );

    // Clic en el día → detalle; borrar y deshacer.
    await t.tap(find.text('Dentista'));
    await t.pumpAndSettle();
    expect(find.byType(DetalleDia), findsOneWidget);
    await t.tap(find.descendant(of: find.byType(DetalleDia), matching: find.byTooltip('Eliminar')).first);
    await t.pumpAndSettle();
    expect(dentista.borrado, isTrue);
    await t.tap(find.text('Deshacer'));
    await t.pump();
    expect(dentista.borrado, isFalse);

    // Esc cierra el detalle.
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.byType(DetalleDia), findsNothing);

    // N pone el cursor en la captura, sin escribir la letra.
    await t.sendKeyEvent(LogicalKeyboardKey.keyN);
    await t.pumpAndSettle();
    expect(captura.hasFocus, isTrue);
    expect(find.text('n'), findsNothing);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(captura.hasFocus, isFalse);

    // → pasa al mes siguiente.
    final siguiente = DateTime(ahora.year, ahora.month + 1);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    expect(find.text('${nombresMes[siguiente.month - 1]} ${siguiente.year}'), findsOneWidget);

    // Ctrl + K busca; Enter abre el primero.
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyK);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await t.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)), 'dentis');
    await t.pump();
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(DetalleDia), findsOneWidget);
  });
}

void cajita() {
  testWidgets('la cajita abre en Nota y Tab pasa a eventos', (t) async {
    archivoDatos = File('${Directory.systemTemp.createTempSync('agenda').path}/entradas.json');
    entradas.value = [];
    var cerrada = false;
    await t.pumpWidget(
      MaterialApp(
        theme: tema(Brightness.light),
        home: Cajita(cerrar: () => cerrada = true),
      ),
    );
    await t.pump();
    // Nota: se guarda tal cual, sin buscar fechas ni horas.
    await t.enterText(find.byType(TextField), 'ideas para el viaje el martes 10hs');
    await t.testTextInput.receiveAction(TextInputAction.done);
    for (var i = 0; i < 10; i++) {
      // el guardado en disco avanza con tiempo real, paso a paso
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
      await t.pump();
    }
    expect(
      [entradas.value.single.tipo, entradas.value.single.texto, entradas.value.single.fecha, cerrada],
      [Tipo.nota, 'Ideas para el viaje el martes 10hs', null, true],
    );
    // Tab: eventos y tareas, con la interpretación de siempre.
    await t.tap(find.byType(TextField));
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    await t.enterText(find.byType(TextField), 'dentista el martes 10hs');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect([entradas.value.last.tipo, entradas.value.last.hora], [Tipo.evento, '10:00']);
  });
}
