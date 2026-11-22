# Guía de desarrollo y pruebas en iPhone

Esta guía explica cómo preparar, compilar y actualizar **app-lectura** en el iPhone con el entorno que quedó configurado en este Mac.

## Estado actual del entorno

- Proyecto: `/Users/juanignaciosilvalaguna/Documents/app-lectura`
- Flutter usado por este proyecto: `/Users/juanignaciosilvalaguna/flutter/bin/flutter`
- Dart: `3.14.0`
- Flutter: `3.50.1`
- Xcode: `16.4`
- CocoaPods: `1.16.2`
- iPhone identificado como: `iPhone de Juan`
- ID del dispositivo: `00008110-0018143E0179801E`
- Team de desarrollo: `Juan Ignacio Silva Laguna`
- Team ID: `5TK35CMTNV`

> Usa el Flutter de la ruta `/Users/juanignaciosilvalaguna/flutter/bin/flutter`. Esta instalación contiene los ajustes necesarios para firmar frameworks en este Mac. El comando global `flutter` puede apuntar a `/Applications/flutter`, que fue la instalación que presentó problemas de firma.

## Flujo rápido para trabajar cada día

1. Conecta el iPhone por cable.
2. Desbloquéalo y déjalo con la pantalla encendida.
3. Abre una terminal y entra al proyecto:

   ```bash
   cd /Users/juanignaciosilvalaguna/Documents/app-lectura
   ```

4. Si no cambiaste dependencias, ejecuta:

   ```bash
   /Users/juanignaciosilvalaguna/flutter/bin/flutter test
   /Users/juanignaciosilvalaguna/flutter/bin/flutter run --release -d 00008110-0018143E0179801E
   ```

5. El segundo comando compila, firma, instala y abre la versión nueva en el iPhone.
6. Para cerrar la sesión de prueba, pulsa `q` en la terminal. La app instalada permanece en el iPhone.

## 1. Preparar el Mac una sola vez

### Verificar Flutter y Xcode

```bash
/Users/juanignaciosilvalaguna/flutter/bin/flutter --version
/Users/juanignaciosilvalaguna/flutter/bin/dart --version
xcodebuild -version
pod --version
/Users/juanignaciosilvalaguna/flutter/bin/flutter doctor -v
```

Explicación:

- `flutter --version`: confirma Flutter y Dart compatibles.
- `dart --version`: confirma que el SDK satisface `^3.14.0` de `pubspec.yaml`.
- `xcodebuild -version`: verifica Xcode.
- `pod --version`: verifica CocoaPods.
- `flutter doctor -v`: revisa Flutter, Android, Xcode, herramientas y dispositivos.

Las advertencias sobre que Flutter dejará de soportar Macs Intel son informativas; no impiden ejecutar esta app actualmente.

### Aceptar licencias Android

Solo es necesario si también se va a probar en Android:

```bash
yes | flutter doctor --android-licenses
```

Esto responde `sí` automáticamente a las licencias pendientes del Android SDK.

## 2. Preparar las dependencias del proyecto

Desde la raíz del proyecto:

```bash
cd /Users/juanignaciosilvalaguna/Documents/app-lectura
/Users/juanignaciosilvalaguna/flutter/bin/flutter pub get
cd ios
pod install
cd ..
```

Explicación:

- `flutter pub get`: descarga las dependencias declaradas en `pubspec.yaml` y regenera `.dart_tool` y configuraciones de Flutter.
- `pod install`: descarga y enlaza plugins nativos de iOS dentro de `ios/Pods`.

Ejecuta ambos comandos cuando:

- se agrega, elimina o actualiza una dependencia en `pubspec.yaml`;
- se cambia una versión de plugin;
- se vuelve a clonar el proyecto;
- CocoaPods informa que su lockfile no coincide.

## 3. Preparar y conectar el iPhone

1. Conecta el iPhone al Mac con cable.
2. En el iPhone, pulsa **Confiar** y escribe su código.
3. Ve a **Ajustes > Privacidad y seguridad > Modo de desarrollador**.
4. Activa **Modo de desarrollador**.
5. Reinicia cuando iOS lo solicite.
6. Vuelve a desbloquear el iPhone.
7. Verifica que Flutter lo detecta:

   ```bash
   /Users/juanignaciosilvalaguna/flutter/bin/flutter devices
   ```

