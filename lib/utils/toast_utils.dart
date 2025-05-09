import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum AppToastType { success, error, warning, info }

void showAppToast(BuildContext context, String message, AppToastType toastType, {Duration duration = const Duration(seconds: 3)}) {
  if (!context.mounted) return;

  Color backgroundColor;
  Color textColor = Colors.white; // Default for darker backgrounds
  IconData iconData;

  switch (toastType) {
    case AppToastType.success:
      backgroundColor = AppColors.success;
      iconData = Icons.check_circle_outline;
      break;
    case AppToastType.error:
      backgroundColor = AppColors.error; // This is AppColors.puce
      iconData = Icons.error_outline;
      break;
    case AppToastType.warning:
      backgroundColor = AppColors.warning; // This is an orange color
      iconData = Icons.warning_amber_outlined;
      textColor = AppColors.prussianBlue; // Better contrast for orange
      break;
    case AppToastType.info:
    default:
      backgroundColor = AppColors.prussianBlue; 
      iconData = Icons.info_outline;
      break;
  }

  final scaffoldMessenger = ScaffoldMessenger.of(context);
  scaffoldMessenger.removeCurrentSnackBar(); // Remove any existing snackbar
  scaffoldMessenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(iconData, color: textColor),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(color: textColor, fontSize: 16))),
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      // Position at the top by setting a large bottom margin.
      // The SnackBar is constrained by Scaffold padding, so it won't go under system UI.
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - kToolbarHeight - 70, // 70 is an estimate for SnackBar height + its own padding
        left: 10,
        right: 10,
      ),
      dismissDirection: DismissDirection.up, 
      duration: duration,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
} 