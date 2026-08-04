#TEMPLATE(BrowseGrid,'BrowseGrid - draw any browse with Direct2D - v1.0'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  BrowseGrid  -  a browse that does not look like 1995.
#!
#!  Drop it on a procedure that already has an ABC browse, point it at the
#!  LIST, and the LIST is hidden and a Direct2D grid drawn in its place:
#!  banded rows, a proper header, frozen columns, crisp DirectWrite text and
#!  any colours you like.
#!
#!  WHAT IT DOES NOT TOUCH. The browse. BrowseClass keeps the file, the sort
#!  order, the filter, the range limit and the locator, exactly as they are -
#!  this only replaces what the rows LOOK like. That is what makes it a drop-in
#!  rather than a rewrite, and it is why an existing browse keeps working if
#!  you disable the extension.
#!
#!  WHERE THE COLUMNS COME FROM. The LIST itself, at run time, through
#!  PROPLIST:Exists / FieldNo / Header / Width / Picture / Left / Right /
#!  Center / Decimal. So the widths, headings, pictures and alignment you
#!  already set in the window formatter carry straight over, and a column the
#!  user has resized or moved comes over as it now is - the same approach
#!  myExport uses to read any browse.
#!
#!  WHERE THE VALUES COME FROM. The browse's own QUEUE, read generically with
#!  WHAT(queue, fieldnumber) - so nothing here knows or cares what the file is.
#!
#!  REQUIRES d2grid.c on the redirection path (with the myImage files, if you
#!  have those). Direct2D and DirectWrite are part of Windows and are bound at
#!  run time, so there is no import library and nothing to ship.
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - BrowseGridGlobal
#!#############################################################################
#EXTENSION(BrowseGridGlobal,'BrowseGrid - Global (add once per application)'),APPLICATION,HLP('~BrowseGrid.htm')
#SHEET
  #TAB('&General')
    #BOXED('BrowseGrid')
      #DISPLAY('BrowseGrid - Version 1.0')
      #DISPLAY('Draws an ABC browse with Direct2D and DirectWrite instead of')
      #DISPLAY('the runtime LIST, without touching the browse underneath.')
      #DISPLAY('')
      #DISPLAY('REQUIRES d2grid.c on the redirection path.')
      #DISPLAY('Add this extension ONCE per application - and to EVERY app of')
      #DISPLAY('a multi-DLL set that carries a grid.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%bgGDisable,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#AT(%AfterGlobalIncludes),WHERE(%bgGDisable=0)
  PRAGMA('compile(d2grid.c)')                                 ! the grid, built by Clarion's own C compiler
#ENDAT
#!
#AT(%GlobalMap),WHERE(%bgGDisable=0)
#!  cdecl exports from C, so the Clarion name carries a leading underscore.
    MODULE('d2grid.c')
d2g_Available(),LONG,NAME('_d2g_Available')
d2g_Attach(LONG hwnd,*CSTRING face,LONG pt),LONG,RAW,NAME('_d2g_Attach')
d2g_Detach(LONG h),NAME('_d2g_Detach')
d2g_Columns(LONG h,LONG n),NAME('_d2g_Columns')
d2g_Column(LONG h,LONG col,LONG width,LONG align,*CSTRING title),RAW,NAME('_d2g_Column')
d2g_Frozen(LONG h,LONG n),NAME('_d2g_Frozen')
d2g_RowHeight(LONG h,LONG px),NAME('_d2g_RowHeight')
d2g_HeaderHeight(LONG h,LONG px),NAME('_d2g_HeaderHeight')
d2g_Total(LONG h,LONG n),NAME('_d2g_Total')
d2g_Select(LONG h,LONG row),NAME('_d2g_Select')
d2g_ScrollX(LONG h,LONG x),NAME('_d2g_ScrollX')
d2g_ScrollY(LONG h,LONG y),NAME('_d2g_ScrollY')
d2g_Colours(LONG h,ULONG back,ULONG band,ULONG grid,ULONG txt,ULONG hb,ULONG ht,ULONG sb,ULONG st),NAME('_d2g_Colours')
d2g_Page(LONG h,LONG firstRow,LONG rows),NAME('_d2g_Page')
d2g_Cell(LONG h,LONG visRow,LONG col,*CSTRING s),RAW,NAME('_d2g_Cell')
d2g_Repaint(LONG h),NAME('_d2g_Repaint')
d2g_PaintNow(LONG h),LONG,PROC,NAME('_d2g_PaintNow')
d2g_Resize(LONG h),LONG,PROC,NAME('_d2g_Resize')
d2g_PageSize(LONG h),LONG,NAME('_d2g_PageSize')
d2g_RowH(LONG h),LONG,NAME('_d2g_RowH')
d2g_HeaderH(LONG h),LONG,NAME('_d2g_HeaderH')
d2g_HitRow(LONG h,LONG y),LONG,NAME('_d2g_HitRow')
d2g_HitCol(LONG h,LONG x),LONG,NAME('_d2g_HitCol')
    END
