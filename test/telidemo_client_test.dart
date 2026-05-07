import 'package:telidemo/telidemo.dart';
import 'package:test/test.dart';
import 'package:t/t.dart' as t;

void main() {
  group('TeliDemoClient', () {
    late TeliDemoClient client;
    late TeliDemoCredentials credentials;

    setUp(() {
      credentials = TeliDemoCredentials(apiId: 12345, apiHash: 'abcde');
      client = TeliDemoClient(credentials);
    });

    test('can be instantiated', () {
      expect(client, isNotNull);
      expect(client.credentials.apiId, 12345);
      expect(client.credentials.apiHash, 'abcde');
    });

    test('credentials can be updated', () {
      client.credentials.apiId = 67890;
      expect(client.credentials.apiId, 67890);
    });

    test('phone number components can be set and retrieved', () {
      client.credentials.countryCode = '91';
      client.credentials.phoneNumber = '9876543210';
      expect(client.credentials.countryCode, '91');
      expect(client.credentials.phoneNumber, '9876543210');
      expect(client.credentials.fullPhoneNumber, '+919876543210');
    });

    test('rawClient is null before init', () {
      expect(client.rawClient, isNull);
    });

    group('Validation', () {
      test('validateApiCredentials accepts valid API ID and Hash', () {
        credentials.apiId = 1234567;
        credentials.apiHash = 'a' * 32;
        expect(() => credentials.validateApiCredentials(), returnsNormally);
      });

      test('validateApiCredentials throws ArgumentError for invalid API ID', () {
        credentials.apiId = 123;
        expect(() => credentials.validateApiCredentials(), throwsArgumentError);
      });

      test('validateApiCredentials throws ArgumentError for invalid API Hash', () {
        credentials.apiId = 1234567;
        credentials.apiHash = 'short';
        expect(() => credentials.validateApiCredentials(), throwsArgumentError);
      });

      test('validatePhoneNumber accepts valid phone number components', () {
        credentials.countryCode = '91';
        credentials.phoneNumber = '9876543210';
        expect(() => credentials.validatePhoneNumber(), returnsNormally);
      });

      test('validatePhoneNumber throws ArgumentError for missing components', () {
        credentials.countryCode = null;
        credentials.phoneNumber = '9876543210';
        expect(() => credentials.validatePhoneNumber(), throwsArgumentError);
        
        credentials.countryCode = '91';
        credentials.phoneNumber = null;
        expect(() => credentials.validatePhoneNumber(), throwsArgumentError);
      });

      test('validatePhoneNumber throws ArgumentError for invalid length', () {
        credentials.countryCode = '1';
        credentials.phoneNumber = '23'; // too short
        expect(() => credentials.validatePhoneNumber(), throwsArgumentError);
      });
    });

    group('OTP methods', () {
      test('getChatHistory throws StateError if not initialized', () {
        expect(() => client.getChatHistory(const t.InputPeerEmpty()), throwsStateError);
      });
    });
  });
}
