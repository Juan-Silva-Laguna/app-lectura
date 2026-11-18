# Entre lineas

Primera version de un lector personal de PDF para **iOS y Android**, construido
con Flutter. No es una app web ni una version lista para publicar en tiendas.
La biblioteca empieza vacia: no incluye libros, cuentas ni un backend.

## Funciones implementadas

- Importar un PDF desde el selector nativo, darle un nombre y abrirlo. La copia
  se realiza por streaming en almacenamiento privado, incluso con URI de
  documentos de Android. Se detectan duplicados por SHA-256.
- Biblioteca local y renombrado. El nombre del libro nunca se usa como ruta.
- **Lectura**: texto adaptable por pagina, fuentes Lora y Atkinson incluidas,
  tamano e interlineado configurables, temas papel/sepia/noche.
- **PDF original**: pagina renderizada con su diagramacion y zoom.
- En Lectura: mantener pulsado el texto y elegir **Resaltar**, **Anotar** o
  **Guardar aqui**. Lista de anotaciones, salto al fragmento, edicion de notas y
  borrado con confirmacion. No se modifica el PDF original.
- Posicion automatica al terminar un desplazamiento y al cambiar de pagina.
  **Guardar aqui** conserva el inicio exacto del fragmento seleccionado.
- Indice navegable cuando el PDF lo incluye, y salto a numero de pagina.
- Narracion local en espanol, seleccion de voz, velocidad, seguimiento de
  palabras, pausa/reanudacion y continuacion a la siguiente pagina.
- Progreso de audio separado del progreso de lectura. El menu permite
  **Retomar narracion** o **Volver a mi lectura**.

## Alcance y limites importantes

- Solo PDF con texto extraible, sin cifrado ni restricciones de extraccion.
  Las paginas sin texto se pueden ver, pero no narrar/anotar; no hay OCR.
- El modo adaptable respeta el orden extraido por PDFium y conserva offsets.
  No es una conversion editorial perfecta: tablas, columnas, guiones de final
  de linea, encabezados y formulas pueden necesitar tratamiento posterior.
- Resaltados y notas se muestran en **Lectura**, no superpuestos al PDF original.
  No se genera un PDF anotado para exportacion.
- La posicion en PDF original se conserva por pagina, no por zoom/coordenada.
  No se inventan capitulos o secciones si el archivo no incluye un indice.
- La voz se instala mediante los ajustes del sistema, no desde un servidor de
  la app. Android filtra voces marcadas como dependientes de red o no instaladas;
  iOS utiliza las voces expuestas por AVSpeechSynthesizer. Validar en modo avion.
  Calidad, pronunciacion y callbacks por palabra dependen de la voz/motor.
- Se usa sintesis del sistema, no un modelo neural propio ni un narrador humano.
- **Audio solo en primer plano**: al salir de la app o bloquear la pantalla se
  pausa. Audio en segundo plano, controles de auriculares/pantalla bloqueada y
  manejo nativo completo de interrupciones siguen pendientes.
- No hay sincronizacion, exportacion/importacion de backups ni cifrado adicional
  de la base de datos. Desinstalar o perder el dispositivo puede perder las notas.
  Las copias automaticas del sistema dependen de su configuracion.
- No hay eliminacion de libros ni busqueda global en esta primera entrega.
- No hay garantias de rendimiento para libros grandes o de accesibilidad completa
  hasta medirlas en dispositivos reales.

## Arquitectura

| Componente | Responsabilidad |
| --- | --- |
| `lib/library_store.dart` | SQLite versionada, copia privada, hash, notas, preferencias y progreso |
| `lib/pdf_book.dart` | Apertura/validacion de PDF y extraccion de texto por pagina |
| `lib/narrator.dart` | Adaptador TTS local, filtrado de voces, fragmentacion y cancelacion |
| `lib/models.dart` | Modelos y offsets UTF-16 compartidos por lector, PDF y voz |
| `lib/reflow_page.dart` | Texto seleccionable, resaltados y restauracion visual del ancla |
| `lib/reader_screen.dart` | Ciclo de lectura, navegacion y persistencia |

Los PDF se guardan con UUID en `ApplicationSupport/library/books`.
`library.sqlite` contiene `books`, `page_text`, `annotations` y `settings`.
Se guardan rutas relativas para soportar cambios del contenedor de iOS.
El texto extraido se almacena de forma inmutable por pagina: cambiar la fuente
no invalida notas ni posiciones. Cada nota conserva pagina, offsets, cita y
contexto anterior/posterior. Se debe disenar una migracion explicita antes de
modificar este formato de texto.

La importacion usa un archivo temporal, validacion nativa y renombrado antes de
registrar el libro. Los errores normales eliminan la copia parcial. Un cierre
forzado justo entre renombrado y escritura en SQLite puede dejar un archivo
huerfano; la reconciliacion de esos archivos queda pendiente.

