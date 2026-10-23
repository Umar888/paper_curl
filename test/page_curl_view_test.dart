import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_curl/paper_curl.dart';

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => TextButton(
    key: const ValueKey('counter'),
    onPressed: () => setState(() => taps++),
    child: Text('taps $taps'),
  );
}

void main() {
  late List<int> changes;

  Widget book({PageCurlController? controller, int count = 3}) => MaterialApp(
    home: Scaffold(
      body: PageCurlView(
        controller: controller,
        itemCount: count,
        onPageChanged: changes.add,
        itemBuilder: (context, index) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [Text('page $index'), if (index == 0) const _Counter()],
          ),
        ),
      ),
    ),
  );

  // the shader loads through the engine, which needs real time
  Future<void> ready(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
  }

  Rect pageRect(WidgetTester tester) =>
      tester.getRect(find.byType(PageCurlView));

  setUp(() => changes = []);

  testWidgets('shows the first page with its neighbour built underneath', (
    tester,
  ) async {
    await tester.pumpWidget(book());
    await ready(tester);
    expect(find.text('page 0'), findsOneWidget);
    expect(find.text('page 1'), findsOneWidget);
    expect(find.text('page 2'), findsNothing);
  });

  testWidgets('a drag to the left turns the page', (tester) async {
    await tester.pumpWidget(book());
    await ready(tester);
    final rect = pageRect(tester);
    await tester.flingFrom(
      Offset(rect.right - 10, rect.bottom - 20),
      Offset(-rect.width * 0.9, -40),
      1500,
    );
    await tester.pumpAndSettle();
    expect(changes, [1]);
    expect(find.text('page 2'), findsOneWidget);
  });

  testWidgets('a short drag lets the page fall back', (tester) async {
    await tester.pumpWidget(book());
    await ready(tester);
    final rect = pageRect(tester);
    final gesture = await tester.startGesture(
      Offset(rect.right - 10, rect.bottom - 20),
    );
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(-15, -3));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
  });

  testWidgets('a drag to the right turns back', (tester) async {
    final controller = PageCurlController(initialPage: 1);
    await tester.pumpWidget(book(controller: controller));
    await ready(tester);
    expect(controller.page, 1);
    final rect = pageRect(tester);
    await tester.flingFrom(
      Offset(rect.left + 10, rect.center.dy),
      Offset(rect.width * 0.6, 0),
      1500,
    );
    await tester.pumpAndSettle();
    expect(changes, [0]);
    expect(controller.page, 0);
  });

  testWidgets('no turning past either end', (tester) async {
    await tester.pumpWidget(book(count: 1));
    await ready(tester);
    final rect = pageRect(tester);
    await tester.flingFrom(
      Offset(rect.right - 10, rect.center.dy),
      Offset(-rect.width * 0.9, 0),
      1500,
    );
    await tester.flingFrom(
      Offset(rect.left + 10, rect.center.dy),
      Offset(rect.width * 0.9, 0),
      1500,
    );
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
  });

  testWidgets('the controller turns pages with a curl', (tester) async {
    final controller = PageCurlController();
    await tester.pumpWidget(book(controller: controller));
    await ready(tester);

    final turning = controller.nextPage();
    await tester.pump();
    expect(controller.isTurning, isTrue);
    await tester.pumpAndSettle();
    await turning;
    expect(controller.page, 1);

    final back = controller.previousPage();
    await tester.pumpAndSettle();
    await back;
    expect(controller.page, 0);
    expect(changes, [1, 0]);

    controller.jumpToPage(2);
    await tester.pump();
    expect(find.text('page 2'), findsOneWidget);
  });

  testWidgets('pages keep their state while turning', (tester) async {
    final controller = PageCurlController();
    await tester.pumpWidget(book(controller: controller));
    await ready(tester);
    await tester.tap(find.byKey(const ValueKey('counter')));
    await tester.tap(find.byKey(const ValueKey('counter')));
    await tester.pump();
    expect(find.text('taps 2'), findsOneWidget);

    final forward = controller.nextPage();
    await tester.pumpAndSettle();
    await forward;
    final back = controller.previousPage();
    await tester.pumpAndSettle();
    await back;
    expect(find.text('taps 2'), findsOneWidget);
  });

  testWidgets('works without a shader, minus the curl', (tester) async {
    PageCurlView.debugDisableShader = true;
    addTearDown(() => PageCurlView.debugDisableShader = false);
    final controller = PageCurlController();
    await tester.pumpWidget(book(controller: controller));
    await controller.nextPage();
    await tester.pump();
    expect(controller.page, 1);
    expect(changes, [1]);
  });
}
