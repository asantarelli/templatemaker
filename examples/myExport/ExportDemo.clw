! ============================================================================
!  myExport demo  -  a plain Clarion LIST + QUEUE, and one Export button.
!
!  This is the hand-coded equivalent of what the myExportButton control
!  template generates for you. Everything the exporter needs it reads off the
!  LIST itself, so this demo never tells it about a single column.
!
!  Build:  msbuild ExportDemo.cwproj -t:Build -p:Configuration=Debug
!                  -p:Platform=Win32 -p:ClarionBinPath="C:\clarion12\bin"
! ============================================================================
  PROGRAM

  INCLUDE('ExportClass.INC'),ONCE
  INCLUDE('EQUATES.CLW'),ONCE
  INCLUDE('KEYCODES.CLW'),ONCE

  MAP
    SeedData()
  END

DemoQ    QUEUE,PRE(DQ)
Invoice    STRING(12)
Customer   STRING(32)
Country    STRING(18)
Qty        LONG
Unit       DECIMAL(9,2)
Total      DECIMAL(11,2)
Due        LONG
Paid       STRING(10)
         END

Exporter1  ExportClass
i          LONG
Msg        CSTRING(2049)
Wnd      WINDOW('myExport demo - export this list to anything'),AT(,,464,262),SYSTEM,GRAY,MAX, |
             RESIZE,FONT('Segoe UI',9,,FONT:regular,CHARSET:ANSI),CENTER,ICON(ICON:Application)
           PANEL,AT(0,0,464,38),USE(?Band),FILL(0603A1FH)
           STRING('Invoices'),AT(14,8),USE(?T1),FONT('Segoe UI',13,COLOR:White,FONT:bold),TRN
           STRING('Press Export and pick any of the seven formats.'),AT(14,24),USE(?T2), |
             FONT('Segoe UI',8,0D8C8B4H),TRN
           LIST,AT(10,48,444,168),USE(?List),FROM(DemoQ),VSCROLL,HVSCROLL,FONT('Segoe UI',9), |
             FORMAT('54L(2)|M~Invoice~@s12@#1#104L(2)|M~Customer~@s32@#2#62L(2)|M~Country~@s18@#3#' & |
                    '32R(2)|M~Qty~@n5@#4#48R(2)|M~Unit~@n-9.2@#5#58R(2)|M~Total~@n-11.2@#6#' & |
                    '56L(2)|M~Due~@d17@#7#40L(2)|M~Paid~@s10@#8#')
           BUTTON('&Export...'),AT(10,226,64,15),USE(?Export),DEFAULT,TIP('Choose a format and a file name')
           BUTTON('Write all &seven'),AT(78,226,72,15),USE(?All),TIP('Write one file per format, into this folder')
           STRING(''),AT(158,229,232,10),USE(?Info),FONT('Segoe UI',8,0757575H),TRN
           BUTTON('&Close'),AT(400,226,54,15),USE(?Close),STD(STD:Close)
         END
  CODE
  SeedData()
  OPEN(Wnd)
  ?Info{PROP:Text} = RECORDS(DemoQ) & ' rows.  Hide or re-order a column and export again - the file follows.'
  ACCEPT
    CASE FIELD()
    OF ?Export
      IF EVENT() = EVENT:Accepted
        !  Exactly what the control template emits: bind, describe, go.
        Exporter1.Init(?List, DemoQ)
        Exporter1.Title = 'Invoices'
        Exporter1.Run()                                   ! dialog -> format + file name -> write
      END
    OF ?All
      IF EVENT() = EVENT:Accepted
        Exporter1.Init(?List, DemoQ)
        Exporter1.Title        = 'Invoices'
        Exporter1.Confirm      = 0                        ! no popup per file
        Exporter1.OpenWhenDone = 0
        Msg = 'Written into' & '<13,10>' & CLIP(LONGPATH()) & '<13,10>'
        LOOP i = 1 TO Exp:Formats
          Exporter1.Fmt      = i
          !  CSV and CSV UTF-8 share the .csv extension, so number the files
          Exporter1.FileName = CLIP(LONGPATH()) & '\Invoices' & i & Exporter1.FormatExt(i)
          IF Exporter1.ExportQueue()
            Msg = CLIP(Msg) & '<13,10>   Invoices' & i & Exporter1.FormatExt(i) & |
                  '   (' & CLIP(LEFT(FORMAT(Exporter1.RowsOut,@n_7))) & ' rows)'
          ELSE
            Msg = CLIP(Msg) & '<13,10>   FAILED: ' & CLIP(Exporter1.ErrText)
          END
        END
        Exporter1.Confirm      = 1
        Exporter1.OpenWhenDone = 1
        MESSAGE(Msg,'All seven formats',ICON:Asterisk,BUTTON:OK,BUTTON:OK,0)
      END
    END
  END
  CLOSE(Wnd)
  RETURN