BG_Rgb(LONG),ULONG
#ENDAT
#!
#AT(%ProgramProcedures),WHERE(%bgGDisable=0)
!  A Clarion COLOR is a BGR long; Direct2D wants 0xRRGGBB. One place, once.
BG_Rgb PROCEDURE(LONG pColor)
c LONG,AUTO
  CODE
  c = pColor
  IF c < 0 THEN c = 0FFFFFFh.                                 ! a system colour: use white
  RETURN BOR(BOR(BSHIFT(BAND(c,00000FFh),16),BAND(c,000FF00h)),                |
             BSHIFT(BAND(c,0FF0000h),-16))
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - BrowseGrid
#!#############################################################################
#EXTENSION(BrowseGrid,'BrowseGrid - draw this browse with Direct2D'),PROCEDURE,MULTI,REQ(BrowseGridGlobal),DESCRIPTION('[Grid] ' & %bgList),HLP('~BrowseGrid.htm')
#SHEET
  #TAB('&Browse')
    #BOXED('Which browse')
      #PROMPT('&Disable this grid',CHECK),%bgDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%bgObject,REQ,DEFAULT('Grid' & %ActiveTemplateInstance)
      #PROMPT('&LIST control to take over:',CONTROL),%bgList,REQ
      #PROMPT('Browse &queue:',@s64),%bgQueue,REQ,DEFAULT('Queue:Browse:1')
      #DISPLAY('The queue the LIST is FROM(). ABC calls the first one')
      #DISPLAY('Queue:Browse, the second Queue:Browse:2, and so on - look in')
      #DISPLAY('the generated source if you are not sure.')
    #ENDBOXED
    #BOXED('Columns')
      #DISPLAY('Taken from the LIST itself at run time: widths, headings,')
      #DISPLAY('pictures and alignment come over as they are, including any')
      #DISPLAY('the user has resized or reordered.')
      #PROMPT('&Frozen columns (stay put when scrolled sideways):',SPIN(@n2,0,8,1)),%bgFrozen,DEFAULT(0)
    #ENDBOXED
  #ENDTAB
  #TAB('&Look')
    #BOXED('Type')
      #PROMPT('&Font:',@s32),%bgFont,DEFAULT('Segoe UI')
      #PROMPT('&Size (points):',SPIN(@n3,6,24,1)),%bgSize,DEFAULT(9)
      #PROMPT('&Row height (pixels, 0 = from the font):',SPIN(@n3,0,80,1)),%bgRowH,DEFAULT(0)
      #PROMPT('&Header height (pixels, 0 = from the font):',SPIN(@n3,0,80,1)),%bgHdrH,DEFAULT(0)
    #ENDBOXED
    #BOXED('Colours')
      #PROMPT('&Background:',COLOR),%bgCBack,DEFAULT(00FFFFFFH)
      #PROMPT('&Banding (every other row):',COLOR),%bgCBand,DEFAULT(00FAF7F5H)
      #PROMPT('&Gridlines:',COLOR),%bgCGrid,DEFAULT(00EAE5E1H)
      #PROMPT('&Text:',COLOR),%bgCText,DEFAULT(0033291FH)
      #PROMPT('Header b&ackground:',COLOR),%bgCHdrBack,DEFAULT(004A3A2BH)
      #PROMPT('Header te&xt:',COLOR),%bgCHdrText,DEFAULT(00FFFFFFH)
      #PROMPT('&Selected row:',COLOR),%bgCSelBack,DEFAULT(00B56F2FH)
      #PROMPT('Selected te&xt:',COLOR),%bgCSelText,DEFAULT(00FFFFFFH)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%bgDisable=0 AND %bgList)
