#TEMPLATE(myImage,'myImage - image formats, colour formats and transforms - v1.0'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  myImage template set - read twelve image formats, write nine, convert
#!  between every common colour format, and transform along the way.
#!
#!    READ   BMP GIF JPEG PNG TIFF ICO EMF WMF TGA PCX PNM QOI
#!    WRITE  BMP GIF JPEG PNG TIFF TGA PCX PNM QOI
#!    COLOUR 32-bit ARGB, 24-bit RGB, 16-bit 5-6-5, 15-bit 5-5-5, 256 and 16
#!           colours (median cut, optional Floyd-Steinberg dither), 256/16/4
#!           greys, 1-bit black & white, web-safe 216
#!    SHAPE  rotate 90/180/270, free rotation, mirror, flip, crop, extend
#!           canvas, resize (nearest/bilinear/area), fit: stretch,
#!           proportional, cover, centred, contain
#!    TONE   brightness, contrast, saturation, gamma, levels, blur, sharpen,
#!           invert, sepia, posterise, alpha flatten, opacity, histogram
#!
#!  It is quick because the pixel work is C: imgcore.c is compiled INTO your
#!  exe by Clarion's own C compiler. Nothing to install and nothing to ship -
#!  the formats Windows already knows are decoded through GDI+, which is part
#!  of Windows.
#!
#!  myImageGlobal  (APPLICATION) - INCLUDEs ImageClass. Add once.
#!  myImage        (PROCEDURE)   - an image object on a window, drawn into an
#!                 IMAGE control, with a Load: and a Refresh: routine.
#!  myImageConvert (CODE)        - drop into any embed: convert one file to
#!                 another format / colour format / size, in one statement.
#!
#!  REQUIRED FILES: copy ImageClass.inc, ImageClass.clw AND imgcore.c (shipped
#!  beside this .tpl) to a folder on the Clarion redirection path (the app
#!  folder or \clarion12\libsrc\win). Keep the .inc/.clw in ANSI, CRLF.
#!
#!  API (the object is procedure data - drive it from any embed):
#!    Pic.LoadFile('holiday.jpg')
#!    Pic.Resize(800, 600, Img:Best) ; Pic.Convert(Img:Pal256, 1)
#!    Pic.SaveFile('holiday.gif')    ; Pic.Draw(MyWindow, ?Preview)
#!    DO Refresh:Pic                 ! re-apply the prompts and redraw
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - myImageGlobal
#!#############################################################################
#EXTENSION(myImageGlobal,'myImage - Global (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('myImage')
      #DISPLAY('myImage Global - Version 1.0')
      #DISPLAY('Adds the ImageClass image engine: 12 formats in, 9 out,')
      #DISPLAY('every colour format, and the usual transforms.')
      #DISPLAY('')
      #DISPLAY('Add once, at the Application (global) level. IMPORTANT: copy')
      #DISPLAY('ImageClass.inc + ImageClass.clw + imgcore.c to the redirection')
      #DISPLAY('path. The .inc/.clw must be ANSI; imgcore.c is compiled by')
      #DISPLAY('Clarion''s own C compiler, so there is no DLL to ship.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%miDisable,DEFAULT(0),AT(10)
      #PROMPT('Declare the shared &worker object (ImgWork)',CHECK),%miWorker,DEFAULT(1),AT(10)
      #DISPLAY('The myImageConvert code template uses ImgWork. Untick only if')
      #DISPLAY('that name clashes with something you already have.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#AT(%AfterGlobalIncludes),WHERE(%miDisable=0)
