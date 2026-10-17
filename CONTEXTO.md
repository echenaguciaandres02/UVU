# Contexto del proyecto UVU (para continuar en otro chat)

Resumen de todo lo hablado y hecho hasta el 17 de octubre de 2026 (incluye las fases 3 y 4 y el sistema visual
DISCIPLINE, sección 7). Pégalo al inicio de un chat nuevo con Claude (o pídele que lea este archivo)
para continuar sin perder contexto.

---

## 1. Quién soy y mi situación

- Soy el **único usuario** de la app. Soy **principiante en Xcode**: necesito pasos exactos.
- Uso **Windows 11, sin Mac** y **sin cuenta de Apple Developer de pago** (Apple ID gratuito).
- Mi iPhone tiene **iOS 26.6.2 en inglés**, pero la app debe estar **en español**.
- GitHub: usuario **`echenaguciaandres02`**, repo privado **https://github.com/echenaguciaandres02/UVU**.
- Tengo instalados Git, GitHub CLI (`gh`, con sesión iniciada), iTunes e iCloud (versiones web de
  Apple, no las de Microsoft Store) y Sideloadly. Los instaladores están en `Descargas\CLAUDE`.
- **Problema de red:** mi conexión sale por un servidor en EE. UU. (Latitude.sh, parece VPN o proxy) y
  eso bloquea `gsa.apple.com`. Sideloadly fallaba con "GSA returned HTTP 503". Al final logré
  instalar la app, así que ese error depende de la red que use.

## 2. Cómo se compila e instala (sin Mac)

1. El código está en GitHub. **XcodeGen** genera el proyecto desde `project.yml`; el `UVU.xcodeproj`
   no se guarda en el repo.
2. **GitHub Actions** (`.github/workflows/build.yml`) corre en `macos-15` y elige **Xcode 26.3**
   cuando existe. Compila un **`UVU.ipa` sin firmar**, lo sube como artefacto `UVU-ipa` y corre los
   tests unitarios y de interfaz en un simulador con iOS 26. Si fallan, muestra el resumen de
   `xcresulttool`, los reportes de cierre (`.ips`) y sube `TestResults`.
3. Claude descarga el `.ipa` con
   `gh run download <id> --repo echenaguciaandres02/UVU --name UVU-ipa --dir "$env:USERPROFILE\Downloads\CLAUDE"`.
4. Yo lo instalo con **Sideloadly**: arrastro el `.ipa`, elijo el iPhone y mi Apple ID, y toco Start.
   **Se instala encima sin borrar la app**, así se conservan los datos.
5. Con Apple ID gratuito la app **caduca a los 7 días**: se reinstala igual y los datos se mantienen.
6. Ya activé el Modo de desarrollador y confié en mi Apple ID en el iPhone (solo hacía falta una vez).

**Forma de trabajar de Claude:** no puede compilar en Windows. Sube el código, espera a GitHub
Actions, lee los errores con `gh run view --log` y corrige. Para bugs de interfaz, primero
**reproduce con una prueba de UI en la nube** y después arregla. Hay un commit por fase con mensaje
claro en español y la línea `Co-Authored-By: Claude …`. Para cambios con riesgo usa una rama y
`gh workflow run build.yml --ref <rama>`; después hace merge a `main`. La copia local de la sesión
anterior era temporal: en un chat nuevo hay que clonar con `gh repo clone echenaguciaandres02/UVU`.

## 3. Lo que pedí originalmente (especificación)

App nativa de iPhone, personal, "compañera del día a día". En español, siguiendo las Human Interface
Guidelines, limpia, rápida y con modo claro/oscuro.

- **Stack:** SwiftUI + SwiftData, iOS 17+, datos solo en el dispositivo (sin backend ni login),
  notificaciones locales (UserNotifications), Swift Charts y exportar/importar todo en JSON con la
  hoja de Compartir. iCloud/CloudKit **preparado pero desactivado**.
- **Navegación:** TabView con **Hoy, Hábitos, Tareas, Journal, Gym**. El calendario unificado se abre
  desde Hoy.
- **Hoy:** saludo y fecha; hábitos del día para marcar con un toque (con vibración); tareas de hoy o
  atrasadas; próximos recordatorios; entreno de hoy con botón "Empezar"; acceso al journal del día.