BG:Park              EQUATE(4000)                             ! how far off the window the LIST is parked
BG:Resized:%bgObject EQUATE(EVENT:User + 240 + %ActiveTemplateInstance)
%bgObject:G          LONG                                    ! the grid, 0 = not running
%bgObject:Rgn        SIGNED                                  ! the region it is drawn on
%bgObject:Cols       LONG                                    ! how many columns came over
%bgObject:Fld        LONG,DIM(32)                            ! queue field behind each column
%bgObject:Pic        STRING(32),DIM(32)                       ! and its picture, if it has one
%bgObject:Face       CSTRING(33)
%bgObject:Cell       CSTRING(65)
%bgObject:Sel        LONG
%bgObject:Parked     BYTE                                    ! is the LIST out of sight yet?
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'Init','(),BYTE'),PRIORITY(8800),WHERE(%bgDisable=0 AND %bgList)
  IF ReturnValue = Level:Benign
    DO BG:Setup:%bgObject
  END
#ENDAT
#!
#!  WHERE THE REFILL HANGS OFF. Not TakeEvent: that method returns the moment
#!  PARENT.TakeEvent() comes back, so code embedded after it is unreachable -
#!  it generates, it compiles, and it never runs. ABC calls Reset when the
#!  browse has refilled itself, and TakeNewSelection when the highlight moves,
#!  which between them cover scrolling, locating, filtering and editing.
#AT(%WindowManagerMethodCodeSection,'Reset','(BYTE Force=0)'),PRIORITY(8000),WHERE(%bgDisable=0 AND %bgList)
  IF %bgObject:G
    DO BG:Fill:%bgObject
  END
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeNewSelection','(),BYTE'),PRIORITY(8000),WHERE(%bgDisable=0 AND %bgList)
  IF %bgObject:G
    DO BG:Fill:%bgObject
  END
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%bgDisable=0 AND %bgList)
  CASE EVENT()
  OF EVENT:Sized
!  Do NOT move the region here. The window resizer is working on this same
!  event, and on this window it runs after us - so the LIST has not been given
!  its new size yet, and anything measured from it now is the old one. Posting
!  puts the move at the back of the queue, by which time the resizer has
!  finished and the LIST is the size it is going to be.
    POST(BG:Resized:%bgObject)
  OF BG:Resized:%bgObject
    IF %bgObject:G
      DO BG:Place:%bgObject                                   ! follow the LIST to its new size
      d2g_Resize(%bgObject:G)                                 ! and the render target with it
      DO BG:Fill:%bgObject                                    ! a taller browse holds more rows
    END
  END
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeFieldEvent','(),BYTE'),PRIORITY(2000),WHERE(%bgDisable=0 AND %bgList)
  IF FIELD() = %bgObject:Rgn AND %bgObject:G
    CASE EVENT()
    OF EVENT:MouseDown
      DO BG:Hit:%bgObject
    END
  END
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'Kill','(),BYTE'),PRIORITY(2000),WHERE(%bgDisable=0 AND %bgList)
  IF %bgObject:G
    d2g_Detach(%bgObject:G)
    %bgObject:G = 0
  END
#ENDAT
#!
#AT(%ProcedureRoutines),WHERE(%bgDisable=0 AND %bgList)
BG:Setup:%bgObject ROUTINE
!  Put a region exactly where the LIST is, hide the LIST, and hand the region
!  to the grid. The LIST stays in the window doing its job - it is simply not
!  the thing you look at any more, which is why the browse carries on working.
  DATA
