import 'dart:convert';

import 'package:cloud_frog/cloud_frog.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:firebase_admin_sdk/app_check.dart';
import 'package:test/test.dart';

class TestContext implements RequestContext {
  TestContext(this.request, [this.values = const {}]);
  @override
  final Request request;
  final Map<Type, Object?> values;
  @override
  T read<T>() => values[T] as T;
  @override
  RequestContext provide<T>(T Function() create) =>
      TestContext(request, {...values, T: create()});
  @override
  Map<String, String> get mountedParams => const {};
}

RequestContext context({String? token, String method = 'GET'}) => TestContext(
  Request(
    method,
    Uri.parse('http://localhost/private'),
    headers: token == null ? {} : {'X-Firebase-AppCheck': token},
  ),
);

void main() {
  late AppCheckVerifier verifier;
  late int calls;
  late List<AppCheckResult> observed;
  setUp(() {
    calls = 0;
    observed = [];
    verifier = AppCheckVerifier(
      projectNumber: '123',
      clock: () => DateTime.fromMillisecondsSinceEpoch(1000000),
      verifyToken: (token) async {
        calls++;
        if (token == 'invalid') {
          throw FirebaseAppCheckException(AppCheckErrorCode.invalidArgument);
        }
        if (token == 'unavailable') {
          throw StateError('private exception details');
        }
        return DecodedAppCheckToken.fromMap({
          'iss': 'https://firebaseappcheck.googleapis.com/123',
          'aud': ['projects/123'],
          'sub': 'app',
          'iat': 900,
          'exp': 1100,
        });
      },
    );
  });
  for (final token in [null, 'invalid', 'unavailable', 'valid']) {
    for (final enforce in [true, false]) {
      test('$token with enforce=$enforce', () async {
        var handled = false;
        final middleware = checkFirebaseAppCheck(
          verifier: verifier,
          enforce: enforce,
          onVerification: (ctx, result) async {
            expect(ctx.read<AppCheckResult>(), same(result));
            observed.add(result);
          },
        );
        final handler = middleware((ctx) {
          handled = true;
          expect(ctx.read<AppCheckResult>(), same(observed.single));
          return Response(statusCode: 204);
        });
        final response = await handler(context(token: token));
        final allowed = !enforce || token == 'valid';
        expect(handled, allowed);
        expect(observed, hasLength(1));
        expect(calls, token == null ? 0 : 1);
        expect(
          response.statusCode,
          allowed
              ? 204
              : token == 'unavailable'
              ? 503
              : 403,
        );
        if (!allowed) {
          final body = await response.body();
          expect(
            (jsonDecode(body) as Map<String, dynamic>)['code'],
            token == 'unavailable'
                ? 'app_check_unavailable'
                : 'app_check_failed',
          );
          expect(body, isNot(contains('private exception details')));
        }
      });
    }
  }
  test('supports custom rejection response after observation', () async {
    final handler = checkFirebaseAppCheck(
      verifier: verifier,
      onVerification: (_, result) => observed.add(result),
      onRejected: (ctx, result) async {
        expect(observed.single, same(result));
        expect(ctx.read<AppCheckResult>(), same(result));
        return Response(statusCode: 401, body: 'Custom rejection');
      },
    )((_) => throw StateError('must not run'));
    final response = await handler(context());
    expect(response.statusCode, 401);
    expect(await response.body(), 'Custom rejection');
  });
  test('monitoring does not call rejection callback', () async {
    final handler = checkFirebaseAppCheck(
      verifier: verifier,
      enforce: false,
      onRejected: (_, _) => throw StateError('must not run'),
    )((_) => Response(statusCode: 204));
    expect((await handler(context())).statusCode, 204);
  });
  for (final bypass in [true, false]) {
    test('OPTIONS bypass=$bypass', () async {
      final handler = checkFirebaseAppCheck(
        verifier: verifier,
        bypassOptions: bypass,
        onVerification: (_, result) => observed.add(result),
      )((_) => Response(statusCode: 204));
      final response = await handler(
        context(token: 'invalid', method: 'OPTIONS'),
      );
      expect(response.statusCode, bypass ? 204 : 403);
      expect(calls, bypass ? 0 : 1);
      expect(observed.length, bypass ? 0 : 1);
    });
  }
  test('observer errors do not allow protected handler to execute', () async {
    final handler = checkFirebaseAppCheck(
      verifier: verifier,
      onVerification: (_, _) => throw StateError('logger failure'),
    )((_) => throw ArgumentError('must not run'));
    await expectLater(handler(context(token: 'valid')), throwsStateError);
  });
}