- **Hábitos:** crear, editar, archivar y reordenar (nombre, SF Symbol, color). Tipo sí/no o
  cuantitativo con meta. Frecuencia diaria, días específicos o X veces por semana. Recordatorios.
  Calendario mensual por hábito y uno general: verde = cumplido, amarillo = parcial, rojo = fallado,
  gris = no aplicaba; los días futuros no se colorean. Se pueden corregir días pasados. Estadísticas:
  racha actual, mejor racha, % semanal y mensual.
- **Tareas:** varias listas (Personal, Trabajo, Universidad). Cada tarea tiene título, notas,
  fecha/hora límite, prioridad, subtareas y recurrencia (diaria, semanal, mensual). Vistas Hoy,
  Próximos, Todas y Completadas. Notificaciones con acciones "Completar" y "Posponer 1 hora". Deslizar
  para completar o borrar.
- **Journal:** una entrada por día (editable), ánimo del 1 al 5, etiquetas, preguntas guía opcionales,
  búsqueda por texto y etiqueta, protección con Face ID, y en el calendario los días con entrada y su
  ánimo.
- **Gym:** biblioteca de ejercicios por músculo (precargada) más ejercicios propios. Rutinas (Push,
  Pull, Legs…) asignables a días. Sesión en vivo con series (peso, reps, RPE opcional), lo que hice la
  última vez y temporizador de descanso que avisa con notificación aunque el teléfono esté bloqueado.
  Historial, progreso por ejercicio (gráfica de peso máximo y volumen) y PR resaltados. Al terminar un
  entreno se marca solo el hábito "Ejercicio".
- **Calendario unificado:** vista mensual; al tocar un día muestra hábitos cumplidos o fallados, si
  entrené, tareas completadas y la entrada del journal.
- **Widgets (última fase):** hábitos del día con su progreso y la racha principal.
- **Fases:** 1 proyecto, navegación, modelos y respaldo · 2 hábitos y calendario · 3 tareas y
  notificaciones · 4 journal · 5 gym · 6 pantalla Hoy, calendario unificado y pulido · 7 widgets. Al
  final de cada fase la app debe compilar y poder probarse. Si algo no está claro, Claude debe
  **preguntar** en vez de suponer.

## 4. Decisiones tomadas

- **Nombre:** UVU. Bundle ID `com.uvu.app`. Ícono: un toro negro sobre fondo rojo; es una imagen
  que elegí yo y se usa tal cual, sin modificar.
- **Estética:** sistema visual "DISCIPLINE", **solo modo oscuro**. Esto reemplaza el "modo claro
  y oscuro" de la especificación original. Ver la sección 7.
- **Arquitectura:** MVVM ligero. Las vistas simples usan `@Query` y `modelContext`; las pantallas
  complejas, un ViewModel `@Observable`; la lógica de negocio va en `Services/` y tiene tests.
- **Modelos compatibles con CloudKit:** todas las propiedades tienen valor por defecto, las relaciones
  son opcionales, no se usa `@Attribute(.unique)` y los enums se guardan como String o Int.
- **Migraciones:** **sin `SchemaMigrationPlan`**. Los cambios aditivos los migra SwiftData solo, y
  `MigrationTests` lo comprueba con una base de la fase 2. Para cambios incompatibles hará falta un
  plan con etapas. Si una base no abre, se **aparta sin borrarla** (`UVU-apartada-<fecha>.store`) y
  se crea una nueva.
- **Base de datos:** en el App Group `group.com.uvu.app` si está disponible (para los widgets); si
  no, en Application Support. Con firma gratuita hoy no está disponible, así que usa Application
  Support.
- **Semana:** empieza el lunes. Locale `es` forzado y calendario gregoriano (`AppCalendar`).
- **Peso:** cada serie guarda el número **tal como lo escribí** y su unidad (kg o lb). En Ajustes elijo
  la unidad principal; gráficas y PR convierten a esa unidad.
- **Colores de "X veces por semana":** los días hechos son verdes. Los días sin hacer son grises
  mientras la meta semanal sea alcanzable o ya esté cumplida; pasan a rojo si la semana termina sin la
  meta o ya no da el tiempo. La racha se cuenta en semanas.
- **Hoy nunca se pinta de rojo**, solo verde o amarillo si ya hubo avance. Los días anteriores a la
  creación del hábito son grises.
