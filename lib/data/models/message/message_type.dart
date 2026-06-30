/// 📨 MESSAGE TYPE
enum MessageType {
  text,
  image,
  video,
  audio,
  document,
  template,
  interactive,
  button,
  location,
  contact,
  sticker,
  reaction,
  order,
  system,
  unsupported;

  String get label {
    switch (this) {
      case MessageType.text:
        return 'Text';
      case MessageType.image:
        return 'Image';
      case MessageType.video:
        return 'Video';
      case MessageType.audio:
        return 'Audio';
      case MessageType.document:
        return 'Document';
      case MessageType.template:
        return 'Template';
      case MessageType.interactive:
        return 'Reply';
      case MessageType.button:
        return 'Button Reply';
      case MessageType.location:
        return 'Location';
      case MessageType.contact:
        return 'Contact';
      case MessageType.sticker:
        return 'Sticker';
      case MessageType.reaction:
        return 'Reaction';
      case MessageType.order:
        return 'Order';
      case MessageType.system:
        return 'System';
      case MessageType.unsupported:
        return 'Message';
    }
  }

  bool get isMedia =>
      this == MessageType.image ||
      this == MessageType.video ||
      this == MessageType.audio ||
      this == MessageType.document;

  static MessageType fromString(String value) {
    return MessageType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageType.text,
    );
  }
}
