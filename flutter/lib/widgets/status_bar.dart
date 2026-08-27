import 'package:flutter/material.dart' hide ConnectionState;
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
