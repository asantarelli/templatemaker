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
BG:Scrolled          EQUATE(EVENT:User + 244)                 ! a grid scrollbar moved
BG:GwlStyle          EQUATE(-16)
BG:GwlWndProc        EQUATE(-4)
BG:HScrollStyle      EQUATE(00100000h)
BG:VScrollStyle      EQUATE(00200000h)
BG:FrameChanged      EQUATE(0020h)
BG:NoMove            EQUATE(0002h)
BG:NoSize            EQUATE(0001h)
BG:NoZOrder          EQUATE(0004h)
BG:ClipSiblings      EQUATE(04000000h)                        ! WS_CLIPSIBLINGS
BG:Visible           EQUATE(10000000h)                        ! WS_VISIBLE
BG:HwndTop           EQUATE(0)
BG:SbHorz            EQUATE(0)
BG:SbVert            EQUATE(1)
BG:WmHScroll         EQUATE(0114h)
BG:WmVScroll         EQUATE(0115h)
BG:SifRange          EQUATE(1)
BG:SifPage           EQUATE(2)
BG:SifPos            EQUATE(4)
BG:SifTrack          EQUATE(10h)
BG:WmMouseWheel      EQUATE(020Ah)
BG:WheelNotch        EQUATE(120)                              ! WHEEL_DELTA
BG:WheelCode         EQUATE(99)                               ! not one of Windows' scroll codes
BG:WheelLines        EQUATE(3)                                ! rows per notch, as everything else does
BG:ThumbPct          EQUATE(12)                               ! fallback when the count is unknown
BG:FontCode          EQUATE(98)                               ! Ctrl-wheel resized the type
BG:MkControl         EQUATE(0008h)
BG:WmLButtonDown     EQUATE(0201h)
BG:WmLButtonUp       EQUATE(0202h)
BG:MkLButton         EQUATE(0001h)
BG:DragSlop          EQUATE(3)                                ! pixels before a click becomes a drag
BG:VkLButton         EQUATE(1)
#ENDAT
#!
#!  The callback cannot hand anything to Clarion through POST, so what it saw
#!  is left here for the ACCEPT loop to pick up. Only one scrollbar can be
#!  moving at a time, so one set of variables is enough.
#AT(%GlobalData),WHERE(%bgGDisable=0)
BG:LastBar           LONG                                     ! 0 horizontal, 1 vertical
BG:LastCode          LONG                                     ! what the user did to it
BG:LastPos           LONG                                     ! and where the thumb ended up
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
d2g_TotalWidth(LONG h),LONG,NAME('_d2g_TotalWidth')
d2g_HitEdge(LONG h,LONG x),LONG,NAME('_d2g_HitEdge')
d2g_ColWidth(LONG h,LONG col),LONG,NAME('_d2g_ColWidth')
d2g_SetWidth(LONG h,LONG col,LONG width),NAME('_d2g_SetWidth')
d2g_HdrHeight(LONG h),LONG,NAME('_d2g_HdrHeight')
d2g_FromHwnd(LONG hwnd),LONG,NAME('_d2g_FromHwnd')
d2g_VBar(LONG h,LONG show,LONG pos,LONG pct),NAME('_d2g_VBar')
d2g_VHit(LONG h,LONG x,LONG y),LONG,NAME('_d2g_VHit')
d2g_VGrab(LONG h,LONG y),LONG,NAME('_d2g_VGrab')
d2g_VDrag(LONG h,LONG y,LONG grab),LONG,NAME('_d2g_VDrag')
d2g_FontSize(LONG h,LONG pt),LONG,PROC,NAME('_d2g_FontSize')
d2g_FontPt(LONG h),LONG,NAME('_d2g_FontPt')
d2g_RowNeed(LONG h),LONG,NAME('_d2g_RowNeed')
d2g_SortMark(LONG h,LONG col,LONG dir),NAME('_d2g_SortMark')
d2g_Lines(LONG h,LONG n),NAME('_d2g_Lines')
d2g_Wrap(LONG h,LONG on,LONG lines),NAME('_d2g_Wrap')
d2g_Groups(LONG h,LONG n),NAME('_d2g_Groups')
d2g_Group(LONG h,LONG gi,LONG x,LONG width,*CSTRING title),RAW,NAME('_d2g_Group')
d2g_ColumnAt(LONG h,LONG col,LONG grp,LONG line,LONG x,LONG width,LONG align),NAME('_d2g_ColumnAt')
d2g_ViewWidth(LONG h),LONG,NAME('_d2g_ViewWidth')
    END
BG_Rgb(LONG),ULONG
BG_BarProc(ULONG,ULONG,ULONG,LONG),LONG,PASCAL
BG_HookBars(LONG),BYTE,PROC
BG_DropBars(LONG),LONG,PROC
BG_SetBar(LONG,LONG,LONG,LONG,LONG)
BG_BarPos(LONG,LONG),LONG
    MODULE('win32')
bgApi_SetProp(ULONG hWnd,LONG lpString,LONG hData),LONG,PASCAL,PROC,NAME('SetPropA')
bgApi_GetProp(ULONG hWnd,LONG lpString),LONG,PASCAL,NAME('GetPropA')
bgApi_RemoveProp(ULONG hWnd,LONG lpString),LONG,PASCAL,PROC,NAME('RemovePropA')
bgApi_CallWndProc(LONG lpPrev,ULONG hWnd,ULONG wMsg,ULONG wParam,LONG lParam),LONG,PASCAL,NAME('CallWindowProcA')
bgApi_SetWindowLong(ULONG hWnd,LONG nIndex,LONG dwNewLong),LONG,PASCAL,PROC,NAME('SetWindowLongA')
bgApi_GetWindowLong(ULONG hWnd,LONG nIndex),LONG,PASCAL,NAME('GetWindowLongA')
bgApi_SetWindowPos(ULONG hWnd,LONG after,LONG x,LONG y,LONG cx,LONG cy,ULONG flags),LONG,PASCAL,PROC,NAME('SetWindowPos')
bgApi_SetScrollInfo(ULONG hWnd,LONG bar,LONG lpsi,LONG redraw),LONG,PASCAL,PROC,NAME('SetScrollInfo')
bgApi_GetScrollInfo(ULONG hWnd,LONG bar,LONG lpsi),LONG,PASCAL,PROC,NAME('GetScrollInfo')
bgApi_GetAsyncKeyState(LONG vKey),SHORT,PASCAL,NAME('GetAsyncKeyState')
bgApi_PostMessage(ULONG hWnd,ULONG msg,ULONG wParam,LONG lParam),LONG,PASCAL,PROC,NAME('PostMessageA')
    END
