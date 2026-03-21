class AdminOrderConfig {
  final int totalShares;
  final double remainingShares;
  final double lateBookingFee;

  final int day1;
  final int day2;
  final int day3;

  final int day1Remaining;
  final int day2Remaining;
  final int day3Remaining;

  AdminOrderConfig({
    required this.totalShares,
    required this.remainingShares,
    required this.lateBookingFee,
    required this.day1,
    required this.day2,
    required this.day3,
    required this.day1Remaining,
    required this.day2Remaining,
    required this.day3Remaining,
  });

  factory AdminOrderConfig.fromJson(Map<String, dynamic> json) {
    return AdminOrderConfig(
      totalShares: int.tryParse(json['total_shares'].toString()) ?? 0,
      remainingShares:
          double.tryParse(json['remaining_shares'].toString()) ?? 0,
      lateBookingFee:
          double.tryParse(json['late_booking_fee'].toString()) ?? 0,
      day1: int.tryParse(json['day1'].toString()) ?? 0,
      day2: int.tryParse(json['day2'].toString()) ?? 0,
      day3: int.tryParse(json['day3'].toString()) ?? 0,
      day1Remaining: int.tryParse(json['day1_remaining'].toString()) ?? 0,
      day2Remaining: int.tryParse(json['day2_remaining'].toString()) ?? 0,
      day3Remaining: int.tryParse(json['day3_remaining'].toString()) ?? 0,
    );
  }
}