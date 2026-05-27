class AppSettings {
  final bool audioReviewEnabled;
  final bool audioInterruptEnabled;
  final double audioInterruptProbability; // default 0.5
  final int audioInterruptAfterMinutes; // default 60
  final String defaultTranslation; // "ESV"
  final String themeMode; // "system" | "light" | "dark"

  const AppSettings({
    this.audioReviewEnabled = false,
    this.audioInterruptEnabled = false,
    this.audioInterruptProbability = 0.5,
    this.audioInterruptAfterMinutes = 60,
    this.defaultTranslation = 'ESV',
    this.themeMode = 'system',
  });

  AppSettings copyWith({
    bool? audioReviewEnabled,
    bool? audioInterruptEnabled,
    double? audioInterruptProbability,
    int? audioInterruptAfterMinutes,
    String? defaultTranslation,
    String? themeMode,
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
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      audioReviewEnabled: map['audio_review_enabled'] as bool? ?? false,
      audioInterruptEnabled: map['audio_interrupt_enabled'] as bool? ?? false,
      audioInterruptProbability:
          (map['audio_interrupt_probability'] as num?)?.toDouble() ?? 0.5,
      audioInterruptAfterMinutes:
          map['audio_interrupt_after_minutes'] as int? ?? 60,
      defaultTranslation: map['default_translation'] as String? ?? 'ESV',
      themeMode: map['theme_mode'] as String? ?? 'system',
    );
  }
}
