// Arranque de la app: bandeja, atajo global, notificaciones y ventana principal.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

import 'alarmas.dart';
import 'calendario.dart';
import 'clima.dart';
import 'estilo.dart';
import 'pantalla.dart';
import 'datos.dart';

final notis = FlutterLocalNotificationsPlugin();
final registro = ValueNotifier<List<String>>([]);
late final tray.TrayIcon iconoBandeja; // referencia global para que no se libere
late final Window ventana;

void log(String s) {
  final t = DateTime.now();
  final hora = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
  registro.value = ['$hora  $s', ...registro.value];
  debugPrint('[agenda] $s');
}

void mostrar() {
  if (cajita.value) cerrarCajita();
  ventana.show();
  ventana.focus();
  // Esperar al primer dibujo: pedir foco antes rompe la caja de texto al arrancar.
  WidgetsBinding.instance.addPostFrameCallback((_) => captura.requestFocus());
}

// ---------- Cajita flotante ----------
// La misma ventana, chica, sin marco y siempre encima, solo con la captura.

final cajita = ValueNotifier(false);
dynamic _bordesNormales; // Rectangle de nativeapi (no exportado); solo se guarda y se devuelve

/// Atajo global: con la agenda a la vista pone el cursor en la captura; si no, abre la cajita.
void alAtajo() {
  if (cajita.value || (ventana.isVisible && !ventana.isMinimized)) return mostrar();
  cajita.value = true; // primero el contenido chico, después la ventana chica: si no, la pantalla completa no entra
  _bordesNormales = ventana.bounds;
  ventana.setFrameless(true);
  ventana.isAlwaysOnTop = true;
  ventana.setSize(const Size(680, 150).toNative(), false);
  ventana.center();
  ventana.show();
  ventana.focus();
}

void cerrarCajita() {
  ventana.hide();
  ventana.isAlwaysOnTop = false;
  ventana.setFrameless(false);
  if (_bordesNormales != null) ventana.bounds = _bordesNormales;
  cajita.value = false; // al revés que al abrir: la ventana vuelve a su tamaño antes que la pantalla completa
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  ventana = WindowManager.instance.getCurrent()!;
  ventana.addListener((e) {
    if (e is WindowCloseRequestedEvent) {
      e.request.cancel(); // cerrar = minimizar a la bandeja
      cajita.value ? cerrarCajita() : ventana.hide();
    }
  });

  await cargar();
  await notis.initialize(
    settings: const InitializationSettings(
      windows: WindowsInitializationSettings(appName: 'Agenda', appUserModelId: 'com.agenda.agenda', guid: '8c9a5077-333c-466b-8443-ef71354cf30a'),
    ),
    onDidReceiveNotificationResponse: _respuesta,
  );
  final inicio = await notis.getNotificationAppLaunchDetails();
  if (inicio?.notificationResponse case final r? when inicio!.didNotificationLaunchApp) _respuesta(r);
  Timer.periodic(const Duration(seconds: 30), (_) {
    revisarAlarmas();
    diario(alAbrir: false);
  });
  diario(alAbrir: true);

  _bandeja();

  await usarAtajo(atajoGuardado.value == null ? atajoActual.value : HotKey.fromJson(atajoGuardado.value!));

  runApp(const App());
  if (args.contains('--minimized')) {
    log('Arrancó minimizada en la bandeja');
  } else {
    mostrar();
  }
}

void _bandeja() {
  iconoBandeja = tray.TrayIcon.create()!;
  iconoBandeja.icon = tray.ImageAsset.fromAsset('assets/tray.ico');
  iconoBandeja.setTooltip('Agenda');

  final menu = tray.Menu.create()!;
  void item(String texto, void Function() accion) {
    final i = tray.MenuItem.createWithLabelAndType(texto, tray.MenuItemType.normal)!;
    i.addListener((e) {
      if (e is tray.MenuItemClickedEvent) accion();
    });
    menu.addItem(i);
  }

  item('Abrir', mostrar);
  menu.addSeparator();
  item('Salir', () async {
    iconoBandeja.setVisible(false);
    exit(0);
  });

  iconoBandeja.setContextMenu(menu);
  iconoBandeja.setContextMenuTrigger(tray.ContextMenuTrigger.rightClicked);
  iconoBandeja.addListener((e) {
    if (e is tray.TrayIconClickedEvent) mostrar();
  });
  iconoBandeja.setVisible(true);
}

// ---------- Atajo global ----------

final atajoActual = ValueNotifier(HotKey(key: PhysicalKeyboardKey.space, modifiers: [HotKeyModifier.control, HotKeyModifier.alt]));
final atajoError = ValueNotifier<String?>(null); // se muestra en Ajustes