No hay llamadas de red en la logica de la app, telemetria propia ni envio de
documentos. Los paquetes y bibliotecas nativas se descargan **al compilar**;
las fuentes de lectura viajan en el instalador. El selector del sistema puede
necesitar internet si el PDF todavia esta en iCloud/Drive, antes de copiarlo.

## Herramientas

- Flutter **3.50.0**, Dart **3.14.0**; conservar `pubspec.lock`.
- Android **8.0 / API 26+**. Android SDK, NDK y Java compatible con el Gradle
  generado (Java 17 a 25; se recomienda el JDK de Android Studio).
- iOS **15+**, Mac con Xcode y las herramientas de desarrollo de Flutter para
  iOS. Xcode administra la firma para el iPhone.
- Las pruebas usan SQLite y PDFium reales. PDFium necesita un compilador C:
  Visual Studio Build Tools C++ y Windows SDK en Windows; Xcode en macOS.

### Windows de este proyecto

Se instalo Flutter aisladamente en:

```text
%LOCALAPPDATA%\app-lectura-toolchain\flutter
```

No se modifico el PATH global. Desde la raiz, en PowerShell:

```powershell
.\tool\flutter.ps1 --version
.\tool\flutter.ps1 pub get
.\tool\flutter.ps1 analyze
.\tool\flutter.ps1 test --reporter expanded
```

En VS Code usar **Flutter: Change SDK** para seleccionar ese SDK. No se han
instalado Android Studio, emuladores ni cambiado el Java global.
Con autorizacion, se instalaron Visual Studio Build Tools C++ y Windows SDK en
`C:\BuildToolsLectura` para ejecutar las pruebas nativas.

### Mac / iPhone

Copiar el proyecto sin `build`, `.dart_tool` ni caches locales. Con Flutter
3.50.0 y Xcode configurados, ejecutar desde la raiz:

```sh
flutter doctor -v
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter devices
flutter run -d <identificador-del-iphone>
```

Elegir un equipo de desarrollo y un bundle identifier propio en Xcode antes de
firmar. Los identificadores `com.applectura.app_lectura` son provisionales.
Activar Developer Mode en el iPhone si lo solicita Xcode.

### Android

Con SDK/NDK y JDK configurados, conectar un Android con depuracion USB o iniciar
un emulador:

```sh
flutter doctor -v
flutter devices
flutter run -d <identificador-android>
flutter build apk --debug
```

El proyecto generado usa firma de depuracion tambien para release. **No
publicarlo asi**: configurar identificadores, firma de produccion, iconos,
privacidad y los requisitos de ambas tiendas antes de distribuir.

## Validacion

Validacion ejecutada en Windows: `flutter analyze` sin incidencias y **13
pruebas aprobadas** con `flutter test --reporter expanded --timeout 60s`.
No se ha generado un APK/IPA ni ejecutado la app en un iPhone o Android.

Las pruebas cubren importacion privada y rollback, duplicados, SQLite tras
reabrir, anclas, notas, preferencias, filtrado de voces, cancelacion/error TTS,
dialogos y restauracion de lectura. `pdf_book_test.dart` crea un PDF propio de
dos paginas y verifica importacion, texto, renderizado, indice y reanudacion.
Los callbacks TTS son simulados en tests: no prueban la calidad de una voz real.

Antes de considerar la app funcionalmente aceptada en ambas plataformas:

1. Importar un PDF local, desconectar internet y reiniciar la app.
2. Resaltar un fragmento repetido, agregar una nota y verificar el fragmento
   correcto tras cambiar fuente, tamano, orientacion y reiniciar.
3. Guardar una palabra con **Guardar aqui** y comprobar la reanudacion.
4. Descargar una voz espanola, activar modo avion, escuchar varias paginas y
   probar pausa, reanudacion, salida de la app, bloqueo y una interrupcion.
5. Probar portadas sin texto, documentos invalidos/cifrados, falta de espacio y
   PDF de cientos de paginas. Medir tiempos, memoria y bateria en hardware.
6. Probar VoiceOver/TalkBack, texto del sistema grande y pantallas pequenas.
7. Implementar y validar backup/restauracion antes de confiar notas irremplazables.

Compilar/ejecutar en Windows no certifica el funcionamiento en iOS o Android.

## Fuentes y licencias

Fuentes redistribuidas bajo SIL Open Font License, con sus textos incluidos en
`assets/fonts` y disponibles en la pantalla de licencias:

- [Lora](https://github.com/google/fonts/tree/main/ofl/lora).
- [Atkinson Hyperlegible](https://github.com/google/fonts/tree/main/ofl/atkinsonhyperlegible).

Motor PDF: [pdfrx / PDFium](https://pub.dev/packages/pdfrx).
Sintesis: [flutter_tts](https://pub.dev/packages/flutter_tts).
Conservar los avisos y revisar las licencias transitivas al preparar distribucion.
