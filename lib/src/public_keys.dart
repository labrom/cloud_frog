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

class Jwks {
  Jwks.fromJson(String json) {
    final keysJson = jsonDecode(json)['keys'] as List<dynamic>;
    for (final keyJson in keysJson) {
      final key = Jwk.fromJson(keyJson as Map<String, dynamic>);
      _keys[key.kid] = key;
    }
  }
  final _keys = <String, Jwk>{};

  List<String> get kids => _keys.keys.toList();
  List<Jwk> get keys => _keys.values.toList();
  Jwk? key(String kid) => _keys[kid];
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
