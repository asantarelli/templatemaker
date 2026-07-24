#TEMPLATE(graficaBarra,'graficaBarra - Bar graphs on windows and reports - v1.0'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  graficaBarra template set - simple bar graphs drawn with native Clarion
#!  graphics primitives (BOX / LINE / SHOW). No external dependencies.
#!
#!  graficaBarraGlobal (APPLICATION) - INCLUDEs GraficaBarraClass. Add once.
#!  graficaBarra       (PROCEDURE)   - draws a bar graph into an IMAGE control
#!                     on a WINDOW. Add once per graph (several per window OK).
#!  graficaBarraReport (PROCEDURE)   - draws a bar graph into a REPORT band as
#!                     BOX/LINE/SHOW VECTOR primitives - never a bitmap - so a
#!                     PDF export stays as small as possible. A control in the
#!                     band (IMAGE / BOX / REGION) is used ONLY as the position
#!                     and size placeholder; it is hidden at print time.
#!
#!  REQUIRED FILES: copy GraficaBarraClass.inc AND GraficaBarraClass.clw
#!  (shipped beside this .tpl) to a folder on the Clarion redirection path
#!  (the app folder or \clarion12\libsrc\win). Store them in ANSI.
#!
#!  API (the object is in the procedure's data - call it from any embed):
#!    Graph1.ClearBars() ; Graph1.AddBar('Ene', 120) ; Graph1.AddBar('Feb', 95, 0B6752Eh)
#!    Graph1.SetRange(0, 200)          ! fixed scale (otherwise auto "nice" scale)
#!    DO Refresh:Graph1                ! window: reload the bars + redraw
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - graficaBarraGlobal
#!#############################################################################
#EXTENSION(graficaBarraGlobal,'graficaBarra - Global (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('graficaBarra')
      #DISPLAY('graficaBarra Global - Version 1.0')
      #DISPLAY('Adds the GraficaBarraClass bar-graph renderer.')
      #DISPLAY('Add once, at the Application (global) level. IMPORTANT: copy')
      #DISPLAY('GraficaBarraClass.inc + .clw to the redirection path - ANSI.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%gbDisable,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#AT(%AfterGlobalIncludes),WHERE(%gbDisable=0)
