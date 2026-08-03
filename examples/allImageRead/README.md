# allImageRead — the verification harnesses

Three small programs. They are not demos of what the template *looks* like; they are how the
template was proved to be correct, and they can be re-run whenever it changes.

Everything here needs the myImage files on the redirection path — `ImageClass.inc`,
`ImageClass.clw` and `imgcore.c`. They already sit in `clarion12\accessory\libsrc\win`
if myImage was deployed; otherwise copy them from `templates/myImage/` (ANSI, CRLF).

`.exe`, `.lib`, `.dll` and `.obj` are gitignored, so rebuild before you run.

---

## `airwin` — the canvas on a window

A full ABC application carrying **both** window placements at once, so one build proves both:

| control | template | source |
|---|---|---|
| `?Pic1` | `allImageRead` procedure extension | a **base64** string in memory |
| `?AirCanvas` | `allImageReadCanvas` control template | a **URL** |

It also exercises the parts that are easy to get wrong: two canvases on one window (so the event
equates and the wheel hook must not collide), a per-canvas touch-up (the canvas rotates 90° and caps
its longest side at 2000px), the status bar in two different zones, and the full right-click menu.

Rebuild it from the TXA — the `.app` is not committed, because a TXA is text and diffable:

```
ClarionCL -win -au -ai airwin.app airwin.txa      # create the .app
ClarionCL -win -au -ag airwin.app                 # generate the source
MSBuild airwin.cwproj /p:ClarionBinPath=C:\clarion12\bin /p:Configuration=Debug
```

The generated source is committed too (`airwin.clw`, `AIRWIN001.CLW`, …) so a change in the template
shows up as a readable diff without anyone having to run AppGen.

## `rpttest` — the canvas in a report band

The band half of the same template, lifted out of a generated application: the global readers, the
`Air:Band` routine the template writes, a `REPORT` with an `IMAGE` in its `DETAIL`, and a `PRINT`.
It exists because a report procedure needs a primary table before ABC will generate cleanly, and
that would have dragged a dictionary into the harness for no gain. This compiles the *emitted* code
instead — which is the part worth proving.

```
MSBuild rpttest.cwproj /p:ClarionBinPath=C:\clarion12\bin /p:Configuration=Debug
```

## `wheeltest` — does the mouse wheel actually arrive?

The one that earned its keep. Clarion's `EVENT:ScrollUp` / `EVENT:ScrollDown` are **LIST events**
("the user pressed the up arrow", `IMM` only) — they never reach a window or an `IMAGE`, so a first
attempt at wheel zoom silently did nothing. The wheel has to be taken off the window procedure.

`wheeltest` opens a window, hooks `PROP:WndProc`, and turns `WM_MOUSEWHEEL` into four counters —
wheel up, wheel down, and the same two with Ctrl held — which it writes into the **window title**.
`drivewheel.ps1` starts it, sends real `WM_MOUSEWHEEL` messages with `SendMessage`, and reads the
title back, so the whole thing runs without a human touching a mouse:

```
MSBuild wheeltest.cwproj /p:ClarionBinPath=C:\clarion12\bin /p:Configuration=Debug
powershell -File drivewheel.ps1
```

Sending Ctrl+up ×2, Ctrl+down, plain up and plain down must print:

```
title now: AirWheelTest U=1 D=1 CU=2 CD=1
```

That is the proof behind three claims the template makes: a subclassed window procedure sees the
wheel, `POST` from inside that callback reaches the `ACCEPT` loop, and chaining on to the window's
own procedure leaves everything else working.
