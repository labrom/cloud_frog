import 'dart:convert';

import 'package:cloud_frog/src/auth.dart';
import 'package:cloud_frog/src/oidc_token.dart';
import 'package:cloud_frog/src/public_keys.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:test/test.dart';

const _kid = 'test-key';
const _projectId = 'test-project';
const _issuer = '$issuerFirebasePrefix$_projectId';

// The JWT key parser expects PEM boundaries at the start of the string.
// ignore: leading_newlines_in_multiline_strings
final _privateKey = RSAPrivateKey('''-----BEGIN PRIVATE KEY-----
MIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQC7VJTUt9Us8cKj
MzEfYyjiWA4R4/M2bS1GB4t7NXp98C3SC6dVMvDuictGeurT8jNbvJZHtCSuYEvu
NMoSfm76oqFvAp8Gy0iz5sxjZmSnXyCdPEovGhLa0VzMaQ8s+CLOyS56YyCFGeJZ
qgtzJ6GR3eqoYSW9b9UMvkBpZODSctWSNGj3P7jRFDO5VoTwCQAWbFnOjDfH5Ulg
p2PKSQnSJP3AJLQNFNe7br1XbrhV//eO+t51mIpGSDCUv3E0DDFcWDTH9cXDTTlR
ZVEiR2BwpZOOkE/Z0/BVnhZYL71oZV34bKfWjQIt6V/isSMahdsAASACp4ZTGtwi
VuNd9tybAgMBAAECggEBAKTmjaS6tkK8BlPXClTQ2vpz/N6uxDeS35mXpqasqskV
laAidgg/sWqpjXDbXr93otIMLlWsM+X0CqMDgSXKejLS2jx4GDjI1ZTXg++0AMJ8
sJ74pWzVDOfmCEQ/7wXs3+cbnXhKriO8Z036q92Qc1+N87SI38nkGa0ABH9CN83H
mQqt4fB7UdHzuIRe/me2PGhIq5ZBzj6h3BpoPGzEP+x3l9YmK8t/1cN0pqI+dQwY
dgfGjackLu/2qH80MCF7IyQaseZUOJyKrCLtSD/Iixv/hzDEUPfOCjFDgTpzf3cw
ta8+oE4wHCo1iI1/4TlPkwmXx4qSXtmw4aQPz7IDQvECgYEA8KNThCO2gsC2I9PQ
DM/8Cw0O983WCDY+oi+7JPiNAJwv5DYBqEZB1QYdj06YD16XlC/HAZMsMku1na2T
N0driwenQQWzoev3g2S7gRDoS/FCJSI3jJ+kjgtaA7Qmzlgk1TxODN+G1H91HW7t
0l7VnL27IWyYo2qRRK3jzxqUiPUCgYEAx0oQs2reBQGMVZnApD1jeq7n4MvNLcPv
t8b/eU9iUv6Y4Mj0Suo/AU8lYZXm8ubbqAlwz2VSVunD2tOplHyMUrtCtObAfVDU
AhCndKaA9gApgfb3xw1IKbuQ1u4IF1FJl3VtumfQn//LiH1B3rXhcdyo3/vIttEk
48RakUKClU8CgYEAzV7W3COOlDDcQd935DdtKBFRAPRPAlspQUnzMi5eSHMD/ISL
DY5IiQHbIH83D4bvXq0X7qQoSBSNP7Dvv3HYuqMhf0DaegrlBuJllFVVq9qPVRnK
xt1Il2HgxOBvbhOT+9in1BzA+YJ99UzC85O0Qz06A+CmtHEy4aZ2kj5hHjECgYEA
mNS4+A8Fkss8Js1RieK2LniBxMgmYml3pfVLKGnzmng7H2+cwPLhPIzIuwytXywh
2bzbsYEfYx3EoEVgMEpPhoarQnYPukrJO4gwE2o5Te6T5mJSZGlQJQj9q4ZB2Dfz
et6INsK0oG8XVGXSpQvQh3RUYekCZQkBBFcpqWpbIEsCgYAnM3DQf3FJoSnXaMhr
VBIovic5l0xFkEHskAjFTevO86Fsz1C2aSeRKSqGFoOQ0tmJzBEs1R6KqnHInicD
TQrKhArgLXX4v3CddjfTRJkFWDbE/CkvKZNOrcf1nhaGCPspRJj2KUkj1Fhl9Cnc
dn/RsYEONbwQSjIfMPkvxF+8HQ==
-----END PRIVATE KEY-----''');

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
