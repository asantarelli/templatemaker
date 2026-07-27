! ============================================================================
!  myImage demo  -  open any of a dozen image formats, push it through every
!  colour format and every transform, watch it change, and save it back out
!  as any of nine formats.
!
!  Nothing here is destructive: the file you opened is kept as the MASTER, and
!  every redraw rebuilds the working copy from it with the current settings
!  applied. So you can drag a slider back and forth all day and never lose a
!  pixel of the original.
!
!  Build:  msbuild ImageDemo.cwproj -t:Build -p:Configuration=Debug
!                  -p:Platform=Win32 -p:ClarionBinPath="C:\clarion12\bin"
! ============================================================================
  PROGRAM

  INCLUDE('ImageClass.INC'),ONCE
  INCLUDE('EQUATES.CLW'),ONCE

  MAP
  END

Master      ImageClass                                  ! exactly as loaded - never touched
Work        ImageClass                                  ! master + the current settings
LOC:File    CSTRING(261)
LOC:Status  STRING(200)
LOC:Recipe  STRING(200)
LOC:Dither  BYTE
LOC:Thresh  LONG
LOC:Degrees LONG
LOC:ZoomPct LONG
LOC:Bright  LONG
LOC:Contra  LONG
LOC:Satur   LONG
LOC:GammaV  REAL
LOC:BlurR   LONG
LOC:SharpA  LONG
LOC:Poster  LONG
LOC:Invert  BYTE
LOC:Sepia   BYTE
LOC:Quality LONG
LOC:Busy    BYTE
i           LONG

