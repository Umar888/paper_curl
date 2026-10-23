# paper_curl

Realistic page curl for Flutter. Pages turn like a real book: the corner
follows your finger, the sheet wraps around a cylinder, the back of the page
is paper with the ink faintly showing through, and soft shadows fall on the
page underneath. It's rendered in one GPU fragment shader.

![paper_curl demo](https://raw.githubusercontent.com/Umar888/paper_curl/main/doc/demo.gif)

## Features

- **Follows the finger.** Grab near the top or bottom corner to lift that
  corner, or the middle of the edge to curl the whole edge. The corner stays
  exactly under your finger.
- **Bound at the spine.** A page can't be pulled off the book. The bound
  edge never lifts, and the page resists being pulled further.
- **Paper backs.** The back of a turning page is paper colored, with the
  front's ink showing through, mirrored, like real thin paper.
- **Light and shadow.** The roll darkens as it turns away, its top catches
  the light, and the revealed page and the page under the folded sheet get
  soft shadows. Shadows fade out as a turn finishes, so nothing pops.
- **Both directions.** Drag from the right half to turn forward, from the
  left half to turn back.
- **Physics on release.** Let go past the middle, or flick, to finish the
  turn. Otherwise the page falls back. You can catch a page mid-animation.
- **Controller.** `nextPage()` and `previousPage()` curl the corner along a
  gentle arc, and `jumpToPage()` jumps straight there.
- **Pages keep their state.** All pages stay mounted, so scroll positions,
  text fields and counters survive turning away and back.
- **Graceful fallback.** If shaders aren't available, pages still change,
  just without the curl.

## Usage

```dart
import 'package:paper_curl/paper_curl.dart';

final controller = PageCurlController();

PageCurlView(
  controller: controller,
  itemCount: chapters.length,
  pageColor: const Color(0xFFFBF7EE),
  onPageChanged: (page) => print('now on page $page'),
  itemBuilder: (context, index) => ChapterPage(chapters[index]),
)

// from code
controller.nextPage();
controller.previousPage();
controller.jumpToPage(3);
```

## Options

| Parameter | Default | Description |
| --- | --- | --- |
| `itemCount` / `itemBuilder` | required | The pages. |
| `controller` | `null` | Turns pages from code and reports `page` and `isTurning`. |
| `initialPage` | `0` | First page when there's no controller. |
| `onPageChanged` | `null` | Called after a turn lands. |
| `pageColor` | theme surface | Painted behind every page, so transparent pages don't show the ones beneath. |
| `backColor` | warm tint of `pageColor` | Paper color of a page's back. |
| `ink` | `0.14` | How much of the front shows through the back (0 to 1). |
| `shadow` | `1` | Shadow strength (0 to 1). |
| `maxRadius` | `56` | Largest curl radius. The curl starts tight and opens up as the page lifts. |
| `duration` | 560 ms | A full turn after letting go or from code. Partial turns take proportionally less. |
| `enableGestures` | `true` | Turn off to turn pages from code only. |

## How it works

When a drag starts, the page being turned is captured once as an image. For
every pixel, the fragment shader works backwards from where the pixel is to
the point of the page that ends up there. That point is one of:

1. part of the flat page,
2. the front of the sheet curving up around the cylinder,
3. the back of the sheet coming over the top, or
4. the turned-over back lying flat again.

Whichever is physically on top wins. Pixels the page has lifted away from
are left transparent, plus a shadow, so the next page shows through.

The fold is placed so the grabbed corner lands exactly under the finger,
then moved if needed so the spine never lifts. That geometry is pure Dart
and unit tested against the same model the shader uses.

## Notes

- While a page is turning, it shows as a snapshot taken when the turn
  started, so animations on that page pause until it lands.
- The pages either side of the current one are built underneath, so a turn
  can start instantly.
- Vertical scrolling inside a page still works. Horizontal and diagonal
  drags go to the book.

## Example

`example/` is a short illustrated book with next and previous buttons. It
also has an integration test that turns pages by corner, by edge, backwards
and by button on a device.
