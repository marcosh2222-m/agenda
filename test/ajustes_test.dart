import 'package:agenda/estilo.dart';
import 'package:agenda/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Ajustes entra en una ventana baja: se desplaza', (t) async {
    t.view.physicalSize = const Size(800, 450);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: tema(Brightness.light),
        home: const Scaffold(
          body: Padding(padding: EdgeInsets.all(32), child: Ajustes()),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    await t.scrollUntilVisible(find.text('Registro'), 100, scrollable: find.byType(Scrollable).first);
    expect(find.text('Registro'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 500))); // termina la consulta al registro de Windows
    await t.pump(const Duration(seconds: 1));
  });
}