#ENDAT
#!
#AT(%ProgramProcedures),WHERE(%bgGDisable=0)
!  ---- scrollbars ---------------------------------------------------------
!  A REGION is not born with scrollbars, so the styles go on at run time and
!  the control is subclassed for the two scroll messages. The address of the
!  callback is taken HERE, in the module that defines it - taken in a member
!  module it is an import thunk, not the procedure.
BG_HookBars PROCEDURE(LONG pHwnd)
prop CSTRING('BrowseGridBarProc')
old  LONG,AUTO
sty  LONG,AUTO
  CODE
  IF ~pHwnd THEN RETURN 0.
  IF bgApi_GetProp(pHwnd,ADDRESS(prop)) THEN RETURN 0.
!  Only the horizontal bar is Windows'. The vertical one is drawn by the grid,
!  because Windows' cannot be made to follow the data: it drags inside a
!  message loop of its own, and moving the browse needs records, which needs
!  ACCEPT, which that loop is holding up. Sideways needed nothing from the
!  browse so it could be done inside the loop; downwards cannot be.
  sty = bgApi_GetWindowLong(pHwnd,BG:GwlStyle)
  bgApi_SetWindowLong(pHwnd,BG:GwlStyle,BOR(sty,BG:HScrollStyle))
  bgApi_SetWindowPos(pHwnd,0,0,0,0,0,BOR(BOR(BOR(BG:FrameChanged,BG:NoMove),BG:NoSize),BG:NoZOrder))
  old = bgApi_SetWindowLong(pHwnd,BG:GwlWndProc,ADDRESS(BG_BarProc))
  IF ~old THEN RETURN 0.
  bgApi_SetProp(pHwnd,ADDRESS(prop),old)
  RETURN 1

BG_DropBars PROCEDURE(LONG pHwnd)
prop CSTRING('BrowseGridBarProc')
old  LONG,AUTO
  CODE
  IF ~pHwnd THEN RETURN 0.
  old = bgApi_GetProp(pHwnd,ADDRESS(prop))
  IF old
    bgApi_SetWindowLong(pHwnd,BG:GwlWndProc,old)
  END
  bgApi_RemoveProp(pHwnd,ADDRESS(prop))
  RETURN old

BG_SetBar PROCEDURE(LONG pHwnd,LONG pBar,LONG pPos,LONG pPage,LONG pTotal)
si   GROUP
cbSize  ULONG
fMask   ULONG
nMin    LONG
nMax    LONG
nPage   ULONG
nPos    LONG
nTrack  LONG
     END
  CODE
  IF ~pHwnd THEN RETURN.
  si.cbSize = SIZE(si)
  si.fMask  = BOR(BOR(BG:SifRange,BG:SifPage),BG:SifPos)
  si.nMin   = 0
  si.nMax   = pTotal - 1
  si.nPage  = pPage
  si.nPos   = pPos
  bgApi_SetScrollInfo(pHwnd,pBar,ADDRESS(si),1)

BG_BarPos PROCEDURE(LONG pHwnd,LONG pBar)
si   GROUP
cbSize  ULONG
fMask   ULONG
nMin    LONG
nMax    LONG
nPage   ULONG
nPos    LONG
nTrack  LONG
     END
  CODE
  IF ~pHwnd THEN RETURN 0.
  si.cbSize = SIZE(si)
  si.fMask  = BG:SifPos
  IF ~bgApi_GetScrollInfo(pHwnd,pBar,ADDRESS(si)) THEN RETURN 0.
  RETURN si.nPos

!  Windows does not work out the new position for a scroll message; this does,
!  writes it back, leaves what happened in the globals and tells the ACCEPT
!  loop. Horizontal scrolling is the grid's own business - it just slides the
!  columns. Vertical is the BROWSE's, so it is passed on rather than acted on.
BG_BarProc PROCEDURE(ULONG hWnd,ULONG wMsg,ULONG wParam,LONG lParam)
prop CSTRING('BrowseGridBarProc')
old  LONG,AUTO
g    LONG,AUTO
dz   LONG,AUTO
bar  LONG,AUTO
code LONG,AUTO
pos  LONG,AUTO
si   GROUP
cbSize  ULONG
fMask   ULONG
nMin    LONG
nMax    LONG
nPage   ULONG
nPos    LONG
nTrack  LONG
     END
  CODE
  old = bgApi_GetProp(hWnd,ADDRESS(prop))
!  The roller. Windows sends this to whatever is under the pointer, which is
!  the region - the LIST underneath is invisible and cannot be hit. There is no
!  modal loop involved here, so unlike a thumb drag it is enough to post: the
!  ACCEPT loop runs between notches and the browse fetches its records as it
!  always would.
  IF wMsg = BG:WmMouseWheel
    dz = BSHIFT(BAND(wParam,0FFFF0000h),-16)
    IF dz > 32767 THEN dz -= 65536.                           ! it is a SIGNED short up there
    IF dz
      IF BAND(wParam,BG:MkControl)
!  Ctrl and the roller: bigger and smaller type, the way every other program
!  does it. The rows grow with the font, so the browse is told to reload - it
!  fits a different number of records now.
        g = d2g_FromHwnd(hWnd)
        IF g
          d2g_FontSize(g,d2g_FontPt(g) + CHOOSE(dz > 0, 1, -1))
          d2g_PaintNow(g)
          BG:LastBar  = BG:SbVert
          BG:LastCode = BG:FontCode
          BG:LastPos  = 0
          POST(BG:Scrolled)
        END
      ELSE
        BG:LastBar  = BG:SbVert
        BG:LastCode = BG:WheelCode
        BG:LastPos  = dz
        POST(BG:Scrolled)
      END
    END
  END
  IF wMsg = BG:WmHScroll OR wMsg = BG:WmVScroll
    bar = CHOOSE(wMsg = BG:WmHScroll, BG:SbHorz, BG:SbVert)
    code = BAND(wParam,0FFFFh)
    si.cbSize = SIZE(si)
    si.fMask  = BOR(BOR(BOR(BG:SifRange,BG:SifPage),BG:SifPos),BG:SifTrack)
    IF bgApi_GetScrollInfo(hWnd,bar,ADDRESS(si))
      pos = si.nPos
      CASE code
      OF 0
        pos -= INT(si.nPage / 8) + 1
      OF 1
        pos += INT(si.nPage / 8) + 1
      OF 2
        pos -= si.nPage
      OF 3
        pos += si.nPage
      OF 4
        pos = si.nTrack
      OF 5
        pos = si.nTrack
      OF 6
        pos = si.nMin
      OF 7
        pos = si.nMax
      END
      IF pos > si.nMax - si.nPage + 1 THEN pos = si.nMax - si.nPage + 1.
      IF pos < si.nMin THEN pos = si.nMin.
      IF bar = BG:SbHorz                                      ! ours: just move the columns
        si.fMask = BG:SifPos
        si.nPos  = pos
        bgApi_SetScrollInfo(hWnd,bar,ADDRESS(si),1)
