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
