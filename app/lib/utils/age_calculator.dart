/// Utility for calculating age from date of birth.
class AgeCalculator {
  AgeCalculator._();

  /// Returns the age in years from a date of birth.
  static int yearsFromDob(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  /// Returns the age bracket string for UI display.
  static String ageBracket(DateTime dob) {
    final age = yearsFromDob(dob);
    if (age < 3) return 'Toddler';
    if (age < 6) return 'Preschool';
    if (age < 9) return 'Early School';
    return 'Older Kids';
  }
}
