## 1.4.1

- Update the `gcputil` dependency constraint to `^0.3.0`.

## 1.4.0

- Add account disabled information to `User` and reject disabled users in
  `verifyContextUser`.

## 1.3.4

- Update the `gcputil` dependency constraint to `^0.2.0`.
- Raise the minimum Dart SDK constraint to `^3.9.0`.

## 1.3.3

- Harden Firebase ID token validation by rejecting malformed tokens, invalid
  user claims, missing key IDs, non-RS256 algorithms, invalid subjects, and
  future `auth_time` values.
- Refresh Google and Firebase public keys according to `Cache-Control`
  `max-age` values, avoid caching failed fetches, and report public-key fetch
  failures as authentication failures.
- Add unit tests for Firebase token validation and public-key fetching.
- Update the `dart_jsonwebtoken` dependency constraint to `^3.4.1`.

## 1.3.2

- Move Google Cloud utility implementations to the `gcputil` package and
  re-export them for compatibility.

## 1.3.1

- Update googleapis dependency to support version 16.

## 1.3.0

- Add DateTimeService (using the timezone package) to work with local times.

## 1.2.5

- Downgrade json_serializable to avoid analyzer 9.0.0 constraint.

## 1.2.4

- Update most dependencies.

## 1.2.3

- Fix a bug where Google Cloud secret values were returned Base64-encoded.

## 1.2.2

- Update asn1lib dependency.

## 1.2.1

- Update dart_jsonwebtoken dependency.

## 1.2.0

- Introduce support for Google APIs clients.

## 1.1.0

- Introduce support for Firebase end-user authentication.

## 1.0.3

- Fixed README.
- No code change.

## 1.0.2

- Fixed README.
- Some refactoring, no public API change.

## 1.0.1

- Added API documentation.
- No code change.

## 1.0.0

- Initial version.
