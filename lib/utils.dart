import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

SecureRandom _secureRandom() {
  final secureRandom = FortunaRandom();

  final seed = Uint8List(32);
  final rng = Random.secure();
  for (var i = 0; i < seed.length; i++) {
    seed[i] = rng.nextInt(256);
  }

  secureRandom.seed(KeyParameter(seed));
  return secureRandom;
}

AsymmetricKeyPair<PublicKey, PrivateKey> generateRSAKeyPair({int bitLength = 2048}) {
  final secureRandom = _secureRandom();

  final keyGen = RSAKeyGenerator()
    ..init(ParametersWithRandom(
      RSAKeyGeneratorParameters(BigInt.parse('65537'), bitLength, 64),
      secureRandom,
    ));

  final pair = keyGen.generateKeyPair();
  return AsymmetricKeyPair<PublicKey, PrivateKey>(pair.publicKey, pair.privateKey);
}