INCLUDE('ImageClass.INC'),ONCE
#ENDAT
#!
#!  One shared object for one-shot work (the myImageConvert code template uses
#!  it). Conversions run start to finish in a single statement, so sharing it
#!  is safe and it keeps a converting embed down to no declarations at all.
#AT(%GlobalData),WHERE(%miDisable=0 AND %miWorker=1)
ImgWork              ImageClass                              ! shared by myImageConvert
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - myImage  -  one image object per instance
#!#############################################################################
#EXTENSION(myImage,'myImage - An image on this window'),PROCEDURE,MULTI,REQ(myImageGlobal),DESCRIPTION('[Image] ' & %miObject)
#SHEET
  #TAB('&General')
    #BOXED('Object &&  control')
      #PROMPT('&Disable this image',CHECK),%miWDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%miObject,REQ,DEFAULT('Pic' & %ActiveTemplateInstance)
      #PROMPT('&Show it in this IMAGE control:',CONTROL),%miControl
      #DISPLAY('Leave the control blank to work with the image in code only -')
      #DISPLAY('handy for converting or thumbnailing without showing anything.')
    #ENDBOXED
    #BOXED('What to load when the window opens')
      #PROMPT('&Load a file:',DROP('Nothing|A fixed file name|A variable or expression|A test card')),%miSource,DEFAULT('Nothing')
      #ENABLE(%miSource='A fixed file name')
        #PROMPT('File &name:',@s255),%miFile,DEFAULT('')
      #ENDENABLE
      #ENABLE(%miSource='A variable or expression')
        #PROMPT('&Variable / expression:',@s255),%miFileVar,DEFAULT('')
      #ENDENABLE
      #ENABLE(%miSource='A test card')
        #PROMPT('Test card &width:',SPIN(@n5,16,4000,16)),%miCardW,DEFAULT(640)
        #PROMPT('Test card &height:',SPIN(@n5,16,4000,16)),%miCardH,DEFAULT(480)
      #ENDENABLE
      #PROMPT('If the file will not load, tell the user',CHECK),%miWarn,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('How to fit it to the control')
      #PROMPT('&Fit:',DROP('Proportional (pad)|Contain (no pad)|Cover (crop)|Stretch|Centred 1:1')),%miFit,DEFAULT('Proportional (pad)')
      #PROMPT('Pad / background color:',COLOR),%miPad,DEFAULT(00FFFFFFH)
    #ENDBOXED
  #ENDTAB
  #TAB('&Colour')
    #BOXED('Colour format')
      #PROMPT('Con&vert to:',DROP('Leave as loaded|32-bit true colour + alpha|24-bit true colour|16-bit high colour (5-6-5)|15-bit high colour (5-5-5)|256 colours|16 colours|256 greys|16 greys|4 greys|Black and white|Web-safe 216')),%miMode,DEFAULT('Leave as loaded')
      #PROMPT('&Dither (Floyd-Steinberg)',CHECK),%miDither,DEFAULT(0),AT(10)
      #PROMPT('Black &&  white threshold:',SPIN(@n3,1,254,4)),%miThreshold,DEFAULT(128)
    #ENDBOXED
    #BOXED('Tone')
      #PROMPT('&Brightness (-100..100):',SPIN(@n4,-100,100,5)),%miBright,DEFAULT(0)
      #PROMPT('&Contrast (-100..100):',SPIN(@n4,-100,100,5)),%miContrast,DEFAULT(0)
      #PROMPT('&Saturation (-100..100):',SPIN(@n4,-100,100,5)),%miSatur,DEFAULT(0)
      #PROMPT('&Gamma (1 = leave alone):',@n5.2),%miGamma,DEFAULT(1.0)
      #PROMPT('B&lur radius (0 = none):',SPIN(@n3,0,20,1)),%miBlur,DEFAULT(0)
      #PROMPT('S&harpen (0 = none):',SPIN(@n4,0,300,10)),%miSharpen,DEFAULT(0)
      #PROMPT('&Invert',CHECK),%miInvert,DEFAULT(0),AT(10)
      #PROMPT('Se&pia',CHECK),%miSepia,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Shape')
    #BOXED('Turn it')
      #PROMPT('&Rotate:',DROP('No|90 right|180|90 left')),%miRotate,DEFAULT('No')
      #PROMPT('&Mirror (left to right)',CHECK),%miMirror,DEFAULT(0),AT(10)
      #PROMPT('&Flip (top to bottom)',CHECK),%miFlip,DEFAULT(0),AT(10)
      #PROMPT('Free rotation, &degrees (0 = none):',SPIN(@n4,-180,180,5)),%miDegrees,DEFAULT(0)
    #ENDBOXED
    #BOXED('Size it')
      #PROMPT('Resi&ze to:',DROP('Leave alone|A fixed width and height|A percentage|Fit a box, keep the ratio')),%miSize,DEFAULT('Leave alone')
      #ENABLE(%miSize='A fixed width and height' OR %miSize='Fit a box, keep the ratio')
        #PROMPT('&Width:',SPIN(@n5,1,20000,10)),%miNewW,DEFAULT(640)
        #PROMPT('&Height:',SPIN(@n5,1,20000,10)),%miNewH,DEFAULT(480)
      #ENDENABLE
      #ENABLE(%miSize='A percentage')
        #PROMPT('&Percent:',SPIN(@n5,1,2000,5)),%miPct,DEFAULT(100)
      #ENDENABLE
      #PROMPT('Resample with:',DROP('Best (area / bilinear)|Smooth (bilinear)|Fast (nearest)')),%miFilter,DEFAULT('Best (area / bilinear)')
    #ENDBOXED
  #ENDTAB
  #TAB('&Save')
    #BOXED('Write a copy every time the image is (re)loaded')
      #PROMPT('&Save a copy',CHECK),%miSave,DEFAULT(0),AT(10)
      #ENABLE(%miSave=1)
        #PROMPT('To file &name / expression:',@s255),%miSaveTo,DEFAULT('')
        #PROMPT('&Format:',DROP('From the file extension|PNG|JPEG|BMP|GIF|TIFF|Targa|PCX|PNM|QOI')),%miSaveFmt,DEFAULT('From the file extension')
        #PROMPT('&JPEG quality:',SPIN(@n3,1,100,5)),%miQuality,DEFAULT(85)
        #PROMPT('BMP bit depth (0 = from the colour format):',SPIN(@n2,0,32,1)),%miBmpBits,DEFAULT(0)
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%miWDisable=0)
%miObject            ImageClass                              ! one image object for this instance
#ENDAT
#!
#! PRIORITY(2000) puts this self-contained CASE EVENT() ABOVE the framework's own
#! LOOP/CASE scaffolding (registered at PRIORITY 2500) - the spot myGauge,
#! graficaBarra and myPixel all use. 2500 collides and duplicates CASE EVENT().
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%miWDisable=0)
  CASE EVENT()
  OF EVENT:OpenWindow
    DO Refresh:%miObject
