# Clarion Template Maker

Tooling to make Claude a **Clarion 12 template authoring professional** — for creating and editing the
`.tpl`/`.tpw` files that drive Clarion's Application Generator (AppGen).

This was built by studying the installed Clarion 12 template corpus:
- Shipped ABC + classic templates — `C:\clarion12\template\win\` (160 `.tpl`, 626 `.tpw`)
- Third-party / accessory templates — `C:\clarion12\accessory\template\win\` (AJE*, CapeSoft AnyFont/
  AnyText, ChromeExplorer, HotDates, KeepingTabs, Cryptonite, …)
- Official docs — `C:\clarion12\docs\TemplateLanguageReference.pdf`, `TemplateGuide.pdf`

## What was created

### 1. Skill — `clarion-template`
Location: `~/.claude/skills/clarion-template/`

A reusable knowledge pack Claude loads when working on any `.tpl`/`.tpw` file:
- `SKILL.md` — file types, the three-rule mental model (directive vs. literal, `#!` vs `!`,
  parse-time vs generate-time), the 80%-case extension skeleton, authoring workflow, correctness rules.
- `reference/directives.md` — full directive vocabulary (`#TEMPLATE`/`#PROCEDURE`/`#CONTROL`/
  `#EXTENSION`/`#CODE`/`#GROUP`, the `#PROMPT`/`#SHEET`/`#TAB`/`#BOXED` UI set, `%Symbol` state,
  control flow, `#AT`/`#EMBED` injection, `#GENERATE`/`#CREATE`/`#INSERT`) with real signatures.
- `reference/patterns.md` — the playbook: disable switch, multi-DLL externals + export lists, `ONCE`
  includes, Init/Kill lifecycle, multi-instance naming, `#GROUP` reuse, project files, custom embeds.
- `reference/examples.md` — three complete annotated templates (a procedure extension, an application
  extension, a value-returning group) plus a verification checklist.

### 2. Agent — `clarion-template-pro`
Location: `~/.claude/agents/clarion-template-pro.md`

A specialist subagent trained on the above. Use it for any template task — writing a new
procedure/control/extension/code/group template, modifying or debugging an existing one, explaining
directives, or designing the AppGen prompt UI and embed wiring. It reads the skill references and the
shipped corpus before writing, respects the parse-time/generate-time model, and predicts the generated
Clarion source so you know exactly what to verify.

## Repo layout

```
skills/clarion-template/        # the skill (SKILL.md + reference/)
agents/clarion-template-pro.md  # the specialist subagent
templates/                      # ready-to-register Clarion templates
  myPixel.tpl                   #   per-window diagnostic pixel (see below)
  showLine.tpl                  #   Ctrl+Shift+P "where am I" hotkey (see below)
  identifier.tpl                #   Ctrl+Shift+I shows the procedure name
  myFuncs/                      #   global function library (see below)
    myFuncs.tpl                 #     self-contained: prototypes + bodies in one template
  myPie/                        #   pie chart for a window (see below)
    myPie.tpl                   #     global helper + procedure extension
  myFontChanger/                #   global + per-list font picker (see below)
    myFontChanger.tpl
  myBackground/                 #   global default + per-window background color/image (see below)
    myBackground.tpl
  myQR/                         #   QR code into an image control, auto-refresh (see below)
    myQR.tpl
  myGauge/                      #   analog gauge/dial on windows and reports (see below)
    GaugeClass.inc              #     the gauge class (config + method prototypes)
    GaugeClass.clw              #     the implementation (geometry + native drawing)
    myGauge.tpl                 #     global include + window + report extensions
  graficaBarra/                 #   bar graphs on windows and reports, vector on PDF (see below)
    GraficaBarraClass.inc       #     the bar-graph class (config + method prototypes)
    GraficaBarraClass.clw       #     the implementation (scale + BOX/LINE/SHOW drawing)
    graficaBarra.tpl            #     global include + window + report extensions
    graficaBarra.zip            #     the three files above, zipped for easy distribution
  myGaugePlus/                  #   ANTIALIASED (GDI+) gauge/dial on windows (see below)
    gpcanvas.c                  #     GDI+ flat-API shim (bound at runtime, compiled by Clacpp)
    AaCanvasClass.inc/.clw      #     reusable antialiased 2D canvas over GDI+
    GaugePlusClass.inc/.clw     #     the pretty gauge, drawn on the canvas
    myGaugePlus.tpl             #     global include + window + control template
  myCompress/                   #   pure-Clarion compression: DEFLATE/zlib/gzip (see below)
    CompressClass.inc           #     the codec class (config + method prototypes)
    CompressClass.clw           #     the implementation (inflate/deflate/containers)
    CompressClassC.inc          #     optional C-backed subclass (the fast engine)
    CompressClassC.clw          #     overrides Wrap/Unwrap to call mc.c
    mc.c                        #     our own DEFLATE in C (compiled by Clarion's Clacpp)
    myCompress.tpl              #     one global extension (engine prompt: Clarion / C)
  myPdfSign/                    #   pure-Clarion signed-PDF reader: who signed it (see below)
    PdfSignClass.inc            #     the reader class (config + method prototypes)
    PdfSignClass.clw            #     the implementation (PDF parse + PKCS#7/DER walk)
    myPdfSign.tpl               #     one global extension (the shared object)
  myCalc/                       #   pop-up calculator beside a numeric field (see below)
    CalcClass.inc               #     the calculator (4 modes, tape, EN/ES strings)
    CalcClass.clw               #     the implementation (keypad, arithmetic, window)
    calc16.ico                  #     the little calculator on the button
    myCalc.tpl                  #     global extension + button control + code template
    myCalc.zip                  #     the four files above, zipped for easy distribution
  myCalendar/                   #   pop-up date picker beside a date field (see below)
    MyCalendarClass.inc         #     the calendar (views, range, EN/ES strings)
    MyCalendarClass.clw         #     the implementation (date maths, drawing, window)
    cal16.ico                   #     the little calendar on the button
    myCalendar.tpl              #     global extension + button control + code template
    myCalendar.zip              #     the four files above, zipped for easy distribution
  myExport/                     #   export any browse/list to 7 file formats (see below)
    ExportClass.inc             #     the export engine (config + method prototypes)
    ExportClass.clw             #     the implementation (dialog + 7 writers + ZIP + UTF-8)
    myExport.tpl                #     global extension + Export-button control + code template
    myExport.zip                #     the three files above, zipped for easy distribution
designer/ClarionTplDesigner/    # WPF visual designer for the prompt UI (see below)
installer/                      # builds the installer + a portable single-file exe
README.md
```

## Included templates

### `templates/myPixel.tpl` — per-window diagnostic pixel
A global (APPLICATION-scope) ABC extension that needs no per-procedure setup. On **every** procedure
that owns a window it drops a tiny configurable REGION "pixel" in the top-left corner. Hovering it shows
a tooltip with the **procedure name**, the current **thread number**, and the **binary** the procedure
lives in (app/EXE or DLL). Pressing **Ctrl+Shift+I** pops a message box with the same information.

