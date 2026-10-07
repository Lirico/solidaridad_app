# 📦 Mandar la "identidad" de la terminal al backend — explicado para cualquiera

> **Para quién:** todo el equipo (no hace falta saber de backend ni de Flutter).
> **Qué es:** la explicación simple de qué hicimos, por qué, y qué NO cambia.

---

## 1. El problema en una frase 🎯

La terminal Verifone tiene **tres números que la identifican**, y hoy solo uno de ellos
llegaba al sistema central. Ahora la app los **lee y los manda juntos en el login**, para
que el tech leader los use como le parezca (auditar, asociar equipos, soporte, lo que
decida).

---

## 2. Los tres números, en criollo 🧩

Pensá en un auto: tiene patente, número de chasis y número de motor. Son tres
identificadores **distintos** del mismo vehículo, puestos por tres entidades distintas.

| Dato | Qué es | Ejemplo | Quién lo puso |
|---|---|---|---|
| **`installation_id`** | La "patente" comercial: el código con el que el sistema de cobros reconoce la terminal. Ya se enviaba antes. | `05000001` | El procesador (lo cargan con SQL) |
| **`serialNumber`** | El "número de chasis": la matrícula de fábrica, grabada en el aparato. | `713-348-525` | Verifone (fábrica) |
| **`logical_device_id`** | El "número de motor" de Verifone: el ID que le asignó el sistema de gestión de terminales. Sirve para soporte. | `XXXXXXXX-XXXX-...` | Verifone (sistema de gestión) |

> ⚠️ **No son lo mismo.** El serial lo graba la fábrica; el `logical_device_id` lo
> asigna el sistema de gestión de Verifone. El `installation_id` lo asigna el procesador
> de cobros. Mandar los tres juntos evita confundirlos y le da al backend la foto completa.

---

## 3. La idea en una frase 💡

> En el momento en que el operador **inicia sesión** (login), la app le pregunta a la
> terminal "¿quién sos?" (serial + logical), y manda los **tres** datos pegados en la
> misma solicitud que ya se usa para entrar.

Es como cuando entrás a un edificio y en la recepción anotan tu nombre **y** tu DNI:
una sola parada, queda todo registrado junto.

---

## 4. Cómo se ve "por dentro" 📨

Antes, el login mandaba esto:

```json
{
  "username": "demo@solidaridad.local",
  "password": "demo1234",
  "installation_id": "05000001"
}
```

Ahora manda lo mismo **más** los dos datos del equipo (cuando puede leerlos):

```json
{
  "username": "demo@solidaridad.local",
  "password": "demo1234",
  "installation_id": "05000001",
  "serial_number": "713-348-525",
  "logical_device_id": "XXXXXXXX-XXXX-..."
}
```

Eso es todo. No hay pantallas nuevas, no hay botones nuevos, no hay pasos extra para el
operador.

---

## 5. ¿Qué se tocó? 🔧

**Solo la app (el "frente").** El backend **no se tocó**. En la rama
`feature/front_serial_to_backend`:

- La app aprende a leer el serial y el `logical_device_id` del equipo (el aparato ya
  sabía responder; faltaba pedírselo). Lo hace en el login y con paciencia: si el equipo
  tarda más de ~4 segundos o falla, sigue sin esos datos.
- Guarda esos datos en la memoria mientras la app está abierta.
- Los agrega al login cuando existen.

### ¿Y si el backend todavía no los espera? 🤔

No pasa nada. El backend acepta solicitudes con datos extra y **los ignora** (es como
llenar un formulario donde hay casilleros que todavía no están en el sistema: te lo toman
gual, no rompe nada). Cuando el tech leader quiera **usarlos**, se agregan dos casilleros
del lado del servidor — tarea chica y separada.

---

## 6. ¿Qué pasa en cada situación? 🧪

| Situación | ¿Qué hace la app? | ¿Anda el login? |
|---|---|---|
| Terminal Verifone real | Lee serial + logical y los manda | ✅ Sí |
| Emulador / compu de prueba (sin equipo) | Manda el login **sin** esos dos datos | ✅ Sí, igual que antes |
| El equipo tarda en responder | Espera unos segundos y si no, sigue sin ellos | ✅ Sí, nunca se queda colgado |

La regla de oro: **el login nunca se rompe por culpa de estos datos**. Si no se pueden
obtener, se omiten y listo.

---

## 7. Qué NO cambia para el operador 👤

- Misma pantalla de login, mismo usuario y contraseña.
- Sin pasos nuevos, sin configuraciones, sin pantallas de "set up".
- El único detalle invisible: la primera vez puede tardar 1 o 2 segundos extra mientras
  la app le pregunta al equipo quién es.

---

## 8. Qué hicimos para que no hiciera falta la terminal al programar 🛠️

- Se agregó un "simulacro" de los datos del equipo para las pruebas de laboratorio
  (build con `USE_MSR_MOCK=true`): devuelve un serial y un logical **claramente falsos**
  (`V660P-LAB-0001` / `LAB-LOGICAL-0001`), así no se confunden con los reales.
- Se escribieron tests automáticos (8 nuevos) y toda la suite del mobile sigue en verde
  (22 tests) con `flutter analyze` sin warnings.

---

## 9. Decisiones que quedan para después 🗓️

1. **El backend no guarda todavía** `serial_number` ni `logical_device_id`. Cuando el
   tech leader decida qué quiere hacer con ellos, hay que habilitarlos del lado del
   servidor (cambio chico: dos campos opcionales + decidir si se guardan).
2. **Verificación pendiente en la V660P real:** confirmar que el SDK devuelve el serial
   de la etiqueta (el `713-348-525` que viste bajo la tapita) y que el request de login
   lo incluye.
3. Hoy los datos viven en la memoria de la app mientras está abierta. Si algún día se
   quiere que la terminal "se acuerde" de quién es aunque la apagues, hay que guardarlos
   en el disco del equipo (fuera de este alcance).

---

## 10. Resumen en 3 líneas 📌

1. La terminal tiene 3 identificadores (comercial, de fábrica y de Verifone) y antes
   solo se mandaba uno.
2. Hicimos que la app los **lea y los mande juntos en el login**, sin tocar el backend
   y sin cambiar nada para el operador.
3. Si el equipo no puede leerlos (pruebas sin hardware), el login anda igual: esos dos
   datos son opcionales y nunca rompen nada.