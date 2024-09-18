import 'dart:convert';

import 'package:http/http.dart';
import 'package:json_annotation/json_annotation.dart';

part 'public_keys.g.dart';

Future<Jwks> gCloudPublicKeys() async => Jwks.fromJson(
      (await get(
        Uri.parse(
          'https://www.googleapis.com/oauth2/v3/certs',
        ),
      ))
          .body,
    );

Future<Pems> firebasePublicKeys() async => Pems.fromJson(
      (await get(
        Uri.parse(
          'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com',
        ),
      ))
          .body,
    );

abstract class KeyStore<T> {
  final _keys = <String, T>{};

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
