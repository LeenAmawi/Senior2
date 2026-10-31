
import 'package:flutter/material.dart';

const Color statusGreen = Color(0xFF00D943);
const Color statusBackground = Color(0xFFE8FBEF);
const Color statusPurple = Color(0xFF9B55D5);

Widget _statusCircle({required Widget child}) {//Circle style for awake and sleep

  return Container(
    width: 70,
    height: 70,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: statusBackground,
      border: Border.all(
        color: statusGreen,
        width: 3,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 5,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}
// awake icon
Widget smileStatusIcon() {
  return _statusCircle(
    child: const Icon(
      Icons.sentiment_satisfied_alt,
      color: statusGreen,
      size: 48,
    ),
  );
}
// sleep icon
Widget sleepingStatusIcon() {
  return _statusCircle(
    child: const Center(
      child: Text(
        'Zzz',
        style: TextStyle(
          color: statusGreen,
          fontSize: 25,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
//check icon
Widget checkStatusIcon() {
  return _checkOrCrossIcon(
    Icons.check,
    statusGreen,
  );
}
//cross icon
Widget crossStatusIcon() {
  return _checkOrCrossIcon(
    Icons.close,
    Colors.red,
  );
}

Widget _checkOrCrossIcon(//shared style
    IconData icon,
    Color iconColor,
    ) {
  return Container(
    width: 50,
    height: 50,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.18),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Icon(
      icon,
      color: iconColor,
      size: 30,
    ),
  );
}


Widget getStatusIcon(String status) { //choose icon
  final currentStatus = status.toLowerCase().trim();

  if (currentStatus.contains('sleep')) {
    return sleepingStatusIcon();
  }

  if (currentStatus.contains('awake')) {
    return smileStatusIcon();
  }

  if (currentStatus.contains('safe')) {
    return checkStatusIcon();
  }

  if (currentStatus.contains('danger')) {
    return crossStatusIcon();
  }

  return const Icon(
    Icons.help_outline,
    color: Colors.grey,
    size: 40,
  );
}
