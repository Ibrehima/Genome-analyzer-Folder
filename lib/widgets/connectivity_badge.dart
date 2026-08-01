import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';

class ConnectivityBadge extends StatelessWidget {
  const ConnectivityBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectivityService>();
    final online = conn.isOnline;
    return InkWell(
      onTap: () => conn.checkNow(),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: online ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (conn.isChecking)
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              )
            else
              Icon(
                online ? Icons.wifi : Icons.wifi_off,
                size: 14,
                color: online
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFEF6C00),
              ),
            const SizedBox(width: 6),
            Text(
              online ? 'Online' : 'Offline',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: online
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFEF6C00),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
