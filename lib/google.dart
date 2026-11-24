// Inicio de sesión de Google, solo con permiso para la carpeta oculta de la app en Drive (drive.appdata).
// Windows: navegador + PKCE, con el token de renovación cifrado por Windows (DPAPI) en %APPDATA%\Agenda.
// Android: lo maneja Google Play; la app no guarda tokens.
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Vienen de google.json al compilar (--dart-define-from-file); ese archivo no va al repo.
const _clientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
const _clientSecret = String.fromEnvironment('GOOGLE_CLIENT_SECRET');
const _permiso = 'https://www.googleapis.com/auth/drive.appdata';

/// En Windows hace falta compilar con las credenciales; en Android alcanza con el paquete y la firma.
bool get googleConfigurado => !Platform.isWindows || _clientId.isNotEmpty;

class SesionVencida implements Exception {
  @override
  String toString() => 'Google pide volver a conectar la cuenta';
}

Future<void> conectarGoogle() => Platform.isWindows ? _conectarWindows() : _conectarAndroid();

Future<String> tokenGoogle({bool renovar = false}) => Platform.isWindows ? _tokenWindows(renovar) : _tokenAndroid(renovar);

/// Olvida la sesión en este equipo. No borra la copia de Drive ni desconecta los otros equipos.
Future<void> olvidarGoogle() async {
  _acceso = null;
  if (Platform.isWindows && await archivoToken.exists()) await archivoToken.delete();
}

// ---------- Android ----------

Future<void>? _inicio;

Future<GoogleSignInAuthorizationClient> _autorizacion() async {
  await (_inicio ??= GoogleSignIn.instance.initialize());
  return GoogleSignIn.instance.authorizationClient;
}

Future<void> _conectarAndroid() async => _acceso = (await (await _autorizacion()).authorizeScopes([_permiso])).accessToken;

Future<String> _tokenAndroid(bool renovar) async {
  final a = await _autorizacion();
  if (renovar && _acceso != null) await a.clearAuthorizationToken(accessToken: _acceso!);
  final t = await a.authorizationForScopes([_permiso]);
  if (t == null) throw SesionVencida();
  return _acceso = t.accessToken;
}

// ---------- Windows ----------

String? _acceso;
DateTime _vence = DateTime(0);
File archivoToken = File('${Platform.environment['APPDATA']}\\Agenda\\google.token');

final _azar = Random.secure();
String _aleatorio() => base64UrlEncode(List.generate(32, (_) => _azar.nextInt(256))).replaceAll('=', '');

/// Desafío PKCE (S256) de un verificador.
String desafio(String verificador) => base64UrlEncode(sha256.convert(ascii.encode(verificador)).bytes).replaceAll('=', '');

HttpServer? _espera;

Future<void> _conectarWindows() async {
  await _espera?.close(force: true); // un intento anterior que quedó abierto
  final servidor = _espera = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final verificador = _aleatorio(), estado = _aleatorio();
  final vuelta = 'http://127.0.0.1:${servidor.port}';
  try {
    final pagina = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': _clientId,
      'redirect_uri': vuelta,
      'response_type': 'code',
      'scope': _permiso,
      'code_challenge': desafio(verificador),
      'code_challenge_method': 'S256',
      'state': estado,
      'prompt': 'consent', // para que siempre mande el token de renovación
    });
    await Process.run('rundll32', ['url.dll,FileProtocolHandler', '$pagina']);
    final codigo = await esperarCodigo(servidor, estado).timeout(const Duration(minutes: 3), onTimeout: () => throw 'no llegó la respuesta del navegador');
    final j = await _pedirToken({'grant_type': 'authorization_code', 'code': codigo, 'redirect_uri': vuelta, 'code_verifier': verificador});
    final renovacion = j['refresh_token'] as String?;
    if (renovacion == null) throw 'Google no mandó el permiso para seguir conectado';
    await archivoToken.parent.create(recursive: true);
    await archivoToken.writeAsBytes(dpapi(utf8.encode(renovacion), cifrar: true), flush: true);
  } finally {
    await servidor.close(force: true);
    if (_espera == servidor) _espera = null;
  }
}

