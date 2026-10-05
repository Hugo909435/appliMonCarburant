import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mon_carburant_app/data/services/feedback_service.dart';

void main() {
  test('posts the message, version and reply address', () async {
    late Map<String, dynamic> sent;
    final service = FeedbackService(
      client: MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"ok":true}', 200);
      }),
    );

    await service.send(
      message: 'Station manquante à La Ferrière',
      appVersion: 'Version 1.0.0 (5)',
      replyTo: 'moi@exemple.fr',
    );

    expect(sent['message'], 'Station manquante à La Ferrière');
    expect(sent['version'], 'Version 1.0.0 (5)');
    expect(sent['email'], 'moi@exemple.fr');
  });

  test('leaves out an empty reply address', () async {
    late Map<String, dynamic> sent;
    final service = FeedbackService(
      client: MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"ok":true}', 200);
      }),
    );
    await service.send(message: 'Bug', appVersion: '', replyTo: '');
    expect(sent.containsKey('email'), isFalse);
  });

  test('throws when Formspree refuses the message', () async {
    final service = FeedbackService(
      client: MockClient((_) async => http.Response('{"errors":[]}', 400)),
    );
    expect(
      service.send(message: 'Bug', appVersion: ''),
      throwsA(isA<Exception>()),
    );
  });
}
