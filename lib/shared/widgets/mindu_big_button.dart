import 'package:flutter/material.dart';

/// 給長輩使用的滿版寬度主按鈕（固定高度、大字粗體）。
class MinduBigButton extends StatelessWidget {
  const MinduBigButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  final String text;
  final VoidCallback onPressed;

  /// 明德社區主題綠
  static const Color _backgroundColor = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 60),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.bold,
        ),
      ),
      child: Text(text),
    );
  }
}