Wnd  WINDOW('myImage - twelve formats in, nine out, every colour format'),AT(,,884,540),SYSTEM,GRAY, |
         CENTER,FONT('Segoe UI',9,,FONT:regular,CHARSET:ANSI),ICON(ICON:Application)
       PANEL,AT(0,0,884,38),USE(?Band),FILL(0603A1FH)
       STRING('Images'),AT(12,6),USE(?T1),FONT('Segoe UI',13,COLOR:White,FONT:bold),TRN
       STRING('Read 12 formats, write 9, convert every colour format, rotate, mirror,' & |
         ' resize, fit - all in C, compiled into the exe.'),AT(12,23),USE(?T2), |
         FONT('Segoe UI',8,0D8C8B4H),TRN
       BUTTON('&Open image...'),AT(8,46,86,16),USE(?Open)
       BUTTON('&Test card'),AT(98,46,60,16),USE(?TestCard)
       BUTTON('&Save as...'),AT(162,46,60,16),USE(?SaveAs)
       SHEET,AT(8,68,214,404),USE(?Sheet)
         TAB('&Colour')
           PROMPT('Colour format:'),AT(16,88),USE(?PMode)
           LIST,AT(16,99,196,11),USE(?ModeList),DROP(12),FROM('32-bit true colour + alpha|' & |
             '24-bit true colour|16-bit high colour (5-6-5)|15-bit high colour (5-5-5)|' & |
             '256 colours (median cut)|16 colours (median cut)|256 greys|16 greys|4 greys|' & |
             'Black &&  white|Web-safe 216')
           CHECK('&Dither (Floyd-Steinberg)'),AT(16,116),USE(LOC:Dither)
           PROMPT('B&&W threshold:'),AT(16,131),USE(?PTh)
           SPIN(@n3),AT(120,130,40,11),USE(LOC:Thresh),RANGE(1,254),STEP(4)
           CHECK('&Invert'),AT(16,148),USE(LOC:Invert)
           CHECK('Se&pia'),AT(80,148),USE(LOC:Sepia)
           PROMPT('Posterise (2 = off):'),AT(16,165),USE(?PPo)
           SPIN(@n3),AT(120,164,40,11),USE(LOC:Poster),RANGE(2,64),STEP(1)
           STRING('Palette:'),AT(16,186),USE(?PalCap),FONT(,8,00808080H),TRN
           IMAGE,AT(16,196,196,44),USE(?Palette)
           STRING('Histogram:'),AT(16,246),USE(?HistCap),FONT(,8,00808080H),TRN
           IMAGE,AT(16,256,196,60),USE(?Hist)
         END
         TAB('&Geometry')
           BUTTON('Rotate &left'),AT(16,88,90,16),USE(?RotL)
           BUTTON('Rotate &right'),AT(112,88,90,16),USE(?RotR)
           BUTTON('&Mirror'),AT(16,108,90,16),USE(?Mirror)
           BUTTON('&Flip'),AT(112,108,90,16),USE(?FlipV)
           PROMPT('Free rotation (degrees):'),AT(16,134),USE(?PDeg)
           SPIN(@n4),AT(140,133,50,11),USE(LOC:Degrees),RANGE(-180,180),STEP(5)
           PROMPT('&Zoom (percent):'),AT(16,152),USE(?PZoom)
           SPIN(@n4),AT(140,151,50,11),USE(LOC:ZoomPct),RANGE(5,400),STEP(5)
           PROMPT('Fit the preview by:'),AT(16,172),USE(?PFit)
           LIST,AT(16,183,196,11),USE(?FitList),DROP(6),FROM('Stretch|Proportional|Cover (crop)|' & |
             'Centred 1:1|Contain')
           STRING('The preview always fits the box; zoom and free rotation change the' & |
             ' image itself, so what you save is what you see.'),AT(16,202,196,30),USE(?GeoNote), |
             FONT(,8,00808080H),TRN
           BUTTON('&Reset everything'),AT(16,244,110,16),USE(?Reset)
         END
         TAB('&Adjust')
           PROMPT('Brightness:'),AT(16,88),USE(?PB)
           SPIN(@n4),AT(140,87,50,11),USE(LOC:Bright),RANGE(-100,100),STEP(5)
           PROMPT('Contrast:'),AT(16,104),USE(?PC)
           SPIN(@n4),AT(140,103,50,11),USE(LOC:Contra),RANGE(-100,100),STEP(5)
           PROMPT('Saturation:'),AT(16,120),USE(?PS)
           SPIN(@n4),AT(140,119,50,11),USE(LOC:Satur),RANGE(-100,100),STEP(5)
           PROMPT('Gamma:'),AT(16,136),USE(?PG)
           SPIN(@n5.2),AT(140,135,50,11),USE(LOC:GammaV),RANGE(0.1,4.0),STEP(0.1)
           PROMPT('Blur radius (0 = off):'),AT(16,152),USE(?PBl)
           SPIN(@n3),AT(140,151,50,11),USE(LOC:BlurR),RANGE(0,20),STEP(1)
           PROMPT('Sharpen (0 = off):'),AT(16,168),USE(?PSh)
           SPIN(@n4),AT(140,167,50,11),USE(LOC:SharpA),RANGE(0,300),STEP(10)
           PROMPT('JPEG quality on save:'),AT(16,190),USE(?PQ)
           SPIN(@n3),AT(140,189,50,11),USE(LOC:Quality),RANGE(1,100),STEP(5)
           STRING('Gamma and levels are worked out as a 256-entry lookup table in' & |
             ' Clarion, then applied to every pixel in C.'),AT(16,210,196,30),USE(?AdjNote), |
             FONT(,8,00808080H),TRN
         END
       END
       BOX,AT(230,46,646,426),USE(?Frame),COLOR(00D4D0CCH),FILL(00F4F4F4H)
       IMAGE,AT(233,49,640,420),USE(?Preview)
       STRING(@s200),AT(8,480,868,10),USE(LOC:Status),FONT('Segoe UI',8,0603A1FH),TRN
       STRING(@s200),AT(8,492,868,10),USE(LOC:Recipe),FONT('Segoe UI',8,00808080H),TRN
       STRING('Every pixel here is touched by imgcore.c - compiled into this exe by' & |
         ' Clarion''s own C compiler. No DLL, no installer, no external library.'), |
         AT(8,508,700,10),USE(?Foot),FONT('Segoe UI',8,00A0A0A0H),TRN
       BUTTON('&Close'),AT(820,504,56,15),USE(?Close),STD(STD:Close)
     END

  CODE
  LOC:Thresh  = 128
  LOC:ZoomPct = 100
  LOC:GammaV  = 1.0
  LOC:Poster  = 2
  LOC:Quality = 85
  OPEN(Wnd)
  ?ModeList{PROP:Selected} = 1
  ?FitList{PROP:Selected} = 2
  Master.TestCard(640, 480)
  DO Rebuild
  ACCEPT
    CASE EVENT()
    OF EVENT:Accepted OROF EVENT:NewSelection
      CASE FIELD()
      OF ?Close
      OF ?Open      ; DO OpenFile
      OF ?TestCard  ; Master.TestCard(640, 480); DO ResetAll; DO Rebuild
      OF ?SaveAs    ; DO SaveFile
      OF ?Reset     ; DO ResetAll; DO Rebuild
      OF ?RotL      ; Master.RotateLeft();  DO Rebuild
      OF ?RotR      ; Master.RotateRight(); DO Rebuild
      OF ?Mirror    ; Master.Mirror();      DO Rebuild
      OF ?FlipV     ; Master.FlipVert();    DO Rebuild
      ELSE            DO Rebuild
      END
    OF EVENT:Sized
      DO Redraw
    END
  END
  CLOSE(Wnd)
  RETURN

