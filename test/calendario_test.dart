import 'package:agenda/calendario.dart';
import 'package:agenda/captura.dart';
import 'package:agenda/datos.dart';
import 'package:flutter_test/flutter_test.dart';

final ahora = DateTime(2026, 11, 21, 12); // sábado
Entrada f(String frase) => interpretar(frase, ahora);
List<int> diasDe(Entrada e, int desde, int hasta) => [
  for (var d = desde; d <= hasta; d++)
    if (ocurre(e, DateTime(2026, 11, d))) d,
];

void main() {
  test('repeticiones', () {
    expect(diasDe(f('yoga todos los lunes y miércoles 19hs'), 15, 30), [23, 25, 30]);
    expect(diasDe(f('regar plantas cada 3 días'), 15, 30), [21, 24, 27, 30]);
    expect(diasDe(f('limpiar filtro cada 2 semanas'), 15, 30), [21]); // arranca sáb 21: próximo 5/12
    expect(ocurre(f('limpiar filtro cada 2 semanas'), DateTime(2026, 12, 5)), isTrue);
    expect(ocurre(f('alquiler cada mes'), DateTime(2027, 2, 21)), isTrue);
    expect(diasDe(f('dentista el martes 18:30'), 15, 30), [24]);
  });

  test('cumpleaños todos los años, 29/2 avisa el 28 en años comunes', () {
    final ana = f('cumple Ana 14/3/1996');
    expect([ocurre(ana, DateTime(2027, 3, 14)), ocurre(ana, DateTime(2040, 3, 14))], [true, true]);
    expect(tituloCorto(ana, DateTime(2027, 3, 14)), 'Cumpleaños Ana (31)');
    expect(tituloLargo(ana, DateTime(2027, 3, 14)), 'Cumpleaños de Ana · 31 años');
    final leo = f('cumple Leo 29/2');
    expect([ocurre(leo, DateTime(2027, 2, 28)), ocurre(leo, DateTime(2028, 2, 28)), ocurre(leo, DateTime(2028, 2, 29))], [true, false, true]);
  });

  test('completar: simple se va de pendientes, repetitiva solo el día', () {
    final pan = f('comprar pan mañana');
    final remedio = f('tomar remedio todos los días 08:00');
    final todas = [pan, remedio];
    final hoy = DateTime(2026, 11, 21), manana = DateTime(2026, 11, 22);

    completar(pan, manana, true);
    completar(remedio, hoy, true);
    expect(pendientes(todas), [remedio]);
    expect([hecha(remedio, hoy), hecha(remedio, manana)], [true, false]);

    completar(remedio, hoy, false);
    completar(pan, manana, false);
    expect([remedio.hechas, pan.hechas], [isEmpty, isEmpty]);
  });

  test('detalle del día y próxima fecha', () {
    final hoy = DateTime(2026, 11, 21);
    final vieja = Entrada(texto: 'vieja', tipo: Tipo.tarea, fecha: DateTime(2026, 11, 1));
    final remedio = f('tomar remedio todos los días 08:00');
    final luz = f('pagar luz hoy!');
    final todas = [vieja, remedio, luz, f('cena 21hs')];
    expect(tareasDelDia(todas, hoy, hoy), [luz, remedio, vieja]); // hoy suma vencidas
    expect(tareasDelDia(todas, DateTime(2026, 11, 22), hoy), [remedio]);

    completar(remedio, hoy, true);
    expect(
      [tareasDelDia(todas, hoy, hoy), hechasDelDia(todas, hoy)],
      [
        [luz, vieja],
        [remedio],
      ],
    );

    vieja.borrado = true;
    expect(tareasDelDia(todas, hoy, hoy), [luz]);

    expect(proximaFecha(f('cumple Ana 14/3/1996'), hoy), DateTime(2027, 3, 14));
    expect(proximaFecha(f('yoga todos los lunes'), hoy), DateTime(2026, 11, 23));
    expect(proximaFecha(f('comprar pan'), hoy), isNull);
  });

  test('delDia y pendientes', () {
    final todas = [
      f('cena 21hs'),
      f('cumple Ana 21/11'),
      f('pagar luz hoy!'),
      f('comprar pan'),
      f('tomar remedio todos los días'),
      f('nota: algo'),
      Entrada(texto: 'vieja', tipo: Tipo.tarea, fecha: DateTime(2026, 11, 1)),
    ];
    // Sin repetitiva común (llenaría todos los días), sin nota; con hora primero.
    expect([for (final e in delDia(todas, DateTime(2026, 11, 21))) e.texto], ['Cena', 'Ana', 'Pagar luz']);
    expect([for (final e in pendientes(todas)) e.texto], ['Pagar luz', 'Tomar remedio', 'vieja', 'Comprar pan']);
    expect(vencida(todas.last, DateTime(2026, 11, 21)), isTrue);
  });
}
