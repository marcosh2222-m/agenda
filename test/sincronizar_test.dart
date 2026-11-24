import 'package:agenda/datos.dart';
import 'package:agenda/sincronizar.dart';
import 'package:flutter_test/flutter_test.dart';

Entrada e(String id, String texto, int minuto, {bool borrado = false}) =>
    Entrada(id: id, texto: texto, tipo: Tipo.tarea, actualizado: DateTime(2026, 11, 22, 10, minuto), borrado: borrado);

void main() {
  test('gana la última modificación; lo nuevo de cada lado se suma', () {
    final pc = [e('a', 'Pan', 0), e('b', 'Banco (editado en la PC)', 5), e('c', 'Solo en la PC', 1)];
    final celular = [e('a', 'Pan (editado en el celular)', 9), e('b', 'Banco', 2), e('d', 'Solo en el celular', 3)];
    final r = {for (final x in fusionar(pc, celular)) x.id: x.texto};
    expect(r, {'a': 'Pan (editado en el celular)', 'b': 'Banco (editado en la PC)', 'c': 'Solo en la PC', 'd': 'Solo en el celular'});
  });

  test('un borrado más nuevo llega al otro equipo', () {
    final r = fusionar([e('a', 'Pan', 0)], [e('a', 'Pan', 7, borrado: true)]);
    expect(r.single.borrado, isTrue);
  });

  test('da lo mismo el orden: los dos equipos terminan igual', () {
    final pc = [e('a', 'A pc', 4), e('b', 'B pc', 1)];
    final celular = [e('a', 'A cel', 2), e('b', 'B cel', 6)];
    String foto(List<Entrada> l) => (l.map((x) => '${x.id}:${x.texto}').toList()..sort()).join(',');
    expect(foto(fusionar(pc, celular)), foto(fusionar(celular, pc)));
  });
}
