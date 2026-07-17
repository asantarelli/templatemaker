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

## Programs

| File | What it is |
| --- | --- |
| `YuruDemo.clw` / `.cwproj` | The interactive demo — a live canvas with **Preset / Ink / Speed** pickers and **Start / Stop / Reset / Save BMP** buttons. Build & run this. |
| `YuruShots.clw` / `.cwproj` | A headless render — paints one still frame of every preset to `shot_*.bmp` (used to make the montage above). Also a smoke-test of the class. |
| `YuruClass.inc` / `YuruClass.clw` | Copies of the class (kept beside the demos so they compile standalone). The master copies live in [`../../templates/myYuru/`](../../templates/myYuru/). |

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
