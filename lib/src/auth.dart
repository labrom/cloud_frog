import 'dart:io';

import 'package:cloud_frog/src/dart_frog.dart';
import 'package:cloud_frog/src/gcloud_keys.dart';
import 'package:cloud_frog/src/oidc_token.dart';
import 'package:cloud_frog/src/user.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_auth/dart_frog_auth.dart';
import 'package:dart_frog_request_logger/dart_frog_request_logger.dart';

const issuerGoogle = 'https://accounts.google.com';

Middleware verifyServiceAccount(
  List<String> allowedEmails, {
  bool verifyAudience = true,
  String? issuer,
}) =>
    (handler) => handler
        .use(verifyContextUser(allowedEmails))
        .use(
          validateToken(
            verifyAudience: verifyAudience,
            issuer: issuer,
          ),
        )
        .use(gCloudPublicKeysProvider);

Middleware verifyContextUser(List<String> allowedEmails) => (handler) {
      return (context) {
        final user = context.read<User>();
        if (!user.emailVerified || !allowedEmails.contains(user.email)) {
          return Response(statusCode: HttpStatus.forbidden);
        }
        return handler(context);
      };
    };

Middleware validateToken({
  required bool verifyAudience,
  String? issuer,
}) =>
    bearerAuthentication<User>(
      authenticator: (context, token) async {
        final logger = await context.readOptional<Future<RequestLogger>>();
        final oidcToken = OIDCToken(token: token);

        final jwks = await context.read<Future<Jwks>>();
        try {
          oidcToken.verify(
            jwks,
            audience: verifyAudience ? context.request.uri.toString() : null,
            issuer: issuer,
          );
          return Future.value(oidcToken.user);
        } on TokenVerificationException catch (e) {
          logger?.alert('Invalid token: ${e.message}');
          return Future.value();
        }
      },
    );

final gCloudPublicKeysProvider = provider<Future<Jwks>>(
  (context) async => _gCloudPublicKeys ??= gCloudPublicKeys(),
);

Future<Jwks>? _gCloudPublicKeys;
