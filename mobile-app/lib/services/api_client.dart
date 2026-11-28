import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/models.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final String apiBaseUrl = AppConfig.apiBaseUrl;
  String? accessToken;
  UserProfileModel? currentUser;
  String selectedLocation = 'All Locations';

  Map<String, String> _headers({String? idempotencyKey}) {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null && accessToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer $accessToken';
    }
    if (idempotencyKey != null) h['Idempotency-Key'] = idempotencyKey;
    return h;
  }

  String _genKey(String prefix) {
    final r = Random();
    final randHex = List.generate(8, (_) => r.nextInt(16).toRadixString(16)).join();
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}-$randHex';
  }

  dynamic _decode(http.Response res) => res.body.isEmpty ? {} : jsonDecode(res.body);

  Uri getGoogleOAuthUri() => Uri.parse(
        '${AppConfig.supabaseUrl}/auth/v1/authorize?provider=google&redirect_to=${Uri.encodeComponent("${AppConfig.apiBaseUrl}/admin/")}',
      );

  Future<void> initPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    selectedLocation = prefs.getString('mc_location') ?? 'All Locations';
  }

  Future<void> saveLocation(String loc) async {
    selectedLocation = loc;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mc_location', loc);
  }

  Future<List<String>> getRecentAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('mc_recent_emails') ?? [];
  }

  Future<void> _rememberAccount(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('mc_recent_emails') ?? [];
    list.remove(email);
    list.insert(0, email);
    if (list.length > 5) list.removeLast();
    await prefs.setStringList('mc_recent_emails', list);
  }

  Future<UserProfileModel> signIn(String email, String password) async {
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
    final profile = await syncMe();
    await _rememberAccount(profile.email);
    return profile;
  }

  Future<UserProfileModel> signUp(String email, String password) async {
    final res = await http.post(
      Uri.parse('${AppConfig.supabaseUrl}/auth/v1/signup'),
      headers: {'apikey': AppConfig.supabaseKey, 'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = _decode(res);
    if (res.statusCode >= 400) {
      throw Exception(data['error_description'] ?? data['msg'] ?? data['message'] ?? data['error'] ?? res.body);
    }
    if (data['access_token'] != null) {
      accessToken = data['access_token'];
      await syncMe();
    } else {
      await signIn(email, password);
    }
    // Sync custom 24-36 char dictionary hash immediately to public.users
    final profile = await updateProfile(rawPassword: password);
    await _rememberAccount(profile.email);
    return profile;
  }

  Future<UserProfileModel> signInWithToken(String jwtToken) async {
    accessToken = jwtToken.trim();
    final profile = await syncMe();
    await _rememberAccount(profile.email);
    return profile;
  }

  void logout() {
    accessToken = null;
    currentUser = null;
  }

  Future<UserProfileModel> syncMe() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/v1/auth/me'), headers: _headers());
    final data = _decode(res);
    if (res.statusCode >= 400) throw Exception(data['detail'] ?? 'Auth sync failed');
    currentUser = UserProfileModel.fromJson(data);
    return currentUser!;
  }

  Future<UserProfileModel> setLoginPassword(String newPassword) async {
    // 1. Bind password to the exact same Supabase user_id (merges Google + Email/Password login)
    final sbRes = await http.put(
      Uri.parse('${AppConfig.supabaseUrl}/auth/v1/user'),
      headers: {
        'apikey': AppConfig.supabaseKey,
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'password': newPassword}),
    );
    final sbData = _decode(sbRes);
    if (sbRes.statusCode >= 400) {
      throw Exception(sbData['msg'] ?? sbData['message'] ?? sbData['error_description'] ?? 'Failed to set password');
    }
    // 2. Sync 24-36 char custom dictionary hash to public.users
    return await updateProfile(rawPassword: newPassword);
  }

  Future<UserProfileModel> updateProfile({String? fullName, String? rawPassword}) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (rawPassword != null) body['raw_password'] = rawPassword;
    final res = await http.patch(
      Uri.parse('$apiBaseUrl/api/v1/auth/me'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    final data = _decode(res);
    if (res.statusCode >= 400) throw Exception(data['detail'] ?? 'Profile update failed');
    currentUser = UserProfileModel.fromJson(data);
    return currentUser!;
  }

  Future<List<MovieModel>> getMovies() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/v1/movies'), headers: _headers());
    final data = _decode(res);
    if (res.statusCode >= 400) throw Exception(data['detail'] ?? 'Failed to load movies');
    return (data as List).map((e) => MovieModel.fromJson(e)).toList();
  }

  Future<List<CinemaModel>> getCinemas() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/v1/cinemas'), headers: _headers());
    final data = _decode(res);
    if (res.statusCode >= 400) throw Exception(data['detail'] ?? 'Failed to load cinemas');
    return (data as List).map((e) => CinemaModel.fromJson(e)).toList();
  }

  Future<RecommendationsModel> getRecommendations() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/v1/recommendations'), headers: _headers());
    final data = _decode(res);
    if (res.statusCode >= 400) throw Exception(data['detail'] ?? 'Failed to load recommendations');
    return RecommendationsModel.fromJson(data);
  }

  Future<void> toggleBookmark(String movieId, bool currentlyBookmarked) async {
    final uri = Uri.parse('$apiBaseUrl/api/v1/bookmarks/$movieId');
    final res = currentlyBookmarked
        ? await http.delete(uri, headers: _headers())
        : await http.post(uri, headers: _headers());
    if (res.statusCode >= 400) {
      final data = _decode(res);
      throw Exception(data['detail'] ?? 'Bookmark update failed');
    }
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

  Future<Map<String, dynamic>> aiChat(String prompt, {String? location, String? model}) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/v1/ai/chat'),
      headers: _headers(),
      body: jsonEncode({'prompt': prompt, 'location': location, if (model != null) 'model': model}),
    );
    final data = _decode(res);
    if (res.statusCode >= 400) throw Exception(data['detail'] ?? 'AI chat failed');
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> aiPickSeats(String showtimeId, int partySize, String preference, {String? model}) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/v1/ai/seat-pick'),
      headers: _headers(),
      body: jsonEncode({
        'showtime_id': showtimeId,
        'party_size': partySize,
        'preference': preference,
        if (model != null) 'model': model,
      }),
    );
    final data = _decode(res);
    if (res.statusCode >= 400) throw Exception(data['detail'] ?? 'AI seat pick failed');
    return data as Map<String, dynamic>;
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

