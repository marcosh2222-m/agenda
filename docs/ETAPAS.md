# Etapas

Cada etapa deja la app usable y se prueba antes de pasar a la siguiente. Detalle de cada punto en [CONCEPTO.md](CONCEPTO.md).

## ✅ 0. Prueba de Windows
Bandeja del sistema, arranque con Windows, atajo global Ctrl + Alt + Espacio, notificaciones con botones.

## ✅ 1. Datos y captura automática
Entradas guardadas en `%APPDATA%\Agenda\entradas.json`. La frase se interpreta sola (tipo, fecha, hora, repetición, importante, edad del cumpleaños).

## ✅ 2. Interfaz principal
- Barra izquierda: Inicio, Notas, Hechas, Ajustes.
- Captura con burbujas de tipo y etiquetas.
- Próximos 7 días (sin clima todavía) con eventos, cumpleaños y tareas importantes.
- Mes en grilla con puntos de color y flechas.
- Barra derecha: tareas pendientes, filtros, completar con un clic.
- Notas y Hechas como listas simples (en Hechas se puede desmarcar). Ajustes: arranque con Windows.

## ✅ 3. Detalle del día y edición
- Clic en un día → panel con eventos, cumpleaños, tareas y hechas de ese día; captura ya puesta en esa fecha.
- Editar el texto en el lugar, borrar con "Deshacer" (sin confirmaciones).
- Atajos: `Ctrl + K` buscar, `N` nueva entrada, `←` / `→` mes, `Esc` cerrar.
- Búsqueda.

## ✅ 4. Alarmas de verdad
- Valores por defecto por tipo en Ajustes; cada entrada puede tener los suyos (campana en el detalle del día).
- La app revisa cada 30 s qué tiene que sonar (queda en la bandeja); no se programan en Windows. Con la app cerrada no suena nada.
- Botones de la notificación conectados: Hecha (solo tareas), Posponer 10 min / 1 h.
- Alarmas varias veces por día en tareas ("8:00, 14:00 y 22:00"); dejan de sonar al completar la del día. "Avisame 30 min antes" en la captura.
- Cumpleaños 29/2 en años no bisiestos: avisa el 28/2 "(cumple el 29/2)".
- Al despertar la PC: una notificación con las alarmas perdidas.

## ✅ 5. Rapidez y comodidad
- Cajita flotante de captura con el atajo global, configurable en Ajustes (Enter guarda, Esc cierra). Con la agenda a la vista, el atajo pone el cursor en la captura.
- Botón de micrófono que abre el dictado de Windows (Win + H).
- Resumen del día al abrir la app (arranca con Windows), una vez por día.
- Copia automática diaria a una carpeta elegida en Ajustes (últimas 30).

## 6. Clima ← ahora
Open-Meteo, ciudad en Ajustes, último clima guardado si no hay internet.

## 7. Pulido y versión instalable
Uso real unas semanas, arreglar lo que moleste, instalador para Windows.

## Después
Android y sincronización con Google Drive, editar una sola ocurrencia, eventos de varios días, etiquetas, checklists en notas, exportar.
