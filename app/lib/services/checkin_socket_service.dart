// lib/services/checkin_socket_service.dart
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../model/checkin_frame.dart';

/// One instance of this class = one check-in conversation = one open socket.
class CheckinSocketService {
  final WebSocketChannel _channel;

  CheckinSocketService(String serverUrl, String sessionId)
      : _channel = WebSocketChannel.connect(
          Uri.parse('$serverUrl/ws/checkin/$sessionId'),
        );

  /// Incoming frames, decoded String -> Map -> typed CheckinFrame.
  Stream<CheckinFrame> get frames {
    return _channel.stream.map((rawMessage) {
      var decoded = json.decode(rawMessage);       
      var frame = CheckinFrame.fromJson(decoded);  
      return frame;
    });
  }

  /// Send the FIRST message of a check-in (the user's situation).
  void start(String situationText, {String language = 'en', String countryCode = 'IN'}) {
    var msg = {
      "text": situationText,
      "language": language,
      "country_code": countryCode,
    };
    var msgJson = json.encode(msg);
    _channel.sink.add(msgJson);
  }

  /// Send an ANSWER to whatever question was just asked.
  void answer(String answerText) {
    var msg = {"text": answerText};
    var msgJson = json.encode(msg);
    _channel.sink.add(msgJson);
  }

  void dispose() {
    _channel.sink.close();
  }
}