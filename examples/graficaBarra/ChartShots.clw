! ============================================================================
!  graficaBarra - contact sheet. Six charts per page, so one screenshot shows
!  a whole family at once. Page number on the command line: ChartShots 2
!
!  Build:  msbuild ChartShots.cwproj -t:Build -p:Configuration=Debug
!                  -p:Platform=Win32 -p:ClarionBinPath="C:\clarion12\bin"
! ============================================================================
  PROGRAM

  INCLUDE('GraficaBarraClass.INC'),ONCE
  INCLUDE('EQUATES.CLW'),ONCE

  MAP
  END

G          GraficaBarraClass                                 ! one object paints all six
Pg         LONG
Slot       LONG
Feq        SIGNED
Ty         LONG
Wnd      WINDOW('graficaBarra - chart types'),AT(,,880,474),SYSTEM,GRAY,CENTER, |
             FONT('Segoe UI',9,,FONT:regular,CHARSET:ANSI),ICON(ICON:Application)
           IMAGE,AT(8,10,280,196),USE(?G1)
           IMAGE,AT(296,10,280,196),USE(?G2)
           IMAGE,AT(584,10,280,196),USE(?G3)
           IMAGE,AT(8,214,280,196),USE(?G4)
           IMAGE,AT(296,214,280,196),USE(?G5)
           IMAGE,AT(584,214,280,196),USE(?G6)
           STRING(''),AT(8,420,600,10),USE(?Foot),FONT('Segoe UI',8,00808080H),TRN
           BUTTON('&Close'),AT(810,418,54,14),USE(?Close),STD(STD:Close)
         END
  CODE
  Pg = COMMAND('1')
  IF Pg < 1 THEN Pg = 1.
  OPEN(Wnd)
  ?Foot{PROP:Text} = 'graficaBarra - page ' & Pg & ' - drawn with native BOX / LINE / POLYGON / ELLIPSE / PIE'
  LOOP Slot = 1 TO 6
    CASE Slot
    OF 1; Feq = ?G1
    OF 2; Feq = ?G2
    OF 3; Feq = ?G3
    OF 4; Feq = ?G4
    OF 5; Feq = ?G5
    OF 6; Feq = ?G6
    END
    DO OneChart
  END
  ACCEPT
  END
  CLOSE(Wnd)
  RETURN

!----------------------------------------------------------------------------
OneChart ROUTINE
  DATA
s   LONG
  CODE
  Ty = (Pg - 1) * 6 + Slot - 1
  G.ChartType = Ty
  G.BackColor = 0FFFFFFh                                     ! a white card per chart
  G.PlotColor = COLOR:None
  G.ShowLegend = 1
  G.LegendPos = Legend:Bottom
  G.Smooth = 0
  G.Percent = 0
  G.ShowValues = 1
  G.ShowMarkers = 1
  G.MarkerShape = Marker:Circle
  G.DonutText = ''
  G.AutoScale = 1
  G.ShowGrid = 1
  G.ValueDP = 0
  G.ScaleDP = 0
  G.DonutPct = 55
  CASE Ty
  OF Chart:Column;      G.Title = 'Column'
  OF Chart:Bar;         G.Title = 'Bar (horizontal)'
  OF Chart:StackedCol;  G.Title = 'Stacked column'
  OF Chart:StackedBar;  G.Title = 'Stacked bar'
  OF Chart:Stacked100;  G.Title = '100% stacked'; G.ValueDP = 0
  OF Chart:Line;        G.Title = 'Line'
  OF Chart:Area;        G.Title = 'Area'
  OF Chart:StackedArea; G.Title = 'Stacked area'; G.ShowValues = 0
  OF Chart:Scatter;     G.Title = 'Scatter'
  OF Chart:Pie;         G.Title = 'Pie'; G.Percent = 1
  OF Chart:Pie3D;       G.Title = '3D pie'
  OF Chart:Donut;       G.Title = 'Donut'; G.Percent = 1; G.DonutText = '100'
  OF Chart:Radar;       G.Title = 'Radar'
  END
  IF Ty < 13
    G.Demo()                                                 ! sample data suited to the type
  END
  ! ---- page 3: the awkward cases, hand fed ----
  CASE Ty
  OF 13                                                      ! grouped columns, legend on the right
    G.ChartType = Chart:Column
    G.Title = 'Grouped + legend right'
    G.LegendPos = Legend:Right
    G.ClearAll()
    G.AddSeries('2025')
    G.AddSeries('2026')
    G.AddCat('Q1', 42, 55)
    G.AddCat('Q2', 58, 49)
    G.AddCat('Q3', 35, 62)
    G.AddCat('Q4', 71, 80)
  OF 14                                                      ! negative values, zero baseline
    G.ChartType = Chart:Column
    G.Title = 'Negative values'
    G.ClearAll()
    G.AddBar('Ene', 42)
    G.AddBar('Feb', -18)
    G.AddBar('Mar', 35)
    G.AddBar('Abr', -27)
    G.AddBar('May', 64)
  OF 15                                                      ! smooth multi-series line
    G.ChartType = Chart:Line
    G.Title = 'Smooth line, two series'
    G.Smooth = 1
    G.ShowValues = 0
    G.ClearAll()
    G.AddSeries('Plan')
    G.AddSeries('Real')
    G.AddCat('Ene', 30, 22)
    G.AddCat('Feb', 45, 51)
    G.AddCat('Mar', 40, 33)
    G.AddCat('Abr', 62, 70)
    G.AddCat('May', 55, 48)
    G.AddCat('Jun', 78, 84)
  OF 16                                                      ! money, two decimals, no grid
    G.ChartType = Chart:Bar
    G.Title = 'Two decimals, no grid'
    G.ShowGrid = 0
    G.ValueDP = 2
    G.ScaleDP = 2
    G.ClearAll()
    G.AddBar('Alfa', 12.5)
    G.AddBar('Beta', 33.75)
    G.AddBar('Gama', 21.125)
  OF 17                                                      ! forty points, crowded labels
    G.ChartType = Chart:Column
    G.Title = 'Forty bars'
    G.ShowValues = 0
    G.ClearAll()
    LOOP s = 1 TO 40
      G.AddBar('D' & s, 20 + 30 * (1 + SIN(s / 3)))
    END
  END
  G.Draw(Wnd, Feq)
