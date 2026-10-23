import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:paper_curl/paper_curl.dart';
import 'package:paper_curl_example/main.dart';

// turns pages by hand and by button on a real device. --dart-define=SLOW=true
// holds poses mid-curl for screen recordings
const _slow = bool.fromEnvironment('SLOW');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // pages animate forever, so wait a fixed time instead of pumpAndSettle
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> hold(WidgetTester tester, int ms) async {
    final frames = (_slow ? ms : ms ~/ 4) ~/ 16;
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  // drags along a path in small steps, pausing at [pauseAt] if given
  Future<void> drag(
    WidgetTester tester,
    Offset from,
    List<Offset> path, {
    int pauseAt = -1,
  }) async {
    final gesture = await tester.startGesture(from);
    var at = from;
    for (var i = 0; i < path.length; i++) {
      final target = path[i];
      for (var step = 1; step <= 12; step++) {
        await gesture.moveTo(Offset.lerp(at, target, step / 12)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      at = target;
      if (i == pauseAt) await hold(tester, 900);
    }
    await gesture.up();
    await settle(tester);
  }

  int page(WidgetTester tester) => tester
      .state(find.byType(PageCurlView))
      .widget
      .let((w) => (w as PageCurlView).controller!.page);

  testWidgets('turn pages by corner, by edge, backwards and by button', (
    tester,
  ) async {
    await tester.pumpWidget(const BookApp());
    // the shader loads through the engine
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await settle(tester);
    await hold(tester, 800);
    final book = tester.getRect(find.byKey(const ValueKey('book')));

    // 1. lift the bottom corner, hold it mid-curl, then turn
    await drag(tester, book.bottomRight + const Offset(-8, -8), [
      Offset(book.left + book.width * 0.55, book.bottom - book.height * 0.18),
      Offset(book.left + book.width * 0.15, book.bottom - book.height * 0.1),
    ], pauseAt: 0);
    expect(page(tester), 1);
    await hold(tester, 600);

    // 2. curl from the middle of the edge
    await drag(tester, Offset(book.right - 8, book.center.dy), [
      Offset(book.left + book.width * 0.5, book.center.dy - 20),
      Offset(book.left + book.width * 0.05, book.center.dy - 30),
    ], pauseAt: 0);
    expect(page(tester), 2);
    await hold(tester, 600);

    // 3. lift the top corner a little and let it fall back
    await drag(tester, book.topRight + const Offset(-8, 8), [
      Offset(book.right - book.width * 0.3, book.top + book.height * 0.15),
    ], pauseAt: 0);
    expect(page(tester), 2);
    await hold(tester, 600);

    // 4. turn back from the left edge
    await drag(tester, Offset(book.left + 8, book.center.dy + 60), [
      Offset(book.left + book.width * 0.3, book.center.dy + 40),
      Offset(book.left + book.width * 0.6, book.center.dy + 20),
    ], pauseAt: 0);
    expect(page(tester), 1);
    await hold(tester, 600);

    // 5. buttons
    await tester.tap(find.byKey(const ValueKey('next')));
    await settle(tester);
    expect(page(tester), 2);
    await hold(tester, 500);
    await tester.tap(find.byKey(const ValueKey('next')));
    await settle(tester);
    expect(page(tester), 3);
    await hold(tester, 500);
    await tester.tap(find.byKey(const ValueKey('previous')));
    await settle(tester);
    expect(page(tester), 2);
    await hold(tester, 800);
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