- Prompts: master disable, pixel fill color, pixel size, and a Ctrl+Shift+I hotkey toggle.
- Implementation: a self-contained `CASE EVENT()` injected at the top of `WindowManager.TakeWindowEvent`
  (PRIORITY 2000, before the framework's CYCLE/BREAK loop), creating the control on `EVENT:OpenWindow`
  and answering `EVENT:AlertKey`. Local-only code — no globals, so no multi-DLL handling needed.
- Register it like any template (see below), then add **myPixel - Diagnostic Pixel (Global)** under
  Global → Extensions.

### `templates/showLine.tpl` — Ctrl+Shift+P "where am I" hotkey
A global (APPLICATION-scope) ABC extension that needs no per-procedure setup. On **every** windowed
procedure it alerts **Ctrl+Shift+P**; pressing it pops a message telling you where you are: the
**procedure** (the code you're in), the **control with focus** (its field number and USE variable), the
**thread number**, and the host **binary** (EXE/DLL).

- Prompts: master disable, a toggle to include the focused-control details, and a custom message title.
- Implementation: a self-contained `CASE EVENT()` injected at the top of `WindowManager.TakeWindowEvent`
  (PRIORITY 2000); `ALERT(CtrlShiftP)` on `EVENT:OpenWindow`, and on `EVENT:AlertKey` it reads `FOCUS()`
  and `feq{PROP:Use}` to report the live focus. Local-only code — no globals, so no multi-DLL handling.
- Register it, then add **showLine - Where-Am-I Hotkey (Global)** under Global → Extensions.

### `templates/identifier.tpl` — Ctrl+Shift+I shows the procedure name
A global (APPLICATION-scope) ABC extension, no per-procedure setup. It alerts **Ctrl+Shift+I** on every
windowed procedure; pressing it pops a message box with the current **procedure name** (baked in at
generation time via `%Procedure`). Same proven injection as the other hotkey templates (self-contained
`CASE EVENT()` at the top of `WindowManager.TakeWindowEvent`). Register it and add **identifier - Show
Procedure Name (Ctrl+Shift+I)** under Global → Extensions.

### `templates/myFuncs/` — global function library
A global (APPLICATION-scope) ABC extension that makes a growing set of utility **functions** callable
from anywhere in the app, with no per-procedure setup and **no external source files**. The template
is self-contained: it adds each prototype **bare** to the program's global `MAP` (`#AT(%GlobalMap)`)
and writes each function **body into the program module itself** (`#AT(%ProgramProcedures)`). Prototype
and body in the same module is the simplest, always-valid Clarion structure. Grow the library by adding
one prototype line and one body to `myFuncs.tpl` — nothing else to wire.

**Functions provided** (both take an omittable date that defaults to today):
- **`weekNumber(<date>),LONG`** — **ISO‑8601 (European)** week number. Weeks start Monday; week 1 is the
  week containing the year's first Thursday (the week with Jan 4). Early‑January dates can fall in week
  52/53 of the *prior* year.
- **`weekNumberUS(<date>),LONG`** — **US / North‑American** week number. Weeks start Sunday; week 1 is the
  week containing January 1st, so Jan 1 is always in week 1.

```clarion
wk  = weekNumber()              ! this week's ISO number
wk2 = weekNumber(myOrder:Date)  ! ISO week of a specific date
us  = weekNumberUS(myOrder:Date)! US week of the same date (can differ by one)
```

Install: register `myFuncs.tpl`, then add **myFuncs - Global Function Library (Global)** under
Global → Extensions, generate, and build. (No source files to copy — everything is generated.)

### `templates/myPie/` — pie chart on a window
Renders a pie chart into an IMAGE control using Clarion's built-in `PIE` graphics primitive (no external
files). **Easiest path: a control template** — drag **myPie - Pie Chart** straight onto a window and it
drops the IMAGE *and* wires the pie + legend in one go, fully self-contained (no global/procedure extension
needed). Drop several on one window. Or use the two-extension route for an existing IMAGE control. Four
registrations in all:
- **`myPieControl`** (CONTROL) — the drag-on pie. Set the 3D depth, background, legend/percentages, and the
  segments (label / relative **value** / **color**); each control owns its own data (keyed off its **Image
  control**, so there are no names to keep in sync) and redraws on open/resize. The segments **seed a runtime
  `QUEUE`** (`<Image>:Q`, fields `QLabel`/`QValue`/`QColor`) — so the slice count is **unbounded** at run
  time, not fixed at generation. The redraw rebuilds the `PIE()` arrays (fixed `DIM(64)` buffers; a 0-value
  slice is an invisible 0° wedge) and walks the queue for the legend. Depth / legend / percentages are
  **run-time variables** so a panel can change them live.
- **`myPiePanel`** (CONTROL, **MULTI**) — a drag-on **live control panel**: a 3D-depth field, show-legend and
  show-percentages **toggle buttons**, and an **editable slice list with Add / Edit / Delete**. Link it by
  **picking the pie's Image control** (a drop-list — no typed names). The list shows every slice; **Add**,
  **Edit** (or **double-click** a row), and **Delete** edit them through a small **modal popup** (Label /
  Value / **Color** via the color dialog) — so you are no longer capped at a handful of slices. Every change
  repaints the pie **live**. **Drop one panel per pie** on the same window — it's multi-instance: the on-window
  controls are field-equates (auto-uniqued, captured in `#ATSTART`) and the per-instance data (the modal +
  its fields) is keyed by `%ActiveTemplateInstance`, so panels never collide. (Editing is plain queue + modal
  Clarion — no `QEIPManager`/EIP classes, which proved unstable as a standalone in-cell editor.)
- **`myPieGlobal`** (APPLICATION) — adds the global helper `myPieDraw(window, imageFeq, slices[], colors[],
  …)` to the program module. Add once, globally (only needed for the procedure-extension route).
- **`myPie`** (PROCEDURE) — drop on a window procedure; pick a sized **IMAGE control**, set 3D depth /
  background, and define the segments. Draws the pie plus a **legend** (swatch + label + **percentage**),
  redraws on **resize**, and exposes a **`myPieRepaint`** routine.

`PIE` (`builtins.clw:1402`) takes a SIGNED array of relative slice sizes and a LONG array of colors and
draws the whole chart in one call. The drawing uses **`SETTARGET(window, ?image)`** so the IMAGE itself is
the target (origin `0,0`, the graphics belong to the control and survive a repaint/resize, and a `BLANK`
clears only that image) — the same model as myGauge, so multiple pies never erase each other.

Install: register `myPie.tpl`, then either drop **myPie - Pie Chart** from the control toolbox, or add
**myPie - Global Helper** (Global → Extensions) + the **myPie** procedure extension on a window. **Upgrade
note:** the `myPieDraw` helper gained a leading `WINDOW` parameter, so **regenerate** any app built against
the older one (a stale call shows as "No matching prototype available").

### `templates/myFontChanger/` — global + per-list font picker
A single global (APPLICATION-scope) ABC extension, no per-procedure setup:
- Applies a **default font** (name + size) to every browse/`LIST` control at window open.
- **Right-click any list** at run time for a popup menu (**Change Font…** → the Windows font dialog, or
  **Reset to Default Font**).
- With a list focused, **Ctrl+Plus / Ctrl+Minus** change its font size up/down by **1 point** and save it.
- Saves each list's choice in **its own INI section** (`[Procedure_Control]`, with Name/Size/Color/Style)
  and re-applies it on reopen — a stored per-list font overrides the global default; reset reverts to it.

It adds two helpers to the program module (`myFontApply`, `myFontChange`) and injects into
`WindowManager.TakeWindowEvent` (apply fonts + arm the right-click on `EVENT:OpenWindow`) and
`TakeFieldEvent` (list events arrive there with `FIELD()` = the list). Uses `SETFONT`, `FONTDIALOG`,
`GETINI`/`PUTINI`, and armed-key alerts (`MouseRightUp` for the menu, `CtrlPlus`/`CtrlMinus` for sizing).
The extension has a **General** tab (default font, size, INI name) and an **Instructions** tab.
Register it, add **myFontChanger - global per-list font picker** under Global → Extensions, set the
default font + INI name, generate and build.

### `templates/myBackground/` — global default + per-window background color / image
A single global (APPLICATION-scope) ABC extension, no per-procedure setup:
- Gives **every window** a **global default background** — a solid **color** and/or an **image** — applied
  automatically at window open.
- Press **Ctrl+Shift+B** on any window for a small chooser: **Background Color…** (color dialog),
  **Background Image…** (file dialog, stretched to fill), or **Use Default** (drop this window's
  personal setting and revert to the global default).
- Saves each window's choice in **its own INI section** (`[Procedure]`, with `Mode`/`Color`/`Image`) and
  re-applies it on reopen — a stored personal background **overrides** the global default.

It adds two helpers to the program module (`myBackApply`, `myBackChoose`) and injects into
`WindowManager.TakeWindowEvent` (apply the background + arm the hotkey on `EVENT:OpenWindow`; pop the
chooser on `EVENT:AlertKey`). At run time a solid color is set with `0{PROP:Color}` and an image with
`0{PROP:WallPaper}` (with `PROP:Tiled`/`PROP:Centered` off so it stretches to fill); uses `COLORDIALOG`,
`FILEDIALOG`, `GETINI`/`PUTINI`, and an armed `Ctrl+Shift+B` alert. The extension has a **General** tab
(default color, default image, INI name, hotkey toggle) and an **Instructions** tab. Register it, add
**myBackground - per-window background color / image** under Global → Extensions, set your defaults +
INI name, generate and build. Full programmer's documentation (prompts, generated code, embed points,
the `myBackApply`/`myBackChoose` helper API, and the runtime properties it uses) is in
[`docs/myBackground-template.html`](docs/myBackground-template.html).

### `templates/myQR/` — QR code into an image control
A self-contained ABC **procedure** extension that renders a **QR code** into an `IMAGE` control on a window.
The QR **value** can be a design-time **literal** (a quoted string) **or any Clarion variable/expression** you
change in code (e.g. `Cus:Email`, `loc:URL`) — it's emitted verbatim, so it's read at run time. With
**auto-refresh** on, a window timer watches the value and reloads the QR whenever it changes; you can also
force a redraw anytime with `DO myQRRefresh`. Prompts: image control, value, size, error-correction (L/M/Q/H),
quiet-zone margin, and the auto-refresh toggle/poll.

Since Clarion has no built-in QR encoder, the PNG is fetched from the free public web service
**`api.qrserver.com`** (goqr.me) and loaded into the image with `feq{PROP:Text}=file`. The download uses
**`curl.exe`** (ships with Windows 10/11), launched **hidden and synchronously** via `CreateProcessA` +
`WaitForSingleObject` (no console flash; the PNG is on disk before the image loads). It's self-contained (a
URL-encoder + a download/load helper in the program module; no external `.inc`/`.clw`). **Privacy/internet
caveat:** the value is sent over HTTPS to that third-party service every render and an internet connection is
required — don't encode secrets, or repoint the helper at your own QR endpoint / a local library for
offline use. Register it, add **myQR - QR code into an image control** to a window procedure's Extensions,
pick a sized IMAGE control, set the value, generate and build. Full programmer's documentation (prompts,
the literal-vs-code value, generated code, the `myQRLoad`/`myQRUrlEncode`/`myQRRefresh` API, the curl/
CreateProcess download, and the privacy caveat) is in [`docs/myQR-template.html`](docs/myQR-template.html).

### `templates/myQRDraw/` — offline QR code drawn with BOX primitives
The **offline** companion to myQR: instead of downloading a PNG, it carries a complete **QR encoder** and
draws every module as a filled `BOX` into an `IMAGE` control — exactly the way myPie draws a pie. **No
internet, no `curl`, no temp files.** The window `Draw` renders in **pixel units** (`0{PROP:Pixels}`), so
adjacent module boxes abut on exact pixel boundaries — no dialog-unit rounding leaves thin white seams
between modules (and it stays crisp across repaints; the report path keeps report units). The window
`Draw` targets the image with the **two-argument `SETTARGET(Window, ?Image)`**, so its `BLANK` is clipped to
the image rectangle and the modules paint from a `0,0` origin — several QR codes on one window no longer erase
each other, and `Draw` also accepts a plain `STRING` value, not only a `CSTRING`. A **global** extension adds the encoder + the `QRDraw()` helper (add
once per app); a **procedure** extension wires it to a window, redrawing on open/resize. The value can be a
design-time **literal** or any **Clarion variable/expression** (change it and `DO myQRDrawRepaint`). Prompts:
image control, value, ECC level (L/M/Q/H), dark/light colors, quiet-zone width, and a **self-test** that
draws a fixed `HELLO WORLD` symbol so you can confirm the encoder works by scanning it.

**Reports** render bands through the print engine, not window events, so a separate **myQRDrawReport**
extension handles them: drop an IMAGE control in the detail band, add the extension, and a code is drawn
**per record** in the *Before-Print-Detail* embed via `SETTARGET(Report)` (the window extension and the
report extension share the same encoder and `QRPaint()` drawing — only the draw target and timing differ).

The encoder (byte mode, **versions 1–10**, automatic version + mask) is a line-for-line port of the
ZXing-validated C# reference in [`designer/QrCodeCore/`](designer/QrCodeCore/); its exact `HELLO WORLD`/ECC-M
matrix is pinned by a golden test, and that is the same symbol the self-test draws. The encoder ships as a
self-contained Clarion **class** — `QRCodeClass.inc` + `QRCodeClass.clw` (stored in **ANSI**) — so it compiles
in its own module instead of filling the program's global procedure area; the global extension just
`INCLUDE`s it and declares one `QRCodeObj` instance. Copy the two class files to a folder on the Clarion
redirection path (your app folder or `\clarion12\libsrc\win`). Choose myQRDraw for kiosks, point-of-sale,
field laptops, air-gapped networks, and reports that must render with zero external dependencies; choose myQR
when an internet round-trip is acceptable. Full programmer's documentation is in
[`docs/myQRDraw-template.html`](docs/myQRDraw-template.html).

