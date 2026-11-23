# Guía rápida: ejecutar y probar la app

Estos son los comandos esenciales para validar, compilar y abrir la app en
**iPhone** o **Android**. Ejecutarlos desde macOS.

## 1. Entrar al proyecto

```bash
cd /Users/juanignaciosilvalaguna/Documents/app-lectura
```

Para usar la instalación correcta de Flutter:

```bash
export PATH="$HOME/flutter/bin:$PATH"
```

Verificar el entorno:

```bash
flutter doctor -v
flutter devices
```

- `doctor`: muestra SDK, Xcode, Android y configuración faltante.
- `devices`: muestra iPhone, Android, emuladores y simuladores disponibles.

## 2. Preparar dependencias

```bash
flutter pub get
```

Solo si se modificó `pubspec.yaml`, se agregaron plugins o se acaba de clonar:

```bash
cd ios
pod install
cd ..
```

## 3. Validar antes de compilar

```bash
flutter analyze
flutter test
```

- `analyze`: revisa errores y problemas estáticos.
- `test`: ejecuta las pruebas automatizadas.

## 4. Probar directamente en iPhone

1. Conecta el iPhone por cable y desbloquéalo.
2. Confirma **Confiar en este equipo** en el iPhone.
3. Activa **Ajustes > Privacidad y seguridad > Modo de desarrollador**.
4. Comprueba que aparece con:

```bash
flutter devices
```

Ejecutar la app:

```bash
flutter run -d <id-del-iphone>
```

Para una compilación más estable al probar funciones, sin depurador:

```bash
flutter run --release -d <id-del-iphone>
```

Mientras se ejecuta en modo normal:

- `r`: Hot Reload.
- `R`: Hot Restart.
- `q`: cerrar la sesión de terminal.

## 5. Compilar y abrir en Xcode

Crear el proyecto iOS:

```bash
flutter build ios --debug
open ios/Runner.xcworkspace
```

En Xcode:

1. Abrir **Runner**, no `Runner.xcodeproj`.
2. Seleccionar el destino **Runner > Targets > Runner**.
3. Entrar en **Signing & Capabilities**.
4. Activar **Automatically manage signing**.
5. Seleccionar tu cuenta en **Team**.
6. Elegir el iPhone en la barra superior.
7. Pulsar **Run** (`⌘R`).

Si iOS impide abrir la app:

**Ajustes > General > VPN y gestión de dispositivos** y confiar en el perfil
de desarrollo.

Para compilar una versión optimizada:

```bash
flutter build ios --release
```

## 6. Probar en Android

Conecta el celular por USB y habilita **Opciones de desarrollador > Depuración
USB**, o inicia un emulador desde Android Studio.

Verificar que Android aparece:

```bash
flutter devices
```

Ejecutar:

```bash
flutter run -d <id-del-android>
```

Crear APK para instalar y compartir:

```bash
flutter build apk --debug
```

El archivo queda en:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Para una compilación optimizada:

```bash
flutter build apk --release
```

## 7. Flujo recomendado después de cada cambio

Para cambios normales en Dart o recursos:

```bash
flutter analyze
flutter test
flutter run -d <id-del-dispositivo>
```

Para probar en iPhone sin depurador:

```bash
flutter run --release -d <id-del-iphone>
```

Si se modificó `pubspec.yaml`:

```bash
flutter pub get
cd ios
pod install
cd ..
flutter test
flutter run -d <id-del-dispositivo>
```

## 8. Limpiar cuando un build falle o quedó desactualizado

```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..
```

Después volver a ejecutar:

```bash
flutter run -d <id-del-dispositivo>
```

## 9. Secuencia mínima

```bash
cd /Users/juanignaciosilvalaguna/Documents/app-lectura
export PATH="$HOME/flutter/bin:$PATH"
flutter pub get
flutter test
flutter devices
flutter run -d <id-del-dispositivo>
```

No uses `open ios/Runner.xcodeproj`. Para Xcode utiliza siempre
`ios/Runner.xcworkspace`, porque incluye las dependencias de CocoaPods.
