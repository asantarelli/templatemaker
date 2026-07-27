! ============================================================================
!  myCalc demo  -  three numeric fields, each with a calculator button beside
!  it. This is the hand-coded equivalent of what the myCalcButton control
!  template generates for you.
!
!  Build:  msbuild CalcDemo.cwproj -t:Build -p:Configuration=Debug
!                  -p:Platform=Win32 -p:ClarionBinPath="C:\clarion12\bin"
! ============================================================================
  PROGRAM

  INCLUDE('CalcClass.INC'),ONCE
  INCLUDE('EQUATES.CLW'),ONCE

  MAP
  END

LOC:Qty        DECIMAL(11,2)
LOC:UnitPrice  DECIMAL(11,2)
LOC:Total      DECIMAL(13,2)
Calc1          CalcClass
Wnd      WINDOW('myCalc demo - a calculator beside every number'),AT(,,300,180),SYSTEM,GRAY, |
             FONT('Segoe UI',9,,FONT:regular,CHARSET:ANSI),CENTER,ICON(ICON:Application)
           PANEL,AT(0,0,300,38),USE(?Band),FILL(0603A1FH)
           STRING('Order line'),AT(14,8),USE(?T1),FONT('Segoe UI',13,COLOR:White,FONT:bold),TRN
           STRING('Press the calculator beside a field to work the number out.'),AT(14,24),USE(?T2), |
             FONT('Segoe UI',8,0D8C8B4H),TRN
           PROMPT('&Quantity:'),AT(20,56),USE(?P1)
           ENTRY(@n-11.2),AT(90,54,110,10),USE(LOC:Qty),RIGHT
           BUTTON(''),AT(204,53,14,12),USE(?CalcQty),ICON('calc16.ico'),TIP('Open the calculator')
           PROMPT('&Unit price:'),AT(20,74),USE(?P2)
           ENTRY(@n-11.2),AT(90,72,110,10),USE(LOC:UnitPrice),RIGHT
           BUTTON(''),AT(204,71,14,12),USE(?CalcPrice),ICON('calc16.ico'),TIP('Open the calculator')
           PROMPT('&Total:'),AT(20,92),USE(?P3)
           ENTRY(@n-13.2),AT(90,90,110,10),USE(LOC:Total),RIGHT
           BUTTON(''),AT(204,89,14,12),USE(?CalcTotal),ICON('calc16.ico'),TIP('Open the calculator')
           PANEL,AT(20,116,260,1),USE(?Rule),FILL(00D4D0CCH)
           STRING('The calculator reopens on whichever type you last used.'), |
             AT(20,124),USE(?Hint),FONT('Segoe UI',8,00808080H),TRN
           BUTTON('&Close'),AT(226,150,54,15),USE(?Close),STD(STD:Close)
         END
  CODE
  LOC:Qty       = 12
  LOC:UnitPrice = 48.5
  LOC:Total     = LOC:Qty * LOC:UnitPrice
  OPEN(Wnd)
  !  One object serves all three fields here. Give each field its own object
  !  (as the control template does) if you want them to remember separately.
  Calc1.Persist  = 1
  Calc1.Profile  = 'CalcDemo'
  Calc1.TaxRate  = 16
  Calc1.Decimals = 2
  ACCEPT
    CASE FIELD()
    OF ?CalcQty
      IF EVENT() = EVENT:Accepted
        Calc1.Title = 'Quantity'
        IF Calc1.AskFor(LOC:Qty) THEN DISPLAY(?LOC:Qty) .
      END
    OF ?CalcPrice
      IF EVENT() = EVENT:Accepted
        Calc1.Title = 'Unit price'
        IF Calc1.AskFor(LOC:UnitPrice) THEN DISPLAY(?LOC:UnitPrice) .
      END
    OF ?CalcTotal
      IF EVENT() = EVENT:Accepted
        Calc1.Title = 'Total'
        IF Calc1.AskFor(LOC:Total) THEN DISPLAY(?LOC:Total) .
      END
    END
  END
  CLOSE(Wnd)
  RETURN