- **Tareas recurrentes (fase 3):** al completarla, queda en Completadas y se crea la siguiente
  ocurrencia con las subtareas sin marcar. La fecha avanza desde la anterior (conservando la hora) y
  salta las ocurrencias ya pasadas.
- **Avisos de tareas (mis respuestas en la fase 3):**
  - Las tareas con fecha pero sin hora avisan a las **9:00** de ese día (cambiable en Ajustes).
  - La anticipación se **elige por tarea**: a la hora, 5, 15 o 30 min, 1 hora o 1 día antes.
  - **"Posponer 1 hora" solo mueve el aviso**; la fecha límite no cambia.
- **Journal (mis respuestas en la fase 4):**
  - Con Face ID activado, el journal **se bloquea al salir de la app**. Se pide la primera vez que
    entras al Journal tras abrir UVU o volver a ella; cambiar de pestaña no lo pide otra vez.
  - El ánimo se muestra con **5 barras tipo nivel** (sin emojis). En el calendario del journal, cada
    día con entrada es un gris que se aclara del 1 (oscuro) al 5 (hueso); el rojo sigue reservado
    para lo completado.
- **Importar JSON:** reemplaza **todos** los datos, con confirmación. El respaldo tiene `version`
  (actualmente 1).
- **Hábitos precargados (8):** Ejercicio (sí/no, `systemRole = "exercise"`), Tomar agua (8 vasos),
  Trabajar en la tesis (60 min), Tomar sol (15 min), Lectura (20 páginas), Tomar creatina (sí/no),
  Proteína (130 g) y Aprender algo nuevo (sí/no). Listas: Personal, Trabajo, Universidad. Unos 45
  ejercicios por músculo.
- **Alternativa descartada:** una app web (PWA) se instalaría sin Sideloadly, pero perdería
  notificaciones programadas, widgets, Face ID y vibración. Seguimos con la app nativa.

## 5. Estado actual

**Hecho y probado en la nube:**
- **Fase 1:** proyecto, pestañas, modelos de todo el app, datos iniciales, exportar/importar JSON y
  Ajustes (unidad de peso, respaldo, iCloud "desactivado", versión).
- **Fase 2:** pestaña Hábitos completa:
  - Marcar con un toque y vibración; registrar cantidades con botones +N.
  - Crear, editar, archivar, restaurar, eliminar y reordenar hábitos.
  - Detalle con estadísticas y calendario mensual; calendario general.
  - Corregir días pasados.
- **Fase 2b (mis pedidos tras probar la fase 2):**
  1. **Varios recordatorios por hábito** (`Habit.reminderMinutes: [Int]`, minutos desde medianoche),
     con "Repartir durante el día…" (ej. cada 2 h de 8:00 a 20:00) y un máximo de 12 por hábito.
     El recordatorio único anterior se migra solo.
  2. **Calendario general con resumen del día:** al tocar un día se despliegan grupos (Cumplidos,
     Parciales, Fallados, Pendientes) con los íconos de los hábitos.
  3. **Arreglado el cuelgue** al tocar 📅 en Hábitos (también afectaba a Archivados). La causa eran
     los `navigationDestination(isPresented:)`; ahora se usa `NavigationStack(path:)` con
     `enum HabitsRoute`.
  - Además, las notificaciones se ven con la app abierta (`AppDelegate` + `NotificationDelegate`).
- **Sistema visual DISCIPLINE** (sección 7), aplicado a todas las pantallas que existen hoy.
  Se revisó con capturas automáticas del simulador.
- **Fase 3: tareas y notificaciones.**
  - Vistas Hoy (con Atrasadas), Próximos (por día), Todas (por lista) y Hechas, con un `ScopeBar`
    propio.
  - Tareas con notas, lista, fecha y hora, prioridad (!, !!, !!!), subtareas y recurrencia.
  - Deslizar a la derecha completa o reabre; a la izquierda borra.
  - Listas: crear, editar, ordenar y borrar.
  - Avisos con botones **Completar** y **Posponer 1 hora**, que funcionan con la app cerrada: hay
    un contenedor compartido `AppContainer.shared` y la categoría se registra en `AppDelegate`.
  - Lógica en `Services/Tasks/` (`TaskSchedule`, `TaskActions`, `TaskGrouping`). Pantallas en
    `Features/Tasks/`.
  - Incluye un flujo de interfaz: crear, completar deslizando y verla en Hechas. La probé en mi
    iPhone.
