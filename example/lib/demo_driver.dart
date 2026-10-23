import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:paper_curl/paper_curl.dart';

/// Plays a scripted demo for screen recordings: real pointer events sent
/// through the gesture system, with smooth eased finger paths. Prints a
/// `DEMO:<step>` line as each step starts so captions can be synced.
///
/// Started with `flutter run --dart-define=DEMO=true`.
class DemoDriver {
  DemoDriver({required this.controller, required this.bookKey});

  final PageCurlController controller;
  final GlobalKey bookKey;
  int _pointer = 900;

  Rect get _book {
    final box = bookKey.currentContext!.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _wait(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  void _mark(String step) => debugPrint('DEMO:$step');

  Future<void> _drag(
    List<Offset> points,
    List<int> durations, {
    List<int> holds = const [],
    Map<int, String> marks = const {},
    Curve curve = Curves.easeInOutCubic,
  }) async {
    final pointer = ++_pointer;
    final binding = GestureBinding.instance;
    var at = points.first;
    binding.handlePointerEvent(
      PointerDownEvent(pointer: pointer, position: at),
    );
    for (var i = 1; i < points.length; i++) {
      final from = at;
      final to = points[i];
      final frames = (durations[i - 1] / 16).round().clamp(1, 1000);
      for (var f = 1; f <= frames; f++) {
        final next = Offset.lerp(from, to, curve.transform(f / frames))!;
        binding.handlePointerEvent(
          PointerMoveEvent(pointer: pointer, position: next, delta: next - at),
        );
        at = next;
        await _wait(16);
      }
      if (marks.containsKey(i)) _mark(marks[i]!);
      if (i - 1 < holds.length && holds[i - 1] > 0) await _wait(holds[i - 1]);
    }
    binding.handlePointerEvent(PointerUpEvent(pointer: pointer, position: at));
  }

  Future<void> run() async {
    _mark('ready');
    // gives the recorder a moment to start
    await _wait(3000);
    final b = _book;

    _mark('intro');
    await _wait(2200);

    _mark('corner');
    // lift the corner, hold it mid-curl so the live page is visible, then turn
    await _drag(
      [
        b.bottomRight + const Offset(-6, -6),
        Offset(b.left + b.width * 0.55, b.bottom - b.height * 0.2),
        Offset(b.left + b.width * 0.08, b.bottom - b.height * 0.06),
      ],
      [1600, 900],
      holds: [3200],
      marks: {1: 'live'},
    );
    await _wait(1500);

    _mark('edge');
    await _drag(
      [
        Offset(b.right - 6, b.center.dy),
        Offset(b.left + b.width * 0.55, b.center.dy - 25),
        Offset(b.left + b.width * 0.04, b.center.dy - 40),
      ],
      [1100, 700],
    );
    await _wait(1500);

    _mark('peek');
    await _drag(
      [
        b.topRight + const Offset(-6, 6),
        Offset(b.right - b.width * 0.32, b.top + b.height * 0.16),
      ],
      [1000],
      holds: [700],
    );
    await _wait(1500);

    _mark('back');
    await _drag(
      [
        Offset(b.left + 6, b.center.dy + 80),
        Offset(b.left + b.width * 0.35, b.center.dy + 60),
        Offset(b.left + b.width * 0.7, b.center.dy + 40),
      ],
      [900, 700],
    );
    await _wait(1500);

    _mark('flick');
    await _drag(
      [
        Offset(b.right - 10, b.bottom - b.height * 0.3),
        Offset(b.right - b.width * 0.45, b.bottom - b.height * 0.33),
      ],
      [180],
      curve: Curves.easeIn,
    );
    await _wait(1800);

    _mark('buttons');
    await controller.nextPage();
    await _wait(900);
    await controller.nextPage();
    await _wait(900);
    await controller.previousPage();
    await _wait(1400);

    _mark('end');
    await _wait(3000);
    _mark('done');
  }
}
