class UserSettings {
  const UserSettings({
    required this.locationAlertEnabled,
    required this.pushAlertEnabled,
    required this.radiusM,
    required this.updatedAt,
  });

  final bool locationAlertEnabled;
  final bool pushAlertEnabled;
  final int radiusM;
  final DateTime? updatedAt;

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      locationAlertEnabled: (json['locationAlertEnabled'] as bool?) ?? true,
      pushAlertEnabled: (json['pushAlertEnabled'] as bool?) ?? true,
      radiusM: (json['radiusM'] as num?)?.toInt() ?? 100,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}
