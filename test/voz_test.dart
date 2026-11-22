import 'package:agenda/voz.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('limpia marcas de silencio y ruido de Whisper', () {
    expect(limpiarTranscripcion(' Llamar a mamá mañana a las diez.\n'), 'Llamar a mamá mañana a las diez.');
    expect(limpiarTranscripcion('[BLANK_AUDIO]'), '');
    expect(limpiarTranscripcion(' (música) Comprar pan [Risas] '), 'Comprar pan');
  });
}
