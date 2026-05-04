/// Preferencias de avatar almacenadas en `users/{uid}` (Firestore).
abstract final class UserAvatarMode {
  static const String custom = 'custom';
  static const String defaultMale = 'default_male';
  static const String defaultFemale = 'default_female';
  static const String defaultNeutral = 'default_neutral';

  /// Valores de [AppUser.gender] reconocidos para fallback visual.
  static const String genderMale = 'male';
  static const String genderFemale = 'female';
  static const String genderNeutral = 'neutral';
}
