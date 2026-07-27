! ============================================================================
!  myCalendar demo  -  three date fields with a calendar button beside them:
!  one plain date, one from/to range served by a single button, and one date
!  that will not accept a weekend or anything in the past.
!
!  This is the hand-coded equivalent of what the myCalendarButton control
!  template generates for you.
!
!  Build:  msbuild CalendarDemo.cwproj -t:Build -p:Configuration=Debug
!                  -p:Platform=Win32 -p:ClarionBinPath="C:\clarion12\bin"
! ============================================================================
  PROGRAM

  INCLUDE('CalendarClass.INC'),ONCE
  INCLUDE('EQUATES.CLW'),ONCE

  MAP
  END

LOC:Booked     DATE
LOC:From       DATE
LOC:To         DATE
LOC:Delivery   DATE
LOC:Nights     LONG
Cal1           CalendarClass                              ! the single date
Cal2           CalendarClass                              ! the from/to range
Cal3           CalendarClass                              ! working days only
Wnd      WINDOW('myCalendar demo - a date picker beside every date'),AT(,,320,208),SYSTEM,GRAY, |
             FONT('Segoe UI',9,,FONT:regular,CHARSET:ANSI),CENTER,ICON(ICON:Application)
           PANEL,AT(0,0,320,38),USE(?Band),FILL(0603A1FH)
           STRING('Reservation'),AT(14,8),USE(?T1),FONT('Segoe UI',13,COLOR:White,FONT:bold),TRN
           STRING('Press the calendar beside a field to pick the date.'),AT(14,24),USE(?T2), |
             FONT('Segoe UI',8,0D8C8B4H),TRN
           PROMPT('&Booked on:'),AT(20,56),USE(?P1)
           ENTRY(@d17),AT(96,54,70,10),USE(LOC:Booked)
           BUTTON(''),AT(170,53,14,12),USE(?CalBooked),ICON('cal16.ico'),TIP('Open the calendar')
           STRING('one date, one month on screen'),AT(192,56),USE(?H1), |
             FONT('Segoe UI',8,00808080H),TRN
           PROMPT('&Stay:'),AT(20,78),USE(?P2)
           ENTRY(@d17),AT(96,76,70,10),USE(LOC:From)
           STRING('to'),AT(170,78),USE(?P2b)
           ENTRY(@d17),AT(182,76,70,10),USE(LOC:To)
           BUTTON(''),AT(256,75,14,12),USE(?CalStay),ICON('cal16.ico'),TIP('Drag out the nights')
           STRING(''),AT(20,92,240,10),USE(?Nights),FONT('Segoe UI',8,0603A1FH),TRN
           PROMPT('&Delivery:'),AT(20,112),USE(?P3)
           ENTRY(@d17),AT(96,110,70,10),USE(LOC:Delivery)
           BUTTON(''),AT(170,109,14,12),USE(?CalDelivery),ICON('cal16.ico'),TIP('Working days only')
           STRING('no weekends, nothing before today'),AT(192,112),USE(?H3), |
             FONT('Segoe UI',8,00808080H),TRN
           PANEL,AT(20,140,280,1),USE(?Rule),FILL(00D4D0CCH)
           STRING('One button can fill in two fields: drag across the days to sweep out'), |
             AT(20,148),USE(?Hint1),FONT('Segoe UI',8,00808080H),TRN
           STRING('a period. The view you leave it on comes back next time.'), |
             AT(20,158),USE(?Hint2),FONT('Segoe UI',8,00808080H),TRN
           BUTTON('&Close'),AT(246,178,54,15),USE(?Close),STD(STD:Close)
         END
  CODE
  LOC:Booked   = TODAY()
  LOC:From     = TODAY() + 14
  LOC:To       = TODAY() + 21
  LOC:Delivery = 0
  OPEN(Wnd)

  !  One date. Everything else is left at the class defaults.
  Cal1.Title      = 'Booked on'
  Cal1.Persist    = 1
  Cal1.Profile    = 'Booked'

  !  A range, over three months so a long stay is easy to sweep out.
  Cal2.Selection  = Cal:Range
  Cal2.Months     = Cal:ThreeMonths
  Cal2.Orient     = Cal:Across
  Cal2.FirstDay   = Cal:Monday
  Cal2.ShowWeekNo = 1
  Cal2.Title      = 'Stay'
  Cal2.Persist    = 1
  Cal2.Profile    = 'Stay'

  !  Working days from today onwards.
  Cal3.NoWeekends = 1
  Cal3.MinDate    = TODAY()
  Cal3.MaxDate    = TODAY() + 90
  Cal3.FirstDay   = Cal:Monday
  Cal3.Title      = 'Delivery'
  Cal3.Persist    = 1
  Cal3.Profile    = 'Delivery'

  DO ShowNights
  ACCEPT
    CASE FIELD()
    OF ?CalBooked
      IF EVENT() = EVENT:Accepted
        IF Cal1.AskFor(LOC:Booked) THEN DISPLAY(?LOC:Booked) .
      END
    OF ?CalStay
      IF EVENT() = EVENT:Accepted
        IF Cal2.AskRange(LOC:From,LOC:To)
          DISPLAY(?LOC:From)
          DISPLAY(?LOC:To)
          DO ShowNights
        END
      END
    OF ?CalDelivery
      IF EVENT() = EVENT:Accepted
        IF Cal3.AskFor(LOC:Delivery) THEN DISPLAY(?LOC:Delivery) .
      END
    END
  END
  CLOSE(Wnd)
  RETURN

ShowNights ROUTINE
  IF LOC:From AND LOC:To
    LOC:Nights = LOC:To - LOC:From
    ?Nights{PROP:Text} = CLIP(LEFT(LOC:Nights)) & ' nights, ' & |
                         CLIP(LEFT(LOC:Nights + 1)) & ' days'
  ELSE
    ?Nights{PROP:Text} = ''
  END
  DISPLAY(?Nights)
