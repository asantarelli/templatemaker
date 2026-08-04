# BrowseGrid — the engine, and the proof it draws

`templates/BrowseGrid/d2grid.c` is a grid drawn with **Direct2D and DirectWrite** into an ordinary
Clarion `REGION`. It holds no data: the Clarion side pushes in the rows that are visible and the grid
draws them, which is exactly the shape an ABC browse queue already has.

## `gridtest` — first light

Attaches to a REGION, sets five columns, pushes a page of made-up rows in and paints:

```
MSBuild gridtest.cwproj /p:ClarionBinPath=C:\clarion12\bin /p:Configuration=Debug
powershell -File shot.ps1 -Exe .\gridtest.exe -Prefix GridTest -Out gridshot.png
```

`docs/BrowseGrid-first-light.png` is the result: a dark header with bold titles, banded rows, gridlines,
a selected row, right-aligned numeric columns, text centred down each row, and a frozen first column.
23 rows fill the region exactly, which is `d2g_PageSize()` answering how many fit.

## Smooth scrolling, proved

`docs/BrowseGrid-smooth-scroll.png` is the same grid with `d2g_ScrollY(11)` — half a row. The top record
is **sliced through the middle**, showing only its lower half beneath an intact header. That is the whole
trick: everything below the header is clipped, so the page can be nudged by pixels and only changes
record when a whole row has gone past. Hit testing accounts for the offset, so a click still lands on the
record you pointed at.

## What the engine gives Clarion

| call | for |
|---|---|
| `d2g_Available()` | 0 when Direct2D/DirectWrite are missing, so the caller can fall back |
| `d2g_Attach(hwnd, face, pt)` | take over a REGION's window; returns a handle |
| `d2g_Columns` / `d2g_Column` | how many columns, and each one's width, alignment and title |
| `d2g_Frozen(n)` | columns that stay put while the rest scrolls sideways |
| `d2g_Colours(...)` | background, banding, gridlines, text, header, selection |
| `d2g_Page(first, rows)` + `d2g_Cell(row, col, text)` | push the visible page in |
| `d2g_PageSize()` | how many whole rows fit — what to ask the VIEW for |
| `d2g_HitRow` / `d2g_HitCol` | turn a click into a record and a column |
| `d2g_ScrollY(px)` / `d2g_RowH` | nudge the page by pixels — smooth, not jumpy |
| `d2g_Resize` / `d2g_Repaint` / `d2g_PaintNow` | keep it in step with the window |

## The template, tested on a real browse

`templates/BrowseGrid/BrowseGrid.tpl` is the drop-in: add it to a procedure that already has an ABC
browse, point it at the LIST, and the LIST is hidden with the grid drawn in its place.

It was tested against a **copy of a real application** rather than an invented one — School's
`BrowseStudents`, whose LIST is `?Browse:1` over `Queue:Browse:1`. `add-to-a-real-browse.py` is how:
export the app to a TXA, splice the two `[ADDITION]` blocks in, re-import, generate, compile.

```
ClarionCL -win -au -ax SCHOOL.APP school.txa      # export a COPY, never the original
python add-to-a-real-browse.py                    # splice BrowseGrid in
ClarionCL -win -au -ai bgschool.app school.txa
ClarionCL -win -au -ag bgschool.app
MSBuild bgschool.cwproj /p:ClarionBinPath=C:\clarion12in /p:Configuration=Debug
```

Result: **generates and compiles clean, 0 errors**, whole application. The generated code hides
`?Browse:1`, reads its columns with `PROPLIST:FieldNo` and friends, and reads values with
`WHAT(Queue:Browse:1, fieldno)` — the browse itself is untouched.

Two things that testing caught, which reading would not have:

- **`Queue:Browse` is wrong.** ABC names the first browse queue `Queue:Browse:1`. The prompt default
  said otherwise until a real app said so.
- **A value-returning `#GROUP` cannot be called from an emitted line.** `%bgRgb(%bgCBack)` inside
  generated source is not a call — substitution looks for a symbol of that name and reports
  `Unknown Variable`. Template expressions can call groups; output lines cannot. The BGR-to-RGB
  conversion is an ordinary Clarion function now, `BG_Rgb`, written once by the global extension.