Debe aparecer una línea similar a:

```text
iPhone de Juan • 00008110-0018143E0179801E • ios
```

Si el iPhone aparece como `unpaired`:

1. Abre Xcode.
2. Menú **Window > Devices and Simulators**.
3. Selecciona el iPhone.
4. Pulsa **Pair** o conecta nuevamente el cable.
5. Atiende cualquier solicitud mostrada en el iPhone.

## 4. Configurar Xcode paso a paso

### Abrir el archivo correcto

En Finder:

1. Ve a `/Users/juanignaciosilvalaguna/Documents/app-lectura/ios`.
2. Abre `Runner.xcworkspace` con doble clic.

No abras `Runner.xcodeproj`. El `.xcworkspace` incluye Runner y CocoaPods.

### Configurar firma

1. En Xcode, selecciona el proyecto **Runner** en el panel izquierdo.
2. Bajo **Targets**, selecciona **Runner**.
3. Abre **Signing & Capabilities**.
4. Marca **Automatically manage signing**.
5. En **Team**, selecciona `Juan Ignacio Silva Laguna (Personal Team)`.
6. Verifica que aparezcan:
   - Signing Certificate: `Apple Development`;
   - Provisioning Profile: `Xcode Managed Profile`;
   - Development Team: `5TK35CMTNV`.

La configuración actual usa el bundle identifier `com.applectura.appLectura--`.

### Configurar Scheme

1. Menú **Product > Scheme > Edit Scheme…**.
2. Selecciona **Build** en el panel izquierdo.
3. En la lista **Targets**:
   - marca **Runner** para Analyze, Test, Run, Profile y Archive;
   - deja **RunnerTests** desmarcado para ejecuciones diarias.
4. Haz clic en **Close**.

La pre-acción `Run Prepare Flutter Framework Script` debe permanecer ausente. Si aparece:

1. Vuelve a **Build > Pre-actions**.
2. Elimina esa acción con el botón `-`.
3. Cierra y vuelve a abrir el workspace si Xcode conserva la configuración anterior.

### Seleccionar el iPhone

En la barra superior de Xcode:

1. Haz clic en el selector junto a **Runner**.
2. Selecciona **iPhone de Juan** bajo dispositivos físicos.
3. No selecciones un simulador si quieres probar la app en el celular.

## 5. Compilar y ejecutar desde Flutter

La forma más estable de probar cambios en este equipo es ejecutar desde terminal con la instalación local corregida.

### Desarrollo rápido con debug

```bash
cd /Users/juanignaciosilvalaguna/Documents/app-lectura
/Users/juanignaciosilvalaguna/flutter/bin/flutter run -d 00008110-0018143E0179801E
```

Este modo permite hot reload, pero iOS puede rechazar el depurador cuando no se concede acceso `ptrace` o la sesión de Xcode no puede adjuntarse.

Comandos interactivos durante `flutter run`:

- `r`: hot reload;
- `R`: hot restart;
- `h`: mostrar comandos;
- `c`: limpiar consola;
- `q`: cerrar la sesión.

### Prueba estable en el iPhone

```bash
cd /Users/juanignaciosilvalaguna/Documents/app-lectura
/Users/juanignaciosilvalaguna/flutter/bin/flutter run --release -d 00008110-0018143E0179801E
```

Este es el comando recomendado para probar ahora:

- compila más optimizado;
- no necesita depurador/LLDB;
- no depende de `ptrace`;
- instala y abre la app en el teléfono;
- deja el icono instalado.

No hay hot reload en release. Después de cada cambio hay que ejecutar el comando nuevamente.

### Solo compilar sin instalar

```bash
cd /Users/juanignaciosilvalaguna/Documents/app-lectura
/Users/juanignaciosilvalaguna/flutter/bin/flutter build ios --release
```

Esto valida código y configuración iOS, pero no abre ni actualiza el iPhone.

## 6. Ejecutar desde Xcode

Después de hacer cambios Dart/Flutter:

```bash
cd /Users/juanignaciosilvalaguna/Documents/app-lectura
/Users/juanignaciosilvalaguna/flutter/bin/flutter pub get
cd ios
pod install
cd ..
```

