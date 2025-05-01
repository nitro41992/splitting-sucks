import 'package:flutter/material.dart';

class WaveDividerPainter extends CustomPainter {
  final Color color;
  
  WaveDividerPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
      
    var path = Path();
    
    // Start from the left side
    path.moveTo(0, size.height / 2);
    
    // Create a gentle wave pattern
    final wavesCount = 6;
    final width = size.width;
    final waveWidth = width / wavesCount;
    
    for (int i = 0; i < wavesCount; i++) {
      final x1 = waveWidth * i + waveWidth / 2;
      final x2 = waveWidth * (i + 1);
      
      if (i % 2 == 0) {
        // Wave up
        path.quadraticBezierTo(x1, size.height / 2 - 8, x2, size.height / 2);
      } else {
        // Wave down
        path.quadraticBezierTo(x1, size.height / 2 + 8, x2, size.height / 2);
      }
    }
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
} 