x  SIGNED,AUTO
y  SIGNED,AUTO
w  SIGNED,AUTO
h  SIGNED,AUTO
  CODE
  IF ~d2g_Available() THEN EXIT.                              ! no Direct2D: leave the LIST alone
  IF ~%bgObject:Rgn
    %bgObject:Rgn = CREATE(0,CREATE:Region,%bgList{PROP:Parent})
    %bgObject:Rgn{PROP:IMM} = 1                               ! or no mouse events arrive
  END
  DO BG:Place:%bgObject
  UNHIDE(%bgObject:Rgn)
  %bgObject:Face = '%bgFont'
  %bgObject:G = d2g_Attach(%bgObject:Rgn{PROP:Handle},%bgObject:Face,%bgSize)
  IF ~%bgObject:G
    HIDE(%bgObject:Rgn)                                       ! could not start: the LIST shows through
    EXIT
  END
!  The LIST is PARKED, not hidden: BG:Place has moved it off past the edge of
!  the window at full size. It goes on filling its queue, counting its visible
!  rows and holding the selection exactly as it always did - Windows simply
!  clips it away. Hidden, the browse can decide it has nothing to show; left
!  where it was, it repaints over the grid the moment it is clicked.
#IF(%bgRowH > 0)
  d2g_RowHeight(%bgObject:G,%bgRowH)
#ENDIF
#IF(%bgHdrH > 0)
  d2g_HeaderHeight(%bgObject:G,%bgHdrH)
#ENDIF
  d2g_Frozen(%bgObject:G,%bgFrozen)
  d2g_Colours(%bgObject:G,BG_Rgb(%bgCBack),BG_Rgb(%bgCBand),                  |
              BG_Rgb(%bgCGrid),BG_Rgb(%bgCText),                               |
              BG_Rgb(%bgCHdrBack),BG_Rgb(%bgCHdrText),                         |
              BG_Rgb(%bgCSelBack),BG_Rgb(%bgCSelText))
  DO BG:Columns:%bgObject
  DO BG:Fill:%bgObject

BG:Place:%bgObject ROUTINE
!  Put the region where the LIST would be, and park the LIST the same distance
!  off to the left. The resizer goes on moving and sizing the LIST as it always
!  did; the region just follows it back by the parking distance, so it stays
!  exactly where the browse appears to be.
  DATA
x  SIGNED,AUTO
y  SIGNED,AUTO
w  SIGNED,AUTO
h  SIGNED,AUTO
  CODE
  IF ~%bgObject:Rgn THEN EXIT.
  GETPOSITION(%bgList,x,y,w,h)
  IF %bgObject:Parked
    SETPOSITION(%bgObject:Rgn,x + BG:Park,y,w,h)              ! it is already off to the left
  ELSE
    SETPOSITION(%bgObject:Rgn,x,y,w,h)
    SETPOSITION(%bgList,x - BG:Park,y,w,h)                    ! same size, out of sight
    %bgObject:Parked = 1
  END

BG:Columns:%bgObject ROUTINE
!  Read the columns off the LIST as they stand. Every PROPLIST read goes
!  through a LONG first: a property comes back as a STRING, and the STRING '0'
!  is logically TRUE, so a hidden column would otherwise look visible.
  DATA
