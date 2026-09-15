/// The request's authenticated user.
class User {
  User({
    required this.subject,
    required this.email,
    required this.emailVerified,
    this.accountDisabled = false,
    this.identityProviders = const {},
    this.signInProvider,
  });

  /// The subject.
  ///
  /// This is the uid in the case of Firebase authentication.
  final String subject;

  /// The user email address.
  final String email;

  /// Whether the user email address is verified.
  final bool emailVerified;

  /// Whether the user account is disabled.
  final bool accountDisabled;

  /// Provider identifiers from the Firebase `identities` claim.
  ///
  /// Empty when the token does not contain Firebase identity information.
  final Set<String> identityProviders;

  /// The provider used for the current Firebase sign-in.
  final String? signInProvider;
}
