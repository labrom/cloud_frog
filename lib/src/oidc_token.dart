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

  bool hasAudience(String audience) {
    final Audience? audiences = _decodedToken.audience;
    if (audiences == null) {
      return false;
    }
    return audiences.contains(audience);
  }

  String? get issuer => _decodedToken.issuer;

  User get user => User(
        email: _decodedToken.payload['email'] as String,
        emailVerified: _decodedToken.payload['email_verified'] as bool,
      );

  void verify(Jwks jwks) {
    final kid = _decodedToken.header?['kid'] as String?;
    if (kid != null) {
      final jwk = jwks.key(kid);
      if (jwk == null) {
        throw TokenVerificationException('Invalid token key id');
      }
      try {
        _verifyWithKey(jwk);
      } catch (e) {
        throw TokenVerificationException(e.toString());
      }
      return;
    } else {
      for (final jwk in jwks.keys) {
        try {
          _verifyWithKey(jwk);
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

  void _verifyWithKey(Jwk jwk) {
    JWT.verify(
      _token,
      RSAPublicKey(
        rsaPublicKeyFromJwkUsingASN1(
          n: jwk.n,
          e: jwk.e,
        ),
      ),
    );
  }
}

class TokenVerificationException implements Exception {
  TokenVerificationException(this.message);

  final String message;
}
