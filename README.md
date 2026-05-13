# telissy

A high-level, resource-oriented, and reactive Telegram client library for Dart. 

`telissy` is designed to provide a clean, developer-friendly abstraction over the MTProto protocol. It focuses on memory efficiency, non-blocking execution, and a simplified object model, making it ideal for both mobile apps (Flutter) and background services.

## Core Features

-   **⚡ Reactive Authentication**: A state-machine-based auth flow that doesn't block your main thread. Handle OTPs and 2FA via simple method calls.
-   **📦 Facade Data Models**: High-level `TeliMessage`, `TeliChannel`, and `TeliUser` objects. No more struggling with nested and confusing raw MTProto types.
-   **🌊 Memory-Efficient Streams**: Fetch thousands of messages without crashing your app. The library yields messages in chunks via Dart Streams.
-   **🏗️ Resource-Oriented API**: Clean, predictable methods for common Telegram tasks.
-   **🔒 Secure & Persistent**: Easy session management and credential handling.

## Getting Started

### Installation

Add `telissy` to your `pubspec.yaml`:

```yaml
dependencies:
  telissy:
    path: . # Or use the hosted version once published
```

### 1. Authentication

`telissy` uses a non-blocking state machine for login. Instead of callbacks, you drive the process based on the returned state.

```dart
import 'package:telissy/telissy.dart';

void main() async {
  final credentials = TeliCredentials(
    apiId: YOUR_API_ID,
    apiHash: 'YOUR_API_HASH',
    countryCode: '91',
    phoneNumber: '9876543210',
  );

  final auth = TeliAuth(credentials);
  var state = await auth.login();

  if (state is TeliAuthWaitOtp) {
    // Show OTP input in your UI
    state = await auth.submitOtp('12345');
  }

  if (state is TeliAuthWaitPassword) {
    // Handle 2FA if enabled
    state = await auth.submitPassword('your_password');
  }

  if (state is TeliAuthSuccess) {
    print('Login successful!');
    // Save credentials.sessionData for future use
  }
}
```

### 2. Connecting the Client

Once authenticated, use the `TeliClient` to interact with Telegram.

```dart
final client = TeliClient(credentials);
await client.connect();

// Fetch your channels
final channels = await client.getSubscribedChannels();
for (var channel in channels) {
  print('Channel: ${channel.title}');
}
```

### 3. Fetching Messages (Reactive)

For large message histories, `telissy` uses Streams to ensure your application remains responsive and uses minimal memory.

#### Option A: Latest N Messages (Paginated)

Best for quickly displaying the most recent activity. Fetches results in pages of up to 100, returning a single list.

```dart
final messages = await client.getMessages(selectedChannel, limit: 150);
```

#### Option B: Latest N Messages (Stream)

Memory-efficient streaming version of Option A. Yields batches as they arrive without loading everything at once.

```dart
final stream = client.getMessagesStream(
  selectedChannel,
  limit: 150,
);

await for (final batch in stream) {
  print('Chunk: ${batch.length} messages');
}
```

#### Option C: Time Range (Stream)

Best for historical processing or search. Defaults to last 24h if dates are omitted.

```dart
final stream = client.getMessagesByTimeRange(
  selectedChannel,
  startDate: DateTime(2023, 10, 1),
  endDate: DateTime(2023, 10, 5),
);

await for (final batch in stream) {
  print('Chunk: ${batch.length} messages');
}
```

#### Option D: Until Message ID (Stream)

Best for syncing databases or "catching up" to where you last left off.

```dart
final syncStream = client.getMessagesUntil(
  selectedChannel,
  lastMessageId: 54321, // Stop when this ID is reached
);

await for (final batch in syncStream) {
  // Process batches until lastMessageId is found
}
```

## Advanced Usage

### Custom Credentials
You can extend the `TeliCredentials` base class to implement custom persistence (e.g., storing session data in a database or secure storage).

### Raw MTProto Access
If you need a method not yet covered by the high-level API, you can still use the `rawClient`:

```dart
final rawResult = await client.invoke(t.HelpGetConfig());
```

## Why telissy?

The standard Telegram libraries often leak complex, deeply nested types and use blocking patterns that are difficult to manage in modern UI frameworks. `telissy` solves this by:
1.  **Hiding Complexity**: Converting raw types into flat, easy-to-use models.
2.  **Streaming Data**: Preventing `OutOfMemory` errors by never loading the entire history at once.
3.  **Reactive Auth**: Allowing developers to build seamless, step-by-step authentication UIs without thread hangs.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
