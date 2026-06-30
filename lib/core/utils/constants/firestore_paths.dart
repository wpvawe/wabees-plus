/// 📁 FIRESTORE COLLECTION PATHS - SINGLE SOURCE OF TRUTH
class FirestorePaths {
  FirestorePaths._();

  // User-level collections
  static const String users = 'users';
  static const String messages = 'messages';
  static const String conversations = 'conversations';
  static const String bots = 'bots';
  static const String campaigns = 'campaigns';
  static const String contacts = 'contacts';
  static const String templates = 'templates';
  static const String subscription = 'subscription'; // singular — single doc 'current'
  static const String notifications = 'notifications';
  static const String whatsappConfig = 'whatsapp_config';
  static const String products = 'products';
  static const String logs = 'logs';

  // Global collections
  static const String plans = 'plans';
  static const String supportChats = 'support_chats';
  static const String adminNotifications = 'admin_notifications';
  static const String config = 'config';
  static const String analytics = 'analytics';
  static const String pendingSubscriptions = 'pending_subscriptions';

  // Deprecated alias — kept for backward compat
  @Deprecated('Use subscription instead')
  static const String subscriptions = 'subscription';
}
