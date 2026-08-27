# Flutter Tablet Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Initialize and structure the Flutter tablet project (`flutter/`) with WebSocket connectivity, state providers, base screens, and a mock backend — no real minigames yet.

**Architecture:** Standard Flutter app with `provider` for state management. Two providers (`ConnectionProvider`, `GameProvider`) mediate between a `WebSocketService` (or `MockServerService` swapped in via config) and the UI screens. Screens flow Splash → Game → GameOver. A generic `PlaceholderGameWidget` stands in for the real minigames.

**Tech Stack:** Flutter 3.44.5 (stable, exceeds 3.13+ floor), Dart 3.12.2, `provider`, `web_socket_channel`, `flutter_local_notifications`, `vibration`, `flutter_svg`, `lottie`, `logger`, `shared_preferences`.

**Spec:** [docs/superpowers/specs/2026-08-27-flutter-tablet-skeleton-design.md](../specs/2026-08-27-flutter-tablet-skeleton-design.md)

## Global Constraints

- Dart 3.0+, Flutter 3.13+ (installed: Flutter 3.44.5 — satisfies floor)
- State management: `provider` package only — no Riverpod, no Bloc
- Communication: WebSocket (`web_socket_channel`), not HTTP polling
- JSON message shapes must match exactly what's defined in `docs/FLUTTER_TABLET_ESPECIFICACION.md` section "Protocolo de Comunicación" (message `type` values: `connect`, `task_completed`, `task_failed`, `attack_acknowledged`, `disconnect`, `new_task`, `attack`, `pause`, `game_over`, `reconnect_success`)
- Reconnection: retry every 3s, max 5 attempts, then surface error state
- No real minigame logic in this plan — `PlaceholderGameWidget` only
- No `sqflite` dependency (out of scope for skeleton)
- No automated unit tests in this phase — manual flow verification only (per spec's Testing section)

---

## Task 1: Create Flutter Project and Add Dependencies

**Files:**
- Create: `flutter/` (entire Flutter project scaffold via `flutter create`)
- Modify: `flutter/pubspec.yaml`
- Create: `flutter/assets/images/.gitkeep`, `flutter/assets/sounds/.gitkeep`, `flutter/assets/animations/.gitkeep`

**Interfaces:**
- Produces: a runnable Flutter project at `flutter/` with all dependencies resolved, ready for `lib/` code in later tasks.

- [ ] **Step 1: Generate the Flutter project**

Run from repo root:
```bash
rm -rf flutter && flutter create --org com.ucsp.fnaf --project-name fn_attention_defense_tablet flutter
```

(The existing `flutter/` directory is empty, so this is safe — `flutter create` needs an empty or non-existent target.)

- [ ] **Step 2: Verify the default app runs**

Run: `cd flutter && flutter pub get`
Expected: `Got dependencies!` with no errors.

- [ ] **Step 3: Add dependencies to pubspec.yaml**

Edit `flutter/pubspec.yaml`, add under `dependencies:` (keep the existing `flutter:` and `cupertino_icons:` lines):

```yaml
  web_socket_channel: ^2.4.0
  provider: ^6.1.2
  flutter_local_notifications: ^17.2.3
  vibration: ^2.0.1
  flutter_svg: ^2.0.10+1
  lottie: ^3.1.2
  logger: ^2.4.0
  shared_preferences: ^2.3.2
```

Add near the bottom, inside the `flutter:` section (after `uses-material-design: true`):

```yaml
  assets:
    - assets/images/
    - assets/sounds/
    - assets/animations/
```

- [ ] **Step 4: Create asset directories with placeholders**

```bash
mkdir -p flutter/assets/images flutter/assets/sounds flutter/assets/animations
touch flutter/assets/images/.gitkeep flutter/assets/sounds/.gitkeep flutter/assets/animations/.gitkeep
```

- [ ] **Step 5: Install dependencies and verify**

Run: `cd flutter && flutter pub get`
Expected: `Got dependencies!` with no version conflicts. If a version conflict appears, run `flutter pub get` again after checking `flutter pub outdated` and relax the pinned version to whatever resolves (keep caret `^` constraints).

- [ ] **Step 6: Commit**

```bash
git add flutter/
git commit -m "chore: scaffold Flutter project and add dependencies"
```

---

## Task 2: Data Models (Task, Attack, GameSession)

**Files:**
- Create: `flutter/lib/models/task.dart`
- Create: `flutter/lib/models/attack.dart`
- Create: `flutter/lib/models/game_session.dart`

**Interfaces:**
- Produces:
  - `class Task { int taskId; String taskType; int duration; String description; int difficulty; DateTime createdAt; Map<String, dynamic> params; factory Task.fromJson(Map<String, dynamic> json); }`
  - `class Attack { String attackId; int damage; String urgency; String animatronic; String message; DateTime timestamp; factory Attack.fromJson(Map<String, dynamic> json); }`
  - `class GameSession { String playerId; int health; int score; int tasksCompleted; int tasksFailed; DateTime? startTime; DateTime? endTime; bool isConnected; Task? currentTask; GameSession({required String playerId}); }`

- [ ] **Step 1: Create `task.dart`**

```dart
class Task {
  final int taskId;
  final String taskType;
  final int duration;
  final String description;
  final int difficulty;
  final DateTime createdAt;
  final Map<String, dynamic> params;

  Task({
    required this.taskId,
    required this.taskType,
    required this.duration,
    required this.description,
    required this.difficulty,
    required this.createdAt,
    required this.params,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      taskId: json['task_id'] as int,
      taskType: json['task_type'] as String,
      duration: json['duration'] as int,
      description: json['description'] as String,
      difficulty: json['difficulty'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      params: (json['task_params'] as Map<String, dynamic>?) ?? {},
    );
  }
}
```

- [ ] **Step 2: Create `attack.dart`**

```dart
class Attack {
  final String attackId;
  final int damage;
  final String urgency;
  final String animatronic;
  final String message;
  final DateTime timestamp;

  Attack({
    required this.attackId,
    required this.damage,
    required this.urgency,
    required this.animatronic,
    required this.message,
    required this.timestamp,
  });

  factory Attack.fromJson(Map<String, dynamic> json) {
    return Attack(
      attackId: json['attack_id'] as String,
      damage: json['damage'] as int,
      urgency: json['urgency'] as String,
      animatronic: json['animatronic'] as String,
      message: json['message'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }
}
```

- [ ] **Step 3: Create `game_session.dart`**

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

- [ ] **Step 4: Verify it compiles**

Run: `cd flutter && dart analyze lib/models`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add flutter/lib/models
git commit -m "feat: add Task, Attack, GameSession models"
```

---

## Task 3: Config and Utils

**Files:**
- Create: `flutter/lib/config/server_config.dart`
- Create: `flutter/lib/utils/constants.dart`
- Create: `flutter/lib/utils/colors.dart`
- Create: `flutter/lib/utils/logger.dart`

**Interfaces:**
- Produces:
  - `class ServerConfig { static const bool useMock; static const String host; static const int port; static String get wsUrl; }`
  - `class AppConstants { static const int reconnectMaxAttempts; static const Duration reconnectDelay; static const Duration connectTimeout; }`
  - `class AppColors { static const Color primary; static const Color danger; static const Color background; }`
  - top-level `final Logger appLogger;` (from `package:logger`)

- [ ] **Step 1: Create `server_config.dart`**

```dart
class ServerConfig {
  // Backend Python no existe todavía — usar mock hasta que el equipo lo entregue.
  static const bool useMock = true;

  static const String host = '192.168.1.100';
  static const int port = 8000;

  static String get wsUrl => 'ws://$host:$port';
}
```

- [ ] **Step 2: Create `constants.dart`**

```dart
class AppConstants {
  static const int reconnectMaxAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 3);
  static const Duration connectTimeout = Duration(seconds: 10);
}
```

- [ ] **Step 3: Create `colors.dart`**

```dart
import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Colors.red;
  static const Color danger = Color(0xFFD32F2F);
  static const Color background = Color(0xFF121212);
}
```

- [ ] **Step 4: Create `logger.dart`**

```dart
import 'package:logger/logger.dart';

