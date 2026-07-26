! ============================================================================
!  ExportClass - implementation.   See ExportClass.inc for the overview.
!
!  This file must be stored ANSI, with CRLF line endings.
! ============================================================================
  MEMBER()

  MAP
    MODULE('win32')
      exCreateFile(*CSTRING lpFileName, ULONG dwDesiredAccess, ULONG dwShareMode, LONG lpSecurityAttributes, ULONG dwCreationDisposition, ULONG dwFlagsAndAttributes, LONG hTemplateFile),LONG,RAW,PASCAL,NAME('CreateFileA')
      exWriteFile( LONG hFile, *STRING lpBuffer, ULONG nBytes, *ULONG lpWritten, LONG lpOverlapped ),LONG,RAW,PASCAL,NAME('WriteFile')
      exCloseHandle( LONG hObject ),LONG,RAW,PASCAL,PROC,NAME('CloseHandle')
      exMB2WC( UNSIGNED CodePage, ULONG dwFlags, *STRING lpMultiByteStr, SIGNED cbMultiByte, *STRING lpWideCharStr, SIGNED cchWideChar ),SIGNED,RAW,PASCAL,NAME('MultiByteToWideChar')
      exWC2MB( UNSIGNED CodePage, ULONG dwFlags, *STRING lpWideCharStr, SIGNED cchWideChar, *STRING lpMultiByteStr, SIGNED cbMultiByte, LONG lpDefaultChar, LONG lpUsedDefault ),SIGNED,RAW,PASCAL,NAME('WideCharToMultiByte')
      exShellExec( LONG hwnd, *CSTRING lpOperation, *CSTRING lpFile, *CSTRING lpParameters, *CSTRING lpDirectory, SIGNED nShowCmd ),ULONG,PASCAL,RAW,PROC,NAME('ShellExecuteA')
    END
  END

  INCLUDE('ExportClass.INC'),ONCE
  INCLUDE('EQUATES.CLW'),ONCE
  INCLUDE('KEYCODES.CLW'),ONCE

Exp:CP_ACP         EQUATE(0)                    ! the machine's ANSI code page
Exp:CP_UTF8        EQUATE(65001)
Exp:MinChunk       EQUATE(65536)                ! the buffers never start smaller than this
Exp:BOM            EQUATE('<239,187,191>')      ! UTF-8 byte order mark
Exp:CRLF           EQUATE('<13,10>')
Exp:TAB            EQUATE('<9>')

! ############################################################################
!  Lifetime
! ############################################################################
ExportClass.Construct PROCEDURE
  CODE
  SELF.Cols  &= NEW ExportColumnQueue
  SELF.Parts &= NEW ExportZipQueue
  SELF.Delim  = ','
  SELF.RowTag = 'Row'
  SELF.Title  = 'Data'


ExportClass.Destruct PROCEDURE
  CODE
  SELF.Kill()


ExportClass.Init PROCEDURE(SIGNED pList,*QUEUE pQ)
  CODE
  SELF.ListControl = pList
  SELF.Q          &= pQ
  SELF.ScanColumns()


ExportClass.Kill PROCEDURE
  CODE
  SELF.FreeBuffers()
  IF ~SELF.Cols &= NULL
    FREE(SELF.Cols)
    DISPOSE(SELF.Cols)
  END
  IF ~SELF.Parts &= NULL
    FREE(SELF.Parts)
    DISPOSE(SELF.Parts)
  END


! ############################################################################
!  Reading the LIST's own layout
! ############################################################################
!  Everything the export knows about its columns comes from the live control,
!  so a column the user hid, widened or dragged somewhere else is honoured.
ExportClass.ScanColumns PROCEDURE()
c    LONG,AUTO
f    LONG,AUTO
n    LONG,AUTO
p    LONG,AUTO
w    LONG,AUTO
ex   LONG,AUTO
ic   LONG,AUTO
it   LONG,AUTO
h    CSTRING(129)
  CODE
  IF SELF.Cols &= NULL THEN RETURN 0 .
  FREE(SELF.Cols)
  n = 0
  IF ~SELF.ListControl THEN RETURN 0 .
!  Every PROPLIST read goes through a LONG first: a property returns a STRING,
!  and the STRING '0' is logically TRUE - so ~?List{PROPLIST:Width,c} never
!  fires on a hidden column, and a plain ?List{PROPLIST:Icon,c} is always true.
  LOOP c = 1 TO 512
    ex = SELF.ListControl{PROPLIST:Exists,c}
    IF ~ex THEN BREAK .
    f = SELF.ListControl{PROPLIST:FieldNo,c}
    IF ~f THEN CYCLE .                                    ! a decoration, not a data column
    w = SELF.ListControl{PROPLIST:Width,c}
    IF SELF.VisibleOnly
      ic = SELF.ListControl{PROPLIST:Icon,c}
      it = SELF.ListControl{PROPLIST:IconTrn,c}
      IF ic OR it THEN CYCLE .                            ! an icon number means nothing in a file
      IF ~w       THEN CYCLE .                            ! the user hid this column
    END
    n += 1
    h = CLIP(SELF.ListControl{PROPLIST:Header,c})
    LOOP p = 1 TO LEN(h)                                  ! '|' wraps a heading on screen
      IF h[p] = '|' THEN h[p] = ' ' .
    END
    h = CLIP(LEFT(h))
    IF ~h THEN h = 'Column' & n .
    SELF.Cols.ColNo = c
    SELF.Cols.FldNo = f
    SELF.Cols.Head  = h
    SELF.Cols.Pic   = CLIP(SELF.ListControl{PROPLIST:Picture,c})
    SELF.Cols.Width = w
    SELF.Cols.Tag   = SELF.SafeTag(h,n)
    SELF.Cols.IsNum = 0
    IF ~SELF.Q &= NULL                                    ! a real number, shown as a number?
      IF ~ISSTRING(WHAT(SELF.Q,f))
        IF ~SELF.Cols.Pic
          SELF.Cols.IsNum = 1
        ELSIF UPPER(SUB(SELF.Cols.Pic,1,2)) = '@N'        ! @D / @T / @P / @S / @E stay text
          SELF.Cols.IsNum = 1
        END
      END
    END
    ADD(SELF.Cols)
  END
  RETURN n


ExportClass.Columns PROCEDURE()
  CODE
  IF SELF.Cols &= NULL THEN RETURN 0 .
  RETURN RECORDS(SELF.Cols)


! ############################################################################
!  Format descriptions
! ############################################################################
ExportClass.FormatName PROCEDURE(LONG pFmt)
  CODE
  CASE pFmt
  OF Exp:CSV     ; RETURN 'CSV - comma separated (*.csv)'
  OF Exp:CSVUTF8 ; RETURN 'CSV - comma separated, UTF-8 (*.csv)'
  OF Exp:TSV     ; RETURN 'TSV - tab separated (*.tsv)'
  OF Exp:XML     ; RETURN 'XML document (*.xml)'
  OF Exp:JSON    ; RETURN 'JSON document (*.json)'
  OF Exp:XLSX    ; RETURN 'Excel workbook (*.xlsx)'
  OF Exp:HTML    ; RETURN 'HTML table (*.html)'
  END
  RETURN ''


