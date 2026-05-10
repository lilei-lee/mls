import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/qna_thread.dart';

class QnaException implements Exception {
  final String message;
  QnaException(this.message);
  @override String toString() => message;
}

class QnaService {
  QnaService._();
  static final instance = QnaService._();
  Dio get _dio => ApiClient.instance.dio;

  Future<QnaListResp> getList(String listingId, {int limit = 20, int offset = 0, String status = 'all'}) async {
    final resp = await _dio.get('/listings/$listingId/qna', queryParameters: {'limit': limit, 'offset': offset, 'status': status});
    return QnaListResp.fromJson(resp.data['data'] as Map<String, dynamic>);
  }

  Future<String> ask(String listingId, String question) async {
    try {
      final resp = await _dio.post('/listings/$listingId/qna', data: {'question': question});
      return resp.data['data']['thread_id'] as String;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? '提问失败';
      throw QnaException(msg.toString());
    }
  }

  Future<void> answer(String threadId, String answer) async {
    try {
      await _dio.post('/qna/$threadId/answer', data: {'answer': answer});
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? '回答失败';
      throw QnaException(msg.toString());
    }
  }

  Future<void> delete(String threadId) async {
    try {
      await _dio.delete('/qna/$threadId');
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? '删除失败';
      throw QnaException(msg.toString());
    }
  }
}
