class AppSettings {
  final bool audioReviewEnabled;
  final bool audioInterruptEnabled;
  final double audioInterruptProbability; // default 0.5
  final int audioInterruptAfterMinutes; // default 60
  final String defaultTranslation; // "ESV"
  final String themeMode; // "system" | "light" | "dark"
  final bool driveBackupEnabled; // opt-in only, default false
  final String backupCadence; // "daily" | "weekly" | "monthly"
  final DateTime? lastBackupAt;
  // Consent record persisted for audit; null = not yet consented
  final String? driveConsentAt; // ISO-8601
  final int driveConsentVersion; // disclosure version shown at consent time

  const AppSettings({
    this.audioReviewEnabled = false,
    this.audioInterruptEnabled = false,
    this.audioInterruptProbability = 0.5,
    this.audioInterruptAfterMinutes = 60,
    this.defaultTranslation = 'ESV',
    this.themeMode = 'system',
    this.driveBackupEnabled = false,
    this.backupCadence = 'weekly',
    this.lastBackupAt,
    this.driveConsentAt,
    this.driveConsentVersion = 0,
  });

  AppSettings copyWith({
    bool? audioReviewEnabled,
    bool? audioInterruptEnabled,
    double? audioInterruptProbability,
    int? audioInterruptAfterMinutes,
    String? defaultTranslation,
    String? themeMode,
    bool? driveBackupEnabled,
    String? backupCadence,
    DateTime? lastBackupAt,
    bool clearLastBackupAt = false,
    String? driveConsentAt,
    int? driveConsentVersion,
  }) {
    return AppSettings(
      audioReviewEnabled: audioReviewEnabled ?? this.audioReviewEnabled,
      audioInterruptEnabled:
          audioInterruptEnabled ?? this.audioInterruptEnabled,
      audioInterruptProbability:
          audioInterruptProbability ?? this.audioInterruptProbability,
      audioInterruptAfterMinutes:
          audioInterruptAfterMinutes ?? this.audioInterruptAfterMinutes,
      defaultTranslation: defaultTranslation ?? this.defaultTranslation,
      themeMode: themeMode ?? this.themeMode,
      driveBackupEnabled: driveBackupEnabled ?? this.driveBackupEnabled,
      backupCadence: backupCadence ?? this.backupCadence,
      lastBackupAt:
          clearLastBackupAt ? null : (lastBackupAt ?? this.lastBackupAt),
      driveConsentAt: driveConsentAt ?? this.driveConsentAt,
      driveConsentVersion: driveConsentVersion ?? this.driveConsentVersion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'audio_review_enabled': audioReviewEnabled,
      'audio_interrupt_enabled': audioInterruptEnabled,
      'audio_interrupt_probability': audioInterruptProbability,
      'audio_interrupt_after_minutes': audioInterruptAfterMinutes,
      'default_translation': defaultTranslation,
      'theme_mode': themeMode,
      'drive_backup_enabled': driveBackupEnabled,
      'backup_cadence': backupCadence,
      'last_backup_at': lastBackupAt?.toIso8601String(),
      'drive_consent_at': driveConsentAt,
      'drive_consent_version': driveConsentVersion,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    final lastBackupRaw = map['last_backup_at'] as String?;
    DateTime? lastBackupAt;
    if (lastBackupRaw != null) {
      final parsed = DateTime.tryParse(lastBackupRaw);
      // Reject far-future timestamps (tampered preference guard per security review)
      if (parsed != null &&
          parsed.isBefore(DateTime.now().add(const Duration(days: 365)))) {
        lastBackupAt = parsed;
      }
    }

    final cadenceRaw = map['backup_cadence'] as String? ?? 'weekly';
    const validCadences = {'daily', 'weekly', 'monthly'};
    final backupCadence =
        validCadences.contains(cadenceRaw) ? cadenceRaw : 'weekly';

    return AppSettings(
      audioReviewEnabled: map['audio_review_enabled'] as bool? ?? false,
      audioInterruptEnabled: map['audio_interrupt_enabled'] as bool? ?? false,
      audioInterruptProbability:
          (map['audio_interrupt_probability'] as num?)?.toDouble() ?? 0.5,
      audioInterruptAfterMinutes:
          map['audio_interrupt_after_minutes'] as int? ?? 60,
      defaultTranslation: map['default_translation'] as String? ?? 'ESV',
      themeMode: map['theme_mode'] as String? ?? 'system',
      driveBackupEnabled: map['drive_backup_enabled'] as bool? ?? false,
      backupCadence: backupCadence,
      lastBackupAt: lastBackupAt,
      driveConsentAt: map['drive_consent_at'] as String?,
      driveConsentVersion: map['drive_consent_version'] as int? ?? 0,
    );
  }
}
