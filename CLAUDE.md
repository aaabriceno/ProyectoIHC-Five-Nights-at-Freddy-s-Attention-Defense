# CLAUDE.md — Five Nights at Freddy's: Attention Defense (Tablet App)

Contexto persistente para Claude Code. Leer esto antes de trabajar. Ver también `PROGRESS.md` para estado actual de avance.

## Qué es este proyecto

Juego para curso CS2H1 (IHC, UCSP). Combina detección de atención visual (gaze tracking) con mini-juegos en tablet. Jugador está frente a PC (ve juego 3D en Unity), sostiene tablet (hace tareas), cámara USB detecta hacia dónde mira. Animatrónico ataca si el jugador ignora la tablet O ignora la pantalla demasiado tiempo.

Repo completo tiene 3 componentes, hechos por 3 personas:
1. **Tablet (Flutter/Dart)** — MI RESPONSABILIDAD (Anthony)
2. **Backend (Python)** — gaze tracking (MediaPipe/OpenCV), lógica de ataque, WebSocket server — compañero
3. **Motor 3D (Unity/C#)** — escena de vigilancia, animatrónico, audio — compañero

Yo solo trabajo en el componente Tablet. No toco backend Python ni Unity salvo para acordar el protocolo JSON compartido.

## Mi responsabilidad (Tablet/Flutter)

QUÉ HAGO:
- UI tablet (Flutter, Material Design 3)
- 4 mini-juegos: cables, perillas, secuencias, ritmo
- Comunicación WebSocket con servidor Python (`web_socket_channel`)
- Captura y envío de estado de tareas (JSON)
- Feedback visual + háptico (vibración, sonido)

QUÉ NO HAGO:
- Gaze tracking (Python)
- Motor 3D / animatrónico (Unity)
- Lógica de decisión de ataque (Python)

Doc fuente completo: `docs/FLUTTER_TABLET_ESPECIFICACION.md` — especificación técnica detallada (mini-juegos, protocolo JSON, modelos Dart, cronograma, checklist). Consultar ahí para detalles de implementación.

## Stack técnico (tablet)

- Dart 3.0+, Flutter 3.13+
- Comunicación: WebSocket (`web_socket_channel`) — preferido sobre HTTP polling, latencia <50ms
- Estado: Provider (`ChangeNotifierProvider`)
- Notificaciones/feedback: `flutter_local_notifications`, `vibration`
- UI: Material Design 3, `CustomPainter` para mini-juegos dibujados, `flutter_svg`, `lottie`
- Storage local: `shared_preferences`, `sqflite` si hace falta

Servidor backend (referencia): `ws://[IP_SERVIDOR]:8000`, formato JSON. Ver especificación para todos los tipos de mensaje (`new_task`, `attack`, `task_completed`, `pause`, `game_over`, `reconnect_success`, etc).

## Estructura de carpetas (ya creada)

```
flutter/                      # proyecto Flutter real (package: fn_attention_defense_tablet)
├── lib/
│   ├── main.dart               # MultiProvider + MaterialApp, home: SplashScreen
│   ├── models/                # task.dart, attack.dart, game_session.dart
│   ├── screens/                # splash_screen, game_screen, game_over_screen
│   ├── widgets/                # health_bar, status_bar, placeholder_game_widget
│   ├── services/                # websocket_service, mock_server_service
│   ├── providers/                # connection_provider, game_provider
│   ├── utils/                # constants, colors, logger
│   └── config/                # server_config (useMock toggle)
├── assets/ (images, sounds, animations — vacíos, con .gitkeep)
└── pubspec.yaml
```

Nota: el README raíz del proyecto dice `tablet/` como nombre de carpeta; la carpeta real es `flutter/`. Usar `flutter/` como ubicación real del proyecto Flutter.

**Estado del esqueleto:** completo y fusionado a `main` (ver `PROGRESS.md`). Flujo Splash→Game→GameOver funciona end-to-end contra `MockServerService` (`ServerConfig.useMock = true`, no hay backend Python real todavía). Los 4 minijuegos (cables, perillas, secuencias, ritmo) NO están implementados — hoy hay un `PlaceholderGameWidget` genérico con botones "Completar/Fallar (simulado)" en su lugar. Sin gráficos/animaciones propias del juego todavía (eso es trabajo de la fase de minijuegos, con `CustomPainter` + `GestureDetector`).

## Convenciones de trabajo

- Idioma de conversación con el usuario: español.
- Commits/código: normal (sin modo caveman), en inglés o español según lo que ya use el repo — seguir el estilo de mensajes existentes.
- Actualizar `PROGRESS.md` al completar cada tarea o sesión de trabajo relevante — no hace falta preguntar, hacerlo por defecto.
- No inventar IP/puerto del servidor backend real — usar mocks (`MockServerService`, ver `flutter/lib/services/mock_server_service.dart`) hasta que el compañero de backend entregue el server real.
- Protocolo JSON entre tablet y servidor debe respetar exactamente los mensajes definidos en `docs/FLUTTER_TABLET_ESPECIFICACION.md` sección "Protocolo de Comunicación" — cualquier cambio se coordina con el equipo, no se decide unilateralmente desde el lado Flutter.

## Versionado semántico (SemVer)

Usamos [SemVer](https://semver.org/) para este proyecto: `MAJOR.MINOR.PATCH` (+ build number de Flutter, ej. `0.1.0+1`).

- **MAJOR** (`X.0.0`): cambios incompatibles/rediseño grande (ej. cambio de protocolo JSON que rompe compatibilidad con backend, reescritura de arquitectura).
- **MINOR** (`0.X.0`): funcionalidad nueva compatible hacia atrás (ej. un minijuego nuevo implementado, una pantalla nueva).
- **PATCH** (`0.0.X`): fixes de bugs, sin funcionalidad nueva (ej. corregir el bug de fuga de subscripción que tuvimos en el esqueleto).
- **Build number** (el `+N` al final): se incrementa en cada build/release, independiente de la versión semántica.

Convención de fases para este proyecto académico (sin release público):
- `0.1.x` — esqueleto/arquitectura base (fase actual, sin minijuegos reales)
- `0.2.x` — primer minijuego real implementado (ej. Cables)
- `0.x.0` — se sigue incrementando MINOR por cada minijuego/feature grande añadido
- `1.0.0` — versión considerada "completa" para la entrega/demo del curso (los 4 minijuegos + feedback + integración con backend/Unity real)

La versión vive en `flutter/pubspec.yaml` (campo `version:`). Actualizar el número al completar cada feature/fix significativo, y mencionarlo en el mensaje de commit correspondiente. No hace falta tags de git por ahora salvo que el usuario lo pida explícitamente.

## Dónde mirar primero

- `README.md` — visión general del proyecto completo (los 3 componentes)
- `docs/FLUTTER_TABLET_ESPECIFICACION.md` — spec técnica completa del lado tablet (única fuente de verdad para mini-juegos y protocolo)
- `PROGRESS.md` — qué se ha hecho, qué falta, próximos pasos
