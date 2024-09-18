// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_keys.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Jwk _$JwkFromJson(Map<String, dynamic> json) => Jwk(
      kid: json['kid'] as String,
      kty: json['kty'] as String,
      n: json['n'] as String,
      e: json['e'] as String,
      alg: json['alg'] as String,
      use: json['use'] as String,
    );

Map<String, dynamic> _$JwkToJson(Jwk instance) => <String, dynamic>{
      'kid': instance.kid,
      'kty': instance.kty,
      'n': instance.n,
      'e': instance.e,
      'alg': instance.alg,
      'use': instance.use,
    };
