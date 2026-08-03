

   MEMBER('airwin.clw')                                    ! This is a MEMBER module


   INCLUDE('ABTOOLBA.INC'),ONCE
   INCLUDE('ABWINDOW.INC'),ONCE

                     MAP
                       INCLUDE('AIRWIN001.INC'),ONCE        !Local module procedure declarations
                     END


!!! <summary>
!!! Generated from procedure template - Window
!!! Window
!!! </summary>
Main PROCEDURE 

Loc:Url              CSTRING(256)
Loc:B64              STRING(4096)
Loc:File             CSTRING(261)
QuickWindow          WINDOW('allImageRead test'),AT(,,340,300),RESIZE,GRAY,MAX,STATUS(-1),SYSTEM,IMM
                       IMAGE,AT(8,8,320,130),USE(?Pic1)
                       IMAGE,AT(8,150,320,130),USE(?AirCanvas)
                     END

PicA                ImageClass                              ! the picture, exactly as it was read
PicA:Ref            &STRING                                 ! a BLOB, while it is being handed over
PicA:Sz             LONG                                    ! how many bytes that was
PicA:Path           CSTRING(261)                            ! what is on the canvas now
PicA:Frame          LONG(1)                                 ! which frame of a multi-frame picture
PicA:Cv             ImageClass                              ! the canvas: what the control is showing
PicA:Zoom           LONG                                    ! 0 = fit the frame, else per cent
PicA:PanX           LONG                                    ! the viewport, in picture pixels
PicA:PanY           LONG
PicA:Rgn            SIGNED                                  ! the region that takes the mouse
PicA:Hooked         BYTE                                    ! this canvas took the window procedure
PicA:Drag           BYTE
PicA:DragX          SIGNED
PicA:DragY          SIGNED
Air:Redraw:PicA     EQUATE(EVENT:User + 260 + 2)
PicB                ImageClass                              ! the picture, exactly as it was read
PicB:Ref            &STRING                                 ! a BLOB, while it is being handed over
PicB:Sz             LONG                                    ! how many bytes that was
PicB:Path           CSTRING(261)                            ! what is on the canvas now
PicB:Frame          LONG(1)                                 ! which frame of a multi-frame picture
PicB:Cv             ImageClass                              ! the canvas: what the control is showing
PicB:Zoom           LONG                                    ! 0 = fit the frame, else per cent
PicB:PanX           LONG                                    ! the viewport, in picture pixels
PicB:PanY           LONG
PicB:Rgn            SIGNED                                  ! the region that takes the mouse
PicB:Hooked         BYTE                                    ! this canvas took the window procedure
PicB:Drag           BYTE
PicB:DragX          SIGNED
PicB:DragY          SIGNED
Air:Redraw:PicB     EQUATE(EVENT:User + 220 + 1)
ThisWindow           CLASS(WindowManager)
Init                   PROCEDURE(),BYTE,PROC,DERIVED
Kill                   PROCEDURE(),BYTE,PROC,DERIVED
TakeFieldEvent         PROCEDURE(),BYTE,PROC,DERIVED
TakeWindowEvent        PROCEDURE(),BYTE,PROC,DERIVED
                     END

Toolbar              ToolbarClass

  CODE
  GlobalResponse = ThisWindow.Run()                        ! Opens the window and starts an Accept Loop

