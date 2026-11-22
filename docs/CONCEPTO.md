# Agenda y Anotador — Concepto

Agenda y anotador personal. Prioridad: útil, intuitivo y fluido.

## Plataformas
- **Primera versión: solo Windows (PC).** Hecha con **Flutter**.
- Después: Android, con el mismo código. iPhone fuera de alcance.

## Formato
- La semana arranca el **lunes**.
- Hora en formato **24 h**.

## Entradas
Un solo tipo de objeto ("entrada") con atributos:

| Tipo | Fecha | Hora | Completada | Repetición | Alarmas |
|---|---|---|---|---|---|
| Nota | opcional | — | — | — | — |
| Tarea | opcional | opcional | sí | opcional | sí, varias por día |
| Evento | sí | opcional | — | opcional | sí |
| Cumpleaños | sí | — | — | anual (fija) | sí |

Campos comunes: `id`, `texto`, `tipo`, `actualizado` (timestamp), `borrado` (bool).
Campos extra:
- Tarea: `importante` (bool), `hechas` (lista de fecha y hora de cada vez que se completó).
- Tarea y evento: `repeticion` (ver abajo).
- Tarea, evento y cumpleaños: `alarmas` (vacío = usar las de Ajustes).

> `actualizado` y `borrado` no se usan en la primera versión, pero se guardan desde el principio para que la sincronización futura no obligue a migrar datos.

### Tareas
- **Simples:** se completan una vez → pasan a **Hechas** con la fecha y hora.
- **Repetitivas:** usan las mismas opciones de repetición que los eventos.
  - *Propuesto:* al completarla se marca solo la ocurrencia de ese día; queda registrada en Hechas y la tarea sigue para la próxima.
- **Alarmas varias veces por día:** cada tarea (simple o repetitiva) puede tener una lista de horarios. Se agregan o quitan horarios libremente (ej.: 08:00, 14:00, 22:00).
  - *Propuesto:* las alarmas del día dejan de sonar cuando la tarea de ese día se marca como hecha.
- En **Hechas** se ve la fecha y la hora en que se completó. Se puede desmarcar y vuelve a pendiente.

### Repetición (tareas y eventos)
- Opciones: diario, semanal (eligiendo días), mensual, anual, cada N días/semanas.
- Opcional: fecha de fin.
- *Propuesto:* editar una repetición cambia toda la serie (editar una sola ocurrencia queda para después).

### Eventos de varios días
Fuera de la primera versión.

## Captura automática (primera versión)
Escribís una frase; mientras escribís, debajo aparecen etiquetas con lo que entendió (tipo, fecha, hora, repetición, importante, alarma). Enter guarda. Los botones de tipo muestran el tipo detectado y tocando otro se corrige.

Reglas (sin internet, sin IA):
- "cumple"/"cumpleaños" → Cumpleaños. Con año ("14/3/1996") calcula la edad.
- Fecha: hoy, mañana, pasado mañana, día de la semana (el próximo; si es hoy, el de la semana que viene), "14/3", "14 de marzo". Una fecha ya pasada sin año → el año que viene.
- Hora: "10hs", "a las 18", "18:30".
- Repetición: "todos los lunes y miércoles", "cada domingo", "todos los días", "diario", "cada mes".
- "!" al final o "importante" → tarea importante.
- "nota:" al principio → Nota.
- Tipo: empieza con verbo (llamar, comprar…) → tarea; si no, y tiene hora o repetición → evento; texto largo sin fecha → nota; si no → tarea.
- Las palabras de fecha y hora se sacan del texto guardado.
- Tarea con hora y sin fecha → hoy.

Limitación conocida: "turno médico 14/3" (sin hora) queda como tarea; se corrige con un toque.

## Rapidez y comodidad (primera versión)
- **Micrófono:** botón a la izquierda de la caja de captura que abre el dictado de Windows (Win + H). Lo dictado entra como texto y lo interpreta la captura automática. No hay reconocimiento de voz propio. El dictado en español de Windows probablemente necesite internet.
- **Atajo global:** desde cualquier programa, **Ctrl + Alt + Espacio** abre una cajita flotante de captura en el centro de la pantalla (con micrófono). Enter guarda y se cierra; Esc la cierra sin guardar.
- **Notificaciones con botones:** cada alarma trae **Hecha**, **Posponer 10 min** y **Posponer 1 h** (eventos y cumpleaños: solo posponer).
- **Resumen al prender la PC:** al iniciar Windows, una notificación con lo de hoy ("Hoy: 2 eventos, 3 tareas · Mañana cumple Ana"). Una vez por día.
- **Atajos de teclado dentro de la app:**
  - `Ctrl + K` buscar · `N` escribir algo nuevo (foco en la captura) · `←` / `→` mes anterior / siguiente · `Esc` cerrar panel o cancelar.
- **Copia automática:** una vez por día, copia del archivo de datos en una carpeta elegida en Ajustes (puede ser de OneDrive). Se guardan las últimas 30 copias.

