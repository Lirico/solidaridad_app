# Guía para probar el proyecto en Windows

> **Para quién es esta guía:** para alguien que no es programador y quiere probar
> la aplicación en su PC con Windows. Seguí los pasos **en orden** y no te saltees
> ninguno. Si algo no funciona, avisá al equipo de desarrollo.

---

## ¿Qué vas a instalar y por qué?

La aplicación tiene dos partes que se comunican entre sí:

1. **El "motor" (backend):** es el servidor que procesa los pagos. Corre dentro
   de un "Linux virtual" llamado **WSL** que se instala dentro de Windows.
2. **La "pantalla" (la app):** es la ventana que vas a ver y usar. Se abre como
   una aplicación normal de Windows.

Para que funcione, hay que instalar 4 cosas (solo la primera vez):

| Qué | Para qué sirve |
|-----|----------------|
| **WSL** | Un "Linux virtual" dentro de Windows donde corre el motor |
| **Docker Desktop** | Para levantar las bases de datos del motor |
| **Flutter** | Para abrir la pantalla (la app) |
| **Visual Studio** | Una herramienta que Flutter necesita para crear la app de Windows |

> ⏱️ **Tiempo estimado:** la instalación completa puede llevar **1 a 2 horas**
> (sobre todo por las descargas). La parte de "usar la app" después es rápida.

---

## Paso 0 — Requisitos previos

- Una PC con **Windows 11** (o Windows 10 actualizado).
- Conexión a internet.
- Espacio libre en disco (al menos **20 GB**).

---

## Paso 1 — Instalar WSL (el "Linux virtual")

1. Abrí el menú **Inicio**, escribí **PowerShell**, hacé clic derecho sobre
   "Windows PowerShell" y elegí **"Ejecutar como administrador"**.
2. En la ventana que se abre, pegá este comando y presioná **Enter**:

   ```
   wsl --install
   ```

3. Esperá a que termine. **Si Windows te pide reiniciar, reiniciá.**
4. Después de reiniciar, se va a abrir una ventana para configurar **Ubuntu**
   (te va a pedir crear un usuario y una contraseña). **Anotá esa contraseña**,
   la vas a necesitar. Completá ese paso.

> ✅ **Listo cuando:** puedas abrir "Ubuntu" desde el menú Inicio y veas una
> ventana negra con texto.

---

## Paso 2 — Instalar Docker Desktop

1. Andá a https://www.docker.com/products/docker-desktop/ y descargá
   **Docker Desktop for Windows**.
2. Ejecutá el instalador y seguí los pasos (dejá las opciones por defecto).
3. Cuando termine, **abrí Docker Desktop** y esperá a que diga que está
   corriendo (el ícono de la ballena en la barra de abajo deja de animarse).
4. Andá a **Settings → Resources → WSL Integration** y asegurate de que la
   casilla de **Ubuntu** esté marcada. Aplicá los cambios.

> ✅ **Listo cuando:** Docker Desktop esté abierto y diga "Engine running".

---

## Paso 3 — Instalar Flutter

1. Andá a https://docs.flutter.dev/get-started/install/windows/mobile y seguí
   la guía oficial para descargar e instalar **Flutter**.
2. La guía te va a pedir que agregues Flutter al "PATH" de Windows. Seguí esos
   pasos (es importante).
3. Cerrá y volvé a abrir la terminal (PowerShell) para que tome los cambios.

> ✅ **Listo cuando:** al escribir `flutter --version` en PowerShell, muestre
> una versión (ej. `Flutter 3.44.4`).

---

## Paso 4 — Instalar Visual Studio (con C++)

1. Andá a https://visualstudio.microsoft.com/downloads/ y descargá
   **Visual Studio 2022 Community** (es gratis).
2. Ejecutá el instalador.
3. En la pantalla de **"Cargas de trabajo"**, marcá la casilla
   **"Desarrollo para escritorio con C++"** (Desktop development with C++).
4. Hacé clic en **"Instalar"** y esperá (descarga varios GB, tarda un rato).
5. Cuando termine, **cerrá y reabrí la terminal**.

> ✅ **Listo cuando:** al escribir `flutter doctor` en PowerShell, la línea de
> "Visual Studio" aparezca con un **✓** (verde).

---

## Paso 5 — Clonar el proyecto (descargar el código)

