/// Asks for the PIN again after the app has been in the background for a
/// while. There is no "immediately" choice because taking a receipt photo or
/// sharing a file also sends the app to the background briefly.
class AppLock {
  static const settingKey = 'auto_lock_minutes';

  /// Minutes away before locking. 0 turns auto-lock off.
  static const choices = [0, 1, 5, 15];

  static String label(int minutes) => switch (minutes) {
        0 => 'Off',
        1 => 'After 1 minute',
        _ => 'After $minutes minutes',
      };

  static int parse(String value) {
    final minutes = int.tryParse(value) ?? 0;
    return choices.contains(minutes) ? minutes : 0;
  }

  static bool shouldLock({
    required DateTime? leftAt,
    required DateTime now,
    required int minutes,
  }) =>
      leftAt != null &&
      minutes > 0 &&
      now.difference(leftAt) >= Duration(minutes: minutes);
}
