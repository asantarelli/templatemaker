! ============================================================================
!  graficaBarra - ClearAll() on a REPORT: diagnostic demo.
!
!  Paints chart A into a band placeholder, calls ClearAll(), builds a totally
!  different chart B and paints it into the SAME placeholder. Each experiment
!  gets its own page so the .wmf pages can be compared side gy side.
!
!  ReportClear      -> pages 1..5, the diagnosis
!  ReportClear 2    -> pages 1..3, candidate fixes
!
!  Build: msbuild ReportClear.cwproj -t:Build -p:Configuration=Debug
!                 -p:Platform=Win32 -p:ClarionBinPath="C:\clarion12\bin"
! ============================================================================
  PROGRAM

  INCLUDE('GraficaBarraClass.INC'),ONCE
  INCLUDE('EQUATES.CLW'),ONCE
  PRAGMA('link(ClaASC%X%%L%.lib)')                           ! ASCII driver, for the mode-3 log

  MAP
  END

G          GraficaBarraClass                                 ! ONE object, reused - the point of the test
Caption    STRING(90)
Mode       LONG
i          LONG
gx         LONG
gy         LONG
gw         LONG
gh         LONG
PrevQ      QUEUE
FName        STRING(260)
           END
Line       STRING(120)                                       ! mode 3: the control census log
Note       STRING(60)
LogName    STRING(64)
Log        FILE,DRIVER('ASCII'),NAME(LogName),PRE(LG),CREATE
           RECORD
Dbg          STRING(120)
             END
           END

Rpt   REPORT,AT(500,500,7500,10000),THOUS,FONT('Segoe UI',9,,,CHARSET:ANSI)
Hdr     HEADER,AT(0,0,7500,420),USE(?Hdr)
          STRING(@s90),AT(0,60,7500,220),USE(Caption),CENTER,FONT('Segoe UI',11,,FONT:bold)
        END
Det     DETAIL,AT(0,0,7000,5600),USE(?Det)
          IMAGE,AT(250,150,6500,5000),USE(?Place)
          STRING('band control - a BLANK must not eat this'),AT(250,5250,4000,200),USE(?Tag), |
            FONT('Segoe UI',8,0808080H)
        END
Two     DETAIL,AT(0,0,7000,5600),USE(?Two)
          IMAGE,AT(250,150,3100,5000),USE(?P1)
          IMAGE,AT(3550,150,3100,5000),USE(?P2)
          STRING('left = repainted, right = must survive'),AT(250,5250,4000,200),USE(?Tag2), |
            FONT('Segoe UI',8,0808080H)
        END
      END

  CODE
  Mode = COMMAND('1')
  IF Mode < 1 THEN Mode = 1.
  OPEN(Rpt)
  Rpt{PROP:Preview} = PrevQ.FName                            ! must be AFTER open
  CASE Mode
  OF 2
    DO Fixes
  OF 3
    DO Enumerate
  ELSE
    DO Diagnose
  END
  ENDPAGE(Rpt)
  LOOP i = 1 TO RECORDS(PrevQ)                               ! copy BEFORE close - close deletes them
    GET(PrevQ, i)
    COPY(CLIP(PrevQ.FName), 'rpt' & Mode & '_page' & i & '.wmf')
  END
  CLOSE(Rpt)
  RETURN

!----------------------------------------------------------------------------
!  The five experiments
!----------------------------------------------------------------------------
Diagnose ROUTINE
  ! (1) baseline - chart A on its own
  Caption = '1) chart A alone'
  DO ChartA
  DO PaintIt
  PRINT(Det)
  ENDPAGE(Rpt)

  ! (2) print the band again WITHOUT drawing anything at all.
  !     If chart A shows up here, the band keeps its graphics between prints.
  Caption = '2) nothing painted at all - is chart A still in the band?'
  PRINT(Det)
  ENDPAGE(Rpt)

  ! (3) ClearAll() then a completely different chart into the same placeholder
  Caption = '3) ClearAll() then chart B - did chart A go away?'
  DO ChartB
  DO PaintIt
  PRINT(Det)
  ENDPAGE(Rpt)

  ! (4) both charts painted into one band before a single PRINT
  Caption = '4) chart A, ClearAll(), chart B - both painted before one PRINT'
  DO ChartA
  DO PaintIt
  DO ChartB
  DO PaintIt
  PRINT(Det)
  ENDPAGE(Rpt)

  ! (5) what chart B is supposed to look like, from a virgin object
  Caption = '5) chart B on its own (what page 3 and 4 should look like)'
  DO ChartB
  DO PaintIt
  PRINT(Det)
  ENDPAGE(Rpt)

  ! (6) the same as (4) with the erase switched off - the old behaviour,
  !     and what you still get when you ask for a deliberate overlay
  Caption = '6) the same as 4) with EraseFirst = 0 - chart A bleeds through'
  G.EraseFirst = 0
  DO ChartA
  DO PaintIt
  DO ChartB
  DO PaintIt
  G.EraseFirst = 1
  PRINT(Det)