Luego, en Xcode:

1. Abre `ios/Runner.xcworkspace`.
2. Selecciona **Runner** como Scheme.
3. Selecciona **iPhone de Juan** como destino.
4. Confirma en **Signing & Capabilities** que el Team sigue seleccionado.
5. Menú **Product > Clean Build Folder** o usa `Shift + Command + K` si cambiaste dependencias nativas.
6. Pulsa el triángulo **Run (▶)**.

Si Xcode solicita automatización, acepta **Allow** para controlar Xcode o configura después en **Ajustes del sistema > Privacidad y seguridad > Automatización**.

Si la app no abre por confianza del desarrollador:

1. En el iPhone abre **Ajustes > General > VPN y gestión de dispositivos**.
2. Entra en el perfil de Apple ID/desarrollador.
3. Pulsa **Confiar**.
4. Vuelve a abrir la app.

## 7. Rutina después de modificar código

### Si solo cambias Dart o recursos Flutter

```bash
cd /Users/juanignaciosilvalaguna/Documents/app-lectura
/Users/juanignaciosilvalaguna/flutter/bin/flutter test
/Users/juanignaciosilvalaguna/flutter/bin/flutter run --release -d 00008110-0018143E0179801E
```

- `flutter test`: ejecuta pruebas automatizadas del proyecto.
- `flutter run --release`: recompila, firma, actualiza e inicia la app.

### Si cambias `pubspec.yaml`

```bash
cd /Users/juanignaciosilvalaguna/Documents/app-lectura
/Users/juanignaciosilvalaguna/flutter/bin/flutter pub get
cd ios
pod install
cd ..
/Users/juanignaciosilvalaguna/flutter/bin/flutter test
/Users/juanignaciosilvalaguna/flutter/bin/flutter run --release -d 00008110-0018143E0179801E
```

### Si el build queda en un estado inconsistente

```bash
cd /Users/juanignaciosilvalaguna/Documents/app-lectura
/Users/juanignaciosilvalaguna/flutter/bin/flutter clean
rm -rf /private/tmp/app_lectura_build
/Users/juanignaciosilvalaguna/flutter/bin/flutter pub get
cd ios
pod install
cd ..
/Users/juanignaciosilvalaguna/flutter/bin/flutter run --release -d 00008110-0018143E0179801E
```

Explicación:

- `flutter clean`: elimina artefactos generados por Flutter.
- `rm -rf /private/tmp/app_lectura_build`: elimina el directorio de build temporal que se configuró para evitar los metadatos de `Documents`.
- `pub get` y `pod install`: regeneran dependencias.
- `run --release`: reconstruye e instala una versión nueva.

## 8. Errores encontrados y solución

### Dart SDK incompatible

Error:

```text
The current Dart SDK version is 3.8.1.
Because app_lectura requires SDK version ^3.14.0...
```

Solución: actualizar Flutter hasta obtener Dart 3.14 o usar la instalación ya preparada.

```bash
/Users/juanignaciosilvalaguna/flutter/bin/dart --version
```

### Licencias Android pendientes

Error visto en `flutter doctor`:

```text
Some Android licenses not accepted
```

Solución:

```bash
yes | flutter doctor --android-licenses
```

### Falta `Podfile`

Si se ejecuta `pod install` antes de `flutter pub get`, Flutter aún no ha regenerado la estructura iOS.

Solución:

```bash
cd /Users/juanignaciosilvalaguna/Documents/app-lectura
/Users/juanignaciosilvalaguna/flutter/bin/flutter pub get
cd ios
pod install
```

### iPhone no emparejado o no disponible

Errores:

```text
iPhone ... is not available because it is unpaired (code -29)
To use ... for development, enable Developer Mode
```

Solución:

- Cable y desbloqueo del iPhone.
- Confiar en el Mac.
- Activar Modo de desarrollador.
- Window > Devices and Simulators > Pair en Xcode.

### `Run Prepare Flutter Framework Script`

Error:

```text
SchemeAction Run Prepare Flutter Framework Script
Failed to copy Flutter framework
```

La causa fue una pre-acción extra del Scheme. La acción se eliminó de `Runner.xcscheme`, y RunnerTests quedó excluido de builds de ejecución.