String nombreAtajo(HotKey h) {
  const nombres = {HotKeyModifier.control: 'Ctrl', HotKeyModifier.alt: 'Alt', HotKeyModifier.shift: 'Shift', HotKeyModifier.meta: 'Win'};
  final tecla = h.physicalKey.keyLabel.trim();
  return [
    for (final m in h.modifiers ?? <HotKeyModifier>[]) nombres[m] ?? m.name,
    h.physicalKey == PhysicalKeyboardKey.space || tecla.isEmpty ? 'Espacio' : tecla,
  ].join(' + ');
}

/// Registra el atajo que abre la agenda desde cualquier programa. Si otro programa ya lo usa, queda el anterior.
Future<bool> usarAtajo(HotKey nuevo) async {
  Future<void> registrar(HotKey h) => hotKeyManager.register(h, keyDownHandler: (_) => alAtajo());
  final anterior = atajoActual.value;
  await hotKeyManager.unregisterAll();
  try {
    await registrar(nuevo);
    atajoActual.value = nuevo;
    atajoError.value = null;
    log('Atajo ${nombreAtajo(nuevo)} registrado');
    return true;
  } catch (e) {
    log('No se pudo registrar ${nombreAtajo(nuevo)}: $e');
    atajoError.value = '${nombreAtajo(nuevo)} ya lo usa otro programa. Elegí otra combinación.';
    if (anterior != nuevo) {
      try {
        await registrar(anterior);
      } catch (_) {} // el anterior tampoco anda: el error ya está a la vista
    }
    return false;
  }
}

// ---------- Alarmas ----------

var _ultimaRevision = DateTime.now(); // al abrir no se avisa lo de antes: solo lo perdido mientras corre
var _idNotificacion = 1;

// ---------- Una vez por día ----------

final estadoCopia = ValueNotifier<String?>(null); // error de la última copia, para Ajustes

/// Resumen del día (solo al abrir la app, una vez por día) y copia de los datos.
Future<void> diario({required bool alAbrir}) async {
  final ahora = DateTime.now(), hoy = diaClave(ahora);
  if (alAbrir && ultimoResumen != hoy) {
    ultimoResumen = hoy;
    await guardar();
    _notificar('Agenda de hoy', resumenDelDia(entradas.value, ahora));
  }
  final error = await copiaDiaria(ahora);
  if (error != estadoCopia.value && error != null) log(error); // un solo registro por error, no cada 30 s
  estadoCopia.value = error;
  final errorClima = await actualizarClima(); // cada 3 h; sin internet queda el último guardado
  if (errorClima != null) log(errorClima);
}

/// Selector de carpeta de Windows vía PowerShell: sin paquetes extra. Null si se cancela.
Future<String?> elegirCarpeta() async {
  final r = await Process.run('powershell', [
    '-NoProfile',
    '-Command',
    r"Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description = 'Carpeta para la copia diaria de la agenda'; if ($f.ShowDialog() -eq 'OK') { $f.SelectedPath }",
  ]);
  final ruta = (r.stdout as String).trim();
  return ruta.isEmpty ? null : ruta;
}

void revisarAlarmas() {
  final ahora = DateTime.now();
  final r = revisar(entradas.value, _ultimaRevision, ahora);
  _ultimaRevision = ahora;
  for (final a in r.ahora) {
    final (titulo, cuerpo) = textoAviso(a, ahora);
    _notificar(titulo, cuerpo, payload: '${a.entrada.id}|${a.dia.toIso8601String()}', hecha: a.entrada.tipo == Tipo.tarea);
  }
  if (r.perdidas.isNotEmpty) {
    final titulos = {for (final a in r.perdidas) textoAviso(a, ahora).$1}.toList();
    final mas = titulos.length > 4 ? ' y ${titulos.length - 4} más' : '';
    _notificar('Mientras la PC estaba suspendida', titulos.take(4).join(' · ') + mas);
  }
}

Future<void> _notificar(String titulo, String cuerpo, {String? payload, bool hecha = false}) async {
  try {
    await notis.show(
      id: _idNotificacion++,
      title: titulo,
      body: cuerpo,
      payload: payload,
      notificationDetails: NotificationDetails(
        windows: WindowsNotificationDetails(
          actions: [
            if (hecha) const WindowsAction(content: 'Hecha', arguments: 'hecha'),
            if (payload != null) ...const [
              WindowsAction(content: 'Posponer 10 min', arguments: 'posponer-10'),
              WindowsAction(content: 'Posponer 1 h', arguments: 'posponer-60'),
            ],
          ],
        ),
      ),
    );
    log('Aviso: $titulo · $cuerpo');
  } catch (e) {
    log('Error al avisar "$titulo": $e');
  }
}

