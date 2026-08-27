# Esqueleto Flutter Tablet App — Design Spec

**Fecha:** 2026-08-27
**Autor:** Anthony (especialista Frontend Mobile / Networking)
**Estado:** Aprobado, listo para implementation plan

## Contexto

Proyecto "Five Nights at Freddy's - Attention Defense" (curso CS2H1, UCSP). Componente tablet en Flutter/Dart es responsabilidad de Anthony. Especificación técnica completa ya existe en `docs/FLUTTER_TABLET_ESPECIFICACION.md` — este documento define el esqueleto inicial del proyecto Flutter, sin implementar aún los 4 minijuegos.

Carpeta real del proyecto: `flutter/` (actualmente vacía). El README raíz menciona `tablet/` pero esa carpeta no existe — se usa `flutter/`.

## Objetivo de esta fase

Dejar el proyecto Flutter inicializado y estructurado, con:
- Conexión WebSocket funcional (contra mock, backend real no existe todavía)
- Modelos de datos según protocolo JSON del spec
- Providers de estado (conexión + juego)
- Pantallas de flujo base (splash → game → game over)
- Reconexión automática
- Placeholders donde van los 4 minijuegos (implementación real: próxima sesión)

Fuera de alcance: implementación de los 4 minijuegos (cables, perillas, secuencias, ritmo), tests unitarios, build de APK, integración con backend/Unity reales.

## Decisiones

- **State management:** Provider (`ChangeNotifierProvider`), según especificación — más simple, ya documentado para el equipo.
- **Comunicación:** WebSocket vía `web_socket_channel`, no HTTP polling.
- **Backend:** no existe aún. Se usa `MockServerService` que simula mensajes `new_task` y `attack` con delays, activable/desactivable desde `config/server_config.dart`.
- **Minijuegos:** no se implementan ahora. Se usa un `PlaceholderGameWidget` genérico en `widgets/` que muestra el `task_type` recibido y permite simular `task_completed` con un botón, para poder probar el flujo completo end-to-end sin lógica real de juego.

## Estructura de carpetas

```
flutter/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── task.dart
│   │   ├── attack.dart
│   │   └── game_session.dart
│   ├── screens/
│   │   ├── splash_screen.dart
│   │   ├── game_screen.dart
│   │   ├── task_screen.dart
│   │   └── game_over_screen.dart
│   ├── widgets/
│   │   ├── health_bar.dart
│   │   ├── status_bar.dart
│   │   └── placeholder_game_widget.dart
│   ├── services/
│   │   ├── websocket_service.dart
│   │   ├── mock_server_service.dart
│   │   └── notification_service.dart
│   ├── providers/
│   │   ├── connection_provider.dart
│   │   └── game_provider.dart
│   ├── utils/
│   │   ├── constants.dart
│   │   ├── colors.dart
│   │   └── logger.dart
│   └── config/
│       └── server_config.dart
├── assets/
│   ├── images/.gitkeep
│   ├── sounds/.gitkeep
│   └── animations/.gitkeep
└── pubspec.yaml
```

## Componentes

### Modelos (`lib/models/`)
`Task`, `Attack`, `GameSession` — exactamente como se definen en `docs/FLUTTER_TABLET_ESPECIFICACION.md` sección "Estructura de Datos Local (Dart Model)", con `fromJson` factory constructors.

### `ConnectionProvider`
- Estados: `idle`, `connecting`, `connected`, `reconnecting`, `error`
- Lógica de reconexión: cada 3s, máximo 5 intentos, luego pasa a `error`
- Expone estado actual a la UI (StatusBar)

### `WebSocketService`
- Conecta a `ws://[IP]:8000` (IP configurable en `server_config.dart`)
- Envía mensaje `connect` al abrir
- Escucha stream y despacha por `type` (`new_task`, `attack`, `pause`, `game_over`, `reconnect_success`) hacia `GameProvider`
- Métodos: `sendMessage(Map)`, `connect(String address)`, `disconnect()`

### `MockServerService`
- No es un server real — simula comportamiento del backend dentro de la app cuando `server_config.dart` tiene `useMock = true`
- Emite `new_task` cada cierto tiempo y `attack` ocasional, con los mismos formatos JSON que usaría el backend real
- Permite probar toda la UI y el flujo de estados sin depender del compañero de backend

### `GameProvider`
- Estado de sesión: vida, tarea actual, score, tasksCompleted/Failed
- Recibe eventos desde `WebSocketService`/`MockServerService`, actualiza estado, notifica listeners
- Métodos para reportar `task_completed` / `task_failed` de vuelta

### Pantallas
- `SplashScreen`: intenta conectar (real o mock), muestra spinner, transiciona a `GameScreen` al conectar
- `GameScreen`: contenedor principal — `StatusBar` (arriba: conexión, nivel, tiempo) + `HealthBar` + área de tarea actual (`TaskScreen`/`PlaceholderGameWidget`)
- `TaskScreen`: envuelve el `PlaceholderGameWidget` correspondiente al `task_type` actual
- `GameOverScreen`: estadísticas finales, botón reintentar/volver al menú

### `PlaceholderGameWidget`
Muestra `task_type`, `description`, cronómetro countdown, y un botón "Completar (simulado)" que dispara `task_completed` con `success: true`. Sirve de stand-in hasta que se implementen los 4 minijuegos reales.

## Dependencias (pubspec.yaml)

Según especificación: `web_socket_channel`, `provider`, `flutter_local_notifications`, `vibration`, `flutter_svg`, `lottie`, `logger`, `shared_preferences`. `sqflite` se omite por ahora (no hay necesidad de DB local en el esqueleto).

## Testing

- `flutter pub get` sin errores
- `flutter run` (emulador Android, tablet 10", API 30+) levanta la app
- Flujo manual: Splash conecta a mock → GameScreen recibe `new_task` mock → tocar "Completar (simulado)" → recibe siguiente tarea o `attack` mock → HealthBar baja → tras varios eventos, `game_over` mock → GameOverScreen muestra stats
- No hay unit tests automatizados en esta fase (fuera de alcance)

## Próximos pasos (fuera de este spec)

1. Implementar los 4 minijuegos reales reemplazando `PlaceholderGameWidget`
2. Feedback háptico/sonido real vía `NotificationService`
3. Conectar contra backend Python real cuando esté disponible
4. Tests
