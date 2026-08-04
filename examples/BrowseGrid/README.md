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

## Still to come

Smooth scrolling end to end. The engine scrolls by pixels already; the Clarion side currently pushes
the browse's own queue, which is one page, so it moves a page at a time like any browse. Buffering a
few pages around the viewport and moving through the VIEW with NEXT/PREVIOUS is the next piece.
