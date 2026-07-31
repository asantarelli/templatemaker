! ============================================================================
!  weatherWidget demo  -  the weather card, the way the template shows it at
!  start-up, plus the four buttons that exercise the rest of the class.
!
!  This is the hand-coded equivalent of what the weatherWidget template
!  generates. Every call is annotated with the embed point the template emits
!  it at.
!
!  Build:  msbuild WeatherDemo.cwproj -t:Build -p:Configuration=Debug
!                  -p:Platform=Win32 -p:ClarionBinPath="C:\clarion12\bin"
! ============================================================================
  PROGRAM

  INCLUDE('MyWeatherClass.INC'),ONCE
  INCLUDE('EQUATES.CLW'),ONCE

  MAP
  END

Weather        MyWeatherClass                               ! %GlobalData
LOC:City       CSTRING(65)
LOC:Imperial   BYTE
LOC:Spanish    BYTE
LOC:Days       BYTE
LOC:Auto       LONG
Wnd      WINDOW('weatherWidget demo - the weather at start-up'),AT(,,364,196),SYSTEM,GRAY, |
             FONT('Segoe UI',9,,FONT:regular,CHARSET:ANSI),CENTER,ICON(ICON:Application)
           PANEL,AT(0,0,364,38),USE(?Band),FILL(0603A1FH)
           STRING('weatherWidget'),AT(14,8),USE(?T1),FONT('Segoe UI',13,COLOR:White,FONT:bold),TRN
           STRING('The card the template puts up when your program starts.'),AT(14,24), |
             USE(?T2),FONT('Segoe UI',8,0D8C8B4H),TRN
           PROMPT('&City (blank = find me by IP):'),AT(20,56),USE(?P1)
           ENTRY(@s64),AT(160,54,180,10),USE(LOC:City)
           CHECK('&Imperial units - F, mph, in'),AT(160,70,150,10),USE(LOC:Imperial)
           CHECK('En espa<241>&ol'),AT(160,86,150,10),USE(LOC:Spanish)
           PROMPT('&Forecast days:'),AT(20,104),USE(?P4)
           SPIN(@n1),AT(160,102,40,10),USE(LOC:Days),RANGE(0,7),STEP(1)
           PROMPT('Close &automatically after (seconds, 0 = wait):'),AT(20,120),USE(?P5)
           SPIN(@n2),AT(160,118,40,10),USE(LOC:Auto),RANGE(0,60),STEP(1)
           PANEL,AT(20,140,324,1),USE(?Rule),FILL(00D4D0CCH)
           BUTTON('&Show the card'),AT(20,150,84,15),USE(?Show),DEFAULT
           BUTTON('&Refresh now'),AT(110,150,72,15),USE(?Force)
           BUTTON('For&get cache'),AT(188,150,66,15),USE(?Forget)
           BUTTON('&Close'),AT(290,150,54,15),USE(?Close),STD(STD:Close)
           STRING(''),AT(20,172,324,10),USE(?Status),FONT('Segoe UI',8,00808080H),TRN
         END
  CODE
!  WeatherDemo.exe /shots puts the documentation cards up one after another
!  and quits. Each one closes itself, so the screenshot driver only has to
!  capture - it never has to drive the window, which is what makes the images
!  reproducible (SendKeys cannot reliably reach a window it did not raise).
  IF UPPER(CLIP(LEFT(COMMAND('1')))) = '/SHOTS'
    DO Gallery
    RETURN
  END
  LOC:Days = 5
  LOC:Auto = 6                                              ! the start-up card counts itself out
  OPEN(Wnd)

! ---- what the template emits at %ProgramSetup -----------------------------
!  Configure the object, then put the card up. In a generated application
!  this runs before the frame opens, which is what makes it a start-up card.
  DO Configure
  Weather.Ask()
  DO ShowStatus

  ACCEPT
    CASE FIELD()
    OF ?Show
      IF EVENT() = EVENT:Accepted
        DO Configure
        Weather.Ask()                                       ! cache first, network only if stale
        DO ShowStatus
      END
    OF ?Force
      IF EVENT() = EVENT:Accepted
        DO Configure
        Weather.Refresh()                                   ! always hits the network
        Weather.Ask()
        DO ShowStatus
      END
    OF ?Forget
      IF EVENT() = EVENT:Accepted
        Weather.ForgetCache()
        ?Status{PROP:Text} = 'Cache cleared - the next fetch starts from nothing.'
        DISPLAY(?Status)
      END
    END
  END
  CLOSE(Wnd)
  RETURN

!  Everything the template writes from its prompts.
Configure ROUTINE
  IF LEN(CLIP(LOC:City))
    Weather.Locate = Wx:ByCity
    Weather.City   = CLIP(LOC:City)
  ELSE
    Weather.Locate = Wx:ByIP
  END
  Weather.Units     = CHOOSE(LOC:Imperial = 1,Wx:Imperial,Wx:Metric)
  Weather.Language  = CHOOSE(LOC:Spanish  = 1,Wx:Spanish,Wx:English)
  Weather.Days      = LOC:Days
  Weather.AutoClose = LOC:Auto
  Weather.OnFail    = Wx:FailShow                           ! a demo should say what went wrong
  Weather.Timeout   = 8

!  The three cards the documentation shows. Nothing here is special-cased for
!  the screenshots: it is the same object, configured three ways.
Gallery ROUTINE
  Weather.Persist   = 0                                     ! never answer from a cache
  Weather.Timeout   = 12
  Weather.Days      = 5
  Weather.AutoClose = 12                                    ! long enough to be captured
  Weather.OnFail    = Wx:FailShow

  Weather.Locate    = Wx:ByCity                             ! Spanish, Fahrenheit
  Weather.City      = 'Monterrey'
  Weather.Units     = Wx:Imperial
  Weather.Language  = Wx:Spanish
  Weather.Ask()

  Weather.City      = 'Tokyo'                               ! the small hours - a moon, not a sun
  Weather.Units     = Wx:Metric
  Weather.Ask()

  Weather.City      = 'Zzqqxx Nowhere'                      ! nothing to show, and it says so
  Weather.Language  = Wx:English
  Weather.Ask()

ShowStatus ROUTINE
  IF Weather.Ok
    ?Status{PROP:Text} = CLIP(Weather.Place) & ' - ' & CLIP(Weather.Describe(Weather.WCode)) & |
                         ' - ' & CLIP(Weather.TempText(Weather.Temp)) & CLIP(Weather.UnitTemp()) & |
                         CHOOSE(Weather.Stale = 1,'   (from the cache)','')
  ELSE
    ?Status{PROP:Text} = 'No reading: ' & CLIP(Weather.Err)
  END
  DISPLAY(?Status)
