import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class RsaEncryptor {
  final RSAPublicKey _publicKey;
  final RSAPrivateKey _privateKey;
  final SecureRandom _rng;

  /// Generate a new RSA keypair (default 2048 bits).
  factory RsaEncryptor.generate({int rsaBits = 2048}) {
    final keyPair = _generateRsaKeyPair(rsaBits);
    return RsaEncryptor._(
      publicKey: keyPair.$1,
      privateKey: keyPair.$2,
      rng: _secureRandom(),
    );
  }

  /// Private constructor
  RsaEncryptor._({
    required RSAPublicKey publicKey,
    required RSAPrivateKey privateKey,
    required SecureRandom rng,
  }) : _publicKey = publicKey,
       _privateKey = privateKey,
       _rng = rng;

  /// Construct from existing keys (e.g., if you already have a keypair).
  RsaEncryptor.fromKeys({
    required RSAPublicKey publicKey,
    required RSAPrivateKey privateKey,
  }) : this._(
         publicKey: publicKey,
         privateKey: privateKey,
         rng: _secureRandom(),
       );

  /// Public key encoded as base64 in a custom binary format:
  /// [u16 nLen][nBytes][u16 eLen][eBytes]
  /// where n=modulus, e=exponent, big-endian unsigned.
  String get publicKeyBase64 => base64Encode(_encodePublicKey(_publicKey));

  /// Parse a public key from [publicKeyBase64] format above.
  static RSAPublicKey parsePublicKeyBase64(String b64) {
    final bytes = base64Decode(b64);
    var offset = 0;

    int readU16() {
      if (offset + 2 > bytes.length) throw FormatException('Bad public key');
      final v = (bytes[offset] << 8) | bytes[offset + 1];
      offset += 2;
      return v;
    }

    Uint8List readBytes(int len) {
      if (offset + len > bytes.length) throw FormatException('Bad public key');
      final out = bytes.sublist(offset, offset + len);
      offset += len;
      return Uint8List.fromList(out);
    }

    final nLen = readU16();
    final nBytes = readBytes(nLen);
    final eLen = readU16();
    final eBytes = readBytes(eLen);

    final n = _decodeBigIntUnsigned(nBytes);
    final e = _decodeBigIntUnsigned(eBytes);
    return RSAPublicKey(n, e);
  }

  /// Encrypt a UTF-8 string. Output is a base64 envelope.
  ///
  /// Envelope binary format (then base64):
  /// [u16 encKeyLen][encKey][u8 nonceLen][nonce][ciphertextWithTag]
  ///
  /// - AES key: random 32 bytes (AES-256)
  /// - Nonce: random 12 bytes (GCM recommended)
  /// - Ciphertext includes the 16-byte GCM tag appended (PointyCastle behavior)
  String encrypt(String plaintext) {
    final plainBytes = Uint8List.fromList(utf8.encode(plaintext));

    // 1) AES key + nonce
    final aesKey = _generateRandomBytes(32);
    final nonce = _generateRandomBytes(12);

    // 2) AES-GCM encrypt
    final gcm = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(aesKey),
      128, // tag bits
      nonce,
      Uint8List(0), // AAD (empty). Add AAD support here if you need it.
    );
    gcm.init(true, params);
    final cipherBytes = gcm.process(plainBytes);

    // 3) RSA-OAEP wrap AES key
    final encKey = _rsaEncryptOaep(_publicKey, aesKey);

    // 4) Pack envelope
    final bb = BytesBuilder();
    bb.add(_u16be(encKey.length));
    bb.add(encKey);
    bb.add([nonce.length]); // u8
    bb.add(nonce);
    bb.add(cipherBytes);

    return base64Encode(bb.toBytes());
  }

  /// Decrypt a base64 envelope produced by encrypt().
  String decrypt(String envelopeBase64) {
    final bytes = base64Decode(envelopeBase64);
    var offset = 0;

    int readU16() {
      if (offset + 2 > bytes.length) throw FormatException('Bad envelope');
      final v = (bytes[offset] << 8) | bytes[offset + 1];
      offset += 2;
      return v;
    }

    int readU8() {
      if (offset + 1 > bytes.length) throw FormatException('Bad envelope');
      final v = bytes[offset];
      offset += 1;
      return v;
    }

    Uint8List readBytes(int len) {
      if (offset + len > bytes.length) throw FormatException('Bad envelope');
      final out = bytes.sublist(offset, offset + len);
      offset += len;
      return Uint8List.fromList(out);
    }

    final encKeyLen = readU16();
    final encKey = readBytes(encKeyLen);

    final nonceLen = readU8();
    final nonce = readBytes(nonceLen);

    final cipherBytes = readBytes(bytes.length - offset);

    // 1) RSA-OAEP unwrap AES key
    final aesKey = _rsaDecryptOaep(_privateKey, encKey);
    if (aesKey.length != 32) {
      throw StateError('Unexpected AES key length: ${aesKey.length}');
    }

    // 2) AES-GCM decrypt (throws if tag invalid / tampering)
    final gcm = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(aesKey),
      128,
      nonce,
      Uint8List(0), // must match encrypt AAD
    );
    gcm.init(false, params);

    final plainBytes = gcm.process(cipherBytes);
    return utf8.decode(plainBytes);
  }

  /// Encrypt a UTF-8 string using any RSA public key. Output is a base64 envelope.
  static String encryptWithPublicKey(RSAPublicKey publicKey, String plaintext) {
    final plainBytes = Uint8List.fromList(utf8.encode(plaintext));
    final rng = _secureRandom();

    // 1) AES key + nonce
    final aesKey = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      aesKey[i] = rng.nextUint32() & 0xFF;
    }
    final nonce = Uint8List(12);
    for (int i = 0; i < 12; i++) {
      nonce[i] = rng.nextUint32() & 0xFF;
    }

    // 2) AES-GCM encrypt
    final gcm = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(aesKey),
      128,
      nonce,
      Uint8List(0),
    );
    gcm.init(true, params);
    final cipherBytes = gcm.process(plainBytes);

    // 3) RSA-OAEP wrap AES key
    final encKey = _rsaEncryptOaep(publicKey, aesKey);

    // 4) Pack envelope
    final bb = BytesBuilder();
    bb.add(_u16be(encKey.length));
    bb.add(encKey);
    bb.add([nonce.length]); // u8
    bb.add(nonce);
    bb.add(cipherBytes);

    return base64Encode(bb.toBytes());
  }

  // -------------------- internals --------------------

  Uint8List _generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _rng.nextUint32() & 0xFF;
    }
    return bytes;
  }

  static (RSAPublicKey, RSAPrivateKey) _generateRsaKeyPair(int bitLength) {
    final secureRandom = _secureRandom();
    final keyGen = RSAKeyGenerator()
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.parse('65537'), bitLength, 64),
          secureRandom,
        ),
      );
    final pair = keyGen.generateKeyPair();
    return (pair.publicKey, pair.privateKey);
  }

  static Uint8List _rsaEncryptOaep(
    RSAPublicKey publicKey,
    Uint8List plaintext,
  ) {
    final engine = OAEPEncoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    return engine.process(plaintext);
  }

  static Uint8List _rsaDecryptOaep(
    RSAPrivateKey privateKey,
    Uint8List ciphertext,
  ) {
    final engine = OAEPEncoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    return engine.process(ciphertext);
  }

  static SecureRandom _secureRandom() {
    final secureRandom = FortunaRandom();
    final seed = Uint8List(32);
    final rng = Random.secure();
    for (var i = 0; i < seed.length; i++) {
      seed[i] = rng.nextInt(256);
    }
    secureRandom.seed(KeyParameter(seed));
    return secureRandom;
  }

  static Uint8List _encodePublicKey(RSAPublicKey key) {
    final nBytes = _encodeBigIntUnsigned(key.modulus!);
    final eBytes = _encodeBigIntUnsigned(key.exponent!);

    final bb = BytesBuilder();
    bb.add(_u16be(nBytes.length));
    bb.add(nBytes);
    bb.add(_u16be(eBytes.length));
    bb.add(eBytes);
    return bb.toBytes();
  }

  static Uint8List _u16be(int v) =>
      Uint8List.fromList([(v >> 8) & 0xFF, v & 0xFF]);

  static Uint8List _encodeBigIntUnsigned(BigInt i) {
    if (i == BigInt.zero) return Uint8List.fromList([0]);
    var x = i;
    final bytes = <int>[];
    while (x > BigInt.zero) {
      bytes.add((x & BigInt.from(0xFF)).toInt());
      x = x >> 8;
    }
    return Uint8List.fromList(bytes.reversed.toList());
  }

  static BigInt _decodeBigIntUnsigned(Uint8List bytes) {
    var result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b);
    }
    return result;
  }
}

