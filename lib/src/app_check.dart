import 'dart:async';

import 'package:dart_frog/dart_frog.dart';

import 'package:gcputil/app_check.dart';

/// Header carrying the Firebase App Check token.
const firebaseAppCheckHeader = 'x-firebase-appcheck';

/// Checks App Check before invoking the handler. In monitoring mode all
/// requests proceed, but verification and [onVerification] still run.
///
/// Results are provided in the request context, including to both callbacks.
/// OPTIONS bypasses verification by default; the app must handle CORS itself.
Middleware checkFirebaseAppCheck({
  required AppCheckVerifier verifier,
  bool enforce = true,
  bool bypassOptions = true,
  FutureOr<void> Function(RequestContext, AppCheckResult)? onVerification,
  FutureOr<Response> Function(RequestContext, AppCheckResult)? onRejected,
}) =>
    (handler) => (context) async {
      if (bypassOptions && context.request.method == HttpMethod.options) {
        return handler(context);
      }
      final result = await verifier.verify(
        context.request.headers[firebaseAppCheckHeader],
      );
      final verifiedContext = context.provide<AppCheckResult>(() => result);
      if (onVerification != null) {
        await onVerification(verifiedContext, result);
      }
      if (enforce && !result.isValid) {
        if (onRejected != null) {
          return onRejected(verifiedContext, result);
        }
        final unavailable = result.status == AppCheckStatus.unavailable;
        return Response.json(
          statusCode: unavailable ? 503 : 403,
          body: {
            'code': unavailable ? 'app_check_unavailable' : 'app_check_failed',
            'error': unavailable
                ? 'App Check verification is unavailable'
                : 'A valid Firebase App Check token is required',
          },
        );
      }
      return handler(verifiedContext);
    };
