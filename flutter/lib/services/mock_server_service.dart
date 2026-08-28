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