!----------------------------------------------------------------------------
!  Rebuild the working image from the master, applying everything the user has
!  chosen, in the order that makes sense: geometry, then tone, then colour
!  depth last (so the palette is chosen from the pixels you actually end up
!  with).
!----------------------------------------------------------------------------
Rebuild ROUTINE
  IF LOC:Busy OR NOT Master.Ok() THEN EXIT.
  LOC:Busy = 1
  Master.CloneInto(Work)
  ! ---- geometry ----
  IF LOC:ZoomPct <> 100 AND LOC:ZoomPct > 0
    Work.Zoom(LOC:ZoomPct, Img:Best)
  END
  IF LOC:Degrees <> 0
    Work.Rotate(LOC:Degrees, 0FF202428h, 1, 1)
  END
  ! ---- tone ----
  IF LOC:Bright <> 0 OR LOC:Contra <> 0 OR LOC:Satur <> 0
    Work.Adjust(LOC:Bright, LOC:Contra, LOC:Satur)
  END
  IF LOC:GammaV > 0 AND LOC:GammaV <> 1.0
    Work.Gamma(LOC:GammaV)
  END
  IF LOC:BlurR > 0   THEN Work.Blur(LOC:BlurR, 2).
  IF LOC:SharpA > 0  THEN Work.Sharpen(LOC:SharpA).
  IF LOC:Invert      THEN Work.Invert().
  IF LOC:Sepia       THEN Work.Sepia().
  IF LOC:Poster > 2  THEN Work.Posterize(LOC:Poster).
  ! ---- colour format last ----
  Work.Convert(CHOOSE(CHOICE(?ModeList) > 0, CHOICE(?ModeList), 1), LOC:Dither, LOC:Thresh)
  LOC:Busy = 0
  DO Redraw
  DO ShowInfo

Redraw ROUTINE
  IF NOT Work.Ok() THEN EXIT.
  Work.Draw(Wnd, ?Preview, CHOOSE(CHOICE(?FitList) > 0, CHOICE(?FitList) - 1, 1), 0FFF4F4F4h)
  DO DrawHistogram
  DO DrawPalette

ShowInfo ROUTINE
  LOC:Status = 'Master: ' & CLIP(Master.Describe()) & '   |   Preview: ' & |
               Work.Wide() & ' x ' & Work.High() & ' ' & CLIP(Work.ColorModeName())
  IF LOC:File
    LOC:Status = CLIP(LOC:Status) & '   |   ' & CLIP(LOC:File)
  END
  LOC:Recipe = 'zoom ' & LOC:ZoomPct & '%  rotate ' & LOC:Degrees & '  bright ' & LOC:Bright & |
               '  contrast ' & LOC:Contra & '  saturation ' & LOC:Satur & '  gamma ' & |
               FORMAT(LOC:GammaV,@n5.2) & '  blur ' & LOC:BlurR & '  sharpen ' & LOC:SharpA
  DISPLAY(?LOC:Status)
  DISPLAY(?LOC:Recipe)

!  The luma histogram, drawn with native BOX straight into a small IMAGE.
DrawHistogram ROUTINE
  DATA
peak  LONG
x     LONG
bh    LONG
w     LONG
h     LONG
v     LONG
  CODE
  IF NOT Work.Ok() THEN EXIT.
  peak = Work.Histogram()
  IF peak < 1 THEN peak = 1.
  SETTARGET(Wnd, ?Hist)
  BLANK
  GETPOSITION(?Hist, , , w, h)
  SETPENCOLOR(0F8F8F8h)
  BOX(0, 0, w, h, 0F8F8F8h)
  LOOP x = 0 TO 255
    v = Work.HistogramBin(x)
    bh = INT(v * (h - 2) / peak)
    IF bh < 1 AND v > 0 THEN bh = 1.
    IF bh > 0
      SETPENCOLOR(0B6752Eh)
      BOX(INT(x * w / 256), h - bh, INT(w / 256) + 1, bh, 0B6752Eh)
    END
  END
  SETPENCOLOR(0D0D0D0h)
  LINE(0, h - 1, w, 0)
  SETTARGET()

!  The palette an indexed conversion built - one swatch per entry.
DrawPalette ROUTINE
  DATA