final Logger appLogger = Logger(
  printer: PrettyPrinter(methodCount: 0, colors: false),
);
```

- [ ] **Step 5: Verify it compiles**

Run: `cd flutter && dart analyze lib/config lib/utils`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add flutter/lib/config flutter/lib/utils
git commit -m "feat: add server config, constants, colors, logger utilities"
```

---

## Task 4: WebSocketService and MockServerService

**Files:**
- Create: `flutter/lib/services/websocket_service.dart`
- Create: `flutter/lib/services/mock_server_service.dart`

**Interfaces:**
- Consumes: `ServerConfig.wsUrl` (Task 3), `appLogger` (Task 3)
- Produces:
  - `class WebSocketService { void connect(String url); void sendMessage(Map<String, dynamic> data); void disconnect(); Stream<Map<String, dynamic>> get messages; }`
  - `class MockServerService { void start(); void stop(); void sendTaskCompleted(Map<String, dynamic> data); Stream<Map<String, dynamic>> get messages; }`
  - Both expose `Stream<Map<String, dynamic>> get messages` so `GameProvider`/`ConnectionProvider` (Task 5) can consume either interchangeably.

- [ ] **Step 1: Create `websocket_service.dart`**

```dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../utils/logger.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  void connect(String url) {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _channel!.stream.listen(
        (dynamic raw) {
          final Map<String, dynamic> decoded =
              jsonDecode(raw as String) as Map<String, dynamic>;
          _messageController.add(decoded);
        },
        onError: (Object error) {
          appLogger.e('WebSocket error: $error');
          _messageController.addError(error);
        },
        onDone: () {
          appLogger.w('WebSocket connection closed');
        },
      );
    } catch (e) {
      appLogger.e('Error connecting: $e');
      _messageController.addError(e);
    }
  }

  void sendMessage(Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode(data));
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
```