### `templates/myBarcodeGen/` — nine barcode types, offline, drawn with BOX primitives
A generalization of myQRDraw to **nine symbologies**: the **linear (1D)** codes **Code 39, Code 128**
(auto Code B / Code C), **Interleaved 2 of 5, EAN-13, UPC-A**, and the **2D** codes **QR, Data Matrix,
PDF417, Aztec**. Same offline approach — encode at run time, draw with `BOX`es (1D = full-height bars +
optional human-readable text; 2D = a module/stacked grid). As in myQRDraw, every window `Draw` renders in
**pixel units** (`0{PROP:Pixels}`) so modules/bars abut on exact pixel boundaries — no dialog-unit rounding
leaves thin white seams (the report path keeps report units). Pick the **Barcode type** from a drop-list; the
rest is like myQRDraw (value literal-or-variable, colors, quiet zone), with **window** and **report**
extensions. Each encoder is a self-contained ANSI Clarion class, ported from the ZXing-validated C# reference
[`designer/BarcodeCore/`](designer/BarcodeCore/) (**42 round-trip tests**): `BarcodeClass` (1D),
`QRCodeClass`, `DataMatrixClass` (ECC200), `Pdf417Class` (GF(929) + a packed pattern table), and `AztecClass`
(variable Galois field, bullseye + spiral). Copy the five encoder classes (ten `.inc`/`.clw` files) to the
Clarion redirection path. Reed–Solomon spans four different fields across the set (GF(256) poly 0x11D/0x12D,
the prime field GF(929), and GF(2^n) for Aztec). Full **developer's manual** (install, the class APIs, per-
symbology rules, drawing model, multi-DLL, troubleshooting) is in
[`docs/myBarcodeGen-template.html`](docs/myBarcodeGen-template.html).

### `templates/myGauge/` — analog gauges/dials on windows and reports
A configurable **analog gauge** drawn entirely with native Clarion graphics (`ARC`, `ELLIPSE`, `LINE`,
`POLYGON`, `SHOW`) into an `IMAGE` control — the same offline, no-dependency approach as myPie and myQRDraw.
A single self-contained ANSI class, **`GaugeClass`**, holds the configuration (range, span, colors, ticks,
zones) and renders itself; each gauge on a window is its **own local object**, so multiple dials per window
or report just work. **Easiest path: a control template** — drag **myGauge - Analog Gauge** straight onto a
window and it drops the IMAGE *and* wires the gauge in one go, fully self-contained (it `INCLUDE`s the class
itself, so no global extension is needed). Pick an **arc style** — 45°, 90°, 180°, 270° (speedometer), 360°,
or a **custom** start + signed sweep — set the **min/max range**, then drive the needle from a **literal** or
any **variable/field**.
Configurable everything: major/minor **ticks** with numeric labels, a digital **value readout**, **title/units**
text, a **triangle or line needle**, face/rim/track/tick/text colors, up to 16 colored **zones** (e.g. green
0–60 / amber 60–85 / red 85–100), and **smooth needle animation** via the window timer (`AnimateTo` +
`AnimStep`). Four registrations: the **myGaugeControl** control template (drag-on, self-contained) plus three
extensions — **myGaugeGlobal** (include the class once), **myGauge** for **windows** (redraw
on open/resize, optional animation, a generated `Refresh:<Object>` routine), and **myGaugeReport** for
**reports** (a gauge per record, drawn at `%BeforePrint` under `SETTARGET(Report)`). Copy `GaugeClass.inc` +
`GaugeClass.clw` (ANSI) to the redirection path. Full programmer's documentation — shapes, prompts, the class
API, run-time control, and troubleshooting — is in [`docs/myGauge-template.html`](docs/myGauge-template.html).

### `templates/graficaBarra/` — bar graphs on windows and reports (vector on PDF)
A **simple bar graph** drawn entirely with native Clarion primitives (`BOX`, `LINE`, `SHOW`) — the same
offline, no-dependency family as myPie and myGauge. One self-contained ANSI class, **`GraficaBarraClass`**,
holds the bars (up to 48: label, value, color) and the look (title, value/scale labels, gridlines, gaps,
colors, auto or fixed scale with a "nice" 1/2/5×10ᵏ maximum; negative values hang below the zero baseline)
and renders itself; every graph is its **own local object**, so several per window or report just work.
The report path is the point: **graficaBarraReport** draws the graph **straight into the band as vector
`BOX`/`LINE`/`SHOW` primitives** under `SETTARGET(Report)` at `%BeforePrint` — never a bitmap — so a
**PDF export stays as small as possible**. A control in the detail band (IMAGE/BOX) is used *only* as the
position/size placeholder and is hidden at print time. On windows, **graficaBarra** draws into an `IMAGE`
control (redraw on open/resize, plus a generated `DO Refresh:<Object>` routine that re-reads
variable/expression bar values). Bars are defined in the prompts (literal value or a field/expression, auto
professional palette or a per-bar color); an empty list draws six sample bars as a self-test. Three
registrations: **graficaBarraGlobal** (include the class once), **graficaBarra** (window),
**graficaBarraReport** (report). Copy `GraficaBarraClass.inc` + `.clw` (ANSI) to the redirection path —
[`graficaBarra.zip`](templates/graficaBarra/graficaBarra.zip) bundles all three files for easy
distribution. Full docs — prompts, class API, run-time control — in
[`docs/graficaBarra-template.html`](docs/graficaBarra-template.html); a bilingual (English + Spanish)
developer's reference with worked example code is in
[`docs/graficaBarra-reference.html`](docs/graficaBarra-reference.html).

### `templates/myGaugePlus/` — **antialiased** (GDI+) gauges/dials on windows
The pretty sibling of myGauge. Native Clarion `ARC`/`ELLIPSE`/`LINE` have **no antialiasing**, so round
gauges drawn with them look jagged — myGaugePlus draws every pixel with **GDI+** instead: smooth arcs with
rounded caps, a **glossy radial-gradient face**, an antialiased needle and crisp text, rendered to a PNG and
shown in an `IMAGE` control. It carries **no redistributable** — `gdiplus.dll` ships with Windows, and the
bridge to its flat C API is a tiny shim (`gpcanvas.c`) bound at runtime (`LoadLibrary`/`GetProcAddress`) and
compiled automatically by Clarion's own compiler (`PRAGMA('compile')` inside `AaCanvasClass.clw`) — so there
is **no manual project step**. Three layers ship together: **`gpcanvas.c`** (the GDI+ shim),
**`AaCanvasClass`** (a reusable antialiased 2D canvas — `Arc`/`Line`/`FillCircleGrad`/`Polygon`/`Text`/
`SavePng`, useful for any drawing), and **`GaugePlusClass`** (the gauge, with the *same* API shape as
`GaugeClass`: `SetRange`/`Preset`/`AddZone`/`SetValue`/`AnimateTo`/`Draw`). Same prompts and presets as
myGauge — arc styles, range, literal-or-variable value, ticks/labels, title/units, up to 16 colored zones,
and **eased needle animation** — plus a glossy **value/accent fill**, face-gloss and rim toggles, an
optional **face image** drawn as the dial's base layer (a photo/texture/logo dial, disc-clipped: set
`Gauge.FaceImage = 'path'`), and automatic **centring for every span** (90/45/180/custom sit centred in the
control, not just the full 270/360 dials). Three
registrations: the **myGaugePlusControl** control template (drag-on, self-contained) and the
**myGaugePlusGlobal** + **myGaugePlus** (window) extensions. The transparent PNG composites cleanly onto any
window; it is **window-only** (use myGauge for report-band gauges). Copy the five files
(`GaugePlusClass.inc/.clw`, `AaCanvasClass.inc/.clw`, `gpcanvas.c`, all ANSI) to the redirection path. Full
docs — how it works, prompts, the `GaugePlusClass` + `AaCanvasClass` API, and gotchas — are in
[`docs/myGaugePlus-template.html`](docs/myGaugePlus-template.html). A hand-coded, ready-to-compile
**live property playground** — [`examples/myGaugePlus/GaugePlusPlayground.clw`](examples/myGaugePlus/GaugePlusPlayground.clw)
(build `GaugePlusPlayground.cwproj`) — drives *every* property in real time from a tabbed panel of sliders,
radios, check boxes and colour pickers beside a big live gauge, so you can see exactly what each option does
before wiring the template.

### `templates/myCompress/` — pure-Clarion compression (memory + files)
A self-contained **compression library** written entirely in **pure Clarion** — no DLL, no external
library. One self-contained ANSI class, **`CompressClass`**, implements **DEFLATE (RFC 1951)** with the
**zlib (RFC 1950)** and **gzip (RFC 1952)** wrappers, so a `.gz` it writes opens in gzip / 7-Zip /
browsers / .NET `GZipStream`, and it reads any DEFLATE-family stream those tools produce. Decompression
(INFLATE) is complete — stored + fixed + dynamic Huffman; compression is **LZ77** (a hash-chain match
finder) + fixed Huffman, with Level 0 emitting stored blocks. Add **one global extension** —
**myCompress - Global Compressor** — and reach the shared object from any embed; there is **no per-window
or per-report wiring** (compression is all code-driven). It works on **memory buffers** (length-explicit
`Compress`/`Decompress(*STRING,LONG,*STRING)`) **and files** (`CompressFile`/`DecompressFile`), carries
**CRC32** (gzip) and **Adler32** (zlib) checksums, and ships a `SelfTest()` smoke test. Pick the format
(`Cmp:Raw`/`Cmp:Zlib`/`Cmp:Gzip`) and level (0–9) at run time; decompression **auto-detects** the
container. The codec is validated by a .NET golden-vector oracle, [`designer/CompressCore/`](designer/CompressCore/),
that round-trips a corpus both ways (Clarion ↔ `GZipStream`/`ZLibStream`/`DeflateStream`). Copy
`CompressClass.inc` + `CompressClass.clw` (**ANSI, CRLF**) to the redirection path.

