! ============================================================================
!  GraficaBarraClass - implementation. Simple bar graph, pure Clarion, drawn
!  with BOX/LINE/SHOW so a report PDF stays vector (small). All coordinates
!  come from GETPOSITION of the target control, so the same Paint serves
!  windows (dialog units) and reports (thousandths of an inch) - only the
!  text cell metrics differ (see cw/ch below).
!  bare MEMBER + module MAP. Store this file in ANSI (not UTF-8), CRLF.
! ============================================================================
  MEMBER

  MAP
  END

  INCLUDE('GraficaBarraClass.INC'),ONCE

GraficaBarraClass.Construct PROCEDURE()
  CODE
  SELF.Title = ''
  SELF.ShowValues = 1; SELF.ValueDP = 0
  SELF.ShowLabels = 1
  SELF.ShowScale = 1;  SELF.ScaleDP = 0
  SELF.ShowGrid = 1;   SELF.GridDivs = 5
  SELF.ShowAxis = 1
  SELF.AutoScale = 1;  SELF.MinVal = 0; SELF.MaxVal = 0
  SELF.BarGapPct = 30
  SELF.TextW = 0; SELF.TextH = 0
  SELF.BackColor = COLOR:None
  SELF.PlotColor = COLOR:None
  SELF.AxisColor = 02B2B2Bh                                  ! near-black
  SELF.GridColor = 0E0E0E0h                                  ! light gray
  SELF.TextColor = 02B2B2Bh
  SELF.BarBorderColor = COLOR:None
  SELF.NBars = 0

GraficaBarraClass.ClearBars PROCEDURE()
  CODE
  SELF.NBars = 0

GraficaBarraClass.AddBar PROCEDURE(STRING pLabel,REAL pValue,LONG pColor=-1)
  CODE
  IF SELF.NBars >= GraficaBarra:MaxBars THEN RETURN.
  SELF.NBars += 1
  SELF.BarLabel[SELF.NBars] = pLabel
  SELF.BarValue[SELF.NBars] = pValue
  SELF.BarColor[SELF.NBars] = pColor

GraficaBarraClass.SetRange PROCEDURE(REAL pMin,REAL pMax)
  CODE
  SELF.MinVal = pMin; SELF.MaxVal = pMax
  SELF.AutoScale = 0

GraficaBarraClass.Demo PROCEDURE()
  CODE
  SELF.ClearBars()
  SELF.AddBar('Ene', 42)
  SELF.AddBar('Feb', 58)
  SELF.AddBar('Mar', 35)
  SELF.AddBar('Abr', 71)
  SELF.AddBar('May', 64)
  SELF.AddBar('Jun', 89)

!=== helpers ================================================================
GraficaBarraClass.NiceMax PROCEDURE(REAL v)
m  REAL
f  REAL
  CODE
  IF v <= 0 THEN RETURN 1.
  m = 10 ^ INT(LOG10(v))
  IF m > v THEN m = m / 10.                                  ! guard rounding on exact powers
  f = v / m
  IF f <= 1 THEN RETURN m.
  IF f <= 2 THEN RETURN 2 * m.
  IF f <= 5 THEN RETURN 5 * m.
  RETURN 10 * m

GraficaBarraClass.Palette PROCEDURE(LONG i)
k  LONG
  CODE
  k = i - INT((i - 1) / 8) * 8                               ! cycle 1..8, no modulus operator
  CASE k
  OF 1; RETURN 0B6752Eh                                      ! steel blue
  OF 2; RETURN 0A4A62Ch                                      ! teal
  OF 3; RETURN 03DA3E8h                                      ! amber
  OF 4; RETURN 0794E1Fh                                      ! deep navy
  OF 5; RETURN 04E996Ah                                      ! sage green
  OF 6; RETURN 04657C0h                                      ! terracotta
  OF 7; RETURN 08B7464h                                      ! slate gray
  END
  RETURN 0B1A59Ah                                            ! cool gray

