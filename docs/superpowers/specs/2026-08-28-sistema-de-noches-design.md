# Sistema de Noches (Tablet Flutter) — Design Spec

**Fecha:** 2026-08-28
**Autor:** Anthony (especialista Frontend Mobile / Networking)
**Estado:** Aprobado, listo para implementation plan

## Contexto

El juego original (FNAF) se juega en 5 noches, cada una simulando el horario 12:00 AM → 6:00 AM. En este proyecto cada noche dura 6 minutos reales (1 hora simulada ≈ 1 minuto real). La dificultad aumenta noche a noche: los animatrónicos atacan con más frecuencia/velocidad en noches avanzadas. Esta lógica de dificultad vive en el **backend Python** (fuera de este spec) — Flutter solo recibe y muestra el estado.

Un requisito importante detectado durante el diseño: el número de noche y el reloj en curso se muestran **tanto en la tablet como en la pantalla del PC (escena Unity)**. Por eso el reloj/noche deben originarse en una única fuente de verdad — el servidor — y no calcularse de forma independiente en cada cliente, para evitar desincronización entre tablet y monitor.

## Objetivo de esta fase

Implementar en Flutter:
- Modelo de datos para noche actual y reloj en curso
- UI que muestra "Noche N/5" + hora simulada (ej. "3:47 AM")
- Manejo de mensajes del protocolo que traen este estado
- Flujo de reintento por noche (fallar no reinicia todo el juego, solo esa noche)
- Pantalla de victoria final al completar la Noche 5
- Simulación completa en `MockServerService` (el backend real aún no existe)

Fuera de alcance: lógica de dificultad real (eso decide el backend Python), más minijuegos, mejoras visuales generales, la interfaz de la pantalla PC/Unity (componente de otro compañero).

## Propuesta de protocolo (a validar con el equipo)

**IMPORTANTE:** esto es una extensión aditiva propuesta al protocolo existente (`docs/FLUTTER_TABLET_ESPECIFICACION.md`). No se implementa en el backend real sin que el usuario lo coordine primero con su compañero de backend/Unity. Mientras tanto, se simula en el mock.

Nuevo mensaje servidor → tablet/Unity, enviado periódicamente (~cada segundo) durante una noche activa:

```json
{
  "type": "night_status",
  "night": 3,
  "in_game_time": "03:47 AM",
  "seconds_elapsed": 227,
  "seconds_total": 360
}
```

- `night`: entero 1-5, noche actual
- `in_game_time`: string ya formateado por el servidor (ej. "03:47 AM") — el cliente no calcula la hora, solo la pinta
- `seconds_elapsed` / `seconds_total`: para que el cliente pueda mostrar barra de progreso si quiere, sin recalcular el reloj

El mensaje `game_over` existente gana un campo opcional `"night": N` indicando en qué noche ocurrió.

Se propone un nuevo `result` para `game_over` cuando se completa la Noche 5 exitosamente: `"result": "final_victory"` (distinto de `"result": "loss"` que ya existe). Si el jugador sobrevive una noche que no es la 5, no hay `game_over` — el servidor simplemente inicia la siguiente noche (se podría mandar un `night_status` con `night` incrementado, o un mensaje nuevo `night_complete`; se deja como detalle de implementación del backend, Flutter solo necesita reaccionar a que `night` cambió en el próximo `night_status` que reciba).

## Modelo de datos (Flutter)

### `GameSession` (modificación)
Se agregan dos campos:
```dart
int currentNight;      // 1-5, default 1
String inGameTime;     // "12:00 AM" default
```

### `GameProvider` (modificación)
- `handleMessage` gana un `case 'night_status':` que actualiza `session.currentNight` y `session.inGameTime`, y detecta si `night` subió respecto al valor anterior (para saber que se completó la noche anterior, útil para logging/UI, no bloqueante)
- `handleMessage` en el `case 'game_over':` lee el campo opcional `night` del mensaje y lo guarda para mostrarlo en la pantalla correspondiente
- Nuevo campo `bool isFinalVictory` en `GameProvider`, se pone en `true` cuando `game_over.result == 'final_victory'`

### Reintento por noche (cambio de comportamiento)
- `GameProvider.reset()` actual reinicia TODO el estado (vida, tareas, noche) — esto se mantiene como el reset "duro" (usado al iniciar sesión desde cero)
- Nuevo método `GameProvider.resetNight()`: reinicia vida a 100, `tasksCompleted`/`tasksFailed` a 0, `currentTask` a null, pero **mantiene** `currentNight` sin cambios
- `GameOverScreen` usa `resetNight()` en el botón "Reintentar" cuando el fallo NO fue en la Noche 5 con victoria (es decir, siempre que sea un fallo por vida=0); solo un botón "Volver al menú" (si se agrega en el futuro) usaría el `reset()` duro

