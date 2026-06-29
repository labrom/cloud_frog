import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_frog/src/auth.dart';
import 'package:cloud_frog/src/oidc_token.dart';
import 'package:cloud_frog/src/public_keys.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:test/test.dart';

const _kid = 'test-key';
const _projectId = 'test-project';
const _issuer = '$issuerFirebasePrefix$_projectId';
final _privateKey = _generatePrivateKey();

void main() {
  group('OIDCToken', () {
    test('verifies a Firebase token with required claims', () {
      final token = OIDCToken(token: _firebaseToken())
        ..verify(
          _keyStore(),
          audience: _projectId,
          issuer: _issuer,
          requiredAlgorithm: 'RS256',
          requireKeyId: true,
          verifyFirebaseClaims: true,
        );

      final user = token.user;
      expect(user.subject, 'user-123');
      expect(user.email, 'user@example.com');
      expect(user.emailVerified, true);
      expect(user.accountDisabled, false);
    });

    test('reads the account disabled claim from a Firebase token', () {
      final token =
          OIDCToken(token: _firebaseToken(payload: {'account_disabled': true}))
            ..verify(
              _keyStore(),
              audience: _projectId,
              issuer: _issuer,
              requiredAlgorithm: 'RS256',
              requireKeyId: true,
              verifyFirebaseClaims: true,
            );

      final user = token.user;
      expect(user.accountDisabled, true);
    });

    test('reads the disabled claim from a Firebase token', () {
      final token =
          OIDCToken(token: _firebaseToken(payload: {'disabled': true}))..verify(
            _keyStore(),
            audience: _projectId,
            issuer: _issuer,
            requiredAlgorithm: 'RS256',
            requireKeyId: true,
            verifyFirebaseClaims: true,
          );

      final user = token.user;
      expect(user.accountDisabled, true);
    });

    test('rejects malformed tokens without leaking an exception type', () {
      expect(
        () => OIDCToken(token: 'not-a-token'),
        throwsA(isA<TokenVerificationException>()),
      );
    });

    test('rejects Firebase tokens without kid', () {
      final token = OIDCToken(token: _firebaseToken(includeKid: false));

      expect(
        () => token.verify(
          _keyStore(),
          audience: _projectId,
          issuer: _issuer,
          requiredAlgorithm: 'RS256',
          requireKeyId: true,
          verifyFirebaseClaims: true,
        ),
        throwsA(isA<TokenVerificationException>()),
      );
    });

    test('rejects Firebase tokens signed with the wrong algorithm', () {
      final token = OIDCToken(
        token: _firebaseToken(algorithm: JWTAlgorithm.RS384),
      );

      expect(
        () => token.verify(
          _keyStore(),
          audience: _projectId,
          issuer: _issuer,
          requiredAlgorithm: 'RS256',
          requireKeyId: true,
          verifyFirebaseClaims: true,
        ),
        throwsA(isA<TokenVerificationException>()),
      );
    });

    test('rejects Firebase tokens with an empty subject', () {
      final token = OIDCToken(token: _firebaseToken(payload: {'sub': ''}));

      expect(
        () => token.verify(
          _keyStore(),
          audience: _projectId,
          issuer: _issuer,
          requiredAlgorithm: 'RS256',
          requireKeyId: true,
          verifyFirebaseClaims: true,
        ),
        throwsA(isA<TokenVerificationException>()),
      );
    });

    test('rejects Firebase tokens with auth_time in the future', () {
      final token = OIDCToken(
        token: _firebaseToken(
          payload: {
            'auth_time': _secondsSinceEpoch(
              DateTime.now().toUtc().add(const Duration(minutes: 1)),
            ),
          },
        ),
      );

      expect(
        () => token.verify(
          _keyStore(),
          audience: _projectId,
          issuer: _issuer,
          requiredAlgorithm: 'RS256',
          requireKeyId: true,
          verifyFirebaseClaims: true,
        ),
        throwsA(isA<TokenVerificationException>()),
      );
    });

    test('rejects invalid user claims after successful token verification', () {
      final token =
          OIDCToken(token: _firebaseToken(payload: {'email_verified': 'true'}))
            ..verify(
              _keyStore(),
              audience: _projectId,
              issuer: _issuer,
              requiredAlgorithm: 'RS256',
              requireKeyId: true,
              verifyFirebaseClaims: true,
            );

      expect(() => token.user, throwsA(isA<TokenVerificationException>()));
    });

    test('rejects invalid account disabled claims', () {
      final token =
          OIDCToken(token: _firebaseToken(payload: {'disabled': 'true'}))
            ..verify(
              _keyStore(),
              audience: _projectId,
              issuer: _issuer,
              requiredAlgorithm: 'RS256',
              requireKeyId: true,
              verifyFirebaseClaims: true,
            );

      expect(() => token.user, throwsA(isA<TokenVerificationException>()));
    });
  });
}

String _firebaseToken({
  Map<String, dynamic>? header,
  Map<String, dynamic>? payload,
  JWTAlgorithm algorithm = JWTAlgorithm.RS256,
  bool includeKid = true,
}) {
  return JWT(
    {
      'aud': _projectId,
      'auth_time': _secondsSinceEpoch(DateTime.now().toUtc()),
      'email': 'user@example.com',
      'email_verified': true,
      'iss': _issuer,
      'sub': 'user-123',
      ...?payload,
    },
    header: {if (includeKid) 'kid': _kid, ...?header},
  ).sign(
    _privateKey,
    algorithm: algorithm,
    expiresIn: const Duration(hours: 1),
  );
}

Jwks _keyStore() {
  return Jwks.fromJson(
    jsonEncode({
      'keys': [_privateKey.toJWK(keyID: _kid, algorithm: JWTAlgorithm.RS256)],
    }),
  );
}

int _secondsSinceEpoch(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;

RSAPrivateKey _generatePrivateKey() {
  final random = Random.secure();
  final seed = Uint8List.fromList(
    List<int>.generate(32, (_) => random.nextInt(256)),
  );
  final secureRandom = pc.SecureRandom('Fortuna')..seed(pc.KeyParameter(seed));
  final generator = pc.RSAKeyGenerator()
    ..init(
      pc.ParametersWithRandom(
        pc.RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
        secureRandom,
      ),
    );

  final pair = generator.generateKeyPair();
  return RSAPrivateKey.raw(pair.privateKey);
}
