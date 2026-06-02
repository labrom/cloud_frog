import 'package:cloud_frog/src/keys.dart';
import 'package:cloud_frog/src/public_keys.dart';
import 'package:cloud_frog/src/user.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class OIDCToken {
  OIDCToken({required String token}) : _token = token {
    try {
      _decodedToken = JWT.decode(token);
    } catch (e) {
      throw TokenVerificationException('Invalid token format: $e');
    }
  }

  final String _token;
  late final JWT _decodedToken;

  User get user {
    final payload = _payload;
    try {
      return User(
        subject: payload['sub'] as String,
        email: payload['email'] as String,
        emailVerified: payload['email_verified'] as bool,
      );
    } catch (e) {
      throw TokenVerificationException('Invalid user claims: $e');
    }
  }

  /// Verifies the token.
  ///
  /// The [T] type parameter is the public key format: [Jwk] or [Pem].
  void verify<T>(
    KeyStore<T> keyStore, {
    String? audience,
    String? issuer,
    String? requiredAlgorithm,
    bool requireKeyId = false,
    bool verifyFirebaseClaims = false,
  }) {
    _verifyHeader(requiredAlgorithm, requireKeyId);
    if (verifyFirebaseClaims) {
      _verifyFirebaseClaims();
    }

    final kid = _decodedToken.header?['kid'] as String?;
    if (kid != null) {
      final key = keyStore.key(kid);
      if (key == null) {
        throw TokenVerificationException('Invalid token key id');
      }
      try {
        _verifyWithRsaPK(_rsaPK(key), audience: audience, issuer: issuer);
      } catch (e) {
        throw TokenVerificationException(e.toString());
      }
      return;
    } else {
      for (final key in keyStore.keys) {
        try {
          _verifyWithRsaPK(_rsaPK(key), audience: audience, issuer: issuer);
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

  Map<String, dynamic> get _payload {
    final payload = _decodedToken.payload;
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    throw TokenVerificationException('Invalid token payload');
  }

  void _verifyHeader(String? requiredAlgorithm, bool requireKeyId) {
    final header = _decodedToken.header;
    if (header == null) {
      throw TokenVerificationException('Invalid token header');
    }

    final kid = header['kid'];
    if (requireKeyId && (kid is! String || kid.isEmpty)) {
      throw TokenVerificationException('Missing token key id');
    }

    if (requiredAlgorithm != null && header['alg'] != requiredAlgorithm) {
      throw TokenVerificationException(
        'Invalid token algorithm: ${header['alg']}',
      );
    }
  }

  void _verifyFirebaseClaims() {
    final payload = _payload;
    final sub = payload['sub'];
    if (sub is! String) {
      throw TokenVerificationException('Missing token subject');
    }
    if (sub.isEmpty) {
      throw TokenVerificationException('Empty token subject');
    }
    if (sub.length > 128) {
      throw TokenVerificationException('Token subject is too long');
    }

    final authTime = payload['auth_time'];
    if (authTime is! num) {
      throw TokenVerificationException('Invalid token auth_time');
    }

    final authTimeDate = DateTime.fromMillisecondsSinceEpoch(
      (authTime * 1000).toInt(),
      isUtc: true,
    );
    if (authTimeDate.isAfter(DateTime.now().toUtc())) {
      throw TokenVerificationException('Token auth_time is in the future');
    }
  }

  RSAPublicKey _rsaPK(dynamic key) {
    if (key is Jwk) {
      return RSAPublicKey(rsaPublicKeyFromJwkUsingASN1(n: key.n, e: key.e));
    }
    if (key is Pem) {
      return RSAPublicKey.cert(key.x509);
    }
    throw TokenVerificationException('Invalid public key format');
  }

  void _verifyWithRsaPK(RSAPublicKey key, {String? audience, String? issuer}) {
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
