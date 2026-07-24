!ABCIncludeFile
! ============================================================================
!  GraficaBarraClass - a simple bar graph for Clarion, drawn with native
!  graphics primitives (BOX / LINE / SHOW). Works on WINDOWs (into an IMAGE
!  control) and on REPORTs (drawn straight into the band as vector primitives,
!  so PDF export stays as small as possible - no bitmap involved).
!  Pure Clarion - no external dependencies.
!
!  USAGE (handled by the graficaBarra template, or call it yourself):
!    INCLUDE('GraficaBarraClass.INC'),ONCE     then declare one per graph:
!      Ventas  GraficaBarraClass
!    Ventas.Title = 'Ventas 2026'
!    Ventas.AddBar('Ene', 120)                 ! auto palette color
!    Ventas.AddBar('Feb', 95, 0B6752Eh)        ! explicit color (Clarion BGR)
!    Ventas.Draw(MyWindow, ?Graph)             ! window: draw into the IMAGE
!    ! report (per band):
!    !   SETTARGET(MyReport) ; Ventas.Paint(?Placeholder) ; SETTARGET()
!
!  Values may be negative (bars hang below the zero baseline). If AutoScale=1
!  (default) the value axis is computed from the data and rounded up to a
!  "nice" 1/2/5 x 10^k number; call SetRange(min,max) for a fixed scale.
!
!  This file MUST be stored in ANSI (not UTF-8), CRLF line ends.
! ============================================================================

GraficaBarra:MaxBars EQUATE(48)

GraficaBarraClass CLASS,TYPE,MODULE('GraficaBarraClass.CLW'),LINK('GraficaBarraClass.CLW')
! ---- text ----
Title              CSTRING(64)                               ! centered above the plot
! ---- features on/off ----
ShowValues         BYTE                                      ! numeric value over each bar
ValueDP            LONG                                      ! decimals on bar values
ShowLabels         BYTE                                      ! bar label under the baseline
ShowScale          BYTE                                      ! numeric scale down the left side
ScaleDP            LONG                                      ! decimals on scale labels
ShowGrid           BYTE                                      ! horizontal gridlines
GridDivs           LONG                                      ! scale/grid divisions (default 5)
ShowAxis           BYTE                                      ! left axis + zero baseline
! ---- scale ----
AutoScale          BYTE                                      ! 1 = derive the scale from the data
MinVal             REAL                                      ! used when AutoScale = 0
MaxVal             REAL
! ---- layout ----
BarGapPct          LONG                                      ! gap between bars, percent of one slot
TextW              LONG                                      ! char cell width override (0 = auto per target)
TextH              LONG                                      ! char cell height override (0 = auto per target)
! ---- colors (Clarion BGR longs) ----
BackColor          LONG                                      ! whole-control background (COLOR:None = leave)
PlotColor          LONG                                      ! plot-area fill (COLOR:None = leave)
AxisColor          LONG
GridColor          LONG
TextColor          LONG
BarBorderColor     LONG                                      ! COLOR:None = border same as the fill
! ---- data ----
NBars              LONG
BarLabel           STRING(32),DIM(GraficaBarra:MaxBars)
BarValue           REAL,DIM(GraficaBarra:MaxBars)
BarColor           LONG,DIM(GraficaBarra:MaxBars)            ! -1 (COLOR:None) = auto palette
! ---- methods --------------------------------------------------------------
Construct          PROCEDURE
ClearBars          PROCEDURE
AddBar             PROCEDURE(STRING pLabel,REAL pValue,LONG pColor=-1)
SetRange           PROCEDURE(REAL pMin,REAL pMax)            ! fixed scale (sets AutoScale=0)
Demo               PROCEDURE                                 ! six sample bars (self-test)
Draw               PROCEDURE(WINDOW pWin,SIGNED pImageFeq)   ! window: target the IMAGE, clear, paint
Paint              PROCEDURE(SIGNED pFeq,BYTE pWindowMode=0) ! paint into the CURRENT target at pFeq's rect;
                                                             ! pWindowMode=1 clears the image first (windows),
                                                             ! 0 = no clear, band offset kept (reports)
! ---- internal ----
NiceMax            PROCEDURE(REAL v),REAL                    ! round up to 1/2/5 x 10^k
Palette            PROCEDURE(LONG i),LONG                    ! professional auto colors (cycles)
FmtNum             PROCEDURE(REAL v,LONG dp),STRING
                   END