#IF(%miControl)
  OF EVENT:Sized
    DO Show:%miObject
#ENDIF
  END
#ENDAT
#!
#!  Refresh: (re)load the source and apply everything on the prompts.
#!  Show: just redraw what is already loaded into the control.
#AT(%ProcedureRoutines),WHERE(%miWDisable=0)
Refresh:%miObject ROUTINE
#INSERT(%miEmitLoad)
#INSERT(%miEmitRecipe)
#IF(%miSave)
#INSERT(%miEmitSave)
#ENDIF
#IF(%miControl)
    DO Show:%miObject

Show:%miObject ROUTINE
    IF %miObject.Ok()
#INSERT(%miEmitFit)
    END
#ENDIF
#ENDAT
#!#############################################################################
#!  CODE TEMPLATE - myImageConvert  -  one file in, one file out
#!#############################################################################
#CODE(myImageConvert,'myImage - Convert an image file'),HLP('~myImageConvert')
#SHEET
  #TAB('&Files')
    #BOXED('In and out')
      #PROMPT('&Source file (name or expression):',@s255),%mcFrom,REQ
      #PROMPT('&Target file (name or expression):',@s255),%mcTo,REQ
      #PROMPT('&Format:',DROP('From the target extension|PNG|JPEG|BMP|GIF|TIFF|Targa|PCX|PNM|QOI')),%mcFmt,DEFAULT('From the target extension')
      #PROMPT('&JPEG quality:',SPIN(@n3,1,100,5)),%mcQuality,DEFAULT(85)
      #PROMPT('Put the result (1 = worked) in:',@s64),%mcResult,DEFAULT('')
      #DISPLAY('Leave the result variable blank if you do not need it.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Convert')
    #BOXED('Colour format')
      #PROMPT('Convert &to:',DROP('Leave as loaded|32-bit true colour + alpha|24-bit true colour|16-bit high colour (5-6-5)|15-bit high colour (5-5-5)|256 colours|16 colours|256 greys|16 greys|4 greys|Black and white|Web-safe 216')),%mcMode,DEFAULT('Leave as loaded')
      #PROMPT('&Dither (Floyd-Steinberg)',CHECK),%mcDither,DEFAULT(0),AT(10)
    #ENDBOXED
    #BOXED('Size')
      #PROMPT('Resi&ze to:',DROP('Leave alone|A fixed width and height|A percentage|Fit a box, keep the ratio')),%mcSize,DEFAULT('Leave alone')
      #ENABLE(%mcSize='A fixed width and height' OR %mcSize='Fit a box, keep the ratio')
        #PROMPT('&Width:',SPIN(@n5,1,20000,10)),%mcW,DEFAULT(640)
        #PROMPT('&Height:',SPIN(@n5,1,20000,10)),%mcH,DEFAULT(480)
      #ENDENABLE
      #ENABLE(%mcSize='A percentage')
        #PROMPT('&Percent:',SPIN(@n5,1,2000,5)),%mcPct,DEFAULT(100)
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
  ImgWork.Quality = %mcQuality
  IF ImgWork.LoadFile(%mcFrom)
