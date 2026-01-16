import 'package:flutter/material.dart';

class ChatItem extends StatelessWidget {
  const ChatItem({
    super.key,
    required this.message,
    required this.isMe,
    this.senderName,
    this.timestamp,
    this.isRead = false,
  });

  final String message;
  final bool isMe;
  final String? senderName;
  final DateTime? timestamp;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) _buildAvatar(),
          if (!isMe) const SizedBox(width: 8.0),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe && senderName != null) _buildSenderName(),
                _buildMessageBubble(context),
                if (timestamp != null) _buildTimestamp(),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8.0),
          if (isMe) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 16,
      backgroundColor: isMe ? Colors.blue.shade200 : Colors.grey.shade300,
      child: Icon(
        Icons.person,
        size: 20,
        color: isMe ? Colors.blue.shade700 : Colors.grey.shade600,
      ),
    );
  }

  Widget _buildSenderName() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0, left: 12.0),
      child: Text(
        senderName!,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: isMe ? Colors.blue.shade500 : Colors.grey.shade200,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            message,
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestamp() {
    return Row(
      spacing: 4,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 4.0),
          child: Text(
            _formatTimestamp(timestamp!),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ),
        if (isMe) ...[
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade500,
              shape: BoxShape.circle,
            ),
          ),
          if (isRead)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Icon(Icons.done_all, size: 16, color: Colors.black54),
            ),
          if (!isRead)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Icon(Icons.access_time, size: 16, color: Colors.black54),
            ),
        ],
      ],
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // Same day - show time only
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      final weekday = [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ][dateTime.weekday - 1];
      return weekday;
    } else {
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      return '$day/$month';
    }
  }
}

class ChatSystem extends StatelessWidget {
  const ChatSystem({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
