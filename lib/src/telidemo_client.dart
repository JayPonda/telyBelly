import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:t/t.dart' as t;
import 'package:tg/tg.dart' as tg;

import 'telidemo_credentials.dart';
import 'telidemo_socket.dart';

/// Defines the result of an authentication attempt.
class AuthResult {
  /// Whether the authentication was successful.
  final bool success;

  /// An optional message describing the result (e.g., error message).
  final String? message;

  /// Optional data associated with the result (e.g., the signed-in user).
  final dynamic data;

  /// Creates a new [AuthResult].
  const AuthResult({
    required this.success,
    this.message,
    this.data,
  });
}

/// A high-level Telegram client with an automated authentication flow.
///
/// This client wraps [tg.Client] and provides a simplified interface for
/// connecting, authenticating (including OTP and 2FA), and interacting with
/// the Telegram API.
final class TeliDemoClient {
  tg.Client? _client;
  final TeliDemoCredentials credentials;
  final StreamController<dynamic> _updateController =
      StreamController<dynamic>.broadcast();

  /// Callback triggered before the authentication process starts.
  FutureOr<void> Function()? onBeforeAuth;

  /// Callback used to retrieve the OTP code from the user.
  Future<String> Function()? onGetOtp;

  /// Callback used to retrieve the 2FA password from the user.
  ///
  /// The [hint] provides the password hint configured by the user.
  Future<String> Function(String hint)? onGetPassword;

  /// Callback triggered when the authentication process completes.
  void Function(AuthResult result)? onAuthResult;

  /// Creates a new [TeliDemoClient] with the given [credentials].
  TeliDemoClient(this.credentials);

  /// The underlying raw [tg.Client] instance.
  ///
  /// This is `null` until [login] is called and the initial handshake is successful.
  tg.Client? get rawClient => _client;

  /// Initializes the client and starts the automated login flow.
  ///
  /// This method performs the following steps:
  /// 1. Validates API credentials.
  /// 2. Connects to the Telegram server.
  /// 3. Performs the Diffie-Hellman handshake or resumes a session.
  /// 4. Initializes the connection.
  /// 5. Checks if the user is already signed in.
  /// 6. If not signed in, starts the OTP authentication flow.
  Future<void> login({
    String ip = '91.108.56.130',
    int port = 443,
    int dcId = 5,
  }) async {
    credentials.validateApiCredentials();

    if (onBeforeAuth != null) {
      await onBeforeAuth!();
    }

    final socket = await Socket.connect(ip, port);
    final teliSocket = TeliDemoSocket(socket);
    final obfuscation = tg.Obfuscation.random(false, dcId);
    final idGenerator = tg.MessageIdGenerator();

    await teliSocket.send(obfuscation.preamble);

    tg.AuthorizationKey? authKey;
    final session = credentials.sessionData;
    if (session != null && session.isNotEmpty) {
      try {
        authKey = tg.AuthorizationKey.fromJson(
          jsonDecode(session) as Map<String, dynamic>,
        );
      } catch (e) {
        // Fallback to DH exchange if session is invalid
      }
    }

    if (authKey == null) {
      authKey = await tg.Client.authorize(
        teliSocket,
        obfuscation,
        idGenerator,
      );
      credentials.sessionData = jsonEncode(authKey.toJson());
    }

    _client = tg.Client(
      socket: teliSocket,
      obfuscation: obfuscation,
      authorizationKey: authKey,
      idGenerator: idGenerator,
    );

    _client!.stream.listen((event) {
      _updateController.add(event);
    });

    await _client!.initConnection<t.Config>(
      apiId: credentials.apiId,
      deviceModel: 'Desktop',
      systemVersion: 'Unknown',
      appVersion: '1.0.0',
      systemLangCode: 'en',
      langPack: '',
      langCode: 'en',
      query: const t.HelpGetConfig(),
    );

    bool alreadySignedIn = false;
    try {
      final userResponse = await _client!.users.getUsers(
        id: [const t.InputUserSelf()],
      );
      if (userResponse.result is List &&
          (userResponse.result as List).isNotEmpty) {
        alreadySignedIn = true;
      }
    } catch (e) {
      // Not signed in
    }

    if (alreadySignedIn) {
      onAuthResult?.call(
        const AuthResult(success: true, message: 'Session resumed.'),
      );
    } else {
      await _startOtpFlow();
    }
  }

