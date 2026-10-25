import 'dart:convert';
import 'package:http/http.dart' as http;

class VatanApi {
  VatanApi({this.baseUrl = 'https://binercraft.ir/api'});
  final String baseUrl;

  Future<Map<String, dynamic>> request(String path, {String? token, String method = 'GET', Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Accept':'application/json','Content-Type':'application/json',if(token!=null)'Authorization':'Bearer $token'};
    late http.Response response;
    try {
      if (method == 'POST') {
        response = await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 20));
      } else if (method == 'PATCH') {
        response = await http.patch(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 20));
      } else if (method == 'DELETE') {
        response = await http.delete(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 20));
      } else {
        response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));
      }
    } catch (_) {
      throw VatanApiException('اتصال به سرور وطن برقرار نشد. اینترنت و وضعیت API را بررسی کن.');
    }
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) { data = <String, dynamic>{}; }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw VatanApiException((data['error'] ?? 'خطای سرور (${response.statusCode})').toString(), response.statusCode);
    }
    return data;
  }

  Future<Map<String, dynamic>> register(String username, String displayName, String password) =>
      request('/auth/register', method: 'POST', body: {'username': username, 'displayName': displayName, 'password': password});
  Future<Map<String, dynamic>> login(String username, String password) =>
      request('/auth/login', method: 'POST', body: {'username': username, 'password': password});
  Future<Map<String, dynamic>> me(String token) => request('/auth/me', token: token);
  Future<void> logout(String token) async { await request('/auth/logout', token: token, method: 'POST'); }
  Future<List<Map<String, dynamic>>> conversations(String token) async =>
      _list(await request('/conversations', token: token), 'conversations');
  Future<Map<String, dynamic>> createConversation(String token, String type, String title, String description) async =>
      (await request('/conversations', token: token, method: 'POST', body: {'type': type, 'title': title, 'description': description}))['conversation'] as Map<String, dynamic>;
  Future<List<Map<String, dynamic>>> messages(String token, String id) async =>
      _list(await request('/messages?conversation_id=${Uri.encodeQueryComponent(id)}&limit=50', token: token), 'messages');
  Future<Map<String, dynamic>> sendMessage(String token, String id, String body) async =>
      (await request('/messages', token: token, method: 'POST', body: {'conversation_id': int.tryParse(id) ?? id, 'body': body}))['message'] as Map<String, dynamic>;
  Future<void> updateProfile(String token, Map<String, dynamic> values) async {
    await request('/auth/profile', token: token, method: 'PATCH', body: values);
  }
  List<Map<String, dynamic>> _list(Map<String, dynamic> data, String key) =>
      (data[key] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}
class VatanApiException implements Exception {
  VatanApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override String toString() => message;
}
