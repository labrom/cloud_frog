import 'package:cloud_frog/src/keys.dart';
import 'package:cloud_frog/src/public_keys.dart';
import 'package:cloud_frog/src/user.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class OIDCToken {
  OIDCToken({required String token})
      : _token = token,
        _decodedToken = JWT.decode(token);

  final String _token;
  final JWT _decodedToken;

  User get user => User(
        subject: _decodedToken.payload['sub'] as String,
        email: _decodedToken.payload['email'] as String,
        emailVerified: _decodedToken.payload['email_verified'] as bool,
      );

  /// Verifies the token.
  ///
  /// The [T] type parameter is the public key format: [Jwk] or [Pem].
  void verify<T>(
    KeyStore<T> keyStore, {
    String? audience,
    String? issuer,
  }) {
    final kid = _decodedToken.header?['kid'] as String?;
    if (kid != null) {
      final key = keyStore.key(kid);
      if (key == null) {
        throw TokenVerificationException('Invalid token key id');
      }
      try {
        _verifyWithRsaPK(
          _rsaPK(key),
          audience: audience,
          issuer: issuer,
        );
      } catch (e) {
        throw TokenVerificationException(e.toString());
      }
      return;
    } else {
      for (final key in keyStore.keys) {
        try {
          _verifyWithRsaPK(
            _rsaPK(key),
            audience: audience,
            issuer: issuer,
          );
          return;
        } on Exception {
          // Do nothing, will try next one, and throw if we cannot return
        }
      }
      throw TokenVerificationException(
        "Token couldn't be verified with any key",
      );
    }
  }

  RSAPublicKey _rsaPK(dynamic key) {
    if (key is Jwk) {
      return RSAPublicKey(
        rsaPublicKeyFromJwkUsingASN1(
          n: key.n,
          e: key.e,
        ),
      );
    }
    if (key is Pem) {
      return RSAPublicKey.cert(key.x509);
    }
    throw TokenVerificationException('Invalid public key format');
  }

  void _verifyWithRsaPK(
    RSAPublicKey key, {
    String? audience,
    String? issuer,
  }) {
    JWT.verify(
      _token,
      key,
      audience: audience != null ? Audience.one(audience) : null,
      issuer: issuer,
    );
  }
}

class TokenVerificationException implements Exception {
  TokenVerificationException(this.message);

  final String message;
}