- [ ] **Step 2: Create `mock_server_service.dart`**

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
    _emitNextTask();
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
  }

  void dispose() {
    stop();
    _messageController.close();
  }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `cd flutter && dart analyze lib/services`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add flutter/lib/services
git commit -m "feat: add WebSocketService and MockServerService"
```

---

## Task 5: ConnectionProvider and GameProvider

**Files:**
- Create: `flutter/lib/providers/connection_provider.dart`
- Create: `flutter/lib/providers/game_provider.dart`

**Interfaces:**
- Consumes: `WebSocketService`, `MockServerService` (Task 4), `ServerConfig` (Task 3), `AppConstants` (Task 3), `Task`/`Attack`/`GameSession` models (Task 2)
- Produces:
  - `enum ConnectionState { idle, connecting, connected, reconnecting, error }`
  - `class ConnectionProvider extends ChangeNotifier { ConnectionState get state; int get reconnectAttempts; void connect(); void disconnect(); Stream<Map<String, dynamic>> get messages; }`
  - `class GameProvider extends ChangeNotifier { GameSession get session; Attack? get lastAttack; void handleMessage(Map<String, dynamic> message); void reportTaskCompleted({required bool success, required double timeTaken}); void Function(Map<String, dynamic>)? sendToServer; }`

- [ ] **Step 1: Create `connection_provider.dart`**

```dart
import 'package:flutter/foundation.dart';
import '../config/server_config.dart';
import '../services/websocket_service.dart';
import '../services/mock_server_service.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

