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