INCLUDE('GraficaBarraClass.INC'),ONCE
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - graficaBarra (WINDOW)  -  add once per graph
#!#############################################################################
#EXTENSION(graficaBarra,'graficaBarra - Draw a bar graph on this window'),PROCEDURE,REQ(graficaBarraGlobal),DESCRIPTION(' [BarGraph] ' & %gbWObject)
#SHEET
  #TAB('&General')
    #BOXED('Object &&  control')
      #PROMPT('&Disable this graph',CHECK),%gbWDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%gbWObject,REQ,DEFAULT('Graph' & %ActiveTemplateInstance)
      #PROMPT('&Image control to draw into:',CONTROL),%gbWImage,REQ
      #PROMPT('&Title text:',@s64),%gbWTitle,DEFAULT('')
    #ENDBOXED
    #BOXED('Value scale')
      #PROMPT('&Automatic scale (nice round maximum from the data)',CHECK),%gbWAutoScale,DEFAULT(1),AT(10)
      #ENABLE(%gbWAutoScale=0)
        #PROMPT('&Minimum:',@n13.2),%gbWMin,DEFAULT(0)
        #PROMPT('Ma&ximum:',@n13.2),%gbWMax,DEFAULT(100)
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
  #TAB('&Look')
    #BOXED('Show')
      #PROMPT('Show bar &values',CHECK),%gbWShowValues,DEFAULT(1),AT(10)
      #PROMPT('Value &decimals:',SPIN(@n2,0,4,1)),%gbWValueDP,DEFAULT(0)
      #PROMPT('Show bar &labels',CHECK),%gbWShowLabels,DEFAULT(1),AT(10)
      #PROMPT('Show &scale (left axis numbers)',CHECK),%gbWShowScale,DEFAULT(1),AT(10)
      #PROMPT('Scale d&ecimals:',SPIN(@n2,0,4,1)),%gbWScaleDP,DEFAULT(0)
      #PROMPT('Show &gridlines',CHECK),%gbWShowGrid,DEFAULT(1),AT(10)
      #PROMPT('Scale/grid di&visions:',SPIN(@n3,1,20,1)),%gbWGridDivs,DEFAULT(5)
      #PROMPT('Gap between bars (%% of a slot):',SPIN(@n3,0,90,5)),%gbWGapPct,DEFAULT(30)
    #ENDBOXED
    #BOXED('Colors')
      #PROMPT('Paint the &background',CHECK),%gbWUseBack,DEFAULT(0),AT(10)
      #ENABLE(%gbWUseBack=1)
        #PROMPT('Background &color:',COLOR),%gbWBackColor,DEFAULT(00FFFFFFH)
      #ENDENABLE
      #PROMPT('A&xis color:',COLOR),%gbWAxisColor,DEFAULT(002B2B2BH)
      #PROMPT('G&rid color:',COLOR),%gbWGridColor,DEFAULT(00E0E0E0H)
      #PROMPT('Te&xt color:',COLOR),%gbWTextColor,DEFAULT(002B2B2BH)
    #ENDBOXED
  #ENDTAB
  #TAB('&Bars')
    #DISPLAY('The bars, left to right. Value can be a literal number or a')
    #DISPLAY('variable / field / expression re-read by DO Refresh:<object>.')
    #DISPLAY('If the list is empty, six sample bars are drawn (self-test).')
    #BUTTON('Bars'),MULTI(%gbWBar,%gbWBarLabel),INLINE
      #PROMPT('&Label:',@s32),%gbWBarLabel,DEFAULT('')
      #PROMPT('Value is a &variable / expression',CHECK),%gbWBarIsExpr,DEFAULT(0),AT(10)
      #ENABLE(%gbWBarIsExpr=0)
        #PROMPT('&Value:',@n13.2),%gbWBarValue,DEFAULT(0)
      #ENDENABLE
      #ENABLE(%gbWBarIsExpr=1)
        #PROMPT('Value &field / expression:',@s255),%gbWBarField,REQ,DEFAULT('')
      #ENDENABLE
      #PROMPT('&Automatic color (professional palette)',CHECK),%gbWBarAutoColor,DEFAULT(1),AT(10)
      #ENABLE(%gbWBarAutoColor=0)
        #PROMPT('&Color:',COLOR),%gbWBarColor,DEFAULT(00B6752EH)
      #ENDENABLE
    #ENDBUTTON
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%gbWDisable=0 AND %gbWImage)
%gbWObject           GraficaBarraClass                       ! one bar-graph object for this instance
Redraw:%gbWObject    EQUATE(EVENT:User + 220 + %ActiveTemplateInstance) ! private "repaint" event (unique per graph)
#ENDAT
#!
#! PRIORITY(2000) puts this self-contained CASE EVENT() ABOVE the framework's own
#! LOOP/CASE scaffolding (registered at PRIORITY 2500) - same proven spot myGauge,
#! myQRDraw and myPixel use. Using 2500 collides and duplicates CASE EVENT().
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%gbWDisable=0 AND %gbWImage)
  CASE EVENT()
  OF EVENT:OpenWindow
#INSERT(%gbWEmitConfig)
#INSERT(%gbWEmitBars)
    POST(Redraw:%gbWObject)                                  ! first draw, after the window has opened
  OF EVENT:Sized
    POST(Redraw:%gbWObject)                                  ! redraw AFTER the resizer settles (fresh size)
  OF Redraw:%gbWObject
    %gbWObject.Draw(%Window, %gbWImage)
  END
