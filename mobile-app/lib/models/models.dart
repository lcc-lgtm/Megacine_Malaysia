double _toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;

String formatMYT(String? isoStr) {
  if (isoStr == null || isoStr.isEmpty) return '-';
  final dt = DateTime.tryParse(isoStr)?.toUtc().add(const Duration(hours: 8));
  if (dt == null) return isoStr;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)} MYT';
}

class UserProfileModel {
  final String id, email;
  final String? fullName;
  final bool hasCustomHash;

  UserProfileModel({
    required this.id,
    required this.email,
    this.fullName,
    this.hasCustomHash = false,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> j) => UserProfileModel(
        id: j['id'],
        email: j['email'],
        fullName: j['full_name'],
        hasCustomHash: j['has_custom_hash'] == true,
      );
}

class AuditoriumBriefModel {
  final String id, name;
  final int totalRows, totalCols;

  AuditoriumBriefModel({required this.id, required this.name, required this.totalRows, required this.totalCols});

  factory AuditoriumBriefModel.fromJson(Map<String, dynamic> j) => AuditoriumBriefModel(
        id: j['id'],
        name: j['name'],
        totalRows: j['total_rows'] ?? 0,
        totalCols: j['total_cols'] ?? 0,
      );
}

class CinemaModel {
  final String id, name, address, city, state;
  final List<AuditoriumBriefModel> auditoriums;

  CinemaModel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.auditoriums,
  });

  factory CinemaModel.fromJson(Map<String, dynamic> j) => CinemaModel(
        id: j['id'],
        name: j['name'],
        address: j['address'] ?? '',
        city: j['city'] ?? '',
        state: j['state'] ?? '',
        auditoriums: (j['auditoriums'] as List? ?? []).map((e) => AuditoriumBriefModel.fromJson(e)).toList(),
      );
}

class MovieModel {
  final String id, title, language, status;
  final String? synopsis, rating, posterUrl, genre, trailerUrl, selectionWeek, releaseDate;
  final int durationMinutes;

  MovieModel({
    required this.id,
    required this.title,
    required this.durationMinutes,
    required this.language,
    required this.status,
    this.synopsis,
    this.rating,
    this.posterUrl,
    this.genre,
    this.trailerUrl,
    this.selectionWeek,
    this.releaseDate,
  });

  factory MovieModel.fromJson(Map<String, dynamic> j) => MovieModel(
        id: j['id'],
        title: j['title'],
        synopsis: j['synopsis'],
        durationMinutes: j['duration_minutes'] ?? 0,
        rating: j['rating'],
        language: j['language'] ?? 'English',
        posterUrl: j['poster_url'],
        genre: j['genre'],
        trailerUrl: j['trailer_url'],
        selectionWeek: j['selection_week'],
        releaseDate: j['release_date'],
        status: j['status'] ?? 'NOW_SHOWING',
      );
}

class RecommendationsModel {
  final List<String> preferredGenres;
  final Set<String> bookmarkedMovieIds;
  final List<MovieModel> movies;

  RecommendationsModel({
    required this.preferredGenres,
    required this.bookmarkedMovieIds,
    required this.movies,
  });

  factory RecommendationsModel.fromJson(Map<String, dynamic> j) => RecommendationsModel(
        preferredGenres: List<String>.from(j['preferred_genres'] ?? []),
        bookmarkedMovieIds: Set<String>.from(j['bookmarked_movie_ids'] ?? []),
        movies: (j['movies'] as List? ?? []).map((e) => MovieModel.fromJson(e)).toList(),
      );
}

class ShowtimeModel {
  final String id, movieId, movieTitle, cinemaId, cinemaName, auditoriumId, auditoriumName, startTime, endTime, status;
  final double basePrice;

  ShowtimeModel({
    required this.id,
    required this.movieId,
    required this.movieTitle,
    required this.cinemaId,
    required this.cinemaName,
    required this.auditoriumId,
    required this.auditoriumName,
    required this.startTime,
    required this.endTime,
    required this.basePrice,
    required this.status,
  });

  factory ShowtimeModel.fromJson(Map<String, dynamic> j) => ShowtimeModel(
        id: j['id'],
        movieId: j['movie_id'],
        movieTitle: j['movie_title'],
        cinemaId: j['cinema_id'],
        cinemaName: j['cinema_name'],
        auditoriumId: j['auditorium_id'],
        auditoriumName: j['auditorium_name'],
        startTime: j['start_time'],
        endTime: j['end_time'],
        basePrice: _toDouble(j['base_price']),
        status: j['status'],
      );
}