Future<void> probarAlarma() => _notificar('Así se ve una alarma', 'Hoy · ${DateTime.now().hour.toString().padLeft(2, '0')}:00');

/// Botones de la notificación: Hecha, Posponer; un clic en el cuerpo abre la app.
void _respuesta(NotificationResponse r) {
  final accion = r.actionId ?? '';
  final p = r.payload?.split('|');
  final e = p == null || p.length != 2 ? null : entradas.value.where((e) => e.id == p[0]).firstOrNull;
  if (e == null || accion.isEmpty) return mostrar();
  final dia = DateTime.parse(p![1]);
  if (accion == 'hecha') {
    completar(e, dia, true);
    cambiar();
    log('Hecha desde la notificación: ${e.texto}');
  } else if (accion.startsWith('posponer-')) {
    final minutos = int.parse(accion.substring('posponer-'.length));
    pospuestas.add(Aviso(e, dia, DateTime.now().add(Duration(minutes: minutos))));
    log('Pospuesta $minutos min: ${e.texto}');
  }
}

// Arranque con Windows: entrada en HKCU\...\Run, sin dependencias extra.
const _run = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
Future<bool> arranqueActivo() async => (await Process.run('reg', ['query', _run, '/v', 'Agenda'])).exitCode == 0;
Future<void> cambiarArranque(bool activar) async {
  final r = await Process.run(
    'reg',
    activar
        ? ['add', _run, '/v', 'Agenda', '/t', 'REG_SZ', '/d', '"${Platform.resolvedExecutable}" --minimized', '/f']
        : ['delete', _run, '/v', 'Agenda', '/f'],
  );
  log(r.exitCode == 0 ? 'Arranque con Windows: ${activar ? 'activado' : 'desactivado'}' : 'Error: ${r.stderr}');
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: modoTema,
    builder: (_, modo, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: tema(Brightness.light),
      darkTheme: tema(Brightness.dark),
      themeMode: ThemeMode.values.asNameMap()[modo] ?? ThemeMode.system,
      home: ValueListenableBuilder(
        valueListenable: cajita,
        builder: (_, chica, _) => chica ? const Cajita(cerrar: cerrarCajita) : const Pantalla(ajustes: Ajustes()),
      ),
    ),
  );
}

/// Ajustes: apariencia, arranque con Windows y alarmas por defecto.
class Ajustes extends StatefulWidget {
  const Ajustes({super.key});
  @override
  State<Ajustes> createState() => _AjustesState();
}

class _AjustesState extends State<Ajustes> {
  bool arranque = false;
  bool grabando = false;

  @override
  void initState() {
    super.initState();
    arranqueActivo().then((v) {
      if (mounted) setState(() => arranque = v);
    });
  }

  @override
  void dispose() {
    if (grabando) _dejarDeGrabar();
    super.dispose();
  }

  void _grabarAtajo() {
    setState(() => grabando = true);
    grabandoAtajo = true;
    HardwareKeyboard.instance.addHandler(_tecla);
  }

  void _dejarDeGrabar() {
    HardwareKeyboard.instance.removeHandler(_tecla);
    grabandoAtajo = false;
    if (mounted) setState(() => grabando = false);
  }

