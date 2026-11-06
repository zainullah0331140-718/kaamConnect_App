import 'package:flutter/material.dart';
import '../core/constants.dart';

class VerifiedBadge extends StatelessWidget {
  final String status;
  final bool compact;

  const VerifiedBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isVerified = status.toLowerCase() == 'verified';
    final isPending = status.toLowerCase() == 'pending';

    final Color color = isVerified
        ? AppConstants.verifiedGreen
        : (isPending ? AppConstants.pendingYellow : AppConstants.rejectedRed);

    final String label = isVerified ? 'Verified' : (isPending ? 'Pending' : 'Unverified');
    final IconData icon = isVerified
        ? Icons.verified_rounded
        : (isPending ? Icons.hourglass_top_rounded : Icons.info_outline_rounded);

    if (compact) {
      return Tooltip(
        message: label,
        child: Icon(icon, color: color, size: 18),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
