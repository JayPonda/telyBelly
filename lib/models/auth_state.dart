import 'credentials.dart';

/// Represents the various states of the authentication process.
sealed class TeliAuthState {
  const TeliAuthState();
}

/// Authentication completed successfully.
class TeliAuthSuccess extends TeliAuthState {
  final TeliCredentials credentials;
  final dynamic rawData;
  const TeliAuthSuccess(this.credentials, {this.rawData});
}

/// Authentication failed.
class TeliAuthError extends TeliAuthState {
  final String message;
  const TeliAuthError(this.message);
}

/// Waiting for the user to provide an OTP code.
class TeliAuthWaitOtp extends TeliAuthState {
  const TeliAuthWaitOtp();
}

/// Waiting for the user to provide a 2FA password.
class TeliAuthWaitPassword extends TeliAuthState {
  final String hint;
  const TeliAuthWaitPassword(this.hint);
}

/// Internal state: Connection established, waiting for next step.
class TeliAuthReady extends TeliAuthState {
  const TeliAuthReady();
}
