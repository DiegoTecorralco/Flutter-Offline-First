# Práctica guiada Semana 11 - Flutter Offline-First

Implementa los pasos 1-6 y los criterios de evaluación del PDF de 20 páginas:

| Requisito del PDF | Implementación |
|---|---|
| Single Source of Truth | La UI consulta exclusivamente SQLite |
| Persistencia local | `sqflite` + `path`, tablas con metadatos |
| CRUD offline | Crear, listar, editar, completar y soft delete |
| UUID / timestamps | `uuid`, `updated_at` UTC, `version` |
| Detección de red | `connectivity_plus` con indicador de estado |
| WorkManager | Tarea one-off condicionada a red (Android) |
| PUSH → ACK → PULL → MERGE | Servicio de sincronización con Firestore |
| Colisiones | Last Write Wins por timestamp y versión |
| Seguridad de sesión | Firebase Auth por UID, `flutter_secure_storage` para UID local, limpieza de SQLite al cerrar sesión |
| Reglas backend | `firestore.rules`: acceso limitado al UID autenticado |
| Evidencias | Pruebas guiadas abajo; capturas reales pendientes |

## Tecnologías utilizadas (sin agregados ajenos a la práctica)

- Flutter / Dart: aplicación.
- `sqflite`, `path`: datos persistentes locales.
- `connectivity_plus`: cambios de conectividad.
- `workmanager`: ejecución diferida en Android.
- `uuid`: IDs únicos generados sin red.
- `firebase_core`, `firebase_auth`, `cloud_firestore`: conectividad al backend remoto Firebase, autenticación y sincronización.
- `flutter_secure_storage`: almacena de forma segura el identificador de la cuenta que posee los datos locales para evitar mezclar sesiones.

**Por qué Firebase:** el PDF exige CRUD nube, sincronización y reglas Firebase/**backend**. No exige Firebase en particular. Se eligió Firebase para evitar Node.js, Express, MySQL y un servidor extra. No se incluyen esos componentes.

## Comandos Windows CMD (primera vez)

Descarga y descomprime este ZIP; abre CMD en `semana11_offline_first`:

```cmd
flutter doctor
flutter doctor --android-licenses
flutter create --project-name semana11_offline_first --platforms android .
flutter pub get
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login
flutterfire configure --platforms=android
```

En [Firebase Console](https://console.firebase.google.com/):

1. Crea o selecciona tu proyecto Firebase.
2. Authentication → Sign-in method → habilita **Anonymous**.
3. Firestore Database → Create database → selecciona región.
4. Revisa que `flutterfire configure` haya asociado tu paquete Android y generado `android/app/google-services.json`. **No uses emuladores Firebase** a menos que configures explícitamente el proyecto para ellos.
5. Si `flutterfire configure` modifica `firebase.json`, conserva la entrada `"firestore": {"rules": "firestore.rules"}` de este proyecto.

Luego publica las reglas:

```cmd
firebase use --add
firebase deploy --only firestore:rules
```

Para ejecutar en tu Motorola moto g23 o emulador Android Studio:

```cmd
flutter devices
flutter run -d ZY22HZXVMV
```

**Importante:** `ZY22HZXVMV` es el ID que tenía tu Motorola en una prueba anterior; si cambió, sustituye por el ID mostrado en `flutter devices`. Para emulador, usa el ID que aparezca en el listado.

Para validar:

```cmd
flutter analyze
flutter test
flutter build apk --debug
```

APK en `build\app\outputs\flutter-apk\app-debug.apk`.

## Pruebas exigidas (hacerlas de verdad)

1. **Modo avión:** sin red, crea y edita tres tareas; comprueba que se ven en la UI y siguen pendientes.
2. **Cierre forzado:** cierra la app, vuelve a abrirla aún sin red; comprueba persistencia SQLite.
3. **Reconexión:** habilita red; verifica sincronización automática y documentos en Firebase Console → Firestore → `users/{uid}/tasks`.
4. **Colisiones:** modifica un documento en Firebase con un `updated_at` UTC posterior, sincroniza en la app y confirma que prevalece el más reciente.
5. **Soft delete:** elimina una tarea offline, reconecta y verifica `is_deleted: true` en Firestore.
6. **Seguridad:** valida que un usuario anónimo no pueda leer documentos del UID de otra cuenta. Al cerrar sesión se vacía la base local.

WorkManager depende del planificador Android; no garantiza ejecución inmediata después de cerrar forzosamente una app ni puede garantizar sincronización ante un *force-stop* del sistema. La reconexión con la app en primer plano sí dispara sincronización.

## Limitaciones importantes

- **No se incluyen credenciales Firebase.** Debes ejecutar `flutterfire configure` con tu proyecto; ese paso es específico de tu cuenta.
- Firestore Auth anónimo se mantiene en una instalación. No comparte automáticamente datos con otro teléfono: hace falta añadir un proveedor de identidad para eso.
- `flutter_secure_storage` protege el UID almacenado, pero los tokens internos de Firebase los gestiona su SDK. **SQLite no está cifrada en reposo**: si la evaluación exige cifrar *toda* la BD, será necesaria una base SQLite cifrada, que no es parte del stack indicado en el paso 1.
- La comparación por reloj del dispositivo (LWW) es adecuada para esta práctica, pero no ofrece garantías de relojes sincronizados para una aplicación financiera real.
- Los tests incluidos son unitarios. Las capturas y la prueba de extremo a extremo requieren un dispositivo y una cuenta Firebase activos.

## Git con commits

```cmd
git init
git branch -M main
git add .
git commit -m "feat: implement offline-first Flutter SQLite and cloud sync"
```

Puedes seguir haciendo commits por pruebas y documentación. No se incluye un historial simulado de commits.

# Flutter-Offline-First
Flutter Offline-First with SQLite, Firebase and WorkManager
