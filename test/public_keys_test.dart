import 'dart:convert';

import 'package:cloud_frog/src/public_keys.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('firebasePublicKeys', () {
    test('sets the expiration from Cache-Control max-age', () async {
      final keys = await firebasePublicKeys(
        client: MockClient(
          (_) async => Response(
            jsonEncode({'test-key': _certificate}),
            200,
            headers: {'cache-control': 'public, max-age=3600'},
          ),
        ),
      );

      expect(keys.kids, ['test-key']);
      expect(keys.expiresAt, isNotNull);
      expect(keys.isExpired, false);
    });

    test('expires immediately when max-age is not provided', () async {
      final keys = await firebasePublicKeys(
        client: MockClient(
          (_) async => Response(jsonEncode({'test-key': _certificate}), 200),
        ),
      );

      expect(keys.expiresAt, isNull);
      expect(keys.isExpired, true);
    });

    test('throws on non-success responses', () async {
      expect(
        () => firebasePublicKeys(
          client: MockClient((_) async => Response('unavailable', 503)),
        ),
        throwsA(isA<PublicKeysException>()),
      );
    });

    test('throws on invalid responses', () async {
      expect(
        () => firebasePublicKeys(
          client: MockClient((_) async => Response('not-json', 200)),
        ),
        throwsA(isA<PublicKeysException>()),
      );
    });
  });

  group('gCloudPublicKeys', () {
    test('sets the expiration from Cache-Control max-age', () async {
      final keys = await gCloudPublicKeys(
        client: MockClient(
          (_) async => Response(
            '''
{
  "keys": [
    {
      "kid": "test-key",
      "kty": "RSA",
      "n": "modulus",
      "e": "AQAB",
      "alg": "RS256",
      "use": "sig"
    }
  ]
}
''',
            200,
            headers: {'cache-control': 'public; max-age=3600'},
          ),
        ),
      );

      expect(keys.kids, ['test-key']);
      expect(keys.expiresAt, isNotNull);
      expect(keys.isExpired, false);
    });
  });
}

const _certificate = '''
-----BEGIN CERTIFICATE-----
cert
-----END CERTIFICATE-----
''';
