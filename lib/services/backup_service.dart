// Stub — full implementation in Task 10
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  Future<bool> signIn() async => false;
  Future<void> signOut() async {}
  Future<String?> accountEmail() async => null;
  Future<void> backup() async {}
  Future<bool> restore() async => false;
  Future<void> restoreData() async {}
}
