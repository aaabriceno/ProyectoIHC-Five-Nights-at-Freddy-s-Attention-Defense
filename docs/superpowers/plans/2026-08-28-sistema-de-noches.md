# Sistema de Noches Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 5-night progression system to the Flutter tablet app — night counter, an in-game clock (12:00 AM → 6:00 AM per night), per-night retry (not a full game reset), and a final victory screen after night 5 — all driven by a new `night_status` server message, simulated in `MockServerService` until the real backend implements it.

**Architecture:** `GameSession` gains `nocheActual`/`horaEnJuego` fields updated by a new `night_status` case in `GameProvider.handleMessage`. `MockServerService` gains an independent `Timer.periodic` that advances a simulated clock and emits `night_status`, and emits `game_over` with `result: 'final_victory'` after night 5. `GameProvider` gains `reiniciarNoche()` (keeps `nocheActual`, clears health/tasks) alongside the existing `reset()` (full reset). A new `BarraRelojDeNoche` widget renders night/time in `GameScreen`. A new `PantallaVictoria` handles the night-5-complete case, parallel to the existing `GameOverScreen`.

**Tech Stack:** Dart 3.12, Flutter 3.44, `provider` package (already in use, no new dependencies).

**Spec:** [docs/superpowers/specs/2026-08-28-sistema-de-noches-design.md](../specs/2026-08-28-sistema-de-noches-design.md)

## Global Constraints

