import 'dart:async';
import 'package:flutter/material.dart';

class TimerButton extends StatefulWidget {
  final VoidCallback onPressed;
  final int timeLimit;
  final String defaultText;

  const TimerButton({
    Key? key,
    required this.onPressed,
    this.timeLimit = 180, // 3분
    this.defaultText = '인증번호 요청',
  }) : super(key: key);

  @override
  State<TimerButton> createState() => _TimerButtonState();
}

class _TimerButtonState extends State<TimerButton> {
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isActive = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void startTimer() {
    setState(() {
      _isActive = true;
      _remainingSeconds = widget.timeLimit;
    });

    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {
        if (_remainingSeconds > 0) {
          setState(() {
            _remainingSeconds--;
          });
        } else {
          setState(() {
            _isActive = false;
          });
          timer.cancel();
        }
      },
    );
  }

  String get _buttonText {
    if (!_isActive) return widget.defaultText;
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _isActive ? null : () {
          widget.onPressed();
          startTimer();
        },
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Text(_buttonText),
      ),
    );
  }
}