c     LONG,AUTO
n     LONG,AUTO
ex    LONG,AUTO
fld   LONG,AUTO
wid   LONG,AUTO
algn  LONG,AUTO
p     LONG,AUTO
head  CSTRING(65)
  CODE
  n = 0
  LOOP c = 1 TO 512
    ex = %bgList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
    fld = %bgList{PROPLIST:FieldNo,c}
    IF ~fld THEN CYCLE.                                       ! a decoration, not a data column
    wid = %bgList{PROPLIST:Width,c}
    IF wid < 1 THEN CYCLE.                                    ! hidden
    IF n >= 32 THEN BREAK.
    algn = 0
    p = %bgList{PROPLIST:Right,c}
    IF p THEN algn = 1.
    p = %bgList{PROPLIST:Decimal,c}
    IF p THEN algn = 1.
    p = %bgList{PROPLIST:Center,c}
    IF p THEN algn = 2.
    head = CLIP(%bgList{PROPLIST:Header,c})
    LOOP p = 1 TO LEN(head)                                   ! a bar wraps a heading on screen
      IF head[p] = '|' THEN head[p] = ' '.
    END
    head = CLIP(LEFT(head))
    %bgObject:Fld[n + 1] = fld
    %bgObject:Pic[n + 1] = CLIP(%bgList{PROPLIST:Picture,c})
    d2g_Column(%bgObject:G,n,wid * 2,algn,head)               ! LIST widths are dialog units
    n += 1
  END
  %bgObject:Cols = n
  d2g_Columns(%bgObject:G,n)

BG:Hit:%bgObject ROUTINE
!  A click picks a row. The browse still owns the selection: it is told which
!  record was chosen and left to do the rest, so locators, range limits and
!  anything hanging off EVENT:NewSelection behave exactly as they always did.
!  MOUSEY answers in WINDOW units and the grid measures in pixels, hence the
!  switch - a window unit is half a pixel.
  DATA
rx SIGNED,AUTO
ry SIGNED,AUTO
rw SIGNED,AUTO
rh SIGNED,AUTO
sp LONG,AUTO
row LONG,AUTO
  CODE
  IF ~%bgObject:G THEN EXIT.
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  GETPOSITION(%bgObject:Rgn,rx,ry,rw,rh)
  row = d2g_HitRow(%bgObject:G,MOUSEY() - ry)
  0{PROP:Pixels} = sp
  IF row < 0 OR row >= RECORDS(%bgQueue) THEN EXIT.
  %bgList{PROP:Selected} = row + 1
  POST(EVENT:NewSelection,%bgList)                            ! let the browse react as usual
  SELECT(%bgObject:Rgn)                                       ! keep the focus off the parked LIST
  %bgObject:Sel = row
  d2g_Select(%bgObject:G,row)
  d2g_Repaint(%bgObject:G)

BG:Fill:%bgObject ROUTINE
!  Push the browse's queue into the grid. This is every visible row and no
!  more, which is exactly what the queue holds - the grid is told nothing
!  about the file.
  DATA
i    LONG,AUTO
col  LONG,AUTO
rows LONG,AUTO
fit  LONG,AUTO
  CODE
  IF ~%bgObject:G THEN EXIT.
  rows = RECORDS(%bgQueue)
  fit  = d2g_PageSize(%bgObject:G) + 1
  IF rows > fit THEN rows = fit.
  d2g_Page(%bgObject:G,0,rows)
  LOOP i = 1 TO rows
    GET(%bgQueue,i)
    IF ERRORCODE() THEN BREAK.
    LOOP col = 1 TO %bgObject:Cols
      IF %bgObject:Pic[col]
        %bgObject:Cell = CLIP(LEFT(FORMAT(WHAT(%bgQueue,%bgObject:Fld[col]), |
                                          CLIP(%bgObject:Pic[col]))))
      ELSE
        %bgObject:Cell = CLIP(LEFT(WHAT(%bgQueue,%bgObject:Fld[col])))
      END
      d2g_Cell(%bgObject:G,i - 1,col - 1,%bgObject:Cell)
    END
  END
  d2g_Total(%bgObject:G,rows)
  %bgObject:Sel = CHOICE(%bgList)                             ! the browse owns the selection
  d2g_Select(%bgObject:G,%bgObject:Sel - 1)
  d2g_Repaint(%bgObject:G)
#ENDAT
#!#############################################################################
#!  GROUPS
#!#############################################################################
#!-----------------------------------------------------------------------------
#!  A Clarion COLOR prompt is a BGR long; the grid wants 0xRRGGBB.
#!-----------------------------------------------------------------------------
#!-----------------------------------------------------------------------------
#!  End of BrowseGrid template set
#!-----------------------------------------------------------------------------