- **All Dart code (class/method/field/variable names, comments, doc comments) must be written in Spanish (castellano)** — this applies to every task below. The ONLY exceptions: (a) JSON protocol keys that are cross-team contract (`'night_status'`, `'night'`, `'in_game_time'`, `'seconds_elapsed'`, `'seconds_total'`, `'game_over'`, `'result'`, `'final_victory'`, `'final_stats'`, `'timestamp'`, and all pre-existing protocol keys like `'task_id'`) — these stay exactly as specified in `docs/FLUTTER_TABLET_ESPECIFICACION.md` and the sistema-de-noches spec, never translated; (b) Flutter/Dart framework-mandated names that cannot be renamed (`build`, `initState`, `dispose`, `StatelessWidget`, `Widget`, override signatures, package API names like `ChangeNotifier`, `Timer`, `StreamController`).
- No new pub dependencies — this feature only touches existing models/providers/widgets
- Protocol addition (`night_status`, `game_over.night`, `game_over.result: 'final_victory'`) is a PROPOSAL not yet implemented by the real backend — only `MockServerService` emits it; production code must not assume a real server sends it yet
- `dart analyze lib` must stay clean (the pre-existing `use_null_aware_elements` info-level lint on `game_provider.dart` is a known, accepted non-issue — do not "fix" it as part of this plan, and do not treat it as a new finding; its exact line number may shift as edits land, confirm it's still the only entry, still `info` severity, still about `use_null_aware_elements`)
- No automated unit tests in this phase — manual verification only (consistent with rest of project)
- Commit messages in Spanish, no Claude co-author trailer (per project convention)
- `PROGRESS.md` is gitignored — update it locally per session convention but do not `git add` it

---

## Task 1: GameSession and GameProvider — night/clock state — ✅ ALREADY COMPLETE

**Status:** Implemented and merged in commits `0bfd7c2` (initial, English names) and `1319c78` (correction to Spanish names, per Global Constraints). No further action needed for this task — it is documented here only so later tasks' "Interfaces: Consumes" sections have an accurate reference.

**Files (already modified):**
- `flutter/lib/models/game_session.dart`
- `flutter/lib/providers/game_provider.dart`

**Interfaces actually produced (current state, post-correction):**
- `GameSession.nocheActual` (`int`, default `1`)
- `GameSession.horaEnJuego` (`String`, default `'12:00 AM'`)
- `GameProvider.esVictoriaFinal` (`bool`, default `false`)
- `GameProvider.ultimaNocheDeGameOver` (`int?`, default `null`) — the night the last `game_over`/health-zero occurred in
- `GameProvider.reiniciarNoche()` — resets health/tasks/currentTask but keeps `nocheActual`/`horaEnJuego`
- `handleMessage` has a `case 'night_status':` reading `message['night']`/`message['in_game_time']` into `session.nocheActual`/`session.horaEnJuego`, and `case 'game_over':` reads `message['night']` (falling back to `session.nocheActual`) into `ultimaNocheDeGameOver`, branching on `message['result'] == 'final_victory'` to set `esVictoriaFinal` vs `isGameOver`
- `reset()` (pre-existing method, unchanged name) now also clears `esVictoriaFinal` and `ultimaNocheDeGameOver`

Current full content of `flutter/lib/providers/game_provider.dart` for reference (later tasks' dispatches should read the live file rather than trusting this snapshot, but this is accurate as of commit `1319c78`):

```dart
import 'package:flutter/foundation.dart';
import '../models/attack.dart';
import '../models/game_session.dart';
import '../models/task.dart';
import '../utils/logger.dart';

class GameProvider extends ChangeNotifier {
  GameSession session = GameSession(playerId: 'player_1');
  Attack? lastAttack;
  bool isGameOver = false;
  bool esVictoriaFinal = false;
  int? ultimaNocheDeGameOver;

  /// Asignado por la capa de pantallas al `sender` del provider activo
  /// (ver ConnectionProvider.sender) para que este provider pueda
  /// reportar resultados de tareas sin depender directamente de
  /// ConnectionProvider.
  void Function(Map<String, dynamic>)? sendToServer;

  void handleMessage(Map<String, dynamic> message) {
    final String type = message['type'] as String;
    switch (type) {
      case 'new_task':
        session.currentTask = Task.fromJson(message);
        break;
      case 'attack':
        final Attack attack = Attack.fromJson(message);
        lastAttack = attack;
        session.health = (session.health - attack.damage).clamp(0, 100);
        if (session.health == 0) {
          ultimaNocheDeGameOver = session.nocheActual;
          isGameOver = true;
        }
        break;
      case 'night_status':
        session.nocheActual = message['night'] as int;
        session.horaEnJuego = message['in_game_time'] as String;
        break;
      case 'game_over':
        ultimaNocheDeGameOver = (message['night'] as int?) ?? session.nocheActual;
        if (message['result'] == 'final_victory') {
          esVictoriaFinal = true;
        } else {
          isGameOver = true;
        }
        break;
      default:
        appLogger.w('Unhandled message type: $type');
    }
    notifyListeners();
  }

  void reportTaskCompleted({
    required bool success,
    required double timeTaken,
    Map<String, dynamic>? taskData,
  }) {
    if (session.currentTask == null) return;
    final Task task = session.currentTask!;

    if (success) {
      session.tasksCompleted++;
      session.score += 100;
    } else {
      session.tasksFailed++;
    }

    sendToServer?.call({
      'type': 'task_completed',
      'task_id': task.taskId,
      'task_type': task.taskType,
      'success': success,
      'time_taken': timeTaken,
      'attempts': 1,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      if (taskData != null) 'task_data': taskData,
    });

    session.currentTask = null;
    notifyListeners();
  }

  void reset() {
    session = GameSession(playerId: session.playerId);
    lastAttack = null;
    isGameOver = false;
    esVictoriaFinal = false;
    ultimaNocheDeGameOver = null;
    notifyListeners();
  }

  /// Reinicia vida/tareas/tarea actual para reintentar la MISMA noche,
  /// sin tocar `nocheActual` ni `horaEnJuego`. Se usa cuando el jugador
  /// falla (la vida llega a 0) a mitad de la noche.
  void reiniciarNoche() {
    session.health = 100;
    session.tasksCompleted = 0;
    session.tasksFailed = 0;
    session.currentTask = null;
    lastAttack = null;
    isGameOver = false;
    notifyListeners();
  }
}
```

No steps to execute for this task — skip directly to Task 2.

---

## Task 2: MockServerService — simulate night clock and final victory — ✅ ALREADY COMPLETE

**Status:** Implemented and merged in commits `aed2631` (initial, English names) and `1319c78` (correction to Spanish names, per Global Constraints). No further action needed for this task.

**Files (already modified):**
- `flutter/lib/services/mock_server_service.dart`

**Interfaces actually produced (current state, post-correction):**
- Emits `{'type': 'night_status', 'night': int, 'in_game_time': String, 'seconds_elapsed': int, 'seconds_total': int}` periodically, and eventually `{'type': 'game_over', 'result': 'final_victory', 'night': 5, 'final_stats': {...}}` — field names match exactly what Task 1's `GameProvider.handleMessage` reads
- `MockServerService.reiniciarRelojDeNoche()` — public method that resets the internal elapsed-seconds counter without changing which night is active
- Internal constants `segundosPorNoche` (360) and `totalNoches` (5) — later tasks (specifically Task 8) reference `segundosPorNoche` by this exact name when temporarily shortening it for manual testing

Current full content of `flutter/lib/services/mock_server_service.dart` for reference (later tasks' dispatches should read the live file rather than trusting this snapshot, but this is accurate as of commit `1319c78`):

```dart
import 'dart:async';
import '../utils/logger.dart';

/// Simula el comportamiento del backend (eventos new_task / attack /
/// night_status) para poder desarrollar y probar la app tablet antes de
/// que exista el backend real en Python. `night_status` es una PROPUESTA
/// de extensión del protocolo (ver
/// docs/superpowers/specs/2026-08-28-sistema-de-noches-design.md) — el
/// backend real todavía no manda esto.
class MockServerService {
  Timer? _taskTimer;
  Timer? _attackTimer;
  Timer? _temporizadorRelojDeNoche;
  int _taskCounter = 0;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  static const List<String> _taskTypes = ['cables', 'dials', 'sequence', 'rhythm'];

  // Duración de una noche en segundos reales. 360 = 6 minutos (spec real).
  // Se puede acortar temporalmente para pruebas manuales rápidas.
  static const int segundosPorNoche = 360;
  static const int totalNoches = 5;

  int _nocheActual = 1;
  int _segundosTranscurridosEstaNoche = 0;

  void start() {
    appLogger.i('MockServerService started');
    // Se retrasa la primera tarea porque este es un stream broadcast: si se
    // emite de forma síncrona, se pierde para cualquier listener que se
    // suscriba después (ej. GameScreen, que recién escucha un frame más
    // tarde tras la navegación desde SplashScreen).
    _taskTimer = Timer(const Duration(milliseconds: 300), _emitNextTask);
    _attackTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _emitAttack();
    });
    _temporizadorRelojDeNoche = Timer.periodic(const Duration(seconds: 1), (_) {
      _avanzarRelojDeNoche();
    });
  }

  void _emitNextTask() {
    _taskCounter++;
    final String type = _taskTypes[(_taskCounter - 1) % _taskTypes.length];
    _messageController.add({
      'type': 'new_task',
      'task_id': _taskCounter,
      'task_type': type,
      'duration': 25,
      'description': 'Tarea simulada: $type',
      'difficulty': 1,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'task_params': <String, dynamic>{},
    });
  }

  void _emitAttack() {
    _messageController.add({
      'type': 'attack',
      'attack_id': 'mock_atk_$_taskCounter',
      'damage': 20,
      'urgency': 'medium',
      'animatronic': 'Freddy',
      'message': 'Ataque simulado',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _avanzarRelojDeNoche() {
    _segundosTranscurridosEstaNoche++;
    _messageController.add({
      'type': 'night_status',
      'night': _nocheActual,
      'in_game_time': _formatearHoraEnJuego(_segundosTranscurridosEstaNoche),
      'seconds_elapsed': _segundosTranscurridosEstaNoche,
      'seconds_total': segundosPorNoche,
    });

    if (_segundosTranscurridosEstaNoche >= segundosPorNoche) {
      if (_nocheActual >= totalNoches) {
        _emitirVictoriaFinal();
      } else {
        _nocheActual++;
        _segundosTranscurridosEstaNoche = 0;
      }
    }
  }

  /// Convierte segundos transcurridos (0..segundosPorNoche) a una hora
  /// simulada 12:00 AM -> 6:00 AM, formateada como "H:MM AM".
  String _formatearHoraEnJuego(int segundosTranscurridos) {
    final double fraccion = segundosTranscurridos / segundosPorNoche;
    final int minutosTotalesSimulados = (fraccion * 6 * 60).round();
    int hora = 12 + (minutosTotalesSimulados ~/ 60);
    final int minuto = minutosTotalesSimulados % 60;
    if (hora > 12) hora -= 12;
    final String minutoStr = minuto.toString().padLeft(2, '0');
    return '$hora:$minutoStr AM';
  }

  void _emitirVictoriaFinal() {
    _temporizadorRelojDeNoche?.cancel();
    _attackTimer?.cancel();
    _taskTimer?.cancel();
    _messageController.add({
      'type': 'game_over',
      'result': 'final_victory',
      'night': totalNoches,
      'final_stats': <String, dynamic>{},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Llamado por GameProvider cuando el widget de tarea reporta que
  /// terminó, para que el mock avance a la siguiente tarea como lo
  /// haría un servidor real.
  void sendTaskCompleted(Map<String, dynamic> data) {
    appLogger.i('Mock received task_completed: $data');
    _taskTimer?.cancel();
    _taskTimer = Timer(const Duration(seconds: 1), _emitNextTask);
  }

  /// Reinicia el reloj de la noche actual (sin cambiar `_nocheActual`),
  /// para cuando el jugador reintenta tras fallar. No reinicia el timer
  /// de ataques/tareas, que siguen corriendo independientemente.
  void reiniciarRelojDeNoche() {
    _segundosTranscurridosEstaNoche = 0;
  }

  void stop() {
    _taskTimer?.cancel();
    _attackTimer?.cancel();
    _temporizadorRelojDeNoche?.cancel();
    _taskCounter = 0;
    _nocheActual = 1;
    _segundosTranscurridosEstaNoche = 0;
  }

  void dispose() {
    stop();
    _messageController.close();
  }
}
```

No steps to execute for this task — skip directly to Task 3.

---

## Task 3: ConnectionProvider — expose night reset alongside sender

**Files:**
- Modify: `flutter/lib/providers/connection_provider.dart`

**Interfaces:**
- Consumes: `MockServerService.reiniciarRelojDeNoche()` (Task 2)
- Produces: `ConnectionProvider.reiniciarNoche()` — calls through to the mock's `reiniciarRelojDeNoche()` when `ServerConfig.useMock` is true; no-op otherwise (the real backend will own night-reset logic itself once implemented)

- [ ] **Step 1: Read the current file**

Read `flutter/lib/providers/connection_provider.dart` in full before editing — it was not reproduced in this plan's context gathering beyond the `sender`/`messages` getters shown below, so confirm the rest of the file (imports, `ConnectionState` enum, `connect()`/`disconnect()`/`_handleDisconnect()` methods) matches what's expected before making this small addition. If anything differs from this excerpt, keep the rest of the file as-is and only add the method described in Step 2. Note: this file's pre-existing content uses English identifiers (`state`, `reconnectAttempts`, `messages`, `sender`, `connect`, `disconnect`) — those are OUT OF SCOPE for this task per the plan's global constraint (only NEW code written by this plan must be in Spanish; do not rename pre-existing methods/fields as a side effect of this task).

Known-current relevant excerpt (getters near the top of the class):

```dart
class ConnectionProvider extends ChangeNotifier {
  final WebSocketService _wsService = WebSocketService();
  final MockServerService _mockService = MockServerService();

  ConnectionState _state = ConnectionState.idle;
  int _reconnectAttempts = 0;

  ConnectionState get state => _state;
  int get reconnectAttempts => _reconnectAttempts;

  Stream<Map<String, dynamic>> get messages =>
      ServerConfig.useMock ? _mockService.messages : _wsService.messages;

  void Function(Map<String, dynamic>) get sender =>
      ServerConfig.useMock ? _mockService.sendTaskCompleted : _wsService.sendMessage;
```

- [ ] **Step 2: Add `reiniciarNoche()` method**

Add this method to the `ConnectionProvider` class, right after the `sender` getter shown above (before `void connect()`):

```dart
  /// Reinicia el reloj de la noche actual (misma noche, tiempo en 0) sin
  /// desconectar. Se usa cuando el jugador falla y reintenta la misma
  /// noche. No hace nada contra el backend real hasta que implemente su
  /// propia lógica de reinicio de noche (ver spec de protocolo propuesto).
  void reiniciarNoche() {
    if (ServerConfig.useMock) {
      _mockService.reiniciarRelojDeNoche();
    }
  }
```

- [ ] **Step 3: Verify it compiles**

Run: `cd flutter && dart analyze lib/providers/connection_provider.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add flutter/lib/providers/connection_provider.dart
git commit -m "feat: agregar reiniciarNoche a ConnectionProvider"
```

---

## Task 4: BarraRelojDeNoche widget

**Files:**
- Create: `flutter/lib/widgets/barra_reloj_de_noche.dart`

**Interfaces:**
- Consumes: nothing from other tasks directly (pure presentational widget, takes primitives as constructor params)
- Produces: `class BarraRelojDeNoche extends StatelessWidget { const BarraRelojDeNoche({required int nocheActual, required String horaEnJuego}); }` — consumed by Task 5's `GameScreen`

- [ ] **Step 1: Create the widget**

```dart
import 'package:flutter/material.dart';

/// Muestra la noche actual (1-5) y la hora simulada del reloj (12:00 AM ->
/// 6:00 AM). Puramente presentacional — GameScreen le pasa los valores
/// leídos de GameProvider.session.
class BarraRelojDeNoche extends StatelessWidget {
  final int nocheActual;
  final String horaEnJuego;

  const BarraRelojDeNoche({
    super.key,
    required this.nocheActual,
    required this.horaEnJuego,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.nightlight_round, size: 18),
            const SizedBox(width: 6),
            Text('Noche $nocheActual/5'),
          ],
        ),
        Row(
          children: [
            const Icon(Icons.access_time, size: 18),
            const SizedBox(width: 6),
            Text(horaEnJuego),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd flutter && dart analyze lib/widgets/barra_reloj_de_noche.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add flutter/lib/widgets/barra_reloj_de_noche.dart
git commit -m "feat: agregar widget BarraRelojDeNoche"
```

---

## Task 5: Wire BarraRelojDeNoche into GameScreen

**Files:**
- Modify: `flutter/lib/screens/game_screen.dart`

**Interfaces:**
- Consumes: `BarraRelojDeNoche` (Task 4), `GameProvider.session.nocheActual`/`horaEnJuego` (Task 1)
- Produces: no new public interface — this task only changes `GameScreen`'s internal layout

- [ ] **Step 1: Read the current file first**

Read `flutter/lib/screens/game_screen.dart` in full before editing. As of commit `fdb0e34` (last known state before Tasks 1-2 landed, which did not touch this file) it should look like:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/connection_provider.dart';
import '../providers/game_provider.dart';
import '../widgets/health_bar.dart';
import '../widgets/status_bar.dart';
import '../widgets/placeholder_game_widget.dart';
import '../widgets/cable_game_widget.dart';
import '../widgets/sequence_game_widget.dart';
import '../widgets/dial_game_widget.dart';
import '../widgets/rhythm_game_widget.dart';
import 'game_over_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _wired = false;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ConnectionProvider connection = context.watch<ConnectionProvider>();
    final GameProvider game = context.watch<GameProvider>();

    if (!_wired) {
      _wired = true;
      game.sendToServer = connection.sender;
      _messageSubscription = connection.messages.listen(game.handleMessage);
    }

    if (game.isGameOver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const GameOverScreen()),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: StatusBar(
          connectionState: connection.state,
          reconnectAttempts: connection.reconnectAttempts,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            HealthBar(health: game.session.health),
            const SizedBox(height: 16),
            Expanded(
              child: game.session.currentTask == null
                  ? const Center(child: Text('Esperando siguiente tarea...'))
                  : _buildTaskWidget(game, game.session.currentTask!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskWidget(GameProvider game, Task task) {
    switch (task.taskType) {
      case 'cables':
        return CableGameWidget(
          task: task,
          onComplete: (success, connections) {
            game.reportTaskCompleted(
              success: success,
              timeTaken: task.duration.toDouble(),
              taskData: {'connections': connections},
            );
          },
        );
      case 'sequence':
        return SequenceGameWidget(
          task: task,
          onComplete: (exito, secuenciaUsuario, errores) {
            game.reportTaskCompleted(
              success: exito,
              timeTaken: task.duration.toDouble(),
              taskData: {
                'correct_order': task.params['targets'] ?? [],
                'user_sequence': secuenciaUsuario,
                'errors': errores,
              },
            );
          },
        );
      case 'dials':
        return DialGameWidget(
          task: task,
          onComplete: (exito, diales) {
            game.reportTaskCompleted(
              success: exito,
              timeTaken: task.duration.toDouble(),
              taskData: {'dials': diales},
            );
          },
        );
      case 'rhythm':
        return RhythmGameWidget(
          task: task,
          onComplete: (exito, datosRitmo) {
            game.reportTaskCompleted(
              success: exito,
              timeTaken: task.duration.toDouble(),
              taskData: {'rhythm_data': datosRitmo},
            );
          },
        );
      default:
        return PlaceholderGameWidget(
          task: task,
          onComplete: (success) {
            game.reportTaskCompleted(success: success, timeTaken: 10.0);
          },
        );
    }
  }
}
```

If the live file differs from this (it shouldn't, since Tasks 1-2 only touched other files), stop and report BLOCKED rather than guessing.

- [ ] **Step 2: Add the import and render `BarraRelojDeNoche` below the existing `HealthBar`**

Add this import line among the existing widget imports (alphabetical position doesn't matter, but keep it near `status_bar.dart`):

```dart
import '../widgets/barra_reloj_de_noche.dart';
```

Change the `body:` section to insert `BarraRelojDeNoche` between `HealthBar` and the task area:

```dart
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            HealthBar(health: game.session.health),
            const SizedBox(height: 8),
            BarraRelojDeNoche(
              nocheActual: game.session.nocheActual,
              horaEnJuego: game.session.horaEnJuego,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: game.session.currentTask == null
                  ? const Center(child: Text('Esperando siguiente tarea...'))
                  : _buildTaskWidget(game, game.session.currentTask!),
            ),
          ],
        ),
      ),
```

- [ ] **Step 3: Verify it compiles**

Run: `cd flutter && dart analyze lib/screens/game_screen.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add flutter/lib/screens/game_screen.dart
git commit -m "feat: mostrar BarraRelojDeNoche en GameScreen"
```

---

## Task 6: Per-night retry in GameOverScreen, and navigation target

**Files:**
- Modify: `flutter/lib/screens/game_over_screen.dart`

**Interfaces:**
- Consumes: `GameProvider.reiniciarNoche()` (Task 1), `GameProvider.ultimaNocheDeGameOver` (Task 1), `ConnectionProvider.reiniciarNoche()` (Task 3), `GameScreen` (existing, imported for navigation target)
- Produces: no new public interface

- [ ] **Step 1: Rewrite `GameOverScreen`**

Current full content of `flutter/lib/screens/game_over_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/connection_provider.dart';
import 'splash_screen.dart';

class GameOverScreen extends StatelessWidget {
  const GameOverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final GameProvider game = context.watch<GameProvider>();
    final session = game.session;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('JUEGO TERMINADO',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Tareas completadas: ${session.tasksCompleted}'),
            Text('Tareas fallidas: ${session.tasksFailed}'),
            Text('Puntuación: ${session.score}'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.read<GameProvider>().reset();
                context.read<ConnectionProvider>().disconnect();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
                  (route) => false,
                );
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Replace with (per spec: fallo por vida ahora reintenta la MISMA noche, sin desconectar — se mantiene la sesión de conexión y `nocheActual`):

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/connection_provider.dart';
import 'game_screen.dart';

class GameOverScreen extends StatelessWidget {
  const GameOverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final GameProvider game = context.watch<GameProvider>();
    final session = game.session;
    final int? noche = game.ultimaNocheDeGameOver;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('JUEGO TERMINADO',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (noche != null) Text('Fallaste en la Noche $noche'),
            const SizedBox(height: 16),
            Text('Tareas completadas: ${session.tasksCompleted}'),
            Text('Tareas fallidas: ${session.tasksFailed}'),
            Text('Puntuación: ${session.score}'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.read<GameProvider>().reiniciarNoche();
                context.read<ConnectionProvider>().reiniciarNoche();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(builder: (_) => const GameScreen()),
                  (route) => false,
                );
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Note: the `splash_screen.dart` import is removed (no longer navigates there) and replaced with `game_screen.dart`. The `ConnectionProvider` import stays (still used for `reiniciarNoche()`). The pre-existing method call `context.read<GameProvider>().reset()` (English name, pre-existing) is deliberately replaced by `reiniciarNoche()` (the new per-night reset), not renamed — `reset()` itself is untouched, out of scope for this task.

- [ ] **Step 2: Verify it compiles**

Run: `cd flutter && dart analyze lib/screens/game_over_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add flutter/lib/screens/game_over_screen.dart
git commit -m "feat: reintentar la misma noche en vez de reiniciar todo el juego"
```

---

## Task 7: PantallaVictoria and wiring from GameScreen

**Files:**
- Create: `flutter/lib/screens/pantalla_victoria.dart`
- Modify: `flutter/lib/screens/game_screen.dart`

**Interfaces:**
- Consumes: `GameProvider.esVictoriaFinal`, `GameProvider.reset()` (Task 1, pre-existing method name unchanged), `SplashScreen` (existing)
- Produces: `class PantallaVictoria extends StatelessWidget` — a screen, not consumed by any later task in this plan

- [ ] **Step 1: Create `PantallaVictoria`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/connection_provider.dart';
import 'splash_screen.dart';

/// Se muestra cuando el jugador completa la Noche 5 (GameProvider.esVictoriaFinal).
class PantallaVictoria extends StatelessWidget {
  const PantallaVictoria({super.key});

  @override
  Widget build(BuildContext context) {
    final GameProvider game = context.watch<GameProvider>();
    final session = game.session;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¡SOBREVIVISTE LAS 5 NOCHES!',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Tareas completadas: ${session.tasksCompleted}'),
            Text('Tareas fallidas: ${session.tasksFailed}'),
            Text('Puntuación final: ${session.score}'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.read<GameProvider>().reset();
                context.read<ConnectionProvider>().disconnect();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
                  (route) => false,
                );
              },
              child: const Text('Jugar de nuevo'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd flutter && dart analyze lib/screens/pantalla_victoria.dart`
Expected: `No issues found!`

- [ ] **Step 3: Wire `esVictoriaFinal` navigation into `GameScreen`**

Read the current `flutter/lib/screens/game_screen.dart` first (Task 5 will have already landed by the time this task is dispatched, so it will include the `barra_reloj_de_noche.dart` import and the `BarraRelojDeNoche` widget in `body:` — add this task's changes alongside those, do not revert Task 5's work).

Add this import line alongside the existing screen imports (near `game_over_screen.dart`):

```dart
import 'pantalla_victoria.dart';
```

Change the game-over check inside `build()` to also handle `esVictoriaFinal`. The current code (after Task 5 landed) looks like:

```dart
    if (game.isGameOver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const GameOverScreen()),
        );
      });
    }
```

Replace with:

```dart
    if (game.esVictoriaFinal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const PantallaVictoria()),
        );
      });
    } else if (game.isGameOver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const GameOverScreen()),
        );
      });
    }
