# Agenda

Agenda y anotador personal para Windows y Android, hecha con Flutter. Qué hace: [docs/CONCEPTO.md](docs/CONCEPTO.md). Plan: [docs/ETAPAS.md](docs/ETAPAS.md).

- Versión portable de Windows: `.\tool\empaquetar.ps1`
- APK: `flutter build apk --release --split-per-abi`

## Sincronización con Google Drive

La app solo pide acceso a su propia carpeta oculta en tu Drive (`drive.appdata`): no ve el resto de tus archivos. Para compilarla con sincronización hace falta un proyecto propio en [Google Cloud](https://console.cloud.google.com):

1. Crear un proyecto y activar la **Google Drive API**.
2. En la pantalla de consentimiento: tipo **Externo**, y agregar el permiso `https://www.googleapis.com/auth/drive.appdata`. Después, **publicar la app**: en modo prueba el acceso vence cada 7 días. Ese permiso es "no sensible".
3. Crear dos credenciales OAuth en el mismo proyecto:
   - **App de escritorio** (Windows). Copiar `google.ejemplo.json` como `google.json` y poner ahí el ID y el secreto. `google.json` no va al repo.
   - **Android**: paquete `com.agenda.agenda` y la huella SHA-1 del certificado con que se firma la APK. No lleva archivo.

En Windows se compila con `flutter run -d windows --dart-define-from-file=google.json` (`empaquetar.ps1` ya lo usa si existe). Después, en los dos equipos: Ajustes → Sincronizar con Google → Conectar, con la misma cuenta.