- **Fase 4: journal.**
  - Una entrada por día (`JournalStore.entryOrNew`), editable, con ánimo, texto libre (Cormorant),
    preguntas guía opcionales y etiquetas. Las etiquetas no se duplican aunque cambien mayúsculas,
    tildes o "#"; las que quedan sin uso se borran.
  - Tarjeta "Hoy" que invita a escribir o resume lo escrito.
  - Lista por mes con búsqueda (texto, respuestas y etiquetas; ignora tildes) y filtro por etiqueta.
  - Calendario del journal con grises según el ánimo; tocar un día abre su entrada, también los
    pasados.
  - Face ID opcional (`JournalLock`; usa `.deviceOwnerAuthentication`, así que acepta el código
    si Face ID falla). Se confirma al activarlo en Ajustes y se bloquea en `scenePhase == .background`.
  - Ajustes → Journal: Face ID y editor de preguntas guía (`JournalPrompts`, guardadas como JSON en
    `@AppStorage`).
  - Lógica en `Services/Journal/`. Pantallas en `Features/Journal/`.
  - 39 tests en verde (30 unitarios y 9 de interfaz), incluido un flujo: escribir hoy y encontrarlo con la búsqueda.
- El último `UVU.ipa` (fase 4) está en `Descargas\CLAUDE`. **Todavía no lo probé en mi iPhone.**
  Face ID no se puede probar en el simulador.

**Siguiente:** probar la fase 4 en el iPhone (sobre todo Face ID) y luego **fase 5: gym**.

**Pendiente o limitaciones conocidas:**
- La pantalla Hoy y el calendario unificado son marcadores de posición hasta la fase 6.
- Los recordatorios de hábitos repiten cada día aunque el hábito ya esté cumplido.
- iOS permite unas **64 notificaciones pendientes** por app (hábitos + tareas). El formulario de
  hábitos avisa si uno usa muchas. Cada tarea con aviso usa una.
- Reabrir una tarea recurrente no borra la ocurrencia siguiente que ya se creó.
- Durante las pruebas automáticas no se programan avisos (`NotificationService.isDisabledForTesting`,
  argumento `-uvu-no-notifications`). Así el cuadro de permiso no bloquea las pruebas de interfaz.
- En las pruebas de interfaz, el checkbox de una tarea se llama "Completar <título>": para abrir la
  tarea hay que excluirlo de la búsqueda.
- Widgets (fase 7) necesitan App Group: con firma gratuita puede no funcionar; se verá en esa fase.
- Los números de los días completados (texto negro sobre rojo) tienen contraste 3,9:1. Cumple AA
  solo para texto grande; VoiceOver lee la fecha y el estado completos.

## 6. Estructura del código

```
project.yml                     XcodeGen: targets UVU, UVUTests, UVUUITests
.github/workflows/build.yml     Compilación en la nube, .ipa y tests
README.md                       Guía paso a paso (descargar, instalar con Sideloadly, renovar)
UVU/App/                        UVUApp (contenedor, datos iniciales, DataUpgrades), RootTabView
UVU/Models/                     Schema.swift (AppSchema, DataStore), Habits/, Tasks/, Journal/, Gym/
UVU/Services/                   Habits/HabitEvaluator (estados, rachas, %), Habits/HabitActions,
                                NotificationService, Backup/ (BackupFile DTOs, BackupService),
                                SeedData, DataUpgrades, Haptics
UVU/Features/                   Today/, Habits/ (Home, Row, Detail, Form, DayEditor, Calendar,
                                Management, SpreadReminders), Tasks/, Journal/, Gym/, Calendar/,
                                Settings/
UVU/Shared/                     Components/ (MonthCalendarView, SymbolBadge, Pickers, ActivityView),
                                Extensions/ (AppCalendar, Color+Hex, NumberText, ReminderTime)
UVUTests/                       BackupServiceTests, HabitEvaluatorTests, MigrationTests
UVUUITests/                     NavigationUITests (calendario general, detalle, archivados)
```

Modelos SwiftData:
- **Hábitos:** `Habit`, `HabitEntry`.
- **Tareas:** `TaskList`, `TaskItem` (prioridad `TaskItemPriority`, recurrencia `TaskRecurrence`),
  `Subtask`.
- **Journal:** `JournalEntry`, `PromptAnswer`, `JournalTag` (relación muchos a muchos).
- **Gym:** `Exercise`, `Routine`, `RoutineExercise`, `WorkoutSession`, `SessionExercise`,
  `WorkoutSet` (con `unitRaw` kg/lb).

