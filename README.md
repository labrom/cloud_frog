# Cloud Frog

A library to help build secure Google Cloud services using [Dart Frog](https://dartfrog.vgv.dev/).

[Dart Frog](https://dartfrog.vgv.dev/) is a simple-to-use framework to create servers in Dart and deploy them to Google Cloud Run (among other environments). In this scenario, Cloud Frog provides additional support to easily implement authentication and authorization for those services, at a more granular level than Google Cloud Run allows.

A further goal of Cloud Frog is to also support the other environments [supported by Dart Frog](https://dartfrog.vgv.dev/docs/category/deploy) in the future.

## Features

The main feature currently provided by Cloud Frog is a [Dart Frog middleware](https://dartfrog.vgv.dev/docs/basics/middleware) that can be used to restrict service invocation to only certain Cloud IAM service accounts, at the route level.

Google Cloud Run does offer access control over HTTPS by using IAM (see https://cloud.google.com/run/docs/authenticating/service-to-service), however in some scenarios it might be more convenient to implement this verification within your own service code.
Some of those scenarios include when your service has a combination of public and private routes, or when different service accounts should have access to different routes.retruned

Note that whenever access control is configured in Google Cloud Run and IAM, incoming requests are verified before your service code is invoked. Although it is technically possible to combine Google Cloud IAM and Cloud Frog access control, there isn't much benefit in doing so and it will probably increase complexity.

If you choose to stick with Google Cloud IAM, configuring access control boils down to the following steps:
- Set the service's *SECURITY/Authentication* to *Require authentication*
- Add the service account as a principal  in the service's *PERMISSIONS* panel (*ADD PRINCIPAL* button) and grant the *Cloud Run Invoker* role.

If you decide to use Cloud Frog access control instead, read below! Note that in both cases, requests are authenticated using the same underlying mechanism: OIDC (OpenID Connect) tokens.

Cloud Frog builds on top of [Dart Frog's authentication support](https://dartfrog.vgv.dev/docs/advanced/authentication#bearer-authentication) by parsing and verifying OIDC tokens included in the *Authorization* header using the *Bearer* scheme. If the token is valid and the account is authorized, the rest of the route handler is executed. If that isn't the case, HTTP code 401 (*unauthorized* - missing or invalid token) or 403 (*forbidden* - valid token but wrong user) is returned.

## Getting started

### Prerequisites

Follow [Dart Frog's Quick Start](https://dartfrog.vgv.dev/docs/overview#quick-start-) to set up a server if you don't already have one.

You will also need to have a Google Cloud project where your service will be deployed. In that project, create a service account in the IAM & Admin section, and make sure to give it the `Cloud Run Invoker` role.

Finally, install the [gcloud CLI](https://cloud.google.com/cli), this wil be needed to deploy the service.

### Import Cloud Frog

Add Cloud Frog as a dependency to your project's `pubspec.yaml` file.

```yaml
dependencies:
  cloud_frog: ^1.0.0
```

Run `pub get` to fetch `cloud_frog`.

### Add the Cloud Frog middleware

[Dart Frog middlewares](https://dartfrog.vgv.dev/docs/basics/middleware) are functions that are executed as part of the request processing logic for a given route. Middlewares can be added to either the top-level route or individual sub-routes. A middleware added to the top route is executed for all routes.

In order to authenticate requests for a given route, add the Cloud Frog middleware to the `_middleware.dart` file:
```dart
import 'dart:io';

import 'package:cloud_frog/cloud_frog.dart';
import 'package:dart_frog/dart_frog.dart';

Handler middleware(Handler handler) => handler
    .use(verifyServiceAccount(
        ['my-service-account@my-project-123456.iam.gserviceaccount.com'],
        issuer: issuerGoogle,
    ));
```

In the file above, the `verifyServiceAccount` middleware is configured with a single service account (`my-service-account@my-project.iam.gserviceaccount.com`) that is allowd to execute the route(s).
The `issuer` argument ensures that the token's issuer field will also be validated as Google accounts.

### Deploy the service

Follow [Dart Frog's Deployment instructions](https://dartfrog.vgv.dev/docs/deploy/google-cloud-run) to deploy your service to Google Cloud.

Note that the `--allow-unauthenticated` option that is used in the `gcloud` command instructs Cloud Run to allow any request. This means that authentication and authorization will be exclusively handled by the middleware you set up in your route(s).

## Usage

Configure and include the Cloud Frog middleware by invoking the `verifyServiceAccount` function:
```dart
import 'dart:io';

import 'package:cloud_frog/cloud_frog.dart';
import 'package:dart_frog/dart_frog.dart';

Handler middleware(Handler handler) => handler
    .use(verifyServiceAccount(
        [
            'my-service-account@my-project-123456.iam.gserviceaccount.com',
            'my-service-account@my-other-project-987654.iam.gserviceaccount.com',
        ],
        verifyAudience: true,
        issuer: issuerGoogle,
    ));
```

The first argument is a list of service accounts that are allowed to access the current route. These service accounts don't need to have any particular role (if you were still using the Google Cloud IAM access control, they would need to have the *Cloud Run Invoker* role).
Also note that these accounts don't necessarily have to be registered in the same project where your service is deployed. From the service perspective, they're just an email address associated with a token issuer (more on the issuer below).

The named argument `verifyAudience` indicates whether the token's `aud` field should be verified. Cloud Frog currently only supports verifying that the audience corresponds to the request URI. This argument is optional and defaults to `true`.

The named argument `issuer` represents the OIDC token issuer. It is optional, and no verification is performed if it isn't specified. Cloud Frog provides the `issuerGoogle` constant that represents Google accounts (*https://accounts.google.com*).

### Logging

The Cloud Frog middleware can optionally be configured with a logger. If the middleware can find an instance of [`RequestLogger`](https://pub.dev/documentation/dart_frog_request_logger/latest/dart_frog_request_logger/RequestLogger-class.html) from the [dart_frog_request_logger package](https://pub.dev/packages/dart_frog_request_logger) in the route's `Context`, it will use it and log messages that could prove useful when trying to authenticate a service account.

In order to make the logger available to the Cloud Frog middleware, add it as a dependency in the route's middleware:
```dart
import 'dart:io';

import 'package:cloud_frog/cloud_frog.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_request_logger/dart_frog_request_logger.dart';
import 'package:dart_frog_request_logger/log_formatters.dart';

Handler middleware(Handler handler) => handler
    .use(
        verifyServiceAccount(
            [
                'my-service-account@my-project-123456.iam.gserviceaccount.com',
                'my-service-account@my-other-project-987654.iam.gserviceaccount.com',
            ],
            verifyAudience: true,
            issuer: issuerGoogle,
        ),
    )
    .use(
      provider<Future<RequestLogger>>(
        (context) async => RequestLogger(
          headers: context.request.headers,
          logFormatter: formatCloudLoggingLog(projectId: await projectId),
        ),
      ),
    );
```
Note that `Future<RequestLogger>`, not `RequestLogger`, is provided in the context. This is needed because the `RequestLogger` constructor uses the `projectId` getter (courtesy of Cloud Frog) that is asynchronous. If the Google Cloud project ID was hard-coded, the `RequestLogger` instance could be returned directly:
```dart
    .use(
        provider<RequestLogger>(
            (context) => RequestLogger(
                headers: context.request.headers,
                logFormatter: formatCloudLoggingLog(projectId: 'my-project-123456'),
            ),
        ),
    )
```