import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:tg/tg.dart' as tg;

/// A [tg.SocketAbstraction] implementation that wraps a standard [Socket].
///
/// This class facilitates communication between the [tg.Client] and the
/// Telegram servers using the Dart IO [Socket].
class TeliDemoSocket extends tg.SocketAbstraction {
  /// The underlying network socket.
  final Socket socket;

  /// Creates a [TeliDemoSocket] wrapping the provided [socket].
  TeliDemoSocket(this.socket) : receiver = socket.asBroadcastStream();

  @override
  final Stream<Uint8List> receiver;

  @override
  Future<void> send(List<int> data) async {
    socket.add(data);
    await socket.flush();
  }

  /// Closes the underlying socket.
  Future<void> close() async {
    await socket.close();
  }
}
