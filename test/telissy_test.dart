import 'package:telissy/telissy.dart';
import 'package:test/test.dart';

void main() {
  group('TeliCredentials', () {
    test('validateApiCredentials throws on invalid API ID', () {
      final creds = TeliCredentials(apiId: 123, apiHash: 'a' * 32);
      expect(() => creds.validateApiCredentials(), throwsArgumentError);
    });

    test('validateApiCredentials throws on invalid API Hash', () {
      final creds = TeliCredentials(apiId: 1234567, apiHash: 'short');
      expect(() => creds.validateApiCredentials(), throwsArgumentError);
    });

    test('validatePhoneNumber formats correctly', () {
      final creds = TeliCredentials(
        apiId: 1234567,
        apiHash: 'a' * 32,
        countryCode: '91',
        phoneNumber: '9876543210',
      );
      expect(creds.fullPhoneNumber, equals('+919876543210'));
    });

    test('getHost returns correct DC for India', () {
      final creds = TeliCredentials(
        apiId: 1234567,
        apiHash: 'a' * 32,
        countryCode: '91',
      );
      final host = creds.getHost();
      expect(host.dcId, equals(5));
      expect(host.ip, equals('91.108.56.130'));
    });

    test('getHost returns correct DC for USA', () {
      final creds = TeliCredentials(
        apiId: 1234567,
        apiHash: 'a' * 32,
        countryCode: '1',
      );
      final host = creds.getHost();
      expect(host.dcId, equals(1));
    });

    test('getHost returns correct DC for UK', () {
      final creds = TeliCredentials(
        apiId: 1234567,
        apiHash: 'a' * 32,
        countryCode: '44',
      );
      final host = creds.getHost();
      expect(host.dcId, equals(2));
    });

    test('validatePhoneNumber throws on empty country code', () {
      final creds = TeliCredentials(apiId: 1234567, apiHash: 'a' * 32);
      expect(() => creds.validatePhoneNumber(), throwsArgumentError);
    });

    test('validatePhoneNumber throws on empty phone number', () {
      final creds = TeliCredentials(
        apiId: 1234567,
        apiHash: 'a' * 32,
        countryCode: '1',
      );
      expect(() => creds.validatePhoneNumber(), throwsArgumentError);
    });
  });
}
