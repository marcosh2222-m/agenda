import 'package:agenda/captura.dart';
import 'package:agenda/datos.dart';
import 'package:flutter_test/flutter_test.dart';

final ahora = DateTime(2026, 11, 21, 12); // sábado

void main() {
  void caso(String frase, Tipo tipo, String texto, {DateTime? fecha, String? hora, bool importante = false}) {
    test(frase, () {
      final e = interpretar(frase, ahora);
      expect([e.tipo, e.texto, e.fecha, e.hora, e.importante], [tipo, texto, fecha, hora, importante]);
    });
  }

  caso('llamar a mamá mañana a las 10', Tipo.tarea, 'llamar a mamá', fecha: DateTime(2026, 11, 22), hora: '10:00');
  caso('dentista el martes 18:30', Tipo.evento, 'dentista', fecha: DateTime(2026, 11, 24), hora: '18:30');
  caso('nota: ideas para el viaje', Tipo.nota, 'ideas para el viaje');
  caso('pagar luz!', Tipo.tarea, 'pagar luz', importante: true);
  caso('renovar DNI importante', Tipo.tarea, 'renovar DNI', importante: true);
  caso('turno médico 14/3', Tipo.tarea, 'turno médico', fecha: DateTime(2027, 3, 14)); // limitación conocida
  caso('sacar basura sábado', Tipo.tarea, 'sacar basura', fecha: DateTime(2026, 11, 28));
  caso('comprar pan a las 18', Tipo.tarea, 'comprar pan', fecha: DateTime(2026, 11, 21), hora: '18:00');
  caso('pasado mañana reunión', Tipo.tarea, 'reunión', fecha: DateTime(2026, 11, 23));
  caso('cena con Pablo 25 de diciembre 21hs', Tipo.evento, 'cena con Pablo', fecha: DateTime(2026, 12, 25), hora: '21:00');
  caso('cumple Juan 29 de febrero', Tipo.cumple, 'cumple Juan', fecha: DateTime(0, 2, 29));
  caso('Una idea larga sobre cómo organizar la mudanza y qué cosas llevar primero', Tipo.nota,
      'Una idea larga sobre cómo organizar la mudanza y qué cosas llevar primero');
  caso('reunión 31/2', Tipo.tarea, 'reunión 31/2'); // fecha imposible: no se toca

  test('repeticiones', () {
    final yoga = interpretar('yoga todos los lunes y miércoles 19hs', ahora);
    expect([yoga.tipo, yoga.texto, yoga.hora, yoga.repeticion!.dias], [Tipo.evento, 'yoga', '19:00', [1, 3]]);
    expect(describir(yoga, ahora), ['sáb 21/11', '19:00', 'todos los lun, mié']);

    final regar = interpretar('regar plantas cada 3 días', ahora);
    expect([regar.tipo, regar.texto, regar.repeticion!.unidad, regar.repeticion!.cada], [Tipo.tarea, 'regar plantas', 'dia', 3]);

    expect(interpretar('misa cada domingo', ahora).repeticion!.dias, [7]);
    expect(interpretar('alquiler cada mes', ahora).repeticion!.unidad, 'mes');
    expect(interpretar('vitaminas diario', ahora).repeticion!.unidad, 'dia');
  });

  test('cumple con año calcula la edad', () {
    final e = interpretar('cumple Ana 14/3/1996', ahora);
    expect([e.tipo, e.fecha, e.repeticion!.unidad], [Tipo.cumple, DateTime(1996, 3, 14), 'anio']);
    expect(describir(e, ahora), ['14/3', 'cumple 31']);
  });

  test('cumple con edad guarda el año de nacimiento', () {
    final ana = interpretar('cumple Ana 30 años 14/3', ahora); // próximo: 14/3/2027
    expect([ana.texto, ana.fecha], ['cumple Ana', DateTime(1997, 3, 14)]);
    expect(describir(ana, ahora), ['14/3', 'cumple 30']);
    expect(interpretar('cumple Leo 14 de diciembre 40 años', ahora).fecha, DateTime(1986, 12, 14));
    expect(interpretar('cumple Leo 21/11 40 años', ahora).fecha, DateTime(1986, 11, 21)); // hoy cuenta como próximo
  });

  test('tipo forzado', () {
    final e = interpretar('turno médico 14/3', ahora, tipo: Tipo.evento);
    expect([e.tipo, e.fecha], [Tipo.evento, DateTime(2027, 3, 14)]);
  });
}
