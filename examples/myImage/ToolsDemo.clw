! ============================================================================
!  myImage - what the two CONTROL templates generate.
!
!  This is not a hand-written demo so much as a transcript: it is, line for
!  line, the code that dropping "myImage - Image view" and "myImage - Image
!  tools panel" onto a window produces (with the view's IMAGE control named
!  ?ImgView, so the generated prefix is ImgView). Keeping it here means the
!  generated design is compiled and run every time this example is built,
!  instead of only being read.
!
!  The point of the two-object design: the MASTER holds the picture as loaded
!  plus any permanent turn or resize, and the working copy is re-derived from
!  it whenever the colour format changes. That is what lets you go 256 colours
!  -> black & white -> back to 24-bit without the picture degrading a little
!  more on each step.
!
!  Build:  msbuild ToolsDemo.cwproj -t:Build -p:Configuration=Debug
!                  -p:Platform=Win32 -p:ClarionBinPath="C:\clarion12\bin"
! ============================================================================
  PROGRAM

  INCLUDE('ImageClass.INC'),ONCE
  INCLUDE('EQUATES.CLW'),ONCE

  MAP
  END

!  ---- what the VIEW control template declares (keyed off its IMAGE feq) ----
ImgView:Master   ImageClass
ImgView:Pic      ImageClass
ImgView:Mode     LONG
ImgView:Dither   BYTE
ImgView:Thresh   LONG
ImgView:Src      CSTRING(261)
!  ---- what the TOOLS control template declares ----
ImgTool:Dither   BYTE
ImgTool:File     STRING(261)

Wnd  WINDOW('myImage - the image view and tools control templates'),AT(,,520,330),SYSTEM,GRAY, |
         CENTER,FONT('Segoe UI',9,,FONT:regular,CHARSET:ANSI),ICON(ICON:Application)
       PANEL,AT(0,0,520,30),USE(?Band),FILL(0603A1FH)
       STRING('Image view + tools'),AT(10,4),USE(?T1),FONT('Segoe UI',12,COLOR:White,FONT:bold),TRN
       STRING('Two control templates: drop the view, drop the toolbar, point one at the other.'), |
         AT(10,18),USE(?T2),FONT('Segoe UI',8,0D8C8B4H),TRN
       IMAGE,AT(8,38,504,214),USE(?ImgView)
       GROUP('Image tools'),AT(8,258,360,54),USE(?ImgTool:Group),BOXED
         BUTTON('&Open...'),AT(16,270,46,14),USE(?ImgTool:Open),TIP('Open an image file')
         BUTTON('&Save...'),AT(66,270,46,14),USE(?ImgTool:Save),TIP('Save the picture as it looks now')
         BUTTON('Rot &L'),AT(116,270,26,14),USE(?ImgTool:RotL),TIP('Rotate left')
         BUTTON('Rot &R'),AT(146,270,26,14),USE(?ImgTool:RotR),TIP('Rotate right')
         BUTTON('M&irror'),AT(176,270,34,14),USE(?ImgTool:Mirror),TIP('Flip left to right')
         BUTTON('Fli&p'),AT(214,270,26,14),USE(?ImgTool:Flip),TIP('Flip top to bottom')
         BUTTON('-'),AT(244,270,22,14),USE(?ImgTool:ZoomOut),TIP('Zoom out 20%')
         BUTTON('+'),AT(270,270,22,14),USE(?ImgTool:ZoomIn),TIP('Zoom in 25%')
         BUTTON('&Fit'),AT(296,270,26,14),USE(?ImgTool:Fit),TIP('Shrink to fit the view')
         BUTTON('&Reset'),AT(326,270,34,14),USE(?ImgTool:Reset),TIP('Load it again and start over')
         PROMPT('Colour:'),AT(16,292,38,10),USE(?ImgTool:ModeP)
         LIST,AT(56,290,150,11),USE(?ImgTool:Mode),DROP(12),FROM('As loaded|32-bit true colour + alpha|' & |
           '24-bit true colour|16-bit high colour|15-bit high colour|256 colours|16 colours|256 greys|' & |
           '16 greys|4 greys|Black and white|Web-safe 216')
         CHECK('&Dither'),AT(212,291,44,10),USE(ImgTool:Dither),TIP('Floyd-Steinberg error diffusion')
         BUTTON('&Grey'),AT(260,289,26,14),USE(?ImgTool:Grey),TIP('Greyscale')
         BUTTON('I&nvert'),AT(290,289,32,14),USE(?ImgTool:Invert),TIP('Invert')
         BUTTON('Sepi&a'),AT(326,289,32,14),USE(?ImgTool:Sepia),TIP('Sepia')
       END
       STRING(@s160),AT(376,266,140,40),USE(ImgView:Src),FONT('Segoe UI',8,00808080H),TRN
       BUTTON('&Close'),AT(456,312,56,14),USE(?Close),STD(STD:Close)
     END

  CODE
  OPEN(Wnd)
  !  ---- the view's EVENT:OpenWindow code ----
  ImgView:Mode = 5                                           ! 256 colours, as the prompt would set it
  ImgView:Dither = 1
  ImgView:Thresh = 128
  DO ImgView:Load
  !  ---- the tools panel's EVENT:OpenWindow + deferred sync ----
  ImgTool:Dither = ImgView:Dither
  ?ImgTool:Mode{PROP:Selected} = ImgView:Mode + 1
  DISPLAY
  ACCEPT
    CASE FIELD()
    OF ?ImgTool:Open
      IF EVENT() = EVENT:Accepted
        ImgTool:File = ''
        IF FILEDIALOG('Open an image', ImgTool:File, |
             'All images|*.bmp;*.gif;*.jpg;*.jpeg;*.png;*.tif;*.tiff;*.ico;*.emf;*.wmf;' & |
             '*.tga;*.pcx;*.pnm;*.ppm;*.pgm;*.pbm;*.qoi|All files|*.*', |
             FILE:KeepDir + FILE:LongName)
          IF ImgView:Master.LoadFile(ImgTool:File)
            ImgView:Src = CLIP(ImgTool:File)
            DO ImgView:Rebuild
          ELSE
            MESSAGE('Could not read that file.||' & CLIP(ImgTool:File), 'myImage', ICON:Exclamation)
          END
        END
      END
    OF ?ImgTool:Save
      IF EVENT() = EVENT:Accepted
        ImgTool:File = ''
        IF FILEDIALOG('Save the image as', ImgTool:File, |
             'PNG|*.png|JPEG|*.jpg|BMP|*.bmp|GIF|*.gif|TIFF|*.tif|Targa|*.tga|PCX|*.pcx|' & |
             'PNM|*.ppm|QOI|*.qoi', FILE:KeepDir + FILE:LongName + FILE:Save)
          ImgView:Pic.Quality = 85
          IF NOT ImgView:Pic.SaveFile(ImgTool:File, 0)
            MESSAGE('Could not write that file.||' & CLIP(ImgTool:File) & |
                    '||Engine error ' & ImgView:Pic.LastError(), 'myImage', ICON:Exclamation)
          END
        END
      END
    OF ?ImgTool:RotL
      IF EVENT() = EVENT:Accepted
        ImgView:Master.RotateLeft()
        DO ImgView:Rebuild
      END
    OF ?ImgTool:RotR
      IF EVENT() = EVENT:Accepted
        ImgView:Master.RotateRight()
        DO ImgView:Rebuild
      END
    OF ?ImgTool:Mirror
      IF EVENT() = EVENT:Accepted
        ImgView:Master.Mirror()
        DO ImgView:Rebuild
      END
    OF ?ImgTool:Flip
      IF EVENT() = EVENT:Accepted
        ImgView:Master.FlipVert()
        DO ImgView:Rebuild
      END
    OF ?ImgTool:ZoomIn
      IF EVENT() = EVENT:Accepted
        ImgView:Master.Zoom(125, Img:Best)
        DO ImgView:Rebuild
      END
    OF ?ImgTool:ZoomOut
      IF EVENT() = EVENT:Accepted
        ImgView:Master.Zoom(80, Img:Best)
        DO ImgView:Rebuild
      END
    OF ?ImgTool:Fit
      IF EVENT() = EVENT:Accepted
        DO ImgTool:FitToView
      END
    OF ?ImgTool:Reset
      IF EVENT() = EVENT:Accepted
        DO ImgView:Load
      END
    OF ?ImgTool:Grey
      IF EVENT() = EVENT:Accepted
        ImgView:Master.Greyscale(Img:Luma)
        DO ImgView:Rebuild
      END
    OF ?ImgTool:Invert
      IF EVENT() = EVENT:Accepted
        ImgView:Master.Invert()
        DO ImgView:Rebuild
      END
    OF ?ImgTool:Sepia
      IF EVENT() = EVENT:Accepted
        ImgView:Master.Sepia()
        DO ImgView:Rebuild
      END
    OF ?ImgTool:Mode
      IF EVENT() = EVENT:Accepted OR EVENT() = EVENT:NewSelection
        DO ImgTool:Apply
      END
    OF ?ImgTool:Dither
      IF EVENT() = EVENT:Accepted
        DO ImgTool:Apply
      END
    END
    CASE EVENT()
    OF EVENT:Sized
      DO ImgView:Show
    END
  END
  CLOSE(Wnd)
  RETURN