!  AND MOVE THEM NOW, not on the next ACCEPT. Dragging a scrollbar thumb puts
!  Windows into a message loop of its OWN, and Clarion's ACCEPT does not get a
!  turn until the button comes back up - so anything POSTed from here just
!  queues, and the columns would not budge until you let go. Scrolling
!  sideways needs nothing from the browse though: it is the grid's own pixels.
!  So it is done right here, synchronously, and painted immediately rather than
!  invalidated - an invalidated window would not be repainted until the loop
!  ends either. Downwards is not like this: that one needs records, which only
!  the browse can fetch, so it still waits for the button.
        g = d2g_FromHwnd(hWnd)
        IF g
          d2g_ScrollX(g,pos)
          d2g_PaintNow(g)
        END
      END
      BG:LastBar  = bar
      BG:LastCode = code
      BG:LastPos  = pos
      POST(BG:Scrolled)
    END
  END
  IF old
    RETURN bgApi_CallWndProc(old,hWnd,wMsg,wParam,lParam)
  END
  RETURN 0

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
      #PROMPT('&Scrollbars on the grid',CHECK),%bgBars,DEFAULT(1),AT(10)
      #PROMPT('Let the user &resize columns by dragging',CHECK),%bgSizeable,DEFAULT(1),AT(10)
      #PROMPT('Hand a right-click back to the &browse popup',CHECK),%bgPopup,DEFAULT(1),AT(10)
      #PROMPT('Scroll with the mouse &wheel',CHECK),%bgWheel,DEFAULT(1),AT(10)
      #PROMPT('&Sort when a heading is clicked',CHECK),%bgSortHdr,DEFAULT(1),AT(10)
      #PROMPT('&Flatten a grouped or multi-line format',CHECK),%bgFlatten,DEFAULT(1),AT(10)
      #DISPLAY('A grouped browse puts several fields on each record, over more than one')
      #DISPLAY('line, under headings that span them. Flattened, every field becomes a')
      #DISPLAY('column of its own on a single line - so resizing, sorting and freezing')
      #DISPLAY('work per field, and the grid scrolls sideways instead of growing taller.')
      #DISPLAY('Untick it and the record is drawn the way the formatter lays it out:')
      #DISPLAY('the groups<39> headings span their fields and each record is as many lines')
      #DISPLAY('tall as the format makes it. Columns cannot be resized by dragging in')
      #DISPLAY('that mode - the fields inside the group would have to move as well.')
      #DISPLAY('Passes the click to the browse, so it sorts by whatever rule the browse')
      #DISPLAY('was already given. A browse with no sort headers will simply ignore it.')
      #PROMPT('F&ile the browse reads (sizes the scrollbar thumb):',@s64),%bgFile,DEFAULT(%Primary)
      #DISPLAY('RECORDS() reads the count from the file header, so the thumb can be')
      #DISPLAY('sized honestly: a page against the whole file. Leave it blank and the')
      #DISPLAY('thumb is a fixed size. A filtered or range-limited browse will read')
      #DISPLAY('high, because the count is the file<39>s, not the view<39>s. This is a')
      #DISPLAY('plain label, not a file prompt - naming it here must not change what')
      #DISPLAY('the procedure is considered to use.')
      #DISPLAY('Sideways is the grid<39>s own. Downwards is passed to the browse,')
      #DISPLAY('so paging, locators and range limits behave as they always did.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Look')
    #BOXED('Type')
      #PROMPT('&Font:',@s32),%bgFont,DEFAULT('Segoe UI')
      #PROMPT('&Size (points):',SPIN(@n3,6,24,1)),%bgSize,DEFAULT(9)
      #PROMPT('&Wrap text that is too long for its column',CHECK),%bgWrap,DEFAULT(0),AT(10)
      #ENABLE(%bgWrap)
        #PROMPT('  &Lines a cell may use:',SPIN(@n1,2,4,1)),%bgWrapLines,DEFAULT(2)
      #ENDENABLE
      #DISPLAY('Every row is that many lines tall, whether its text needs them or not.')
      #DISPLAY('Rows of differing heights would take the page size, the hit testing and')
      #DISPLAY('the scrolling with them, and none of those want to know that one')
      #DISPLAY('particular address happened to be long.')
      #PROMPT('&Row height (pixels, 0 = follow the browse):',SPIN(@n3,0,80,1)),%bgRowH,DEFAULT(0)
      #DISPLAY('Left at 0 the grid draws to the LIST<39>s own line height, so the browse')
      #DISPLAY('loads exactly as many records as there is room to draw. Set it and the')
      #DISPLAY('LIST is given the same height, so the two still agree.')
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
BG:Resized:%bgObject EQUATE(EVENT:User + 240 + %ActiveTemplateInstance)
BG:Popup:%bgObject   EQUATE(EVENT:User + 200 + %ActiveTemplateInstance)
BG:Cover:%bgObject   EQUATE(EVENT:User + 160 + %ActiveTemplateInstance)
%bgObject:G          LONG                                    ! the grid, 0 = not running
%bgObject:Rgn        SIGNED                                  ! the region it is drawn on
%bgObject:Cols       LONG                                    ! how many columns came over
%bgObject:Fld        LONG,DIM(32)                            ! queue field behind each column
%bgObject:Pic        STRING(32),DIM(32)                       ! and its picture, if it has one
%bgObject:Face       CSTRING(33)
%bgObject:Cell       CSTRING(65)
%bgObject:Sel        LONG
%bgObject:Clipped    BYTE                                    ! has the LIST been made invisible?
%bgObject:Barred     BYTE                                    ! does it have scrollbars yet?
%bgObject:ScrollX    LONG                                    ! how far sideways the columns are
%bgObject:Col        LONG,DIM(32)                            ! LIST column behind each grid one
%bgObject:RzCol      LONG                                    ! column being dragged, 0 = none
%bgObject:RzX        LONG                                    ! where the drag started
%bgObject:RzW        LONG                                    ! and how wide the column was then
%bgObject:RzCur      BYTE                                    ! is the sizing cursor showing?
%bgObject:VDrag      BYTE                                    ! is the thumb being dragged?
%bgObject:VGrab      LONG                                    ! and where it was taken hold of
%bgObject:SortCol    LONG                                    ! heading just clicked, for BG:Sort
%bgObject:SortOn     LONG                                    ! LIST column the mark is on, 0 none
%bgObject:SortDir    LONG                                    ! 1 up, -1 down
%bgObject:RzArmed    BYTE                                    ! on an edge, but has it MOVED yet?
%bgObject:Lines      LONG                                    ! lines per record in the LIST's format
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
#IF(%bgBars OR %bgWheel)
  OF BG:Scrolled
    IF %bgObject:G AND %bgObject:Barred
      DO BG:Scroll:%bgObject
    END
#ENDIF
#IF(%bgPopup)
  OF BG:Popup:%bgObject
