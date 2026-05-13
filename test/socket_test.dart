import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:test/test.dart';
import 'package:telissy/src/socket.dart';

@GenerateNiceMocks([MockSpec<Socket>()])
import 'socket_test.mocks.dart';

void main() {
  group('TeliSocket', () {
    late MockSocket mockSocket;
    late TeliSocket teliSocket;
    late StreamController<Uint8List> controller;

    setUp(() {
      mockSocket = MockSocket();
      controller = StreamController<Uint8List>();
      when(mockSocket.asBroadcastStream()).thenAnswer((_) => controller.stream);
      teliSocket = TeliSocket(mockSocket);
    });

    tearDown(() {
      controller.close();
    });

    test('send calls socket.add and flush', () async {
      final data = [1, 2, 3];
      await teliSocket.send(data);
      verify(mockSocket.add(data)).called(1);
      verify(mockSocket.flush()).called(1);
    });

    test('receiver returns socket broadcast stream', () async {
      final data = Uint8List.fromList([4, 5, 6]);
      final future = teliSocket.receiver.first;
      controller.add(data);
      final result = await future;
      expect(result, equals(data));
    });

    test('close calls socket.close', () async {
      await teliSocket.close();
      verify(mockSocket.close()).called(1);
    });
  });
}