!----------------------------------------------------------------------------
!  Candidate fixes
!----------------------------------------------------------------------------
Fixes ROUTINE
  Caption = 'F1) chart A alone (reference)'
  DO ChartA
  DO PaintIt
  PRINT(Det)
  ENDPAGE(Rpt)

  ! fix 1 - opaque background: chart B paints white over its whole rectangle
  Caption = 'F2) A painted, then ClearAll() + chart B with BackColor = white'
  DO ChartA
  DO PaintIt
  DO ChartB
  G.BackColor = COLOR:White
  DO PaintIt
  G.BackColor = COLOR:None
  PRINT(Det)
  ENDPAGE(Rpt)

  ! fix 2 - BLANK the band before repainting
  Caption = 'F3) A painted, then BLANK on the band, then ClearAll() + chart B'
  DO ChartA
  DO PaintIt
  DO ChartB
  SETTARGET(Rpt, ?Det)
  BLANK
  SETTARGET()
  DO PaintIt
  PRINT(Det)
  ENDPAGE(Rpt)

  ! fix 3 - BLANK(x,y,w,h): erase ONLY the one placeholder. Two charts share
  !         this band; repainting the left one must leave the right one alone.
  Caption = 'F4) BLANK(x,y,w,h) on ?P1 only - the chart in ?P2 must survive'
  DO ChartA
  SETTARGET(Rpt, ?Two)
  G.Paint(?P1)
  G.Paint(?P2)
  SETTARGET()
  DO ChartB
  SETTARGET(Rpt, ?Two)
  GETPOSITION(?P1, gx, gy, gw, gh)
  BLANK(gx, gy, gw, gh)
  G.Paint(?P1)
  SETTARGET()
  PRINT(Two)

!----------------------------------------------------------------------------
!  Mode 3 - what does the report actually CONTAIN at each step? Walk every
!  child of the report with PROP:NextField and log it. If Paint created
!  controls they would appear here; if it only laid down ink, the list never
!  changes and only the metafile grows.
!----------------------------------------------------------------------------
Enumerate ROUTINE
  LogName = 'ReportClear.log'
  REMOVE(Log)
  CREATE(Log)
  OPEN(Log, 12h)
  Caption = 'control census'
  Note = 'BEFORE anything is painted'
  DO Census                                                  ! (a) nothing painted yet
  DO ChartA
  DO PaintIt
  Note = 'AFTER painting chart A'
  DO Census
  G.ClearAll()
  Note = 'AFTER ClearAll() - data gone, ink not'
  DO Census
  DO ChartB
  DO PaintIt
  Note = 'AFTER painting chart B over the same placeholder'
  DO Census
  CLOSE(Log)
  PRINT(Det)

Census ROUTINE
  DATA
f    LONG
n    LONG
ty   LONG
nm   STRING(9)
  CODE
  Line = '=== ' & CLIP(Note)
  DO WriteLine
  SETTARGET(Rpt)                                             ! GETPOSITION reads the current target
  f = 0; n = 0
  LOOP
    f = Rpt{PROP:NextField, f}
    IF f = 0 THEN BREAK.
    n += 1
    ty = Rpt$f{PROP:Type}
    CASE ty
    OF CREATE:detail;  nm = 'DETAIL'
    OF CREATE:header;  nm = 'HEADER'
    OF CREATE:footer;  nm = 'FOOTER'
    OF CREATE:form;    nm = 'FORM'
    OF CREATE:break;   nm = 'BREAK'
    OF CREATE:image;   nm = 'IMAGE'
    OF CREATE:string;  nm = 'STRING'
    OF CREATE:box;     nm = 'BOX'
    OF CREATE:line;    nm = 'LINE'
    OF CREATE:ellipse; nm = 'ELLIPSE'
    OF CREATE:region;  nm = 'REGION'
    ELSE;              nm = 'type ' & ty
    END
    GETPOSITION(f, gx, gy, gw, gh)
    Line = '    feq ' & FORMAT(f,@n-5) & '  ' & nm & |
           '  at(' & gx & ',' & gy & ',' & gw & ',' & gh & ')'
    DO WriteLine
  END
  SETTARGET()
  Line = '    children of the REPORT: ' & n
  DO WriteLine
  Line = ''
  DO WriteLine

WriteLine ROUTINE
  LG:Dbg = Line
  ADD(Log)

!----------------------------------------------------------------------------
PaintIt ROUTINE
  SETTARGET(Rpt, ?Det)                                       ! what the template generates
  G.Paint(?Place)
  SETTARGET()

!----------------------------------------------------------------------------
ChartA ROUTINE
  G.ClearAll()
  G.ChartType = Chart:Column
  G.Title = 'A - six tall columns'
  G.ShowLegend = 0
  G.AddBar('Ene', 42)
  G.AddBar('Feb', 58)
  G.AddBar('Mar', 35)
  G.AddBar('Abr', 71)
  G.AddBar('May', 64)
  G.AddBar('Jun', 89)

!----------------------------------------------------------------------------
ChartB ROUTINE
  G.ClearAll()
  G.ChartType = Chart:Bar                                    ! horizontal - unmistakable if A bleeds through
  G.Title = 'B - three horizontal bars'
  G.ShowLegend = 0
  G.AddBar('Norte', 20)
  G.AddBar('Sur', 15)
  G.AddBar('Este', 10)
