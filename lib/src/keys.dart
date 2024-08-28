import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';

String rsaPublicKeyFromJwk({required String e, required String n}) {
  final formatted = '${n}ID$e'.replaceAll('-', '+').replaceAll('_', '/');
  final body = 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA$formatted';
  return '-----BEGIN PUBLIC KEY-----\n${_blockify(body)}-----END PUBLIC KEY-----\n';
}

String rsaPublicKeyFromJwkUsingASN1({required String e, required String n}) {
  final asn = ASN1Sequence();

  final algorithm = ASN1Sequence()
    ..add(ASN1ObjectIdentifier([1, 2, 840, 113549, 1, 1, 1]))
    ..add(ASN1Null());
  asn.add(algorithm);

  final nBytes = base64Url.decode(base64Url.normalize(n));
  final eBytes = base64Url.decode(base64Url.normalize(e));
  final rsaKey = ASN1Sequence()
    ..add(_asn1Integer(nBytes))
    ..add(_asn1Integer(eBytes));
  final keyBytes = rsaKey.encodedBytes;
  asn.add(ASN1BitString(keyBytes));

  final body = base64Encode(asn.encodedBytes);
  return '-----BEGIN PUBLIC KEY-----\n${_blockify(body)}-----END PUBLIC KEY-----\n';
}

String _blockify(String value) {
  final buffer = StringBuffer();
  for (var i = 0; i < value.length; i += 64) {
    buffer
      ..write(value.substring(i, min(value.length, i + 64)))
      ..writeln();
  }
  return buffer.toString();
}

ASN1Integer _asn1Integer(Uint8List bytes) {
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = (value << 8) | BigInt.from(byte);
  }
  return ASN1Integer(value);
}
