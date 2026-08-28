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
