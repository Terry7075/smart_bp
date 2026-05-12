// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/prescription/prescription_provider.dart';

/// 吃藥打卡頁：通常由「吃藥提醒通知」點擊後開啟。
class MedicationCheckinPage extends ConsumerStatefulWidget {
  const MedicationCheckinPage({
    super.key,
    required this.prescriptionId,
    this.slotTime,
  });

  final String prescriptionId;
  final String? slotTime;

  @override
  ConsumerState<MedicationCheckinPage> createState() =>
      _MedicationCheckinPageState();
}

class _MedicationCheckinPageState extends ConsumerState<MedicationCheckinPage>
    with SingleTickerProviderStateMixin {
  static const Color _green = Color(0xFF2E7D32);

  bool _submitting = false;
  bool _done = false;
  late AnimationController _celebrate;

  @override
  void initState() {
    super.initState();
    _celebrate = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _celebrate.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.prescriptionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFC62828),
          content: Text(
            '找不到藥單編號，請從通知點進來打卡。',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(prescriptionRepositoryProvider).insertMedicationLog(
            prescriptionId: widget.prescriptionId,
            slotTime: widget.slotTime,
          );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _done = true;
      });
      await _celebrate.forward(from: 0);
    } catch (e) {
      print('[Checkin] error: $e');
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFC62828),
          duration: const Duration(seconds: 5),
          content: Text(
            '打卡失敗：$e',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final slotLabel =
        (widget.slotTime != null && widget.slotTime!.isNotEmpty)
            ? widget.slotTime!
            : '';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        toolbarHeight: 72,
        title: const Text(
          '吃藥打卡',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 32),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _done ? '🎉 太棒了！' : '該吃藥囉！',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                  color: Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 12),
              if (slotLabel.isNotEmpty)
                Text(
                  '提醒時段：$slotLabel',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                _done
                    ? '村辦公室看得到您的紀錄喔，繼續保持！'
                    : '吃完藥後請按下面的大按鈕打卡，\n讓家人與志工放心。',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                  color: Colors.black54,
                ),
              ),
              const Spacer(),
              if (_done)
                ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _celebrate,
                    curve: Curves.elasticOut,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 120,
                    color: _green,
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final size =
                        (constraints.maxWidth * 0.72).clamp(220.0, 340.0);
                    return Center(
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: Material(
                          color: _green,
                          elevation: 8,
                          shadowColor: Colors.black45,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: _submitting ? null : _submit,
                            child: Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  _submitting ? '送出中…' : '✅ 我剛剛吃過藥了',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: size > 280 ? 28 : 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
              SizedBox(
                height: 64,
                child: OutlinedButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Colors.black38, width: 2),
                  ),
                  child: const Text(
                    '返回首頁',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
