import 'package:cloud_frog/src/gcloud_keys.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import 'keys.dart';
import 'user.dart';

class OIDCToken {
  OIDCToken({required String token})
      : _token = token,
        _decodedToken = JWT.decode(token);

  final String _token;
  final JWT _decodedToken;

  User get user => User(
        email: _decodedToken.payload['email'] as String,
        emailVerified: _decodedToken.payload['email_verified'] as bool,
      );

  void verify(
    Jwks jwks, {
    String? audience,
    String? issuer,
  }) {
    final kid = _decodedToken.header?['kid'] as String?;
    if (kid != null) {
      final jwk = jwks.key(kid);
      if (jwk == null) {
        throw TokenVerificationException('Invalid token key id');
      }
      try {
        _verifyWithKey(
          jwk,
          audience: audience,
          issuer: issuer,
        );
      } catch (e) {
        throw TokenVerificationException(e.toString());
      }
      return;
    } else {
      for (final jwk in jwks.keys) {
        try {
          _verifyWithKey(
            jwk,
            audience: audience,
            issuer: issuer,
          );
          return;
        } on Exception {
          // Do nothing, will try next one, and throw if we cannot return
        }
      }
      throw TokenVerificationException(
        "Token could'nt be verified with any key",
      );
    }
  }

  void _verifyWithKey(
    Jwk jwk, {
    String? audience,
    String? issuer,
  }) {
    JWT.verify(
      _token,
      RSAPublicKey(
        rsaPublicKeyFromJwkUsingASN1(
          n: jwk.n,
          e: jwk.e,
        ),
      ),
      audience: audience != null ? Audience.one(audience) : null,
      issuer: issuer,
    );
  }
}

class TokenVerificationException implements Exception {
  TokenVerificationException(this.message);

  final String message;
}
