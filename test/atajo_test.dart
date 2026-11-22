import 'dart:convert';

import 'package:agenda/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

void main() {
  test('nombre del atajo y guardado como JSON', () {
    expect(nombreAtajo(atajoActual.value), 'Ctrl + Alt + Espacio');
    final h = HotKey(key: PhysicalKeyboardKey.keyA, modifiers: [HotKeyModifier.control, HotKeyModifier.shift]);
    expect(nombreAtajo(h), 'Ctrl + Shift + A');
    // Ida y vuelta por el archivo de datos.
    final vuelta = HotKey.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
    expect([nombreAtajo(vuelta), vuelta.physicalKey], ['Ctrl + Shift + A', PhysicalKeyboardKey.keyA]);
  });
}