!  By now the SELECT has taken effect and the LIST really has the focus, so the
!  keystroke reaches it. Done in the same breath as the SELECT it would still
!  be sitting on the region.
!
!  Taking the focus is also what makes the LIST draw its own selected row, and
!  it draws it straight through the grid - at its own line height and its own
!  column widths, which is what makes it look like the row appears twice. So
!  the grid is put back over it BEFORE the menu opens, and again afterwards in
!  case the LIST repaints while the menu is up. PaintNow, not Repaint: an
!  invalidated window would not be redrawn until the menu closed.
    DO BG:Cover:%bgObject
    PRESSKEY(AppsKey)
    POST(BG:Cover:%bgObject)
  OF BG:Cover:%bgObject
    DO BG:Cover:%bgObject
#ENDIF
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
#IF(%bgPopup)
    OF EVENT:AlertKey
      IF KEYCODE() = MouseRightUp
        DO BG:Right:%bgObject
      END
#ENDIF
#IF(%bgSizeable)
    OF EVENT:MouseMove
      DO BG:Sizing:%bgObject
    OF EVENT:MouseUp
      DO BG:SizeEnd:%bgObject
#ENDIF
    END
  END
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'Kill','(),BYTE'),PRIORITY(2000),WHERE(%bgDisable=0 AND %bgList)
  DO BG:Reveal:%bgObject
  IF %bgObject:Barred
    BG_DropBars(%bgObject:Rgn{PROP:Handle})
    %bgObject:Barred = 0
  END
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
    HIDE(%bgObject:Rgn)                                       ! could not start: leave the LIST alone
    EXIT
  END
  DO BG:Columns:%bgObject
  DO BG:Conceal:%bgObject                                     ! only now the grid can be seen
!  The LIST is neither hidden nor moved: it stays exactly where it is, filling
!  its queue, counting its visible rows and holding the selection, and the
!  region sits on top of it. WS_CLIPSIBLINGS is what makes that stick - without
!  it the LIST paints over the grid whenever it redraws.
#IF(%bgWrap)
!  Before BG:Rows, which asks the engine how tall a row has to be - and with
!  wrapping on, that answer is several lines.
  d2g_Wrap(%bgObject:G,1,%bgWrapLines)
#ENDIF
  DO BG:Rows:%bgObject
#IF(%bgHdrH > 0)
  d2g_HeaderHeight(%bgObject:G,%bgHdrH)
#ENDIF
#IF(%bgBars OR %bgWheel)
  IF BG_HookBars(%bgObject:Rgn{PROP:Handle})                  ! the roller comes through here too
    %bgObject:Barred = 1
  END
#ENDIF
#IF(%bgPopup)
!  The region is on top, so it - not the LIST - is what a right-click lands on.
!  Alerting it here is what lets that click be handed back to the browse.
  %bgObject:Rgn{PROP:Alrt,250} = MouseRightUp
#ENDIF
  d2g_Frozen(%bgObject:G,%bgFrozen)
  d2g_Colours(%bgObject:G,BG_Rgb(%bgCBack),BG_Rgb(%bgCBand),                  |
              BG_Rgb(%bgCGrid),BG_Rgb(%bgCText),                               |
              BG_Rgb(%bgCHdrBack),BG_Rgb(%bgCHdrText),                         |
              BG_Rgb(%bgCSelBack),BG_Rgb(%bgCSelText))
  DO BG:Fill:%bgObject

BG:Place:%bgObject ROUTINE
!  Sit the region exactly on the LIST and keep it on top. The LIST is not moved
!  and not hidden: it is left where the resizer wants it, doing everything it
!  did before, and WS_CLIPSIBLINGS stops it painting into the region's
!  rectangle. Moving it instead fought the resizer, which works out every
!  control's place from the design layout and put it back over the grid.
  DATA
x  SIGNED,AUTO
y  SIGNED,AUTO
w  SIGNED,AUTO
h  SIGNED,AUTO
sty LONG,AUTO
  CODE
  IF ~%bgObject:Rgn THEN EXIT.
  GETPOSITION(%bgList,x,y,w,h)
  SETPOSITION(%bgObject:Rgn,x,y,w,h)
  IF %bgObject:G
    DO BG:Conceal:%bgObject                                   ! a resize can bring it back
  END
!  and raise the region above it, every time, because a resize can restack them
  bgApi_SetWindowPos(%bgObject:Rgn{PROP:Handle},BG:HwndTop,0,0,0,0,             |
                     BOR(BG:NoMove,BG:NoSize))

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
grp   LONG,AUTO
lines LONG,AUTO
head  CSTRING(65)
ghead CSTRING(65)
  CODE
  n = 0
  lines = 1
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
!  A column inside a GROUP usually carries no heading of its own - the group's
!  heading stands over the whole set of them. Adding PROPLIST:Group to any of
!  these properties reads the GROUP's version of it, which is where the words
!  in the formatter's top row actually live. Flattened, each field becomes a
!  column of its own, so it needs a heading of its own: its own if it has one,
!  the group's if it has not.
    head = CLIP(%bgList{PROPLIST:Header,c})
    grp  = %bgList{PROPLIST:GroupNo,c}
    IF grp
      ghead = CLIP(%bgList{PROPLIST:Header + PROPLIST:Group,c})
      IF ~head
        head = ghead
      ELSIF ghead AND UPPER(ghead) <> UPPER(head)
        head = CLIP(ghead) & ' ' & CLIP(head)                 ! "Address City", not just "City"
      END
!  LastOnLine is where the format wraps onto the next line of the row. Counting
!  them is how a multi-line browse is recognised at all.
      IF %bgList{PROPLIST:LastOnLine,c} THEN lines += 1.
    END
    LOOP p = 1 TO LEN(head)                                   ! a bar wraps a heading on screen
      IF head[p] = '|' THEN head[p] = ' '.
    END
    head = CLIP(LEFT(head))
    %bgObject:Fld[n + 1] = fld
    %bgObject:Col[n + 1] = c                                  ! so a resize can be written back
    %bgObject:Pic[n + 1] = CLIP(%bgList{PROPLIST:Picture,c})
    d2g_Column(%bgObject:G,n,wid * 2,algn,head)               ! LIST widths are dialog units
    n += 1
  END
  %bgObject:Cols = n
  %bgObject:Lines = lines                                     ! 1 = an ordinary flat browse
  d2g_Columns(%bgObject:G,n)
#IF(%bgFlatten = 0)
  IF lines > 1
    DO BG:Groups:%bgObject                                    ! place them where the format does
  END
#ENDIF

BG:Groups:%bgObject ROUTINE
!  Lay the record out the way the List Box Formatter does: fields sit inside
!  groups, several to a line, and the group's heading spans the lot. Three
!  things say how:
!
!    PROPLIST:GroupNo     which group a column is in
!    PROPLIST:LastOnLine  where the record wraps onto its next line
!    PROPLIST:Group       ADDED to any other property, reads the GROUP's one -
!                         which is where the heading and the overall width live
!
!  A column with no group is a group of its own, one field on one line, which
!  is how an ordinary browse falls out of the same code.
#IF(%bgFlatten = 0)
  DATA
