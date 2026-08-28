import 'package:flutter/material.dart';

/// Muestra la noche actual (1-5) y la hora simulada del reloj (12:00 AM ->
/// 6:00 AM). Puramente presentacional — GameScreen le pasa los valores
/// leídos de GameProvider.session.
class BarraRelojDeNoche extends StatelessWidget {
  final int nocheActual;
  final String horaEnJuego;

  const BarraRelojDeNoche({
    super.key,
    required this.nocheActual,
    required this.horaEnJuego,
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
            Text('Noche $nocheActual/5'),
          ],
        ),
        Row(
          children: [
            const Icon(Icons.access_time, size: 18),
            const SizedBox(width: 6),
            Text(horaEnJuego),
          ],
        ),
      ],
    );
  }
}
