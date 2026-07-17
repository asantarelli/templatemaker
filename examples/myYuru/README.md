# myYuru — demo &amp; renderer

Hand-coded, ready-to-compile Clarion programs for **`YuruClass`**, the "yuruyurau" animated
flow-field renderer used by the [`myYuru`](../../templates/myYuru/) template set. They mirror the
web app at `c:\ai\yuruyurau\index.html` — the same six presets, rendered natively onto a Clarion
`IMAGE` control with no dependencies.

![the six presets](../../docs/myYuru-presets.png)

## What renders how

Clarion has no per-pixel drawing surface, so each frame `YuruClass`:

1. computes the formula for every particle (10,000 — 30,000 for *Lattice*),
2. plots each point **additively** into an in-memory 24-bit BMP byte buffer, so overlapping points
   brighten (mimics the semi-transparent `stroke()` glow of the p5.js originals),
3. writes the buffer to a temp `.bmp` (raw `DRIVER('DOS')` file: 54-byte header + 480,000 BGR bytes),
4. loads it into the control with `feq{PROP:Text} = filename; DISPLAY(feq)`.

Two temp files (`yuru<feq>a.bmp` / `yuru<feq>b.bmp`) are alternated so the IMAGE control never holds a
lock on the file the next frame is being written to. The internal bitmap is a fixed **400×400**; the
IMAGE control scales it to whatever display size you give the control.

## GPU direct-to-window (Direct2D)

That file round-trip — write `.bmp`, reload the IMAGE — dominates the frame time. Set
**`Flow.Backend = Yuru:Direct2D`** (or tick **GPU (Direct2D)** in the demo) and steps 3–4 disappear:
`YuruClass` hosts a bare child window over the IMAGE control, owns a **GPU-accelerated Direct2D render
target** on it, and each frame's pixel buffer is uploaded as a bitmap and blitted **straight to the
screen** (`DrawBitmap` + `Present`) — no temp file, no `PROP:Text` reload. This is the same
"direct-to-window, no PNG" path added to CapeSoft Draw / DrawPlus, ported to myYuru's per-pixel model:
the GPU does the scale + present, the particle math stays in Clarion.

**The compute is native too.** The real cost per frame was never the file write — it was computing
10–30k particles (trig) and plotting them additively through Clarion string indexing
(`VAL(Pixels[ofs])`/`CHR()`). So on the Direct2D backend the **whole frame is built in native C**
(`yuru_native_frame`, the six sketches ported 1:1) directly into a 32-bit buffer, and the Clarion
particle loop is skipped entirely. Measured on the heaviest preset (`YuruBench`, Lattice = 30,000
particles, 100-frame average):

| | ms / frame | ~fps |
| --- | --- | --- |
| Clarion particle loop | **143.8** | ~7 |
| Native C engine | **16.9** | ~59 |
| **speedup** | **8.5×** | |

That ~7 fps is why the naive GPU path still felt slow — it was doing the *same* Clarion loop and then
blitting. The lighter 10k-particle presets run several times faster again. Correctness is verified:
`YuruNativeShots` renders every preset natively and it matches the Clarion golden `shot_*.bmp` to within
single-pixel jitter (2–9 % of pixels differ by ±a few levels — two independent trig implementations).

- The C shim is **`yurucanvas.c`** (`yuru_d2d_*` / `yuru_native_*` symbols — coexists with any other
  D2D/GDI+ shim in the app). It binds `d2d1.dll` at runtime and calls Direct2D through hand-declared COM
  vtables, and implements `sin/cos/sqrt/atan2` in **pure C** (the Clarion C runtime links no libm), so
  there is **no redistributable** (Direct2D ships with Windows 7+). Compiled in automatically by a
  `PRAGMA('compile(yurucanvas.c)')` in `YuruClass.clw` — just keep the file on the redirection path.
- If the target can't be created (very old Windows), it **silently falls back** to the BMP-file path.
- `SetBackend()` switches at runtime (the demo's checkbox); going back to BMP tears down the host.

> **Background fix:** the BMP path's `Pixels = ALL(CHR(BackGray))` only filled the first 255 bytes —
> Clarion space-padded the rest, so the background was silently **32**, not `BackGray`. `ClearBuf()` now
> fills the whole buffer, so both backends honour `BackGray` (default 9, near-black). Existing apps get a
> slightly darker, cleaner background.

## Programs

| File | What it is |
| --- | --- |
| `YuruDemo.clw` / `.cwproj` | The interactive demo — a live canvas with **Preset / Ink / Speed** pickers, a **GPU (Direct2D)** toggle, and **Start / Stop / Reset / Save BMP** buttons. Build & run this. |
| `YuruShots.clw` / `.cwproj` | A headless render — paints one still frame of every preset to `shot_*.bmp` (used to make the montage above). Also a smoke-test of the class. |
| `YuruNativeShots.clw` / `.cwproj` | Headless verification of the native C engine — renders every preset via `yuru_native_frame` to `native_*.bmp` for byte-comparison against the Clarion `shot_*.bmp`. |
| `YuruBench.clw` / `.cwproj` | Headless timing — Clarion particle loop vs the native C engine (writes `bench.ini`). |
| `YuruClass.inc` / `YuruClass.clw` / `yurucanvas.c` | Copies of the class + the Direct2D shim (kept beside the demos so they compile standalone). The master copies live in [`../../templates/myYuru/`](../../templates/myYuru/). |

## Build

Both projects target a **32-bit Clarion 11/12 EXE** and need the **DOS file driver** (already declared in
each `.cwproj` as `<FileDriver Include="DOS" />`). From a Clarion command prompt, or via MSBuild:

```
MSBuild YuruDemo.cwproj -t:Build -p:Configuration=Debug -p:Platform=Win32 -p:ClarionBinPath="C:\clarion12\bin"
```

Run `YuruDemo.exe`, pick a preset, and it animates. The class source must be stored **ANSI/CRLF**.

## The class API

```clarion
Flow   YuruClass                       ! one object = one animation

  CODE
  Flow.Init(?Canvas)                    ! remember the IMAGE control (call once)
  Flow.Backend  = Yuru:Direct2D         ! optional: GPU direct-to-window (else Yuru:BmpFile, the default)
  Flow.Preset   = Yuru:Ribbon           ! Ribbon/Seashell/Nebula/Lattice/Reeds/Plume
  Flow.InkColor = 006E760FH             ! any Clarion 00BBGGRR color (teal here)
  Flow.Speed    = 1.5                   ! time-step multiplier
  Flow.Brightness = 55                  ! glow added per plotted point
  Flow.BackGray = 9                     ! flat background grey (near-black looks best)
  Flow.Paint()                          ! draw the current frame now
  ! ...then on each window EVENT:Timer:
  Flow.NextFrame()                      ! advance the clock one step + repaint
  ! Flow.Restart()                      ! zero the clock
  ! Flow.SaveAs('out.bmp')              ! write the last-rendered frame to a file
```
