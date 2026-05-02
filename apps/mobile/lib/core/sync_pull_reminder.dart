import 'package:flutter/material.dart';

class SyncPullReminder extends StatelessWidget {
  const SyncPullReminder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A3D)),
      ),
      child: const Row(
        children: [
          Icon(Icons.sync_rounded, size: 18, color: Color(0xFF8B5CF6)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Arraste a tela para baixo para sincronizar.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