## Two more that only running it found

The grid drew its header and columns correctly and showed **no rows at all**. Two causes, both invisible
to inspection:

- **The refill was unreachable code.** It was embedded in `ThisWindow.TakeEvent` at a high priority, and
  that method *returns* the moment `PARENT.TakeEvent()` comes back:

  ```
    ReturnValue = PARENT.TakeEvent()
      RETURN ReturnValue        <-- returns here
    END
    ReturnValue = Level:Fatal
      IF Grid1:G
        DO BG:Fill:Grid1        <-- generated, compiled, never ran
  ```

  It now hangs off `Reset` — which ABC calls when the browse has refilled — and `TakeNewSelection`, which
  between them cover scrolling, locating, filtering and editing. **A high priority is not "last"; it can
  be past the RETURN.**

- **Hiding the LIST was wrong.** A hidden LIST is one ABC may decide has no rows to show, since it loads
  by the control's visible row count. The LIST is now **covered, not hidden**: it goes on filling its
  queue, counting rows, holding the selection and answering the browse exactly as before, and the region
  simply sits over it — created later, so drawn on top. Same trick allImageRead uses over its IMAGE.

## What to do with the LIST — three wrong answers before the right one

1. **Hide it.** ABC loads a browse by the control's visible row count, so a hidden LIST shows no rows at
   all. The grid drew a header over an empty page.
2. **Leave it where it is.** It repaints straight over the grid the moment it is clicked — two controls
   in one rectangle, both painting, and the one that redraws last wins.
3. **Park it off the window.** Fixed the painting, and lasted until the first resize: ABC's resizer works
   every control's position out from the *design* layout, so it hauled the LIST straight back over the
   grid and the template thought it was still parked.

The right answer is not to move it at all, but to make Windows respect the stacking order.
**`WS_CLIPSIBLINGS`** on the LIST means it cannot paint into the rectangle of a sibling above it; the
region is raised to the top and re-raised on every resize, because a resize can restack them. The LIST
stays exactly where the resizer puts it, doing everything it did before, and simply never appears.

Three attempts, and the first two each looked right until something touched the window.

## Resizing: measure after the resizer, not with it

The grid stayed its old size while the LIST grew. `EVENT:Sized` reaches this template *before* the window
resizer has moved anything, so measuring the LIST there returns the size it used to be — and nothing ever
looks again.

`EVENT:Sized` now just **posts** a private event. That puts the move at the back of the queue, by which
time the resizer has finished and the LIST is the size it is going to be; the region follows it, the
render target is resized to match, and the page is refilled because a taller browse holds more rows. It
needs to know nothing about the resizer, which is the point — any resizer, any priority.

## Scrollbars: one is ours, one is the browse's

The LIST's own scrollbars went off the window with it, so the grid needed its own — but the two
directions are completely different jobs.

- **Sideways is the grid's.** The columns can be wider than the region; nothing in the file changes when
  you slide them. The bar is sized from `d2g_TotalWidth` against `d2g_ViewWidth`, and moving it just sets
  `d2g_ScrollX` and repaints. Windows hides a bar whose page covers its range, so it appears only when
  the columns really are too wide.
- **Downwards is the browse's.** The grid has no idea where it is in the file — only ABC does. So the
  vertical bar is a remote control: a line, a page or an end posts the matching `EVENT:ScrollUp` /
  `PageDown` / `ScrollBottom` at the parked LIST, and a dragged thumb sets `PROP:VScrollPos` and posts
  `EVENT:ScrollDrag` — exactly what the LIST's own bar would have done. The browse refills its queue,
  ABC calls `Reset`, and that is where the grid picks up the new page. Paging, locators and range limits
  therefore behave exactly as they always did.

The thumb is approximate on an ISAM file, because `PROP:VScrollPos` is a nought-to-a-hundred estimate —
the same approximation Clarion's own browse thumb shows, for the same reason: the file cannot say what
its 743,000th record is without counting.

## Still to come

Smooth scrolling end to end. The engine scrolls by pixels already; the Clarion side currently pushes
the browse's own queue, which is one page, so it moves a page at a time like any browse. Buffering a
few pages around the viewport and moving through the VIEW with NEXT/PREVIOUS is the next piece.