## Alarmas
- Notificaciones locales de Windows, sin servidor.
- **Valores por defecto en Ajustes**, por tipo. **Cada entrada puede tener los suyos**, que reemplazan los de Ajustes.
- Valores por defecto:
  - Evento con hora: **1 hora antes**.
  - Evento sin hora: el mismo día a las 09:00 *(propuesto)*.
  - Cumpleaños: el día anterior a las 20:00 y el mismo día a las 09:00 *(propuesto)*.
  - Tarea: sin alarma salvo que se le agreguen horarios *(propuesto)*.
- **Cumpleaños el 29/2:** en años no bisiestos avisa el **28/2** con el texto "(cumple el 29/2)".

## Interfaz (PC)
```
┌──────────┬────────────────────────────────────────┬─────────────┐
│          │  [ captura rápida ]                     │             │
│ Barra    ├────────────────────────────────────────┤  Tareas     │
│ izquierda│  Próximos 7 días (grande)               │             │
│          │  Lun │ Mar │ Mié │ Jue │ Vie │ Sáb │ Dom│  ★ Importan.│
│ Inicio   │  clima · eventos · cumpleaños           │  Con fecha  │
│ Notas    ├────────────────────────────────────────┤  Repetitivas│
│ Hechas   │  Mes completo en grilla (lun a dom)     │  Sin fecha  │
│ Ajustes  │  clic en un día → detalle del día       │             │
└──────────┴────────────────────────────────────────┴─────────────┘
```
- **Barra izquierda:** apartados (Inicio, Notas, Hechas) y Ajustes.
- **Arriba, en grande:** próximos 7 días con clima, eventos, cumpleaños y tareas importantes de cada día.
  - *Propuesto:* acá hay espacio, así que se muestra el texto de cada entrada (no puntos).
- **Abajo:** el mes completo en una grilla, con puntos de color (ver abajo).
- **Barra derecha:** **todas** las tareas pendientes: importantes, con fecha, repetitivas y sin fecha.
  - *Propuesto:* orden: importantes arriba, después por fecha, al final las sin fecha.
  - **Filtro por tipo** arriba de la lista. *Propuesto:* chips de un toque: Todas · Importantes · Con fecha · Repetitivas · Sin fecha · Vencidas.
- **Tareas importantes:** se muestran en su día, tanto en los 7 días como en la grilla, y además en la barra derecha.
  - Sin fecha: solo en la barra derecha.

### Puntos en la grilla del mes
- Cada tipo tiene un color: evento, cumpleaños, tarea importante, tarea con fecha.
- Hasta 2 entradas del mismo tipo en un día → un punto por entrada.
- 3 o más del mismo tipo → un solo punto con el número debajo, chico.
- Estilo ligero: puntos chicos (~6 px), colores suaves, número en gris claro. Que se distingan sin cargar la grilla.
- Colores pastel (los mismos en puntos y en las burbujas de tipo de la captura): tarea azul, evento verde, nota naranja, cumpleaños violeta, tarea importante rojo.
- **Clic en un día de la grilla → detalle del día:** eventos, cumpleaños y tareas de ese día.
  - *Propuesto:* se abre en un panel sobre la grilla, con la captura rápida ya puesta en esa fecha. Esc lo cierra.

### Comportamiento general
- Edición inline, "Deshacer" en vez de confirmaciones.
- Tareas vencidas siguen en la barra derecha con marca suave.
- Cumpleaños muestran la edad si se conoce el año.

## Clima
- *Propuesto:* Open-Meteo (gratis, sin cuenta ni clave).
- Necesita internet y una ciudad elegida en Ajustes.
- Sin conexión: se muestra el último clima guardado, o nada.

## Datos
- Todo se guarda local en la PC, en un archivo.

## Funcionamiento en segundo plano
- La app **arranca con Windows y queda minimizada en la bandeja del sistema** (junto al reloj), sin abrir la ventana. Viene activado; se puede apagar en Ajustes. Cerrar la ventana la minimiza; para salir del todo, clic derecho en el ícono → Salir.
- Mientras corre, revisa las alarmas pendientes y lanza las notificaciones.
- Windows no "duerme" una app de escritorio abierta; lo que sí puede pasar es que **la PC entera** entre en suspensión o hibernación, y ahí no corre nada.
  - *Propuesto:* al despertar la PC, la app muestra las alarmas que se perdieron ("Mientras la PC estaba suspendida: …").
  - Que la PC no se suspenda es una opción de energía de Windows, no de la app.

## Riesgos conocidos
- Alarmas: verificar que las notificaciones salgan bien con la app minimizada en la bandeja.
- Tareas y eventos repetidos: se calculan las ocurrencias y se programan solo las alarmas de las próximas semanas, renovándolas al abrir la app.

## Para después
- **Android** y **sincronización con Google Drive** (carpeta oculta de la app, fusión por `actualizado`, borrado lógico).
- Editar una sola ocurrencia de algo repetido, eventos de varios días, etiquetas, checklists en notas, exportar, iPhone.