**Optional C fast-path (~4× faster).** For big files or high throughput, pick the **C engine** in the
extension's *Compression engine* prompt. It's `CompressClassC` — a thin subclass that overrides the virtual
`Wrap`/`Unwrap` to call **`mc.c`**, our own clean-room DEFLATE port (not miniz/zlib/StringTheory) compiled by
**Clarion's own C compiler** via `PRAGMA('compile(mc.c)')`. Compression of a 4 MB buffer drops from ~844 ms
to ~200 ms (and a slightly better ratio, since C has no 64 KB-array limit so it uses the full 32 KB window).
It's the same algorithm, so the two engines produce byte-compatible output and interoperate freely. The
switch is the **template prompt** (it declares the global object as `CompressClass` or `CompressClassC`), so
a pure-Clarion app needs **no `mc.c` and no subclass** — copy the C files only when you choose that engine.

Full programmer's documentation — the API, formats, run-time control, the C fast-path, error codes, and
troubleshooting — is in [`docs/myCompress-template.html`](docs/myCompress-template.html).

### `templates/myPdfSign/` — read a signed PDF and see who signed it
A self-contained **signed-PDF identity reader** written entirely in **pure Clarion** — no DLL, no external
library, no network. One ANSI class, **`PdfSignClass`**, opens a digitally-signed PDF and surfaces the
**authoritative signer identity** that lives in the embedded **PKCS#7 / CMS** signature: the signer
certificate's **Subject** (`SubjectCN` / `SubjectO` / `SubjectOU` / `SubjectEmail`), the issuing CA
(`IssuerCN`), the **signing time** (`SignTime`, ISO-8601 UTC, read from the signed attributes — not the
spoofable `/M`), plus the signature dictionary's own `/Name` (`SignerName`), `/Reason`, `/Location`,
`/SubFilter`, and a `SigCount`. It also reports **`CoversWholeFile`** — 1 when `/ByteRange` spans the whole
file, 0 when bytes were appended after signing (a tamper / incremental-update hint). It works on **files**
(`ReadFile`) or a **memory buffer** (`Read(*STRING,LONG)`), exposes a `Report()` block and a `SelfTest()`.
Internally it finds the `/ByteRange` + `/Contents <hex>` signature dictionary, hex-decodes the DER blob, and
a tiny **ASN.1 tag/length reader** walks `ContentInfo → SignedData → certificates[0] → tbsCertificate` to
read the Subject/Issuer RDNs by OID and the `signingTime` attribute. **Scope (be honest):** it extracts the
*named* signer + an integrity hint — it does **not** cryptographically verify the RSA/ECDSA signature or
validate the certificate trust chain. Add **one global extension** — **myPdfSign - Global signed-PDF reader**
— and reach the shared object (default `PdfSig`) from any embed; there is **no per-window or per-report
wiring**. Validated end-to-end against the real Clarion compiler and a .NET golden-fixture oracle
([`designer/PdfSignCore/`](designer/PdfSignCore/)) that **manufactures real signed PDFs** (CA-signed leaf
certs, detached PKCS#7 over a proper `/ByteRange`, `signingTime` in the signed attributes) and publishes the
ground-truth identity each one must yield — the Clarion `Report()` output matches **byte-for-byte across all
three fixtures**, including a deliberately tampered case that correctly reports `CoversWholeFile=0`. Copy
`PdfSignClass.inc` + `PdfSignClass.clw` (**ANSI, CRLF**) to the redirection path. Full programmer's
documentation is in [`docs/myPdfSign-template.html`](docs/myPdfSign-template.html).

Simplest possible use — declare the object, read a PDF, show the result (the `myPdfSign` global extension
declares `PdfSig` for you; in a hand-coded program just `INCLUDE('PdfSignClass.INC'),ONCE` and declare it):

```clarion
PdfSig  PdfSignClass                    ! one object is all you declare

  CODE
  IF PdfSig.ReadFile('contract.pdf')    ! open + parse the PDF
    IF PdfSig.Signed                    ! did it carry a signature?
      MESSAGE('Signed by : ' & CLIP(PdfSig.SubjectCN)    & |
              '|e-mail    : ' & CLIP(PdfSig.SubjectEmail) & |
              '|Issued by : ' & CLIP(PdfSig.IssuerCN)     & |
              '|Signed at : ' & CLIP(PdfSig.SignTime)     & |
              '|Intact?   : ' & CHOOSE(PdfSig.CoversWholeFile=1,'YES','NO — bytes added after signing'),|
              'Signature')
    ELSE
      MESSAGE('That PDF is not digitally signed.','Signature')
    END
  ELSE
    MESSAGE('Could not read the file: ' & CLIP(PdfSig.ErrText),'Error')
  END
```

In an AppGen app, add the **myPdfSign - Global signed-PDF reader** extension once, then drop the
`IF PdfSig.ReadFile(...) ... END` body into any embed (e.g. a button's **Accepted** embed). Parsing a PDF
already in memory? Use `PdfSig.Read(buffer, length)` instead of `ReadFile`.

### `templates/my3D/` — real WebGL2 3D scenes driven from Clarion
A **3D scene manager** that lets a Clarion app build and display **hardware-accelerated WebGL2** scenes with
**no JavaScript**. One ANSI class, **`WebGL2Class`**, exposes a rich object-oriented 3D API — **camera**
(`SetCamera`/`LookAt`/`SetFOV`/`OrbitCamera`), **lighting** (ambient, a directional key light, and up to 8
coloured **point lights**), **materials** (colour, metalness, roughness, opacity, emissive glow, wireframe),
**20+ mesh primitives** (`AddCube`, `AddSphere`, `AddCylinder`, `AddCone`, `AddPlane`, `AddTorus`,
`AddTorusKnot`, and the five Platonic solids `AddTetra`/`AddOcta`/`AddIcosa`/`AddDodeca`), **per-mesh
transforms** (`SetPos`/`SetRot`/`SetScale`/`SpinMesh`), plus **fog**, a ground **grid** and **axes**. It also
ships genuine **3D maths that run in Clarion** — a `Vec3` set (`Vec3Length`/`Distance`/`Dot`/`Cross`/
`Normalize`/`Lerp`) and a `Mat4` set (`Mat4Identity`/`Translate`/`Scale`/`RotateX/Y/Z`/`Perspective`/
`Multiply`) — so positions can be computed Clarion-side. `Show()` writes a **single self-contained `.html`**
(the scene data **plus** the verified `my3D.engine.js` renderer, inlined) and opens it in the default
browser; **drag to orbit, wheel to zoom, R to reset**. It can also render **inside a Clarion window** —
`ShowEmbedded()` positions a borderless Edge window (real WebGL2, its own process so it can't destabilise
Clarion) as an **owned overlay** over your window or a control in it; being a top-level window keeps it fully
interactive (drag/wheel/keys). The control template's **Show in** dropdown picks External browser or
Embedded. Pure Clarion: no DLL, no COM, no package — file IO via the ASCII driver, launch via
`rundll32 …FileProtocolHandler`.

Add the control template **my3D - 3D Scene Viewer button** to any window and configure the whole scene from
the AppGen prompts (canvas, camera, background, grid/axes/fog, lights, and a **MULTI** list of meshes), or
drive the class directly:

```clarion
Scene  WebGL2Class                              ! one object = one 3D scene

  CODE
  Scene.SetCamera(7, 6, 11);  Scene.LookAt(0, 0.5, 0)
  Scene.SetDirLight(-1,-2,-1.3, 1,0.97,0.9, 1.1)
  Scene.AddPointLight(4,3,4, 1,0.4,0.2, 1.2, 18) ! a warm point light
  Scene.SetColor(0.20,0.55,0.95);  Scene.SetSpin(0,0.6,0)
  Scene.AddCube(1.4)                             ! a spinning blue cube
  Scene.SetColor(0.2,0.85,0.85);  Scene.SetMaterial(0.7,0.2)
  Scene.SetPos(Scene.AddTorusKnot(0.7,0.2,2,3), 3, 0.9, 0)
  Scene.Show()                                   ! writes .html and launches the browser
```

Two example programs live in [`examples/my3D/`](examples/my3D/): **`My3DModels`** — a gallery of **10
real-world objects modelled from primitives** (a car, an airplane, a rocket, a wind turbine, a robot, a
table &amp; chairs, a house, a building foundation, a skyscraper and a park of trees) — and **`My3DDemo`**, a
**proof-of-concept app with 20 fixture scenes** (spinning primitives, a 7×7 sphere grid, the Platonic
solids, a 120-cube random field, a material matrix, point-light and fog demos, a solar system whose planet
orbits are placed with the class's own `Vec3` maths, a Fibonacci sphere, a "mega" scene, and a
**Vec3/Mat4 self-test**). Both build with their shipped `.cwproj`. Copy `WebGL2Class.inc` + `WebGL2Class.clw` (**ANSI, CRLF**) to the redirection path, and
ship **`my3D.engine.js`** beside the compiled `.exe` (it is read at run time and inlined into each page).
Full programmer's documentation — a guided tour in [`docs/my3D-template.html`](docs/my3D-template.html), and
the **exhaustive per‑method/per‑property API reference with example code for each** in
[`docs/my3D-reference.html`](docs/my3D-reference.html).

### `templates/myYuru/` — yuruyurau animated flow-field art on a window
Live **generative "flow-field" animation** — the pure-trigonometry particle sketches of the artist
[@yuruyurau](https://twitter.com/yuruyurau) — playing on a Clarion **`IMAGE` control**, offline and with **no
dependencies**. Clarion has no per-pixel canvas, so one self-contained ANSI class, **`YuruClass`**, plots
~10,000 particles (30,000 for *Lattice*) **additively** into an in-memory **24-bit BMP** each frame — so
overlapping points glow the way the semi-transparent p5.js originals do — writes it to a temp file and
reloads the control (two temp files are alternated per object so the control never locks the frame being
written). A window **`TIMER`** drives the loop. Six presets ship: **Ribbon, Seashell, Nebula, Lattice,
Reeds** and **Plume**, each with its own natural time step; pick any **ink color** (a 10-swatch professional
palette, no purple), the background grey, the per-point **glow**, and a **speed** multiplier. Each animation
on a window is its **own local object**, so several can run at once.

**Optional GPU backend (`Flow.Backend = Yuru:Direct2D`).** The BMP-file round-trip was never the real
cost — computing 10–30k particles and plotting them additively through Clarion string indexing is. So the
Direct2D backend does two things: it builds the **whole frame in native C** (`yuru_native_frame`, the six
sketches ported 1:1, skipping the Clarion loop) and blits it **straight to a GPU-composited child window**
over the IMAGE control — no temp file, no reload. On the heaviest preset (Lattice, 30k particles) that's
**~7 → ~59 fps (8.5×)**; the lighter presets faster again. The C shim **`yurucanvas.c`** binds `d2d1.dll`
through hand-declared COM vtables and implements `sin/cos/sqrt/atan2` in pure C, so there is still **no
redistributable** (Direct2D ships with Windows 7+); it's compiled in automatically by a `PRAGMA` in the
class. If the target can't be created it silently falls back to the BMP path, so the default (`Yuru:BmpFile`)
stays pure Clarion. `SetBackend()` switches at runtime. The GPU host **follows the IMAGE control** — when the
window (and an anchored control) is resized, each frame re-reads the control's pixel rect and moves/resizes the
child host **and** its render target to match, so the art fills the grown control instead of staying boxed in
its original size.

**Easiest path: a control template** — drag **myYuru - Yuruyurau animation** onto a window and it drops the
IMAGE *and* wires the animation in one go, fully self-contained (it `INCLUDE`s the class itself, so no global
extension is needed). Three registrations: the **myYuruControl** control template (drag-on, self-contained)
plus the **myYuruGlobal** (include the class once) and **myYuru** (window) extensions, which wire the object
at `EVENT:OpenWindow`, repaint on a private per-instance `Redraw` event, step on `EVENT:Timer`, and generate
`Start:`/`Stop:`/`Restart:` routines you can `DO` from any embed — and both templates expose a
**Rendering → Backend** choice (BMP file or Direct2D GPU). Copy `YuruClass.inc`, `YuruClass.clw` and
`yurucanvas.c` (**ANSI, CRLF**) to the redirection path; the app needs the **DOS file driver**. A hand-coded,
ready-to-compile demo — [`examples/myYuru/YuruDemo.clw`](examples/myYuru/YuruDemo.clw) (build
`YuruDemo.cwproj`) — mirrors the web app at `c:\ai\yuruyurau\index.html`: a live canvas with preset / ink /
speed pickers, a **GPU (Direct2D)** toggle, and Start / Stop / Reset / Save buttons. The six presets, rendered
by the class itself:

![myYuru presets](docs/myYuru-presets.png)

### `templates/myCalc/` — a pop-up calculator beside any numeric field
Drag **myCalc - Calculator button** next to a numeric entry and point it at that entry. A small calculator
icon appears; pressing it opens a modal calculator already holding whatever the field contains, and **Accept
puts the answer back into the field**.

**Four calculators in one window**, chosen from a drop list: **Standard** (four functions, memory, percent),
**Scientific** (trig, logs, powers, roots, factorial, parentheses, DEG/RAD), **Programmer** (HEX / DEC / OCT /
BIN with the out-of-range digits greyed out, AND OR XOR NOT, Lsh/Rsh, MOD, 8/16/32-bit word size) and
**Accountant** — a real adding-machine tape where `+` and `-` post the entry to the roll and SUBT / TOTAL / GT
print the running figures, with TAX+ / TAX- keys at a configurable rate. A **paper roll** runs down the side:
the tape in accountant mode, the history of finished calculations in the others, copyable to the clipboard.

**It remembers where you left it.** Which calculator you were last on comes back the next time the *program*
runs, along with DEG/RAD, the number base, the word size, the decimals and the tax rate — each profile saved
under its own INI section. **And it speaks Spanish**: the **language setting on the global extension** is what every
calculator in the application follows — mode names, window labels and the word keys (Borr, SUBT, TG,
IVA+/IVA-, Aceptar, Cancelar) — with an optional per-button override. The language is deliberately *not*
remembered between runs: there is no language picker in the calculator, so it is the template's call, and
saving it would let an old value shadow whatever you set today. Digits, operators and the maths names read the same
either way.

The keypad is a 7×7 grid re-labelled per mode, driven through a single `Press(action, text)` entry point — so
the whole calculator can be exercised from code or from a test without opening a window, which is exactly how
its 24-case arithmetic suite runs. Three registrations: **myCalcButton** (the drag-on control template, MULTI),
**myCalcHere** (a code template for an existing button, menu item or hot key) and **myCalcGlobal** (the class
plus the application language). Copy `CalcClass.inc`, `CalcClass.clw` (**ANSI, CRLF**) and `calc16.ico` to the
redirection path — the icon is compiled into the exe's resources, so there is nothing extra to deploy. A
runnable demo is [`examples/myCalc/CalcDemo.clw`](examples/myCalc/CalcDemo.clw), and the full
programmer's documentation — **bilingual English/Spanish** — is
[`docs/myCalc-template.html`](docs/myCalc-template.html).

![The myCalc demo](docs/myCalc-demo.png)

![The scientific calculator, and the accountant tape in Spanish](docs/myCalc-scientific.png)

![Contable (cinta)](docs/myCalc-accountant-es.png)

### `templates/myCalendar/` — a pop-up date picker beside any date field
Drag **myCalendar - Calendar button** next to a date entry and point it at that entry. A small calendar icon
appears; pressing it opens a modal calendar already sitting on whatever the field holds, and **Accept puts the
date back into the field**.

**One button can fill in two fields.** Set *Pick* to *a from-and-to range* and the user **drags across the
days** — over as many months as are on screen — to sweep out a period; the first day goes into the FROM field
and the last into the TO field, sorted whichever way they dragged. The selection follows the mouse live, and
clicking one day then another marks the range too.

**How much is on screen is up to you and the user**: one month, two, three, six, or a **full year** — and two
and three can be stacked **across** (side by side) or **down** (one under the other), with six going 3×2 or
2×3 and a year 4×3 or 3×4. Both the view and the stacking are drop lists in the window itself, the window
resizes itself to fit, and **both choices come back the next time the program runs** (per profile, in the
app's own INI) along with the first day of the week, the week-number gutter and the today ring. Navigation is
`<<` year, `<` month, a month drop and a year spin, `>` month, `>>` year, plus **Today**. Options cover
**ISO-8601 week numbers**, Sunday or Monday first, today ringed in amber, **weekends blocked**, and earliest /
latest date allowed — blocked days are simply deaf to the mouse, so there is no error box to dismiss.

**And it speaks Spanish**: the **language setting on the global extension** is what every calendar in the
application follows — month names, day headings, the view and stacking lists, Today / Clear / Accept / Cancel
and the footer that counts the days — with an optional per-button override. Like myCalc, the language is
deliberately *not* remembered between runs, so changing the setting takes effect immediately.

The months are painted with native `BOX` / `LINE` / `SHOW` into an IMAGE (the two-argument
`SETTARGET(window, ?image)`, so 0,0 is the image's own top-left) with a transparent `REGION` + `IMM` over the
top to collect the mouse — which is what makes a whole year cheap enough to draw, and makes the hit test plain
arithmetic. `Layout()`, `Draw()` and `DateAt()` are public, so the same class will paint an always-visible
calendar into an IMAGE on a window of your own; the date maths (`AddMonths` with the short-month clamp,
`DaysInMonth`, ISO `WeekNumber`, `DayOfWeek`) stands alone as well. A 62-assertion headless suite covers all of
it. Three registrations: **myCalendarButton** (the drag-on control template, MULTI, single-date or from/to),
**myCalendarHere** (a code template for an existing button, menu item or hot key) and **myCalendarGlobal**
(the class plus the application-wide language, first day, view and stacking). Copy `MyCalendarClass.inc`,
`MyCalendarClass.clw` (**ANSI, CRLF**) and `cal16.ico` to the redirection path — the icon is compiled into the
exe's resources, so there is nothing extra to deploy. **The class is `MyCalendarClass`, not `CalendarClass`** —
ABC already ships a `CalendarClass` in `ABUTIL`, and the two link into the same program as
`Duplicate symbol: TYPE$CALENDARCLASS`. A runnable demo is
[`examples/myCalendar/CalendarDemo.clw`](examples/myCalendar/CalendarDemo.clw), and the full programmer's
documentation — **bilingual English/Spanish** — is
[`docs/myCalendar-template.html`](docs/myCalendar-template.html).

![The myCalendar demo](docs/myCalendar-demo.png)

![Three months across, and one month with a dragged range](docs/myCalendar-three-across.png)

![A full year on one canvas](docs/myCalendar-year.png)

### `templates/myExport/` — export any browse or list to seven file formats
Drag **myExport - Export button** onto a browse window and you get a wired-up **Export…** button. Pressing it
opens a modal dialog that asks for the **format**, the **folder and file name** (through the standard Windows
Save-As browser) and **which columns to send** — then writes **CSV**, **CSV UTF-8** (with the BOM Excel needs
before it trusts accents), **TSV**, **XML**, **JSON**, **HTML** or a real **Excel `.xlsx`** workbook.

**The column picker.** Every data column is listed with a tick box, so the user can leave columns out,
**rename** one for the file, or give it a **different picture** — with the list's own heading shown alongside
so nothing gets lost. A blank picture writes the **raw** value (handy for JSON and Excel, where an
unformatted number beats a formatted string), and renaming also renames the XML element and the JSON key.
**All / None / Defaults** act on the lot. The choices **survive between exports**: the generated code
re-`Init`s before each one, so the scan fingerprints the list's layout (column count, field numbers, widths)
and only rebuilds when that actually changes. One prompt (`AllowColumns`) hides the whole picker and shrinks
the dialog back to format + file name if you'd rather lock it down, and every button it offers is also a
public method — `ColumnUse`, `ColumnRename`, `ColumnPicture`, `SelectAll`, `ResetColumns` — so you can preset
the columns from code.

**It remembers how you left it.** With `Persist` on (the default), a successful export writes the format,
the folder, the three tick boxes and the entire column list — which are on, every rename, every picture
override — into an INI section, and the dialog restores them the next time the *program* runs, not just
the next time the window opens. The section is named from a **profile** (the procedure name by default),
so two browses never overwrite each other, and a short fingerprint of the list's layout guards the column
half: add or resize a column and the stale column settings are discarded rather than landing on the wrong
column, while the format and folder still come back. `LoadSettings` / `SaveSettings` / `ForgetSettings`
are public, so an unattended nightly export can restore a saved profile and run with no dialog at all.

**No external program is needed for the Excel format.** An `.xlsx` is a ZIP of XML parts, and `ExportClass`
writes both — the six OOXML parts *and* the ZIP container (local headers, CRC-32, central directory, EOCD) —
so there is no helper `.exe`, no Python, no COM automation, no Excel installation and nothing to redistribute.
The workbook is not a renamed CSV: **numeric columns become real numeric cells** (`<v>1234.56</v>`, so SUM,
sorting, filtering and charts work), with a **bold heading row**, a **frozen pane**, an **auto-filter** and the
**column widths carried over from the screen**. Validated end-to-end against `openpyxl`.

**You never describe your columns to it.** At click time it reads the LIST control's own `FORMAT` —
`PROPLIST:Exists` / `FieldNo` / `Header` / `Picture` — and pulls values with `WHAT(Queue,FieldNo)`, the same
recipe the shipped `brwext.clw` uses. So the file matches the screen exactly, including columns the *user*
re-ordered, resized or hid after the window opened. The **queue is discovered at generate time** from the
LIST's own `FROM()` attribute (`EXTRACT(%ControlStatement,'FROM',1)` — what the shipped BrowseBox does), so
there is nothing to type. By default it walks the **whole browse view** (`BRW1.Reset()` → `Next()` →
`SetQueueRecord()`), honouring the current sort order, range limits and filters — not just the page of rows
the ABC queue happens to hold; a queue-only mode is one prompt away for hand-coded lists.

Three registrations: **myExportButton** (the drag-on control template, `MULTI`, self-contained),
**myExportHere** (a code template for an existing button, menu item or toolbar entry) and **myExportGlobal**
(optional — only if you want the class in procedures with no button). Copy `ExportClass.inc` and
`ExportClass.clw` (**ANSI, CRLF**) to the redirection path. `.xlsx` parts are **stored** by default so the
class has zero dependencies; if you also have **myCompress**, setting `_ExportDeflate_` to 1 in
`ExportClass.inc` switches them to real DEFLATE and shrinks a big workbook by roughly 10×. A runnable demo —
[`examples/myExport/ExportDemo.clw`](examples/myExport/ExportDemo.clw) — is a plain list with one Export
button plus a "write all seven" self-test. Full programmer's documentation:
[`docs/myExport-template.html`](docs/myExport-template.html).

![The myExport dialog, with two columns left out, one renamed and one re-pictured](docs/myExport-dialog.png)

## Install

Copy the two folders into your Claude Code config (`~/.claude` on macOS/Linux,
`C:\Users\<you>\.claude` on Windows):

```sh
cp -r skills/clarion-template ~/.claude/skills/
cp agents/clarion-template-pro.md ~/.claude/agents/
```

Restart Claude Code (or start a new session) so the skill and agent are picked up.

## Visual designer & installer

`designer/ClarionTplDesigner/` is a **.NET 9 / WPF** visual designer for a template's *prompt UI*:
open a `.tpl`, see each `#TAB`'s controls at their real `AT()` positions (icons render as the actual
PNGs), then **drag, resize, snap to a grid/guides, re-order, add, delete, and group** controls — and save,
rewriting only the `AT()` values (plus dropping deleted lines and relocating reparented ones). An *Add:*
command bar inserts new Label/String/Number/Spin/Check/Image/Group controls — and a whole new `#TAB`;
in the flow preview you can **drag a tab's header onto another to reorder the tabs** (a caret shows where it
will land), and the whole `#TAB`…`#ENDTAB` block moves with it;
dropping a control into a group box makes it a child (and moving the box carries its contents); guides pull from the rulers and are
removed by dragging them back onto a ruler; deleting a control whose `%symbol` is still referenced
elsewhere pops a warning so you don't break code generation. Selecting a control surfaces its **`%symbol`**
in the Properties pad with a navigable **Uses** list (every place across all files the symbol appears — click
to jump to that line) and a **Rename** button that renames it *everywhere at once* (prompt **+** every
reference) so the field stays joined; newly added controls can be named the same way. Select several
controls and **align / distribute / size them together** (Arrange menu or right-click), or **group them
into a box** (`Ctrl+G`) / **ungroup** (`Ctrl+Shift+G`). Dragging shows **smart alignment guides** that snap
to other controls' edges with a live spacing readout. An **Outline** panel shows the whole
`#SHEET`/`#TAB`/`#BOXED`/control tree with a find box; a **Symbols** panel lists every `%symbol` with its
use count and click-to-jump; a tab's **`WHERE(...)` visibility condition** is editable from its right-click
menu; a **Problems** panel flags
unbalanced blocks, duplicate/unused symbols, off-canvas or overlapping controls and risky auto-built
prompts (click to jump). Added `#PROMPT` controls get a friendly **type / REQ / DEFAULT** editor, and tabs
can be **renamed or deleted** (right-click a tab header). Controls can be **copied/cut/pasted/duplicated**
(`Ctrl+C/X/V/D`, with fresh `%symbols`), **snippets** drop in ready-made groups (Insert ▸ Snippets), and
**File ▸ Preview changes** shows a colour-coded per-file diff of exactly what a save will write. The source
panel has **find/replace** (`Ctrl+F`) and **`%symbol` / `#directive` autocomplete**. A fixed **icon command
bar** (Open, Recent, Save, Preview changes, Undo, Copy/Paste, Check problems, Find, Preview) sits under the
menu, and **recent templates** are remembered (toolbar dropdown and File ▸ Open Recent). The **Help** menu opens a built-in **User Manual**
(press `F1`) and **Programmer's Reference** — beautifully formatted HTML guides bundled into the app
(sources in `docs/`). See `designer/ClarionTplDesigner/README.md`.

**Clarion-accurate prompt fidelity (v2.8).** The canvas now renders prompt text in Clarion's actual
**AppGen Dialogs font**, auto-detected from `ClarionProperties.xml` (Options ▸ IDE ▸ Fonts), and sizes it
to the zoom so what you lay out matches what AppGen draws. A `#PROMPT`'s **label (`PROMPTAT`) and entry
(`AT`) are modelled separately** — drag the entry and the label follows, or drag the label on its own — and
**visibility guides** highlight (in red/amber) any control off the window, spilling outside its group box, or
whose label is too wide for the gap to its entry. **`#BOXED` children auto-get `SECTION`** so box-relative
coordinates land where the designer shows them, and **True layout** mirrors the canvas exactly. The Style
controls cover what AppGen honours per control — **bold / italic / underline / colour** (written as the
correct `PROP:FontStyle` flags + `PROP:FontName`/`PROP:FontColor`) — while the IDE dialog font is shown
**read-only** (Clarion governs the prompt-sheet face). Switching between open documents restores each one's
part **and** tab.

**Reusable prompt groups & UX (v2.9).** A `#SHEET` that pulls in shared prompts with **`#INSERT(%group)`**
now **resolves the `#GROUP(%group)`** (even when it lives in another `#INCLUDE`d file) and lays its prompts
out inline, so you see the complete sheet. Inlined controls are **read-only** (never written back — they
belong to the group's source) and **click-to-navigate** to the host `#INSERT` line. The **template/document
tabs sit above the toolbars** for a cleaner top strip, and **opening a template refreshes** the canvas
immediately.

**Auto-flow accuracy (v2.11).** When controls have no explicit `AT`, the canvas now lays them out the way
AppGen will: a side-label prompt **reserves its label column** (so the label no longer underflows off the
left into the margin), and an `#IMAGE` **reserves its real footprint** (its intrinsic pixel size, scaled to
fit) so following controls flow *below* it instead of being drawn underneath.

**Offline QR codes, on windows *and* reports (v2.12).** New [`templates/myQRDraw/`](templates/myQRDraw/)
draws a QR code with `BOX` primitives — **no internet, no `curl`, no temp files** — from a complete,
self-contained Clarion **encoder** (byte mode, versions 1–10, ECC L/M/Q/H) ported line-for-line from the
ZXing-validated [`designer/QrCodeCore/`](designer/QrCodeCore/) and pinned by a golden-matrix test. It ships
**two extensions**: `myQRDraw` for **windows** (redraw on open/resize) and `myQRDrawReport` for **reports**
(drawn per record in the *Before-Print-Detail* embed via `SETTARGET(Report)` — reports have no window event
loop, and the report control picker lists the report's own controls). The `clarion-template` skill gained
the hard-won lessons behind it (Clarion integer-rounding, `%`-free modulus, window-vs-report drawing).

**myQRDraw as a class + a beta test plan (v2.13).** The encoder moved into a self-contained Clarion **class**,
`QRCodeClass.inc`/`.clw` (stored in **ANSI**), so it compiles in its own module instead of filling the
program's global procedure area — the template just `INCLUDE`s it and declares one `QRCodeObj` instance,
made **multi-DLL aware** (defined in the root DLL, `EXTERNAL` elsewhere, exported — ABC's `%DefaultExternal`
pattern). The class carries a module-level `MAP` (required, else `BUILTINS.CLW` calls like `LEN`/`BOX`/
`SETTARGET` fail), `Construct`/`Destruct`, and `CLIP`s the value so a space-padded fixed-length field no
longer inflates into a giant dense symbol. The `clarion-template` skill captured the whole self-contained-CLASS
recipe. Also new: a multi-sheet **beta test plan** at
[`testing/Clarion-Template-Maker-Beta-Test-Plan.xlsx`](testing/Clarion-Template-Maker-Beta-Test-Plan.xlsx)
(53 test cases + roster + bug log) for handing the toolkit to testers.

**myBarcodeGen — nine barcode symbologies (v2.14).** A new offline barcode template covering the **1D** codes
**Code 39, Code 128** (auto B/C), **Interleaved 2 of 5, EAN-13, UPC-A** and the **2D** codes **QR, Data Matrix,
PDF417, Aztec** — all encoded at run time and drawn with `BOX`es (no internet/curl), on **windows and reports**,
chosen from one drop-list. Five self-contained ANSI Clarion classes (`BarcodeClass`, `QRCodeClass`,
`DataMatrixClass`, `Pdf417Class`, `AztecClass`) port a ZXing-validated C# reference,
[`designer/BarcodeCore/`](designer/BarcodeCore/) with **42 round-trip tests**. Reed–Solomon spans four fields
(GF(256) 0x11D/0x12D, the prime field GF(929), and GF(2ⁿ) for Aztec); PDF417's 3×929 pattern table is packed
into the class. Full developer's manual in
[`docs/myBarcodeGen-template.html`](docs/myBarcodeGen-template.html).

**myGauge — analog gauges on windows and reports (v2.15).** A new [`templates/myGauge/`](templates/myGauge/) draws a
configurable **speedometer-style dial** entirely with native Clarion graphics (`ARC`/`ELLIPSE`/`LINE`/
`POLYGON`/`SHOW`) into an `IMAGE` control — same offline, no-dependency approach as myPie/myQRDraw, but pure
drawing (no encoder, so no C# oracle needed). One self-contained ANSI class, **`GaugeClass`** (`.inc`/`.clw`),
holds the configuration and renders itself; each gauge is a **local object**, so multiple dials per window/report
just work. Arc **styles** 45°/90°/180°/270°/360° or **custom** start + signed sweep; min/max **range** driven by
a literal or any **field**; major/minor **ticks** + labels, a **value readout**, **title/units**, a triangle or
line **needle**, full **color** control, up to 16 colored **zones**, and **smooth animation** via the window
timer (`AnimateTo` + `AnimStep`). Three extensions — **myGaugeGlobal** (include once), **myGauge** for windows
(redraw on open/resize, optional animation, a generated `Refresh:<Object>` routine) and **myGaugeReport** for
reports (per record at `%BeforePrint` under `SETTARGET(Report)`). The geometry keeps angles un-normalized to
avoid the 0/360 wrap and maps screen-Y downward (`cy − r·sin θ`). Two compile fixes shipped after first
field use: the internal `Band` helper was renamed **`ArcBand`** (`BAND` is the Clarion report-band reserved
word), and the window event handler moved to **`PRIORITY(2000)`** so its self-contained `CASE EVENT()` sits
above ABC's own `TakeWindowEvent` scaffolding (2500) instead of duplicating it — a lesson now baked into the
`clarion-template` skill. Full programmer's manual in [`docs/myGauge-template.html`](docs/myGauge-template.html).

**myGauge gains a drag-on control template (v2.16).** Beyond the three extensions, myGauge now ships a **control
template** — **myGauge - Analog Gauge** — so you can drag a ready-made gauge straight onto a window from the
Window Designer's control toolbox: it drops the `IMAGE` *and* wires the gauge in one go. It's **fully
self-contained** — it emits `INCLUDE('GaugeClass.INC'),ONCE` at `%CustomGlobalDeclarations` (the per-module
compile-global embed, corpus `ABDROPS.TPW:65`), declares its own object, and draws on open/resize — so no
separate global extension is required, and `ONCE` keeps the class single-included even if you add one anyway.
The control's own field equate is captured with the proven `#FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance)`
idiom (corpus `CONTROL.TPW` *CloseButton*), so it tracks AppGen's auto-uniqued feq when several are dropped on
one window.

**myGauge rock-solid resize & multi-gauge redraw (v2.16).** The gauge now draws **into the IMAGE
control itself** rather than onto the window layer: `Draw(window, ?image)` uses the **two-argument
`SETTARGET(window, ?image)`**, so the graphics *belong to the image* and survive a `WM_PAINT`/resize
(a bare window-layer draw was getting wiped). With the image as the target, the origin is `0,0` and a
scoped **`BLANK`** clears **only that gauge's image** — so multiple dials on one window no longer erase
each other, and a gauge whose IMAGE sits away from the window's left edge is no longer clipped. Redraw is
driven by a **private per-instance `Redraw:<Object>` event** posted on `EVENT:OpenWindow` and after
`EVENT:Sized` (the resizer has settled, so the fresh size is read), and **`AnimStep` no longer self-draws**
— it just eases the needle one step and returns *moved*, leaving the caller (which holds the window handle)
to repaint. The `GaugeClass` `Draw` prototype is now `Draw(WINDOW pWin, SIGNED pImageFeq)`; **regenerate
any app** built against the older one-argument `Draw`.

**myCompress — a pure-Clarion compression library (v2.17).** A new [`templates/myCompress/`](templates/myCompress/)
adds DEFLATE / zlib / gzip **compression** to Clarion in pure Clarion — no DLL. One global object
(`CompressClass`) compresses and decompresses **memory buffers and files** in formats that interoperate
with gzip / 7-Zip / .NET; INFLATE is complete (stored + fixed + dynamic Huffman) and DEFLATE is LZ77 +
fixed Huffman, with CRC32/Adler32 checksums and a `SelfTest()`. Verified end-to-end against the real
Clarion compiler and a .NET golden-vector oracle ([`designer/CompressCore/`](designer/CompressCore/)) —
a string round-trips and the self-test passes. Three hard-won Clarion lessons came out of it and are now
baked into the `clarion-template` skill/notes: **a single array can't exceed 64 KB**, **class source must
be stored CRLF** (LF-only includes mis-compile as "Illegal data type"), and a **global object must not be
named after a file field** (e.g. `Zip`) or it collides. A `.gitattributes` rule now keeps all Clarion
source (`.tpl`/`.tpw`/`.inc`/`.clw`) CRLF.

**myPdfSign — read a signed PDF and see who signed it (v2.18).** A new [`templates/myPdfSign/`](templates/myPdfSign/)
adds a pure-Clarion **signed-PDF identity reader** — no DLL, no network. One global object (`PdfSignClass`,
default `PdfSig`) opens a digitally-signed PDF and reads the **authoritative signer identity** out of the
embedded **PKCS#7 / CMS** signature: the certificate Subject (`SubjectCN`/`SubjectO`/`SubjectOU`/
`SubjectEmail`), the issuing CA (`IssuerCN`), the `signingTime` (ISO-8601 UTC, from the signed attributes),
the dictionary's `/Name`/`/Reason`/`/Location`/`/SubFilter`, and **`CoversWholeFile`** (0 = bytes appended
after signing). It finds the `/ByteRange` + `/Contents <hex>` dictionary, hex-decodes the DER, and a small
**ASN.1 reader** walks to the signer cert's RDNs by OID — **identity + integrity only**, no RSA/ECDSA verify
or trust-chain validation. Verified against the real Clarion compiler and a .NET golden-fixture oracle
([`designer/PdfSignCore/`](designer/PdfSignCore/)) that **manufactures real signed PDFs** and publishes the
expected identity; the Clarion `Report()` matches **byte-for-byte across all three fixtures**, including a
tampered one that correctly reports `CoversWholeFile=0`. Programmer's manual in
[`docs/myPdfSign-template.html`](docs/myPdfSign-template.html).

**myCompress gains an optional C fast-path (~4× faster) (v2.19).** The compression template now ships an
optional **C engine**, [`templates/myCompress/mc.c`](templates/myCompress/mc.c) — our own clean-room DEFLATE
port (**not** miniz/zlib/StringTheory) compiled by **Clarion's own C compiler** (`Clacpp`) via
`PRAGMA('compile(mc.c)')`. Set `CmpUseC EQUATE(1)` and copy `mc.c`, and `CompressClass` routes through it:
a 4 MB buffer compresses in **~200 ms instead of ~844 ms** (and a touch smaller, since C has no Clarion
64 KB-array limit so it uses the full 32 KB window). It's the same algorithm, so both engines produce
byte-compatible output and interoperate freely. When `CmpUseC=0` (the default) every line of the C path is
`OMIT`ted — **no `mc.c` needed**, pure Clarion unaffected. Verified end-to-end against the real Clarion
compiler: the wired class round-trips, `SelfTest()` passes in both modes, and C inflate decodes .NET's
dynamic-Huffman gzip. Established a reusable lesson — **Clarion compiles bundled C** (`extern "C"` +
`PRAGMA('compile(x.c)')` + a `MODULE('x.c')` prototype block) — so future templates can drop to C for
hot paths without any external dependency.

**myCompress C fast-path becomes a template choice (v2.20).** The C engine switch moved from a hand-edited
equate into the **extension's prompt**. The C path is now a clean **subclass**, `CompressClassC` — it
overrides the (now `VIRTUAL`) `Wrap`/`Unwrap` to call `mc.c`, inherits the rest of the API unchanged, and is
selected by a *Compression engine: Pure Clarion / C (fast)* drop-list that simply declares the global object
as `CompressClass` or `CompressClassC`. So the choice lives in the template (no library edits), and a
pure-Clarion app pulls in **no `mc.c` and no subclass at all** — verified against the real Clarion compiler:
the C engine is 3.8× faster, both engines interoperate (compress with one, decompress with the other) and
pass `SelfTest()`, and a pure-Clarion build links clean with the C files entirely absent. The reusable
lesson — a **C fast-path as a `VIRTUAL`-override subclass** that the template selects — is captured for the
next template that wants one.

**myPie gains a drag-on control template + a drawing fix (v2.21).** myPie now ships a **control template**,
**myPie - Pie Chart**, so you can drag a ready-made chart straight onto a window from the control toolbox —
it drops the IMAGE *and* wires the pie + legend in one go, fully self-contained (no global/procedure
extension), with many per window. The drawing also moved to myGauge's **2-arg `SETTARGET(%Window,?image)`**
model: the IMAGE is the target (origin `0,0`), so the chart belongs to the control (survives a
repaint/resize) and a `BLANK` clears **only that image** instead of wiping the whole window — fixing
multiple pies (or other controls) erasing each other. The `myPieDraw` helper gained a leading `WINDOW`
parameter to match, so **regenerate** any app built against the old one. Validated against the real Clarion
compiler: the template registers cleanly (`ClarionCL -tr`) and the generated helper code compiles.

**myPie gains a live control-panel control template (v2.22).** A second pie control template, **myPie - Pie
Controls panel**, drops a ready-made panel of inputs — a 3D-depth **spinner**, show-legend / show-percentages
**checkboxes**, and up to six **slice-value spinners** — that drive a pie on the same window. Point it at the
pie by its **Name**; changing any input pushes the value into that pie's data and **POSTs its redraw**, so the
chart updates live. To make that possible, `myPieControl` now exposes depth / legend / percentages as
**run-time variables** (they were baked in at generation). The panel is `WINDOW` (one per window) so its
controls bind to fixed data labels, and it reads the pie's current values on open via a deferred sync event
(so it runs after the pie's `OpenWindow`). Validated against the real Clarion compiler: the template registers
(`ClarionCL -tr`) and the generated pie-draw + panel↔pie wiring compiles. Captures the reusable pattern —
**one control template that live-drives another via its Name + a private redraw event**.

**myPie panel ↔ pie link made robust + two bug fixes (v2.23).** The first cut of the live panel linked to a
pie by a typed **Name** — fragile (the pie auto-named itself `Pie7` while the panel defaulted to `Pie1`, so
they didn't connect) and it didn't compile. Reworked: the pie now **keys its data off its Image control's
field-equate** (no name prompt), and the panel links by **picking that Image** from a drop-list — both derive
the *same* data prefix from the *same* control (`SUB`/`INSTRING` strip the `?`/`:`), so they always match.
Two real Clarion bugs fixed in the process: the panel's input controls now declare their USE variables at
**`%DataSectionBeforeWindow`** (window controls can't forward-reference data declared after the window → it
was "Unknown identifier"), and the handler moved from `PRIORITY(2500)` to **`PRIORITY(2000)`** (2500 collides
with ABC's `TakeWindowEvent` scaffolding, mangling the generated `CASE`). Validated against the real Clarion
compiler: the template registers (`ClarionCL -tr`) and the reworked generated code compiles.

**my3D — drive real WebGL2 3D scenes from Clarion (v2.26).** A new template set: `WebGL2Class` (pure
Clarion) exposes a rich OOP 3D API — camera, ambient + directional + 8 point lights, materials, **20+ mesh
primitives**, per-mesh transforms, fog, grid, axes, and genuine `Vec3`/`Mat4` maths that run in Clarion —
and emits a **single self-contained `.html`** (scene data + the inlined `my3D.engine.js` WebGL2 renderer)
shown in the browser. A control template wires a whole scene from AppGen prompts. Verified end-to-end
against the real Clarion 12 compiler and headless-rendered to confirm it actually draws. See
[`docs/my3D-template.html`](docs/my3D-template.html).

**my3D — composite "special meshes" + WebGL2 *inside* a Clarion window (v2.27).** Ten real-world models
(car, airplane, rocket, wind turbine, robot, table, house, building foundation, skyscraper, trees) are now
one-call class methods — `AddCar(x,y,z,scale)` etc. — and appear in the template's Shape dropdown alongside
the primitives. And the scene can render **embedded in a Clarion window**: `ShowEmbedded()` docks a
borderless Edge `--app` window (real WebGL2, 120 fps) into the host with the Win32 `SetParent`. Edge runs in
its **own process**, which sidesteps the `ClaRUN` reentrancy crash an in-process WebView2 control causes — so
it needs **no DLL and no import lib**, only `user32`. The control template's **Show in** dropdown picks
External browser or Embedded; Edge's title bar is tucked out of view. Examples: a 20-fixture demo (with a
browser/embed toggle), a 10-model gallery, and a dedicated embedded viewer in [`examples/my3D/`](examples/my3D/).

**my3D — dock the WebGL2 view into a control, not just the whole window (v2.28).** `SetEmbedControl(?View)`
confines the docked Edge view to an **IMAGE/REGION** control's rectangle, so the rest of the window holds
ordinary Clarion buttons, lists, etc. The control is a layout placeholder with no HWND of its own, so the
class reads its **pixel rect** (`PROP:Pixels` + `PROP:Xpos/Ypos/Width/Height`) and hosts the view in a small
`WS_CLIPCHILDREN` child window at that rect — which also clips Edge's title bar even when the control isn't at
the top of the window, and re-fits as the control resizes. The control template's embedded option gains a
**Dock into this control** prompt; example [`examples/my3D/My3DInControl.clw`](examples/my3D/My3DInControl.clw)
renders the 3D in an IMAGE control with buttons beside it.

**my3D — interactive frameless overlay + HUD/FPS view options (v2.29).** The embedded view changed from a
*re-parented child* to an **owned overlay**: a re-parented cross-process Edge window can't receive input
(Chromium isn't built to be a foreign-process child), so the embed now keeps Edge a **top-level window**, set
as the Clarion window's **owner** (`GWL_HWNDPARENT`) and positioned over the host/control in screen
coordinates — which preserves **full native mouse + keyboard** (drag-orbit, wheel, R/space). It is stripped
to a **frameless, non-resizable** `WS_POPUP` sized to exactly the target, with `SetWindowRgn` clipping Edge's
title bar; call `EmbedFit()` on **EVENT:Sized and EVENT:Moved** so it tracks the window. New **view options**
`SetHud(on)`/`SetFps(on)` (and **Show info overlay** / **Show FPS** template checkboxes) toggle the on-screen
info box and the fps counter. Note: `my3D.engine.js` is read at run time — ship the matching version beside
the `.exe`.

**my3D — complete API reference (v2.29.1).** Added [`docs/my3D-reference.html`](docs/my3D-reference.html): an
exhaustive per-method/per-property reference for `WebGL2Class` — all 108 methods, each with **example code**,
grouped (lifecycle, page/canvas/view, background/fog, camera, lighting, chrome, material, meshes, composite
models, transforms, Vec3/Mat4, output, embedded display, internal), plus a constants table, a full properties
table with defaults, and recipes. The existing [`docs/my3D-template.html`](docs/my3D-template.html) remains
the guided tour and links to it.

**my3D — reliable cleanup of the embedded Edge view (v2.30.2).** The docked WebGL2 view is a separate
`msedge.exe` process tree; closing it with only `PostMessage(WM_CLOSE)` could leave **orphaned `msedge.exe`
processes** behind (Edge defers/ignores the message during shutdown, and it never reached the GPU/renderer/
network/crashpad child processes). `EmbedClose` now captures the Edge **browser PID** at embed time
(`GetWindowThreadProcessId`), still asks it to close gracefully first, then **guarantees** teardown of the
whole tree via a hidden `taskkill /F /T /PID` (launched with `CREATE_NO_WINDOW`, no console flash). A new
**`Destruct`** calls `EmbedClose` as a safety net, so the view is reaped even when the host forgets the
`EVENT:CloseWindow` handler or the app exits abnormally. Verified end-to-end: 7 Edge processes spawned, all
reaped within ~0.5 s of closing the window, zero leftovers.

**myQRDraw — clipped window Draw + a test program (v2.30.3, PR #19).** The window `QRCodeClass.Draw` now uses
the **two-argument `SETTARGET(Window, ?Image)`** (like myGauge) so the `BLANK` is **clipped to the image
rectangle** instead of the whole window — **multiple QR codes on one window no longer blank each other**, and
an image sitting away from the window's left edge is no longer clipped. With a real window target the paint
runs from a `0,0` origin, so `Paint` gained a `ZeroXY` flag, and `Draw` gained a `STRING` overload (it used to
take only `CSTRING`). A hand-driven test app, [`templates/myQRDraw/TestQRWnd_Renz.clw`](templates/myQRDraw/TestQRWnd_Renz.clw),
exercises every setting live with **two QR codes on one window** (proving one doesn't erase the other) and a
checkerboard for min/max module sizing. Thanks to **Carl T. Barnes** for the fix and test program.

**myQRDraw & myBarcodeGen — `STRING` parameters, failure-aware `Draw`, overridable methods (v2.30.4, PRs #20 & #21).**
The class method parameters moved from `(*CSTRING)` to standard Clarion `(STRING)` (PR #20 for `QRCodeClass`,
PR #21 for `BarcodeClass`/`AztecClass`/`DataMatrixClass`/`Pdf417Class`) — more idiomatic for Clarion developers
and non-breaking, since the RTL still converts a passed `CSTRING` to `STRING`. Every `Draw` now returns a
**`BOOL`** — `False` when it can't paint (typically an invalid value for the type, e.g. a non-numeric UPC-A), so
the caller can surface the error — and many methods became **`VIRTUAL`** so the classes can be derived and
overridden. `EanCheckDigit`/`UpcCheckDigit` now bound their loop to the passed string's `SIZE()` to avoid an
invalid `[slice]`. Both sets of changes were verified to compile clean against Clarion 12. Thanks again to
**Carl T. Barnes**.

**myYuru — Direct2D backend now follows window resizes (v2.30.5).** The GPU direct-to-window host was sized
**once**, lazily, on the first Direct2D frame and then frozen: when the window (and an anchored `IMAGE`
control) grew, the child host window and its render target kept their original size, so the animation stayed
boxed in the old rectangle. The class now re-reads the control's pixel rect each Direct2D frame and, only when
it actually changed, moves/resizes the child host (`yuru_d2d_move_child`) **and** resizes the GPU back buffer
(new `yuru_d2d_resize` → `ID2D1HwndRenderTarget::Resize`, bound at vtable index 58 and called outside the
`BeginDraw`/`EndDraw` pair). The template also repaints on `EVENT:Sized` so a paused animation re-syncs at
once. The BMP-file backend was never affected (the `IMAGE` control scales itself).

To package everything (designer **+** templates **+** skill **+** agent) into one deliverable — .NET is
bundled in, so nothing needs pre-installing on the target:

```powershell
pwsh installer\build-installer.ps1   # -> installer\Output\ClarionTemplateToolsSetup.exe (full installer)
pwsh installer\build-portable.ps1    # -> run\ClarionTemplateDesigner.exe (portable single-file exe)
```

See `installer/README.md` for what each option installs.

### QR encoder core (`designer/QrCodeCore/`)

`designer/QrCodeCore/` is a small, dependency-free **.NET 9** QR-code encoder (versions 1–10, all four
error-correction levels) written as the portable reference for the *offline* [`templates/myQRDraw/`](templates/myQRDraw/)
template, which draws the symbol module-by-module with `BOX` primitives — the same approach as `myPie/` — so no
internet round-trip is needed (unlike `templates/myQR/`, which fetches a PNG via `curl`). The encoder is developed test-first:
`designer/QrCodeCore.Tests/` round-trips every encode through an independent decoder (ZXing.Net) across all
versions and ECC levels and pins the Reed–Solomon stage to the ISO/IEC 18004 worked example. Run the tests
with `dotnet test designer/QrCodeCore.Tests`.

## How to use

- Ask Claude to build/edit a Clarion template and it will pick up the `clarion-template` skill
  automatically (or invoke `/clarion-template`).
- For a focused deep task, delegate to the `clarion-template-pro` agent.

## Verifying a generated template

Claude cannot run AppGen. After it writes a template:
1. Copy the `.tpl` (+ `.tpw`/`.inc`/`.clw`) into the app's template/source path.
2. IDE → **Setup ▸ Template Registry ▸ Register** the `.tpl`.
3. Add the extension/control to a test procedure (or the app, for `APPLICATION` scope).
4. Fill prompts, **Generate**, and confirm the produced `.clw` compiles.

## Beta testing

A ready-to-use **beta test plan** for the whole toolkit lives in
[`testing/Clarion-Template-Maker-Beta-Test-Plan.xlsx`](testing/Clarion-Template-Maker-Beta-Test-Plan.xlsx) —
a multi-sheet workbook (Read Me, Beta Testers roster, 53 **Test Cases** with Pass/Fail/Severity drop-downs and
colour coding, a Bug Log, and an auto-tallying Summary) covering install, the visual designer, every shipped
template, and the QR self-tests. Hand it to testers as their script. Regenerate or extend it with
`python testing/build_beta_test_plan.py` (requires `openpyxl`).

## License

Released under the [MIT License](LICENSE) — © 2026 Reddin Assessments. Free to use, modify, and
distribute; provided "as is" without warranty.
