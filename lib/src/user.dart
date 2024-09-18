/// The request's authenticated user.
class User {
  User({
    required this.subject,
    required this.email,
    required this.emailVerified,
  });

  /// The subject.
  ///
  /// This is the uid in the case of Firebase authentication.
  final String subject;

  /// The user email address.
  final String email;

  /// Whether the user email address is verified.
  final bool emailVerified;
}
