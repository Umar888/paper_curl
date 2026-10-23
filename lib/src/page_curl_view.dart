import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'curl_geometry.dart';
import 'page_curl_painter.dart';

/// Turns the pages of a [PageCurlView] from code.
class PageCurlController extends ChangeNotifier {
  /// Creates a controller.
  PageCurlController({int initialPage = 0}) : _page = initialPage;

  _PageCurlViewState? _view;
  int _page;

  /// The page showing now.
  int get page => _view?._page ?? _page;

  /// Whether a page is being turned, by hand or by code.
  bool get isTurning => _view?._turn != null;

  /// Curls to the next page. Does nothing on the last page.
  Future<void> nextPage() =>
      _view?._turnByCode(forward: true) ?? Future.value();

  /// Curls back to the previous page. Does nothing on the first page.
  Future<void> previousPage() =>
      _view?._turnByCode(forward: false) ?? Future.value();

  /// Shows [page] straight away, without a curl.
  void jumpToPage(int page) {
    _page = page;
    _view?._jumpTo(page);
  }

  void _attach(_PageCurlViewState view) {
    _view = view;
  }

  void _detach(_PageCurlViewState view) {
    if (identical(_view, view)) {
      _page = view._page;
      _view = null;
    }
  }

  void _changed() => notifyListeners();
}

/// A book: pages that turn with a realistic curl.
///
/// Drag from the right half to turn forward, or from the left half to turn
/// back. Grabbing near a top or bottom corner lifts that corner; grabbing
/// the middle of the edge curls the whole edge. Let go past the middle (or
/// flick) to finish the turn, otherwise the page falls back.
///
/// ```dart
/// PageCurlView(
///   itemCount: pages.length,
///   itemBuilder: (context, index) => MyPage(pages[index]),
/// )
/// ```
///
/// Pages stay mounted while they turn, so their state survives. During a
/// turn the page being turned is shown as a snapshot, so animations inside
/// it pause until it lands.
class PageCurlView extends StatefulWidget {
  /// Creates a book of [itemCount] pages built by [itemBuilder].
  const PageCurlView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.initialPage = 0,
    this.onPageChanged,
    this.pageColor,
    this.backColor,
    this.ink = 0.14,
    this.shadow = 1,
    this.maxRadius = 56,
    this.duration = const Duration(milliseconds: 560),
    this.enableGestures = true,
  }) : assert(itemCount >= 0),
       assert(ink >= 0 && ink <= 1),
       assert(shadow >= 0 && shadow <= 1);

  /// Number of pages.
  final int itemCount;

  /// Builds page [index].
  final IndexedWidgetBuilder itemBuilder;

  /// Turns pages from code and reports the current one.
  final PageCurlController? controller;

  /// The page shown first when no [controller] is given.
  final int initialPage;

  /// Called after a turn lands on a new page.
  final ValueChanged<int>? onPageChanged;

  /// Painted behind every page, so pages with transparent backgrounds
  /// don't show the pages under them. Defaults to the theme's surface.
  final Color? pageColor;

  /// Paper color of a page's back. Defaults to a warm tint of
  /// [pageColor].
  final Color? backColor;

  /// How much of a page's ink shows through its back, from 0 to 1.
  final double ink;

  /// Strength of the shadows under and around the curl, from 0 to 1.
  final double shadow;

  /// Largest radius of the curl, in logical pixels. The curl starts tight
  /// and opens up to this as the page lifts.
  final double maxRadius;

  /// How long a full turn takes when let go or started from code. Partial
  /// turns take proportionally less.
  final Duration duration;

  /// Whether pages can be turned by dragging.
  final bool enableGestures;

  /// Pretend shaders are unavailable, to test the fallback without a curl.
  @visibleForTesting
  static bool debugDisableShader = false;

  @override
  State<PageCurlView> createState() => _PageCurlViewState();
}

class _Turn {
  _Turn({
    required this.forward,
    required this.page,
    required this.corner,
    required this.touch,
    required this.image,
  });

  /// Turning towards the next page (true) or back to the previous (false).
  final bool forward;

  /// The page being curled: the current one going forward, the previous
  /// one coming back.
  final int page;

  /// The page corner being lifted.
  final Offset corner;

  /// Where the corner is now.
  Offset touch;

  final ui.Image image;
  Offset dragStart = Offset.zero;
  Offset touchAtDragStart = Offset.zero;
}