#ENDAT
#!
#!  Per-instance refresh ROUTINE: reload the bars (re-evaluating any variable
#!  values) and redraw. Call it (e.g. DO Refresh:Graph1) after data changes.
#AT(%ProcedureRoutines),WHERE(%gbWDisable=0 AND %gbWImage)
Refresh:%gbWObject ROUTINE
#INSERT(%gbWEmitBars)
    %gbWObject.Draw(%Window, %gbWImage)
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - graficaBarraReport (REPORT)  -  vector primitives
#!#############################################################################
#!  Draws with BOX/LINE/SHOW straight into the band under SETTARGET(Report) -
#!  the graph reaches the PDF as vector primitives, NOT a bitmap, so the file
#!  stays as small as possible. The placeholder control only supplies the
#!  position/size (GETPOSITION) and is hidden so it never prints itself.
#!#############################################################################
#EXTENSION(graficaBarraReport,'graficaBarra - Draw a bar graph on this REPORT'),PROCEDURE,REQ(graficaBarraGlobal),DESCRIPTION(' [BarGraph] ' & %gbRObject)
#SHEET
  #TAB('&General')
    #BOXED('Object &&  placeholder')
      #PROMPT('&Disable this graph',CHECK),%gbRDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%gbRObject,REQ,DEFAULT('RptGraph' & %ActiveTemplateInstance)
      #! a report needs FROM(%ReportControl,...) (corpus: blobsrv.tpw:20)
      #PROMPT('&Placeholder control (in the DETAIL band):',FROM(%ReportControl,%ReportControlType='IMAGE' OR %ReportControlType='BOX' OR %ReportControlType='REGION')),%gbRPlace,REQ,DEFAULT('')
      #PROMPT('&Hide the placeholder when printing',CHECK),%gbRHide,DEFAULT(1),AT(10)
      #PROMPT('&Title text:',@s64),%gbRTitle,DEFAULT('')
    #ENDBOXED
    #BOXED('Value scale')
      #PROMPT('&Automatic scale (nice round maximum from the data)',CHECK),%gbRAutoScale,DEFAULT(1),AT(10)
      #ENABLE(%gbRAutoScale=0)
        #PROMPT('&Minimum:',@n13.2),%gbRMin,DEFAULT(0)
        #PROMPT('Ma&ximum:',@n13.2),%gbRMax,DEFAULT(100)
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
  #TAB('&Look')
    #BOXED('Show')
      #PROMPT('Show bar &values',CHECK),%gbRShowValues,DEFAULT(1),AT(10)
      #PROMPT('Value &decimals:',SPIN(@n2,0,4,1)),%gbRValueDP,DEFAULT(0)
      #PROMPT('Show bar &labels',CHECK),%gbRShowLabels,DEFAULT(1),AT(10)
      #PROMPT('Show &scale (left axis numbers)',CHECK),%gbRShowScale,DEFAULT(1),AT(10)
      #PROMPT('Scale d&ecimals:',SPIN(@n2,0,4,1)),%gbRScaleDP,DEFAULT(0)
      #PROMPT('Show &gridlines',CHECK),%gbRShowGrid,DEFAULT(1),AT(10)
      #PROMPT('Scale/grid di&visions:',SPIN(@n3,1,20,1)),%gbRGridDivs,DEFAULT(5)
      #PROMPT('Gap between bars (%% of a slot):',SPIN(@n3,0,90,5)),%gbRGapPct,DEFAULT(30)
    #ENDBOXED
    #BOXED('Colors')
      #PROMPT('A&xis color:',COLOR),%gbRAxisColor,DEFAULT(002B2B2BH)
      #PROMPT('G&rid color:',COLOR),%gbRGridColor,DEFAULT(00E0E0E0H)
      #PROMPT('Te&xt color:',COLOR),%gbRTextColor,DEFAULT(002B2B2BH)
    #ENDBOXED
  #ENDTAB
  #TAB('&Bars')
    #DISPLAY('The bars, left to right. Value can be a literal number or a')
    #DISPLAY('field / expression evaluated for every record printed.')
    #DISPLAY('If the list is empty, six sample bars are drawn (self-test).')
    #BUTTON('Bars'),MULTI(%gbRBar,%gbRBarLabel),INLINE
      #PROMPT('&Label:',@s32),%gbRBarLabel,DEFAULT('')
      #PROMPT('Value is a &variable / expression',CHECK),%gbRBarIsExpr,DEFAULT(1),AT(10)
      #ENABLE(%gbRBarIsExpr=0)
        #PROMPT('&Value:',@n13.2),%gbRBarValue,DEFAULT(0)
      #ENDENABLE
      #ENABLE(%gbRBarIsExpr=1)
        #PROMPT('Value &field / expression:',@s255),%gbRBarField,REQ,DEFAULT('')
      #ENDENABLE
      #PROMPT('&Automatic color (professional palette)',CHECK),%gbRBarAutoColor,DEFAULT(1),AT(10)
      #ENABLE(%gbRBarAutoColor=0)
        #PROMPT('&Color:',COLOR),%gbRBarColor,DEFAULT(00B6752EH)
      #ENDENABLE
    #ENDBUTTON
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%gbRDisable=0 AND %gbRPlace)
%gbRObject           GraficaBarraClass
#ENDAT
#!
#AT(%BeforePrint),WHERE(%gbRDisable=0 AND %gbRPlace)
  %gbRObject.Title = '%gbRTitle'
  %gbRObject.ShowValues = %gbRShowValues
  %gbRObject.ValueDP = %gbRValueDP
  %gbRObject.ShowLabels = %gbRShowLabels
  %gbRObject.ShowScale = %gbRShowScale
  %gbRObject.ScaleDP = %gbRScaleDP
  %gbRObject.ShowGrid = %gbRShowGrid
  %gbRObject.GridDivs = %gbRGridDivs
  %gbRObject.BarGapPct = %gbRGapPct
  %gbRObject.AxisColor = %gbRAxisColor
  %gbRObject.GridColor = %gbRGridColor
  %gbRObject.TextColor = %gbRTextColor
