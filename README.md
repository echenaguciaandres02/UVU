# UVU

Tu compañera del día a día para iPhone: hábitos, tareas, journal y gym.
App personal en SwiftUI + SwiftData (iOS 17+), con los datos guardados solo en el teléfono.

---

## Cómo funciona sin Mac

Las apps de iPhone solo se pueden compilar con Xcode, y Xcode solo existe en macOS.
Por eso el proceso es así:

```
Código en GitHub  →  GitHub Actions (un Mac en la nube) compila  →  UVU.ipa
                                                                      ↓
                                     Sideloadly (en tu PC) la instala en tu iPhone
```

- **GitHub Actions** compila la app cada vez que se sube un cambio a la rama `main`,
  corre los tests y genera el archivo **UVU.ipa** (la app empaquetada).
- **Sideloadly** firma esa app con tu Apple ID gratuito y la instala por cable.

Nada de esto tiene costo.

---

## 1. Descargar la última versión de la app (UVU.ipa)

**Opción rápida (con la terminal):** abre PowerShell y ejecuta:

```bash
gh run download --repo echenaguciaandres02/UVU --name UVU-ipa --dir "$env:USERPROFILE\Downloads\CLAUDE"
```

El archivo queda en `Descargas\CLAUDE\UVU.ipa`.

**Opción con el navegador:**

1. Entra a `https://github.com/echenaguciaandres02/UVU/actions`.
2. Haz clic en la ejecución más reciente que tenga un ✅ verde.
3. Baja hasta **Artifacts** y descarga **UVU-ipa**. Es un `.zip`: descomprímelo
   y adentro está `UVU.ipa`.

> Si la ejecución tiene una ❌ roja, la app no compiló: no la instales y avísale a Claude.

---

## 2. Instalar en tu iPhone con Sideloadly

### La primera vez

1. Conecta el iPhone al PC con el cable y desbloquéalo.
   Si pregunta **"¿Confiar en esta computadora?"**, toca **Confiar**.
2. Abre **Sideloadly**.
3. Arrastra `UVU.ipa` al recuadro con el ícono de la app (o haz clic en él y búscalo).
4. En **iDevice**, elige tu iPhone.
5. En **Apple account**, escribe tu Apple ID (el mismo de tu iPhone).
6. Haz clic en **Start**. Te pedirá la contraseña de tu Apple ID; escríbela tú.
   Si tienes verificación en dos pasos, también te pedirá el código que llega a tu iPhone.
7. Espera a que diga **Done**.

### Activar el Modo de desarrollador (solo una vez)

iOS no deja abrir apps instaladas así hasta que lo actives:

1. En el iPhone: **Ajustes → Privacidad y seguridad → Modo de desarrollador** (está al final).
   - Si no aparece, primero intenta abrir UVU una vez; después aparecerá.
2. Actívalo. El iPhone se reiniciará.
3. Al encender, confirma **Activar**.

### Confiar en tu Apple ID como desarrollador (solo una vez)

1. **Ajustes → General → VPN y gestión de dispositivos**.
2. Toca tu Apple ID en "App de desarrollador" y luego **Confiar**.

Listo: abre **UVU** desde la pantalla de inicio.

---

## 3. Renovar la app cada 7 días

Con un Apple ID gratuito, Apple hace que la app deje de abrir a los 7 días.
**Tus datos no se pierden.** Para renovarla:

1. Conecta el iPhone y abre Sideloadly.
2. Arrastra el mismo `UVU.ipa` (o uno más nuevo) y haz clic en **Start**.

Se instala encima y todo sigue igual. Lo mismo para instalar una versión nueva.

> **Importante:** no borres la app del iPhone para reinstalarla. Si la borras,
> se borran tus datos. Antes de cualquier cambio grande, usa
> **Hoy → ⚙️ Ajustes → Exportar datos** para guardar un respaldo.

---

## 4. Respaldo de tus datos

En **Hoy → ⚙️ Ajustes**:

- **Exportar datos (JSON):** crea un archivo con todo (hábitos, tareas, journal, gym)
  y abre la hoja de Compartir para guardarlo en Archivos, iCloud Drive o enviártelo.
- **Importar respaldo:** elige un archivo exportado antes. Reemplaza **todos** los datos
  actuales (pide confirmación).

---

## 5. Si algún día tienes un Mac

1. Instala Xcode desde la App Store y [XcodeGen](https://github.com/yonaskolb/XcodeGen)
   (`brew install xcodegen`).
2. En la carpeta del proyecto ejecuta `xcodegen generate`.
3. Abre `UVU.xcodeproj`, elige un simulador de iPhone arriba y presiona ▶︎ (Cmd + R).
4. Para tu iPhone: conéctalo, elígelo arriba, y en el target **UVU → Signing & Capabilities**
   marca *Automatically manage signing* y elige tu Apple ID en *Team*.

### Activar iCloud (requiere Apple Developer, 99 USD/año)

Los modelos ya son compatibles con CloudKit. Hay que:
1. En `UVU/Models/Schema.swift`, cambiar `cloudKitDatabase: .none` por
   `.private(cloudKitContainerID)`.
2. Añadir las capacidades **iCloud (CloudKit)** y **Background Modes → Remote notifications**
   al target en `project.yml`.

---

## Estructura del proyecto

```
project.yml              Definición del proyecto (XcodeGen genera UVU.xcodeproj)
.github/workflows/       Compilación en la nube
UVU/
  App/                   Punto de entrada y pestañas
  Models/                Modelos de SwiftData (Habits, Tasks, Journal, Gym) y esquema
  Services/              Lógica sin interfaz: respaldo, datos iniciales…
  Features/              Pantallas por módulo (Today, Habits, Tasks, Journal, Gym, Calendar, Settings)
  Shared/                Componentes y extensiones reutilizables
  Resources/             Íconos, colores e Info.plist
UVUTests/                Tests automáticos
```

### Arquitectura

MVVM ligero: las vistas simples leen datos directamente con `@Query` de SwiftData;
las pantallas con lógica compleja tienen un ViewModel `@Observable`; y la lógica de negocio
(rachas, recurrencias, respaldo, notificaciones) vive en `Services/`, sin depender de la
interfaz, para poder probarla con tests.

## Fases

- [x] Fase 1: proyecto, navegación, modelos de datos, exportar/importar
- [x] Fase 2: hábitos + calendario
- [x] Sistema visual "DISCIPLINE" (solo modo oscuro; ver `CONTEXTO.md`, sección 7)
- [x] Fase 3: tareas y notificaciones
- [x] Fase 4: journal
- [x] Fase 5: gym
- [x] Fase 6: pantalla Hoy, calendario unificado y pulido visual
- [ ] Fase 7: widgets
