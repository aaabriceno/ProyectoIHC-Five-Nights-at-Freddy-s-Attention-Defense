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
