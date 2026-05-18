class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ndbhxjvrgxeuyykrlyxl.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_oqeYb0IhGpRlPmYCWqLomQ_Jr4yrwT9',
  );

  static const String evermemosApiKey = String.fromEnvironment(
    'EVERMEMOS_API_KEY',
    defaultValue: '03c09b42-c9a0-4565-a0ef-33bc8be1b2e9',
  );

  static const String evermemosBaseUrl = String.fromEnvironment(
    'EVERMEMOS_BASE_URL',
    defaultValue: 'https://api.evermind.ai/api/v1',
  );

  static const String evermemosSender = String.fromEnvironment(
    'EVERMEMOS_SENDER',
    defaultValue: 'smart-p-user',
  );

  static const String openaiChatModel = String.fromEnvironment(
    'OPENAI_CHAT_MODEL',
    defaultValue: 'deepseek-chat',
  );

  static const String agentChatProxyUrl = String.fromEnvironment(
    'AGENT_CHAT_PROXY_URL',
    defaultValue: 'http://127.0.0.1:3000/agent/free-chat',
  );

  /// 微信功能开关（暂时隐藏，待安全加固后重新启用）
  static const bool wechatEnabled = false;
}
