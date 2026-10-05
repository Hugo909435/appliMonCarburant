import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

/// Sends "Signaler un problème" messages through Formspree, which forwards
/// them by e-mail to the address tied to the [AppConfig.feedbackFormId]
/// form. The app never holds that address, so users never see it.
class FeedbackService {
  FeedbackService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Throws if the message could not be delivered. [replyTo] is the user's
  /// own address, when they gave one, so the e-mail can be answered.
  Future<void> send({
    required String message,
    required String appVersion,
    String? replyTo,
  }) async {
    final response = await _client
        .post(
          Uri.parse('https://formspree.io/f/${AppConfig.feedbackFormId}'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            '_subject': 'Mon Carburant — problème signalé',
            'message': message,
            'version': appVersion,
            // Formspree fait de `email` l'adresse de réponse du message.
            if (replyTo != null && replyTo.isNotEmpty) 'email': replyTo,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final ok =
        response.statusCode == 200 &&
        (jsonDecode(response.body) as Map)['ok'] == true;
    if (!ok) {
      throw Exception('Envoi refusé (HTTP ${response.statusCode})');
    }
  }
}