/// Espera la vuelta del navegador. Ignora cualquier pedido sin el `state` de este intento (otra página o programa).
Future<String> esperarCodigo(HttpServer servidor, String estado) async {
  await for (final p in servidor) {
    final q = p.uri.queryParameters;
    final nuestro = p.uri.path == '/' && q['state'] == estado;
    p.response.statusCode = nuestro ? 200 : 404;
    p.response.headers.contentType = ContentType.html;
    if (nuestro) p.response.write('<meta charset="utf-8"><p>Ya podés cerrar esta pestaña y volver a la agenda.</p>');
    await p.response.close();
    if (!nuestro) continue;
    if (q['code'] case final c?) return c;
    throw q['error'] == 'access_denied' ? 'no se dio el permiso' : 'Google respondió con un error';
  }
  throw 'se canceló la conexión';
}

Future<String> _tokenWindows(bool renovar) async {
  if (!renovar && _acceso != null && DateTime.now().isBefore(_vence)) return _acceso!;
  if (!await archivoToken.exists()) throw SesionVencida();
  final String renovacion;
  try {
    renovacion = utf8.decode(dpapi(await archivoToken.readAsBytes(), cifrar: false));
  } catch (_) {
    throw SesionVencida(); // archivo de otro usuario o de otra PC
  }
  await _pedirToken({'grant_type': 'refresh_token', 'refresh_token': renovacion});
  return _acceso!;
}

Future<Map<String, dynamic>> _pedirToken(Map<String, String> campos) async {
  final cliente = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final p = await cliente.postUrl(Uri.https('oauth2.googleapis.com', '/token'));
    p.headers.set(HttpHeaders.contentTypeHeader, 'application/x-www-form-urlencoded');
    p.write(Uri(queryParameters: {...campos, 'client_id': _clientId, if (_clientSecret.isNotEmpty) 'client_secret': _clientSecret}).query);
    final r = await p.close().timeout(const Duration(seconds: 30));
    final j = jsonDecode(await r.transform(utf8.decoder).join()) as Map<String, dynamic>;
    if (j['error'] == 'invalid_grant') throw SesionVencida();
    if (r.statusCode != 200) throw 'Google no aceptó el inicio de sesión (${j['error']})';
    _acceso = j['access_token'] as String;
    _vence = DateTime.now().add(Duration(seconds: (j['expires_in'] as int) - 60));
    return j;
  } finally {
    cliente.close(force: true);
  }
}

// ---------- Cifrado de Windows (DPAPI): solo este usuario en esta PC puede leerlo ----------

final class _Bloque extends Struct {
  @Uint32()
  external int tamano;
  external Pointer<Uint8> datos;
}

typedef _DpapiC = Int32 Function(Pointer<_Bloque>, Pointer<Void>, Pointer<Void>, Pointer<Void>, Pointer<Void>, Uint32, Pointer<_Bloque>);
typedef _DpapiD = int Function(Pointer<_Bloque>, Pointer<Void>, Pointer<Void>, Pointer<Void>, Pointer<Void>, int, Pointer<_Bloque>);
typedef _Liberar = Pointer<Void> Function(Pointer<Void>);

Uint8List dpapi(List<int> bytes, {required bool cifrar}) {
  final f = DynamicLibrary.open('crypt32.dll').lookupFunction<_DpapiC, _DpapiD>(cifrar ? 'CryptProtectData' : 'CryptUnprotectData');
  final liberar = DynamicLibrary.open('kernel32.dll').lookupFunction<_Liberar, _Liberar>('LocalFree');
  return using((memoria) {
    final entra = memoria<_Bloque>(), sale = memoria<_Bloque>();
    final copia = memoria<Uint8>(bytes.length);
    copia.asTypedList(bytes.length).setAll(0, bytes);
    entra.ref.tamano = bytes.length;
    entra.ref.datos = copia;
    const sinVentana = 1; // CRYPTPROTECT_UI_FORBIDDEN
    if (f(entra, nullptr, nullptr, nullptr, nullptr, sinVentana, sale) == 0) throw 'Windows no pudo ${cifrar ? 'cifrar' : 'descifrar'} la sesión';
    try {
      return Uint8List.fromList(sale.ref.datos.asTypedList(sale.ref.tamano));
    } finally {
      liberar(sale.ref.datos.cast());
    }
  });
}