c    LONG,AUTO
n    LONG,AUTO
g    LONG,AUTO
ex   LONG,AUTO
fld  LONG,AUTO
wid  LONG,AUTO
algn LONG,AUTO
p    LONG,AUTO
grp  LONG,AUTO
prev LONG,AUTO
gx   LONG,AUTO
gw   LONG,AUTO
ln   LONG,AUTO
xo   LONG,AUTO
mx   LONG,AUTO
head CSTRING(65)
  CODE
  n    = 0
  g    = -1
  prev = -9999
  gx   = 0
  mx   = 1
  LOOP c = 1 TO 512
    ex = %bgList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
    fld = %bgList{PROPLIST:FieldNo,c}
    IF ~fld THEN CYCLE.
    wid = %bgList{PROPLIST:Width,c}
    IF wid < 1 THEN CYCLE.
    IF n >= 32 THEN BREAK.
    grp = %bgList{PROPLIST:GroupNo,c}
    IF grp <> prev OR ~grp                                    ! a new group starts here
      IF g >= 0 THEN gx += gw.
      g += 1
      prev = grp
      ln = 0
      xo = 0
      IF grp
        gw   = %bgList{PROPLIST:Width + PROPLIST:Group,c} * 2
        head = CLIP(%bgList{PROPLIST:Header + PROPLIST:Group,c})
      ELSE
        gw   = wid * 2                                        ! ungrouped: a group of one
        head = CLIP(%bgList{PROPLIST:Header,c})
      END
      LOOP p = 1 TO LEN(head)
        IF head[p] = '|' THEN head[p] = ' '.
      END
      head = CLIP(LEFT(head))
      d2g_Group(%bgObject:G,g,gx,gw,head)
    END
    algn = 0
    p = %bgList{PROPLIST:Right,c}
    IF p THEN algn = 1.
    p = %bgList{PROPLIST:Decimal,c}
    IF p THEN algn = 1.
    p = %bgList{PROPLIST:Center,c}
    IF p THEN algn = 2.
    d2g_ColumnAt(%bgObject:G,n,g,ln,gx + xo,wid * 2,algn)
    xo += wid * 2
    IF grp AND %bgList{PROPLIST:LastOnLine,c}                 ! the record wraps here
      ln += 1
      xo = 0
      IF ln + 1 > mx THEN mx = ln + 1.
    END
    n += 1
  END
  IF g >= 0
    d2g_Groups(%bgObject:G,g + 1)
    d2g_Lines(%bgObject:G,mx)
  END
#ELSE
  EXIT
#ENDIF

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
mx LONG,AUTO
my LONG,AUTO
col LONG,AUTO
row LONG,AUTO
  CODE
  IF ~%bgObject:G THEN EXIT.
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  GETPOSITION(%bgObject:Rgn,rx,ry,rw,rh)
  mx = MOUSEX() - rx
  my = MOUSEY() - ry
  row = d2g_HitRow(%bgObject:G,my)
  0{PROP:Pixels} = sp
!  The scrollbar first: it is drawn over everything else, so it is clicked
!  before everything else.
  CASE d2g_VHit(%bgObject:G,mx,my)
  OF 1
    %bgObject:VDrag = 1
    %bgObject:VGrab = d2g_VGrab(%bgObject:G,my)               ! anchored, so it cannot jump
    EXIT
  OF 2
    POST(EVENT:PageUp,%bgList)
    EXIT
  OF 3
    POST(EVENT:PageDown,%bgList)
    EXIT
  END
!  A heading. On the edge of a column that is a resize; anywhere else it is a
!  request to sort by that column. Either way it never changes the selection.
  IF my < d2g_HdrHeight(%bgObject:G)
#IF(%bgSortHdr)
    %bgObject:SortCol = d2g_HitCol(%bgObject:G,mx)            ! remember it either way
#ENDIF
#IF(%bgSizeable)
    col = d2g_HitEdge(%bgObject:G,mx)
    IF col >= 0
!  Near an edge - but a click and a drag both start here, and until the mouse
!  MOVES there is no telling which this is. So the resize is only armed. Commit
!  it on the first click and a narrow column can never be sorted at all: the
!  grab margin reaches four pixels either side of every boundary, so a narrow
!  heading is almost entirely edge, and every click on it was being swallowed
!  by a resize that then went nowhere.
      %bgObject:RzCol   = col + 1                             ! 1-based: 0 means nothing is being dragged
      %bgObject:RzX     = mx
      %bgObject:RzW     = d2g_ColWidth(%bgObject:G,col)
      %bgObject:RzArmed = 1
      EXIT
    END
#ENDIF
#IF(%bgSortHdr)
    IF %bgObject:SortCol >= 0
      DO BG:Sort:%bgObject
    END
#ENDIF
    EXIT
  END
  IF row < 0 OR row >= RECORDS(%bgQueue) THEN EXIT.
  %bgList{PROP:Selected} = row + 1
  POST(EVENT:NewSelection,%bgList)                            ! let the browse react as usual
!  Give the focus to the BROWSE, not to the region. The LIST is invisible to
!  Windows but perfectly alive to Clarion, so with the focus on it every key an
!  ABC browse has always answered goes on working, unchanged and unwritten by
!  us: up and down arrows, PageUp and PageDown, Ctrl-PageUp and Ctrl-PageDown
!  for the two ends, the incremental locator, Insert, Delete and Enter. The
!  region only ever needed the mouse, and a REGION with PROP:IMM gets that
!  whether it has the focus or not.
  SELECT(%bgList)
  %bgObject:Sel = row
  d2g_Select(%bgObject:G,row)
  d2g_Repaint(%bgObject:G)

BG:Rows:%bgObject ROUTINE
!  Make the grid and the browse agree on how tall a row is, because otherwise
!  they never agree on how long a PAGE is. ABC works out how many records to
!  load from the LIST's height and its line height; the grid works out how many
!  it can draw from the region's height and its row height. Let those differ
!  and the browse loads records the grid has no room for - they end up below
!  the visible area, and the last of them cannot be seen at all.
!
!  PROP:LineHeight answers in whatever PROP:Pixels is currently set to - 8
!  units, 16 pixels, measured in examples/BrowseGrid/lineh.clw - so it is read
!  in pixels, which is what the grid works in.
  DATA
sp   LONG,AUTO
lh   LONG,AUTO
need LONG,AUTO
  CODE
  IF ~%bgObject:G THEN EXIT.
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
!  Whatever height is wanted, it can never be less than the type needs - that
!  is what made big rows come out short. The engine clamps it too, but the
!  clamped value is what has to go back to the LIST, or the browse still loads
!  to a height nothing is drawn at.
  need = d2g_RowNeed(%bgObject:G)
  IF %bgObject:Lines > 1 THEN need = need * %bgObject:Lines.  ! a record is that many lines tall
