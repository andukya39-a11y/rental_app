import 'package:flutter/material.dart';

class VerificationBadge extends StatelessWidget {
  final String verificationStatus;

  const VerificationBadge({
    Key? key,
    required this.verificationStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine the badge color and text based on verificationStatus
    Color backgroundColor;
    String text;
    Color textColor;

    switch (verificationStatus) {
      case 'verified':
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        text = 'Verified by Sheha';
        textColor = Colors.green;
        break;
      case 'pending':
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        text = 'Verification Pending';
        textColor = Colors.orange;
        break;
      case 'rejected':
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        text = 'Verification Unsuccessful';
        textColor = Colors.red;
        break;
      case 'not_verified':
      default:
        backgroundColor = Colors.grey.withValues(alpha: 0.1);
        text = 'Not Verified';
        textColor = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
