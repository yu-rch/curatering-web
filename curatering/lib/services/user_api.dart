import '../services/api_client.dart';

class UserApi {
  UserApi._();

  static final UserApi instance = UserApi._();

  Future<void> requestHelp({required String issue}) async {
    final trimmed = issue.trim();
    await ApiClient.instance.postJson(
      '/api/help-requests',
      body: {
        'feature': 'Settings',
        'problem': trimmed,
        'request': 'Resolve: $trimmed',
      },
    );
  }
}