n     LONG
k     LONG
w     LONG
h     LONG
cols  LONG
rows  LONG
cw    LONG
chh   LONG
c     ULONG
cc    LONG
  CODE
  IF NOT Work.Ok() THEN EXIT.
  SETTARGET(Wnd, ?Palette)
  BLANK
  GETPOSITION(?Palette, , , w, h)
  SETPENCOLOR(0F8F8F8h)
  BOX(0, 0, w, h, 0F8F8F8h)
  n = Work.Colors()
  IF n > 0
    cols = 32
    IF n <= 16 THEN cols = 8.
    IF n <= 4  THEN cols = 4.
    rows = INT((n + cols - 1) / cols)
    IF rows < 1 THEN rows = 1.
    cw = INT(w / cols)
    chh = INT(h / rows)
    IF cw < 1 THEN cw = 1.
    IF chh < 1 THEN chh = 1.
    LOOP k = 0 TO n - 1
      c = Work.PaletteEntry(k)
      ! engine palette is 0x00RRGGBB; Clarion wants BGR
      cc = BOR(BOR(BSHIFT(BAND(c, 0FFh), 16), BAND(c, 0FF00h)), BSHIFT(BAND(c, 0FF0000h), -16))
      SETPENCOLOR(cc)
      BOX(INT(k % cols) * cw, INT(k / cols) * chh, cw, chh, cc)
    END
    ?PalCap{PROP:Text} = 'Palette: ' & n & ' entries'
  ELSE
    ?PalCap{PROP:Text} = 'Palette: none (true colour)'
  END
  SETTARGET()
  DISPLAY(?PalCap)

ResetAll ROUTINE
  LOC:Dither  = 0
  LOC:Thresh  = 128
  LOC:Degrees = 0
  LOC:ZoomPct = 100
  LOC:Bright  = 0
  LOC:Contra  = 0
  LOC:Satur   = 0
  LOC:GammaV  = 1.0
  LOC:BlurR   = 0
  LOC:SharpA  = 0
  LOC:Poster  = 2
  LOC:Invert  = 0
  LOC:Sepia   = 0
  ?ModeList{PROP:Selected} = 1
  DISPLAY()

OpenFile ROUTINE
  DATA
f  STRING(261)
  CODE
  f = ''
  IF NOT FILEDIALOG('Open an image', f, |
        'All images|*.bmp;*.dib;*.rle;*.gif;*.jpg;*.jpeg;*.jpe;*.jfif;*.png;*.tif;*.tiff;' & |
        '*.ico;*.cur;*.emf;*.wmf;*.tga;*.pcx;*.pnm;*.ppm;*.pgm;*.pbm;*.qoi|' & |
        'BMP|*.bmp;*.dib;*.rle|GIF|*.gif|JPEG|*.jpg;*.jpeg;*.jpe;*.jfif|PNG|*.png|' & |
        'TIFF|*.tif;*.tiff|Icon|*.ico;*.cur|Metafile|*.emf;*.wmf|Targa|*.tga|PCX|*.pcx|' & |
        'PNM|*.pnm;*.ppm;*.pgm;*.pbm|QOI|*.qoi|All files|*.*', |
        FILE:KeepDir + FILE:LongName)
    EXIT
  END
  IF NOT Master.LoadFile(f)
    MESSAGE('Could not read that file.||' & CLIP(f) & '||Engine error ' & Master.LastError(), |
            'myImage', ICON:Exclamation)
    EXIT
  END
  LOC:File = CLIP(f)
  DO ResetAll
  DO Rebuild

SaveFile ROUTINE
  DATA
f    STRING(261)
fmt  LONG
  CODE
  IF NOT Work.Ok() THEN EXIT.
  f = ''
  IF NOT FILEDIALOG('Save the image as', f, |
        'PNG|*.png|JPEG|*.jpg|BMP|*.bmp|GIF|*.gif|TIFF|*.tif|Targa|*.tga|PCX|*.pcx|' & |
        'PNM|*.ppm|QOI|*.qoi', |
        FILE:KeepDir + FILE:LongName + FILE:Save)
    EXIT
  END
  fmt = Work.FormatFromExt(f)
  IF NOT fmt
    f = CLIP(f) & '.png'
    fmt = Img:Png
  END
  Work.Quality = LOC:Quality
  IF Work.SaveFile(f, fmt)
    MESSAGE('Saved as ' & CLIP(Work.FormatName(fmt)) & '.||' & CLIP(f), 'myImage', ICON:Asterisk)
  ELSE
    MESSAGE('Could not write that file.||' & CLIP(f) & '||Engine error ' & Work.LastError(), |
            'myImage', ICON:Exclamation)
  END
