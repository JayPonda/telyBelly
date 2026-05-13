import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:telissy/telissy.dart';
import 'package:telissy/src/auth.dart';
import 'package:telissy/src/socket.dart';
import 'package:tg/tg.dart' as tg;
import 'package:t/t.dart' as t;

@GenerateNiceMocks([
  MockSpec<tg.Client>(),
  MockSpec<t.ClientUsers>(),
  MockSpec<t.ClientAuth>(),
  MockSpec<t.ClientAccount>(),
  MockSpec<Socket>(),
  MockSpec<tg.AuthorizationKey>(),
])
import 'auth_test.mocks.dart';

class MockVector<T> extends Mock implements t.Vector<T> {
  @override
  final List<T> items;
  MockVector(this.items);
}

void main() {
  group('TeliAuth', () {
    late MockClient mockTgClient;
    late MockClientUsers mockUsers;
    late MockClientAuth mockAuth;
    late MockClientAccount mockAccount;
    late MockSocket mockSocket;
    late TeliAuth teliAuth;
    late TeliCredentials credentials;

    setUp(() {
      mockTgClient = MockClient();
      mockUsers = MockClientUsers();
      mockAuth = MockClientAuth();
      mockAccount = MockClientAccount();
      mockSocket = MockSocket();

      when(mockTgClient.users).thenReturn(mockUsers);
      when(mockTgClient.auth).thenReturn(mockAuth);
      when(mockTgClient.account).thenReturn(mockAccount);

      credentials = TeliCredentials(
        apiId: 1234567,
        apiHash: 'a' * 32,
        countryCode: '91',
        phoneNumber: '9876543210',
      );

      final teliSocket = TeliSocket(mockSocket);
      teliAuth = TeliAuth(
        credentials,
        client: mockTgClient,
        teliSocket: teliSocket,
      );
    });

    test('login returns TeliAuthSuccess if session is valid', () async {
      final selfUser = const t.UserEmpty(id: 123);
      final vector = MockVector<t.UserBase>([selfUser]);

      when(
        mockUsers.getUsers(id: anyNamed('id')),
      ).thenAnswer((_) async => t.Result.ok(vector));

      final result = await teliAuth.login();
      expect(result, isA<TeliAuthSuccess>());
    });

    test('login returns TeliAuthWaitOtp if login is needed', () async {
      // Return empty vector to trigger _sendCode
      when(
        mockUsers.getUsers(id: anyNamed('id')),
      ).thenAnswer((_) async => t.Result.ok(MockVector<t.UserBase>([])));

      when(
        mockAuth.sendCode(
          phoneNumber: anyNamed('phoneNumber'),
          apiId: anyNamed('apiId'),
          apiHash: anyNamed('apiHash'),
          settings: anyNamed('settings'),
        ),
      ).thenAnswer(
        (_) async => const t.Result.ok(
          t.AuthSentCode(
            type: t.AuthSentCodeTypeApp(length: 5),
            phoneCodeHash: 'hash',
          ),
        ),
      );

      final result = await teliAuth.login();
      expect(result, isA<TeliAuthWaitOtp>());
      expect(credentials.phoneCodeHash, equals('hash'));
    });

    test('submitOtp returns TeliAuthSuccess on success', () async {
      credentials.phoneCodeHash = 'hash';
      final mockAuthKey = MockAuthorizationKey();
      when(mockAuthKey.toJson()).thenReturn({});
      when(mockTgClient.authorizationKey).thenReturn(mockAuthKey);

      when(
        mockAuth.signIn(
          phoneNumber: anyNamed('phoneNumber'),
          phoneCodeHash: anyNamed('phoneCodeHash'),
          phoneCode: anyNamed('phoneCode'),
        ),
      ).thenAnswer(
        (_) async => const t.Result.ok(
          t.AuthAuthorization(
            setupPasswordRequired: false,
            user: t.UserEmpty(id: 123),
          ),
        ),
      );

      final result = await teliAuth.submitOtp('12345');
      expect(result, isA<TeliAuthSuccess>());
    });
    test('submitOtp returns TeliAuthWaitPassword if 2FA is needed', () async {
      credentials.phoneCodeHash = 'hash';

      when(
        mockAuth.signIn(
          phoneNumber: anyNamed('phoneNumber'),
          phoneCodeHash: anyNamed('phoneCodeHash'),
          phoneCode: anyNamed('phoneCode'),
        ),
      ).thenAnswer(
        (_) async => const t.Result.error(
          t.RpcError(errorCode: 401, errorMessage: 'SESSION_PASSWORD_NEEDED'),
        ),
      );

      when(mockAccount.getPassword()).thenAnswer(
        (_) async => t.Result.ok(
          t.AccountPassword(
            hasRecovery: true,
            hasSecureValues: false,
            hasPassword: true,
            currentAlgo: t.PasswordKdfAlgoUnknown(),
            newAlgo: t.PasswordKdfAlgoUnknown(),
            newSecureAlgo: t.SecurePasswordKdfAlgoUnknown(),
            secureRandom: Uint8List(0),
            hint: 'my hint',
          ),
        ),
      );

      final result = await teliAuth.submitOtp('12345');
      expect(result, isA<TeliAuthWaitPassword>());
      expect((result as TeliAuthWaitPassword).hint, equals('my hint'));
    });
    test('submitPassword returns TeliAuthError if check2FA fails', () async {
      final mockAuthKey = MockAuthorizationKey();
      when(mockAuthKey.toJson()).thenReturn({});
      when(mockTgClient.authorizationKey).thenReturn(mockAuthKey);

      when(mockAccount.getPassword()).thenAnswer(
        (_) async => t.Result.ok(t.AccountPassword(
          hasRecovery: true,
          hasSecureValues: false,
          hasPassword: true,
          currentAlgo: const t.PasswordKdfAlgoUnknown(),
          newAlgo: const t.PasswordKdfAlgoUnknown(),
          newSecureAlgo: const t.SecurePasswordKdfAlgoUnknown(),
          secureRandom: Uint8List(0),
          hint: 'my hint',
        )),
      );

      final result = await teliAuth.submitPassword('my password');
      expect(result, isA<TeliAuthError>());
    });
  });
}