## 7. Sistema visual "DISCIPLINE"

La especificación completa está en mi archivo `UVU_prompt_estetica.md`; las imágenes de referencia
fueron collages de Pinterest. Resumen:

**La vibra.** Disciplina, 4:00 AM, gimnasio vacío, "nadie está mirando". Póster brutalista en papel
rojo, fotocopia en blanco y negro con grano. Crudeza (boxeo, táctico, outdoor) mezclada con lujo
sobrio. Nada de colores alegres ni estilo "app de bienestar".

**Paleta** (Asset Catalog `Colors/` + `DesignSystem/Theme.swift`, solo modo oscuro):

| Token | Hex | Uso |
|---|---|---|
| `ink` | #0A0A0A | Fondo principal |
| `carbon` | #151515 | Superficies y filas |
| `graphite` | #2A2A2A | Bordes de 1 pt, separadores |
| `ash` | #8C8C8C | Texto secundario |
| `bone` | #E9E3D6 | Texto principal (nunca blanco puro) |
| `signal` | #D42A20 | Acento único: completado, acción principal, progreso del día |
| `signalDeep` | #8E1B14 | Parcial, presionado |
| `brass` | #B08D57 | Solo récords e hitos |

**Reglas:**
- El rojo es el único color con volumen: máximo un elemento rojo dominante por pantalla.
- Completado = rojo lleno; pendiente = contorno `graphite`. No se usa verde.
- Nunca texto pequeño rojo sobre negro.
- El acento del sistema (`.tint`) es `bone`.

**Mis decisiones al revisar el plan:**
- El color de cada hábito se mantiene, **apagado** (`Color.muted(hex:)`) y solo en el ícono.
- En los calendarios, el día fallado es un cuadro `carbon` **tachado**.
- Las barras del sistema (pestañas y barra superior) conservan el Liquid Glass de iOS 26; el
  contenido es plano.

**Tipografía** (fuentes OFL en `Resources/Fonts`, `DesignSystem/Typography.swift`):

| Fuente | Uso |
|---|---|
| Anton | Titulares y pósters, siempre en mayúsculas (`.posterTitle()`) |
| Inter Regular / SemiBold / Black | Texto y botones; etiquetas en mayúsculas con tracking amplio (`.labelCaps()`) |
| Cormorant Garamond | Frases editoriales (`QuoteCard`) |
| SF Pro ultraligera | Números grandes (`.numeral()`) |

Todas las fuentes respetan el tamaño de texto del sistema (Dynamic Type).

**Forma:**
- Esquinas de 2–4 pt.
- Listas y formularios con estilo `.grouped` de borde a borde: iOS 26 redondea mucho las tarjetas
  `.insetGrouped`.
- Grano sutil (`GrainOverlay`) en los pósters rojos.

**Componentes** (`UVU/DesignSystem/Components/`):
- `PosterHeader`, `RedPoster`, `TapeLabel` ("DO."), `QuoteCard`, `DayCompleteOverlay`.
- `HabitCheckbox`: cuadrado que se "estampa" en rojo con vibración `.heavy`.
- `QuantityBar` (hueso; roja solo con `accent: true`), `StreakCounter` (etiqueta `brass` si es
  récord), `UVUButtonStyle` (`.uvuPrimary` / `.uvuSecondary`), `StatusSwatch`.
- Frases editables en `DesignSystem/Quotes.swift` (frase del día, estado vacío, día completo).

**Verificación visual sin Mac:**
- `UVUUITests/ScreenshotTests` toma capturas de la galería (`DesignSystemGallery`, abierta con
  `-uvu-gallery`) y de cada pantalla, con datos de ejemplo (`-uvu-demo-data`). Lo hace en tamaño
  normal y con texto grande.
- GitHub Actions las sube como artefacto **`Capturas`**.

**Lecciones:**
- **No usar `LazyVGrid` dentro de una `List`.** Causó un ciclo infinito de cálculo de alturas y la
  app se cerraba. El calendario y la paleta usan filas fijas (`HStack`/`VStack`/`Grid`).
- Para cualquier pantalla nueva: fondo con `.screenBackground()` y filas con `.rowSurface()`.
  Formularios con `List` + `.uvuForm()`. Encabezados con `Text(...).labelCaps()`.
