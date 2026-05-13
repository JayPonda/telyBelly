import 'dart:io';
import 'dart:convert';

import 'package:telissy/telissy.dart';

/// A utility to persist credentials with session data to a local file.
class SessionStore {
  static final File _file = File('session.json');

  static void save(TeliCredentials credentials) {
    _file.writeAsStringSync(
      jsonEncode({
        'apiId': credentials.apiId,
        'apiHash': credentials.apiHash,
        'sessionData': credentials.sessionData,
      }),
    );
  }

  static TeliCredentials? load() {
    if (!_file.existsSync()) return null;
    try {
      final data = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
      return TeliCredentials(
        apiId: data['apiId'] as int,
        apiHash: data['apiHash'] as String,
        sessionData: data['sessionData'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static void clear() {
    if (_file.existsSync()) _file.deleteSync();
  }
}

void main() async {
  print('=========================================');
  print('   Telissy Reactive Client Example');
  print('=========================================');

  TeliCredentials? credentials = SessionStore.load();
  TeliAuthState? authState;

  if (credentials == null || credentials.sessionData == null) {
    print('[Auth] No valid session found. Starting authentication...');

    stdout.write('Enter your API ID: ');
    final apiId = int.tryParse(stdin.readLineSync() ?? '');

    stdout.write('Enter your API Hash: ');
    final apiHash = stdin.readLineSync();

    if (apiId == null || apiHash == null || apiHash.isEmpty) {
      print('[Error] API ID and Hash are mandatory.');
      return;
    }

    stdout.write('Enter Country Code (e.g., 91): ');
    final countryCode = stdin.readLineSync() ?? '';
    stdout.write('Enter Phone Number (e.g., 9876543210): ');
    final phoneNumber = stdin.readLineSync() ?? '';

    credentials = TeliCredentials(
      apiId: apiId,
      apiHash: apiHash,
      countryCode: countryCode,
      phoneNumber: phoneNumber,
    );

    print('[Auth] Initializing connection...');
    final auth = TeliAuth(credentials);
    authState = await auth.login();

    // Loop through authentication states
    while (authState is! TeliAuthSuccess && authState is! TeliAuthError) {
      if (authState is TeliAuthWaitOtp) {
        stdout.write('[Auth] Enter OTP code: ');
        final code = stdin.readLineSync() ?? '';
        authState = await auth.submitOtp(code);
      } else if (authState is TeliAuthWaitPassword) {
        print('[2FA] Hint: ${authState.hint}');
        stdout.write('[2FA] Enter Password: ');
        final password = stdin.readLineSync() ?? '';
        authState = await auth.submitPassword(password);
      }
    }

    if (authState is TeliAuthError) {
      print('[Error] Authentication failed: ${authState.message}');
      return;
    }

    if (authState is TeliAuthSuccess) {
      SessionStore.save(credentials);
      print('[Auth] Authentication successful. Session saved.');
    }
  } else {
    print(
      '[Session] Resuming existing session for API ID: ${credentials.apiId}',
    );
  }

  // Create client with credentials
  final client = TeliClient(credentials);

  try {
    print('[Action] Connecting to Telegram...');
    await client.connect();
    print('[Status] Connected.');

    print('[Action] Fetching subscribed channels...');
    final channels = await client.getSubscribedChannels(limit: 10);

    print('[Data] Found ${channels.length} chats:');
    for (var i = 0; i < channels.length; i++) {
      final c = channels[i];
      final type = c.isBroadcast ? 'Channel' : (c.isChannel ? 'Supergroup' : 'Chat');
      final forbidden = c.isForbidden ? ' [FORBIDDEN]' : '';
      print('  [$i] $type: ${c.title}$forbidden');
    }

    if (channels.isNotEmpty) {
      stdout.write(
        '\nEnter index to view messages, "L" to logout, or enter to skip: ',
      );
      final input = stdin.readLineSync();
      if (input != null && input.toUpperCase() == 'L') {
        print('[Action] Logging out...');
        await client.logout();
        SessionStore.clear();
        print('[Status] Logged out and session cleared.');
        return;
      }

      if (input != null && input.isNotEmpty) {
        final index = int.tryParse(input);
        if (index != null && index >= 0 && index < channels.length) {
          final selectedChannel = channels[index];

          stdout.write('\nSelect fetch mode:\n');
          stdout.write('  1 - Time range (Stream)\n');
          stdout.write('  2 - Until message (Stream)\n');
          stdout.write('  3 - Latest 5 messages (Simple)\n');
          stdout.write('Enter choice: ');
          final modeInput = stdin.readLineSync();

          if (modeInput == '1') {
            print('\n[Action] Fetching by time range (last 24h) via Stream...');
            final stream = client.getMessagesByTimeRange(selectedChannel);
            bool found = false;
            await for (final batch in stream) {
              found = true;
              print('--- Received Batch (${batch.length} messages) ---');
              for (final msg in batch) {
                print('  [ID: ${msg.id}] [${msg.date}] ${msg.text ?? "Service Message"}');
              }
            }
            if (!found) print('[Info] No messages found in the last 24h.');
          } else if (modeInput == '2') {
            stdout.write('Enter message ID to stop at: ');
            final idInput = stdin.readLineSync();
            final lastId = int.tryParse(idInput ?? '');
            if (lastId == null) {
              print('[Error] Valid message ID required.');
            } else {
              print('\n[Action] Fetching until ID $lastId via Stream...');
              final stream = client.getMessagesUntil(selectedChannel, lastMessageId: lastId);
              bool found = false;
              await for (final batch in stream) {
                found = true;
                print('--- Received Batch (${batch.length} messages) ---');
                for (final msg in batch) {
                  print('  [ID: ${msg.id}] [${msg.date}] ${msg.text ?? "Service Message"}');
                }
              }
              if (!found) print('[Info] No messages found until ID $lastId.');
            }
          } else {
            print('\n[Action] Fetching latest 5 messages...');
            final messages = await client.getMessages(selectedChannel, limit: 5);
            if (messages.isEmpty) {
              print('[Info] No messages found.');
            } else {
              for (final msg in messages) {
                print('  [ID: ${msg.id}] [${msg.date}] ${msg.text ?? "Service Message"}');
              }
            }
          }
        }
      }
    }

    stdout.write('\nWould you like to logout before exiting? (y/N): ');
    final logoutChoice = stdin.readLineSync()?.toLowerCase();
    if (logoutChoice == 'y') {
      print('[Action] Logging out...');
      await client.logout();
      SessionStore.clear();
      print('[Status] Logged out and session cleared.');
    } else {
      print('\n[Action] Shutting down...');
      await client.close();
    }
    print('[Status] Done.');
    exit(0);
  } catch (e) {
    print('[Fatal] Error: $e');
    if (e.toString().contains('AUTH_KEY_UNREGISTERED')) {
      SessionStore.clear();
      print('[Notice] Session expired and cleared.');
    }
    await client.close();
  }
}
