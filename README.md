# Cloud Frog

A library to help build secure Google Cloud services using [Dart Frog](https://dartfrog.vgv.dev/).

[Dart Frog](https://dartfrog.vgv.dev/) is a simple-to-use framework to create servers in Dart and deploy them to Google Cloud Run (among other environments). In this scenario, Cloud Frog provides additional support to easily implement authentication and authorization for those services, at a more granular level than Google Cloud Run allows.

A further goal of Cloud Frog is to also support the other environments [supported by Dart Frog](https://dartfrog.vgv.dev/docs/category/deploy) in the future.

## Features

Cloud Frog currently provides with route-level access control in two distinct scenarios:
1. service-to-service authentication
1. end-user authentication using Firebase

### Service-to-service authentication

Service-to-service authentication is provided by Cloud Frog in the form of a [Dart Frog middleware](https://dartfrog.vgv.dev/docs/basics/middleware) that can be used to restrict service invocation to only certain Cloud IAM service accounts, at the route level.

Google Cloud Run does offer access control over HTTPS by using IAM (see https://cloud.google.com/run/docs/authenticating/service-to-service), however in some scenarios it might be more convenient to implement this verification within your own service code.
Some of those scenarios include when your service has a combination of public and private routes, or when different service accounts should have access to different routes.

Note that whenever access control is configured in Google Cloud Run and IAM, incoming requests are verified before your service code is invoked. Although it is technically possible to combine Google Cloud IAM and Cloud Frog access control, there isn't much benefit in doing so and it will probably increase complexity.

If you choose to stick with Google Cloud IAM, configuring access control boils down to the following steps:
- Set the service's *SECURITY/Authentication* to *Require authentication*
- Add the service account as a principal  in the service's *PERMISSIONS* panel (*ADD PRINCIPAL* button) and grant the *Cloud Run Invoker* role.

If you decide to use Cloud Frog access control instead, keep reading! Note that in both cases, requests are authenticated using the same underlying mechanism: OIDC (OpenID Connect) tokens.

Cloud Frog builds on top of [Dart Frog's authentication support](https://dartfrog.vgv.dev/docs/advanced/authentication#bearer-authentication) by parsing and verifying OIDC tokens included in the *Authorization* header using the *Bearer* scheme. If the token is valid and the account is authorized, the remainder of the route handler is executed. If that isn't the case, HTTP code 401 (*unauthorized* - missing or invalid token) or 403 (*forbidden* - valid token but wrong user) is returned.

### End-user authentication using Firebase

End-user authentication using Firebase is also provided by Cloud Frog in the form of a [Dart Frog middleware](https://dartfrog.vgv.dev/docs/basics/middleware) that can be used to extract the signed-in Firebase user for a particular route.

Unlike the service-to-service scenario, this middleware doesn't handle restricting access to specific users, but it does ensure that the request is authenticated, and will place the extracted user information into the request context for further use.

Similarly to the service-to-service scenario, this middleware workds with OIDC (OpenID Connect) tokens, the ones that are issued by Firebase Auth in this case.

## Getting started

### Prerequisites

Follow [Dart Frog's Quick Start](https://dartfrog.vgv.dev/docs/overview#quick-start-) to set up a server if you don't already have one.

You will also need to have a Google Cloud project where your service will be deployed. In that project, create a service account in the IAM & Admin section, and make sure to give it the `Cloud Run Invoker` role.

Finally, install the [gcloud CLI](https://cloud.google.com/cli), this wil be needed to deploy the service.

### Import Cloud Frog

Add Cloud Frog as a dependency to your project's `pubspec.yaml` file.

```yaml
dependencies:
  cloud_frog: ^1.1.0
```

Run `pub get` to fetch `cloud_frog`.

### Add the Cloud Frog middleware

[Dart Frog middlewares](https://dartfrog.vgv.dev/docs/basics/middleware) are functions that are executed as part of the request processing logic for a given route. Middlewares can be added to either the top-level route or individual sub-routes. A middleware added to the top route is executed for all routes.

#### Service-to-service authentication
In order to authenticate service-to-service requests for a given route, add the Cloud Frog middleware to the `_middleware.dart` file:
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

#### End-user authentication using Firebase
Similarly, in order to authenticate Firebase end-user requests for a given route, add the Cloud Frog middleware to the `_middleware.dart` file:
```dart
import 'dart:io';

import 'package:cloud_frog/cloud_frog.dart';
import 'package:dart_frog/dart_frog.dart';

Handler middleware(Handler handler) => handler
    .use(authenticateFirebaseUser);
```

In the file above, the `authenticateFirebaseUser` middleware will ensure that requests for this route are authenticated with a Firebase user . For every request, once this verification is done, the corresponding `User` object is placed in the request context for further use.

The request handler implementation can then access the 'User' object in the request context for authorization and/or personalized logic purposes:
```dart
const allowedEmails = [...];

Response onRequest(RequestContext context) {
  final user = context.read<User>();
  if (!user.emailVerified || !allowedEmails.contains(user.email)) {
    return Response(statusCode: HttpStatus.forbidden);
  }

  // Do something with the user here

  return Response(body: 'Welcome ${user.email}');
}
```

User authorization can alternatively be handled in a downstream middleware, using either your own implementation or the built-in [verifyContextUser] middleware:
```dart
const allowedEmails = [...];

Handler middleware(Handler handler) {
  return handler
      .use(
        verifyContextUser(allowedEmails),
      )
      .use(
        authenticateFirebaseUser,
      );
}
```

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