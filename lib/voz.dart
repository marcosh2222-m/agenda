// Dictado en español con Whisper (whisper.cpp), en la PC y sin internet.
// La primera vez descarga el programa (9 MB, GitHub) y el modelo "base" (148 MB, Hugging Face).
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

const _urlPrograma = 'https://github.com/ggml-org/whisper.cpp/releases/download/b5907/whisper-bin-x64.zip'; // versión fija
const _urlModelo = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-base.bin';

// Huellas SHA-256 publicadas por GitHub y Hugging Face: lo bajado se ejecuta, así que tiene que ser exactamente eso.
const _huellaPrograma = 'ecca07b277d943e9b9f4712856a144b857271a6b333104e511e1988e80db582b';
const _huellaModelo = '60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe';

enum EstadoVoz { listo, descargando, grabando, transcribiendo }

final estadoVoz = ValueNotifier(EstadoVoz.listo);
final progresoVoz = ValueNotifier<double?>(null); // 0..1 mientras descarga
final avisoVoz = ValueNotifier<String?>(null); // para mostrar debajo de la captura

Directory get _carpeta => Directory('${Platform.environment['LOCALAPPDATA']}\\Agenda\\voz');
File get _modelo => File('${_carpeta.path}\\ggml-base.bin');
File get _wav => File('${Directory.systemTemp.path}\\agenda-dictado.wav');
final _grabador = AudioRecorder();

Future<File?> _programa() async {
  if (!await _carpeta.exists()) return null;
  await for (final f in _carpeta.list(recursive: true)) {
    if (f is File && f.uri.pathSegments.last.toLowerCase() == 'whisper-cli.exe') return f;
  }
  return null;
}

/// Baja [url] a [destino] solo si su SHA-256 es [huella].
Future<void> descargar(String url, String huella, File destino, double desde, double hasta) async {
  final cliente = HttpClient();
  try {
    final r = await (await cliente.getUrl(Uri.parse(url))).close();
    if (r.statusCode != 200) throw 'La descarga falló (HTTP ${r.statusCode})';
    final parcial = File('${destino.path}.parcial'); // a medio bajar no cuenta como instalado
    final salida = parcial.openWrite();
    var bajado = 0;
    await for (final trozo in r) {
      salida.add(trozo);
      bajado += trozo.length;
      if (r.contentLength > 0) progresoVoz.value = desde + (hasta - desde) * bajado / r.contentLength;
    }
    await salida.close();
    if ('${await sha256.bind(parcial.openRead()).first}' != huella) {
      await parcial.delete();
      throw 'La descarga no coincide con la original y se descartó';
    }
    await parcial.rename(destino.path);
  } finally {
    cliente.close();
  }
}

Future<void> _instalar() async {
  await _carpeta.create(recursive: true);
  if (await _programa() == null) {
    final zip = File('${_carpeta.path}\\whisper.zip');
    await descargar(_urlPrograma, _huellaPrograma, zip, 0, .06);
    final r = await descomprimir(zip, Directory('${_carpeta.path}\\programa'));
    if (r.exitCode != 0) throw 'No se pudo descomprimir Whisper: ${r.stderr}';
    await zip.delete();
    if (await _programa() == null) throw 'No encontré whisper-cli.exe en la descarga';
  }
  if (!await _modelo.exists()) await descargar(_urlModelo, _huellaModelo, _modelo, .06, 1);
}

/// Con el tar de Windows (abre zip), sin pasar la ruta por una consola.
Future<ProcessResult> descomprimir(File zip, Directory destino) async {
  await destino.create(recursive: true);
  return Process.run('${Platform.environment['SystemRoot']}\\System32\\tar.exe', ['-xf', zip.path, '-C', destino.path]);
}

/// Un toque: la primera vez instala; después empieza a grabar, y el siguiente toque termina y devuelve el texto.
Future<String?> tocarMicrofono() async {
  avisoVoz.value = null;
  try {
    switch (estadoVoz.value) {
      case EstadoVoz.descargando || EstadoVoz.transcribiendo:
        return null;
      case EstadoVoz.grabando:
        return await _terminar();
      case EstadoVoz.listo:
        if (await _programa() == null || !await _modelo.exists()) {
          estadoVoz.value = EstadoVoz.descargando;
          await _instalar();
          estadoVoz.value = EstadoVoz.listo;
          progresoVoz.value = null;
          avisoVoz.value = 'Dictado listo: tocá el micrófono para hablar.';
          return null; // no grabar de sorpresa después de una descarga larga
        }
        if (!await _grabador.hasPermission()) throw 'Windows no deja usar el micrófono (Configuración → Privacidad → Micrófono).';
        await _grabador.start(const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1), path: _wav.path);
        estadoVoz.value = EstadoVoz.grabando;
        avisoVoz.value = 'Escuchando… tocá de nuevo para terminar.';
        return null;
    }
  } catch (e) {
    estadoVoz.value = EstadoVoz.listo;
    progresoVoz.value = null;
    avisoVoz.value = '$e';
    return null;
  }
}

Future<String> _terminar() async {
  final ruta = await _grabador.stop() ?? _wav.path;
  estadoVoz.value = EstadoVoz.transcribiendo;
  avisoVoz.value = 'Pasando a texto…';
  try {
    final r = await Process.run((await _programa())!.path, ['-m', _modelo.path, '-f', ruta, '-l', 'es', '-nt', '-np'], stdoutEncoding: utf8);
    if (r.exitCode != 0) throw 'Whisper falló: ${r.stderr}';
    final texto = limpiarTranscripcion(r.stdout as String);
    avisoVoz.value = texto.isEmpty ? 'No se entendió nada. Probá de nuevo más cerca del micrófono.' : null;
    return texto;
  } finally {
    estadoVoz.value = EstadoVoz.listo;
    final audio = File(ruta);
    if (await audio.exists()) await audio.delete(); // la voz no queda guardada
  }
}

/// Whisper marca silencios y ruidos como "[BLANK_AUDIO]" o "(música)": se sacan.
String limpiarTranscripcion(String s) => s.replaceAll(RegExp(r'\[[^\]]*\]|\([^)]*\)'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
