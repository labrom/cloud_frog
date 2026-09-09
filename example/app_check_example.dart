import 'package:cloud_frog/cloud_frog.dart';
import 'package:dart_frog/dart_frog.dart';

/// Mount on protected routes after initializing the application-owned verifier.
Middleware appCheckMiddleware({
  required AppCheckVerifier verifier,
  bool enforce = true,
}) => checkFirebaseAppCheck(
  verifier: verifier,
  enforce: enforce,
  onVerification: (context, result) {
    // Record result.status and result.appId with your request logger.
  },
  onRejected: (context, result) => Response.json(
    statusCode: result.status == AppCheckStatus.unavailable ? 503 : 403,
    body: {
      'code': result.status == AppCheckStatus.unavailable
          ? 'app_check_unavailable'
          : 'app_check_failed',
    },
  ),
);
