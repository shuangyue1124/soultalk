import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class BackupEncryption {
  static const _saltLength = 32;
  static const _ivLength = 16;

  /// Encrypt bytes with AES-128-CBC using password.
  /// Returns [salt][iv][ciphertext] concatenated.
  static Uint8List encrypt(Uint8List plainData, String password) {
    // Generate random salt and IV
    final salt = enc.Key.fromSecureRandom(_saltLength);
    final keyBytes = _deriveKey(password, salt.bytes);
    final key = enc.Key(keyBytes);

    final iv = enc.IV.fromSecureRandom(_ivLength);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final encrypted = encrypter.encryptBytes(plainData, iv: iv);

    // Concatenate: salt + iv + ciphertext
    final saltBytes = salt.bytes;
    final ivBytes = iv.bytes;
    final cipherBytes = encrypted.bytes;
    final result = Uint8List(
      saltBytes.length + ivBytes.length + cipherBytes.length,
    );
    var offset = 0;
    result.setAll(offset, saltBytes);
    offset += saltBytes.length;
    result.setAll(offset, ivBytes);
    offset += ivBytes.length;
    result.setAll(offset, cipherBytes);
    return result;
  }

  /// Decrypt bytes. Input format: [salt(32)][iv(16)][ciphertext]
  static Uint8List decrypt(Uint8List encryptedData, String password) {
    if (encryptedData.length < _saltLength + _ivLength + 16) {
      throw ArgumentError('Invalid encrypted data: too short');
    }

    final saltBytes = encryptedData.sublist(0, _saltLength);
    final ivBytes = encryptedData.sublist(_saltLength, _saltLength + _ivLength);
    final cipherBytes = encryptedData.sublist(_saltLength + _ivLength);

    final keyBytes = _deriveKey(password, saltBytes);
    final key = enc.Key(keyBytes);
    final iv = enc.IV(Uint8List.fromList(ivBytes));

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decryptBytes(
      enc.Encrypted(Uint8List.fromList(cipherBytes)),
      iv: iv,
    );

    return Uint8List.fromList(decrypted);
  }

  /// Derive a 16-byte key from password + salt (AES-128).
  static Uint8List _deriveKey(String password, List<int> salt) {
    final saltStr = String.fromCharCodes(salt);
    var key = utf8.encode('$password$saltStr');
    final passwordBytes = utf8.encode(password);
    for (var i = 0; i < 10000; i++) {
      final hmac = Hmac(sha256, key);
      key = Uint8List.fromList(hmac.convert(passwordBytes).bytes);
    }
    return Uint8List.fromList(sha256.convert(key).bytes.sublist(0, 16));
  }
}