#IF(%bgRowH > 0)
!  A row height was asked for, so the BROWSE is the one that gives way.
  lh = %bgRowH
#ELSE
!  Nothing was asked for: take the browse's own line height...
  lh = %bgList{PROP:LineHeight}
#ENDIF
  IF lh < need THEN lh = need.                                ! ...but never squash the type
  d2g_RowHeight(%bgObject:G,lh)
  %bgList{PROP:LineHeight} = lh                               ! and both sides agree on it
  0{PROP:Pixels} = sp

BG:Conceal:%bgObject ROUTINE
!  Take WS_VISIBLE off the LIST at the WINDOWS level. Not HIDE(): ABC works out
!  how many rows to load from the control's own state, and a hidden browse
!  decides it has none - that was the very first bug this template had. But
!  WS_VISIBLE is Windows' flag, not Clarion's. Strip it and Windows stops
!  painting and hit-testing the control, while PROP:Hide, the queue, the
!  visible-row count and everything else ABC reads are untouched. Proved in
!  examples/BrowseGrid/novis.clw: winvis 1>0, PROP:Hide 0>0, recs 20.
!
!  This replaces WS_CLIPSIBLINGS, which was never enough. The two controls
!  really are siblings - the same harness reports sameparent 1 - so the LIST
!  was painting by some route that ignores the clip, and it did it every time
!  it had any reason to redraw: on being given a new column width, on taking
!  the focus for the popup. A window Windows will not paint cannot do that.
  DATA
sty LONG,AUTO
  CODE
  sty = bgApi_GetWindowLong(%bgList{PROP:Handle},BG:GwlStyle)
  IF BAND(sty,BG:Visible)
    bgApi_SetWindowLong(%bgList{PROP:Handle},BG:GwlStyle,                       |
                        BAND(sty,BXOR(0FFFFFFFFh,BG:Visible)))
    bgApi_SetWindowPos(%bgList{PROP:Handle},0,0,0,0,0,                          |
                       BOR(BOR(BG:FrameChanged,BG:NoMove),BOR(BG:NoSize,BG:NoZOrder)))
    %bgObject:Clipped = 1
  END

BG:Reveal:%bgObject ROUTINE
!  ...and give it back, so a window that gives up on the grid still has a
!  working browse to show.
  DATA
sty LONG,AUTO
  CODE
  IF ~%bgObject:Clipped THEN EXIT.
  sty = bgApi_GetWindowLong(%bgList{PROP:Handle},BG:GwlStyle)
  bgApi_SetWindowLong(%bgList{PROP:Handle},BG:GwlStyle,BOR(sty,BG:Visible))
  bgApi_SetWindowPos(%bgList{PROP:Handle},0,0,0,0,0,                            |
                     BOR(BOR(BG:FrameChanged,BG:NoMove),BOR(BG:NoSize,BG:NoZOrder)))
  %bgObject:Clipped = 0

BG:Mark:%bgObject ROUTINE
!  Where ABC will say which column it sorted by, believe it rather than our own
!  memory of what was clicked - a sort can be changed by a tab, a button or the
!  browse's own code, none of which come through us. PROPLIST:SortColumn is
!  only kept when the browse was given sort colours, so when it says nothing
!  the mark stays where the last click put it.
#IF(%bgSortHdr)
  DATA
sc LONG,AUTO
i  LONG,AUTO
  CODE
  sc = %bgList{PROPLIST:SortColumn}
  IF ~sc OR sc = %bgObject:SortOn THEN EXIT.
  %bgObject:SortOn = sc
  LOOP i = 1 TO %bgObject:Cols                                ! back to a GRID column
    IF %bgObject:Col[i] = sc
      d2g_SortMark(%bgObject:G,i - 1,%bgObject:SortDir)
      EXIT
    END
  END
  d2g_SortMark(%bgObject:G,-1,1)                              ! sorted on a column we do not draw
#ELSE
  EXIT
#ENDIF

BG:Sort:%bgObject ROUTINE
!  Sort by the column that was clicked, exactly as clicking the LIST's own
!  heading would. ABC's sort-header class reads PROPLIST:MouseDownField to find
!  out which column was pressed (brwext.clw:2926) - and that property can simply
!  be WRITTEN. So it is set and EVENT:HeaderPressed posted, and there is no
!  geometry in it at all.
!
!  It used to post a fake mouse click at the heading's x instead, which is why
!  a column could not be sorted until it had been resized once.
!  examples/BrowseGrid/mdfield.clw shows why: a posted click on a LIST that
!  Windows will not paint raises no header press whatever - "HeaderPressed n1"
!  counts the written one only, not the clicked one - while writing the field
!  and posting the event works on the concealed control every time.
#IF(%bgSortHdr)
  DATA
lc LONG,AUTO
  CODE
  lc = %bgObject:Col[%bgObject:SortCol + 1]                   ! which LIST column that was
  IF ~lc THEN EXIT.
!  Which way round the arrow points. ABC toggles on a second click of the same
!  heading, so the same rule is kept here. It is only a mark: if the browse
!  refuses the sort - not a valid field, or descending not allowed - the arrow
!  is corrected on the next fill, where PROPLIST:SortColumn is read back.
  IF %bgObject:SortOn = lc
    %bgObject:SortDir = -%bgObject:SortDir
  ELSE
    %bgObject:SortOn  = lc
    %bgObject:SortDir = 1
  END
  d2g_SortMark(%bgObject:G,%bgObject:SortCol,%bgObject:SortDir)
  %bgList{PROPLIST:MouseDownField} = lc
  POST(EVENT:HeaderPressed,%bgList)
#ELSE
  EXIT
#ENDIF

BG:Cover:%bgObject ROUTINE
!  Put the grid back over the LIST and draw it THIS INSTANT. Wanted any time
!  the LIST has had a reason to paint itself - taking the focus, being given a
!  new column width - because the clip style stops it owning the region's
!  pixels but does not stop it drawing into them.
#IF(%bgPopup)
  IF ~%bgObject:G THEN EXIT.
  DO BG:Place:%bgObject
  d2g_Resize(%bgObject:G)
  d2g_PaintNow(%bgObject:G)
#ELSE
  EXIT
#ENDIF

BG:Right:%bgObject ROUTINE
!  Hand a right-click back to the browse. NOT by forwarding the click itself:
!  the grid's rows and the LIST's rows are not the same height, so the same
!  y would pick a different record. The row is worked out in the grid's own
!  geometry, the LIST is told to select it, and then the browse is sent
!  AppsKey - "show the menu for what is selected", which needs no coordinates
!  at all. ABC alerts AppsKey on the list alongside MouseRightUp and treats
!  the two identically, so Insert/Change/Delete behave exactly as they always
!  did, popup formatter and all.
#IF(%bgPopup)
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
  IF row >= 0 AND row < RECORDS(%bgQueue)                     ! on a row: take it with us
    %bgList{PROP:Selected} = row + 1
    %bgObject:Sel = row
    d2g_Select(%bgObject:G,row)
    d2g_Repaint(%bgObject:G)
  END
  SELECT(%bgList)
  POST(BG:Popup:%bgObject)
