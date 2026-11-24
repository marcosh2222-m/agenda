// Archivo de la agenda en la carpeta oculta de la app en Google Drive (appDataFolder).
import 'dart:convert';
import 'dart:io';

const _nombre = 'agenda.json';

class Drive {
  /// Token de acceso; con [renovar] descarta el anterior (Google lo rechazó).
  final Future<String> Function({bool renovar}) token;
  final Uri base; // los tests usan un servidor local
  Drive(this.token, {Uri? base}) : base = base ?? Uri.parse('https://www.googleapis.com');

  Future<String> _pedir(String metodo, String ruta, Map<String, String> consulta, {String? tipo, String? cuerpo}) async {
    final uri = base.replace(path: ruta, queryParameters: consulta);
    for (var intento = 0; ; intento++) {
      final acceso = await token(renovar: intento > 0);
      final cliente = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      try {
        final pedido = await cliente.openUrl(metodo, uri);
        pedido.headers.set(HttpHeaders.authorizationHeader, 'Bearer $acceso');
        if (cuerpo != null) {
          pedido.headers.set(HttpHeaders.contentTypeHeader, tipo!);
          pedido.add(utf8.encode(cuerpo));
        }
        final r = await pedido.close().timeout(const Duration(seconds: 30));
        final texto = await r.transform(utf8.decoder).join().timeout(const Duration(seconds: 30));
        if (r.statusCode == 401 && intento == 0) continue; // token vencido: una vez más con uno nuevo
        if (r.statusCode != 200) throw 'Google Drive respondió ${r.statusCode}';
        return texto;
      } finally {
        cliente.close(force: true);
      }
    }
  }

  /// Ids de los archivos de la agenda, del más viejo al más nuevo. Puede haber dos si ambos equipos crearon el suyo a la vez.
  Future<List<String>> archivos() async {
    final j = jsonDecode(
      await _pedir('GET', '/drive/v3/files', {
        'spaces': 'appDataFolder',
        'q': "name = '$_nombre'",
        'orderBy': 'createdTime',
        'fields': 'files(id)',
        'pageSize': '100',
      }),
    );
    return [for (final f in j['files'] as List) f['id'] as String];
  }

  Future<String> bajar(String id) => _pedir('GET', '/drive/v3/files/$id', {'alt': 'media'});

  Future<void> actualizar(String id, String contenido) =>
      _pedir('PATCH', '/upload/drive/v3/files/$id', {'uploadType': 'media'}, tipo: 'application/json; charset=utf-8', cuerpo: contenido);

  Future<void> crear(String contenido) {
    const limite = 'agenda-limite-7f3c9b';
    final datos = jsonEncode({
      'name': _nombre,
      'parents': ['appDataFolder'],
    });
    return _pedir(
      'POST',
      '/upload/drive/v3/files',
      {'uploadType': 'multipart'},
      tipo: 'multipart/related; boundary=$limite',
      cuerpo:
          '--$limite\r\nContent-Type: application/json; charset=utf-8\r\n\r\n$datos\r\n'
          '--$limite\r\nContent-Type: application/json; charset=utf-8\r\n\r\n$contenido\r\n--$limite--\r\n',
    );
  }

  /// Cuenta conectada, para mostrarla en Ajustes.
  Future<String> cuenta() async {
    final j = jsonDecode(await _pedir('GET', '/drive/v3/about', {'fields': 'user(emailAddress)'}));
    return j['user']['emailAddress'] as String;
  }
}