GraficaBarraClass.FmtNum PROCEDURE(REAL v,LONG dp)
pic  CSTRING(16)
  CODE
  IF dp > 0
    pic = '@n-13.' & dp
  ELSE
    pic = '@n-13'
  END
  RETURN CLIP(LEFT(FORMAT(v, pic)))

!=== drawing ================================================================
GraficaBarraClass.Paint PROCEDURE(SIGNED pFeq,BYTE pWindowMode=0)
x     LONG
y     LONG
w     LONG
h     LONG
cw    LONG                                                   ! text cell width in target units
ch    LONG                                                   ! text cell height in target units
pad   LONG
ml    LONG                                                   ! margins
mr    LONG
mt    LONG
mb    LONG
px    LONG                                                   ! plot rectangle
py    LONG
pw    LONG
ph    LONG
lo    REAL                                                   ! value axis range
hi    REAL
dmin  REAL
dmax  REAL
zy    LONG                                                   ! zero-baseline y
gy    LONG
i     LONG
n     LONG
lw    LONG
slot  REAL
gap   REAL
bx    LONG
bw    LONG
bt    LONG
bh    LONG
v     REAL
c     LONG
tx    LONG
ty    LONG
txt   STRING(64)
  CODE
  GETPOSITION(pFeq, x, y, w, h)
  IF pWindowMode                                             ! window: the IMAGE is the target (2-arg SETTARGET),
    BLANK                                                    ! so origin is 0,0 and BLANK clears just this image.
    x = 0; y = 0                                             ! report: keep the band offset, no clear.
  END
  ! ---- text metrics: dialog units on a window, 1/1000 inch on a report ----
  IF SELF.TextW > 0
    cw = SELF.TextW
  ELSIF pWindowMode
    cw = 4
  ELSE
    cw = 55
  END
  IF SELF.TextH > 0
    ch = SELF.TextH
  ELSIF pWindowMode
    ch = 9
  ELSE
    ch = 130
  END
  pad = INT(ch / 4); IF pad < 1 THEN pad = 1.
  n = SELF.NBars
  ! ---- value axis range ----
  lo = SELF.MinVal; hi = SELF.MaxVal
  IF SELF.AutoScale = 1
    dmin = 0; dmax = 0
    LOOP i = 1 TO n
      IF SELF.BarValue[i] < dmin THEN dmin = SELF.BarValue[i].
      IF SELF.BarValue[i] > dmax THEN dmax = SELF.BarValue[i].
    END
    IF dmax > 0 THEN hi = SELF.NiceMax(dmax) ELSE hi = 0.
    IF dmin < 0 THEN lo = -SELF.NiceMax(-dmin) ELSE lo = 0.
  END
  IF hi <= lo THEN hi = lo + 1.
  ! ---- margins + plot rectangle ----
  mt = pad
  IF SELF.Title THEN mt += ch + pad.
  IF SELF.ShowValues = 1 THEN mt += ch + pad.
  mb = pad
  IF SELF.ShowLabels = 1 THEN mb += ch + pad.
  ml = pad
  IF SELF.ShowScale = 1
    lw = LEN(SELF.FmtNum(hi, SELF.ScaleDP))
    i = LEN(SELF.FmtNum(lo, SELF.ScaleDP))
    IF i > lw THEN lw = i.
    ml += lw * cw + pad
  END
  mr = 2 * cw
  px = x + ml; py = y + mt; pw = w - ml - mr; ph = h - mt - mb
  IF pw < 8 OR ph < 8 THEN RETURN.
  ! ---- backgrounds ----
  SETPENWIDTH(1)
  IF SELF.BackColor <> COLOR:None
    SETPENCOLOR(SELF.BackColor)
    BOX(x, y, w, h, SELF.BackColor)
  END
  IF SELF.PlotColor <> COLOR:None
    SETPENCOLOR(SELF.PlotColor)
    BOX(px, py, pw, ph, SELF.PlotColor)
  END
  ! ---- title ----
  IF SELF.Title
    SETPENCOLOR(SELF.TextColor)
    SHOW(x + INT(w/2) - INT(LEN(CLIP(SELF.Title)) * cw / 2), y + pad, CLIP(SELF.Title))
  END
  ! ---- gridlines + scale labels ----
  IF SELF.GridDivs < 1 THEN SELF.GridDivs = 1.
  LOOP i = 0 TO SELF.GridDivs
    v = lo + (hi - lo) * i / SELF.GridDivs
    gy = py + ph - INT(ph * (v - lo) / (hi - lo))
    IF SELF.ShowGrid = 1 AND i > 0
      SETPENWIDTH(1); SETPENCOLOR(SELF.GridColor)
      LINE(px, gy, pw, 0)
    END
    IF SELF.ShowScale = 1
      txt = SELF.FmtNum(v, SELF.ScaleDP)
      SETPENCOLOR(SELF.TextColor)
      SHOW(px - pad - LEN(CLIP(txt)) * cw, gy - INT(ch/2), CLIP(txt))
    END
  END
  ! ---- zero baseline position ----
  IF lo < 0 AND hi > 0
    zy = py + ph - INT(ph * (0 - lo) / (hi - lo))
  ELSIF lo >= 0
    zy = py + ph                                             ! all positive: baseline at the bottom
  ELSE
    zy = py                                                  ! all negative: baseline at the top
  END
  ! ---- bars ----
  IF n > 0
    slot = pw / n
    gap = slot * SELF.BarGapPct / 200                        ! half the gap each side of a bar
    LOOP i = 1 TO n
      v = SELF.BarValue[i]
      IF v < lo THEN v = lo.
      IF v > hi THEN v = hi.
      bx = px + INT(slot * (i - 1) + gap)
      bw = INT(slot - 2 * gap); IF bw < 1 THEN bw = 1.
      gy = py + ph - INT(ph * (v - lo) / (hi - lo))
      IF gy <= zy
        bt = gy; bh = zy - gy
      ELSE
        bt = zy; bh = gy - zy
      END
      IF bh < 1 THEN bh = 1.
      c = SELF.BarColor[i]
      IF c = COLOR:None THEN c = SELF.Palette(i).
      SETPENWIDTH(1)
      IF SELF.BarBorderColor <> COLOR:None
        SETPENCOLOR(SELF.BarBorderColor)
      ELSE
        SETPENCOLOR(c)
      END
      BOX(bx, bt, bw, bh, c)
      IF SELF.ShowValues = 1
        txt = SELF.FmtNum(SELF.BarValue[i], SELF.ValueDP)
        tx = bx + INT(bw/2) - INT(LEN(CLIP(txt)) * cw / 2)
        IF v >= 0
          ty = bt - ch - INT(pad/2)                          ! above a positive bar
        ELSE
          ty = bt + bh + INT(pad/2)                          ! below a negative bar
        END
        SETPENCOLOR(SELF.TextColor)
        SHOW(tx, ty, CLIP(txt))
      END
      IF SELF.ShowLabels = 1
        txt = CLIP(SELF.BarLabel[i])
        lw = INT((slot - gap) / cw); IF lw < 1 THEN lw = 1.
        IF LEN(CLIP(txt)) > lw THEN txt = SUB(txt, 1, lw).
        tx = bx + INT(bw/2) - INT(LEN(CLIP(txt)) * cw / 2)
        SETPENCOLOR(SELF.TextColor)
        SHOW(tx, py + ph + pad, CLIP(txt))
      END
    END
  END
  ! ---- axis on top of everything ----
  IF SELF.ShowAxis = 1
    SETPENWIDTH(1); SETPENCOLOR(SELF.AxisColor)
    LINE(px, py, 0, ph)                                      ! value axis (left)
    LINE(px, zy, pw, 0)                                      ! zero baseline
  END

GraficaBarraClass.Draw PROCEDURE(WINDOW pWin,SIGNED pImageFeq)
  CODE
  SETTARGET(pWin, pImageFeq)                                 ! the IMAGE is the target: 0,0 = its top-left, and
  SELF.Paint(pImageFeq, 1)                                   ! the graphics belong to the image so they survive a
  SETTARGET()                                                ! repaint / resize (a window-layer draw gets wiped)
