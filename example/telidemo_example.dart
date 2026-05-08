import 'dart:io';

import 'package:t/t.dart' as t;
import 'package:telidemo/telidemo.dart';

/// A custom credentials class that saves/loads session data from a local file.
class PersistentCredentials extends TeliDemoCredentials {
  final File _sessionFile = File('session.json');

  PersistentCredentials({required super.apiId, required super.apiHash});

  @override
  String? get sessionData {
    if (_sessionFile.existsSync()) {
      return _sessionFile.readAsStringSync();
    }
    return null;
  }

  @override
  set sessionData(String? value) {
    if (value != null) {
      _sessionFile.writeAsStringSync(value);
    } else if (_sessionFile.existsSync()) {
      _sessionFile.deleteSync();
    }
  }

  bool get hasSession => _sessionFile.existsSync();
}

void main() async {
  print('--- TeliDemo Standalone Tool ---');

  // 1. Setup API Credentials
  final sessionExists = File('session.json').existsSync();

  int? apiId;
  String? apiHash;

  if (!sessionExists) {
    stdout.write('Enter your API ID: ');
    final apiIdInput = stdin.readLineSync();
    stdout.write('Enter your API Hash: ');
    final apiHashInput = stdin.readLineSync();

    if (apiIdInput == null || apiHashInput == null) return;
    apiId = int.tryParse(apiIdInput);
    apiHash = apiHashInput;
  } else {
    stdout.write('Enter your API ID (required to resume session): ');
    apiId = int.tryParse(stdin.readLineSync() ?? '');
    stdout.write('Enter your API Hash: ');
    apiHash = stdin.readLineSync();
  }

  if (apiId == null || apiHash == null) {
    print('Error: API ID and Hash are required.');
    return;
  }

  final credentials = PersistentCredentials(
    apiId: apiId,
    apiHash: apiHash,
  );

  // 2. Setup Client
  final client = TeliDemoClient(credentials);

  // --- Register Callbacks for Auth ---

  client.onAuthRequired = () {
    print('\n[Notice] No active session found. Authentication required.');
    
    if (credentials.countryCode == null) {
      stdout.write('Enter Country Code (e.g., 91): ');
      credentials.countryCode = stdin.readLineSync();
    }
    if (credentials.phoneNumber == null) {
      stdout.write('Enter Phone Number (e.g., 9876543210): ');
      credentials.phoneNumber = stdin.readLineSync();
    }
  };

  client.onGetOtp = () async {
    stdout.write('\nEnter OTP code: ');
    return stdin.readLineSync() ?? '';
  };

  client.onGetPassword = (hint) async {
    stdout.write('\nEnter 2FA Password (Hint: $hint): ');
    return stdin.readLineSync() ?? '';
  };

  client.onAuthResult = (result) {
    if (result.success) {
      print('\n[Success] ${result.message ?? "Logged in."}');
    } else {
      print('\n[Error] ${result.message}');
    }
  };

  // 3. Execution Flow
  try {
    print('\n[Action] Initiating connection and login...');
    final loginResult = await client.login();
    
    if (!loginResult.success) {
      print('[Status] Login failed. Cleaning up session data.');
      // Clear invalid session data so next try is clean
      credentials.sessionData = null;
      await client.close();
      exit(1);
    }
    
    print('[Status] Login process finished successfully.');

    // 4. Perform Standalone Task: Get Subscribed Channels
    print('\n[Action] Requesting subscribed channels (Standalone API Request)...');
    final response = await client.getSubscribedChannels();

    if (response.error == null) {
      final result = response.result;
      List<t.ChatBase> chats = [];
      
      if (result is t.MessagesDialogs) {
        chats = result.chats;
      } else if (result is t.MessagesDialogsSlice) {
        chats = result.chats;
      }

      if (chats.isNotEmpty) {
        print('\n[Data] Successfully retrieved ${chats.length} channels/chats:');
        for (final chat in chats) {
          if (chat is t.Chat) {
            print('  - [Chat] ${chat.title}');
          } else if (chat is t.Channel) {
            print('  - [Channel] ${chat.title}');
          }
        }
      } else {
        print('\n[Data] No channels found.');
      }
    } else {
      print('\n[Error] Failed to fetch channels: ${response.error?.errorMessage}');
    }

    // 5. Cleanup
    print('\n[Action] Standalone task finished. Closing connection...');
    await client.close();
    print('[Status] Done.');
    exit(0);
  } catch (e) {
    print('\n[Fatal Error] $e');
    await client.close();
    exit(1);
  }
}
