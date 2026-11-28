import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/models.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String apiBaseUrl = AppConfig.defaultApiBaseUrl;
  String? accessToken;
  String? userEmail;

  Map<String, String> _headers({String? idempotencyKey}) {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null && accessToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer $accessToken';
    }
    if (idempotencyKey != null) {
      h['Idempotency-Key'] = idempotencyKey;
    }
    return h;
  }

  String _genKey(String prefix) {
    final r = Random();
    final randHex = List.generate(8, (_) => r.nextInt(16).toRadixString(16)).join();
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}-$randHex';
  }

  dynamic _decode(http.Response res) {
    if (res.body.isEmpty) return {};
    return jsonDecode(res.body);
  }

  Future<void> signIn(String email, String password) async {
    final res = await http.post(
      Uri.parse('${AppConfig.supabaseUrl}/auth/v1/token?grant_type=password'),
      headers: {'apikey': AppConfig.supabaseKey, 'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = _decode(res);
    if (res.statusCode >= 400) {
      throw Exception(data['error_description'] ?? data['msg'] ?? 'Login failed');
    }
    accessToken = data['access_token'];
    await syncMe();
  }

  Future<void> signUp(String email, String password) async {
    final res = await http.post(
      Uri.parse('${AppConfig.supabaseUrl}/auth/v1/signup'),
      headers: {'apikey': AppConfig.supabaseKey, 'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = _decode(res);
    if (res.statusCode >= 400) {
      throw Exception(data['error_description'] ?? data['msg'] ?? data['message'] ?? 'Sign up failed');
    }
    if (data['access_token'] != null) {
      accessToken = data['access_token'];
      await syncMe();
    } else {
      await signIn(email, password);
    }
  }

  void logout() {
    accessToken = null;
    userEmail = null;
  }

  Future<void> syncMe() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/v1/auth/me'), headers: _headers());
    final data = _decode(res);
    if (res.statusCode >= 400) throw Exception(data['detail'] ?? 'Auth sync failed');
    userEmail = data['email'];
  }

  Future<List<MovieModel>> getMovies() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/v1/movies'), headers: _headers());
    final data = _decode(res);
    if (res.statusCode >= 400) throw Exception(data['detail'] ?? 'Failed to load movies');
    return (data as List).map((e) => MovieModel.fromJson(e)).toList();
  }

  Future<List<ShowtimeModel>> getShowtimes(String movieId) async {
    final res = await http.get(
      Uri.parse('$apiBaseUrl/api/v1/showtimes?movie_id=$movieId'),
      headers: _headers(),
    );
    final data = _decode(res);
    if (res.statusCode >= 400) throw Exception(data['detail'] ?? 'Failed to load showtimes');
    return (data as List).map((e) => ShowtimeModel.fromJson(e)).toList();
  }

  Future<SeatMapModel> getSeatMap(String showtimeId) async {
    final res = await http.get(
      Uri.parse('$apiBaseUrl/api/v1/showtimes/$showtimeId/seats'),
      headers: _headers(),
    );
    final data = _decode(res);
    if (res.statusCode >= 400) throw Exception(data['detail'] ?? 'Failed to load seat map');
    return SeatMapModel.fromJson(data);
  }

  Future<OrderModel> createOrder(String showtimeId, List<String> seatIds) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/v1/orders'),
      headers: _headers(idempotencyKey: _genKey('ord')),
      body: jsonEncode({'showtime_id': showtimeId, 'showtime_seat_ids': seatIds}),
    );
    final data = _decode(res);
    if (res.statusCode >= 400) throw Exception(data['detail'] ?? 'Seat hold failed');
    return OrderModel.fromJson(data);
  }

  Future<Map<String, dynamic>> payOrder(String orderId, String scenario) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/v1/orders/$orderId/pay'),
      headers: _headers(idempotencyKey: _genKey('pay')),
      body: jsonEncode({'scenario': scenario}),
    );
    final data = _decode(res) as Map<String, dynamic>;
    // 200=SUCCEEDED, 402=FAILED, 504=TIMEOUT are expected mock outcomes
    if (res.statusCode == 200 || res.statusCode == 402 || res.statusCode == 504) {
      return {'http_status': res.statusCode, ...data};
    }
    throw Exception(data['detail'] ?? 'Payment error (${res.statusCode})');
  }

  Future<List<OrderModel>> getMyOrders() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/v1/orders'), headers: _headers());
    final data = _decode(res);
    if (res.statusCode >= 400) throw Exception(data['detail'] ?? 'Failed to load orders');
    return (data as List).map((e) => OrderModel.fromJson(e)).toList();
  }

  Future<OrderModel> getOrderDetail(String orderId) async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/v1/orders/$orderId'), headers: _headers());
    final data = _decode(res);
    if (res.statusCode >= 400) throw Exception(data['detail'] ?? 'Failed to load order');
    return OrderModel.fromJson(data);
  }

  Future<void> refundOrder(String orderId, String reason) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/v1/orders/$orderId/refund'),
      headers: _headers(),
      body: jsonEncode({'reason': reason}),
    );
    final data = _decode(res);
    if (res.statusCode >= 400) throw Exception(data['detail'] ?? 'Refund rejected');
  }
}