```

(`esVictoriaFinal` is checked first since both flags could theoretically be inspected in the same frame — final victory takes priority as the more specific/terminal state.)

- [ ] **Step 4: Verify it compiles**

Run: `cd flutter && dart analyze lib`
Expected: `No issues found!` (only the known pre-existing info-level lint on `game_provider.dart`, still present, still not touched)

- [ ] **Step 5: Commit**

```bash
git add flutter/lib/screens/pantalla_victoria.dart flutter/lib/screens/game_screen.dart
git commit -m "feat: agregar PantallaVictoria al completar la Noche 5"
```

---

## Task 8: End-to-End Manual Verification

**Files:** none (verification only)

**Interfaces:**
- Consumes: the complete feature from Tasks 1–7

- [ ] **Step 1: Temporarily shorten night duration for fast manual testing**

In `flutter/lib/services/mock_server_service.dart`, temporarily change:

```dart
  static const int segundosPorNoche = 360;
```

to:

```dart
  static const int segundosPorNoche = 15;
```

This lets a full night pass in 15 seconds instead of 6 minutes, so the full 5-night cycle can be observed in under 2 minutes instead of 30.

- [ ] **Step 2: Run the app**

Run: `cd flutter && flutter run -d linux` (or another available device per `flutter devices`)
Expected: app builds and launches without errors.

- [ ] **Step 3: Verify BarraRelojDeNoche renders and advances**

Observe: on reaching `GameScreen`, `BarraRelojDeNoche` shows "Noche 1/5" and a time starting near "12:00 AM", advancing roughly every second toward "6:00 AM" over ~15 seconds (with the shortened duration from Step 1).

- [ ] **Step 4: Verify night advances past night 1**

Observe: once the clock reaches "6:00 AM", the display should reset to "12:00 AM" and the night counter should read "Noche 2/5" (driven by the next `night_status` message from the mock, which increments the night and resets elapsed seconds once `segundosPorNoche` is reached).

- [ ] **Step 5: Verify per-night retry (not full reset)**

Wait for an attack to reduce health to 0 (attacks fire every 25s per the existing mock timer, independent of the shortened night duration) — or, to force it faster for this check only, temporarily also change `Duration(seconds: 25)` to `Duration(seconds: 3)` for the attack timer inside `start()`, same pattern as used in the original skeleton verification. Observe: `GameOverScreen` shows "Fallaste en la Noche N" matching whatever night was active. Tap "Reintentar". Observe: app returns to `GameScreen` (not `SplashScreen` — no reconnect delay), health bar is back to 100%, and `BarraRelojDeNoche` still shows the SAME night number as before the failure (not reset to "Noche 1/5"), clock reset to "12:00 AM".

- [ ] **Step 6: Verify final victory screen**

Let the mock run through all 5 nights uninterrupted (a full run takes ~75 seconds with the 15s-per-night shortcut from Step 1; avoid triggering the attack-timer shortcut from Step 5 during this pass, or revert it first, so health doesn't reach 0 mid-run). Observe: after night 5's clock reaches "6:00 AM", the app navigates to `PantallaVictoria` showing "¡SOBREVIVISTE LAS 5 NOCHES!" with final stats. Tap "Jugar de nuevo". Observe: app returns to `SplashScreen`, reconnects, and `BarraRelojDeNoche` on the next `GameScreen` shows "Noche 1/5" again (full `reset()` this time, since this is a fresh full run, not a per-night retry).

- [ ] **Step 7: Revert the temporary timing shortcuts**

Revert `segundosPorNoche` back to `360` in `mock_server_service.dart` (Step 1's change), and revert the attack timer back to `Duration(seconds: 25)` if it was changed in Step 5. Confirm with `git diff flutter/lib/services/mock_server_service.dart` that only the intended Task 1-7 changes remain (no leftover shortened timings).

- [ ] **Step 8: Final compile check**

Run: `cd flutter && dart analyze lib`
Expected: `No issues found!` except the known pre-existing info-level lint on `game_provider.dart` (`use_null_aware_elements`) — confirm no other findings crept in.

- [ ] **Step 9: Update PROGRESS.md**

`PROGRESS.md` is gitignored (per project convention) — update it locally with a dated log entry summarizing: sistema de noches implementado (5 noches, reloj 12am-6am simulado en 6 min reales), reintento por noche en vez de reset completo, PantallaVictoria nueva, protocolo `night_status` simulado en mock (pendiente de validar con el equipo backend/Unity antes de implementarse en el servidor real). Mention that this feature's code uses Spanish identifiers throughout (nocheActual, horaEnJuego, esVictoriaFinal, reiniciarNoche, BarraRelojDeNoche, PantallaVictoria), per the project's code-language convention. Do not `git add` it.

---

## Self-Review Notes

- **Spec coverage:** Task 1 (already complete) covers the `GameSession`/`GameProvider` data model (spec's "Modelo de datos" section) including `reiniciarNoche()` vs `reset()` distinction. Task 2 (already complete) covers the `MockServerService` simulation (spec's "MockServerService (simulación)" section) including the night-duration constant, clock formatting, and final-victory emission. Task 3 covers exposing a night-reset hook through `ConnectionProvider` (needed because `GameOverScreen`'s retry button must reach the mock's `reiniciarRelojDeNoche()`, and `ConnectionProvider` is the layer screens already use to reach the mock/websocket). Task 4 covers the `BarraRelojDeNoche` widget (spec's "UI" section). Task 5 wires it into `GameScreen`. Task 6 covers the `GameOverScreen` retry-same-night behavior and "Fallaste en la Noche N" display (spec's "GameOverScreen (modificación)" section). Task 7 covers `PantallaVictoria` (spec's "Nueva pantalla: VictoryScreen" section, renamed to Spanish) and the `esVictoriaFinal` navigation branch in `GameScreen`. Task 8 covers the spec's "Testing" section, including the temporary-shortened-duration technique explicitly called out in the spec.
- **Placeholder scan:** no TBD/TODO; all steps carry complete code or, where a file's full current content wasn't guaranteed stable across tasks (Task 3's `ConnectionProvider`, Task 5's and Task 7's `game_screen.dart`), an explicit instruction to read the live file first before making the described addition — this is not a placeholder, it's a necessary caution given multiple tasks touch the same file sequentially.
- **Type consistency:** `GameSession.nocheActual`/`horaEnJuego` (Task 1, already complete) match the field names read by `BarraRelojDeNoche`'s constructor params in Task 4/5 (`nocheActual`, `horaEnJuego`). `GameProvider.ultimaNocheDeGameOver`/`esVictoriaFinal` (Task 1, already complete) match usage in `GameOverScreen` (Task 6) and `GameScreen`'s victory check (Task 7). `MockServerService`'s emitted `night_status` field names (`night`, `in_game_time`, `seconds_elapsed`, `seconds_total` — JSON protocol keys, deliberately NOT translated per Global Constraints) match exactly what `GameProvider.handleMessage`'s `case 'night_status':` reads (Task 1, already complete). `ConnectionProvider.reiniciarNoche()` (Task 3) matches the call site in `GameOverScreen` (Task 6). `MockServerService.reiniciarRelojDeNoche()` (Task 2, already complete) matches the call inside `ConnectionProvider.reiniciarNoche()` (Task 3). `PantallaVictoria` (Task 7) matches the class name referenced in `GameScreen`'s import and navigation code (Task 7 Step 3).
- **Language correction note:** this plan was originally written with English identifiers throughout (`currentNight`, `isFinalVictory`, `NightClockBar`, `VictoryScreen`, etc.), matching Tasks 1-2's first implementation pass. Mid-execution, the user clarified that ALL code (not just commit messages) must use Spanish identifiers. Tasks 1-2 were corrected in commit `1319c78` before this plan document was rewritten; Tasks 3-8 below were rewritten from scratch with Spanish names before being dispatched to any implementer, so no further correction pass should be needed for them.
