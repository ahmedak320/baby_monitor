import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PBKDF2 key derivation using HMAC-SHA256.
class Pbkdf2 {
  /// Derive a key from [password] and [salt] using PBKDF2-HMAC-SHA256.
  ///
  /// [iterations] defaults to 100,000 for strong brute-force resistance.
  /// [keyLength] is the desired output length in bytes (default 32).
  static Uint8List derive(
    String password,
    Uint8List salt, {
    int iterations = 100000,
    int keyLength = 32,
  }) {
    final hmacFactory = Hmac(sha256, password.codeUnits);
    final numBlocks = (keyLength + 31) ~/ 32; // SHA-256 produces 32-byte blocks
    final result = BytesBuilder();

    for (var blockIndex = 1; blockIndex <= numBlocks; blockIndex++) {
      // U1 = PRF(password, salt || INT_32_BE(blockIndex))
      final saltWithIndex = BytesBuilder()
        ..add(salt)
        ..addByte((blockIndex >> 24) & 0xff)
        ..addByte((blockIndex >> 16) & 0xff)
        ..addByte((blockIndex >> 8) & 0xff)
        ..addByte(blockIndex & 0xff);

      var u = Uint8List.fromList(
        hmacFactory.convert(saltWithIndex.toBytes()).bytes,
      );
      final block = Uint8List.fromList(u);

      for (var i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmacFactory.convert(u).bytes);
        for (var j = 0; j < block.length; j++) {
          block[j] ^= u[j];
        }
      }

      result.add(block);
    }

    return Uint8List.fromList(result.toBytes().sublist(0, keyLength));
  }

  /// Convert bytes to a hex string.
  static String toHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Convert a hex string to bytes.
  static Uint8List fromHex(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}