class ShowtimeSeatModel {
  final String showtimeSeatId, seatId, rowLabel, seatZone, seatType, status;
  final int seatNumber, version;
  final double price;

  ShowtimeSeatModel({
    required this.showtimeSeatId,
    required this.seatId,
    required this.rowLabel,
    required this.seatNumber,
    required this.seatZone,
    required this.seatType,
    required this.price,
    required this.status,
    required this.version,
  });

  String get label => '$rowLabel$seatNumber';

  factory ShowtimeSeatModel.fromJson(Map<String, dynamic> j) => ShowtimeSeatModel(
        showtimeSeatId: j['showtime_seat_id'],
        seatId: j['seat_id'],
        rowLabel: j['row_label'],
        seatNumber: j['seat_number'],
        seatZone: j['seat_zone'],
        seatType: j['seat_type'],
        price: _toDouble(j['price']),
        status: j['status'],
        version: j['version'] ?? 1,
      );
}

class SeatMapModel {
  final String showtimeId, auditoriumName;
  final int totalRows, totalCols;
  final List<ShowtimeSeatModel> seats;

  SeatMapModel({
    required this.showtimeId,
    required this.auditoriumName,
    required this.totalRows,
    required this.totalCols,
    required this.seats,
  });

  factory SeatMapModel.fromJson(Map<String, dynamic> j) => SeatMapModel(
        showtimeId: j['showtime_id'],
        auditoriumName: j['auditorium_name'],
        totalRows: j['total_rows'],
        totalCols: j['total_cols'],
        seats: (j['seats'] as List).map((e) => ShowtimeSeatModel.fromJson(e)).toList(),
      );
}

class OrderItemModel {
  final String id, showtimeSeatId, rowLabel, seatZone;
  final int seatNumber;
  final double unitPrice;

  OrderItemModel({
    required this.id,
    required this.showtimeSeatId,
    required this.rowLabel,
    required this.seatNumber,
    required this.seatZone,
    required this.unitPrice,
  });

  String get label => '$rowLabel$seatNumber';

  factory OrderItemModel.fromJson(Map<String, dynamic> j) => OrderItemModel(
        id: j['id'],
        showtimeSeatId: j['showtime_seat_id'],
        rowLabel: j['row_label'],
        seatNumber: j['seat_number'],
        seatZone: j['seat_zone'],
        unitPrice: _toDouble(j['unit_price']),
      );
}

class TicketModel {
  final String id, ticketCode, qrPayload, status, issuedAt;
  final String? usedAt;

  TicketModel({
    required this.id,
    required this.ticketCode,
    required this.qrPayload,
    required this.status,
    required this.issuedAt,
    this.usedAt,
  });

  factory TicketModel.fromJson(Map<String, dynamic> j) => TicketModel(
        id: j['id'],
        ticketCode: j['ticket_code'],
        qrPayload: j['qr_payload'],
        status: j['status'],
        issuedAt: j['issued_at'],
        usedAt: j['used_at'],
      );
}

class OrderModel {
  final String id, orderNo, userId, showtimeId, status, holdExpiresAt, createdAt;
  final double subtotalAmount, discountAmount, totalAmount;
  final List<OrderItemModel> items;
  final List<TicketModel> tickets;

  OrderModel({
    required this.id,
    required this.orderNo,
    required this.userId,
    required this.showtimeId,
    required this.status,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.holdExpiresAt,
    required this.createdAt,
    required this.items,
    required this.tickets,
  });

  factory OrderModel.fromJson(Map<String, dynamic> j) => OrderModel(
        id: j['id'],
        orderNo: j['order_no'],
        userId: j['user_id'],
        showtimeId: j['showtime_id'],
        status: j['status'],
        subtotalAmount: _toDouble(j['subtotal_amount']),
        discountAmount: _toDouble(j['discount_amount']),
        totalAmount: _toDouble(j['total_amount']),
        holdExpiresAt: j['hold_expires_at'],
        createdAt: j['created_at'],
        items: (j['items'] as List? ?? []).map((e) => OrderItemModel.fromJson(e)).toList(),
        tickets: (j['tickets'] as List? ?? []).map((e) => TicketModel.fromJson(e)).toList(),
      );
}
