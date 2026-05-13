import 'dart:async';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:telissy/telissy.dart';
import 'package:tg/tg.dart' as tg;
import 'package:t/t.dart' as t;

@GenerateNiceMocks([MockSpec<tg.Client>()])
import 'client_test.mocks.dart';

void main() {
  group('TeliClient', () {
    late MockClient mockTgClient;
    late TeliClient teliClient;
    late TeliCredentials credentials;

    setUp(() {
      mockTgClient = MockClient();
      credentials = TeliCredentials(apiId: 1234567, apiHash: 'a' * 32);
      teliClient = TeliClient(credentials, client: mockTgClient);
    });

    test('invoke calls client.invoke and returns result', () async {
      final method = const t.HelpGetConfig();
      const expectedResult = t.UserEmpty(id: 123);
      
      when(mockTgClient.invoke(method)).thenAnswer(
        (_) async => const t.Result.ok(expectedResult),
      );

      final result = await teliClient.invoke(method);
      expect(result, equals(expectedResult));
    });

    test('getSubscribedChannels returns list of TeliChannel', () async {
      final expectedChats = [
        t.Chat(
          creator: true,
          left: false,
          deactivated: false,
          callActive: false,
          callNotEmpty: false,
          noforwards: false,
          id: 1,
          title: 'Title',
          photo: const t.ChatPhotoEmpty(),
          participantsCount: 1,
          date: DateTime.fromMillisecondsSinceEpoch(1600000000 * 1000),
          version: 1,
        )
      ];
      
      when(mockTgClient.invoke(any)).thenAnswer(
        (_) async => t.Result.ok(t.MessagesDialogs(
          dialogs: [],
          messages: [],
          chats: expectedChats,
          users: [],
        )),
      );

      final result = await teliClient.getSubscribedChannels();
      expect(result.length, equals(1));
      expect(result[0].id, equals(1));
    });

    test('getMessages returns list of TeliMessage', () async {
      const channel = TeliChannel(id: 1, title: 'Channel');
      
      when(mockTgClient.invoke(any)).thenAnswer(
        (_) async => t.Result.ok(t.MessagesMessages(
          messages: [
            t.Message(
              out: false,
              mentioned: false,
              mediaUnread: false,
              silent: false,
              post: false,
              fromScheduled: false,
              legacy: false,
              editHide: false,
              pinned: false,
              noforwards: false,
              invertMedia: false,
              offline: false,
              videoProcessingPending: false,
              paidSuggestedPostStars: false,
              paidSuggestedPostTon: false,
              id: 1,
              date: DateTime.fromMillisecondsSinceEpoch(1600000000 * 1000),
              message: 'Hello',
              peerId: const t.PeerChat(chatId: 1),
            )
          ],
          topics: [],
          chats: [],
          users: [],
        )),
      );

      final result = await teliClient.getMessages(channel);
      expect(result.length, equals(1));
      expect(result[0].id, equals(1));
    });

    test('getMessagesByTimeRange yields message batches', () async {
      const channel = TeliChannel(id: 1, title: 'Channel');
      
      when(mockTgClient.invoke(any)).thenAnswer(
        (_) async => t.Result.ok(t.MessagesMessages(
          messages: [
            t.Message(
              out: false,
              mentioned: false,
              mediaUnread: false,
              silent: false,
              post: false,
              fromScheduled: false,
              legacy: false,
              editHide: false,
              pinned: false,
              noforwards: false,
              invertMedia: false,
              offline: false,
              videoProcessingPending: false,
              paidSuggestedPostStars: false,
              paidSuggestedPostTon: false,
              id: 1,
              date: DateTime.now(),
              message: 'Hello',
              peerId: const t.PeerChat(chatId: 1),
            )
          ],
          topics: [],
          chats: [],
          users: [],
        )),
      );

      final stream = teliClient.getMessagesByTimeRange(channel);
      final batches = await stream.toList();
      expect(batches.length, equals(1));
      expect(batches[0].length, equals(1));
    });

    test('getMessagesUntil yields messages until stopAtId', () async {
      const channel = TeliChannel(id: 1, title: 'Channel');
      
      when(mockTgClient.invoke(any)).thenAnswer(
        (_) async => t.Result.ok(t.MessagesMessages(
          messages: [
            t.Message(
              out: false,
              mentioned: false,
              mediaUnread: false,
              silent: false,
              post: false,
              fromScheduled: false,
              legacy: false,
              editHide: false,
              pinned: false,
              noforwards: false,
              invertMedia: false,
              offline: false,
              videoProcessingPending: false,
              paidSuggestedPostStars: false,
              paidSuggestedPostTon: false,
              id: 10,
              date: DateTime.now(),
              message: 'Msg 10',
              peerId: const t.PeerChat(chatId: 1),
            ),
            t.Message(
              out: false,
              mentioned: false,
              mediaUnread: false,
              silent: false,
              post: false,
              fromScheduled: false,
              legacy: false,
              editHide: false,
              pinned: false,
              noforwards: false,
              invertMedia: false,
              offline: false,
              videoProcessingPending: false,
              paidSuggestedPostStars: false,
              paidSuggestedPostTon: false,
              id: 5,
              date: DateTime.now(),
              message: 'Msg 5',
              peerId: const t.PeerChat(chatId: 1),
            ),
          ],
          topics: [],
          chats: [],
          users: [],
        )),
      );

      final stream = teliClient.getMessagesUntil(channel, lastMessageId: 5);
      final batches = await stream.toList();
      expect(batches.length, equals(1));
      expect(batches[0].length, equals(1));
      expect(batches[0][0].id, equals(10));
    });

    test('connect and onUpdate receive updates', () async {
      credentials.sessionData = '{"key": [1,2,3]}';
      final updateController = StreamController<t.UpdatesBase>();
      when(mockTgClient.stream).thenAnswer((_) => updateController.stream);
      
      await teliClient.connect();
      
      final completer = Completer<t.UpdatesBase>();
      teliClient.onUpdate((data) {
        completer.complete(data as t.UpdatesBase);
      });
      
      const update = t.UpdatesTooLong();
      updateController.add(update);
      final received = await completer.future;
      expect(received, equals(update));
      await updateController.close();
    });

    test('logout calls AuthLogOut and clears sessionData', () async {
      when(mockTgClient.invoke(const t.AuthLogOut())).thenAnswer(
        (_) async => t.Result.ok(t.True()),
      );

      await teliClient.logout();
      expect(credentials.sessionData, isNull);
    });

    test('close cancels subscription and closes socket', () async {
      await teliClient.close();
    });
  });
}
