import 'package:agenda/alarmas.dart';
import 'package:agenda/calendario.dart';
import 'package:agenda/captura.dart';
import 'package:agenda/datos.dart';
import 'package:flutter_test/flutter_test.dart';

final ahora = DateTime(2026, 11, 21, 12); // sábado
Entrada f(String frase) => interpretar(frase, ahora);
List<String> textos(List<Aviso> l) => [for (final a in l) '${a.entrada.texto} ${a.cuando.day} ${a.cuando.hour}:${a.cuando.minute}'];

void main() {
  setUp(() {
    alarmasDefecto.value = Map.of(alarmasDeFabrica);
    pospuestas.clear();
  });

  resumen();

  test('leer y mostrar alarmas', () {
    expect([leerAlarma('30 min antes'), leerAlarma('1 h antes'), leerAlarma('a la hora')], ['antes 30', 'antes 60', 'antes 0']);
    expect(
      [leerAlarma('9hs'), leerAlarma('09:30'), leerAlarma('día anterior 20:00'), leerAlarma('25:00'), leerAlarma('cualquier cosa')],
      ['0 09:00', '0 09:30', '-1 20:00', null, null],
    );
    expect(['antes 90', 'antes 60', 'antes 0', '0 09:00', '-1 20:00'].map(textoAlarma), [
      '90 min antes',
      '1 h antes',
      'a la hora',
      '09:00',
      'día anterior 20:00',
    ]);
  });

  test('valores por defecto por tipo', () {
    expect(alarmasDe(f('dentista el lunes 10hs')), ['antes 60']);
    expect(alarmasDe(f('reunión el lunes')), isEmpty); // es tarea sin hora: sin alarma
    expect(alarmasDe(f('cumple Ana 23/11')), ['-1 20:00', '0 09:00']);
    expect(alarmasDe(f('llamar al banco mañana a las 10')), ['antes 0']);
    expect(alarmasDe(f('dentista el lunes 10hs avisame 30 min antes')), ['antes 30']);
  });

  test('tarea con varias horas', () {
    final r = f('tomar remedio todos los días 8:00, 14:00 y 22:00');
    expect(
      [r.texto, r.hora, r.alarmas, r.fecha],
      [
        'Tomar remedio',
        null,
        ['0 08:00', '0 14:00', '0 22:00'],
        DateTime(2026, 11, 21),
      ],
    );
    expect(describir(r, ahora).last, 'avisa 08:00, 14:00, 22:00');
  });

  test('cuándo suena', () {
    final dentista = f('dentista el lunes 10hs'); // lun 23
    final ana = f('cumple Ana 23/11');
    final remedio = f('tomar remedio todos los días 8:00 y 22:00');
    final todas = [dentista, ana, remedio];
    // Sábado 12:00 → lunes 12:00
    expect(
      textos(avisosEntre(todas, ahora, DateTime(2026, 11, 23, 12))),
      unorderedEquals([
        'Tomar remedio 21 22:0',
        'Tomar remedio 22 8:0',
        'Ana 22 20:0', // el día anterior
        'Tomar remedio 22 22:0',
        'Tomar remedio 23 8:0',
        'Ana 23 9:0',
        'Dentista 23 9:0', // 1 h antes
      ]),
    );
    // Completar la tarea del día corta las alarmas que faltan de ese día.
    completar(remedio, DateTime(2026, 11, 21), true);
    expect(textos(avisosEntre([remedio], ahora, DateTime(2026, 11, 21, 23))), isEmpty);
  });

  test('revisar: suspensión y pospuestas', () {
    final dentista = f('dentista el lunes 10hs');
    // Revisión normal, cada 30 s.
    var r = revisar([dentista], DateTime(2026, 11, 23, 8, 59, 50), DateTime(2026, 11, 23, 9, 0, 20));
    expect([r.ahora.length, r.perdidas.length], [1, 0]);
    // La PC estuvo suspendida de 8:00 a 11:00: la de las 9:00 va como perdida.
    r = revisar([dentista], DateTime(2026, 11, 23, 8), DateTime(2026, 11, 23, 11));
    expect([r.ahora.length, r.perdidas.length], [0, 1]);
    // Posponer: vuelve a sonar a la hora nueva, una sola vez.
    pospuestas.add(Aviso(dentista, DateTime(2026, 11, 23), DateTime(2026, 11, 23, 9, 10)));
    r = revisar([dentista], DateTime(2026, 11, 23, 9, 9, 50), DateTime(2026, 11, 23, 9, 10, 20));
    expect([r.ahora.length, pospuestas.length], [1, 0]);
  });

  test('texto de la notificación', () {
    final mateo = f('mañana cumpleaños de mateo 23 años');
    expect(textoAviso(Aviso(mateo, DateTime(2026, 11, 22), DateTime(2026, 11, 21, 20)), ahora), ('Cumpleaños de Mateo · 23 años', 'Mañana'));
    final leo = Entrada(texto: 'Leo', tipo: Tipo.cumple, fecha: DateTime(0, 2, 29));
    expect(textoAviso(Aviso(leo, DateTime(2027, 2, 28), DateTime(2027, 2, 28, 9)), DateTime(2027, 2, 28, 9)).$2, 'Hoy (cumple el 29/2)');
    final dentista = f('dentista mañana 10hs');
    expect(textoAviso(Aviso(dentista, DateTime(2026, 11, 22), DateTime(2026, 11, 22, 9)), DateTime(2026, 11, 22, 9)).$2, 'Hoy · 10:00');
  });
}

void resumen() {
  test('resumen del día', () {
    final todas = [f('dentista hoy 10hs'), f('reunión hoy 15hs'), f('pagar luz hoy'), f('cumple Ana 22/11'), f('cumple de mi mamá 21/11')];
    expect(resumenDelDia(todas, ahora), 'Hoy: 2 eventos, 1 tarea · Hoy cumple mi mamá · Mañana cumple Ana');
    expect(resumenDelDia([], ahora), 'Hoy: día libre');
  });
}
