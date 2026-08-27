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

## Estructura de carpetas esperada

```
flutter/                      # carpeta del proyecto Flutter (actualmente vacía, por inicializar)
├── lib/
│   ├── main.dart
│   ├── models/                # task.dart, attack.dart, game_session.dart
│   ├── screens/                # splash, game, task, game_over
│   ├── widgets/                # cable_game, dial_game, sequence_game, rhythm_game, health_bar, status_bar
│   ├── services/                # websocket_service, game_logic_service, notification_service
│   ├── providers/                # game_provider, connection_provider
│   ├── utils/                # constants, colors, logger
│   └── config/                # server_config
├── assets/ (images, sounds, animations)
└── pubspec.yaml
```

Nota: el README raíz del proyecto dice `tablet/` como nombre de carpeta; la carpeta real creada en este repo es `flutter/`. Usar `flutter/` como ubicación real del proyecto Flutter.

## Convenciones de trabajo

- Idioma de conversación con el usuario: español.
- Commits/código: normal (sin modo caveman), en inglés o español según lo que ya use el repo — seguir el estilo de mensajes existentes.
- Actualizar `PROGRESS.md` al completar cada tarea o sesión de trabajo relevante — no hace falta preguntar, hacerlo por defecto.
- No inventar IP/puerto del servidor backend real — usar mocks (`MockGameProvider`, ver especificación) hasta que el compañero de backend entregue el server real.
- Protocolo JSON entre tablet y servidor debe respetar exactamente los mensajes definidos en `docs/FLUTTER_TABLET_ESPECIFICACION.md` sección "Protocolo de Comunicación" — cualquier cambio se coordina con el equipo, no se decide unilateralmente desde el lado Flutter.

## Dónde mirar primero

- `README.md` — visión general del proyecto completo (los 3 componentes)
- `docs/FLUTTER_TABLET_ESPECIFICACION.md` — spec técnica completa del lado tablet (única fuente de verdad para mini-juegos y protocolo)
- `PROGRESS.md` — qué se ha hecho, qué falta, próximos pasos
