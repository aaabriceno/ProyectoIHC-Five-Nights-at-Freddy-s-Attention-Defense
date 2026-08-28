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