#INSERT(%miEmitMode,'ImgWork',%mcMode,%mcDither,128)
#INSERT(%miEmitSize,'ImgWork',%mcSize,%mcW,%mcH,%mcPct,'Best (area / bilinear)')
#IF(%mcResult)
#INSERT(%miEmitFmtResult,'ImgWork',%mcTo,%mcFmt,%mcResult)
  ELSE
    %mcResult = 0
#ELSE
#INSERT(%miEmitFmtCall,'ImgWork',%mcTo,%mcFmt)
#ENDIF
  END
  ImgWork.Kill()
#!#############################################################################
#!  GROUPS
#!#############################################################################
#!  Load the source the user picked.
#GROUP(%miEmitLoad)
#CASE(%miSource)
#OF('A fixed file name')
    IF NOT %miObject.LoadFile('%miFile')
#IF(%miWarn)
      MESSAGE('Could not read %miFile', '%Procedure', ICON:Exclamation)
#ENDIF
    END
#OF('A variable or expression')
    IF NOT %miObject.LoadFile(%miFileVar)
#IF(%miWarn)
      MESSAGE('Could not read ' & CLIP(%miFileVar), '%Procedure', ICON:Exclamation)
#ENDIF
    END
#OF('A test card')
    %miObject.TestCard(%miCardW, %miCardH)
#ENDCASE
#!
#!  Everything on the Colour and Shape tabs, in the order that makes sense:
#!  shape first, then tone, then the colour format last - so the palette is
#!  chosen from the pixels you actually end up with.
#GROUP(%miEmitRecipe)
    IF %miObject.Ok()
#CASE(%miRotate)
#OF('90 right')
      %miObject.RotateRight()
#OF('180')
      %miObject.Rotate180()
#OF('90 left')
      %miObject.RotateLeft()
#ENDCASE
#IF(%miMirror)
      %miObject.Mirror()
#ENDIF
#IF(%miFlip)
      %miObject.FlipVert()
#ENDIF
#IF(%miDegrees)
      %miObject.Rotate(%miDegrees, %miObject.ArgbOf(%miPad), 1, 1)
#ENDIF
#INSERT(%miEmitSize,%miObject,%miSize,%miNewW,%miNewH,%miPct,%miFilter)
#IF(%miBright OR %miContrast OR %miSatur)
      %miObject.Adjust(%miBright, %miContrast, %miSatur)
#ENDIF
#IF(%miGamma<>1.0)
      %miObject.Gamma(%miGamma)
#ENDIF
#IF(%miBlur)
      %miObject.Blur(%miBlur, 2)
#ENDIF
#IF(%miSharpen)
      %miObject.Sharpen(%miSharpen)
#ENDIF
#IF(%miInvert)
      %miObject.Invert()
#ENDIF
#IF(%miSepia)
      %miObject.Sepia()
#ENDIF
#INSERT(%miEmitMode,%miObject,%miMode,%miDither,%miThreshold)
    END
#!
#!  Colour format. Emitted as a whole line per choice so no symbol has to
#!  travel between groups.
#GROUP(%miEmitMode,%pObj,%pMode,%pDither,%pThreshold)
#CASE(%pMode)
#OF('32-bit true colour + alpha')
      %pObj.Convert(Img:True32, %pDither, %pThreshold)
#OF('24-bit true colour')
      %pObj.Convert(Img:True24, %pDither, %pThreshold)
#OF('16-bit high colour (5-6-5)')
      %pObj.Convert(Img:High16, %pDither, %pThreshold)
#OF('15-bit high colour (5-5-5)')
      %pObj.Convert(Img:High15, %pDither, %pThreshold)
#OF('256 colours')
      %pObj.Convert(Img:Pal256, %pDither, %pThreshold)
#OF('16 colours')
      %pObj.Convert(Img:Pal16, %pDither, %pThreshold)
#OF('256 greys')
      %pObj.Convert(Img:Grey256, %pDither, %pThreshold)
#OF('16 greys')
      %pObj.Convert(Img:Grey16, %pDither, %pThreshold)
#OF('4 greys')
      %pObj.Convert(Img:Grey4, %pDither, %pThreshold)
#OF('Black and white')
      %pObj.Convert(Img:Mono, %pDither, %pThreshold)
#OF('Web-safe 216')
      %pObj.Convert(Img:Web216, %pDither, %pThreshold)