class BaleConfigsCodec {
  static const int WT_VARINT = 0;
  static const int WT_LEN = 2;

  // ---------- public API ----------

  /// Build the protobuf-like payload (raw bytes).
  Uint8List createMessage({required String message, required int userId}) {
    final raw = _makeOuter(message: message, userId: userId);
    return raw;
  }

  /// Extract (userId, content) from the payload bytes.
  ///
  /// Mirrors the Python logic:
  /// - Collect all printable UTF-8 strings found in length-delimited fields.
  /// - Find a string starting with "drafts_" -> user id suffix.
  /// - Content is the last other string (if any).
  ///
  /// Returns null if not found / not parseable.
  ({int userId, String content})? parseMessage(Uint8List data) {
    try {
      final strings = _extractUtf8Strings(data);
      for (final s in strings) {
        if (s.startsWith('drafts_')) {
          final userIdStr = s.substring('drafts_'.length);
          final contentCandidates = strings.where((st) => st != s).toList();
          final content = contentCandidates.isNotEmpty
              ? contentCandidates.last
              : '';
          final uid = int.tryParse(userIdStr);
          if (uid == null) return null;
          return (userId: uid, content: content);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ---------- encoder helpers ----------

  Uint8List _uvarint(int n) {
    if (n < 0) throw ArgumentError('uvarint must be non-negative');
    final out = <int>[];
    var x = n;
    while (true) {
      final b = x & 0x7F;
      x >>= 7;
      if (x != 0) {
        out.add(b | 0x80);
      } else {
        out.add(b);
        return Uint8List.fromList(out);
      }
    }
  }

  Uint8List _key(int fieldNumber, int wireType) {
    return _uvarint((fieldNumber << 3) | wireType);
  }

  Uint8List _putVarint(int field, int value) {
    return _concat([_key(field, WT_VARINT), _uvarint(value)]);
  }

  Uint8List _putBytes(int field, Uint8List b) {
    return _concat([_key(field, WT_LEN), _uvarint(b.length), b]);
  }

  Uint8List _putString(int field, String s) {
    return _putBytes(field, Uint8List.fromList(utf8.encode(s)));
  }

  Uint8List _embedded(int field, Uint8List msgBytes) {
    return _putBytes(field, msgBytes);
  }

  Uint8List _makeValue(String s) {
    // message Value { string v = 1; }
    return _putString(1, s);
  }

  Uint8List _makeKv(String k, String v) {
    // message KV { string key = 1; Value value = 2; }
    return _concat([_putString(1, k), _embedded(2, _makeValue(v))]);
  }

  Uint8List _makeF3({required String message, required int userId}) {
    // field3: { 1:drafts_<user_id>, 2:{1:message} }
    return _concat([
      _putString(1, 'drafts_$userId'),
      _embedded(2, _makeValue(message)),
    ]);
  }

  Uint8List _makeF4() {
    // field4: repeated field1 KV entries
    final nowMs = DateTime.now().millisecondsSinceEpoch.toString();
    final entries = <({String k, String v})>[
      (k: 'app_version', v: '139630'),
      (k: 'browser_type', v: '1'),
      (k: 'browser_version', v: '143.0.0.0'),
      (k: 'os_type', v: '3'),
      (k: 'session_id', v: nowMs),
      (k: 'mt_app_version', v: '139630'),
      (k: 'mt_browser_type', v: '1'),
      (k: 'mt_browser_version', v: '143.0.0.0'),
      (k: 'mt_os_type', v: '3'),
      (k: 'mt_session_id', v: nowMs),
    ];

    final parts = <Uint8List>[];
    for (final e in entries) {
      parts.add(_embedded(1, _makeKv(e.k, e.v)));
    }
    return _concat(parts);
  }

  Uint8List _makeInner({required String message, required int userId}) {
    // inner:
    // 1:"bale.v1.Configs"
    // 2:"EditParameter"
    // 3:<f3>
    // 4:<f4>
    // 5:73
    return _concat([
      _putString(1, 'bale.v1.Configs'),
      _putString(2, 'EditParameter'),
      _embedded(3, _makeF3(message: message, userId: userId)),
      _embedded(4, _makeF4()),
      _putVarint(5, 73),
    ]);
  }

  Uint8List _makeOuter({required String message, required int userId}) {
    // outer: field 1 = embedded(inner)
    return _embedded(1, _makeInner(message: message, userId: userId));
  }

  // ---------- decoder helpers ----------

  /// Returns (value, nextIndex)
  (int, int) _readVarint(Uint8List buf, int i) {
    var shift = 0;
    var value = 0;

    while (true) {
      if (i >= buf.length) {
        throw FormatException('Truncated varint');
      }
      final b = buf[i];
      i += 1;

      value |= (b & 0x7F) << shift;
      if ((b & 0x80) == 0) {
        return (value, i);
      }

      shift += 7;
      if (shift > 70) {
        throw FormatException('Varint too long');
      }
    }
  }

  bool _looksLikeProtobufMessage(Uint8List chunk) {
    // Heuristic: first key must be a valid varint, with plausible field number,
    // and wire type in {0,1,2,3,4,5}.
    if (chunk.isEmpty) return false;
    try {
      final (key, _) = _readVarint(chunk, 0);
      final fieldNumber = key >> 3;
      final wireType = key & 0x07;
      return fieldNumber >= 1 &&
          fieldNumber <= 100000 &&
          (wireType >= 0 && wireType <= 5);
    } catch (_) {
      return false;
    }
  }

  int _skipField(Uint8List buf, int i, int wireType, int fieldNumber) {
    final n = buf.length;

    if (wireType == 0) {
      final (_, next) = _readVarint(buf, i);
      return next;
    }

    if (wireType == 1) {
      if (i + 8 > n) throw FormatException('Truncated 64-bit field');
      return i + 8;
    }

    if (wireType == 2) {
      final (length, next) = _readVarint(buf, i);
      i = next;
      if (i + length > n)
        throw FormatException('Truncated length-delimited field');
      return i + length;
    }

    if (wireType == 5) {
      if (i + 4 > n) throw FormatException('Truncated 32-bit field');
      return i + 4;
    }

    if (wireType == 3) {
      // START_GROUP: skip until matching END_GROUP for same field number
      while (i < n) {
        final (key, next) = _readVarint(buf, i);
        i = next;
        final fn = key >> 3;
        final wt = key & 0x07;
        if (wt == 4 && fn == fieldNumber) {
          return i;
        }
        i = _skipField(buf, i, wt, fn);
      }
      throw FormatException('Truncated group (no matching END_GROUP)');
    }

    if (wireType == 4) {
      // END_GROUP handled by caller
      return i;
    }

    throw FormatException('Unsupported wire type: $wireType');
  }

  List<String> _extractUtf8Strings(
    Uint8List buf, {
    int maxDepth = 20,
    int depth = 0,
  }) {
    if (depth > maxDepth) return <String>[];

    final out = <String>[];
    var i = 0;
    final n = buf.length;

    while (i < n) {
      final (key, nextI) = _readVarint(buf, i);
      i = nextI;

      final fieldNumber = key >> 3;
      final wireType = key & 0x07;

      if (wireType == 4) {
        // END_GROUP ends this level
        return out;
      }

      if (wireType == 2) {
        final (length, next2) = _readVarint(buf, i);
        i = next2;

        if (i + length > n)
          throw FormatException('Truncated length-delimited field');

        final chunk = Uint8List.sublistView(buf, i, i + length);
        i += length;

        // Capture printable UTF-8 strings
        try {
          final s = utf8.decode(chunk, allowMalformed: false);
          if (s.isNotEmpty && _isMostlyPrintable(s)) {
            out.add(s);
          }
        } catch (_) {
          // ignore decoding errors
        }

        // Recurse only if chunk plausibly looks like a protobuf message.
        if (_looksLikeProtobufMessage(chunk)) {
          try {
            out.addAll(
              _extractUtf8Strings(chunk, maxDepth: maxDepth, depth: depth + 1),
            );
          } catch (_) {
            // ignore nested decode errors
          }
        }
      } else {
        i = _skipField(buf, i, wireType, fieldNumber);
      }
    }

    return out;
  }

  bool _isMostlyPrintable(String s) {
    // Mirrors Python's: ch.isprintable() or ch in "\r\n\t"
    // Dart doesn't have isPrintable, so implement conservative ASCII+common Unicode check:
    // - allow whitespace \r \n \t
    // - disallow control chars < 0x20 except those, and 0x7F
    for (final rune in s.runes) {
      if (rune == 0x0D || rune == 0x0A || rune == 0x09) continue; // \r \n \t
      if (rune < 0x20 || rune == 0x7F) return false;
    }
    return true;
  }

  // ---------- utils ----------

  Uint8List _concat(List<Uint8List> parts) {
    var total = 0;
    for (final p in parts) {
      total += p.length;
    }
    final out = Uint8List(total);
    var offset = 0;
    for (final p in parts) {
      out.setRange(offset, offset + p.length, p);
      offset += p.length;
    }
    return out;
  }
}