ExportClass.FormatExt PROCEDURE(LONG pFmt)
  CODE
  CASE pFmt
  OF Exp:CSV     ; RETURN '.csv'
  OF Exp:CSVUTF8 ; RETURN '.csv'
  OF Exp:TSV     ; RETURN '.tsv'
  OF Exp:XML     ; RETURN '.xml'
  OF Exp:JSON    ; RETURN '.json'
  OF Exp:XLSX    ; RETURN '.xlsx'
  OF Exp:HTML    ; RETURN '.html'
  END
  RETURN '.txt'


ExportClass.FormatMask PROCEDURE(LONG pFmt)
  CODE
  CASE pFmt
  OF Exp:CSV OROF Exp:CSVUTF8
    RETURN 'Comma separated|*.csv|Text files|*.txt|All files|*.*'
  OF Exp:TSV
    RETURN 'Tab separated|*.tsv|Text files|*.txt|All files|*.*'
  OF Exp:XML
    RETURN 'XML documents|*.xml|All files|*.*'
  OF Exp:JSON
    RETURN 'JSON documents|*.json|All files|*.*'
  OF Exp:XLSX
    RETURN 'Excel workbooks|*.xlsx|All files|*.*'
  OF Exp:HTML
    RETURN 'Web pages|*.html;*.htm|All files|*.*'
  END
  RETURN 'All files|*.*'


ExportClass.Allowed PROCEDURE(LONG pFmt)
  CODE
  IF pFmt < 1 OR pFmt > Exp:Formats THEN RETURN 0 .
  IF ~SELF.Allow THEN RETURN 1 .                          ! nothing configured = everything
  RETURN CHOOSE(BAND(SELF.Allow,BSHIFT(1,pFmt-1)) <> 0,1,0)


ExportClass.SuggestName PROCEDURE()
s   CSTRING(129)
i   LONG,AUTO
  CODE
  s = CLIP(LEFT(SELF.Title))
  IF ~s THEN s = 'Export' .
  LOOP i = 1 TO LEN(s)
    IF INSTRING(s[i],'\/:*?"<>|. ',1,1) THEN s[i] = '_' .
  END
  RETURN CLIP(s) & '_' & FORMAT(YEAR(TODAY()),@n04) & FORMAT(MONTH(TODAY()),@n02) & FORMAT(DAY(TODAY()),@n02)


!  Make the extension agree with the chosen format - so switching format in the
!  dialog silently retargets 'Customers.csv' to 'Customers.xlsx'.
ExportClass.ForceExt PROCEDURE(LONG pFmt)
n    CSTRING(261)
i    LONG,AUTO
cut  LONG(0)
  CODE
  n = CLIP(LEFT(SELF.FileName))
  IF ~n THEN RETURN .
  LOOP i = LEN(n) TO 1 BY -1
    IF n[i] = '\' OR n[i] = '/' THEN BREAK .
    IF n[i] = '.' THEN cut = i; BREAK .
  END
  IF cut THEN n = SUB(n,1,cut-1) .
  SELF.FileName = CLIP(n) & SELF.FormatExt(pFmt)


ExportClass.Note PROCEDURE(STRING pText,STRING pTitle,LONG pIcon)
  CODE
  MESSAGE(pText,pTitle,pIcon,BUTTON:OK,BUTTON:OK,0)


! ############################################################################
!  The run-time dialog:  which format, and where does it go
! ############################################################################
ExportClass.Ask PROCEDURE()
FmtQ           QUEUE,PRE(FQ)
FName            STRING(40)
FId              LONG
               END
i              LONG,AUTO
Sel            LONG(1)
Ok             BYTE(0)
ExpFile        CSTRING(261)
ExpHdrs        BYTE
ExpPics        BYTE
ExpOpen        BYTE
ExpWnd WINDOW('Export data'),AT(,,290,196),FONT('Segoe UI',9,,FONT:regular,CHARSET:ANSI),CENTER,GRAY,SYSTEM,MODAL
         PANEL,AT(0,0,290,36),USE(?ExpBand),FILL(0603A1FH)
         STRING('Export data'),AT(14,8),USE(?ExpT1),FONT('Segoe UI',12,COLOR:White,FONT:bold),TRN
         STRING('Choose a format, then the folder and file name.'),AT(14,23),USE(?ExpT2),FONT('Segoe UI',8,0D8C8B4H),TRN
         PROMPT('&Format:'),AT(14,53),USE(?ExpP1)
         LIST,AT(70,51,206,10),USE(?ExpFmt),VSCROLL,DROP(8),FROM(FmtQ),FORMAT('190L(2)@s40@')
         PROMPT('File &name:'),AT(14,73),USE(?ExpP2)
         ENTRY(@s255),AT(70,71,188,10),USE(ExpFile),TIP('Where the exported file will be written')
         BUTTON('...'),AT(260,71,16,10),USE(?ExpPick),TIP('Choose the folder and the file name')
         CHECK('Include the column &headings'),AT(70,91),USE(ExpHdrs)
         CHECK('Apply each column''s &picture'),AT(70,103),USE(ExpPics),TIP('Off = raw values, on = exactly what the list shows')
         CHECK('&Open the file when it is done'),AT(70,115),USE(ExpOpen)
         PANEL,AT(14,136,262,1),USE(?ExpRule),FILL(0D4D0CCH)
         STRING(''),AT(14,144,262,10),USE(?ExpInfo),FONT('Segoe UI',8,0757575H),TRN
         BUTTON('&Export'),AT(162,170,54,14),USE(?ExpOk),DEFAULT
         BUTTON('Cancel'),AT(220,170,54,14),USE(?ExpCancel)
       END
  CODE
  IF ~SELF.Columns() THEN SELF.ScanColumns() .
  IF ~SELF.Columns()
    SELF.Note('There is nothing to export - this list has no data columns.','Export',ICON:Exclamation)
    RETURN 0
  END
  LOOP i = 1 TO Exp:Formats
    IF ~SELF.Allowed(i) THEN CYCLE .
    FQ:FName = SELF.FormatName(i)
    FQ:FId   = i
    ADD(FmtQ)
  END
  IF ~RECORDS(FmtQ)
    SELF.Note('No export formats have been enabled.','Export',ICON:Exclamation)
    RETURN 0
  END
  LOOP i = 1 TO RECORDS(FmtQ)                             ! preselect the last format used
    GET(FmtQ,i)
    IF FQ:FId = SELF.Fmt
      Sel = i
      BREAK
    END
  END
  GET(FmtQ,Sel)
  SELF.Fmt = FQ:FId
  IF ~CLIP(SELF.FileName)
    SELF.FileName = CLIP(LONGPATH()) & '\' & SELF.SuggestName()
  END
  SELF.ForceExt(SELF.Fmt)
  ExpFile = SELF.FileName
  ExpHdrs = SELF.Headers
  ExpPics = SELF.Pictures
  ExpOpen = SELF.OpenWhenDone
  OPEN(ExpWnd)
  ?ExpFmt{PROP:Selected} = Sel
  ?ExpInfo{PROP:Text} = SELF.Columns() & ' column(s) will be exported, exactly as the list shows them.'
  ACCEPT
    CASE EVENT()
    OF EVENT:OpenWindow
      SELECT(?ExpFmt)
    END
    CASE FIELD()
    OF ?ExpFmt
      CASE EVENT()
      OF EVENT:Accepted OROF EVENT:NewSelection
        i = CHOICE(?ExpFmt)
        IF i
          GET(FmtQ,i)
          IF ~ERRORCODE() AND FQ:FId <> SELF.Fmt
            SELF.Fmt      = FQ:FId
            SELF.FileName = ExpFile
            SELF.ForceExt(SELF.Fmt)                       ! retarget the extension for them
            ExpFile       = SELF.FileName
            DISPLAY(?ExpFile)
          END
        END
      END
    OF ?ExpPick
      CASE EVENT()
      OF EVENT:Accepted
        SELF.FileName = ExpFile
        IF SELF.AskFileName()
          ExpFile = SELF.FileName
          DISPLAY(?ExpFile)
        END
      END
    OF ?ExpOk
      CASE EVENT()
      OF EVENT:Accepted
        IF ~CLIP(LEFT(ExpFile))
          SELF.Note('Please choose a file name first.','Export',ICON:Exclamation)
          SELECT(?ExpFile)
          CYCLE
        END
        Ok = 1
        POST(EVENT:CloseWindow)
      END
    OF ?ExpCancel
      CASE EVENT()
      OF EVENT:Accepted
        POST(EVENT:CloseWindow)
      END
    END
  END
  CLOSE(ExpWnd)
  IF Ok
    SELF.FileName     = CLIP(LEFT(ExpFile))
    SELF.Headers      = ExpHdrs
    SELF.Pictures     = ExpPics
    SELF.OpenWhenDone = ExpOpen
    SELF.ForceExt(SELF.Fmt)
  END
  RETURN Ok


