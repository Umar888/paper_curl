import 'package:flutter/material.dart';
import 'package:paper_curl/paper_curl.dart';

void main() => runApp(const BookApp());

class BookApp extends StatelessWidget {
  const BookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'paper_curl',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF8C5A2B)),
      home: const BookPage(),
    );
  }
}

class _Chapter {
  const _Chapter(this.title, this.colors, this.icon, this.body);

  final String title;
  final List<Color> colors;
  final IconData icon;
  final String body;
}

const _chapters = [
  _Chapter(
    'The Lighthouse',
    [Color(0xFF0F2027), Color(0xFF2C5364)],
    Icons.light_mode,
    'On the last rock before the open sea stood a lighthouse that nobody had lit in forty years. Every night, the keeper\'s daughter climbed its two hundred steps anyway.',
  ),
  _Chapter(
    'Paper Boats',
    [Color(0xFFFF7E5F), Color(0xFFFEB47B)],
    Icons.sailing,
    'She folded boats from old charts and set them on the tide. Most sank before the harbour wall. One, folded from a map of the north, never came back.',
  ),
  _Chapter(
    'The Northern Map',
    [Color(0xFF1D976C), Color(0xFF93F9B9)],
    Icons.explore,
    'The map showed an island no sailor had heard of, ringed in faded red ink, with a note in the margin: light the lamp and they will come.',
  ),
  _Chapter(
    'Two Hundred Steps',
    [Color(0xFF614385), Color(0xFF516395)],
    Icons.stairs,
    'So one winter evening she carried oil up the tower, polished the great lens until it rang, and struck a match against the cold iron rail.',
  ),
  _Chapter(
    'The Light Returns',
    [Color(0xFFF7971E), Color(0xFFFFD200)],
    Icons.wb_sunny,
    'The beam swept out across the water for the first time in forty years. Far to the north, something on the horizon answered it.',
  ),
  _Chapter(
    'The End',
    [Color(0xFF232526), Color(0xFF414345)],
    Icons.auto_stories,
    'Turn back through the pages by dragging from the left edge. Every page stayed exactly as you left it.',
  ),
];

class BookPage extends StatefulWidget {
  const BookPage({super.key});

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  final _controller = PageCurlController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const paper = Color(0xFFFBF7EE);
    return Scaffold(
      backgroundColor: const Color(0xFF3B2A1E),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: Color(0xFFE9D5B5)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'The Keeper\'s Daughter',
                      style: TextStyle(
                        color: Color(0xFFE9D5B5),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${_controller.page + 1} / ${_chapters.length}',
                    style: const TextStyle(color: Color(0xFFE9D5B5)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(14),
                    left: Radius.circular(4),
                  ),
                  child: PageCurlView(
                    key: const ValueKey('book'),
                    controller: _controller,
                    itemCount: _chapters.length,
                    pageColor: paper,
                    itemBuilder: (context, index) => _ChapterPage(
                      chapter: _chapters[index],
                      number: index + 1,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FilledButton.tonalIcon(
                    key: const ValueKey('previous'),
                    onPressed: _controller.page > 0
                        ? _controller.previousPage
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Previous'),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('next'),
                    onPressed: _controller.page < _chapters.length - 1
                        ? _controller.nextPage
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterPage extends StatefulWidget {
  const _ChapterPage({required this.chapter, required this.number});

  final _Chapter chapter;
  final int number;

  @override
  State<_ChapterPage> createState() => _ChapterPageState();
}

// pages are alive: the illustration turns and a timer ticks, and both keep
// going while the page curls
class _ChapterPageState extends State<_ChapterPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();
  final _clock = Stopwatch()..start();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF3B2A1E);
    final chapter = widget.chapter;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: chapter.colors,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: RotationTransition(
                      turns: _spin,
                      child: Icon(
                        chapter.icon,
                        size: 96,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: AnimatedBuilder(
                      animation: _spin,
                      builder: (context, _) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          'LIVE ${(_clock.elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'CHAPTER ${widget.number}',
            style: const TextStyle(
              color: Color(0xFF8C5A2B),
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            chapter.title,
            style: const TextStyle(
              color: ink,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 4,
            child: Text(
              chapter.body,
              style: const TextStyle(
                color: ink,
                fontSize: 16,
                height: 1.55,
                fontFamily: 'Georgia',
              ),
            ),
          ),
          Center(
            child: Text(
              '— ${widget.number} —',
              style: const TextStyle(color: Color(0xFF8C5A2B)),
            ),
          ),
        ],
      ),
    );
  }
}
