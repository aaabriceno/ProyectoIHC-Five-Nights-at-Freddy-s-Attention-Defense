# Sistema de Noches Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 5-night progression system to the Flutter tablet app — night counter, an in-game clock (12:00 AM → 6:00 AM per night), per-night retry (not a full game reset), and a final victory screen after night 5 — all driven by a new `night_status` server message, simulated in `MockServerService` until the real backend implements it.

**Architecture:** `GameSession` gains `currentNight`/`inGameTime` fields updated by a new `night_status` case in `GameProvider.handleMessage`. `MockServerService` gains an independent `Timer.periodic` that advances a simulated clock and emits `night_status`, and emits `game_over` with `result: 'final_victory'` after night 5. `GameProvider` gains `resetNight()` (keeps `currentNight`, clears health/tasks) alongside the existing `reset()` (full reset). A new `NightClockBar` widget renders night/time in `GameScreen`. A new `VictoryScreen` handles the night-5-complete case, parallel to the existing `GameOverScreen`.

**Tech Stack:** Dart 3.12, Flutter 3.44, `provider` package (already in use, no new dependencies).

**Spec:** [docs/superpowers/specs/2026-08-28-sistema-de-noches-design.md](../specs/2026-08-28-sistema-de-noches-design.md)

## Global Constraints

- No new pub dependencies — this feature only touches existing models/providers/widgets
- Protocol addition (`night_status`, `game_over.night`, `game_over.result: 'final_victory'`) is a PROPOSAL not yet implemented by the real backend — only `MockServerService` emits it; production code must not assume a real server sends it yet
- `dart analyze lib` must stay clean (the pre-existing `use_null_aware_elements` info-level lint on `game_provider.dart:63` is a known, accepted non-issue — do not "fix" it as part of this plan, and do not treat it as a new finding)
- No automated unit tests in this phase — manual verification only (consistent with rest of project)
- Commit messages in Spanish, no Claude co-author trailer (per project convention)
- `PROGRESS.md` is gitignored — update it locally per session convention but do not `git add` it

---

## Task 1: GameSession and GameProvider — night/clock state

**Files:**
- Modify: `flutter/lib/models/game_session.dart`
- Modify: `flutter/lib/providers/game_provider.dart`

**Interfaces:**
- Produces:
  - `GameSession.currentNight` (`int`, default `1`)
  - `GameSession.inGameTime` (`String`, default `'12:00 AM'`)
  - `GameProvider.isFinalVictory` (`bool`, default `false`)
  - `GameProvider.lastGameOverNight` (`int?`, default `null`) — the night the last `game_over` occurred in, read by `GameOverScreen`/`VictoryScreen`
  - `GameProvider.resetNight()` — resets health/tasks/currentTask but keeps `currentNight`
  - `handleMessage` gains a `case 'night_status':` and the `case 'game_over':` case is extended to read `night` and `result`

- [ ] **Step 1: Add night/clock fields to `GameSession`**

Edit `flutter/lib/models/game_session.dart` — current content is:

```dart
import 'task.dart';

class GameSession {
  final String playerId;
  int health;
  int score;
  int tasksCompleted;
  int tasksFailed;
  DateTime? startTime;
  DateTime? endTime;
  bool isConnected;
  Task? currentTask;

  GameSession({
    required this.playerId,
    this.health = 100,
    this.score = 0,
    this.tasksCompleted = 0,
    this.tasksFailed = 0,
    this.startTime,
    this.endTime,
    this.isConnected = false,
    this.currentTask,
  });
}
```

Replace with:

```dart
import 'task.dart';

class GameSession {
  final String playerId;
  int health;
  int score;
  int tasksCompleted;
  int tasksFailed;
  DateTime? startTime;
  DateTime? endTime;
  bool isConnected;
  Task? currentTask;
  int currentNight;
  String inGameTime;

  GameSession({
    required this.playerId,
    this.health = 100,
    this.score = 0,
    this.tasksCompleted = 0,
    this.tasksFailed = 0,
    this.startTime,
    this.endTime,
    this.isConnected = false,
    this.currentTask,
    this.currentNight = 1,
    this.inGameTime = '12:00 AM',
  });
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd flutter && dart analyze lib/models/game_session.dart`
Expected: `No issues found!`

- [ ] **Step 3: Add `night_status` handling and `game_over` night/result reading to `GameProvider`**

