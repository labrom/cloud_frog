import 'dart:convert';

import 'package:http/http.dart';
import 'package:json_annotation/json_annotation.dart';

part 'gcloud_keys.g.dart';

Future<Jwks> gCloudPublicKeys() async => Jwks.fromJson(
      (await get(
        Uri.parse(
          'https://www.googleapis.com/oauth2/v3/certs',
        ),
      ))
          .body,
    );

class Jwks {
  final _keys = <String, Jwk>{};

  Jwks.fromJson(String json) {
    final keysJson = jsonDecode(json)['keys'] as List<dynamic>;
    for (final keyJson in keysJson) {
      final key = Jwk.fromJson(keyJson as Map<String, dynamic>);
      _keys[key.kid] = key;
    }
  }

  List<String> get kids => _keys.keys.toList();
  List<Jwk> get keys => _keys.values.toList();
  Jwk? key(String kid) => _keys[kid];
}

@JsonSerializable()
class Jwk {
  factory Jwk.fromJson(Map<String, dynamic> json) => _$JwkFromJson(json);
  Jwk({
    required this.kid,
    required this.kty,
    required this.n,
    required this.e,
    required this.alg,
    required this.use,
  });

  final String kid;
  final String kty;
  final String n;
  final String e;
  final String alg;
  final String use;
}
