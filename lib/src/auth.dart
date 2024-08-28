import 'dart:io';

import 'package:cloud_frog/src/dart_frog.dart';
import 'package:cloud_frog/src/oidc_token.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_auth/dart_frog_auth.dart';
import 'package:dart_frog_request_logger/dart_frog_request_logger.dart';

import 'gcloud_keys.dart';
import 'user.dart';

Middleware verifyServiceAccount(
  List<String> allowedEmails, {
  bool verifyAudience = true,
  bool verifyIssuer = true,
}) =>
    (handler) => handler
        .use(verifyContextUser(allowedEmails))
        .use(
          validateToken(
            verifyAudience: verifyAudience,
            verifyIssuer: verifyIssuer,
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
  required bool verifyIssuer,
}) =>
    bearerAuthentication<User>(
      authenticator: (context, token) async {
        final logger = await context.readOptional<Future<RequestLogger>>();
        final oidcToken = OIDCToken(token: token);

        if (verifyAudience &&
            !oidcToken.hasAudience(context.request.uri.toString())) {
          logger?.alert("Invalid token audience: should be the request's URI");
          return Future.value();
        }
        if (verifyIssuer && oidcToken.issuer != 'https://accounts.google.com') {
          logger?.alert(
              'Invalid token issuer: should be https://accounts.google.com');
          return Future.value();
        }

        final jwks = await context.read<Future<Jwks>>();
        try {
          oidcToken.verify(jwks);
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
