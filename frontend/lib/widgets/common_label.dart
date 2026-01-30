import 'package:Qurbani/theme/theme.dart';
import 'package:flutter/material.dart';

class CommonLabel extends StatelessWidget {
  final String text;
  final bool isRequired;
  final EdgeInsetsGeometry? padding;

  const CommonLabel({
    super.key,
    required this.text,
    this.isRequired = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: 8, top: 4),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          children: isRequired
              ? [
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppTheme.warningRed),
                  ),
                ]
              : [],
        ),
      ),
    );
  }
}