!---------------------------------------------------------------------------
DefineListboxStyle ROUTINE
!|
!| This routine create all the styles to be shared in this window
!| It`s called after the window open
!|
!---------------------------------------------------------------------------
Air:Setup:PicA ROUTINE
!  The IMAGE control is only the paint surface. A REGION created over it takes
!  the mouse - the way Clarion's own ActiveImage class does it
!  (libsrc\win\ActiveImage.clw:303). A REGION has nothing of its own to draw,
!  so the picture underneath shows through untouched.
  IF ~PicA:Rgn
    PicA:Rgn = CREATE(0,CREATE:Region,?Pic1{PROP:Parent})
  END
  DO Air:Place:PicA
  UNHIDE(PicA:Rgn)
!  Take the mouse wheel off the window procedure. The first canvas on a window
!  does it; the rest ride along, because the event reaches all of them.
  IF AirImg_HookWheel(QuickWindow{PROP:Handle})                   ! the helper takes the address,
    PicA:Hooked = 1                                       !   never this module
  END
  ?Pic1{PROP:DropID,1}     = '~FILE'                       ! a file dragged out of Explorer
  PicA:Rgn{PROP:DropID,1} = '~FILE'
  PicA:Rgn{PROP:Alrt,255} = MouseRight
  PicA:Rgn{PROP:Alrt,254} = MouseLeft2
  AirImg_LoadB64(PicA,Loc:B64,'Main_w2')
  PicA:Path = ''
  DO Air:Fresh:PicA
  POST(Air:Redraw:PicA)                                   ! first paint, once the window is up

Air:Place:PicA ROUTINE
!  Keep the region exactly over the image, however the resizer moves it.
  DATA
x  SIGNED,AUTO
y  SIGNED,AUTO
w  SIGNED,AUTO
h  SIGNED,AUTO
  CODE
  IF ~PicA:Rgn THEN EXIT.
  GETPOSITION(?Pic1,x,y,w,h)
  SETPOSITION(PicA:Rgn,x,y,w,h)

Air:Fresh:PicA ROUTINE
!  A NEW picture has just landed in the object.
  PicA:Zoom = 0                                           ! back to fitting the frame
  PicA:PanX = 0
  PicA:PanY = 0
  ?Pic1{PROP:Tooltip} = PicA:Path
  IF PicA.Ok()
    0{PROP:StatusText,1} = PicA.Describe()
  ELSE
    0{PROP:StatusText,1} = ''
  END

Air:Show:PicA ROUTINE
!  Paint what the object holds. At zoom 0 the class fits a copy to the control
!  for us; from there on the viewport is cut out here and blitted as it is.
  DATA
w      LONG,AUTO
h      LONG,AUTO
cw     LONG,AUTO
ch     LONG,AUTO
savePx LONG,AUTO
  CODE
  IF ~PicA.Ok()
    ?Pic1{PROP:Text} = ''
    DISPLAY(?Pic1)
    EXIT
  END
  IF ~PicA:Zoom
    PicA.Draw(QuickWindow,?Pic1,Img:Cover,PicA.ArgbOf(16777215))
    EXIT
  END
  savePx = 0{PROP:Pixels}                                     ! the frame, in real pixels
  0{PROP:Pixels} = 1
  w = ?Pic1{PROP:Width}
  h = ?Pic1{PROP:Height}
  0{PROP:Pixels} = savePx
  IF w < 4 OR h < 4 THEN EXIT.
  IF ~PicA.CloneInto(PicA:Cv) THEN EXIT.
  PicA:Cv.Zoom(PicA:Zoom,Img:Best)
  cw = w                                                      ! the viewport, never bigger than the picture
  ch = h
  IF cw > PicA:Cv.Wide() THEN cw = PicA:Cv.Wide().
  IF ch > PicA:Cv.High() THEN ch = PicA:Cv.High().
  IF PicA:PanX > PicA:Cv.Wide() - cw THEN PicA:PanX = PicA:Cv.Wide() - cw.
  IF PicA:PanY > PicA:Cv.High() - ch THEN PicA:PanY = PicA:Cv.High() - ch.
  IF PicA:PanX < 0 THEN PicA:PanX = 0.
  IF PicA:PanY < 0 THEN PicA:PanY = 0.
  PicA:Cv.Crop(PicA:PanX,PicA:PanY,cw,ch)
  PicA:Cv.Fit(w,h,Img:Centered,PicA.ArgbOf(16777215))  ! pad out to the frame
  PicA:Cv.Draw(QuickWindow,?Pic1,-1)                       ! -1 = blit it as it is

Air:In:PicA ROUTINE
!  Zoom about the middle of the viewport, so the picture does not run away.
!  The wheel event reaches every canvas on the window, so each one first asks
!  whether the pointer is actually over it.
  DATA
was    LONG,AUTO
now    LONG,AUTO
w      LONG,AUTO
h      LONG,AUTO
savePx LONG,AUTO
rx     SIGNED,AUTO
ry     SIGNED,AUTO
rw     SIGNED,AUTO
rh     SIGNED,AUTO
  CODE
  IF ~PicA.Ok() THEN EXIT.
  GETPOSITION(?Pic1,rx,ry,rw,rh)
  IF MOUSEX() < rx OR MOUSEX() > rx + rw THEN EXIT.
  IF MOUSEY() < ry OR MOUSEY() > ry + rh THEN EXIT.
  savePx = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  w = ?Pic1{PROP:Width}
  h = ?Pic1{PROP:Height}
  0{PROP:Pixels} = savePx
  was = PicA:Zoom
  IF ~was THEN was = AirImg_FitPct(PicA,w,h).
  now = was + 25
  IF now > 1600 THEN now = 1600.
  PicA:PanX = INT((PicA:PanX + w / 2) * now / was - w / 2)
  PicA:PanY = INT((PicA:PanY + h / 2) * now / was - h / 2)
  PicA:Zoom = now
  DO Air:Show:PicA

Air:Out:PicA ROUTINE
  DATA
was    LONG,AUTO
now    LONG,AUTO
w      LONG,AUTO
h      LONG,AUTO
savePx LONG,AUTO
rx     SIGNED,AUTO
ry     SIGNED,AUTO
rw     SIGNED,AUTO
rh     SIGNED,AUTO
  CODE
  IF ~PicA.Ok() OR ~PicA:Zoom THEN EXIT.               ! already fitted
  GETPOSITION(?Pic1,rx,ry,rw,rh)
  IF MOUSEX() < rx OR MOUSEX() > rx + rw THEN EXIT.
  IF MOUSEY() < ry OR MOUSEY() > ry + rh THEN EXIT.
  savePx = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  w = ?Pic1{PROP:Width}
  h = ?Pic1{PROP:Height}
  0{PROP:Pixels} = savePx
  was = PicA:Zoom
  now = was - 25
  IF now <= AirImg_FitPct(PicA,w,h)                        ! all the way out = fit the frame
    DO Air:Fit:PicA
    EXIT
  END
  PicA:PanX = INT((PicA:PanX + w / 2) * now / was - w / 2)
  PicA:PanY = INT((PicA:PanY + h / 2) * now / was - h / 2)
  PicA:Zoom = now
  DO Air:Show:PicA

Air:Fit:PicA ROUTINE
  PicA:Zoom = 0
  PicA:PanX = 0
  PicA:PanY = 0
  DO Air:Show:PicA

Air:Open:PicA ROUTINE
!  Whichever picture the user wants.
  DATA
pick CSTRING(261)
  CODE
  pick = PicA:Path
  IF ~FILEDIALOG('Open a picture',pick,AirImg_Filter(),FILE:KeepDir + FILE:LongName) THEN EXIT.
  PicA:Path = pick
  IF AirImg_LoadPath(PicA,PicA:Path)
    DO Air:Fresh:PicA
  END
  DO Air:Show:PicA

Air:Save:PicA ROUTINE
!  The format follows the name the user types: .png .jpg .gif .bmp .tif .tga
!  .pcx .ppm and .qoi are all written by the class.
  DATA
pick CSTRING(261)
  CODE
  IF ~PicA.Ok() THEN EXIT.
  pick = PicA:Path
  IF ~FILEDIALOG('Save a copy',pick,AirImg_Filter(),FILE:Save + FILE:KeepDir + FILE:LongName) THEN EXIT.
  IF ~PicA.SaveFile(pick)
    MESSAGE('That picture could not be written.||' & pick,'Save a copy',ICON:Exclamation)
  END

Air:Menu:PicA ROUTINE
!  The menu is built at generate time out of the boxes the developer ticked, so
!  the numbers below always line up with the lines that are actually on it.
  CASE POPUP('Open a picture...|Zoom in|Zoom out|Actual size|Fit the frame|Rotate left|Rotate right|Next frame|Previous frame|Save a copy...|What is this picture?')
  OF 1
    DO Air:Open:PicA
  OF 2
    DO Air:In:PicA
  OF 3
    DO Air:Out:PicA
  OF 4
    PicA:Zoom = 100
    PicA:PanX = 0
    PicA:PanY = 0
    DO Air:Show:PicA
  OF 5
    DO Air:Fit:PicA
  OF 6
    PicA.RotateLeft()
    DO Air:Show:PicA
  OF 7
    PicA.RotateRight()
    DO Air:Show:PicA
  OF 8
    IF PicA.Frames() > 1
      PicA:Frame += 1
      IF PicA:Frame > PicA.Frames() THEN PicA:Frame = 1.
      PicA.LoadFrame(PicA:Frame)
      DO Air:Show:PicA
    END
  OF 9
    IF PicA.Frames() > 1
      PicA:Frame -= 1
      IF PicA:Frame < 1 THEN PicA:Frame = PicA.Frames().
      PicA.LoadFrame(PicA:Frame)
      DO Air:Show:PicA
    END
  OF 10
    DO Air:Save:PicA
  OF 11
    IF PicA.Ok()
      MESSAGE(PicA.Describe() & '||' & PicA:Path,'Picture',ICON:Asterisk)
    ELSE
      MESSAGE('There is no picture on this canvas.','Picture',ICON:Asterisk)
    END
  END
Air:Setup:PicB ROUTINE
!  The IMAGE control is only the paint surface. A REGION created over it takes
!  the mouse - the way Clarion's own ActiveImage class does it
!  (libsrc\win\ActiveImage.clw:303). A REGION has nothing of its own to draw,
!  so the picture underneath shows through untouched.
  IF ~PicB:Rgn
    PicB:Rgn = CREATE(0,CREATE:Region,?AirCanvas{PROP:Parent})
  END
  DO Air:Place:PicB
  UNHIDE(PicB:Rgn)
!  Take the mouse wheel off the window procedure. The first canvas on a window
!  does it; the rest ride along, because the event reaches all of them.
  IF AirImg_HookWheel(QuickWindow{PROP:Handle})                   ! the helper takes the address,
    PicB:Hooked = 1                                       !   never this module
  END
  ?AirCanvas{PROP:DropID,1}     = '~FILE'                       ! a file dragged out of Explorer
  PicB:Rgn{PROP:DropID,1} = '~FILE'
  PicB:Rgn{PROP:Alrt,255} = MouseRight
  PicB:Rgn{PROP:Alrt,254} = MouseLeft2
  PicB:Path = CLIP(Loc:Url)
  AirImg_LoadUrl(PicB,PicB:Path,'Main_c1',AirImg:Secs)
  DO Air:Fresh:PicB
  POST(Air:Redraw:PicB)                                   ! first paint, once the window is up

Air:Place:PicB ROUTINE
!  Keep the region exactly over the image, however the resizer moves it.
  DATA
x  SIGNED,AUTO
y  SIGNED,AUTO
w  SIGNED,AUTO
h  SIGNED,AUTO
  CODE
  IF ~PicB:Rgn THEN EXIT.
  GETPOSITION(?AirCanvas,x,y,w,h)
  SETPOSITION(PicB:Rgn,x,y,w,h)

Air:Fresh:PicB ROUTINE
!  A NEW picture has just landed in the object.
  IF PicB.Frames() >= 2
    PicB:Frame = 2
    PicB.LoadFrame(PicB:Frame)
  END
  PicB.RotateRight()
  IF PicB.Wide() > 2000 OR PicB.High() > 2000
    PicB.Fit(2000,2000,Img:Contain,0)                      ! cap the longest side
  END
  PicB:Zoom = 0                                           ! back to fitting the frame
  PicB:PanX = 0
  PicB:PanY = 0
  ?AirCanvas{PROP:Tooltip} = PicB:Path
  IF PicB.Ok()
    0{PROP:StatusText,2} = PicB.Describe()
  ELSE
    0{PROP:StatusText,2} = ''
  END

Air:Show:PicB ROUTINE
!  Paint what the object holds. At zoom 0 the class fits a copy to the control
!  for us; from there on the viewport is cut out here and blitted as it is.
  DATA
w      LONG,AUTO
h      LONG,AUTO
cw     LONG,AUTO
ch     LONG,AUTO
savePx LONG,AUTO
  CODE
  IF ~PicB.Ok()
    ?AirCanvas{PROP:Text} = ''
    DISPLAY(?AirCanvas)
    EXIT
  END
  IF ~PicB:Zoom
    PicB.Draw(QuickWindow,?AirCanvas,Img:Proportional,PicB.ArgbOf(16777215))
    EXIT
  END
  savePx = 0{PROP:Pixels}                                     ! the frame, in real pixels
  0{PROP:Pixels} = 1
  w = ?AirCanvas{PROP:Width}
  h = ?AirCanvas{PROP:Height}
  0{PROP:Pixels} = savePx
  IF w < 4 OR h < 4 THEN EXIT.
  IF ~PicB.CloneInto(PicB:Cv) THEN EXIT.
  PicB:Cv.Zoom(PicB:Zoom,Img:Best)
  cw = w                                                      ! the viewport, never bigger than the picture
  ch = h
  IF cw > PicB:Cv.Wide() THEN cw = PicB:Cv.Wide().
  IF ch > PicB:Cv.High() THEN ch = PicB:Cv.High().
  IF PicB:PanX > PicB:Cv.Wide() - cw THEN PicB:PanX = PicB:Cv.Wide() - cw.
  IF PicB:PanY > PicB:Cv.High() - ch THEN PicB:PanY = PicB:Cv.High() - ch.
  IF PicB:PanX < 0 THEN PicB:PanX = 0.
  IF PicB:PanY < 0 THEN PicB:PanY = 0.
  PicB:Cv.Crop(PicB:PanX,PicB:PanY,cw,ch)
  PicB:Cv.Fit(w,h,Img:Centered,PicB.ArgbOf(16777215))  ! pad out to the frame
  PicB:Cv.Draw(QuickWindow,?AirCanvas,-1)                       ! -1 = blit it as it is

Air:In:PicB ROUTINE
!  Zoom about the middle of the viewport, so the picture does not run away.
!  The wheel event reaches every canvas on the window, so each one first asks
!  whether the pointer is actually over it.
  DATA
was    LONG,AUTO
now    LONG,AUTO
w      LONG,AUTO
h      LONG,AUTO
savePx LONG,AUTO
rx     SIGNED,AUTO
ry     SIGNED,AUTO
rw     SIGNED,AUTO
rh     SIGNED,AUTO
  CODE
  IF ~PicB.Ok() THEN EXIT.
  GETPOSITION(?AirCanvas,rx,ry,rw,rh)
  IF MOUSEX() < rx OR MOUSEX() > rx + rw THEN EXIT.
  IF MOUSEY() < ry OR MOUSEY() > ry + rh THEN EXIT.
  savePx = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  w = ?AirCanvas{PROP:Width}
  h = ?AirCanvas{PROP:Height}
  0{PROP:Pixels} = savePx
  was = PicB:Zoom
  IF ~was THEN was = AirImg_FitPct(PicB,w,h).
  now = was + 25
  IF now > 1600 THEN now = 1600.
  PicB:PanX = INT((PicB:PanX + w / 2) * now / was - w / 2)
  PicB:PanY = INT((PicB:PanY + h / 2) * now / was - h / 2)
  PicB:Zoom = now
  DO Air:Show:PicB

Air:Out:PicB ROUTINE
  DATA
was    LONG,AUTO
now    LONG,AUTO
w      LONG,AUTO
h      LONG,AUTO
savePx LONG,AUTO
rx     SIGNED,AUTO
ry     SIGNED,AUTO
rw     SIGNED,AUTO
rh     SIGNED,AUTO
  CODE
  IF ~PicB.Ok() OR ~PicB:Zoom THEN EXIT.               ! already fitted
  GETPOSITION(?AirCanvas,rx,ry,rw,rh)
  IF MOUSEX() < rx OR MOUSEX() > rx + rw THEN EXIT.
  IF MOUSEY() < ry OR MOUSEY() > ry + rh THEN EXIT.
  savePx = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  w = ?AirCanvas{PROP:Width}
  h = ?AirCanvas{PROP:Height}
  0{PROP:Pixels} = savePx
  was = PicB:Zoom
  now = was - 25
  IF now <= AirImg_FitPct(PicB,w,h)                        ! all the way out = fit the frame
    DO Air:Fit:PicB
    EXIT
  END
  PicB:PanX = INT((PicB:PanX + w / 2) * now / was - w / 2)
  PicB:PanY = INT((PicB:PanY + h / 2) * now / was - h / 2)
  PicB:Zoom = now
  DO Air:Show:PicB

Air:Fit:PicB ROUTINE
  PicB:Zoom = 0
  PicB:PanX = 0
  PicB:PanY = 0
  DO Air:Show:PicB

Air:Open:PicB ROUTINE
!  Whichever picture the user wants.
  DATA
pick CSTRING(261)
  CODE
  pick = PicB:Path
  IF ~FILEDIALOG('Open a picture',pick,AirImg_Filter(),FILE:KeepDir + FILE:LongName) THEN EXIT.
  PicB:Path = pick
  IF AirImg_LoadPath(PicB,PicB:Path)
    DO Air:Fresh:PicB
  END
  DO Air:Show:PicB

Air:Save:PicB ROUTINE
!  The format follows the name the user types: .png .jpg .gif .bmp .tif .tga
!  .pcx .ppm and .qoi are all written by the class.
  DATA
pick CSTRING(261)
  CODE
  IF ~PicB.Ok() THEN EXIT.
  pick = PicB:Path
  IF ~FILEDIALOG('Save a copy',pick,AirImg_Filter(),FILE:Save + FILE:KeepDir + FILE:LongName) THEN EXIT.
  IF ~PicB.SaveFile(pick)
    MESSAGE('That picture could not be written.||' & pick,'Save a copy',ICON:Exclamation)
  END

Air:Menu:PicB ROUTINE
!  The menu is built at generate time out of the boxes the developer ticked, so
!  the numbers below always line up with the lines that are actually on it.
  CASE POPUP('Open a picture...|Zoom in|Zoom out|Actual size|Fit the frame|Rotate left|Rotate right|Next frame|Previous frame|Save a copy...|What is this picture?')
  OF 1
    DO Air:Open:PicB
  OF 2
    DO Air:In:PicB
  OF 3
    DO Air:Out:PicB
  OF 4
    PicB:Zoom = 100
    PicB:PanX = 0
    PicB:PanY = 0
    DO Air:Show:PicB
  OF 5
    DO Air:Fit:PicB
  OF 6
    PicB.RotateLeft()
    DO Air:Show:PicB
  OF 7
    PicB.RotateRight()
    DO Air:Show:PicB
  OF 8
    IF PicB.Frames() > 1
      PicB:Frame += 1
      IF PicB:Frame > PicB.Frames() THEN PicB:Frame = 1.
      PicB.LoadFrame(PicB:Frame)
      DO Air:Show:PicB
    END
  OF 9
    IF PicB.Frames() > 1
      PicB:Frame -= 1
      IF PicB:Frame < 1 THEN PicB:Frame = PicB.Frames().
      PicB.LoadFrame(PicB:Frame)
      DO Air:Show:PicB
    END
  OF 10
    DO Air:Save:PicB
  OF 11
    IF PicB.Ok()
      MESSAGE(PicB.Describe() & '||' & PicB:Path,'Picture',ICON:Asterisk)
    ELSE
      MESSAGE('There is no picture on this canvas.','Picture',ICON:Asterisk)
    END
  END

ThisWindow.Init PROCEDURE

ReturnValue          BYTE,AUTO

  CODE
  GlobalErrors.SetProcedureName('Main')
  SELF.Request = GlobalRequest                             ! Store the incoming request
  ReturnValue = PARENT.Init()
  IF ReturnValue THEN RETURN ReturnValue.
  SELF.FirstField = ?Pic1
  SELF.VCRRequest &= VCRRequest
  SELF.Errors &= GlobalErrors                              ! Set this windows ErrorManager to the global ErrorManager
  CLEAR(GlobalRequest)                                     ! Clear GlobalRequest after storing locally
  CLEAR(GlobalResponse)
  SELF.AddItem(Toolbar)
  SELF.Open(QuickWindow)                                   ! Open window
  Do DefineListboxStyle
  INIMgr.Fetch('Main',QuickWindow)                         ! Restore window settings from non-volatile store
  SELF.SetAlerts()
  RETURN ReturnValue


ThisWindow.Kill PROCEDURE

ReturnValue          BYTE,AUTO

  CODE
    IF PicA:Hooked
      AirImg_DropWheel(QuickWindow{PROP:Handle})
      PicA:Hooked = 0
    END
    IF PicB:Hooked
      AirImg_DropWheel(QuickWindow{PROP:Handle})
      PicB:Hooked = 0
    END
  ReturnValue = PARENT.Kill()
  IF ReturnValue THEN RETURN ReturnValue.
  IF SELF.Opened
    INIMgr.Update('Main',QuickWindow)                      ! Save window data to non-volatile store
  END
  GlobalErrors.SetProcedureName
  RETURN ReturnValue


ThisWindow.TakeFieldEvent PROCEDURE

ReturnValue          BYTE,AUTO

Looped BYTE
  CODE
    IF FIELD() = PicA:Rgn OR FIELD() = ?Pic1
      CASE EVENT()
      OF EVENT:MouseDown
        IF KEYCODE() = MouseLeft AND PicA:Zoom
          PicA:Drag  = 1
          PicA:DragX = MOUSEX()
          PicA:DragY = MOUSEY()
        END
      OF EVENT:MouseMove
        IF PicA:Drag
          PicA:PanX += PicA:DragX - MOUSEX()
          PicA:PanY += PicA:DragY - MOUSEY()
          PicA:DragX = MOUSEX()
          PicA:DragY = MOUSEY()
          DO Air:Show:PicA
        END
      OF EVENT:MouseUp
        PicA:Drag = 0
      OF EVENT:Drop
        PicA:Path = CLIP(DROPID())                             ! several files? take the first
        IF INSTRING(',',PicA:Path,1,1)
          PicA:Path = SUB(PicA:Path,1,INSTRING(',',PicA:Path,1,1) - 1)
        END
        IF AirImg_LoadPath(PicA,PicA:Path)
          DO Air:Fresh:PicA
        END
        DO Air:Show:PicA
      OF EVENT:AlertKey
        CASE KEYCODE()
        OF MouseRight
          DO Air:Menu:PicA
        OF MouseLeft2
          DO Air:Open:PicA
        END
      END
    END
    IF FIELD() = PicB:Rgn OR FIELD() = ?AirCanvas
      CASE EVENT()
      OF EVENT:MouseDown
        IF KEYCODE() = MouseLeft AND PicB:Zoom
          PicB:Drag  = 1
          PicB:DragX = MOUSEX()
          PicB:DragY = MOUSEY()
        END
      OF EVENT:MouseMove
        IF PicB:Drag
          PicB:PanX += PicB:DragX - MOUSEX()
          PicB:PanY += PicB:DragY - MOUSEY()
          PicB:DragX = MOUSEX()
          PicB:DragY = MOUSEY()
          DO Air:Show:PicB
        END
      OF EVENT:MouseUp
        PicB:Drag = 0
      OF EVENT:Drop
        PicB:Path = CLIP(DROPID())                             ! several files? take the first
        IF INSTRING(',',PicB:Path,1,1)
          PicB:Path = SUB(PicB:Path,1,INSTRING(',',PicB:Path,1,1) - 1)
        END
        IF AirImg_LoadPath(PicB,PicB:Path)
          DO Air:Fresh:PicB
        END
        DO Air:Show:PicB
      OF EVENT:AlertKey
        CASE KEYCODE()
        OF MouseRight
          DO Air:Menu:PicB
        OF MouseLeft2
          DO Air:Open:PicB
        END
      END
    END
  LOOP                                                     ! This method receives all field specific events
    IF Looped
      RETURN Level:Notify
    ELSE
      Looped = 1
    END
  ReturnValue = PARENT.TakeFieldEvent()
    RETURN ReturnValue
  END
  ReturnValue = Level:Fatal
  RETURN ReturnValue


ThisWindow.TakeWindowEvent PROCEDURE

ReturnValue          BYTE,AUTO

Looped BYTE
  CODE
    CASE EVENT()
    OF EVENT:OpenWindow
      DO Air:Setup:PicA
    OF EVENT:Sized
      DO Air:Place:PicA
      POST(Air:Redraw:PicA)
    OF Air:Redraw:PicA
      DO Air:Show:PicA
    OF AirImg:CtrlUp
      DO Air:In:PicA
    OF AirImg:CtrlDown
      DO Air:Out:PicA
    END
    CASE EVENT()
    OF EVENT:OpenWindow
      DO Air:Setup:PicB
    OF EVENT:Sized
      DO Air:Place:PicB
      POST(Air:Redraw:PicB)
    OF Air:Redraw:PicB
      DO Air:Show:PicB
    OF AirImg:CtrlUp
      DO Air:In:PicB
    OF AirImg:CtrlDown
      DO Air:Out:PicB
    END
  LOOP                                                     ! This method receives all window specific events
    IF Looped
      RETURN Level:Notify
    ELSE
      Looped = 1
    END
  ReturnValue = PARENT.TakeWindowEvent()
    RETURN ReturnValue
  END
  ReturnValue = Level:Fatal
  RETURN ReturnValue

