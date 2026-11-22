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

  caso('llamar a mamá mañana a las 10', Tipo.tarea, 'Llamar a mamá', fecha: DateTime(2026, 11, 22), hora: '10:00');
  caso('dentista el martes 18:30', Tipo.evento, 'Dentista', fecha: DateTime(2026, 11, 24), hora: '18:30');
  caso('nota: ideas para el viaje', Tipo.nota, 'Ideas para el viaje');
  caso('pagar luz!', Tipo.tarea, 'Pagar luz', importante: true);
  caso('renovar DNI importante', Tipo.tarea, 'Renovar DNI', importante: true);
  caso('turno médico 14/3', Tipo.tarea, 'Turno médico', fecha: DateTime(2027, 3, 14)); // limitación conocida
  caso('sacar basura sábado', Tipo.tarea, 'Sacar basura', fecha: DateTime(2026, 11, 28));
  caso('comprar pan a las 18', Tipo.tarea, 'Comprar pan', fecha: DateTime(2026, 11, 21), hora: '18:00');
  caso('pasado mañana reunión', Tipo.tarea, 'Reunión', fecha: DateTime(2026, 11, 23));
  caso('cena con Pablo 25 de diciembre 21hs', Tipo.evento, 'Cena con Pablo', fecha: DateTime(2026, 12, 25), hora: '21:00');
  caso('cumple Juan 29 de febrero', Tipo.cumple, 'Juan', fecha: DateTime(0, 2, 29));
  caso(
    'Una idea larga sobre cómo organizar la mudanza y qué cosas llevar primero',
    Tipo.nota,
    'Una idea larga sobre cómo organizar la mudanza y qué cosas llevar primero',
  );
  caso('reunión 31/2', Tipo.tarea, 'Reunión 31/2'); // fecha imposible: no se toca

  test('repeticiones', () {
    final yoga = interpretar('yoga todos los lunes y miércoles 19hs', ahora);
    expect(
      [yoga.tipo, yoga.texto, yoga.hora, yoga.repeticion!.dias],
      [
        Tipo.evento,
        'Yoga',
        '19:00',
        [1, 3],
      ],
    );
    expect(describir(yoga, ahora), ['sáb 21/11', '19:00', 'todos los lun, mié']);

    final regar = interpretar('regar plantas cada 3 días', ahora);
    expect([regar.tipo, regar.texto, regar.repeticion!.unidad, regar.repeticion!.cada], [Tipo.tarea, 'Regar plantas', 'dia', 3]);

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
    expect([ana.texto, ana.fecha], ['Ana', DateTime(1997, 3, 14)]);
    expect(describir(ana, ahora), ['14/3', 'cumple 30']);
    expect(interpretar('cumple Leo 14 de diciembre 40 años', ahora).fecha, DateTime(1986, 12, 14));
    expect(interpretar('cumple Leo 21/11 40 años', ahora).fecha, DateTime(1986, 11, 21)); // hoy cuenta como próximo
  });

  test('formato de cumpleaños', () {
    // "mañana" es el día del cumple, no el año en que nació: con la edad se calcula el año.
    final mateo = interpretar('mañana cumpleaños de mateo 23 años', ahora);
    expect([mateo.tipo, mateo.texto, mateo.fecha], [Tipo.cumple, 'Mateo', DateTime(2003, 11, 22)]);
    expect(tituloLargo(mateo, DateTime(2026, 11, 22)), 'Cumpleaños de Mateo · 23 años');
    expect(tituloCorto(mateo, DateTime(2026, 11, 22)), 'Cumpleaños Mateo (23)');

    final mama = interpretar('cumple de mi mamá el viernes', ahora);
    expect([mama.texto, mama.fecha], ['mi mamá', DateTime(0, 11, 27)]);
    expect(tituloLargo(mama, DateTime(2026, 11, 27)), 'Cumpleaños de mi mamá');
    expect(tituloCorto(mama, DateTime(2026, 11, 27)), 'Cumpleaños de mi mamá');

    expect(interpretar('cumpleaños del tio juan de la vega 3/5', ahora).texto, 'Tio Juan de la Vega');
    expect(interpretar('turno con el dentista el martes a las 10', ahora).texto, 'Turno con el dentista');
  });

  test('migrar textos viejos', () {
    final viejo = Entrada(texto: 'cumple Ana', tipo: Tipo.cumple, fecha: DateTime(1996, 3, 14));
    final tarea = Entrada(texto: 'llamar al banco', tipo: Tipo.tarea);
    migrarTexto(viejo);
    migrarTexto(tarea);
    expect([viejo.texto, tarea.texto], ['Ana', 'Llamar al banco']);
  });

  test('tipo forzado', () {
    final e = interpretar('turno médico 14/3', ahora, tipo: Tipo.evento);
    expect([e.tipo, e.fecha], [Tipo.evento, DateTime(2027, 3, 14)]);
  });
}
