/// Credentials and session data required for [TeliDemoClient].
///
/// This class holds the necessary information to authenticate with Telegram,
/// including API credentials, phone number, and session persistence data.
class TeliDemoCredentials {
  /// The API ID obtained from https://my.telegram.org.
  int apiId;

  /// The API Hash obtained from https://my.telegram.org.
  String apiHash;

  /// The country code without the '+' prefix (e.g., "91" for India).
  String? countryCode;

  /// The subscriber phone number without the country code (e.g., "9876543210").
  String? phoneNumber;

  /// The hash received after sending the OTP code, used for signing in.
  String? phoneCodeHash;

  /// The serialized session data (JSON) for persistence.
  ///
  /// This can be used to resume an existing session without re-authenticating.
  String? sessionData;

  /// Creates a new [TeliDemoCredentials] instance.
  TeliDemoCredentials({
    required this.apiId,
    required this.apiHash,
    this.countryCode,
    this.phoneNumber,
    this.phoneCodeHash,
    this.sessionData,
  });

  /// Validates the API ID and API Hash.
  ///
  /// Throws an [ArgumentError] if the credentials are invalid.
  void validateApiCredentials() {
    final apiIdStr = apiId.toString();
    if (!RegExp(r'^\d{7,10}$').hasMatch(apiIdStr)) {
      throw ArgumentError('Invalid API ID: Must be a 7-10 digit number.');
    }

    if (apiHash.length != 32) {
      throw ArgumentError('Invalid API Hash: Must be 32 characters long.');
    }
  }

  /// Validates the phone number components and returns the full number.
  ///
  /// This method performs validation on [countryCode] and [phoneNumber].
  /// Throws an [ArgumentError] if either field is missing or invalid.
  String validatePhoneNumber() {
    final cc = countryCode?.replaceAll(RegExp(r'\D'), '');
    final ph = phoneNumber?.replaceAll(RegExp(r'\D'), '');

    if (cc == null || cc.isEmpty) {
      throw ArgumentError('Country code is required and cannot be empty.');
    }
    if (ph == null || ph.isEmpty) {
      throw ArgumentError('Phone number is required and cannot be empty.');
    }

    final full = '+$cc$ph';
    
    // Basic international phone number validation (MTProto typically expects 7-15 digits)
    if (!RegExp(r'^\+\d{7,15}$').hasMatch(full)) {
      throw ArgumentError(
        'Invalid phone number format: $full. '
        'The combined number must be between 7 and 15 digits.',
      );
    }
    
    return full;
  }

  /// Returns the full phone number in international format.
  ///
  /// Alias for [validatePhoneNumber] if you just want the result.
  String get fullPhoneNumber => validatePhoneNumber();
}