Edit `flutter/lib/providers/game_provider.dart`. Current content is:

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

  /// Set by the screen layer to the active provider's `sender` (see
  /// ConnectionProvider.sender) so this provider can report task results
  /// without depending on ConnectionProvider directly.
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
          isGameOver = true;
        }
        break;
      case 'game_over':
        isGameOver = true;
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
    notifyListeners();
  }
}
```

Replace with:

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
  bool isFinalVictory = false;
  int? lastGameOverNight;

  /// Set by the screen layer to the active provider's `sender` (see
  /// ConnectionProvider.sender) so this provider can report task results
  /// without depending on ConnectionProvider directly.
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
          lastGameOverNight = session.currentNight;
          isGameOver = true;
        }
        break;
      case 'night_status':
        session.currentNight = message['night'] as int;
        session.inGameTime = message['in_game_time'] as String;
        break;
      case 'game_over':
        lastGameOverNight = (message['night'] as int?) ?? session.currentNight;
        if (message['result'] == 'final_victory') {
          isFinalVictory = true;
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
    isFinalVictory = false;
    lastGameOverNight = null;
    notifyListeners();
  }

  /// Resets health/tasks/current task for a retry of the SAME night,
  /// keeping `currentNight` and `inGameTime` untouched. Used when the
  /// player fails (health reaches 0) mid-night.
  void resetNight() {
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

- [ ] **Step 4: Verify it compiles**

Run: `cd flutter && dart analyze lib/providers/game_provider.dart`
Expected: `No issues found!` (the pre-existing info-level lint at line 63 in the ORIGINAL file may shift line number after this edit — confirm it's still the only entry, still `info` severity, still about `use_null_aware_elements`; do not fix it)

- [ ] **Step 5: Commit**

```bash
git add flutter/lib/models/game_session.dart flutter/lib/providers/game_provider.dart
git commit -m "feat: agregar estado de noche/reloj a GameSession y GameProvider"
```

---

## Task 2: MockServerService — simulate night clock and final victory

**Files:**
- Modify: `flutter/lib/services/mock_server_service.dart`

**Interfaces:**
- Consumes: nothing new from other tasks (this file is currently self-contained; Task 1's `GameProvider` reads the messages this task emits, but this task only needs to know the exact JSON shape)
- Produces: emits `{'type': 'night_status', 'night': int, 'in_game_time': String, 'seconds_elapsed': int, 'seconds_total': int}` periodically, and eventually `{'type': 'game_over', 'result': 'final_victory', 'night': 5, 'final_stats': {...}}` — the exact field names `night_status`/`night`/`in_game_time` must match what Task 1's `GameProvider.handleMessage` reads

- [ ] **Step 1: Add night clock simulation to `MockServerService`**

Current content of `flutter/lib/services/mock_server_service.dart`:

```dart
import 'dart:async';
import '../utils/logger.dart';

/// Simulates backend behavior (new_task / attack events) so the tablet UI
/// can be developed and tested before the real Python backend exists.
class MockServerService {
  Timer? _taskTimer;
  Timer? _attackTimer;
  int _taskCounter = 0;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  static const List<String> _taskTypes = ['cables', 'dials', 'sequence', 'rhythm'];

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

  /// Called by GameProvider when the placeholder widget reports completion,
  /// so the mock can advance to the next task like a real server would.
  void sendTaskCompleted(Map<String, dynamic> data) {
    appLogger.i('Mock received task_completed: $data');
    _taskTimer?.cancel();
    _taskTimer = Timer(const Duration(seconds: 1), _emitNextTask);
  }

  void stop() {
    _taskTimer?.cancel();
    _attackTimer?.cancel();
    _taskCounter = 0;
  }

  void dispose() {
    stop();
    _messageController.close();
  }
}
```

Replace with:

```dart
import 'dart:async';
import '../utils/logger.dart';

/// Simulates backend behavior (new_task / attack / night_status events) so
/// the tablet UI can be developed and tested before the real Python backend
/// exists. `night_status` is a PROPOSED protocol addition (see
/// docs/superpowers/specs/2026-08-28-sistema-de-noches-design.md) — the real
/// backend does not send this yet.
class MockServerService {
  Timer? _taskTimer;
  Timer? _attackTimer;
  Timer? _nightClockTimer;
  int _taskCounter = 0;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  static const List<String> _taskTypes = ['cables', 'dials', 'sequence', 'rhythm'];

