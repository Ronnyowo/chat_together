import 'package:bale_phone/components/ChatItem.dart';
import 'package:bale_phone/websocket.dart';
import 'package:flutter/material.dart';

class MainPage extends StatefulWidget {
  const MainPage({
    super.key,
    required this.nickname,
    required this.userId,
    required this.userReceiveId,
    required this.baleToken,
  });

  final String nickname;
  final int userId;
  final int userReceiveId;
  final String baleToken;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late BaleWebSocket socket;
  final FocusNode inputFocusNode = FocusNode();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Message> messagesList = <Message>[];

  String currentUserNickname = "";

  @override
  void initState() {
    socket = BaleWebSocket(
      onConnected: (socket) {},
      receiverUserId: widget.userReceiveId,
      userId: widget.userId,
      token: widget.baleToken,
    );

    socket.onMessage.listen((data) {
      if (data.type == 0) return;

      print(data.type);

      switch (data.type) {
        case 100:
          setState(() {
            messagesList.add(
              Message(
                userId: data.userId,
                content: data.data["message"] as String,
              ),
            );
          });

          socket.sendData(101, {"id": data.data["id"]});

          break;
        case 101:
          final messageId = data.data["id"];

          for (int i = 0; i < messagesList.length; i++) {
            if (messagesList[i].id == messageId) {
              print("Received read receipt for message id $messageId");
              setState(() {
                messagesList[i] = Message(
                  id: messagesList[i].id,
                  userId: messagesList[i].userId,
                  content: messagesList[i].content,
                  isSystem: messagesList[i].isSystem,
                  isRead: true,
                );
              });
              break; // Exit the loop once message is found and updated
            }
          }
          break;
        case 200:
          final nickname = data.data["nickname"] as String;
          setState(() {
            messagesList.add(
              Message(
                userId: data.userId,
                content: "User Joined the chat.",
                isSystem: true,
              ),
            );
            currentUserNickname = nickname;
          });
          socket.sendData(201, {"nickname": widget.nickname});
          break;
        case 201:
          final nickname = data.data["nickname"] as String;
          setState(() {
            currentUserNickname = nickname;
          });

        case 300:
          setState(() {
            messagesList.add(
              Message(
                userId: data.userId,
                content: "User leave the chat.",
                isSystem: true,
              ),
            );
            currentUserNickname = ""; // Clear nickname when user leaves
          });
          // Clear the recipient's public key when they leave
          socket.clearRecipientPublicKey();
          break;
        case 500:
          // Handle public key exchange
          if (data.data.containsKey('publicKey')) {
            final publicKey = data.data['publicKey'] as String;
            socket.setRecipientPublicKey(publicKey);
            print('Received and set public key from user ${data.userId}');

            socket.sendPublicKeyReply();
          }
          break;
        case 501:
          if (data.data.containsKey('publicKey')) {
            final publicKey = data.data['publicKey'] as String;
            socket.setRecipientPublicKey(publicKey);
            print('Received and set public key from user ${data.userId}');
            socket.sendData(200, {"nickname": widget.nickname});
          }
          break;
        default:
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    });

    super.initState();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final messageContent = _messageController.text.trim();

    final message = Message(userId: widget.userId, content: messageContent);

    socket.sendData(100, {"message": messageContent, "id": message.id});

    // Add message to local list immediately
    setState(() {
      messagesList.add(message);
    });

    // Clear the text field and keep focus for rapid messaging
    _messageController.clear();
    inputFocusNode.requestFocus();

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    // Send message through WebSocket
    // You can implement the actual sending logic here based on your WebSocket protocol
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    socket.sendData(300, {});
    socket.close();
    socket.onMessage.drain();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentUserNickname.isEmpty
              ? "Waiting for user to connect..."
              : "Chat with ${currentUserNickname}",
        ),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.grey.shade50,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                itemCount: messagesList.length,
                itemBuilder: (context, index) {
                  final message = messagesList[index];
                  final isMe = message.userId == widget.userId;
                  final isSystem = message.isSystem;

                  if (isSystem) {
                    return ChatSystem(message: message.content);
                  }

                  return ChatItem(
                    message: message.content,
                    isMe: isMe,
                    senderName: isMe ? null : currentUserNickname,
                    timestamp: DateTime.fromMillisecondsSinceEpoch(
                      message.timestamp,
                    ),
                    isRead: isMe ? message.isRead : false,
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        focusNode: inputFocusNode,
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: "Type your message...",
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          border: InputBorder.none,
                        ),
                        minLines: 1,
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
