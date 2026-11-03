import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The email history is encrypted by flutter_secure_storage. A password is
/// stored only after explicit opt-in and successful device biometric checking.
class RememberedAccounts {
  RememberedAccounts(this.storage);
  final FlutterSecureStorage storage;

  static const historyKey = 'bm_recent_account_emails_v1';
  static const credentialPrefix = 'bm_biometric_credential_';

  static String normalized(String value) => value.trim().toLowerCase();

  static String credentialKey(String email) =>
      '$credentialPrefix${base64Url.encode(utf8.encode(normalized(email)))}';

  static List<String> recentFirst(Iterable<String> current, String email) {
    final normalizedEmail = normalized(email);
    final entries = <String>[];
    if (normalizedEmail.isNotEmpty) {
      entries.add(normalizedEmail);
    }
    for (final entry in current) {
      final clean = normalized(entry);
      if (clean.isNotEmpty && !entries.contains(clean)) {
        entries.add(clean);
      }
      if (entries.length == 10) break;
    }
    return entries;
  }

  Future<List<String>> list() async {
    try {
      final text = await storage.read(key: historyKey);
      if (text == null || text.isEmpty) return [];
      final decoded = jsonDecode(text);
      if (decoded is! List) return [];
      final values = decoded.whereType<String>().map(normalized)
          .where((email) => email.isNotEmpty).toList();
      return values.toSet().take(10).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> recordLogin(String email) async {
    final accounts = recentFirst(await list(), email);
    await storage.write(key: historyKey, value: jsonEncode(accounts));
  }

  Future<void> rememberPassword(String email, String password) async {
    if (password.isEmpty) {
      throw const FormatException('Password is empty.');
    }
    await storage.write(key: credentialKey(email), value: password);
  }

  Future<bool> hasPassword(String email) async =>
      (await storage.read(key: credentialKey(email)))?.isNotEmpty == true;

  /// Call ONLY after successful biometric verification.
  Future<String?> passwordAfterBiometric(String email) =>
      storage.read(key: credentialKey(email));

  Future<void> clearPasswords() async {
    for (final email in await list()) {
      await storage.delete(key: credentialKey(email));
    }
  }
}
