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
    _taskCounter = 0;
  }

  void dispose() {
    stop();
    _messageController.close();
  }
}