#ELSE
  EXIT
#ENDIF

BG:Sizing:%bgObject ROUTINE
!  Two jobs on one event. Dragging: widen or narrow the column under the
!  pointer, measured from where the drag STARTED rather than from the last
!  event - deltas lose their remainder and the column creeps away from the
!  pointer. Not dragging: show the sizing cursor when the edge is grabbable, so
!  the user can see there is something there. Only when it CHANGES, or the
!  cursor is reset on every mouse move and flickers.
#IF(%bgSizeable)
  DATA
rx SIGNED,AUTO
ry SIGNED,AUTO
rw SIGNED,AUTO
rh SIGNED,AUTO
sp LONG,AUTO
mx LONG,AUTO
my LONG,AUTO
col LONG,AUTO
wid LONG,AUTO
vp  LONG,AUTO
  CODE
  IF ~%bgObject:G THEN EXIT.
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  GETPOSITION(%bgObject:Rgn,rx,ry,rw,rh)
  mx = MOUSEX() - rx
  my = MOUSEY() - ry
  0{PROP:Pixels} = sp
  IF %bgObject:VDrag
!  THIS is what Windows' own scrollbar could not do. There is no modal loop
!  here - it is an ordinary mouse move - so ACCEPT runs, the browse is told to
!  scroll exactly as its own thumb would tell it, and by the time the pointer
!  has moved again the records are on screen. The thumb follows the POINTER
!  while the drag is on rather than the browse, so it cannot stutter.
    IF bgApi_GetAsyncKeyState(BG:VkLButton) >= 0
      %bgObject:VDrag = 0
      EXIT
    END
    vp = d2g_VDrag(%bgObject:G,my,%bgObject:VGrab)
    d2g_VBar(%bgObject:G,1,vp,BG:ThumbPct)
    IF vp <> %bgList{PROP:VScrollPos}
      %bgList{PROP:VScrollPos} = vp
      POST(EVENT:ScrollDrag,%bgList)                          ! ABC fetches, Reset redraws
    ELSE
      d2g_Repaint(%bgObject:G)
    END
    EXIT
  END
  IF %bgObject:RzCol
!  Windows answers with the high bit set while the button is down, and a SHORT
!  is signed, so "still held" is simply "negative". Clarion has no MOUSEDOWN,
!  and the mouse can be released off the grid, where no MouseUp ever arrives.
    IF bgApi_GetAsyncKeyState(BG:VkLButton) >= 0

      DO BG:SizeEnd:%bgObject
      EXIT
    END
    IF %bgObject:RzArmed
      IF ABS(mx - %bgObject:RzX) < BG:DragSlop THEN EXIT.      ! still just a click
      %bgObject:RzArmed = 0                                    ! it has moved: a real drag
    END
    wid = %bgObject:RzW + mx - %bgObject:RzX
    IF wid < 16 THEN wid = 16.
    d2g_SetWidth(%bgObject:G,%bgObject:RzCol - 1,wid)
    DO BG:Bars:%bgObject                                      ! the columns are a different width now
    d2g_Repaint(%bgObject:G)
    EXIT
  END
  col = -1
  IF my < d2g_HdrHeight(%bgObject:G)
    col = d2g_HitEdge(%bgObject:G,mx)
  END
  IF col >= 0
    IF ~%bgObject:RzCur
      %bgObject:Rgn{PROP:Cursor} = CURSOR:SizeWE
      %bgObject:RzCur = 1
    END
  ELSIF %bgObject:RzCur
    %bgObject:Rgn{PROP:Cursor} = ''
    %bgObject:RzCur = 0
  END
#ELSE
  EXIT
#ENDIF

BG:SizeEnd:%bgObject ROUTINE
!  Put the new width back on the LIST as well. The browse goes on believing it
!  owns its own columns - anything that reads them, saves them or rebuilds the
!  grid from them then agrees with what is on screen.
#IF(%bgSizeable)
  DATA
c LONG,AUTO
  CODE
  %bgObject:VDrag = 0
  IF ~%bgObject:RzCol THEN EXIT.
  IF %bgObject:RzArmed
!  It never moved, so it was a click on the heading after all - and a click on
!  a heading sorts. Nothing has been resized, so there is no width to write.
    %bgObject:RzArmed = 0
    %bgObject:RzCol   = 0
#IF(%bgSortHdr)
    IF %bgObject:SortCol >= 0
      DO BG:Sort:%bgObject
    END
#ENDIF
    EXIT
  END
  c = %bgObject:Col[%bgObject:RzCol]
  IF c
    %bgList{PROPLIST:Width,c} = d2g_ColWidth(%bgObject:G,%bgObject:RzCol - 1) / 2
!  Changing a LIST's format makes it redraw itself, and it comes back over the
!  grid when it does - the clip style and the stacking order both survive the
!  write, so it is the painting that gets through, not the ordering. Putting
!  the region back on top and repainting it undoes that in the same breath.
!  Nothing else in the drag touches the LIST, which is why it only ever
!  happened when the button came up.
    DO BG:Place:%bgObject
    d2g_Resize(%bgObject:G)
    d2g_PaintNow(%bgObject:G)
  END
  %bgObject:RzCol = 0
#ELSE
  EXIT
#ENDIF

BG:Fill:%bgObject ROUTINE
!  Push the browse's queue into the grid. This is every visible row and no
!  more, which is exactly what the queue holds - the grid is told nothing
!  about the file.
  DATA
i     LONG,AUTO
col   LONG,AUTO
rows  LONG,AUTO
fit   LONG,AUTO
first LONG,AUTO
sel   LONG,AUTO
total LONG,AUTO
  CODE
  IF ~%bgObject:G THEN EXIT.
  total = RECORDS(%bgQueue)
  fit   = d2g_PageSize(%bgObject:G) + 1
  sel   = CHOICE(%bgList)
  first = 0
  rows  = total
  IF fit > 0 AND total > fit
!  The grid cannot draw the whole queue. Its rows are taller than the LIST's
!  lines, so the browse has loaded more records than there is room for, and
!  drawing from the top simply throws the tail away. Start far enough down that
!  the SELECTED record is one of the ones drawn - at the bottom of the file ABC
!  selects the last entry, and without this it was never on screen, which is
!  what made Ctrl-PageDown look as though it had selected nothing. The top
!  never showed it: entry one is always drawn.
    rows = fit
    IF sel > fit
      first = sel - fit
      IF first > total - fit THEN first = total - fit.
      IF first < 0 THEN first = 0.
    END
  END
  d2g_Page(%bgObject:G,first,rows)
  LOOP i = 1 TO rows
    GET(%bgQueue,first + i)
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
#IF(%bgSortHdr)
  DO BG:Mark:%bgObject
