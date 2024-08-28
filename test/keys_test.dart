import 'package:cloud_frog/src/keys.dart';
import 'package:test/test.dart';

void main() {
  final expectedKey = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAonV5tzUbqyPfkM6MwUqC
trqun9x20hEUbIUlmAYYuPuMhsaNHJqs1AVzRt2TzaNjmPVddEbU7VMDmeFWUt7v
gDi7Xu0leevuIN4VSPbAMGBa0oj9Qopqkn9ePO/7DvIN13ktHgfQqatNBu6uXH6z
kUl3VtXnubXrUhx7uyF22dARDc1+pJoj2NnsvgxDRElPMyDkU+siVv3c6cgIEwLE
ZZPWOcwplPTUB4qeTK6prrPBGQshuE1PWK2ZrYpIvXfzHyEbkGdPnrhcxgCzbKBU
Fvr8n/sfSurLRoDBLjkURKmgB8T8iRzLyXsCu9D3Hw61LKuex1aeSQLdwOFLuUEB
dwIDAQAB
-----END PUBLIC KEY-----
''';
  group('JWK to PEM conversion for an RSA public key', () {
    test('using the values from the JWK', () {
      final publicKey = rsaPublicKeyFromJwk(
        e: 'AQAB',
        n: 'onV5tzUbqyPfkM6MwUqCtrqun9x20hEUbIUlmAYYuPuMhsaNHJqs1AVzRt2TzaNjmPVddEbU7VMDmeFWUt7vgDi7Xu0leevuIN4VSPbAMGBa0oj9Qopqkn9ePO_7DvIN13ktHgfQqatNBu6uXH6zkUl3VtXnubXrUhx7uyF22dARDc1-pJoj2NnsvgxDRElPMyDkU-siVv3c6cgIEwLEZZPWOcwplPTUB4qeTK6prrPBGQshuE1PWK2ZrYpIvXfzHyEbkGdPnrhcxgCzbKBUFvr8n_sfSurLRoDBLjkURKmgB8T8iRzLyXsCu9D3Hw61LKuex1aeSQLdwOFLuUEBdw',
      );

      expect(publicKey, expectedKey);
    });
    test('rebuilding the key using ASN1', () {
      final publicKey = rsaPublicKeyFromJwkUsingASN1(
        e: 'AQAB',
        n: 'onV5tzUbqyPfkM6MwUqCtrqun9x20hEUbIUlmAYYuPuMhsaNHJqs1AVzRt2TzaNjmPVddEbU7VMDmeFWUt7vgDi7Xu0leevuIN4VSPbAMGBa0oj9Qopqkn9ePO_7DvIN13ktHgfQqatNBu6uXH6zkUl3VtXnubXrUhx7uyF22dARDc1-pJoj2NnsvgxDRElPMyDkU-siVv3c6cgIEwLEZZPWOcwplPTUB4qeTK6prrPBGQshuE1PWK2ZrYpIvXfzHyEbkGdPnrhcxgCzbKBUFvr8n_sfSurLRoDBLjkURKmgB8T8iRzLyXsCu9D3Hw61LKuex1aeSQLdwOFLuUEBdw',
      );

      expect(publicKey, expectedKey);
    });
  });
}
