/// 🤖 BOT TRIGGER TYPE — How the bot is activated
enum BotTriggerType {
  keyword,        // Triggers on specific keywords
  exactMatch,     // Triggers on exact message match
  contains,       // Triggers when message contains text
  startsWith,     // Triggers when message starts with text
  regex,          // Triggers on regex pattern match
  allMessages,    // Triggers on all incoming messages
  welcomeMessage; // Default auto-reply (every message or first only)

  String get label {
    switch (this) {
      case BotTriggerType.keyword:
        return 'Keyword';
      case BotTriggerType.exactMatch:
        return 'Exact Match';
      case BotTriggerType.contains:
        return 'Contains';
      case BotTriggerType.startsWith:
        return 'Starts With';
      case BotTriggerType.regex:
        return 'Regex Pattern';
      case BotTriggerType.allMessages:
        return 'All Messages';
      case BotTriggerType.welcomeMessage:
        return 'Welcome Message';
    }
  }

  String get description {
    switch (this) {
      case BotTriggerType.keyword:
        return 'Triggers when message matches a keyword';
      case BotTriggerType.exactMatch:
        return 'Triggers when message exactly matches';
      case BotTriggerType.contains:
        return 'Triggers when message contains the text';
      case BotTriggerType.startsWith:
        return 'Triggers when message starts with the text';
      case BotTriggerType.regex:
        return 'Triggers when message matches regex pattern';
      case BotTriggerType.allMessages:
        return 'Triggers on every incoming message';
      case BotTriggerType.welcomeMessage:
        return 'Default reply for all messages (welcome/greeting)';
    }
  }

  static BotTriggerType fromString(String value) {
    return BotTriggerType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BotTriggerType.keyword,
    );
  }
}
