import 'dart:io';

import 'package:cloud_frog/cloud_frog.dart';
import 'package:cloud_frog/src/dart_frog.dart';
import 'package:cloud_frog/src/oidc_token.dart';
import 'package:cloud_frog/src/public_keys.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_auth/dart_frog_auth.dart';
import 'package:dart_frog_request_logger/dart_frog_request_logger.dart';

/// The Google Accounts OIDC issuer.
///
/// Value: https://accounts.google.com
const issuerGoogle = 'https://accounts.google.com';

/// The Firebase token issuer prefix.
///
/// Value: https://securetoken.google.com/
const issuerFirebasePrefix = 'https://securetoken.google.com/';

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
///
/// If the correct service account cannot be verified, this middleware will
/// return either an HTTP 401 (Unauthorized) or 403 (Forbidden) response code.
Middleware verifyServiceAccount(
  List<String> allowedEmails, {
  bool verifyAudience = true,
  String? issuer,
}) {
  return (handler) {
    return handler
        .use(
          verifyContextUser(allowedEmails),
        )
        .use(
          validateToken(
            verifyAudience: verifyAudience,
            issuer: issuer,
          ),
        )
        .use(gCloudPublicKeysProvider);
  };
}

/// A Dart Frog middleware that verifies that the current route is invoked by
/// a signed-in Firebase user.
///
/// The extracted user information is placed in a [User] instance in the
/// context.
/// If no user is properly authenticated, this middleware will return an HTTP
/// 401 (Unauthorized) response code.
/// This middleware only verifies that requests are authenticated with a
/// Firebase user, it doesn't verify the identity of that user.
/// If you need to restrict the route to a specific set of users or if you need
/// to provide custom logic for different users, you'll need to do it either in
/// the request handler or in a downstream middleware.
///
/// For example, authorizing the user in the request handler would look like
/// this:
/// ```dart
/// const allowedEmails = [...];
///
/// Response onRequest(RequestContext context) {
///   final user = context.read<User>();
///   if (!user.emailVerified || !allowedEmails.contains(user.email)) {
///     return Response(statusCode: HttpStatus.forbidden);
///   }
///   return Response(body: 'Welcome ${user.email}');
/// }
/// ```
///
/// In order to authorize the user in a downstream middleware, you can either
/// implement your own middleware that would get the [User] object from the
/// [RequestContext], or insert [verifyContextUser] directly in the middleware
/// chain, which would look like this:
/// ```dart
/// const allowedEmails = [...];
///
/// Handler middleware(Handler handler) {
///   return handler
///       .use(
///         verifyContextUser(allowedEmails),
///       )
///       .use(
///         authenticateFirebaseUser,
///       );
/// }
/// ```
Middleware get authenticateFirebaseUser {
  return (Handler handler) {
    return handler
        .use(
          validateFirebaseToken(),
        )
        .use(projectProvider)
        .use(firebasePublicKeysProvider);
  };
}

/// A middleware that checks that the user present in the request context is
/// authorized.
///
/// This middleware expects to find a [User] instance in the request context and
/// verifies its email address and also that the email address was verified by
/// the OIDC provider.
/// This middleware can be used downstream of [authenticateFirebaseUser],
/// however don't add it downstream of [verifyServiceAccount], because it
/// already includes it.
Middleware verifyContextUser(List<String> allowedEmails) {
  return (handler) {
    return (context) {
      final user = context.read<User>();
      if (!user.emailVerified || !allowedEmails.contains(user.email)) {
        return Response(statusCode: HttpStatus.forbidden);
      }
      return handler(context);
    };
  };
}

/// A middleware that validates the signature and contents of the request
/// token for a Google Cloud service account.
///
/// This middleware builds on top of Dart Frog's [bearerAuthentication]
/// middleware and provides with token parsing and verification.
/// It expects to find public keys in the request context and uses them to
/// verify the token signature.
/// Don't use this middleware directly but instead use [verifyServiceAccount].
Middleware validateToken({
  required bool verifyAudience,
  String? issuer,
}) {
  return (handler) {
    return (context) async {
      return handler.use(
        _validateToken<Jwk>(
          audience: verifyAudience ? context.request.uri.toString() : null,
          issuer: issuer,
        ),
      )(context);
    };
  };
}

/// A middleware that validates the signature and contents of the request
/// token for a Firebase end user.
///
/// This middleware builds on top of Dart Frog's [bearerAuthentication]
/// middleware and provides with token parsing and verification.
/// It expects to find public keys in the request context and uses them to
/// verify the token signature.
/// Don't use this middleware directly but instead use
/// [authenticateFirebaseUser].
Middleware validateFirebaseToken() {
  return (handler) {
    return (context) async {
      final projectId = await context.read<Future<Project>>();
      return handler.use(
        _validateToken<Pem>(
          audience: projectId.id,
          issuer: issuerFirebasePrefix + projectId.id,
        ),
      )(context);
    };
  };
}

Middleware _validateToken<T>({
  String? audience,
  String? issuer,
}) {
  return bearerAuthentication<User>(
    authenticator: (context, token) async {
      final logger = await context.readOptional<Future<RequestLogger>>();
      final oidcToken = OIDCToken(token: token);

      final keyStore = await context.read<Future<KeyStore<T>>>();
      try {
        oidcToken.verify(
          keyStore,
          audience: audience,
          issuer: issuer,
        );
        return Future.value(oidcToken.user);
      } on TokenVerificationException catch (e) {
        logger?.alert('Invalid token: ${e.message}');
        return Future.value();
      }
    },
  );
}

/// A provider of Google Cloud API public keys.
final gCloudPublicKeysProvider = provider<Future<KeyStore<Jwk>>>(
  (context) async => _gCloudPublicKeys ??= gCloudPublicKeys(),
);

/// A provider of Firebase authentication public keys.
final firebasePublicKeysProvider = provider<Future<KeyStore<Pem>>>(
  (context) async => _firebasePublicKeys ??= firebasePublicKeys(),
);

Future<Jwks>? _gCloudPublicKeys;
Future<Pems>? _firebasePublicKeys;

/// A provider of the current Google Cloud project.
final projectProvider = provider<Future<Project>>(
  (context) async => _project ??= projectId.then(Project.new),
);

Future<Project>? _project;
