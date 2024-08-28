import 'dart:io';

import 'package:googleapis/secretmanager/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart';

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

Future<String> get projectId async => (await get(
      Uri.parse(
        'http://metadata.google.internal/computeMetadata/v1/project/project-id',
      ),
      headers: {'Metadata-Flavor': 'Google'},
    ))
        .body;