#ENDCASE
#!
#!  Resize / fit.
#GROUP(%miEmitSize,%pObj,%pSize,%pW,%pH,%pPct,%pFilter)
#CASE(%pSize)
#OF('A fixed width and height')
#CASE(%pFilter)
#OF('Smooth (bilinear)')
      %pObj.Resize(%pW, %pH, Img:Smooth)
#OF('Fast (nearest)')
      %pObj.Resize(%pW, %pH, Img:Fast)
#ELSE
      %pObj.Resize(%pW, %pH, Img:Best)
#ENDCASE
#OF('A percentage')
#CASE(%pFilter)
#OF('Smooth (bilinear)')
      %pObj.Zoom(%pPct, Img:Smooth)
#OF('Fast (nearest)')
      %pObj.Zoom(%pPct, Img:Fast)
#ELSE
      %pObj.Zoom(%pPct, Img:Best)
#ENDCASE
#OF('Fit a box, keep the ratio')
      %pObj.Fit(%pW, %pH, Img:Contain, 0)
#ENDCASE
#!
#!  Draw into the IMAGE control with the fit the user picked.
#GROUP(%miEmitFit)
#CASE(%miFit)
#OF('Contain (no pad)')
      %miObject.Draw(%Window, %miControl, Img:Contain, %miObject.ArgbOf(%miPad))
#OF('Cover (crop)')
      %miObject.Draw(%Window, %miControl, Img:Cover, %miObject.ArgbOf(%miPad))
#OF('Stretch')
      %miObject.Draw(%Window, %miControl, Img:Stretch, %miObject.ArgbOf(%miPad))
#OF('Centred 1:1')
      %miObject.Draw(%Window, %miControl, Img:Centered, %miObject.ArgbOf(%miPad))
#ELSE
      %miObject.Draw(%Window, %miControl, Img:Proportional, %miObject.ArgbOf(%miPad))
#ENDCASE
#!
#!  Save a copy.
#GROUP(%miEmitSave)
    IF %miObject.Ok()
      %miObject.Quality = %miQuality
      %miObject.BmpBits = %miBmpBits
#INSERT(%miEmitFmtCall,%miObject,%miSaveTo,%miSaveFmt)
    END
#!
#!  One SaveFile line, with the format the user picked.
#GROUP(%miEmitFmtCall,%pObj,%pTo,%pFmt)
#CASE(%pFmt)
#OF('PNG')
      %pObj.SaveFile(%pTo, Img:Png)
#OF('JPEG')
      %pObj.SaveFile(%pTo, Img:Jpeg)
#OF('BMP')
      %pObj.SaveFile(%pTo, Img:Bmp)
#OF('GIF')
      %pObj.SaveFile(%pTo, Img:Gif)
#OF('TIFF')
      %pObj.SaveFile(%pTo, Img:Tiff)
#OF('Targa')
      %pObj.SaveFile(%pTo, Img:Tga)
#OF('PCX')
      %pObj.SaveFile(%pTo, Img:Pcx)
#OF('PNM')
      %pObj.SaveFile(%pTo, Img:Pnm)
#OF('QOI')
      %pObj.SaveFile(%pTo, Img:Qoi)
#ELSE
      %pObj.SaveFile(%pTo)
#ENDCASE
#!
#!  Same again, but the answer goes into the user's variable.
#GROUP(%miEmitFmtResult,%pObj,%pTo,%pFmt,%pRes)
#CASE(%pFmt)
#OF('PNG')
    %pRes = %pObj.SaveFile(%pTo, Img:Png)
#OF('JPEG')
    %pRes = %pObj.SaveFile(%pTo, Img:Jpeg)
#OF('BMP')
    %pRes = %pObj.SaveFile(%pTo, Img:Bmp)
#OF('GIF')
    %pRes = %pObj.SaveFile(%pTo, Img:Gif)
#OF('TIFF')
    %pRes = %pObj.SaveFile(%pTo, Img:Tiff)
#OF('Targa')
    %pRes = %pObj.SaveFile(%pTo, Img:Tga)
#OF('PCX')
    %pRes = %pObj.SaveFile(%pTo, Img:Pcx)
#OF('PNM')
    %pRes = %pObj.SaveFile(%pTo, Img:Pnm)
#OF('QOI')
    %pRes = %pObj.SaveFile(%pTo, Img:Qoi)
#ELSE
    %pRes = %pObj.SaveFile(%pTo)
#ENDCASE
#!-----------------------------------------------------------------------------
#! End of myImage template set
#!-----------------------------------------------------------------------------
