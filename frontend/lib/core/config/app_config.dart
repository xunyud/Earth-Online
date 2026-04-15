class AppConfig {
  const AppConfig._();

  static const String evermemosApiKey = String.fromEnvironment(
    'EVERMEMOS_API_KEY',
    defaultValue: '',
  );

  static const String evermemosBaseUrl = String.fromEnvironment(
    'EVERMEMOS_BASE_URL',
    defaultValue: 'https://api.evermind.ai/api/v0',
  );

  static const String evermemosSender = String.fromEnvironment(
    'EVERMEMOS_SENDER',
    defaultValue: 'smart-p-user',
  );

  static const String openaiApiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '',
  );

  static const String openaiBaseUrl = String.fromEnvironment(
    'OPENAI_BASE_URL',
    defaultValue: 'https://api.86gamestore.com',
  );

  static const String openaiChatModel = String.fromEnvironment(
    'OPENAI_CHAT_MODEL',
    defaultValue: 'deepseek-chat',
  );

  static const String agentChatProxyUrl = String.fromEnvironment(
    'AGENT_CHAT_PROXY_URL',
    defaultValue: 'http://127.0.0.1:3000/agent/free-chat',
  );
}
