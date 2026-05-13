import 'package:test/test.dart';
import 'package:telissy/models/models.dart';
import 'package:t/t.dart' as t;

void main() {
  group('TeliAuthState', () {
    test('TeliAuthSuccess works', () {
      final creds = TeliCredentials(apiId: 1, apiHash: 'abc');
      final state = TeliAuthSuccess(creds, rawData: 'some raw data');
      expect(state.credentials, equals(creds));
      expect(state.rawData, equals('some raw data'));
    });

    test('TeliAuthError works', () {
      const state = TeliAuthError('error');
      expect(state.message, equals('error'));
    });

    test('TeliAuthWaitOtp works', () {
      const state = TeliAuthWaitOtp();
      expect(state, isA<TeliAuthWaitOtp>());
    });

    test('TeliAuthWaitPassword works', () {
      const state = TeliAuthWaitPassword('hint');
      expect(state.hint, equals('hint'));
    });
  });

  group('TeliUser', () {
    test('fromRaw handles t.User', () {
      final raw = t.User(
        id: 123,
        self: false,
        contact: false,
        mutualContact: false,
        deleted: false,
        bot: false,
        botChatHistory: false,
        botNochats: false,
        verified: false,
        restricted: false,
        min: false,
        botInlineGeo: false,
        support: false,
        scam: false,
        applyMinPhoto: false,
        fake: false,
        botAttachMenu: false,
        premium: false,
        attachMenuEnabled: false,
        botCanEdit: false,
        closeFriend: false,
        storiesHidden: false,
        storiesUnavailable: false,
        contactRequirePremium: false,
        botBusiness: false,
        botHasMainApp: false,
        botForumView: false,
        botForumCanManageTopics: false,
        botCanManageBots: false,
        botGuestchat: false,
        firstName: 'John',
      );
      final user = TeliUser.fromRaw(raw);
      expect(user.id, equals(123));
      expect(user.firstName, equals('John'));
    });

    test('toString works', () {
      const user = TeliUser(id: 123, username: 'test');
      expect(user.toString(), contains('id: 123'));
      expect(user.toString(), contains('username: test'));
    });
  });

  group('TeliChannel', () {
    test('fromRaw handles t.Channel', () {
      final raw = t.Channel(
        id: 1,
        title: 'Channel',
        accessHash: 123,
        photo: const t.ChatPhotoEmpty(),
        date: DateTime.now(),
        creator: true,
        left: false,
        broadcast: true,
        verified: false,
        megagroup: false,
        restricted: false,
        signatures: false,
        min: false,
        scam: false,
        hasLink: false,
        hasGeo: false,
        slowmodeEnabled: false,
        callActive: false,
        callNotEmpty: false,
        fake: false,
        gigagroup: false,
        noforwards: false,
        joinToSend: false,
        joinRequest: false,
        forum: false,
        storiesHidden: false,
        storiesHiddenMin: false,
        storiesUnavailable: false,
        signatureProfiles: false,
        broadcastMessagesAllowed: false,
        forumTabs: false,
        autotranslation: false,
        monoforum: false,
      );
      final channel = TeliChannel.fromRaw(raw);
      expect(channel.id, equals(1));
      expect(channel.isChannel, isTrue);
      expect(channel.isBroadcast, isTrue);
    });

    test('fromRaw handles t.ChannelForbidden', () {
      final raw = const t.ChannelForbidden(
        id: 1,
        accessHash: 123,
        title: 'Forbidden',
        broadcast: true,
        megagroup: false,
        monoforum: false,
      );
      final channel = TeliChannel.fromRaw(raw);
      expect(channel.isForbidden, isTrue);
    });

    test('fromRaw handles t.ChatForbidden', () {
      final raw = const t.ChatForbidden(id: 456, title: 'Forbidden');
      final channel = TeliChannel.fromRaw(raw);
      expect(channel.id, equals(456));
      expect(channel.isForbidden, isTrue);
    });
  });

  group('TeliMessage', () {
    test('fromRaw handles t.Message', () {
      final raw = t.Message(
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
      );
      final msg = TeliMessage.fromRaw(raw);
      expect(msg.id, equals(1));
      expect(msg.text, equals('Hello'));
      expect(msg.isService, isFalse);
    });

    test('fromRaw handles t.MessageService', () {
      final raw = t.MessageService(
        out: false,
        mentioned: false,
        mediaUnread: false,
        reactionsArePossible: false,
        silent: false,
        post: false,
        legacy: false,
        id: 789,
        peerId: t.PeerUser(userId: 123),
        date: DateTime.fromMillisecondsSinceEpoch(1600000000 * 1000),
        action: t.MessageActionChatCreate(title: 'Title', users: []),
      );
      final msg = TeliMessage.fromRaw(raw);
      expect(msg.id, equals(789));
      expect(msg.isService, isTrue);
    });
  });
}
