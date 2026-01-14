import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qurbani/services/currency_notifier.dart';

class PriceWidget extends StatelessWidget {
  final double priceUsd;

  const PriceWidget({super.key, required this.priceUsd});

  @override
  Widget build(BuildContext context) {
    final currencyNotifier = Provider.of<CurrencyNotifier>(context);

    double convertedPrice = currencyNotifier.convert(priceUsd);

    return Text(
      '${convertedPrice.toStringAsFixed(2)} ${currencyNotifier.currency}',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }
}
