/// 📨 MESSAGE DIRECTION
enum MessageDirection {
  incoming, // Received from customer
  outgoing; // Sent by user

  bool get isIncoming => this == MessageDirection.incoming;
  bool get isOutgoing => this == MessageDirection.outgoing;

  static MessageDirection fromString(String value) {
    return MessageDirection.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageDirection.outgoing,
    );
  }
}
