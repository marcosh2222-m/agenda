# Etapas

Cada etapa deja la app usable y se prueba antes de pasar a la siguiente. Detalle de cada punto en [CONCEPTO.md](CONCEPTO.md).

## ✅ 0. Prueba de Windows
Bandeja del sistema, arranque con Windows, atajo global Ctrl + Alt + Espacio, notificaciones con botones.

## ✅ 1. Datos y captura automática
Entradas guardadas en `%APPDATA%\Agenda\entradas.json`. La frase se interpreta sola (tipo, fecha, hora, repetición, importante, edad del cumpleaños).

## 2. Interfaz principal ← ahora
- Barra izquierda: Inicio, Notas, Hechas, Ajustes.
- Captura con burbujas de tipo y etiquetas.
- Próximos 7 días (sin clima todavía) con eventos, cumpleaños y tareas importantes.
- Mes en grilla con puntos de color y flechas.
- Barra derecha: tareas pendientes, filtros, completar con un clic.
- Notas y Hechas como listas simples (en Hechas se puede desmarcar). Ajustes: arranque con Windows.

## 3. Detalle del día y edición
- Clic en un día → panel con eventos, cumpleaños, tareas y hechas de ese día; captura ya puesta en esa fecha.
- Editar el texto en el lugar, borrar con "Deshacer" (sin confirmaciones).
- Atajos: `Ctrl + K` buscar, `N` nueva entrada, `←` / `→` mes, `Esc` cerrar.
- Búsqueda.

## 4. Alarmas de verdad
- Valores por defecto por tipo en Ajustes; cada entrada puede tener los suyos.
- Programar las alarmas de las próximas semanas y renovarlas al abrir.
- Botones de la notificación conectados: Hecha, Posponer 10 min / 1 h.
- Alarmas varias veces por día en tareas; dejan de sonar al completar la del día.
- Cumpleaños 29/2 en años no bisiestos.
- Al despertar la PC: avisar las alarmas perdidas.

## 5. Rapidez y comodidad
- Cajita flotante de captura con Ctrl + Alt + Espacio (Enter guarda, Esc cierra).
- Botón de micrófono que abre el dictado de Windows (Win + H).
- Resumen del día al prender la PC, una vez por día.
- Copia automática diaria a una carpeta elegida (últimas 30).

## 6. Clima
Open-Meteo, ciudad en Ajustes, último clima guardado si no hay internet.

## 7. Pulido y versión instalable
Uso real unas semanas, arreglar lo que moleste, instalador para Windows.

## Después
Android y sincronización con Google Drive, editar una sola ocurrencia, eventos de varios días, etiquetas, checklists en notas, exportar.