  // Duración de una noche en segundos reales. 360 = 6 minutos (spec real).
  // Se puede acortar temporalmente para pruebas manuales rápidas — ver
  // Task 4 de este plan, sección de verificación.
  static const int secondsPerNight = 360;
  static const int totalNights = 5;

  int _currentNight = 1;
  int _secondsElapsedThisNight = 0;

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
    _nightClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickNightClock();
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

  void _tickNightClock() {
    _secondsElapsedThisNight++;
    _messageController.add({
      'type': 'night_status',
      'night': _currentNight,
      'in_game_time': _formatInGameTime(_secondsElapsedThisNight),
      'seconds_elapsed': _secondsElapsedThisNight,
      'seconds_total': secondsPerNight,
    });

    if (_secondsElapsedThisNight >= secondsPerNight) {
      if (_currentNight >= totalNights) {
        _emitFinalVictory();
      } else {
        _currentNight++;
        _secondsElapsedThisNight = 0;
      }
    }
  }

  /// Convierte segundos transcurridos (0..secondsPerNight) a una hora
  /// simulada 12:00 AM -> 6:00 AM, formateada como "H:MM AM".
  String _formatInGameTime(int secondsElapsed) {
    final double fraction = secondsElapsed / secondsPerNight;
    final int totalMinutesSimulated = (fraction * 6 * 60).round();
    int hour = 12 + (totalMinutesSimulated ~/ 60);
    final int minute = totalMinutesSimulated % 60;
    if (hour > 12) hour -= 12;
    final String minuteStr = minute.toString().padLeft(2, '0');
    return '$hour:$minuteStr AM';
  }

