enum MessageType { text, image, file }

class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final int timestamp;
  final String? fileUrl;
  final MessageType messageType;
  final String? fileName;
  final int? fileSize;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    this.fileUrl,
    this.messageType = MessageType.text,
    this.fileName,
    this.fileSize,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      text: map['text'],
      senderId: map['senderId'],
      timestamp: map['timestamp'],
      fileUrl: map['fileUrl'],
      messageType: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${map['messageType'] ?? 'text'}',
        orElse: () => MessageType.text,
      ),
      fileName: map['fileName'],
      fileSize: map['fileSize'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'text': text,
    'senderId': senderId,
    'timestamp': timestamp,
    'fileUrl': fileUrl,
    'messageType': messageType.toString().split('.').last,
    'fileName': fileName,
    'fileSize': fileSize,
  };
} 