!----------------------------------------------------------------------------
ImgView:Load ROUTINE
  ImgView:Master.TestCard(640, 480)
  ImgView:Src = 'built-in test card'
  DO ImgView:Rebuild

ImgView:Rebuild ROUTINE
  IF ImgView:Master.Ok()
    ImgView:Master.CloneInto(ImgView:Pic)
    IF ImgView:Mode > 0
      ImgView:Pic.Convert(ImgView:Mode, ImgView:Dither, ImgView:Thresh)
    END
  END
  DO ImgView:Show

ImgView:Show ROUTINE
  IF ImgView:Pic.Ok()
    ImgView:Pic.Draw(Wnd, ?ImgView, Img:Proportional, ImgView:Pic.ArgbOf(COLOR:White))
  END
  ImgView:Src = CLIP(ImgView:Src)
  DISPLAY(?ImgView:Src)

ImgTool:Apply ROUTINE
  ImgView:Mode = CHOICE(?ImgTool:Mode) - 1
  IF ImgView:Mode < 0 THEN ImgView:Mode = 0.
  ImgView:Dither = ImgTool:Dither
  DO ImgView:Rebuild

ImgTool:FitToView ROUTINE
  DATA
vw  LONG
vh  LONG
sp  LONG
  CODE
  SETTARGET(Wnd)
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  vw = ?ImgView{PROP:Width}
  vh = ?ImgView{PROP:Height}
  0{PROP:Pixels} = sp
  SETTARGET()
  IF vw > 3 AND vh > 3
    ImgView:Master.Fit(vw, vh, Img:Contain, 0)
    DO ImgView:Rebuild
  END