ExportClass.AskFileName PROCEDURE()
Name  CSTRING(261)
  CODE
  Name = CLIP(LEFT(SELF.FileName))
  IF ~Name THEN Name = SELF.SuggestName() & SELF.FormatExt(SELF.Fmt) .
  IF FILEDIALOG('Export to ' & SELF.FormatName(SELF.Fmt),Name,SELF.FormatMask(SELF.Fmt), |
                FILE:Save + FILE:KeepDir + FILE:LongName + FILE:AddExtension)
    SELF.FileName = Name
    SELF.ForceExt(SELF.Fmt)
    RETURN 1
  END
  RETURN 0


! ############################################################################
!  One cell
! ############################################################################
ExportClass.HeaderText PROCEDURE(LONG pCol)
  CODE
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN '' .
  RETURN CLIP(SELF.Cols.Head)


ExportClass.CellText PROCEDURE(LONG pCol)
Fld  ANY
  CODE
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN '' .
  Fld &= WHAT(SELF.Q,SELF.Cols.FldNo)
  IF SELF.Pictures AND SELF.Cols.Pic
    RETURN CLIP(LEFT(FORMAT(Fld,SELF.Cols.Pic)))
  END
  RETURN CLIP(LEFT(Fld))


!  The unformatted value, for JSON numbers and real Excel numeric cells.
ExportClass.CellNumber PROCEDURE(LONG pCol)
Fld  ANY
s    CSTRING(65)
  CODE
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN '0' .
  Fld &= WHAT(SELF.Q,SELF.Cols.FldNo)
  s = CLIP(LEFT(Fld))
  IF ~s THEN RETURN '0' .
  RETURN s


! ############################################################################
!  Writing:  StartFile -> AddRow (many) -> EndFile
! ############################################################################
ExportClass.StartFile PROCEDURE()
i     LONG,AUTO
n     LONG,AUTO
w     LONG,AUTO
dlm   STRING(1)
  CODE
  SELF.ErrCode = 0
  SELF.ErrText = ''
  SELF.RowsOut = 0
  SELF.Started = 0
  IF ~SELF.Columns() THEN SELF.ScanColumns() .
  n = SELF.Columns()
  IF ~n
    SELF.ErrCode = 1
    SELF.ErrText = 'There is nothing to export - this list has no data columns.'
    RETURN 0
  END
  IF ~CLIP(LEFT(SELF.FileName))
    SELF.ErrCode = 2
    SELF.ErrText = 'No file name was given.'
    RETURN 0
  END
  SELF.FreeBuffers()
  SELF.Need(Exp:MinChunk)
  SELF.Started = 1
  dlm = SELF.Sep()

  CASE SELF.Fmt
!  ---- the delimited family ------------------------------------------------
  OF Exp:CSV OROF Exp:CSVUTF8 OROF Exp:TSV
    IF SELF.Headers
      LOOP i = 1 TO n
        IF i > 1 THEN SELF.Cat(dlm) .
        IF SELF.Fmt = Exp:TSV
          SELF.CatFlatField(SELF.HeaderText(i))
        ELSE
          SELF.CatCsvField(SELF.HeaderText(i),dlm)
        END
      END
      SELF.Cat(Exp:CRLF)
    END

!  ---- XML -----------------------------------------------------------------
  OF Exp:XML
    SELF.Cat('<?xml version="1.0" encoding="UTF-8"?>' & Exp:CRLF)
    SELF.Cat('<' & SELF.SafeTag(SELF.Title,0) & '>' & Exp:CRLF)

!  ---- JSON ----------------------------------------------------------------
  OF Exp:JSON
    SELF.Cat('[')

!  ---- HTML ----------------------------------------------------------------
  OF Exp:HTML
    SELF.Cat('<!DOCTYPE html>' & Exp:CRLF & '<html><head><meta charset="utf-8">' & Exp:CRLF)
    SELF.Cat('<title>')
    SELF.CatHtmlText(CLIP(SELF.Title))
    SELF.Cat('</title>' & Exp:CRLF)
    SELF.Cat('<style>' & |
             'body{font:14px "Segoe UI",Arial,sans-serif;color:#23303b;background:#f5f7fa;margin:24px}' & |
             'h1{font-size:19px;font-weight:600;color:#1f3a60;margin:0 0 4px}' & |
             'p.meta{margin:0 0 18px;color:#6b7a88;font-size:12px}' & |
             'table{border-collapse:collapse;background:#fff;box-shadow:0 1px 3px rgba(31,58,96,.12);font-size:13px}' & |
             'th{background:#1f3a60;color:#fff;text-align:left;font-weight:600;padding:8px 12px;white-space:nowrap}' & |
             'td{padding:6px 12px;border-bottom:1px solid #e3e9ef}' & |
             'tr:nth-child(even) td{background:#f7f9fc}' & |
             'td.n{text-align:right;font-variant-numeric:tabular-nums}' & |
             '</style></head><body>' & Exp:CRLF)
    SELF.Cat('<h1>')
    SELF.CatHtmlText(CLIP(SELF.Title))
    SELF.Cat('</h1>' & Exp:CRLF)
    SELF.Cat('<p class="meta">Exported ' & FORMAT(TODAY(),@d17) & ' ' & FORMAT(CLOCK(),@t4) & '</p>' & Exp:CRLF)
    SELF.Cat('<table>' & Exp:CRLF)
    IF SELF.Headers
      SELF.Cat('<thead><tr>')
      LOOP i = 1 TO n
        SELF.Cat('<th>')
        SELF.CatHtmlText(SELF.HeaderText(i))
        SELF.Cat('</th>')
      END
      SELF.Cat('</tr></thead>' & Exp:CRLF)
    END
    SELF.Cat('<tbody>' & Exp:CRLF)

