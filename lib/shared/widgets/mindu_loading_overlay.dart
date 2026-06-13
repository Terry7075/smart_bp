import 'package:flutter/material.dart';

/// 在 [child] 之上顯示全螢幕載入遮罩（長輩友善大字提示）。
class MinduLoadingOverlay extends StatelessWidget {
  const MinduLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message = '處理中，請稍候...',
  });

  final bool isLoading;
  final Widget child;
  final String message;

  static const Color _minduGreen = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: _minduGreen),
                      const SizedBox(height: 20),
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
