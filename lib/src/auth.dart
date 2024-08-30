import 'dart:io';

import 'package:cloud_frog/src/dart_frog.dart';
import 'package:cloud_frog/src/gcloud_keys.dart';
import 'package:cloud_frog/src/oidc_token.dart';
import 'package:cloud_frog/src/user.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_auth/dart_frog_auth.dart';
import 'package:dart_frog_request_logger/dart_frog_request_logger.dart';

/// The Google Accounts OIDC issuer.
///
/// Value: https://accounts.google.com
const issuerGoogle = 'https://accounts.google.com';

/// A Dart Frog middleware that verifies that the current route is invoked by
/// an authorized service account.
///
/// The [allowedEmails] parameter is a list of service account emails that are
/// allowed to invoke this route.
/// The optional [verifyAudience] parameter specifies whether the token's
/// audience (aud field) should be verified. This parameter defaults to true.
/// The audience must be set to the route's URL.
/// The optional [issuer] parameter represents the aauthorized OIDC issuer. Use
/// [issuerGoogle] to verify Google Cloud IAM service accounts.
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

/// A middleware that checks that the user present in the request context is
/// authorized.
///
/// This middleware expects to find a [User] instance in the request context and
/// verifies its email address and also that the email address was verified by
/// the OIDC provider.
/// Don't use this middleware directly but instead use [verifyServiceAccount].
Middleware verifyContextUser(List<String> allowedEmails) => (handler) {
      return (context) {
        final user = context.read<User>();
        if (!user.emailVerified || !allowedEmails.contains(user.email)) {
          return Response(statusCode: HttpStatus.forbidden);
        }
        return handler(context);
      };
    };

/// A middleware that validates the signature and contents of the request
/// token.
///
/// This middleware builds on top of Dart Frog's [bearerAuthentication]
/// middleware and provides with token parsing and verification.
/// It expects to find public keys in the request context and uses them to
/// verify the token signature.
/// Don't use this middleware directly but instead use [verifyServiceAccount].
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

/// A provider of Google Cloud API public keys.
final gCloudPublicKeysProvider = provider<Future<Jwks>>(
  (context) async => _gCloudPublicKeys ??= gCloudPublicKeys(),
);

Future<Jwks>? _gCloudPublicKeys;
