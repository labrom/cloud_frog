import 'dart:io';

import 'package:cloud_frog/cloud_frog.dart';
import 'package:googleapis_auth/auth_io.dart';

/// Obtains a Google APIs client based on a service account.
/// 
/// [serviceAccountEmailEnv] and [serviceAccountIdEnv] are environment
/// variable names that hold respectively the service account's email
/// address and ID.
/// [serviceAccountKeySecretName] is the name of the service account's key
/// in the platform's secret manager.
Future<AuthClient> googleapisServiceAccountClient({
  required String serviceAccountEmailEnv,
  required String serviceAccountIdEnv,
  required String serviceAccountKeySecretName,
  required List<String> scopes,
}) async {
  final serviceAccountCredentials = ServiceAccountCredentials(
    Platform.environment[serviceAccountEmailEnv]!,
    ClientId(Platform.environment[serviceAccountIdEnv]!),
    (await secret(serviceAccountKeySecretName)).replaceAll(r'\n', '\n'),
  );

  return clientViaServiceAccount(
    serviceAccountCredentials,
    scopes,
  );
}
