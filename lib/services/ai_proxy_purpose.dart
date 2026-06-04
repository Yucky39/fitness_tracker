/// geminiProxy に渡す用途キー。サーバー側で maxTokens の上限を用途別にクランプする。
enum AiProxyPurpose {
  coach('coach'),
  nutrition('nutrition'),
  trainingAdvice('training_advice'),
  trainingPlan('training_plan'),
  mealSuggestion('meal_suggestion'),
  review('review'),
  stretch('stretch'),
  bodyProgress('body_progress'),
  vision('vision'),
  general('default');

  const AiProxyPurpose(this.key);
  final String key;
}
