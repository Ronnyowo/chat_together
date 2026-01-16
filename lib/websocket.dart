import 'dart:convert';

import 'package:bale_phone/encryption_utils.dart';
import 'package:pointycastle/export.dart';
import 'package:web_socket_channel/io.dart';

class Message {
  final int id;
  final int userId;
  final String content;
  final int timestamp;
  final bool isSystem;
  final bool isRead;

  Message({
    required this.userId,
    required this.content,
    int? timestamp,
    int? id,
    this.isRead = false,
    this.isSystem = false,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch,
       id = id ?? DateTime.now().millisecondsSinceEpoch;
}

IOWebSocketChannel createWebSocketChannel(String token) {
  final channel = IOWebSocketChannel.connect(
    Uri.parse("wss://next-ws.bale.ai/ws/"),
    headers: {
      "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:146.0) Gecko/20100101 Firefox/146.0",
      "Cookie": "access_token=${token}",
      "Origin": "https://web.bale.ai",
    },
  );

  return channel;
}

class SocketData {
  final int type;
  final int userId;
  final Map<String, dynamic> data;

  SocketData({required this.type, required this.data, required this.userId});
}

class BaleWebSocket {
  late IOWebSocketChannel channel;
  final BaleConfigsCodec codec = BaleConfigsCodec();
  late final RsaEncryptor rsaEncryptor;
  RSAPublicKey? recipientPublicKey;

  final int userId;
  final int receiverUserId;

  final Function(BaleWebSocket)? onConnected;

  late final Stream<SocketData> _messageStream;

  BaleWebSocket({
    required String token,
    required this.userId,
    required this.receiverUserId,
    this.onConnected,
  }) {
    channel = createWebSocketChannel(token);
    rsaEncryptor = RsaEncryptor.generate();
    onConnected?.call(this);
    _setupMessageStream();

    // Send our public key when first connecting
    _sendPublicKey(500);
  }

  void _setupMessageStream() {
    _messageStream = channel.stream.map((data) {
      final parsed = codec.parseMessage(data);
      if (parsed == null) {
        return SocketData(type: 0, userId: 0, data: {});
      }

      if (parsed.userId != receiverUserId) {
        return SocketData(type: 0, userId: 0, data: {});
      }
      
      try {
        // First try to decode as JSON (for unencrypted public key messages)
        Map<String, dynamic> decryptedData;
        try {
          decryptedData = jsonDecode(parsed.content);
          // If it's a public key message (type 500), return it directly
          if (decryptedData['type'] < 600 && decryptedData['type'] >= 500) {
            
            return SocketData(
              type: decryptedData['type'] ?? 0,
              userId: parsed.userId,
              data: decryptedData,
            );
          }
        } catch (_) {
          // Not JSON, try decryption
        }

        // Try to decrypt the message
        decryptedData = jsonDecode(rsaEncryptor.decrypt(parsed.content));
        return SocketData(
          type: decryptedData['type'] ?? 0,
          userId: parsed.userId,
          data: decryptedData,
        );
      } catch (e) {
        // Return raw data if decryption fails
        return SocketData(
          type: 0,
          userId: parsed.userId,
          data: {'content': parsed.content, 'error': e.toString()},
        );
      }
    }).asBroadcastStream();
  }

  void sendData(int type, Map<String, dynamic> data) {
    final messageContent = jsonEncode({"type": type, ...data});

    String encryptedMessage;
    if (recipientPublicKey != null && type != 500) {
      // Don't encrypt public key messages
      // Use recipient's public key for encryption
      encryptedMessage = RsaEncryptor.encryptWithPublicKey(
        recipientPublicKey!,
        messageContent,
      );
    } else {
      // Use our own encryptor for public key exchange or fallback
      encryptedMessage = rsaEncryptor.encrypt(messageContent);
    }

    final encodedMessage = codec.createMessage(
      message: encryptedMessage,
      userId: userId,
    );

    channel.sink.add(encodedMessage);
  }

  Stream<SocketData> get onMessage => _messageStream;

  void _sendPublicKey(int type) {
    // Send our public key as an unencrypted message
    final publicKeyData = {
      "type": type,
      "publicKey": rsaEncryptor.publicKeyBase64,
    };

    final encodedMessage = codec.createMessage(
      message: jsonEncode(publicKeyData),
      userId: userId,
    );

    channel.sink.add(encodedMessage);
  }

  void setRecipientPublicKey(String publicKeyBase64) {
    try {
      recipientPublicKey = RsaEncryptor.parsePublicKeyBase64(publicKeyBase64);
      print('Recipient public key set successfully');
    } catch (e) {
      print('Error setting recipient public key: $e');
    }
  }

  void clearRecipientPublicKey() {
    recipientPublicKey = null;
    print('Recipient public key cleared');
  }

  void sendPublicKeyExchange() {
    _sendPublicKey(500);
  }

  void sendPublicKeyReply() {
    _sendPublicKey(501);
  }

  void close() {
    channel.sink.close();
  }
}
