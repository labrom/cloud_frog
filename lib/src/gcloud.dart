import 'dart:io';

import 'package:googleapis/secretmanager/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart';

/// Retrieves a secret from Google Cloud Secret Manager.
///
/// If the secret is exposed in an environment variable with the same name,
/// the secret value is directly returned from there. If not, this function
/// queries Secret Manager.
Future<String> secret(String name) async {
  final envSecret = Platform.environment[name];
  if (envSecret != null) {
    return envSecret;
  }

  final client = await clientViaMetadataServer();

  final secretManagerApi = SecretManagerApi(client);
  final secretPath =
      'projects/${await projectId}/secrets/$name/versions/latest';

  final response =
      await secretManagerApi.projects.secrets.versions.access(secretPath);
  return response.payload!.data!;
}

/// Gets the current project's ID.
///
/// Retrieves the project ID from the Google Cloud Metadata service.
Future<String> get projectId async => (await get(
      Uri.parse(
        'http://metadata.google.internal/computeMetadata/v1/project/project-id',
      ),
      headers: {'Metadata-Flavor': 'Google'},
    ))
        .body;