#IF(%gbRAutoScale=0)
  %gbRObject.SetRange(%gbRMin, %gbRMax)
#ENDIF
  %gbRObject.ClearBars()
#FOR(%gbRBar)
#IF(%gbRBarIsExpr AND %gbRBarField='')
#!  skipped bar - expression mode with no value field
#ELSIF(%gbRBarIsExpr)
#IF(%gbRBarAutoColor)
  %gbRObject.AddBar('%gbRBarLabel', %gbRBarField)
#ELSE
  %gbRObject.AddBar('%gbRBarLabel', %gbRBarField, %gbRBarColor)
#ENDIF
#ELSE
#IF(%gbRBarAutoColor)
  %gbRObject.AddBar('%gbRBarLabel', %gbRBarValue)
#ELSE
  %gbRObject.AddBar('%gbRBarLabel', %gbRBarValue, %gbRBarColor)
#ENDIF
#ENDIF
#ENDFOR
#IF(ITEMS(%gbRBar)=0)
  %gbRObject.Demo()                                          ! no bars defined - sample data (self-test)
#ENDIF
  SETTARGET(%Report)                                         ! the band being printed is the draw target
  %gbRObject.Paint(%gbRPlace)                                ! vector BOX/LINE/SHOW into the band
#IF(%gbRHide)
  %gbRPlace{PROP:Hide} = 1                                   ! placeholder only supplied the rectangle - never prints
#ENDIF
  SETTARGET()
#ENDAT
#!#############################################################################
#!  GROUPS - shared code emitters for the WINDOW extension
#!#############################################################################
#GROUP(%gbWEmitConfig)
    %gbWObject.Title = '%gbWTitle'
    %gbWObject.ShowValues = %gbWShowValues
    %gbWObject.ValueDP = %gbWValueDP
    %gbWObject.ShowLabels = %gbWShowLabels
    %gbWObject.ShowScale = %gbWShowScale
    %gbWObject.ScaleDP = %gbWScaleDP
    %gbWObject.ShowGrid = %gbWShowGrid
    %gbWObject.GridDivs = %gbWGridDivs
    %gbWObject.BarGapPct = %gbWGapPct
#IF(%gbWUseBack)
    %gbWObject.BackColor = %gbWBackColor
#ENDIF
    %gbWObject.AxisColor = %gbWAxisColor
    %gbWObject.GridColor = %gbWGridColor
    %gbWObject.TextColor = %gbWTextColor
#IF(%gbWAutoScale=0)
    %gbWObject.SetRange(%gbWMin, %gbWMax)
#ENDIF
#!
#GROUP(%gbWEmitBars)
    %gbWObject.ClearBars()
#FOR(%gbWBar)
#IF(%gbWBarIsExpr AND %gbWBarField='')
#!  skipped bar - expression mode with no value field
#ELSIF(%gbWBarIsExpr)
#IF(%gbWBarAutoColor)
    %gbWObject.AddBar('%gbWBarLabel', %gbWBarField)
#ELSE
    %gbWObject.AddBar('%gbWBarLabel', %gbWBarField, %gbWBarColor)
#ENDIF
#ELSE
#IF(%gbWBarAutoColor)
    %gbWObject.AddBar('%gbWBarLabel', %gbWBarValue)
#ELSE
    %gbWObject.AddBar('%gbWBarLabel', %gbWBarValue, %gbWBarColor)
#ENDIF
#ENDIF
#ENDFOR
#IF(ITEMS(%gbWBar)=0)
    %gbWObject.Demo()                                        ! no bars defined - sample data (self-test)
#ENDIF
#!-----------------------------------------------------------------------------
#! End of graficaBarra template set
#!-----------------------------------------------------------------------------