  void _emitFinalVictory() {
    _nightClockTimer?.cancel();
    _attackTimer?.cancel();
    _taskTimer?.cancel();
    _messageController.add({
      'type': 'game_over',
      'result': 'final_victory',
      'night': totalNights,
      'final_stats': <String, dynamic>{},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Called by GameProvider when the placeholder widget reports completion,
  /// so the mock can advance to the next task like a real server would.
  void sendTaskCompleted(Map<String, dynamic> data) {
    appLogger.i('Mock received task_completed: $data');
    _taskTimer?.cancel();
    _taskTimer = Timer(const Duration(seconds: 1), _emitNextTask);
  }

  /// Reinicia el reloj de la noche actual (sin cambiar `_currentNight`),
  /// para cuando el jugador reintenta tras fallar. No reinicia el timer
  /// de ataques/tareas, que siguen corriendo independientemente.
  void resetNightClock() {
    _secondsElapsedThisNight = 0;
  }

  void stop() {
    _taskTimer?.cancel();
    _attackTimer?.cancel();
    _nightClockTimer?.cancel();
    _taskCounter = 0;
    _currentNight = 1;
    _secondsElapsedThisNight = 0;
  }

  void dispose() {
    stop();
    _messageController.close();
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd flutter && dart analyze lib/services/mock_server_service.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add flutter/lib/services/mock_server_service.dart
git commit -m "feat: simular reloj de noche y victoria final en MockServerService"
```

---

## Task 3: ConnectionProvider — expose night reset alongside sender

**Files:**
- Modify: `flutter/lib/providers/connection_provider.dart`

**Interfaces:**
- Consumes: `MockServerService.resetNightClock()` (Task 2)
- Produces: `ConnectionProvider.resetNight()` — calls through to the mock's `resetNightClock()` when `ServerConfig.useMock` is true; no-op otherwise (the real backend will own night-reset logic itself once implemented)

- [ ] **Step 1: Read the current file**

Read `flutter/lib/providers/connection_provider.dart` in full before editing — it was not reproduced in this plan's context gathering beyond the `sender`/`messages` getters shown below, so confirm the rest of the file (imports, `ConnectionState` enum, `connect()`/`disconnect()`/`_handleDisconnect()` methods) matches what's expected before making this small addition. If anything differs from this excerpt, keep the rest of the file as-is and only add the method described in Step 2.

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

- [ ] **Step 2: Add `resetNight()` method**

Add this method to the `ConnectionProvider` class, right after the `sender` getter shown above (before `void connect()`):

```dart
  /// Reinicia el reloj de la noche actual (mismo `night`, tiempo en 0) sin
  /// desconectar. Usado cuando el jugador falla y reintenta la misma noche.
  /// No-op contra el backend real hasta que implemente su propia lógica de
  /// reinicio de noche (ver spec de protocolo propuesto).
  void resetNight() {
    if (ServerConfig.useMock) {
      _mockService.resetNightClock();
    }
  }
```

- [ ] **Step 3: Verify it compiles**

Run: `cd flutter && dart analyze lib/providers/connection_provider.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add flutter/lib/providers/connection_provider.dart
git commit -m "feat: agregar resetNight a ConnectionProvider"
```

---

## Task 4: NightClockBar widget

**Files:**
- Create: `flutter/lib/widgets/night_clock_bar.dart`

**Interfaces:**
- Consumes: nothing from other tasks directly (pure presentational widget, takes primitives as constructor params)
- Produces: `class NightClockBar extends StatelessWidget { const NightClockBar({required int currentNight, required String inGameTime}); }` — consumed by Task 5's `GameScreen`

- [ ] **Step 1: Create the widget**

```dart
import 'package:flutter/material.dart';

/// Muestra la noche actual (1-5) y la hora simulada del reloj (12:00 AM ->
/// 6:00 AM). Puramente presentacional — GameScreen le pasa los valores
/// leídos de GameProvider.session.
class NightClockBar extends StatelessWidget {
  final int currentNight;
  final String inGameTime;

  const NightClockBar({
    super.key,
    required this.currentNight,
    required this.inGameTime,
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
            Text('Noche $currentNight/5'),
          ],
        ),
        Row(
          children: [
            const Icon(Icons.access_time, size: 18),
            const SizedBox(width: 6),
            Text(inGameTime),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd flutter && dart analyze lib/widgets/night_clock_bar.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add flutter/lib/widgets/night_clock_bar.dart
git commit -m "feat: agregar widget NightClockBar"
```

---

## Task 5: Wire NightClockBar into GameScreen

**Files:**
- Modify: `flutter/lib/screens/game_screen.dart`

**Interfaces:**
- Consumes: `NightClockBar` (Task 4), `GameProvider.session.currentNight`/`inGameTime` (Task 1)
- Produces: no new public interface — this task only changes `GameScreen`'s internal layout

- [ ] **Step 1: Add the import and render `NightClockBar` below the existing `HealthBar`**

Current relevant excerpt of `flutter/lib/screens/game_screen.dart` (imports at top, and the `body:` section):

```dart
import '../widgets/health_bar.dart';
import '../widgets/status_bar.dart';
import '../widgets/placeholder_game_widget.dart';
import '../widgets/cable_game_widget.dart';
import '../widgets/sequence_game_widget.dart';
import '../widgets/dial_game_widget.dart';
import '../widgets/rhythm_game_widget.dart';
import 'game_over_screen.dart';
```

and:

```dart
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
```

Add the import:

```dart
import '../widgets/health_bar.dart';
import '../widgets/status_bar.dart';
import '../widgets/night_clock_bar.dart';
import '../widgets/placeholder_game_widget.dart';
import '../widgets/cable_game_widget.dart';
import '../widgets/sequence_game_widget.dart';
import '../widgets/dial_game_widget.dart';
import '../widgets/rhythm_game_widget.dart';
import 'game_over_screen.dart';
```

Change the `body:` section to insert `NightClockBar` between `HealthBar` and the task area:

```dart
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            HealthBar(health: game.session.health),
            const SizedBox(height: 8),
            NightClockBar(
              currentNight: game.session.currentNight,
              inGameTime: game.session.inGameTime,
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

- [ ] **Step 2: Verify it compiles**

Run: `cd flutter && dart analyze lib/screens/game_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add flutter/lib/screens/game_screen.dart
git commit -m "feat: mostrar NightClockBar en GameScreen"
```

---

## Task 6: Per-night retry in GameOverScreen, and navigation target

**Files:**
- Modify: `flutter/lib/screens/game_over_screen.dart`

**Interfaces:**
- Consumes: `GameProvider.resetNight()` (Task 1), `GameProvider.lastGameOverNight` (Task 1), `ConnectionProvider.resetNight()` (Task 3), `GameScreen` (existing, imported for navigation target)
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

Replace with (per spec: fallo por vida ahora reintenta la MISMA noche, sin desconectar — se mantiene la sesión de conexión y `currentNight`):

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
    final int? night = game.lastGameOverNight;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('JUEGO TERMINADO',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (night != null) Text('Fallaste en la Noche $night'),
            const SizedBox(height: 16),
            Text('Tareas completadas: ${session.tasksCompleted}'),
            Text('Tareas fallidas: ${session.tasksFailed}'),
            Text('Puntuación: ${session.score}'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.read<GameProvider>().resetNight();
                context.read<ConnectionProvider>().resetNight();
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

Note: the `splash_screen.dart` import is removed (no longer navigates there) and replaced with `game_screen.dart`. The `ConnectionProvider` import stays (still used for `resetNight()`).

- [ ] **Step 2: Verify it compiles**

Run: `cd flutter && dart analyze lib/screens/game_over_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add flutter/lib/screens/game_over_screen.dart
git commit -m "feat: reintentar la misma noche en vez de reiniciar todo el juego"
```

---

## Task 7: VictoryScreen and wiring from GameScreen

**Files:**
- Create: `flutter/lib/screens/victory_screen.dart`
- Modify: `flutter/lib/screens/game_screen.dart`

**Interfaces:**
- Consumes: `GameProvider.isFinalVictory`, `GameProvider.reset()` (Task 1), `SplashScreen` (existing)
- Produces: `class VictoryScreen extends StatelessWidget` — a screen, not consumed by any later task in this plan

- [ ] **Step 1: Create `VictoryScreen`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/connection_provider.dart';
import 'splash_screen.dart';

/// Se muestra cuando el jugador completa la Noche 5 (GameProvider.isFinalVictory).
class VictoryScreen extends StatelessWidget {
  const VictoryScreen({super.key});

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

Run: `cd flutter && dart analyze lib/screens/victory_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Wire `isFinalVictory` navigation into `GameScreen`**

Current relevant excerpt of `flutter/lib/screens/game_screen.dart` (the `build` method's game-over check, and the imports):

```dart
import 'game_over_screen.dart';
```

and:

```dart
    if (game.isGameOver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const GameOverScreen()),
        );
      });
    }
```

Change the import block to also import `victory_screen.dart`:

```dart
import 'game_over_screen.dart';
import 'victory_screen.dart';
```

Change the game-over check to also handle `isFinalVictory`:

```dart
    if (game.isFinalVictory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const VictoryScreen()),
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

(`isFinalVictory` is checked first since both flags could theoretically be inspected in the same frame — final victory takes priority as the more specific/terminal state.)

- [ ] **Step 4: Verify it compiles**

Run: `cd flutter && dart analyze lib`
Expected: `No issues found!` (only the known pre-existing info-level lint on `game_provider.dart`, still present, still not touched)

- [ ] **Step 5: Commit**

```bash
git add flutter/lib/screens/victory_screen.dart flutter/lib/screens/game_screen.dart
git commit -m "feat: agregar VictoryScreen al completar la Noche 5"
```

---

## Task 8: End-to-End Manual Verification

**Files:** none (verification only)

**Interfaces:**
- Consumes: the complete feature from Tasks 1–7

- [ ] **Step 1: Temporarily shorten night duration for fast manual testing**

In `flutter/lib/services/mock_server_service.dart`, temporarily change:

```dart
  static const int secondsPerNight = 360;
```

to:

```dart
  static const int secondsPerNight = 15;
```

This lets a full night pass in 15 seconds instead of 6 minutes, so the full 5-night cycle can be observed in under 2 minutes instead of 30.

- [ ] **Step 2: Run the app**

Run: `cd flutter && flutter run -d linux` (or another available device per `flutter devices`)
Expected: app builds and launches without errors.

- [ ] **Step 3: Verify NightClockBar renders and advances**

Observe: on reaching `GameScreen`, `NightClockBar` shows "Noche 1/5" and a time starting near "12:00 AM", advancing roughly every second toward "6:00 AM" over ~15 seconds (with the shortened duration from Step 1).

- [ ] **Step 4: Verify night advances past night 1**

Observe: once the clock reaches "6:00 AM", the display should reset to "12:00 AM" and the night counter should read "Noche 2/5" (driven by the next `night_status` message from the mock, which increments `night` and resets `seconds_elapsed` once `secondsPerNight` is reached).

- [ ] **Step 5: Verify per-night retry (not full reset)**

Wait for an attack to reduce health to 0 (attacks fire every 25s per the existing mock timer, independent of the shortened night duration) — or, to force it faster for this check only, temporarily also change `Duration(seconds: 25)` to `Duration(seconds: 3)` in `_emitAttack`'s timer inside `start()`, same pattern as used in the original skeleton verification. Observe: `GameOverScreen` shows "Fallaste en la Noche N" matching whatever night was active. Tap "Reintentar". Observe: app returns to `GameScreen` (not `SplashScreen` — no reconnect delay), health bar is back to 100%, and `NightClockBar` still shows the SAME night number as before the failure (not reset to "Noche 1/5"), clock reset to "12:00 AM".

- [ ] **Step 6: Verify final victory screen**

Let the mock run through all 5 nights uninterrupted (a full run takes ~75 seconds with the 15s-per-night shortcut from Step 1; avoid triggering the attack-timer shortcut from Step 5 during this pass, or revert it first, so health doesn't reach 0 mid-run). Observe: after night 5's clock reaches "6:00 AM", the app navigates to `VictoryScreen` showing "¡SOBREVIVISTE LAS 5 NOCHES!" with final stats. Tap "Jugar de nuevo". Observe: app returns to `SplashScreen`, reconnects, and `NightClockBar` on the next `GameScreen` shows "Noche 1/5" again (full `reset()` this time, since this is a fresh full run, not a per-night retry).

- [ ] **Step 7: Revert the temporary timing shortcuts**

Revert `secondsPerNight` back to `360` in `mock_server_service.dart` (Step 1's change), and revert the attack timer back to `Duration(seconds: 25)` if it was changed in Step 5. Confirm with `git diff flutter/lib/services/mock_server_service.dart` that only the intended Task 1-7 changes remain (no leftover shortened timings).

- [ ] **Step 8: Final compile check**

Run: `cd flutter && dart analyze lib`
Expected: `No issues found!` except the known pre-existing info-level lint on `game_provider.dart` (`use_null_aware_elements`) — confirm no other findings crept in.

- [ ] **Step 9: Update PROGRESS.md**

`PROGRESS.md` is gitignored (per project convention) — update it locally with a dated log entry summarizing: sistema de noches implementado (5 noches, reloj 12am-6am simulado en 6 min reales), reintento por noche en vez de reset completo, VictoryScreen nueva, protocolo `night_status` simulado en mock (pendiente de validar con el equipo backend/Unity antes de implementarse en el servidor real). Do not `git add` it.

---

## Self-Review Notes

- **Spec coverage:** Task 1 covers the `GameSession`/`GameProvider` data model (spec's "Modelo de datos" section) including `resetNight()` vs `reset()` distinction. Task 2 covers the `MockServerService` simulation (spec's "MockServerService (simulación)" section) including the night-duration constant, clock formatting, and final-victory emission. Task 3 covers exposing a night-reset hook through `ConnectionProvider` (needed because `GameOverScreen`'s retry button must reach the mock's `resetNightClock()`, and `ConnectionProvider` is the layer screens already use to reach the mock/websocket). Task 4 covers the `NightClockBar` widget (spec's "UI" section). Task 5 wires it into `GameScreen`. Task 6 covers the `GameOverScreen` retry-same-night behavior and "Fallaste en la Noche N" display (spec's "GameOverScreen (modificación)" section). Task 7 covers `VictoryScreen` (spec's "Nueva pantalla: VictoryScreen" section) and the `isFinalVictory` navigation branch in `GameScreen`. Task 8 covers the spec's "Testing" section, including the temporary-shortened-duration technique explicitly called out in the spec.
- **Placeholder scan:** no TBD/TODO; all steps carry complete code or, where a file's full current content wasn't reproduced in this plan (Task 3's `ConnectionProvider`), an explicit instruction to read the file first before making the described small addition — this is not a placeholder, it's a necessary caution since the plan's own context gathering only captured an excerpt of that file.
- **Type consistency:** `GameSession.currentNight`/`inGameTime` (Task 1) match the field names read by `NightClockBar`'s constructor params in Task 4/5 (`currentNight`, `inGameTime`). `GameProvider.lastGameOverNight`/`isFinalVictory` (Task 1) match usage in `GameOverScreen` (Task 6) and `GameScreen`'s victory check (Task 7). `MockServerService`'s emitted `night_status` field names (`night`, `in_game_time`, `seconds_elapsed`, `seconds_total`) match exactly what `GameProvider.handleMessage`'s `case 'night_status':` reads in Task 1. `ConnectionProvider.resetNight()` (Task 3) matches the call site in `GameOverScreen` (Task 6). `MockServerService.resetNightClock()` (Task 2) matches the call inside `ConnectionProvider.resetNight()` (Task 3).