Verificación: en Xcode, Edit Scheme > Build > Pre-actions debe decir **No Actions**.

### `Command PhaseScriptExecution failed with a nonzero exit code`

Este mensaje es un resumen genérico. El detalle real fue:

```text
Flutter.framework/Flutter: resource fork, Finder information, or similar detritus not allowed
```

También apareció en assets nativos como:

- `objective_c.framework`;
- `sqlite3.framework`;
- `pdfrx_pdfium_gate.framework`;
- `PDFium.framework`.

Causa: macOS añadió `com.apple.FinderInfo`, `com.apple.fileprovider.fpfs#P` y `com.apple.provenance` en archivos generados dentro de `Documents`, y `codesign` no puede firmarlos con esos metadatos.

Solución definitiva en este Mac: los builds iOS se realizan en:

```text
/private/tmp/app_lectura_build
```

Comprobaciones usadas:

```bash
xattr build/ios/Debug-iphoneos/Runner.app
xattr -lr build/ios/Debug-iphoneos/Flutter.framework
codesign --verify --verbose=2 build/ios/Debug-iphoneos/Runner.app
```

Explicación:

- `xattr`: muestra atributos extendidos.
- `xattr -r -d <atributo> <ruta>`: elimina un atributo recursivamente.
- `codesign --verify`: comprueba que la firma sea válida.

No vuelvas a firmar manualmente cada carpeta dentro del proyecto. Usa el Flutter local preparado y la ruta temporal configurada.

### `Could not call ptrace(PT_TRACE_ME)`

Ocurrió al intentar ejecutar una build debug sin una sesión correcta de LLDB/Xcode. La aplicación se compiló, pero el runtime debug no pudo adjuntar el depurador.

Solución recomendada para pruebas:

```bash
/Users/juanignaciosilvalaguna/flutter/bin/flutter run --release -d 00008110-0018143E0179801E
```

Para depurar con debug, abre el proyecto en Xcode y usa Run desde Xcode para que Xcode controle LLDB.

### Error al importar PDF en iOS

Error observado:

```text
type '_IOSinkImpl' is not a subtype of type 'StreamConsumer<Uint8List>'
```

Causa: `Stream<List<int>>.pipe(IOSink)` generaba una incompatibilidad de tipos en iOS.

Solución aplicada: escribir explícitamente cada bloque como `Uint8List` con `IOSink.add`, cerrar y limpiar el sink. Se validó con:

```bash
/Users/juanignaciosilvalaguna/flutter/bin/flutter test --reporter expanded test/library_store_test.dart
```

Resultado esperado:

```text
00:00 +4: All tests passed!
```

## 9. Diagnóstico rápido cuando un build falle

1. Guarda el error completo desde terminal:

   ```bash
   /Users/juanignaciosilvalaguna/flutter/bin/flutter run --release -d 00008110-0018143E0179801E -v > /tmp/app_ios.log 2>&1
   ```

2. Busca la causa real:

   ```bash
   grep -nE "error:|Failed to|resource fork|unpaired|Developer Mode|PhaseScriptExecution" /tmp/app_ios.log | tail -n 100
   ```

3. Si el error es de dependencias, ejecuta `flutter pub get` y `pod install`.
4. Si es de dispositivo, revisa cable, confianza, Modo de desarrollador y Team.
5. Si es de firma, usa primero `flutter clean` y elimina `/private/tmp/app_lectura_build`.
6. Si es de código Dart, ejecuta la prueba enfocada o `flutter analyze`.

## 10. Comandos de verificación final

```bash
cd /Users/juanignaciosilvalaguna/Documents/app-lectura
/Users/juanignaciosilvalaguna/flutter/bin/flutter doctor -v
/Users/juanignaciosilvalaguna/flutter/bin/flutter devices
/Users/juanignaciosilvalaguna/flutter/bin/flutter analyze
/Users/juanignaciosilvalaguna/flutter/bin/flutter test
/Users/juanignaciosilvalaguna/flutter/bin/flutter run --release -d 00008110-0018143E0179801E
```

El flujo habitual queda en esta secuencia:

```text
Editar código → flutter test → conectar iPhone → flutter run --release → probar → repetir
```