  Future<void> _startOtpFlow() async {
    try {
      final fullPhone = credentials.validatePhoneNumber();

      final response = await _client!.auth.sendCode(
        phoneNumber: fullPhone,
        apiId: credentials.apiId,
        apiHash: credentials.apiHash,
        settings: const t.CodeSettings(
          allowFlashcall: false,
          currentNumber: true,
          allowAppHash: false,
          allowMissedCall: false,
          allowFirebase: false,
          unknownNumber: false,
        ),
      );

      if (response.error != null) {
        onAuthResult?.call(
          AuthResult(success: false, message: response.error!.errorMessage),
        );
        return;
      }

      final sentCode = response.result as t.AuthSentCode;
      credentials.phoneCodeHash = sentCode.phoneCodeHash;

      if (onGetOtp == null) {
        throw StateError('onGetOtp callback is required but not provided.');
      }
      final otp = await onGetOtp!();

      final signInResponse = await _client!.auth.signIn(
        phoneNumber: fullPhone,
        phoneCodeHash: credentials.phoneCodeHash!,
        phoneCode: otp,
      );

      if (signInResponse.error != null) {
        if (signInResponse.error!.errorMessage == 'SESSION_PASSWORD_NEEDED') {
          await _handle2FA();
        } else {
          onAuthResult?.call(
            AuthResult(
              success: false,
              message: signInResponse.error!.errorMessage,
            ),
          );
        }
      } else {
        onAuthResult?.call(
          AuthResult(success: true, data: signInResponse.result),
        );
      }
    } catch (e) {
      onAuthResult?.call(AuthResult(success: false, message: e.toString()));
    }
  }

  Future<void> _handle2FA() async {
    final accountPasswordResponse = await _client!.account.getPassword();
    if (accountPasswordResponse.result is t.AccountPassword) {
      final accountPassword =
          accountPasswordResponse.result as t.AccountPassword;

      if (onGetPassword == null) {
        onAuthResult?.call(
          const AuthResult(
            success: false,
            message: '2FA required but onGetPassword callback not provided.',
          ),
        );
        return;
      }

      final password = await onGetPassword!(accountPassword.hint ?? '');
      final srp = await tg.check2FA(accountPassword, password);
      final checkPasswordResponse =
          await _client!.auth.checkPassword(password: srp);

      if (checkPasswordResponse.error != null) {
        onAuthResult?.call(
          AuthResult(
            success: false,
            message: checkPasswordResponse.error!.errorMessage,
          ),
        );
      } else {
        onAuthResult?.call(
          AuthResult(success: true, data: checkPasswordResponse.result),
        );
      }
    }
  }

  /// Listens for updates from the Telegram server.
  void onUpdate(FutureOr<void> Function(dynamic data) callback) {
    _updateController.stream.listen((data) async {
      await callback(data);
    });
  }

  /// Invokes a raw Telegram method (RPC call).
  ///
  /// Throws a [StateError] if the client is not initialized.
  Future<dynamic> invoke(t.TlMethod method) async {
    final client = _client;
    if (client == null) {
      throw StateError('Client not initialized. Call login() first.');
    }
    return await client.invoke(method);
  }

  /// Retrieves message history for a specific chat.
  ///
  /// [peer] is the chat to retrieve history from.
  /// [offsetId] and [offsetDate] are used for pagination.
  /// [limit] is the maximum number of messages to retrieve.
  Future<dynamic> getChatHistory(
    t.InputPeerBase peer, {
    int offsetId = 0,
    int offsetDate = 0,
    int addOffset = 0,
    int limit = 10,
    int maxId = 0,
    int minId = 0,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Client not initialized. Call login() first.');
    }

    return await client.messages.getHistory(
      peer: peer,
      offsetId: offsetId,
      offsetDate: DateTime.fromMillisecondsSinceEpoch(offsetDate * 1000),
      addOffset: addOffset,
      limit: limit,
      maxId: maxId,
      minId: minId,
      hash: 0,
    );
  }
}