enum ConnectionState { idle, connecting, connected, reconnecting, error }

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

  void connect() {
    _state = ConnectionState.connecting;
    notifyListeners();

    if (ServerConfig.useMock) {
      appLogger.i('Connecting via MockServerService');
      _mockService.start();
      _state = ConnectionState.connected;
      _reconnectAttempts = 0;
      notifyListeners();
      return;
    }

    _wsService.connect(ServerConfig.wsUrl);
    _wsService.sendMessage({
      'type': 'connect',
      'device': 'tablet',
      'player_id': 'player_1',
      'app_version': '0.1.0',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    _state = ConnectionState.connected;
    _reconnectAttempts = 0;
    notifyListeners();

    _wsService.messages.listen(
      (_) {},
      onError: (Object error) => _handleDisconnect(),
      onDone: _handleDisconnect,
    );
  }

  void _handleDisconnect() {
    if (_reconnectAttempts >= AppConstants.reconnectMaxAttempts) {
      _state = ConnectionState.error;
      notifyListeners();
      return;
    }
    _state = ConnectionState.reconnecting;
    _reconnectAttempts++;
    notifyListeners();

    Future<void>.delayed(AppConstants.reconnectDelay, connect);
  }

  void disconnect() {
    _wsService.disconnect();
    _mockService.stop();
    _state = ConnectionState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _wsService.dispose();
    _mockService.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 2: Create `game_provider.dart`**

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

  void reportTaskCompleted({required bool success, required double timeTaken}) {
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
    });

    session.currentTask = null;
    notifyListeners();
  }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `cd flutter && dart analyze lib/providers`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add flutter/lib/providers
git commit -m "feat: add ConnectionProvider and GameProvider"
```

---

## Task 6: Shared Widgets (HealthBar, StatusBar, PlaceholderGameWidget)

**Files:**
- Create: `flutter/lib/widgets/health_bar.dart`
- Create: `flutter/lib/widgets/status_bar.dart`
- Create: `flutter/lib/widgets/placeholder_game_widget.dart`

**Interfaces:**
- Consumes: `ConnectionState` (Task 5), `GameSession`/`Task` models (Task 2), `AppColors` (Task 3)
- Produces:
  - `class HealthBar extends StatelessWidget { const HealthBar({required int health}); }`
  - `class StatusBar extends StatelessWidget { const StatusBar({required ConnectionState connectionState, required int reconnectAttempts}); }`
  - `class PlaceholderGameWidget extends StatelessWidget { const PlaceholderGameWidget({required Task task, required void Function(bool success) onComplete}); }`

- [ ] **Step 1: Create `health_bar.dart`**

```dart
import 'package:flutter/material.dart';
import '../utils/colors.dart';

class HealthBar extends StatelessWidget {
  final int health;

  const HealthBar({super.key, required this.health});

  @override
  Widget build(BuildContext context) {
    final double fraction = (health.clamp(0, 100)) / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vida: $health%'),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 12,
            backgroundColor: Colors.grey.shade800,
            color: fraction > 0.3 ? AppColors.primary : AppColors.danger,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Create `status_bar.dart`**

```dart
import 'package:flutter/material.dart';
import '../providers/connection_provider.dart';

class StatusBar extends StatelessWidget {
  final ConnectionState connectionState;
  final int reconnectAttempts;

  const StatusBar({
    super.key,
    required this.connectionState,
    required this.reconnectAttempts,
  });

  String _label() {
    switch (connectionState) {
      case ConnectionState.idle:
        return 'Desconectado';
      case ConnectionState.connecting:
        return 'Conectando...';
      case ConnectionState.connected:
        return 'Conectado';
      case ConnectionState.reconnecting:
        return 'Reconectando ($reconnectAttempts/5)...';
      case ConnectionState.error:
        return 'Error de conexión';
    }
  }

  Color _dotColor() {
    switch (connectionState) {
      case ConnectionState.connected:
        return Colors.green;
      case ConnectionState.error:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.circle, size: 10, color: _dotColor()),
        const SizedBox(width: 6),
        Text(_label()),
      ],
    );
  }
}
```

- [ ] **Step 3: Create `placeholder_game_widget.dart`**

```dart
import 'package:flutter/material.dart';
import '../models/task.dart';

/// Stand-in for the real minigames (cables, dials, sequence, rhythm),
/// which are implemented in a later plan. Lets the full connect → task →
/// complete → next-task flow be exercised end-to-end today.
class PlaceholderGameWidget extends StatelessWidget {
  final Task task;
  final void Function(bool success) onComplete;

  const PlaceholderGameWidget({
    super.key,
    required this.task,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Minijuego: ${task.taskType}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(task.description),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => onComplete(true),
            child: const Text('Completar (simulado)'),
          ),
          TextButton(
            onPressed: () => onComplete(false),
            child: const Text('Fallar (simulado)'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Verify it compiles**

Run: `cd flutter && dart analyze lib/widgets`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add flutter/lib/widgets
git commit -m "feat: add HealthBar, StatusBar, PlaceholderGameWidget"
```

---

## Task 7: Screens (Splash, Game, GameOver) and main.dart

**Files:**
- Create: `flutter/lib/screens/splash_screen.dart`
- Create: `flutter/lib/screens/game_screen.dart`
- Create: `flutter/lib/screens/game_over_screen.dart`
- Modify: `flutter/lib/main.dart`

**Interfaces:**
- Consumes: `ConnectionProvider`, `GameProvider` (Task 5), `HealthBar`, `StatusBar`, `PlaceholderGameWidget` (Task 6)
- Produces: runnable app entry point wiring `MultiProvider` → `SplashScreen` → `GameScreen` → `GameOverScreen`

- [ ] **Step 1: Create `splash_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import 'game_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConnectionProvider>().connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, connectionProvider, _) {
        if (connectionProvider.state == ConnectionState.connected) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const GameScreen()),
            );
          });
        }
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Five Nights at Freddy's",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_statusText(connectionProvider.state)),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusText(ConnectionState state) {
    switch (state) {
      case ConnectionState.connecting:
        return 'Conectando con servidor...';
      case ConnectionState.reconnecting:
        return 'Reconectando...';
      case ConnectionState.error:
        return 'No se pudo conectar';
      default:
        return 'Iniciando...';
    }
  }
}
```

- [ ] **Step 2: Create `game_over_screen.dart`**

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

- [ ] **Step 3: Create `game_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/game_provider.dart';
import '../widgets/health_bar.dart';
import '../widgets/status_bar.dart';
import '../widgets/placeholder_game_widget.dart';
import 'game_over_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _wired = false;

  @override
  Widget build(BuildContext context) {
    final ConnectionProvider connection = context.watch<ConnectionProvider>();
    final GameProvider game = context.watch<GameProvider>();

    if (!_wired) {
      _wired = true;
      game.sendToServer = connection.sender;
      connection.messages.listen(game.handleMessage);
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
                  : PlaceholderGameWidget(
                      task: game.session.currentTask!,
                      onComplete: (success) {
                        game.reportTaskCompleted(
                          success: success,
                          timeTaken: 10.0,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Rewrite `main.dart`**

Replace the contents of `flutter/lib/main.dart` (generated by `flutter create`) entirely:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/connection_provider.dart';
import 'providers/game_provider.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
      ],
      child: MaterialApp(
        title: "Five Nights at Freddy's - Tablet",
        theme: ThemeData(
          primarySwatch: Colors.red,
          brightness: Brightness.dark,
        ),
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
```

- [ ] **Step 5: Verify it compiles**

Run: `cd flutter && dart analyze lib`
Expected: `No issues found!`

- [ ] **Step 6: Delete the default counter test**

The `flutter create` scaffold generates `flutter/test/widget_test.dart`, which asserts on the default counter app and will fail against our app. Delete it:

```bash
rm flutter/test/widget_test.dart
```

(Per Global Constraints, this plan adds no automated tests — that file's absence is expected, not a gap.)

- [ ] **Step 7: Commit**

```bash
git add flutter/lib flutter/test
git commit -m "feat: add Splash/Game/GameOver screens and wire up main.dart"
```

---

## Task 8: End-to-End Manual Verification

**Files:** none (verification only)

**Interfaces:**
- Consumes: the complete app from Tasks 1–7

- [ ] **Step 1: Confirm a device/emulator is available**

Run: `flutter devices`
Expected: at least one device or emulator listed. If none, start one (e.g. an Android emulator via `flutter emulators --launch <id>`, or run on Linux desktop with `flutter config --enable-linux-desktop` then `flutter devices` again).

- [ ] **Step 2: Run the app**

Run: `cd flutter && flutter run`
Expected: app builds and launches without errors.

- [ ] **Step 3: Verify Splash → Game transition**

Observe: Splash screen shows "Conectando con servidor..." briefly, then transitions to Game screen automatically (mock connects instantly since `ServerConfig.useMock = true`).

- [ ] **Step 4: Verify task flow**

Observe: Game screen shows a task (e.g. "Minijuego: cables") within ~1 second of arriving at the Game screen. Tap "Completar (simulado)". Observe: within ~1 second, a new task appears with a different `task_type`, cycling through cables → dials → sequence → rhythm.

- [ ] **Step 5: Verify attack flow**

Wait ~25 seconds without navigating away. Observe: Health bar decreases by 20 and the percentage text updates. (To avoid a long wait during review, this step may instead be verified by temporarily changing `Duration(seconds: 25)` to `Duration(seconds: 3)` in `mock_server_service.dart`, observing the drop, then reverting the change before commit.)

- [ ] **Step 6: Verify game over flow**

Continue waiting through repeated attacks (or with the shortened interval from Step 5) until health reaches 0. Observe: app navigates to Game Over screen showing tasks completed/failed and score. Tap "Reintentar". Observe: app returns to Splash screen and reconnects.

- [ ] **Step 7: Record verification in PROGRESS.md**

Update `PROGRESS.md` at repo root: check off the Semana 1 items completed by this plan (Flutter install, project creation, folder structure, dependencies, initial commit, models, splash screen, ConnectionProvider, WebSocketService, GameProvider — mark minigame items as still pending), and add a dated log entry summarizing the skeleton is functional end-to-end against the mock.

- [ ] **Step 8: Commit**

```bash
git add PROGRESS.md
git commit -m "docs: mark skeleton milestones complete in PROGRESS.md"
```

---

## Self-Review Notes

- **Spec coverage:** Task 1 covers project creation + dependencies + assets; Task 2 covers models; Task 3 covers config/mock toggle; Task 4 covers WebSocket + mock services; Task 5 covers both providers; Task 6 covers HealthBar/StatusBar/PlaceholderGameWidget; Task 7 covers all three screens + main.dart wiring; Task 8 covers the manual testing flow from the spec's Testing section. All spec sections are represented.
- **Placeholder scan:** no TBD/TODO; all steps carry complete code.
- **Type consistency:** `Task`, `Attack`, `GameSession` (Task 2) field names match usage in `GameProvider` (Task 5) and `PlaceholderGameWidget`/screens (Tasks 6–7). `ConnectionState` enum (Task 5) matches usage in `StatusBar` and `SplashScreen`. `ConnectionProvider.sender` / `messages` (Task 5) match how `GameScreen` wires `game.sendToServer` and the message listener (Task 7).
