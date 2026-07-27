! ============================================================================
!  graficaBarra demo  -  pick a chart type on the left, watch it draw on the
!  right. Every chart is native Clarion graphics (BOX / LINE / POLYGON /
!  ELLIPSE / PIE / SHOW) into one IMAGE control - no bitmap, no DLL.
!
!  This is the hand-coded equivalent of what the graficaBarra extension
!  template generates for you.
!
!  Build:  msbuild ChartDemo.cwproj -t:Build -p:Configuration=Debug
!                  -p:Platform=Win32 -p:ClarionBinPath="C:\clarion12\bin"
! ============================================================================
  PROGRAM

  INCLUDE('GraficaBarraClass.INC'),ONCE
  INCLUDE('EQUATES.CLW'),ONCE

  MAP
  END

G        GraficaBarraClass
LOC:Type       LONG
LOC:NSeries    LONG
LOC:Values     BYTE
LOC:Labels     BYTE
LOC:Scale      BYTE
LOC:Grid       BYTE
LOC:Legend     BYTE
LOC:Spot       LONG
LOC:Markers    BYTE
LOC:Shape      LONG
LOC:Smooth     BYTE
LOC:Percent    BYTE
LOC:Plot       BYTE
Wnd      WINDOW('graficaBarra - thirteen chart types, native Clarion graphics'),AT(,,760,438), |
             SYSTEM,GRAY,CENTER,FONT('Segoe UI',9,,FONT:regular,CHARSET:ANSI),ICON(ICON:Application)
           PANEL,AT(0,0,760,34),USE(?Band),FILL(0603A1FH)
           STRING('Charts'),AT(12,6),USE(?T1),FONT('Segoe UI',13,COLOR:White,FONT:bold),TRN
           STRING('One class, one IMAGE control, thirteen chart types - and the same' & |
             ' code draws into a report band as vectors.'),AT(12,21),USE(?T2), |
             FONT('Segoe UI',8,0D8C8B4H),TRN
           PROMPT('&Chart type:'),AT(10,42),USE(?PT)
           LIST,AT(10,54,120,148),USE(?TypeList),FROM('Column|Bar (horizontal)|Stacked column|Stacked bar|Stacked percent|Line|Area|Stacked area|Scatter|Pie|Pie 3D|Donut|Radar'),VSCROLL
           PROMPT('&Series:'),AT(10,208),USE(?PS)
           SPIN(@n1),AT(64,207,30,11),USE(LOC:NSeries),RANGE(1,3),STEP(1)
           CHECK('Show &values'),AT(10,224),USE(LOC:Values)
           CHECK('Show &labels'),AT(10,238),USE(LOC:Labels)
           CHECK('Show sc&ale'),AT(10,252),USE(LOC:Scale)
           CHECK('Show &gridlines'),AT(10,266),USE(LOC:Grid)
           CHECK('Show le&gend'),AT(10,280),USE(LOC:Legend)
           LIST,AT(24,294,80,11),USE(?SpotList),DROP(4),FROM('Bottom|Right|Top')
           CHECK('&Markers'),AT(10,310),USE(LOC:Markers)
           LIST,AT(24,324,80,11),USE(?ShapeList),DROP(4),FROM('Circle|Square|Diamond')
           CHECK('S&mooth lines'),AT(10,340),USE(LOC:Smooth)
           CHECK('Values as &percent'),AT(10,354),USE(LOC:Percent)
           CHECK('Tint the &plot area'),AT(10,368),USE(LOC:Plot)
           BOX,AT(140,42,610,352),USE(?Frame),COLOR(00D4D0CCH),FILL(00FFFFFFH)
           IMAGE,AT(144,46,602,344),USE(?Chart)
           STRING('The value axis rounds itself up to a nice 1 / 2 / 5 number and puts zero' & |
             ' on a gridline.'),AT(10,400),USE(?Hint),FONT('Segoe UI',8,00808080H),TRN
           STRING(''),AT(10,412,500,10),USE(?Hint2),FONT('Segoe UI',8,0603A1FH),TRN
           BUTTON('&Close'),AT(692,414,58,15),USE(?Close),STD(STD:Close)
         END
  CODE
  LOC:Type    = 1
  LOC:NSeries = 1
  LOC:Values  = 1
  LOC:Labels  = 1
  LOC:Scale   = 1
  LOC:Grid    = 1
  LOC:Legend  = 1
  LOC:Spot    = 1
  LOC:Markers = 1
  LOC:Shape   = 1
  LOC:Smooth  = 0
  LOC:Percent = 0
  LOC:Plot    = 0
  OPEN(Wnd)
  ?TypeList{PROP:Selected} = 1
  ?SpotList{PROP:Selected} = 1
  ?ShapeList{PROP:Selected} = 1
  ?Hint2{PROP:Text} = 'Pie, Pie 3D and Donut always plot series 1. Radar needs three ' & |
                      'categories or more, otherwise it falls back to a line.'
  DO DrawIt
  ACCEPT
    CASE EVENT()
    OF EVENT:Accepted OROF EVENT:NewSelection
      CASE FIELD()
      OF ?Close
      ELSE
        DO DrawIt
      END
    END
  END
  CLOSE(Wnd)
  RETURN

!----------------------------------------------------------------------------
DrawIt ROUTINE
  DATA
i    LONG
  CODE
  LOC:Type  = CHOICE(?TypeList)
  LOC:Spot  = CHOICE(?SpotList)
  LOC:Shape = CHOICE(?ShapeList)
  IF LOC:Type < 1 THEN LOC:Type = 1.
  IF LOC:Spot < 1 THEN LOC:Spot = 1.
  IF LOC:Shape < 1 THEN LOC:Shape = 1.
  G.ChartType   = LOC:Type - 1                               ! the list is 1..13, Chart: equates are 0..12
  G.ShowValues  = LOC:Values
  G.ShowLabels  = LOC:Labels
  G.ShowScale   = LOC:Scale
  G.ShowGrid    = LOC:Grid
  G.ShowLegend  = LOC:Legend
  G.LegendPos   = LOC:Spot - 1
  G.ShowMarkers = LOC:Markers
  G.MarkerShape = LOC:Shape - 1
  G.Smooth      = LOC:Smooth
  G.Percent     = LOC:Percent
  G.BackColor   = 0FFFFFFh
  IF LOC:Plot
    G.PlotColor = 0FBFBFBh
  ELSE
    G.PlotColor = COLOR:None
  END
  G.DonutText   = 'Ventas'
  G.Title       = 'Ventas por region'
  ! ---- the data: one to three series over six months ----
  G.ClearAll()
  IF LOC:NSeries > 1
    LOOP i = 1 TO LOC:NSeries
      CASE i
      OF 1; G.AddSeries('Norte')
      OF 2; G.AddSeries('Sur')
      OF 3; G.AddSeries('Centro')
      END
    END
    G.AddCat('Ene', 42, 28, 15)
    G.AddCat('Feb', 58, 33, 19)
    G.AddCat('Mar', 35, 25, 12)
    G.AddCat('Abr', 71, 40, 22)
    G.AddCat('May', 64, 36, 26)
    G.AddCat('Jun', 89, 47, 31)
  ELSE
    G.AddBar('Ene', 42)
    G.AddBar('Feb', 58)
    G.AddBar('Mar', 35)
    G.AddBar('Abr', 71)
    G.AddBar('May', 64)
    G.AddBar('Jun', 89)
  END
  G.Draw(Wnd, ?Chart)
