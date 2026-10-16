# Contexto del proyecto UVU (para continuar en otro chat)

Resumen de todo lo hablado y hecho hasta el 16 de octubre de 2026. Pégalo al inicio de un chat
nuevo con Claude (o pídele que lea este archivo) para continuar sin perder contexto.

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

- **Nombre:** UVU. Bundle ID `com.uvu.app`. Ícono provisional: degradado azul-violeta con "UVU".
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
  ocurrencia.
- **Importar JSON:** reemplaza **todos** los datos, con confirmación. El respaldo tiene `version`
  (actualmente 1).
- **Hábitos precargados (8):** Ejercicio (sí/no, `systemRole = "exercise"`), Tomar agua (8 vasos),
  Trabajar en la tesis (60 min), Tomar sol (15 min), Lectura (20 páginas), Tomar creatina (sí/no),
  Proteína (130 g) y Aprender algo nuevo (sí/no). Listas: Personal, Trabajo, Universidad. Unos 45
  ejercicios por músculo.
- **Alternativa descartada:** una app web (PWA) se instalaría sin Sideloadly, pero perdería
  notificaciones programadas, widgets, Face ID y vibración. Seguimos con la app nativa.

## 5. Estado actual

**Hecho y probado en la nube (17 tests en verde):**
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
- El último `UVU.ipa` (fase 2b) está en `Descargas\CLAUDE`. **Todavía no confirmé que funcione en mi
  iPhone.**

**Siguiente:** confirmar la fase 2b en el iPhone y luego **fase 3: tareas y notificaciones**
(categorías de notificación con acciones "Completar" y "Posponer 1 hora", recurrencias y deslizar
para completar o borrar).

**Pendiente o limitaciones conocidas:**
- La pantalla Hoy y el calendario unificado son marcadores de posición hasta la fase 6.
- Los recordatorios de hábitos repiten cada día aunque el hábito ya esté cumplido.
- iOS permite unas **64 notificaciones pendientes** por app. El formulario avisa si un hábito usa
  muchas. Hay que tenerlo en cuenta al sumar las de tareas.
- `NotificationService.rescheduleAll` borra **todas** las notificaciones pendientes y solo vuelve a
  crear las de hábitos. En la fase 3 debe reprogramar también las de tareas.
- Widgets (fase 7) necesitan App Group: con firma gratuita puede no funcionar; se verá en esa fase.

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
