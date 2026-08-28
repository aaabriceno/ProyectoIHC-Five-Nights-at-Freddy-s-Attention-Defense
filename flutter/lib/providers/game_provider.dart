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
