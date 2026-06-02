import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:json_annotation/json_annotation.dart';

part 'public_keys.g.dart';

final _gCloudPublicKeysUrl = Uri.parse(
  'https://www.googleapis.com/oauth2/v3/certs',
);

final _firebasePublicKeysUrl = Uri.parse(
  'https://www.googleapis.com/robot/v1/metadata/x509/'
  'securetoken@system.gserviceaccount.com',
);

Future<Jwks> gCloudPublicKeys({Client? client}) async {
  return _fetchPublicKeys(_gCloudPublicKeysUrl, Jwks.fromJson, client: client);
}

Future<Pems> firebasePublicKeys({Client? client}) async {
  return _fetchPublicKeys(
    _firebasePublicKeysUrl,
    Pems.fromJson,
    client: client,
  );
}

Future<T> _fetchPublicKeys<T extends KeyStore<dynamic>>(
  Uri uri,
  T Function(String) parse, {
  Client? client,
}) async {
  final effectiveClient = client ?? Client();
  try {
    final response = await effectiveClient
        .get(uri)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PublicKeysException(
        'Failed to fetch public keys: HTTP ${response.statusCode}',
      );
    }

    try {
      final keyStore = parse(response.body)
        ..expiresAt = _expiresAt(response.headers);
      return keyStore;
    } catch (e) {
      throw PublicKeysException('Invalid public keys response: $e');
    }
  } on PublicKeysException {
    rethrow;
  } on TimeoutException catch (e) {
    throw PublicKeysException('Timed out fetching public keys: $e');
  } on ClientException catch (e) {
    throw PublicKeysException('Failed to fetch public keys: $e');
  } finally {
    if (client == null) {
      effectiveClient.close();
    }
  }
}

DateTime? _expiresAt(Map<String, String> headers) {
  final cacheControl = headers['cache-control'];
  if (cacheControl == null) {
    return null;
  }

  final match = RegExp(
    r'(?:^|[,;])\s*max-age\s*=\s*(\d+)',
    caseSensitive: false,
  ).firstMatch(cacheControl);
  if (match == null) {
    return null;
  }

  final maxAge = int.tryParse(match.group(1)!);
  if (maxAge == null || maxAge <= 0) {
    return null;
  }

  return DateTime.now().toUtc().add(Duration(seconds: maxAge));
}

abstract class KeyStore<T> {
  final _keys = <String, T>{};

  /// The UTC time after which the public keys should be refreshed.
  DateTime? expiresAt;

  /// Whether this key store should be refreshed before it is used again.
  bool get isExpired {
    final expiresAt = this.expiresAt;
    return expiresAt == null || !DateTime.now().toUtc().isBefore(expiresAt);
  }

  List<String> get kids => _keys.keys.toList();
  List<T> get keys => _keys.values.toList();
  T? key(String kid) => _keys[kid];
}

class Pems extends KeyStore<Pem> {
  Pems.fromJson(String json) {
    final keysJson = jsonDecode(json) as Map<String, dynamic>;
    _keys.addEntries(
      keysJson.entries
          .map((entry) => MapEntry(entry.key, Pem(x509: entry.value as String)))
          .toList(),
    );
  }
}

class Pem {
  Pem({required this.x509});
  final String x509;
}

class Jwks extends KeyStore<Jwk> {
  Jwks.fromJson(String json) {
    final keysJson = jsonDecode(json)['keys'] as List<dynamic>;
    for (final keyJson in keysJson) {
      final key = Jwk.fromJson(keyJson as Map<String, dynamic>);
      _keys[key.kid] = key;
    }
  }
}

@JsonSerializable()
class Jwk {
  Jwk({
    required this.kid,
    required this.kty,
    required this.n,
    required this.e,
    required this.alg,
    required this.use,
  });
  factory Jwk.fromJson(Map<String, dynamic> json) => _$JwkFromJson(json);

  final String kid;
  final String kty;
  final String n;
  final String e;
  final String alg;
  final String use;
}

/// An exception thrown when public keys cannot be fetched or parsed.
class PublicKeysException implements Exception {
  /// Creates a [PublicKeysException].
  PublicKeysException(this.message);

  /// The exception message.
  final String message;
}