#ENDIF
  d2g_Total(%bgObject:G,total)
  %bgObject:Sel = sel                                         ! the browse owns the selection
  d2g_Select(%bgObject:G,sel - 1)                             ! absolute, and now always in view
  DO BG:Bars:%bgObject
  d2g_Repaint(%bgObject:G)

BG:Scroll:%bgObject ROUTINE
!  Sideways is ours: slide the columns and repaint, nothing else changes.
!  Downwards is the browse's: it is told to scroll exactly as it would be by
!  its own scrollbar, and when it has refilled its queue ABC calls Reset, which
!  is where the grid picks the new page up. So paging, locators and range
!  limits keep behaving as they always did.
#IF(%bgBars OR %bgWheel)
  DATA
i  LONG,AUTO
n  LONG,AUTO
sp LONG,AUTO
  CODE
  IF BG:LastCode = BG:FontCode
!  The type changed size, so the rows did too - and this time the GRID is the
!  one that knows how tall they are. NOT BG:Rows, which reads the height off
!  the LIST: that would pull the rows straight back down to the old line
!  height, leaving big type crammed into short rows with its descenders cut
!  off. The height goes the other way here, from the grid to the LIST, so the
!  browse reloads to fit however many rows there is now room for.
!  NOT BG:Rows. That asks the LIST how tall a row should be - and the LIST's
!  line height is the number we ourselves pushed up the last time the type grew.
!  Asking it again just gets that number back, so the rows would ratchet up and
!  never come down. When the type changes size the GRID is the authority and the
!  LIST is told, never the other way round.
    sp = 0{PROP:Pixels}
    0{PROP:Pixels} = 1
    %bgList{PROP:LineHeight} = d2g_RowH(%bgObject:G)           ! whatever the font just made it
    0{PROP:Pixels} = sp
    DO BG:Fill:%bgObject
    EXIT
  END
  IF BG:LastCode = BG:WheelCode
!  One notch is three rows, the same as everywhere else in Windows. The browse
!  is asked to scroll exactly as its own scrollbar would ask it, so paging,
!  locators and range limits are none of our business.
    n = INT(ABS(BG:LastPos) / BG:WheelNotch) * BG:WheelLines
    IF n < 1 THEN n = 1.
    IF n > 30 THEN n = 30.                                    ! a flicked wheel is not a page jump
    LOOP i = 1 TO n
      IF BG:LastPos > 0
        POST(EVENT:ScrollUp,%bgList)
      ELSE
        POST(EVENT:ScrollDown,%bgList)
      END
    END
    EXIT
  END
  IF BG:LastBar = BG:SbHorz
    %bgObject:ScrollX = BG:LastPos
    d2g_ScrollX(%bgObject:G,%bgObject:ScrollX)
    d2g_Repaint(%bgObject:G)
    EXIT
  END
  CASE BG:LastCode
  OF 0
    POST(EVENT:ScrollUp,%bgList)
  OF 1
    POST(EVENT:ScrollDown,%bgList)
  OF 2
    POST(EVENT:PageUp,%bgList)
  OF 3
    POST(EVENT:PageDown,%bgList)
  OF 6
    POST(EVENT:ScrollTop,%bgList)
  OF 7
    POST(EVENT:ScrollBottom,%bgList)
  ELSE
    %bgList{PROP:VScrollPos} = BG:LastPos                     ! the thumb, dragged
    POST(EVENT:ScrollDrag,%bgList)
  END
#ELSE
  EXIT
#ENDIF

BG:Bars:%bgObject ROUTINE
!  Size both scrollbars from what is actually showing. Windows hides a bar
!  whose page covers its whole range, so the horizontal one appears only when
!  the columns are wider than the view, which is what anyone expects.
#IF(%bgBars)
  DATA
tot   LONG,AUTO
view  LONG,AUTO
pct   LONG,AUTO
fRecs LONG,AUTO
  CODE
  IF ~%bgObject:Barred THEN EXIT.
!  Sideways: the grid's own business - the total column width against the view.
  tot  = d2g_TotalWidth(%bgObject:G)
  view = d2g_ViewWidth(%bgObject:G)
  IF view < 1 THEN view = 1.
  IF tot <= view
    %bgObject:ScrollX = 0
    d2g_ScrollX(%bgObject:G,0)
    BG_SetBar(%bgObject:Rgn{PROP:Handle},BG:SbHorz,0,1,1)     ! nothing to scroll: no bar
  ELSE
    IF %bgObject:ScrollX > tot - view THEN %bgObject:ScrollX = tot - view.
    BG_SetBar(%bgObject:Rgn{PROP:Handle},BG:SbHorz,%bgObject:ScrollX,view,tot)
  END
!  Down: NOT ours. The browse knows where it is in the file and keeps that in
!  the LIST's own PROP:VScrollPos, nought to a hundred - the same approximate
!  position Clarion's own browse thumb shows, because on an ISAM file that is
!  the only answer there is.
!  Downwards, ABC gives us one number and only one: PROP:VScrollPos, nought to
!  a hundred. It is the same approximate position Clarion's own browse thumb
!  shows, because on an ISAM file that is the only answer there is - nothing
!  knows the record count without reading the whole file. So the thumb is a
!  fixed size and the position is ABC's.
!  ABC only keeps PROP:VScrollPos when the browse was given a thumb, and turns
!  the LIST's scrollbar off when it was not - and with it off, writing
!  PROP:VScrollPos is ignored, so every drag read back as nought and was taken
!  for "go to the top". Turning it on costs nothing: the LIST is invisible, so
!  this is a number we are borrowing, not a scrollbar anyone will see.
  %bgList{PROP:VScroll} = 1
  IF ~%bgObject:VDrag                                         ! not while it is being dragged
    pct = BG:ThumbPct
#IF(%bgFile)
!  How big the thumb should be is a question that CAN be answered honestly:
!  RECORDS() reads the count out of the file header, so it costs nothing. A
!  page against the whole file is what every other scrollbar in Windows means
!  by the size of its thumb.
    fRecs = RECORDS(%bgFile)
    IF fRecs > 0
      pct = 100 * RECORDS(%bgQueue) / fRecs
      IF pct < 4 THEN pct = 4.
      IF pct > 100 THEN pct = 100.
    END
#ENDIF
    d2g_VBar(%bgObject:G,CHOOSE(pct >= 100, 0, 1),%bgList{PROP:VScrollPos},pct)
  END
!  A scrollbar appearing or disappearing RESIZES the client area behind our
!  back - hide the horizontal one and the client grows by its height. Nothing
!  covers the strip it vacated until the render target is grown to match, so
!  what shows there is whatever is underneath, which is the old list. This does
!  nothing at all unless the client area really did change.
  d2g_Resize(%bgObject:G)
#ELSE
  EXIT
#ENDIF
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