class _PageCurlViewState extends State<PageCurlView>
    with SingleTickerProviderStateMixin {
  static Future<ui.FragmentProgram>? _loading;
  // kept once loaded, so later views get their shader synchronously on
  // their first frame
  static ui.FragmentProgram? _program;

  late int _page =
      widget.controller?._page.clamp(0, math.max(0, widget.itemCount - 1)) ??
      widget.initialPage;
  final Map<int, GlobalKey> _keys = {};
  ui.FragmentShader? _shader;
  _Turn? _turn;
  late final AnimationController _settle = AnimationController(vsync: this);
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    if (PageCurlView.debugDisableShader) return;
    final program = _program;
    if (program != null) {
      _shader = program.fragmentShader();
      return;
    }
    (_loading ??= _loadProgram()).then(
      (program) {
        _program = program;
        if (mounted) setState(() => _shader ??= program.fragmentShader());
      },
      onError: (Object error) {
        // no shader support: pages still turn, just without the curl
        _loading = null;
        debugPrint('paper_curl: shader unavailable ($error)');
      },
    );
  }

  // apps see the shader under packages/paper_curl/, this package's own
  // tests see it at the root
  static Future<ui.FragmentProgram> _loadProgram() async {
    try {
      return await ui.FragmentProgram.fromAsset(
        'packages/paper_curl/shaders/page_curl.frag',
      );
    } on Object {
      return ui.FragmentProgram.fromAsset('shaders/page_curl.frag');
    }
  }

  @override
  void didUpdateWidget(PageCurlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (_page >= widget.itemCount) {
      _page = math.max(0, widget.itemCount - 1);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _settle.dispose();
    _turn?.image.dispose();
    _shader?.dispose();
    super.dispose();
  }

  bool get _hasNext => _page < widget.itemCount - 1;
  bool get _hasPrevious => _page > 0;

  GlobalKey _keyFor(int index) => _keys.putIfAbsent(index, GlobalKey.new);

  // ------------------------------------------------------------- turning

  ui.Image? _snapshot(int index) {
    final boundary = _keyFor(index).currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !boundary.hasSize) return null;
    try {
      return boundary.toImageSync(
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
    } on Object {
      // repainting this frame (debug builds assert); try again next drag
      return null;
    }
  }

  Offset _cornerFor(double y) {
    final h = _size.height;
    // near the top or bottom lift that corner, otherwise curl the edge
    if (y < h * 0.25) return Offset(_size.width, 0);
    if (y > h * 0.75) return Offset(_size.width, h);
    return Offset(_size.width, y);
  }

  bool _begin({required bool forward, required double y}) {
    if (_shader == null || _size.isEmpty) return false;
    final index = forward ? _page : _page - 1;
    final image = _snapshot(index);
    if (image == null) return false;
    final corner = _cornerFor(y);
    setState(() {
      _turn = _Turn(
        forward: forward,
        page: index,
        corner: corner,
        touch: forward ? corner : CurlGeometry.turnedCorner(_size, corner),
        image: image,
      );
    });
    widget.controller?._changed();
    return true;
  }

  void _onPanStart(DragStartDetails details) {
    final turn = _turn;
    if (turn != null) {
      // catch a page that is still settling
      _settle.stop();
      turn
        ..dragStart = details.localPosition
        ..touchAtDragStart = turn.touch;
      return;
    }
    final forward = details.localPosition.dx > _size.width / 2;
    if (forward ? !_hasNext : !_hasPrevious) return;
    if (!_begin(forward: forward, y: details.localPosition.dy)) return;
    _turn!
      ..dragStart = details.localPosition
      ..touchAtDragStart = _turn!.touch;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final turn = _turn;
    if (turn == null || _settle.isAnimating) return;
    final delta = details.localPosition - turn.dragStart;
    // going forward the corner follows the finger; coming back the corner
    // starts off-screen, so it moves twice as fast to reach the finger
    final scale = turn.forward ? 1.0 : 2.0;
    setState(() {
      turn.touch = turn.touchAtDragStart + Offset(delta.dx * scale, delta.dy);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final turn = _turn;
    if (turn == null) return;
    final vx = details.velocity.pixelsPerSecond.dx;
    final x = CurlGeometry.constrainTouch(_size, turn.corner, turn.touch).dx;
    final bool complete;
    if (turn.forward) {
      complete = vx < -350 || (vx <= 350 && x < _size.width * 0.4);
    } else {
      complete = vx > 350 || (vx >= -350 && x > -_size.width * 0.2);
    }
    _settleTo(turn, complete: complete);
  }

  Future<void> _settleTo(
    _Turn turn, {
    required bool complete,
    bool lift = false,
  }) async {
    final turned = CurlGeometry.turnedCorner(_size, turn.corner);
    // forward: done = turned over; backward: done = lying flat again
    final end = (turn.forward == complete) ? turned : turn.corner;
    final start = CurlGeometry.constrainTouch(_size, turn.corner, turn.touch);
    final fraction = ((end - start).distance / (2 * _size.width)).clamp(
      0.15,
      1.0,
    );
    _settle
      ..duration = widget.duration * fraction
      ..value = 0;
    final curve = lift ? Curves.easeInOutCubic : Curves.easeOutCubic;
    void tick() {
      final t = curve.transform(_settle.value);
      var p = Offset.lerp(start, end, t)!;
      // turns started from code lift the corner on a gentle arc
      if (lift) {
        final up = turn.corner.dy > _size.height / 2 ? -1.0 : 1.0;
        p += Offset(0, up * _size.height * 0.12 * math.sin(math.pi * t));
      }
      setState(() => turn.touch = p);
    }

    _settle.addListener(tick);
    try {
      await _settle.forward().orCancel;
    } on TickerCanceled {
      // caught by a new drag, which carries on from here
      return;
    } finally {
      _settle.removeListener(tick);
    }
    if (!identical(_turn, turn)) return;
    _finish(turn, complete: complete);
  }

  void _finish(_Turn turn, {required bool complete}) {
    final from = _page;
    setState(() {
      if (complete) _page = turn.forward ? _page + 1 : _page - 1;
      _turn = null;
    });
    // the snapshot is still referenced by this frame's painter
    SchedulerBinding.instance.addPostFrameCallback((_) => turn.image.dispose());
    widget.controller?._changed();
    if (complete && _page != from) widget.onPageChanged?.call(_page);
  }

  Future<void> _turnByCode({required bool forward}) async {
    if (_turn != null) return;
    if (forward ? !_hasNext : !_hasPrevious) return;
    if (!_begin(forward: forward, y: _size.height)) {
      // no curl available: still change the page
      _jumpTo(forward ? _page + 1 : _page - 1);
      widget.onPageChanged?.call(_page);
      return;
    }
    await _settleTo(_turn!, complete: true, lift: true);
  }

  void _jumpTo(int page) {
    _settle.stop();
    final turn = _turn;
    setState(() {
      _page = page.clamp(0, math.max(0, widget.itemCount - 1));
      _turn = null;
    });
    if (turn != null) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => turn.image.dispose(),
      );
    }
    widget.controller?._changed();
  }

  // ------------------------------------------------------------- building

  Widget _pageAt(int index, {bool visible = true}) {
    final color = widget.pageColor ?? Theme.of(context).colorScheme.surface;
    return Positioned.fill(
      key: ValueKey(index),
      child: Visibility(
        visible: visible,
        maintainState: true,
        maintainAnimation: true,
        maintainSize: true,
        child: RepaintBoundary(
          key: _keyFor(index),
          child: ColoredBox(
            color: color,
            child: widget.itemBuilder(context, index),
          ),
        ),
      ),
    );
  }

  Color get _backColor {
    if (widget.backColor != null) return widget.backColor!;
    final base = widget.pageColor ?? Theme.of(context).colorScheme.surface;
    // a warm paper tint of the page color
    return Color.lerp(base, const Color(0xFFE9DFC9), 0.35)!;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return const SizedBox.expand();
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        final turn = _turn;
        final shader = _shader;
        final children = <Widget>[];

        if (turn == null || shader == null) {
          // previous and next stay built underneath so a turn can start
          // instantly from a snapshot
          if (_hasPrevious) children.add(_pageAt(_page - 1));
          if (_hasNext) children.add(_pageAt(_page + 1));
          children.add(_pageAt(_page));
        } else if (turn.forward) {
          if (_hasPrevious) children.add(_pageAt(_page - 1));
          children
            ..add(_pageAt(_page + 1))
            ..add(_pageAt(_page, visible: false))
            ..add(_curl(turn, shader));
        } else {
          if (_hasNext) children.add(_pageAt(_page + 1));
          children
            ..add(_pageAt(_page - 1, visible: false))
            ..add(_pageAt(_page))
            ..add(_curl(turn, shader));
        }

        final stack = ClipRect(child: Stack(children: children));
        if (!widget.enableGestures) return stack;
        return GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: () {
            final turn = _turn;
            if (turn != null && !_settle.isAnimating) {
              _settleTo(turn, complete: false);
            }
          },
          child: stack,
        );
      },
    );
  }

  Widget _curl(_Turn turn, ui.FragmentShader shader) {
    final geometry = CurlGeometry.fromCorner(
      size: _size,
      corner: turn.corner,
      touch: turn.touch,
      maxRadius: widget.maxRadius,
    );
    // fade the shadow out over the last stretch of a full turn, so it
    // doesn't vanish all at once when the page lands
    final travelled =
        (CurlGeometry.constrainTouch(_size, turn.corner, turn.touch) -
                turn.corner)
            .distance /
        (2 * _size.width);
    final fade = ((1 - travelled) / 0.2).clamp(0.0, 1.0);
    return Positioned.fill(
      key: const ValueKey('curl'),
      child: IgnorePointer(
        child: CustomPaint(
          painter: PageCurlPainter(
            shader: shader,
            image: turn.image,
            geometry: geometry,
            backColor: _backColor,
            ink: widget.ink,
            shadow: widget.shadow * fade,
          ),
        ),
      ),
    );
  }
}