!  A handful of rows with the things that usually break an export: commas,
!  quotes, ampersands, angle brackets, accented letters and an embedded CRLF.
SeedData PROCEDURE()
  CODE
  FREE(DemoQ)
  DQ:Invoice='INV-1001' ; DQ:Customer='Acme, Inc.'            ; DQ:Country='United States'
  DQ:Qty=12 ; DQ:Unit=48.50   ; DQ:Due=TODAY()+7  ; DQ:Paid='Yes' ; DQ:Total=DQ:Qty*DQ:Unit ; ADD(DemoQ)
  DQ:Invoice='INV-1002' ; DQ:Customer='O''Brien & Sons'        ; DQ:Country='Ireland'
  DQ:Qty=3  ; DQ:Unit=1250.00 ; DQ:Due=TODAY()+14 ; DQ:Paid='No'  ; DQ:Total=DQ:Qty*DQ:Unit ; ADD(DemoQ)
  DQ:Invoice='INV-1003' ; DQ:Customer='Z' & CHR(252) & 'rich Handel GmbH' ; DQ:Country='Schweiz'
  DQ:Qty=40 ; DQ:Unit=19.95   ; DQ:Due=TODAY()+2  ; DQ:Paid='Yes' ; DQ:Total=DQ:Qty*DQ:Unit ; ADD(DemoQ)
  DQ:Invoice='INV-1004' ; DQ:Customer='Caf' & CHR(233) & ' <Central>'     ; DQ:Country='France'
  DQ:Qty=7  ; DQ:Unit=232.40  ; DQ:Due=TODAY()-3  ; DQ:Paid='Overdue' ; DQ:Total=DQ:Qty*DQ:Unit ; ADD(DemoQ)
  DQ:Invoice='INV-1005' ; DQ:Customer='Two Line<13,10>Trading Co'         ; DQ:Country='Canada'
  DQ:Qty=1  ; DQ:Unit=8999.00 ; DQ:Due=TODAY()+30 ; DQ:Paid='No'  ; DQ:Total=DQ:Qty*DQ:Unit ; ADD(DemoQ)
  DQ:Invoice='INV-1006' ; DQ:Customer='"Quoted" Supplies'      ; DQ:Country='Australia'
  DQ:Qty=25 ; DQ:Unit=64.00   ; DQ:Due=TODAY()+21 ; DQ:Paid='Yes' ; DQ:Total=DQ:Qty*DQ:Unit ; ADD(DemoQ)
  DQ:Invoice='INV-1007' ; DQ:Customer='Norrk' & CHR(246) & 'ping AB'      ; DQ:Country='Sverige'
  DQ:Qty=9  ; DQ:Unit=410.75  ; DQ:Due=TODAY()+10 ; DQ:Paid='No'  ; DQ:Total=DQ:Qty*DQ:Unit ; ADD(DemoQ)
  DQ:Invoice='INV-1008' ; DQ:Customer='Espa' & CHR(241) & 'a Distribuci' & CHR(243) & 'n' ; DQ:Country='Espa' & CHR(241) & 'a'
  DQ:Qty=60 ; DQ:Unit=7.20    ; DQ:Due=TODAY()+45 ; DQ:Paid='Yes' ; DQ:Total=DQ:Qty*DQ:Unit ; ADD(DemoQ)
  RETURN