## UI

### Nuevo widget: `NightClockBar`
Reemplaza/complementa el `StatusBar` actual dentro de la barra superior de `GameScreen`. Muestra:
- Texto "Noche {currentNight}/5"
- Reloj "{inGameTime}"
- Estilo visual simple (texto + ícono de luna/reloj), consistente con el resto de la UI actual (Material Design 3, sin assets de imagen todavía — eso es la pieza de "tema visual", fuera de este spec)

### `GameOverScreen` (modificación)
- Muestra "Fallaste en la Noche {night}" además de las estadísticas existentes
- Botón "Reintentar" llama `GameProvider.resetNight()` en vez de `reset()`, y navega de vuelta a `GameScreen` en vez de `SplashScreen` (no hace falta reconectar, la sesión de conexión sigue activa)

### Nueva pantalla: `VictoryScreen`
Se muestra cuando `GameProvider.isFinalVictory == true` (completó Noche 5). Contenido mínimo: mensaje de victoria, estadísticas finales acumuladas, botón "Jugar de nuevo" que hace `reset()` duro y vuelve a `SplashScreen`.

## Flujo completo

```
SplashScreen (conecta)
  → GameScreen, Noche 1, reloj en 12:00 AM
  → recibe night_status periódicamente, reloj avanza
  → si vida llega a 0 antes de las 6:00 AM:
      → GameOverScreen ("Fallaste en la Noche N")
      → Reintentar → resetNight() → vuelve a GameScreen, MISMA noche, reloj en 12:00 AM
  → si el reloj llega a 6:00 AM (sobrevive):
      → si currentNight < 5: servidor manda night_status con night+1 → GameScreen sigue mostrando, ahora Noche N+1
      → si currentNight == 5: servidor manda game_over con result: "final_victory" → VictoryScreen
```

## MockServerService (simulación)

- Se agrega un `Timer.periodic` de 1 segundo que:
  - Calcula `seconds_elapsed` desde que arrancó la noche actual
  - Convierte a hora simulada: `12:00 AM + (seconds_elapsed / 360 segundos) * 6 horas`
  - Emite `night_status` con los valores calculados
  - Al llegar a `seconds_total = 360` (6 min): si `night < 5`, incrementa `night` y resetea `seconds_elapsed`; si `night == 5`, emite `game_over` con `result: "final_victory"`
- El mock ya tiene timers de tareas/ataques existentes — este es un timer adicional independiente, no reemplaza a los anteriores
- Al fallar (vida llega a 0 vía ataques simulados existentes), el mock simplemente deja de avanzar su timer de noche hasta que `GameProvider` le indique reinicio (esto requiere que `ConnectionProvider`/`MockServerService` expongan un método para reiniciar el timer de noche sin tocar `night`, análogo a cómo ya existe `sendTaskCompleted`)

## Testing

- `dart analyze` limpio
- Verificación manual: correr en Linux desktop, confirmar que `NightClockBar` muestra "Noche 1/5" y el reloj avanza desde 12:00 AM
- Acortar temporalmente la duración de noche en el mock (de 360s a algo más corto, ej. 20s) para poder verificar manualmente el ciclo completo de: avance de noche → Noche 5 → VictoryScreen, y por separado: fallo de vida → Reintentar → misma noche. Revertir el valor antes de commitear (mismo patrón ya usado para verificar el esqueleto original)
- Sin unit tests automatizados (consistente con el resto del proyecto en esta fase)

## Notas de coordinación con el equipo

Antes de que el backend Python implemente `night_status` y el campo `night` en `game_over`, el usuario debe:
1. Compartir este spec (o al menos la sección de protocolo) con su compañero de backend
2. Confirmar que Unity puede consumir el mismo formato de `night_status` para su propio HUD en la pantalla PC
3. Ajustar el formato si el equipo prefiere otro (ej. mandar `in_game_time` como minutos/segundos crudos en vez de string ya formateado, y que cada cliente lo formatee — a decidir en equipo, no unilateralmente desde Flutter)

Hasta que eso se acuerde, el desarrollo continúa 100% contra el mock, sin bloquear el progreso de Flutter.
