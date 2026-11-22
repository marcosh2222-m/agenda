// Prueba de Windows: bandeja, arranque con Windows, notificación programada
// con botones y atajo global. Se reemplaza por la app real cuando todo funcione.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

import 'captura.dart';
import 'datos.dart';

final notis = FlutterLocalNotificationsPlugin();
final registro = ValueNotifier<List<String>>([]);
final captura = FocusNode();
late final tray.TrayIcon iconoBandeja; // referencia global para que no se libere
late final Window ventana;

void log(String s) {
  final t = DateTime.now();
  final hora = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
  registro.value = ['$hora  $s', ...registro.value];
  debugPrint('[agenda] $s');
}

void mostrar() {
  ventana.show();
  ventana.focus();
  // Esperar al primer dibujo: pedir foco antes rompe la caja de texto al arrancar.
  WidgetsBinding.instance.addPostFrameCallback((_) => captura.requestFocus());
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  ventana = WindowManager.instance.getCurrent()!;
  ventana.addListener((e) {
    if (e is WindowCloseRequestedEvent) {
      e.request.cancel(); // cerrar = minimizar a la bandeja
      ventana.hide();
    }
  });

  await cargar();
  tzdata.initializeTimeZones();
  await notis.initialize(
    settings: const InitializationSettings(
      windows: WindowsInitializationSettings(
        appName: 'Agenda',
        appUserModelId: 'com.agenda.agenda',
        guid: '8c9a5077-333c-466b-8443-ef71354cf30a',
      ),
    ),
    onDidReceiveNotificationResponse: (r) => log('Notificación: ${r.actionId?.isNotEmpty == true ? r.actionId : 'clic en el cuerpo'}'),
  );
  final inicio = await notis.getNotificationAppLaunchDetails();
  if (inicio?.didNotificationLaunchApp ?? false) {
    log('Abierta desde una notificación: ${inicio!.notificationResponse?.actionId}');
  }

  _bandeja();

  await hotKeyManager.unregisterAll();
  try {
    await hotKeyManager.register(
      HotKey(key: PhysicalKeyboardKey.space, modifiers: [HotKeyModifier.control, HotKeyModifier.alt]),
      keyDownHandler: (_) {
        log('Atajo Ctrl + Alt + Espacio');
        mostrar();
      },
    );
    log('Atajo Ctrl + Alt + Espacio registrado');
  } catch (e) {
    // Otro programa ya usa la combinación: la app tiene que abrir igual.
    log('No se pudo registrar Ctrl + Alt + Espacio (¿lo usa otro programa?): $e');
  }

  runApp(const App());
  if (args.contains('--probar')) {
    await notificarAhora();
    await programar();
  }
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
  item('Notificación en 10 s', programar);
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

const _detalles = NotificationDetails(
  windows: WindowsNotificationDetails(actions: [
    WindowsAction(content: 'Hecha', arguments: 'hecha'),
    WindowsAction(content: 'Posponer 10 min', arguments: 'posponer-10'),
    WindowsAction(content: 'Posponer 1 h', arguments: 'posponer-60'),
  ]),
);

Future<void> notificarAhora() async {
  try {
    await notis.show(id: 2, title: 'Prueba inmediata', body: 'Si ves esto, las notificaciones funcionan', notificationDetails: _detalles);
    log('Notificación inmediata enviada');
  } catch (e) {
    log('Error en notificación inmediata: $e');
  }
}

Future<void> programar() async {
  try {
    await notis.zonedSchedule(
      id: 1,
      title: 'Dentista',
      body: 'En 1 hora · 10:00',
      scheduledDate: tz.TZDateTime.now(tz.UTC).add(const Duration(seconds: 10)),
      notificationDetails: _detalles,
      androidScheduleMode: AndroidScheduleMode.inexact,
    );
    log('Notificación programada para dentro de 10 s');
  } catch (e) {
    log('Error al programar: $e');
  }
}

// Arranque con Windows: entrada en HKCU\...\Run, sin dependencias extra.
const _run = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
Future<bool> arranqueActivo() async =>
    (await Process.run('reg', ['query', _run, '/v', 'Agenda'])).exitCode == 0;
Future<void> cambiarArranque(bool activar) async {
  final r = await Process.run('reg', activar
      ? ['add', _run, '/v', 'Agenda', '/t', 'REG_SZ', '/d', '"${Platform.resolvedExecutable}" --minimized', '/f']
      : ['delete', _run, '/v', 'Agenda', '/f']);
  log(r.exitCode == 0 ? 'Arranque con Windows: ${activar ? 'activado' : 'desactivado'}' : 'Error: ${r.stderr}');
}

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  bool arranque = false;
  final _texto = TextEditingController();
  Tipo? _forzado;

  @override
  void initState() {
    super.initState();
    arranqueActivo().then((v) => setState(() => arranque = v));
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          appBar: AppBar(title: const Text('Agenda — prueba de Windows')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                focusNode: captura,
                decoration: const InputDecoration(hintText: 'Escribí algo y Enter: "dentista el martes 18:30"'),
                onChanged: (_) => setState(() {}),
                onSubmitted: (t) async {
                  if (t.trim().isEmpty) return;
                  await agregar(interpretar(t, DateTime.now(), tipo: _forzado));
                  _texto.clear();
                  setState(() => _forzado = null);
                  captura.requestFocus(); // Enter quita el foco; dejarlo para seguir escribiendo
                },
                controller: _texto,
              ),
              if (_texto.text.trim().isNotEmpty)
                Builder(builder: (_) {
                  final e = interpretar(_texto.text, DateTime.now(), tipo: _forzado);
                  return Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final t in Tipo.values)
                      ChoiceChip(label: Text(nombreTipo[t]!), selected: e.tipo == t, onSelected: (_) => setState(() => _forzado = t)),
                    for (final s in describir(e, DateTime.now())) Chip(label: Text(s)),
                  ]);
                }),
              SizedBox(
                height: 200,
                child: ValueListenableBuilder(
                  valueListenable: entradas,
                  builder: (_, l, _) => ListView(children: [
                    for (final e in l.reversed.where((e) => !e.borrado)) ListTile(dense: true, title: Text(e.texto), subtitle: Text(describir(e, DateTime.now()).join(' · ')), trailing: Text(nombreTipo[e.tipo]!)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Arrancar con Windows (minimizada)'),
                value: arranque,
                onChanged: (v) async {
                  await cambiarArranque(v);
                  final real = await arranqueActivo();
                  setState(() => arranque = real);
                },
              ),
              Wrap(spacing: 8, children: [
                FilledButton(onPressed: notificarAhora, child: const Text('Notificación ahora')),
                FilledButton(onPressed: programar, child: const Text('Notificación en 10 s')),
              ]),
              const SizedBox(height: 16),
              const Text('Registro:'),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: registro,
                  builder: (_, l, _) => ListView(children: [for (final s in l) Text(s)]),
                ),
              ),
            ]),
          ),
        ),
      );
}