  // Espera modificador(es) + una tecla; Esc cancela.
  bool _tecla(KeyEvent k) {
    if (k is! KeyDownEvent) return true;
    if (k.logicalKey == LogicalKeyboardKey.escape) {
      _dejarDeGrabar();
      return true;
    }
    final apretadas = HardwareKeyboard.instance.physicalKeysPressed;
    final esModificador = HotKeyModifier.values.any((m) => m.physicalKeys.contains(k.physicalKey));
    final modificadores = HotKeyModifier.values.where((m) => m.physicalKeys.any(apretadas.contains) && !m.physicalKeys.contains(k.physicalKey)).toList();
    if (esModificador || modificadores.isEmpty) return true; // falta la tecla principal (una letra sola no sirve de atajo global)
    _dejarDeGrabar();
    usarAtajo(HotKey(key: k.physicalKey, modifiers: modificadores)).then((ok) {
      if (!ok) return;
      atajoGuardado.value = atajoActual.value.toJson();
      guardar();
    });
    return true;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Ajustes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 20),
      ListTile(
        title: const Text('Apariencia'),
        trailing: ValueListenableBuilder(
          valueListenable: modoTema,
          builder: (_, modo, _) => SegmentedButton<String>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: 'system', label: Text('Sistema'), icon: Icon(Icons.brightness_auto_outlined, size: 16)),
              ButtonSegment(value: 'light', label: Text('Claro'), icon: Icon(Icons.light_mode_outlined, size: 16)),
              ButtonSegment(value: 'dark', label: Text('Oscuro'), icon: Icon(Icons.dark_mode_outlined, size: 16)),
            ],
            selected: {modo},
            onSelectionChanged: (s) {
              modoTema.value = s.first;
              guardar();
            },
          ),
        ),
      ),
      SwitchListTile(
        title: const Text('Arrancar con Windows (minimizada)'),
        value: arranque,
        onChanged: (v) async {
          await cambiarArranque(v);
          final real = await arranqueActivo();
          setState(() => arranque = real);
        },
      ),
      ValueListenableBuilder(
        valueListenable: atajoError,
        builder: (context, error, _) => ListTile(
          title: const Text('Atajo para abrir la agenda'),
          subtitle: Text(
            error ?? (grabando ? 'Apretá la combinación nueva (Esc cancela)' : 'Funciona desde cualquier programa'),
            style: TextStyle(fontSize: 12.5, color: error != null ? colorCat[Categoria.imp] : Paleta.of(context).muted),
          ),
          trailing: ValueListenableBuilder(
            valueListenable: atajoActual,
            builder: (context, atajo, _) =>
                OutlinedButton(onPressed: grabando ? _dejarDeGrabar : _grabarAtajo, child: Text(grabando ? 'Esperando…' : nombreAtajo(atajo))),
          ),
        ),
      ),
      ValueListenableBuilder(
        valueListenable: ciudad,
        builder: (context, c, _) => ListTile(
          title: const Text('Ciudad para el clima'),
          subtitle: Text(
            c == null ? 'Sin ciudad: los 7 días no muestran el clima' : '${c['nombre']} · ${c['detalle']}',
            style: TextStyle(fontSize: 12.5, color: Paleta.of(context).muted),
          ),
          trailing: OutlinedButton(
            onPressed: () async {
              final elegida = await elegirCiudad(context);
              if (elegida == null) return;
              ciudad.value = {'nombre': elegida.nombre, 'detalle': elegida.detalle, 'lat': elegida.lat, 'lon': elegida.lon};
              clima.value = {}; // el pronóstico de la ciudad anterior ya no sirve
              await guardar();
              final error = await actualizarClima(forzar: true);
              if (error != null) log(error);
            },
            child: Text(c == null ? 'Elegir' : 'Cambiar'),
          ),
        ),
      ),
      ListenableBuilder(
        listenable: Listenable.merge([carpetaCopias, estadoCopia]),
        builder: (context, _) {
          final carpeta = carpetaCopias.value, error = estadoCopia.value;
          return ListTile(
            title: const Text('Copia diaria de los datos'),
            subtitle: Text(
              error ?? (carpeta == null ? 'Desactivada · conviene una carpeta de OneDrive' : '$carpeta · quedan las últimas 30'),
              style: TextStyle(fontSize: 12.5, color: error != null ? colorCat[Categoria.imp] : Paleta.of(context).muted),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (carpeta != null)
                  TextButton(
                    onPressed: () {
                      carpetaCopias.value = null;
                      estadoCopia.value = null;
                      guardar();
                    },
                    child: const Text('Desactivar'),
                  ),
                OutlinedButton(
                  onPressed: () async {
                    final ruta = await elegirCarpeta();
                    if (ruta == null) return;
                    carpetaCopias.value = ruta;
                    ultimaCopia = null; // carpeta nueva: copiar ya, sin esperar a mañana
                    await guardar();
                    diario(alAbrir: false);
                  },
                  child: Text(carpeta == null ? 'Elegir carpeta' : 'Cambiar'),
                ),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Expanded(
              child: Text('Alarmas por defecto', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            TextButton(onPressed: probarAlarma, child: const Text('Probar una alarma')),
          ],
        ),
      ),
      ValueListenableBuilder(
        valueListenable: alarmasDefecto,
        builder: (context, defecto, _) => Column(
          children: [
            for (final (clave, nombre) in const [
              ('evento', 'Eventos con hora'),
              ('eventoSinHora', 'Eventos sin hora'),
              ('cumple', 'Cumpleaños'),
              ('tarea', 'Tareas con hora'),
            ])
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 160,
                      child: Padding(padding: const EdgeInsets.only(top: 3), child: Text(nombre)),
                    ),
                    Expanded(
                      child: EditorAlarmas(
                        alarmas: defecto[clave] ?? const [],
                        cambiar: (l) {
                          alarmasDefecto.value = {...defecto, clave: l};
                          guardar();
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('Registro', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      Expanded(
        child: ValueListenableBuilder(
          valueListenable: registro,
          builder: (context, l, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            children: [for (final s in l) Text(s, style: TextStyle(fontSize: 12, color: Paleta.of(context).muted))],
          ),
        ),
      ),
    ],
  );
}
