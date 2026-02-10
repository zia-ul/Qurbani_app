class AdminOrderConfig {
  final int totalShares;
  final int remainingShares;
  final double pricePerShare;
  final double lateBookingFee;
  final DateTime lastBookingDate;
  final String deliveryType;
  final double deliveryFee;
  final double? freeDeliveryThreshold;
  final String currency;

  AdminOrderConfig.fromJson(Map<String, dynamic> json)
      : totalShares =
            int.parse(json['total_shares'].toString()),
        remainingShares =
            int.parse(json['remaining_shares'].toString()),
        pricePerShare =
            double.parse(json['price_per_share'].toString()),
        lateBookingFee =
            double.parse(json['late_booking_fee'].toString()),
        lastBookingDate =
            DateTime.parse(json['last_booking_date']),
        deliveryType = json['delivery_type'],
        deliveryFee =
            double.parse(json['delivery_fee'].toString()),
        freeDeliveryThreshold = json['free_delivery_threshold'] != null
            ? double.parse(json['free_delivery_threshold'].toString())
            : null,
        currency = json['currency'];
}