1. Abrí la terminal de **Ubuntu** (menú Inicio → Ubuntu).
2. Pegá estos comandos uno por uno, presionando **Enter** después de cada uno:

   ```
   sudo apt update
   sudo apt install -y git make curl
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```

   > Cuando pida contraseña, usá la que creaste en el Paso 1.

3. Cerrá y volvé a abrir Ubuntu.
4. Ahora cloná el proyecto (reemplazá `<URL-DEL-REPOSITORIO>` por la dirección
   que te dé el equipo):

   ```
   mkdir -p ~/dev
   cd ~/dev
   git clone <URL-DEL-REPOSITORIO>
   cd solidaridad_app
   ```

> ✅ **Listo cuando:** estés dentro de la carpeta `solidaridad_app` (lo ves en
> el texto de la terminal).

---

## Paso 6 — Encender el motor (backend)

> ⚠️ **Importante:** Docker Desktop debe estar abierto y corriendo.

1. En la terminal de **Ubuntu**, dentro de la carpeta `solidaridad_app`, pegá:

   ```
   make dev
   ```

2. Esperá. La primera vez tarda varios minutos (descarga e instala todo).
3. Cuando termine, vas a ver un mensaje que dice **"Local backend ready"**.
4. **NO cierres esta ventana.** El motor tiene que quedar corriendo mientras
   usás la app.

> ✅ **Listo cuando:** veas "Local backend ready" en la terminal de Ubuntu.

---

## Paso 7 — Abrir la app (la pantalla)

1. Abrí una **nueva** ventana de **PowerShell** (no cierres la de Ubuntu).
2. Andá a la carpeta del proyecto. Escribí esto (reemplazá `<tu-usuario>` por tu
   usuario de Ubuntu):

   ```
   cd \\wsl$\Ubuntu\home\<tu-usuario>\dev\solidaridad_app\mobile
   ```

   > 💡 **Más fácil:** abrí la carpeta `solidaridad_app` desde el Explorador de
   > Windows (está en `\\wsl$\Ubuntu\home\<tu-usuario>\dev\`), y dentro de la
   > carpeta `mobile`, hacé clic derecho → "Abrir en Terminal".

3. En esa terminal, pegá:

   ```
   flutter pub get
   flutter run -d windows
   ```

4. Esperá a que compile (la primera vez tarda unos minutos). Se va a abrir una
   **ventana de la aplicación**.

> ✅ **Listo cuando:** veas la ventana de la app con el logo de Solidaridad.

---

## Paso 8 — Probar la aplicación

En la ventana de la app, iniciá sesión con estos datos de prueba:

| Campo | Valor |
|-------|-------|
| **Usuario / correo** | `demo@solidaridad.local` |
| **Contraseña** | `demo1234` |

Después de entrar, podés probar una venta de gas (elegí un producto, poné un
monto y una tarjeta de prueba).

---

## Cómo apagar todo (cuando termines)

1. En la ventana de la app, cerrá la ventana.
2. En la terminal de **PowerShell**, presioná la tecla **q** (para cerrar la app
   de forma limpia).
3. En la terminal de **Ubuntu**, presioná **Ctrl + C** (detiene el motor).
4. Opcional: para apagar las bases de datos, en Ubuntu escribí:

   ```
   make down
   ```

---

## Solución de problemas comunes

| Problema | Qué hacer |
|----------|-----------|
| `flutter doctor` marca Visual Studio en rojo | Reabrí la terminal o reiniciá la PC. Si sigue, revisá que en el instalador de Visual Studio esté marcada la carga "Desarrollo para escritorio con C++". |
| `make dev` da error de Docker | Asegurate de que **Docker Desktop esté abierto** y diga "Engine running". |
| La app no conecta con el motor | Verificá que la terminal de Ubuntu siga abierta mostrando "Local backend ready". |
| No recordás la contraseña de Ubuntu | Avisá al equipo de desarrollo. |

---

## Resumen rápido (para la segunda vez en adelante)

1. Abrí **Docker Desktop**.
2. Abrí **Ubuntu** → `cd ~/dev/solidaridad_app` → `make dev` (dejá la ventana abierta).
3. Abrí **PowerShell** → andá a la carpeta `mobile` → `flutter run -d windows`.
4. Usá la app. Para terminar: `q` en PowerShell, `Ctrl+C` en Ubuntu.
