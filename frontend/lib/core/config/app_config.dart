class AppConfig {
  const AppConfig._();

  static const String evermemosApiKey = String.fromEnvironment(
    'EVERMEMOS_API_KEY',
    defaultValue: '2884d783-b412-47ea-a8d9-7f954550d7d0',
  );

  static const String evermemosBaseUrl = String.fromEnvironment(
    'EVERMEMOS_BASE_URL',
    defaultValue: 'https://api.evermind.ai/api/v0',
  );

  static const String evermemosSender = String.fromEnvironment(
    'EVERMEMOS_SENDER',
    defaultValue: 'smart-p-user',
  );
}
