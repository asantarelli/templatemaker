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

## The third position for the LIST

Neither hidden nor left in place. Both were wrong, for opposite reasons:

- **Hidden** — ABC loads a browse by the control's visible row count, so a hidden LIST shows no rows.
- **Left where it was** — it repaints straight over the grid the moment it is clicked. Two controls in
  one place, both painting.

So it is **parked**: still there, still full size, still filling its queue and holding the selection, but
moved out past the edge of the window where Windows clips it away. It is parked by a fixed offset rather
than to a fixed spot, so the window resizer can go on moving and sizing it exactly as before and the
region simply follows it back by the same distance. Clicking a row also puts the focus on the region, so
nothing pulls the parked LIST into view.

## Still to come

Smooth scrolling end to end. The engine scrolls by pixels already; the Clarion side currently pushes
the browse's own queue, which is one page, so it moves a page at a time like any browse. Buffering a
few pages around the viewport and moving through the VIEW with NEXT/PREVIOUS is the next piece.
