import 'dart:io';

import 'package:cloud_frog/cloud_frog.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:test/test.dart';

void main() {
  group('verifyContextUser', () {
    test('allows enabled users with a verified allowed email', () async {
      final response =
          await verifyContextUser(['user@example.com'])((_) => Response())(
            _RequestContext(
              User(
                subject: 'user-123',
                email: 'user@example.com',
                emailVerified: true,
              ),
            ),
          );

      expect(response.statusCode, HttpStatus.ok);
    });

    test('rejects disabled users', () async {
      final response =
          await verifyContextUser(['user@example.com'])((_) => Response())(
            _RequestContext(
              User(
                subject: 'user-123',
                email: 'user@example.com',
                emailVerified: true,
                accountDisabled: true,
              ),
            ),
          );

      expect(response.statusCode, HttpStatus.forbidden);
    });
  });
}

class _RequestContext implements RequestContext {
  _RequestContext(this._user);

  final User _user;

  @override
  Map<String, String> get mountedParams => const {};

  @override
  RequestContext provide<T extends Object?>(T Function() create) {
    throw UnimplementedError();
  }

  @override
  T read<T>() {
    if (T == User) {
      return _user as T;
    }
    throw StateError('No value provided for $T');
  }

  @override
  Request get request => throw UnimplementedError();
}