!  ---- Excel .xlsx : the worksheet part -----------------------------------
  OF Exp:XLSX
    SELF.Cat('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' & Exp:CRLF)
    SELF.Cat('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
    IF SELF.Headers                                       ! keep the heading row on screen
      SELF.Cat('<sheetViews><sheetView workbookViewId="0">' & |
               '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>' & |
               '</sheetView></sheetViews>')
    END
    SELF.Cat('<sheetFormatPr defaultRowHeight="15"/>')
    SELF.Cat('<cols>')                                    ! carry the on-screen widths across
    LOOP i = 1 TO n
      GET(SELF.Cols,i)
      w = SELF.Cols.Width / 4 + 2
      IF w < 6  THEN w = 6  .
      IF w > 70 THEN w = 70 .
      SELF.Cat('<col min="' & i & '" max="' & i & '" width="' & w & '" customWidth="1"/>')
    END
    SELF.Cat('</cols><sheetData>')
    IF SELF.Headers
      SELF.Cat('<row r="1">')
      LOOP i = 1 TO n
        SELF.Cat('<c r="' & SELF.ColRef(i) & '1" s="1" t="inlineStr"><is><t>')
        SELF.CatXmlText(SELF.HeaderText(i))
        SELF.Cat('</t></is></c>')
      END
      SELF.Cat('</row>')
    END
  END
  RETURN 1


!  Append whatever is in the QUEUE BUFFER right now.
ExportClass.AddRow PROCEDURE
i     LONG,AUTO
n     LONG,AUTO
num   BYTE,AUTO
rw    LONG,AUTO
dlm   STRING(1)
  CODE
  IF ~SELF.Started THEN RETURN .
  n = SELF.Columns()
  IF ~n THEN RETURN .
  dlm = SELF.Sep()

  CASE SELF.Fmt
  OF Exp:CSV OROF Exp:CSVUTF8 OROF Exp:TSV
    LOOP i = 1 TO n
      IF i > 1 THEN SELF.Cat(dlm) .
      IF SELF.Fmt = Exp:TSV
        SELF.CatFlatField(SELF.CellText(i))
      ELSE
        SELF.CatCsvField(SELF.CellText(i),dlm)
      END
    END
    SELF.Cat(Exp:CRLF)

  OF Exp:XML
    SELF.Cat(' <' & CLIP(SELF.RowTag) & '>' & Exp:CRLF)
    LOOP i = 1 TO n
      GET(SELF.Cols,i)
      SELF.Cat('  <' & CLIP(SELF.Cols.Tag) & '>')
      SELF.CatXmlText(SELF.CellText(i))
      GET(SELF.Cols,i)
      SELF.Cat('</' & CLIP(SELF.Cols.Tag) & '>' & Exp:CRLF)
    END
    SELF.Cat(' </' & CLIP(SELF.RowTag) & '>' & Exp:CRLF)

  OF Exp:JSON
    IF SELF.RowsOut THEN SELF.Cat(',') .
    SELF.Cat(Exp:CRLF & '  {')
    LOOP i = 1 TO n
      GET(SELF.Cols,i)
      num = SELF.Cols.IsNum
      IF i > 1 THEN SELF.Cat(',') .
      SELF.Cat('"')
      SELF.CatJsonText(SELF.HeaderText(i))
      SELF.Cat('":')
      IF num                                              ! a number stays a JSON number
        SELF.Cat(SELF.CellNumber(i))
      ELSE
        SELF.Cat('"')
        SELF.CatJsonText(SELF.CellText(i))
        SELF.Cat('"')
      END
    END
    SELF.Cat('}')

  OF Exp:HTML
    SELF.Cat('<tr>')
    LOOP i = 1 TO n
      GET(SELF.Cols,i)
      IF SELF.Cols.IsNum
        SELF.Cat('<td class="n">')
      ELSE
        SELF.Cat('<td>')
      END
      SELF.CatHtmlText(SELF.CellText(i))
      SELF.Cat('</td>')
    END
    SELF.Cat('</tr>' & Exp:CRLF)

  OF Exp:XLSX
    rw = SELF.RowsOut + 1
    IF SELF.Headers THEN rw += 1 .
    SELF.Cat('<row r="' & rw & '">')
    LOOP i = 1 TO n
      GET(SELF.Cols,i)
      num = SELF.Cols.IsNum
      IF num                                              ! a true numeric cell: sums, sorts, charts
        SELF.Cat('<c r="' & SELF.ColRef(i) & rw & '"><v>' & SELF.CellNumber(i) & '</v></c>')
      ELSE
        SELF.Cat('<c r="' & SELF.ColRef(i) & rw & '" t="inlineStr"><is><t>')
        SELF.CatXmlText(SELF.CellText(i))
        SELF.Cat('</t></is></c>')
      END
    END
    SELF.Cat('</row>')
  END
  SELF.RowsOut += 1


ExportClass.EndFile PROCEDURE()
n     LONG,AUTO
last  LONG,AUTO
ok    BYTE(0)
  CODE
  IF ~SELF.Started
    IF SELF.ErrCode AND SELF.Confirm
      SELF.Note(SELF.ErrText,'Export failed',ICON:Hand)
    END
    RETURN 0
  END
  SELF.Started = 0
  n = SELF.Columns()

  CASE SELF.Fmt
  OF Exp:XML
    SELF.Cat('</' & SELF.SafeTag(SELF.Title,0) & '>' & Exp:CRLF)
  OF Exp:JSON
    SELF.Cat(Exp:CRLF & ']' & Exp:CRLF)
  OF Exp:HTML
    SELF.Cat('</tbody></table>' & Exp:CRLF)
    SELF.Cat('<p class="meta">' & CLIP(LEFT(FORMAT(SELF.RowsOut,@n_11))) & ' row(s)</p>' & Exp:CRLF)
    SELF.Cat('</body></html>' & Exp:CRLF)
  OF Exp:XLSX
    SELF.Cat('</sheetData>')
    IF SELF.Headers AND SELF.RowsOut
      last = SELF.RowsOut + 1
      SELF.Cat('<autoFilter ref="A1:' & SELF.ColRef(n) & last & '"/>')
    END
    SELF.Cat('</worksheet>')
  END

  CASE SELF.Fmt
  OF Exp:XLSX
    ok = SELF.XlsxWrite()
  OF Exp:CSVUTF8 OROF Exp:XML OROF Exp:JSON OROF Exp:HTML
    SELF.ToUTF8(SELF.Buf,SELF.BufLen)                     ! these formats declare UTF-8
    IF SELF.Fmt = Exp:CSVUTF8                             ! Excel needs the BOM to trust it
      SELF.BufLen = 0
      SELF.Cat(Exp:BOM)
      SELF.Need(SELF.U8Len)
      SELF.Buf[SELF.BufLen+1 : SELF.BufLen+SELF.U8Len] = SELF.U8[1 : SELF.U8Len]
      SELF.BufLen += SELF.U8Len
      ok = SELF.WriteDisk(SELF.FileName,SELF.Buf,SELF.BufLen)
    ELSE
      ok = SELF.WriteDisk(SELF.FileName,SELF.U8,SELF.U8Len)
    END
  ELSE
    ok = SELF.WriteDisk(SELF.FileName,SELF.Buf,SELF.BufLen)
  END

  SELF.FreeBuffers()
  IF ~ok
    IF SELF.Confirm THEN SELF.Note(SELF.ErrText,'Export failed',ICON:Hand) .
    RETURN 0
  END
  IF SELF.Confirm
    SELF.Note(CLIP(LEFT(FORMAT(SELF.RowsOut,@n_11))) & ' row(s) exported to' & Exp:CRLF & Exp:CRLF & |
              CLIP(SELF.FileName),'Export complete',ICON:Asterisk)
  END
  IF SELF.OpenWhenDone THEN SELF.ShellOpen(SELF.FileName) .
  RETURN 1


!  The whole queue, start to finish - right for a hand-coded LIST, and for a
!  browse whose records are all loaded.
ExportClass.ExportQueue PROCEDURE()
i  LONG,AUTO
  CODE
  IF ~SELF.StartFile() THEN RETURN 0 .
  IF ~SELF.Q &= NULL
    LOOP i = 1 TO RECORDS(SELF.Q)
      GET(SELF.Q,i)
      IF ERRORCODE() THEN BREAK .
      SELF.AddRow()
    END
  END
  RETURN SELF.EndFile()


ExportClass.Run PROCEDURE()
  CODE
  IF ~SELF.Ask() THEN RETURN 0 .
  RETURN SELF.ExportQueue()


! ############################################################################
!  Growable buffers
! ############################################################################
ExportClass.Need PROCEDURE(LONG pAdd)
cap  LONG,AUTO
nb   &STRING
  CODE
  IF SELF.BufLen + pAdd <= SELF.BufCap THEN RETURN .
  cap = SELF.BufCap
  IF cap < Exp:MinChunk THEN cap = Exp:MinChunk .
  LOOP WHILE cap < SELF.BufLen + pAdd
    cap += cap
  END
  nb &= NEW STRING(cap)
  IF SELF.BufLen THEN nb[1 : SELF.BufLen] = SELF.Buf[1 : SELF.BufLen] .
  IF ~SELF.Buf &= NULL THEN DISPOSE(SELF.Buf) .
  SELF.Buf   &= nb
  SELF.BufCap = cap


ExportClass.Cat PROCEDURE(STRING pText)
l  LONG,AUTO
  CODE
  l = LEN(pText)
  IF l <= 0 THEN RETURN .
  SELF.Need(l)
  SELF.Buf[SELF.BufLen+1 : SELF.BufLen+l] = pText[1 : l]
  SELF.BufLen += l


ExportClass.ArcNeed PROCEDURE(LONG pAdd)
cap  LONG,AUTO
nb   &STRING
  CODE
  IF SELF.ArcLen + pAdd <= SELF.ArcCap THEN RETURN .
  cap = SELF.ArcCap
  IF cap < Exp:MinChunk THEN cap = Exp:MinChunk .
  LOOP WHILE cap < SELF.ArcLen + pAdd
    cap += cap
  END
  nb &= NEW STRING(cap)
  IF SELF.ArcLen THEN nb[1 : SELF.ArcLen] = SELF.Arc[1 : SELF.ArcLen] .
  IF ~SELF.Arc &= NULL THEN DISPOSE(SELF.Arc) .
  SELF.Arc   &= nb
  SELF.ArcCap = cap


ExportClass.ArcCat PROCEDURE(STRING pText)
l  LONG,AUTO
  CODE
  l = LEN(pText)
  IF l <= 0 THEN RETURN .
  SELF.ArcNeed(l)
  SELF.Arc[SELF.ArcLen+1 : SELF.ArcLen+l] = pText[1 : l]
  SELF.ArcLen += l


ExportClass.U8Need PROCEDURE(LONG pSize)
  CODE
  IF pSize <= SELF.U8Cap THEN RETURN .
  IF ~SELF.U8 &= NULL THEN DISPOSE(SELF.U8) .
  SELF.U8   &= NEW STRING(pSize)
  SELF.U8Cap = pSize


ExportClass.FreeBuffers PROCEDURE
  CODE
  IF ~SELF.Buf &= NULL THEN DISPOSE(SELF.Buf) .
  IF ~SELF.Arc &= NULL THEN DISPOSE(SELF.Arc) .
  IF ~SELF.U8  &= NULL THEN DISPOSE(SELF.U8)  .
  SELF.BufLen = 0 ; SELF.BufCap = 0
  SELF.ArcLen = 0 ; SELF.ArcCap = 0
  SELF.U8Len  = 0 ; SELF.U8Cap  = 0
  IF ~SELF.Parts &= NULL THEN FREE(SELF.Parts) .


ExportClass.Sep PROCEDURE()
  CODE
  IF SELF.Fmt = Exp:TSV THEN RETURN Exp:TAB .
  IF SELF.Delim         THEN RETURN SELF.Delim .
  RETURN ','


! ############################################################################
!  Escaping.  Each of these walks the value, copies the longest clean run in
!  one go and only then emits an escape - so ordinary data costs one Cat.
! ############################################################################
ExportClass.CatCsvField PROCEDURE(STRING pText,STRING pDelim)
l     LONG,AUTO
i     LONG,AUTO
run   LONG,AUTO
quote BYTE(0)
c     STRING(1)
  CODE
  l = LEN(pText)
  IF ~l THEN RETURN .
  LOOP i = 1 TO l                                         ! RFC 4180: when must it be quoted
    c = pText[i]
    IF c = '"' OR c = pDelim OR c = '<13>' OR c = '<10>'
      quote = 1
      BREAK
    END
  END
  IF pText[1] = ' ' OR pText[l] = ' ' THEN quote = 1 .
  IF ~quote
    SELF.Cat(pText[1 : l])
    RETURN
  END
  SELF.Cat('"')
  run = 1
  LOOP i = 1 TO l
    IF pText[i] = '"'
      IF i > run THEN SELF.Cat(pText[run : i-1]) .
      SELF.Cat('""')                                      ! a quote is doubled
      run = i + 1
    END
  END
  IF l >= run THEN SELF.Cat(pText[run : l]) .
  SELF.Cat('"')


!  TSV has no quoting convention every reader agrees on, so nothing that would
!  break a row is allowed through.
ExportClass.CatFlatField PROCEDURE(STRING pText)
l    LONG,AUTO
i    LONG,AUTO
run  LONG,AUTO
c    STRING(1)
  CODE
  l = LEN(pText)
  IF ~l THEN RETURN .
  run = 1
  LOOP i = 1 TO l
    c = pText[i]
    IF c = '<9>' OR c = '<13>' OR c = '<10>'
      IF i > run THEN SELF.Cat(pText[run : i-1]) .
      IF ~(c = '<10>' AND i > 1 AND pText[i-1] = '<13>')  ! a CRLF pair is one space, not two
        SELF.Cat(' ')
      END
      run = i + 1
    END
  END
  IF l >= run THEN SELF.Cat(pText[run : l]) .


ExportClass.CatXmlText PROCEDURE(STRING pText)
l    LONG,AUTO
i    LONG,AUTO
run  LONG,AUTO
v    LONG,AUTO
esc  CSTRING(9)
  CODE
  l = LEN(pText)
  IF ~l THEN RETURN .
  run = 1
  LOOP i = 1 TO l
    v   = VAL(pText[i])
    esc = ''
    CASE v
    OF 38 ; esc = '&amp;'
    OF 60 ; esc = '&lt;'
    OF 62 ; esc = '&gt;'
    OF 34 ; esc = '&quot;'
    OF 39 ; esc = '&apos;'
    ELSE
      IF v < 32 AND v <> 9 AND v <> 10 AND v <> 13 THEN esc = ' ' . ! illegal in XML 1.0
    END
    IF esc
      IF i > run THEN SELF.Cat(pText[run : i-1]) .
      SELF.Cat(esc)
      run = i + 1
    END
  END
  IF l >= run THEN SELF.Cat(pText[run : l]) .


ExportClass.CatJsonText PROCEDURE(STRING pText)
l    LONG,AUTO
i    LONG,AUTO
run  LONG,AUTO
v    LONG,AUTO
esc  CSTRING(9)
  CODE
  l = LEN(pText)
  IF ~l THEN RETURN .
  run = 1
  LOOP i = 1 TO l
    v   = VAL(pText[i])
    esc = ''
    CASE v
    OF 34 ; esc = '\"'
    OF 92 ; esc = '\\'
    OF  8 ; esc = '\b'
    OF 12 ; esc = '\f'
    OF 10 ; esc = '\n'
    OF 13 ; esc = '\r'
    OF  9 ; esc = '\t'
    ELSE
      IF v < 32 THEN esc = '\u00' & SUB('0123456789abcdef',BSHIFT(v,-4)+1,1) & SUB('0123456789abcdef',BAND(v,15)+1,1) .
    END
    IF esc
      IF i > run THEN SELF.Cat(pText[run : i-1]) .
      SELF.Cat(esc)
      run = i + 1
    END
  END
  IF l >= run THEN SELF.Cat(pText[run : l]) .


ExportClass.CatHtmlText PROCEDURE(STRING pText)
l    LONG,AUTO
i    LONG,AUTO
run  LONG,AUTO
esc  CSTRING(9)
c    STRING(1)
  CODE
  l = LEN(pText)
  IF ~l THEN RETURN .
  run = 1
  LOOP i = 1 TO l
    c   = pText[i]
    esc = ''
    CASE c
    OF '&' ; esc = '&amp;'
    OF '<' ; esc = '&lt;'
    OF '>' ; esc = '&gt;'
    OF '"' ; esc = '&quot;'
    END
    IF esc
      IF i > run THEN SELF.Cat(pText[run : i-1]) .
      SELF.Cat(esc)
      run = i + 1
    END
  END
  IF l >= run THEN SELF.Cat(pText[run : l]) .


! ############################################################################
!  Names
! ############################################################################
!  'Cust Name' -> 'Cust_Name'.  XML element names cannot hold spaces or start
!  with a digit, and JSON keys read better the same way.
ExportClass.SafeTag PROCEDURE(STRING pText,LONG pCol)
s   CSTRING(65)
o   CSTRING(65)
i   LONG,AUTO
c   STRING(1)
  CODE
  s = CLIP(LEFT(pText))
  o = ''
  LOOP i = 1 TO LEN(s)
    IF LEN(o) >= 60 THEN BREAK .
    c = s[i]
    IF (c >= 'A' AND c <= 'Z') OR (c >= 'a' AND c <= 'z') OR (c >= '0' AND c <= '9') OR c = '_'
      o = o & c
    ELSIF LEN(o) AND o[LEN(o)] <> '_'
      o = o & '_'
    END
  END
  LOOP WHILE LEN(o) AND o[LEN(o)] = '_'
    o = SUB(o,1,LEN(o)-1)
  END
  IF ~LEN(o)
    IF pCol THEN RETURN 'Column' & pCol .
    RETURN 'Data'
  END
  IF o[1] >= '0' AND o[1] <= '9' THEN o = '_' & o .
  RETURN o


!  Excel: 31 characters, and none of  []:*?/\
ExportClass.SheetName PROCEDURE(STRING pText)
s  CSTRING(65)
i  LONG,AUTO
  CODE
  s = CLIP(LEFT(pText))
  IF ~s THEN s = 'Data' .
  LOOP i = 1 TO LEN(s)
    IF INSTRING(s[i],'[]:*?/\',1,1) THEN s[i] = ' ' .
  END
  s = CLIP(LEFT(s))
  IF LEN(s) > 31 THEN s = SUB(s,1,31) .
  IF ~s THEN s = 'Data' .
  RETURN s


ExportClass.ColRef PROCEDURE(LONG pCol)
n  LONG,AUTO
r  CSTRING(5)
m  LONG,AUTO
  CODE
  n = pCol
  r = ''
  IF n < 1 THEN RETURN 'A' .
  LOOP WHILE n > 0
    m = n - 1
    r = CHR(65 + m - INT(m/26)*26) & r
    n = INT(m/26)
  END
  RETURN r


! ############################################################################
!  Text encoding
! ############################################################################
ExportClass.IsAscii PROCEDURE(*STRING pData,LONG pLen)
i  LONG,AUTO
  CODE
  LOOP i = 1 TO pLen
    IF VAL(pData[i]) > 127 THEN RETURN 0 .
  END
  RETURN 1


!  ANSI (the machine's code page) -> UTF-8, into SELF.U8 / SELF.U8Len.
!  Pure-ASCII text is already valid UTF-8, so the common case copies straight
!  through and never touches the API.
ExportClass.ToUTF8 PROCEDURE(*STRING pData,LONG pLen)
nW  SIGNED,AUTO
nU  SIGNED,AUTO
W   &STRING
  CODE
  SELF.U8Len = 0
  IF pLen <= 0
    SELF.U8Need(16)
    RETURN
  END
  IF SELF.IsAscii(pData,pLen)
    SELF.U8Need(pLen)
    SELF.U8[1 : pLen] = pData[1 : pLen]
    SELF.U8Len = pLen
    RETURN
  END
  W &= NEW STRING(pLen * 2 + 4)                           ! 1 byte in -> at most 1 wide char
  nW = exMB2WC(Exp:CP_ACP,0,pData,pLen,W,pLen)
  IF nW > 0
    SELF.U8Need(pLen * 3 + 8)                             ! 1 wide char -> at most 3 UTF-8 bytes
    nU = exWC2MB(Exp:CP_UTF8,0,W,nW,SELF.U8,SELF.U8Cap,0,0)
    IF nU > 0 THEN SELF.U8Len = nU .
  END
  DISPOSE(W)
  IF ~SELF.U8Len                                          ! conversion refused - ship the bytes as-is
    SELF.U8Need(pLen)
    SELF.U8[1 : pLen] = pData[1 : pLen]
    SELF.U8Len = pLen
  END


! ############################################################################
!  Disk
! ############################################################################
ExportClass.WriteDisk PROCEDURE(STRING pFile,*STRING pData,LONG pLen)
h     LONG,AUTO
nm    CSTRING(261)
wr    ULONG,AUTO
  CODE
  nm = CLIP(LEFT(pFile))
  h  = exCreateFile(nm,40000000h,0,0,2,80h,0)             ! GENERIC_WRITE, CREATE_ALWAYS, NORMAL
  IF h = 0 OR h = -1
    SELF.ErrCode = 10
    SELF.ErrText = 'Could not create' & Exp:CRLF & Exp:CRLF & CLIP(nm) & Exp:CRLF & Exp:CRLF & |
                   'Check the folder exists and that the file is not already open.'
    RETURN 0
  END
  IF pLen > 0
    wr = 0
    IF ~exWriteFile(h,pData,pLen,wr,0) OR wr <> pLen
      exCloseHandle(h)
      SELF.ErrCode = 11
      SELF.ErrText = 'Could not write to' & Exp:CRLF & Exp:CRLF & CLIP(nm) & Exp:CRLF & Exp:CRLF & |
                     'The disk may be full or write protected.'
      RETURN 0
    END
  END
  exCloseHandle(h)
  RETURN 1


ExportClass.ShellOpen PROCEDURE(STRING pFile)
op  CSTRING(8)
fn  CSTRING(261)
pm  CSTRING(2)
dr  CSTRING(2)
  CODE
  op = 'open'
  fn = CLIP(LEFT(pFile))
  pm = ''
  dr = ''
  IF ~fn THEN RETURN .
  exShellExec(0,op,fn,pm,dr,1)                            ! SW_SHOWNORMAL


! ############################################################################
!  ZIP  (the .xlsx container)
! ############################################################################
ExportClass.CrcInit PROCEDURE
i  LONG,AUTO
j  LONG,AUTO
c  ULONG,AUTO
  CODE
  LOOP i = 0 TO 255
    c = i
    LOOP j = 1 TO 8
      IF BAND(c,1)
        c = BXOR(BSHIFT(c,-1),0EDB88320h)
      ELSE
        c = BSHIFT(c,-1)
      END
    END
    SELF.CrcTab[i+1] = c
  END
  SELF.CrcReady = 1


ExportClass.CRC32 PROCEDURE(*STRING pData,LONG pLen)
crc  ULONG,AUTO
i    LONG,AUTO
  CODE
  IF ~SELF.CrcReady THEN SELF.CrcInit() .
  crc = 0FFFFFFFFh
  LOOP i = 1 TO pLen
    crc = BXOR(BSHIFT(crc,-8),SELF.CrcTab[ BAND(BXOR(crc,VAL(pData[i])),0FFh) + 1 ])
  END
  RETURN BXOR(crc,0FFFFFFFFh)


ExportClass.Le16 PROCEDURE(ULONG pVal)
G  GROUP
V    USHORT
   END
S  STRING(2),OVER(G)
  CODE
  G.V = pVal
  RETURN S


ExportClass.Le32 PROCEDURE(ULONG pVal)
G  GROUP
V    ULONG
   END
S  STRING(4),OVER(G)
  CODE
  G.V = pVal
  RETURN S


!  One archive member:  local header + the bytes.  Its central-directory entry
!  is remembered in SELF.Parts and written by ZipFinish.
ExportClass.ZipAdd PROCEDURE(STRING pName,*STRING pData,LONG pLen)
nm    CSTRING(65)
crc   ULONG,AUTO
ofs   ULONG,AUTO
dt    ULONG,AUTO
tm    ULONG,AUTO
secs  LONG,AUTO
hh    LONG,AUTO
mi    LONG,AUTO
ss    LONG,AUTO
dy    LONG,AUTO
meth  USHORT(0)
clen  LONG,AUTO
cbuf  &STRING
  COMPILE('_EndDeflateObj_',_ExportDeflate_)
Deflater  CompressClass
  _EndDeflateObj_
  CODE
  nm   = CLIP(pName)
  crc  = SELF.CRC32(pData,pLen)
  ofs  = SELF.ArcLen
  clen = pLen
  cbuf &= NULL
  dy   = TODAY()
  secs = INT((CLOCK() - 1) / 100)
  hh   = INT(secs / 3600)
  mi   = INT((secs - hh * 3600) / 60)
  ss   = secs - hh * 3600 - mi * 60
  tm   = BSHIFT(hh,11) + BSHIFT(mi,5) + INT(ss / 2)
  dt   = BSHIFT(YEAR(dy) - 1980,9) + BSHIFT(MONTH(dy),5) + DAY(dy)

  COMPILE('_EndDeflateRun_',_ExportDeflate_)
  IF pLen > 0
    Deflater.Format = Cmp:Raw                             ! raw DEFLATE is ZIP method 8
    Deflater.Level  = 6
    cbuf &= NEW STRING(Deflater.MaxCompressed(pLen))
    clen  = Deflater.Compress(pData,pLen,cbuf)
    IF clen > 0 AND clen < pLen
      meth = 8
    ELSE                                                  ! it did not help - store it
      DISPOSE(cbuf)
      clen = pLen
      meth = 0
    END
  END
  _EndDeflateRun_

  SELF.ArcCat('PK<3,4>')
  SELF.ArcCat(SELF.Le16(20))                              ! version needed to extract
  SELF.ArcCat(SELF.Le16(0))                               ! general purpose flags
  SELF.ArcCat(SELF.Le16(meth))
  SELF.ArcCat(SELF.Le16(tm))
  SELF.ArcCat(SELF.Le16(dt))
  SELF.ArcCat(SELF.Le32(crc))
  SELF.ArcCat(SELF.Le32(clen))
  SELF.ArcCat(SELF.Le32(pLen))
  SELF.ArcCat(SELF.Le16(LEN(nm)))
  SELF.ArcCat(SELF.Le16(0))                               ! extra field length
  SELF.ArcCat(nm)
  IF clen > 0
    SELF.ArcNeed(clen)
    IF meth = 8
      SELF.Arc[SELF.ArcLen+1 : SELF.ArcLen+clen] = cbuf[1 : clen]
    ELSE
      SELF.Arc[SELF.ArcLen+1 : SELF.ArcLen+clen] = pData[1 : clen]
    END
    SELF.ArcLen += clen
  END
  IF ~cbuf &= NULL THEN DISPOSE(cbuf) .

  SELF.Parts.EName  = nm
  SELF.Parts.ECrc   = crc
  SELF.Parts.ECSize = clen
  SELF.Parts.EUSize = pLen
  SELF.Parts.EOfs   = ofs
  SELF.Parts.EMeth  = meth
  ADD(SELF.Parts)


ExportClass.ZipFinish PROCEDURE
i     LONG,AUTO
cdOfs ULONG,AUTO
cdLen ULONG,AUTO
  CODE
  cdOfs = SELF.ArcLen
  LOOP i = 1 TO RECORDS(SELF.Parts)
    GET(SELF.Parts,i)
    SELF.ArcCat('PK<1,2>')
    SELF.ArcCat(SELF.Le16(20))                            ! version made by
    SELF.ArcCat(SELF.Le16(20))                            ! version needed
    SELF.ArcCat(SELF.Le16(0))                             ! flags
    SELF.ArcCat(SELF.Le16(SELF.Parts.EMeth))
    SELF.ArcCat(SELF.Le16(0))                             ! time  - kept 0 here, set in the local header
    SELF.ArcCat(SELF.Le16(0))                             ! date
    SELF.ArcCat(SELF.Le32(SELF.Parts.ECrc))
    SELF.ArcCat(SELF.Le32(SELF.Parts.ECSize))
    SELF.ArcCat(SELF.Le32(SELF.Parts.EUSize))
    SELF.ArcCat(SELF.Le16(LEN(SELF.Parts.EName)))
    SELF.ArcCat(SELF.Le16(0))                             ! extra
    SELF.ArcCat(SELF.Le16(0))                             ! comment
    SELF.ArcCat(SELF.Le16(0))                             ! disk number
    SELF.ArcCat(SELF.Le16(0))                             ! internal attributes
    SELF.ArcCat(SELF.Le32(0))                             ! external attributes
    SELF.ArcCat(SELF.Le32(SELF.Parts.EOfs))
    SELF.ArcCat(SELF.Parts.EName)
  END
  cdLen = SELF.ArcLen - cdOfs
  SELF.ArcCat('PK<5,6>')                                  ! end of central directory
  SELF.ArcCat(SELF.Le16(0))
  SELF.ArcCat(SELF.Le16(0))
  SELF.ArcCat(SELF.Le16(RECORDS(SELF.Parts)))
  SELF.ArcCat(SELF.Le16(RECORDS(SELF.Parts)))
  SELF.ArcCat(SELF.Le32(cdLen))
  SELF.ArcCat(SELF.Le32(cdOfs))
  SELF.ArcCat(SELF.Le16(0))                               ! archive comment length


! ############################################################################
!  .xlsx  -  a real OOXML workbook, assembled here
! ############################################################################
!  The worksheet is already sitting in SELF.Buf (StartFile/AddRow/EndFile built
!  it).  The five remaining parts are small and fixed, so they are put together
!  here and everything is zipped in one pass.
!  tmp builds each part, then it is copied into the fixed STRING the ZipAdd /
!  ToUTF8 *STRING parameters need (a CSTRING will not bind to *STRING).
ExportClass.XlsxWrite PROCEDURE()
tmp   CSTRING(4097)
part  STRING(4096)
plen  LONG,AUTO
sheet CSTRING(65)
  CODE
  IF SELF.Parts &= NULL THEN RETURN 0 .
  FREE(SELF.Parts)
  SELF.ArcLen = 0
  sheet = SELF.SheetName(SELF.Title)

  tmp = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' & |
         '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' & |
         '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' & |
         '<Default Extension="xml" ContentType="application/xml"/>' & |
         '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' & |
         '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' & |
         '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' & |
         '</Types>'
  plen = LEN(tmp)
  part = tmp
  SELF.ZipAdd('[Content_Types].xml',part,plen)

  tmp = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' & |
         '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' & |
         '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' & |
         '</Relationships>'
  plen = LEN(tmp)
  part = tmp
  SELF.ZipAdd('_rels/.rels',part,plen)

  tmp = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' & |
         '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"' & |
         ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' & |
         '<sheets><sheet name="' & sheet & '" sheetId="1" r:id="rId1"/></sheets></workbook>'
  plen = LEN(tmp)
  part = tmp
  SELF.ToUTF8(part,plen)                                  ! the sheet name may not be ASCII
  SELF.ZipAdd('xl/workbook.xml',SELF.U8,SELF.U8Len)

  tmp = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' & |
         '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' & |
         '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>' & |
         '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>' & |
         '</Relationships>'
  plen = LEN(tmp)
  part = tmp
  SELF.ZipAdd('xl/_rels/workbook.xml.rels',part,plen)

  tmp = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' & |
         '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' & |
         '<fonts count="2">' & |
         '<font><sz val="11"/><color theme="1"/><name val="Calibri"/><family val="2"/></font>' & |
         '<font><b/><sz val="11"/><color theme="1"/><name val="Calibri"/><family val="2"/></font>' & |
         '</fonts>' & |
         '<fills count="2"><fill><patternFill patternType="none"/></fill>' & |
         '<fill><patternFill patternType="gray125"/></fill></fills>' & |
         '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>' & |
         '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' & |
         '<cellXfs count="2">' & |
         '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>' & |
         '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>' & |
         '</cellXfs>' & |
         '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>' & |
         '</styleSheet>'
  plen = LEN(tmp)
  part = tmp
  SELF.ZipAdd('xl/styles.xml',part,plen)

  SELF.ToUTF8(SELF.Buf,SELF.BufLen)                       ! the sheet, last and largest
  IF ~SELF.Buf &= NULL                                    ! release it before the archive grows
    DISPOSE(SELF.Buf)
    SELF.BufLen = 0
    SELF.BufCap = 0
  END
  SELF.ZipAdd('xl/worksheets/sheet1.xml',SELF.U8,SELF.U8Len)
  IF ~SELF.U8 &= NULL
    DISPOSE(SELF.U8)
    SELF.U8Len = 0
    SELF.U8Cap = 0
  END
  SELF.ZipFinish()
  RETURN SELF.WriteDisk(SELF.FileName,SELF.Arc,SELF.ArcLen)
