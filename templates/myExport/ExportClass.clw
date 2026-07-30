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
      exModuleFile( LONG hModule, *CSTRING lpFilename, ULONG nSize ),ULONG,RAW,PASCAL,NAME('GetModuleFileNameA')
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
!
!  Init calls this before every export, but the user may have renamed columns
!  or un-ticked some in the dialog - and those edits must survive to the next
!  export. So it fingerprints the LIST's layout first and only rebuilds when
!  the layout has actually changed. Rescan() forces it.
ExportClass.ScanColumns PROCEDURE()
c    LONG,AUTO
f    LONG,AUTO
n    LONG,AUTO
p    LONG,AUTO
w    LONG,AUTO
ex   LONG,AUTO
ic   LONG,AUTO
it   LONG,AUTO
sg   CSTRING(1025)
h    CSTRING(129)
  CODE
  IF SELF.Cols &= NULL THEN RETURN 0 .
  IF ~SELF.ListControl
    FREE(SELF.Cols)
    SELF.Sig = ''
    RETURN 0
  END
  sg = SELF.LayoutSig()
  IF sg = SELF.Sig AND RECORDS(SELF.Cols)
    RETURN RECORDS(SELF.Cols)                             ! same layout - keep the user's choices
  END
  FREE(SELF.Cols)
  n = 0
!  Every PROPLIST read goes through a LONG first: a property returns a STRING,
!  and the STRING '0' is logically TRUE - so ~?List{PROPLIST:Width,c} never
!  fires on a hidden column, and a plain ?List{PROPLIST:Icon,c} is always true.
  LOOP c = 1 TO 512
    ex = SELF.ListControl{PROPLIST:Exists,c}
    IF ~ex THEN BREAK .
    f = SELF.ListControl{PROPLIST:FieldNo,c}
    IF ~f THEN CYCLE .                                    ! a decoration, not a data column
    w  = SELF.ListControl{PROPLIST:Width,c}
    ic = SELF.ListControl{PROPLIST:Icon,c}
    it = SELF.ListControl{PROPLIST:IconTrn,c}
    n += 1
    h = CLIP(SELF.ListControl{PROPLIST:Header,c})
    LOOP p = 1 TO LEN(h)                                  ! '|' wraps a heading on screen
      IF h[p] = '|' THEN h[p] = ' ' .
    END
    h = CLIP(LEFT(h))
    IF ~h THEN h = SELF.Txt(Txt:ColumnWord) & n .
    SELF.Cols.ColNo   = c
    SELF.Cols.FldNo   = f
    SELF.Cols.Width   = w
    SELF.Cols.HeadDef = h
    SELF.Cols.PicDef  = CLIP(SELF.ListControl{PROPLIST:Picture,c})
    SELF.Cols.Head    = SELF.Cols.HeadDef
    SELF.Cols.Pic     = SELF.Cols.PicDef
!   Hidden and icon columns are listed but start un-ticked, so the dialog can
!   still offer them - VisibleOnly picks the starting state, not the contents.
    SELF.Cols.Use = 1
    IF SELF.VisibleOnly
      IF ic OR it OR ~w THEN SELF.Cols.Use = 0 .
    END
    ADD(SELF.Cols)
    SELF.Classify(n)
  END
  SELF.Sig = sg
  RETURN n


ExportClass.Rescan PROCEDURE()
  CODE
  SELF.Sig = ''                                           ! forget the layout we matched against
  RETURN SELF.ScanColumns()


!  A fingerprint of the LIST's format. Column count, field numbers and widths
!  are enough: if those match, it is the same layout and the user's renames,
!  picture overrides and tick marks still apply.
ExportClass.LayoutSig PROCEDURE()
c    LONG,AUTO
ex   LONG,AUTO
sg   CSTRING(1025)
one  CSTRING(41)
  CODE
  sg = ''
  IF ~SELF.ListControl THEN RETURN sg .
  LOOP c = 1 TO 512
    ex = SELF.ListControl{PROPLIST:Exists,c}
    IF ~ex THEN BREAK .
    one = c & ':' & SELF.ListControl{PROPLIST:FieldNo,c} & ':' & SELF.ListControl{PROPLIST:Width,c} & ';'
    IF LEN(sg) + LEN(one) > 1024 THEN BREAK .
    sg = sg & one
  END
  RETURN sg


!  Tag (the XML/JSON name) and IsNum both follow the CURRENT heading and
!  picture, so they are re-derived whenever either is edited.
ExportClass.Classify PROCEDURE(LONG pCol)
  CODE
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN .
  SELF.Cols.Tag   = SELF.SafeTag(SELF.Cols.Head,pCol)
  SELF.Cols.IsNum = 0
  IF ~SELF.Q &= NULL                                      ! a real number, shown as a number?
    IF ~ISSTRING(WHAT(SELF.Q,SELF.Cols.FldNo))
      IF ~SELF.Cols.Pic
        SELF.Cols.IsNum = 1
      ELSIF UPPER(SUB(SELF.Cols.Pic,1,2)) = '@N'          ! @D / @T / @P / @S / @E stay text
        SELF.Cols.IsNum = 1
      END
    END
  END
  PUT(SELF.Cols)


ExportClass.Columns PROCEDURE()
  CODE
  IF SELF.Cols &= NULL THEN RETURN 0 .
  RETURN RECORDS(SELF.Cols)


ExportClass.Selected PROCEDURE()
i  LONG,AUTO
n  LONG(0)
  CODE
  IF SELF.Cols &= NULL THEN RETURN 0 .
  LOOP i = 1 TO RECORDS(SELF.Cols)
    GET(SELF.Cols,i)
    IF ~ERRORCODE() AND SELF.Cols.Use THEN n += 1 .
  END
  RETURN n


! ############################################################################
!  Remembering the last export
! ############################################################################
!  Everything the user chose in the dialog - the format, the folder, the three
!  option ticks and the whole column list - is written to an INI section when
!  an export succeeds, and read back the next time the dialog opens.
!
!  The saved columns are keyed by position and guarded by SigKey(), a short
!  fingerprint of the LIST's layout. If the browse gains, loses or re-sizes a
!  column the fingerprint no longer matches and the stale column settings are
!  ignored - the format, folder and flags still come back.

!  IniFile if you set one, otherwise <the running exe>.INI beside the program.
ExportClass.IniPath PROCEDURE()
nm  CSTRING(261)
n   ULONG,AUTO
i   LONG,AUTO
cut LONG(0)
  CODE
  IF CLIP(LEFT(SELF.IniFile)) THEN RETURN CLIP(LEFT(SELF.IniFile)) .
  nm = ''
  n  = exModuleFile(0,nm,260)
  IF ~n THEN RETURN '' .                                  ! no path: GETINI falls back to WIN.INI
  LOOP i = LEN(nm) TO 1 BY -1
    IF nm[i] = '\' OR nm[i] = '/' THEN BREAK .
    IF nm[i] = '.' THEN cut = i; BREAK .
  END
  IF cut THEN nm = SUB(nm,1,cut-1) .
  RETURN CLIP(nm) & '.INI'


ExportClass.IniSection PROCEDURE()
p  CSTRING(65)
  CODE
  p = CLIP(LEFT(SELF.Profile))
  IF ~p THEN p = SELF.SafeTag(SELF.Title,0) .
  RETURN 'myExport_' & p


!  A short, INI-safe stand-in for the layout fingerprint: the column count plus
!  a rolling checksum kept small enough that a LONG never overflows.
ExportClass.SigKey PROCEDURE()
sg   CSTRING(1025)
i    LONG,AUTO
sum  LONG(0)
  CODE
  sg = SELF.LayoutSig()
  LOOP i = 1 TO LEN(sg)
    sum = (sum * 31 + VAL(sg[i])) % 99991
  END
  RETURN SELF.Columns() & 'x' & sum


ExportClass.FolderOf PROCEDURE(STRING pPath)
n  CSTRING(261)
i  LONG,AUTO
  CODE
  n = CLIP(LEFT(pPath))
  LOOP i = LEN(n) TO 1 BY -1
    IF n[i] = '\' OR n[i] = '/' THEN RETURN SUB(n,1,i-1) .
  END
  RETURN ''


ExportClass.LoadSettings PROCEDURE
f     CSTRING(261)
sect  CSTRING(80)
fold  CSTRING(261)
v     CSTRING(161)
i     LONG,AUTO
  CODE
  SELF.Loaded = 1
  f    = SELF.IniPath()
  sect = SELF.IniSection()
  SELF.Fmt          = GETINI(sect,'Fmt',SELF.Fmt,f)
  SELF.Headers      = GETINI(sect,'Headers',SELF.Headers,f)
  SELF.Pictures     = GETINI(sect,'Pictures',SELF.Pictures,f)
  SELF.OpenWhenDone = GETINI(sect,'OpenWhenDone',SELF.OpenWhenDone,f)
  fold = GETINI(sect,'Folder','',f)
  IF CLIP(fold)                                           ! same folder, a freshly-dated name
    SELF.FileName = CLIP(fold) & '\' & SELF.SuggestName()
    SELF.ForceExt(SELF.Fmt)
  END
  IF GETINI(sect,'Sig','',f) <> SELF.SigKey() THEN RETURN .  ! layout changed - keep the live columns
  LOOP i = 1 TO SELF.Columns()
    GET(SELF.Cols,i)
    IF ERRORCODE() THEN CYCLE .
    SELF.Cols.Use = GETINI(sect,'C' & i & '.Use',SELF.Cols.Use,f)
    v = GETINI(sect,'C' & i & '.Head','',f)
    IF CLIP(v) THEN SELF.Cols.Head = CLIP(v) .
    v = GETINI(sect,'C' & i & '.Pic','',f)                 ! stored with a leading '=' so that a
    IF SUB(v,1,1) = '='                                    ! deliberately BLANK picture survives
      SELF.Cols.Pic = CLIP(SUB(v,2,32))
    END
    PUT(SELF.Cols)
    SELF.Classify(i)
  END


ExportClass.SaveSettings PROCEDURE
f     CSTRING(261)
sect  CSTRING(80)
i     LONG,AUTO
  CODE
  f    = SELF.IniPath()
  sect = SELF.IniSection()
  PUTINI(sect,'Fmt',SELF.Fmt,f)
  PUTINI(sect,'Headers',SELF.Headers,f)
  PUTINI(sect,'Pictures',SELF.Pictures,f)
  PUTINI(sect,'OpenWhenDone',SELF.OpenWhenDone,f)
  PUTINI(sect,'Folder',SELF.FolderOf(SELF.FileName),f)
  PUTINI(sect,'Sig',SELF.SigKey(),f)
  LOOP i = 1 TO SELF.Columns()
    GET(SELF.Cols,i)
    IF ERRORCODE() THEN CYCLE .
    PUTINI(sect,'C' & i & '.Use',SELF.Cols.Use,f)
    IF SELF.Cols.Head <> SELF.Cols.HeadDef                 ! only store what the user changed
      PUTINI(sect,'C' & i & '.Head',CLIP(SELF.Cols.Head),f)
    ELSE
      PUTINI(sect,'C' & i & '.Head','',f)
    END
    IF SELF.Cols.Pic <> SELF.Cols.PicDef
      PUTINI(sect,'C' & i & '.Pic','=' & CLIP(SELF.Cols.Pic),f)
    ELSE
      PUTINI(sect,'C' & i & '.Pic','',f)
    END
  END


ExportClass.ForgetSettings PROCEDURE
f     CSTRING(261)
sect  CSTRING(80)
i     LONG,AUTO
  CODE
  f    = SELF.IniPath()
  sect = SELF.IniSection()
  PUTINI(sect,'Sig','',f)                                 ! kills the column half on the next load
  PUTINI(sect,'Folder','',f)
  LOOP i = 1 TO SELF.Columns()
    PUTINI(sect,'C' & i & '.Use','',f)
    PUTINI(sect,'C' & i & '.Head','',f)
    PUTINI(sect,'C' & i & '.Pic','',f)
  END
  SELF.Loaded = 0


! ############################################################################
!  The column list - what the dialog edits, and what your code can drive
! ############################################################################
ExportClass.ResetColumns PROCEDURE
i  LONG,AUTO
  CODE
  IF SELF.Cols &= NULL THEN RETURN .
  LOOP i = 1 TO RECORDS(SELF.Cols)
    GET(SELF.Cols,i)
    IF ERRORCODE() THEN CYCLE .
    SELF.Cols.Head = SELF.Cols.HeadDef
    SELF.Cols.Pic  = SELF.Cols.PicDef
    SELF.Cols.Use  = 1
    IF SELF.VisibleOnly AND ~SELF.Cols.Width THEN SELF.Cols.Use = 0 .
    PUT(SELF.Cols)
    SELF.Classify(i)
  END


ExportClass.SelectAll PROCEDURE(BYTE pOn)
i  LONG,AUTO
  CODE
  IF SELF.Cols &= NULL THEN RETURN .
  LOOP i = 1 TO RECORDS(SELF.Cols)
    GET(SELF.Cols,i)
    IF ERRORCODE() THEN CYCLE .
    SELF.Cols.Use = pOn
    PUT(SELF.Cols)
  END


ExportClass.ColumnUse PROCEDURE(LONG pCol,BYTE pOn)
  CODE
  IF SELF.Cols &= NULL THEN RETURN .
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN .
  SELF.Cols.Use = pOn
  PUT(SELF.Cols)


ExportClass.ColumnRename PROCEDURE(LONG pCol,STRING pHead)
h  CSTRING(129)
  CODE
  IF SELF.Cols &= NULL THEN RETURN .
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN .
  h = CLIP(LEFT(pHead))
  IF ~h THEN h = SELF.Cols.HeadDef .                      ! blank means "put it back"
  SELF.Cols.Head = h
  PUT(SELF.Cols)
  SELF.Classify(pCol)


ExportClass.ColumnPicture PROCEDURE(LONG pCol,STRING pPic)
  CODE
  IF SELF.Cols &= NULL THEN RETURN .
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN .
  SELF.Cols.Pic = CLIP(LEFT(pPic))                        ! blank = write the raw value
  PUT(SELF.Cols)
  SELF.Classify(pCol)


ExportClass.ColumnHeading PROCEDURE(LONG pCol)
  CODE
  IF SELF.Cols &= NULL THEN RETURN '' .
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN '' .
  RETURN CLIP(SELF.Cols.Head)


ExportClass.ColumnDefault PROCEDURE(LONG pCol)
  CODE
  IF SELF.Cols &= NULL THEN RETURN '' .
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN '' .
  RETURN CLIP(SELF.Cols.HeadDef)


ExportClass.ColumnPic PROCEDURE(LONG pCol)
  CODE
  IF SELF.Cols &= NULL THEN RETURN '' .
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN '' .
  RETURN CLIP(SELF.Cols.Pic)


ExportClass.ColumnDefaultPic PROCEDURE(LONG pCol)
  CODE
  IF SELF.Cols &= NULL THEN RETURN '' .
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN '' .
  RETURN CLIP(SELF.Cols.PicDef)


ExportClass.ColumnOn PROCEDURE(LONG pCol)
  CODE
  IF SELF.Cols &= NULL THEN RETURN 0 .
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN 0 .
  RETURN SELF.Cols.Use


! ############################################################################
!  Format descriptions
! ############################################################################
ExportClass.FormatName PROCEDURE(LONG pFmt)
  CODE
  CASE pFmt
  OF Exp:CSV     ; RETURN SELF.Txt(Txt:FmtCSV)
  OF Exp:CSVUTF8 ; RETURN SELF.Txt(Txt:FmtCSVU)
  OF Exp:TSV     ; RETURN SELF.Txt(Txt:FmtTSV)
  OF Exp:XML     ; RETURN SELF.Txt(Txt:FmtXML)
  OF Exp:JSON    ; RETURN SELF.Txt(Txt:FmtJSON)
  OF Exp:XLSX    ; RETURN SELF.Txt(Txt:FmtXLSX)
  OF Exp:HTML    ; RETURN SELF.Txt(Txt:FmtHTML)
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
    RETURN SELF.Txt(Txt:MaskCSV) & '|*.csv|' & SELF.Txt(Txt:MaskText) & '|*.txt|' & |
           SELF.Txt(Txt:MaskAll) & '|*.*'
  OF Exp:TSV
    RETURN SELF.Txt(Txt:MaskTSV) & '|*.tsv|' & SELF.Txt(Txt:MaskText) & '|*.txt|' & |
           SELF.Txt(Txt:MaskAll) & '|*.*'
  OF Exp:XML
    RETURN SELF.Txt(Txt:MaskXML) & '|*.xml|' & SELF.Txt(Txt:MaskAll) & '|*.*'
  OF Exp:JSON
    RETURN SELF.Txt(Txt:MaskJSON) & '|*.json|' & SELF.Txt(Txt:MaskAll) & '|*.*'
  OF Exp:XLSX
    RETURN SELF.Txt(Txt:MaskXLSX) & '|*.xlsx|' & SELF.Txt(Txt:MaskAll) & '|*.*'
  OF Exp:HTML
    RETURN SELF.Txt(Txt:MaskHTML) & '|*.html;*.htm|' & SELF.Txt(Txt:MaskAll) & '|*.*'
  END
  RETURN SELF.Txt(Txt:MaskAll) & '|*.*'


ExportClass.FormatHint PROCEDURE(LONG pFmt)
  CODE
  CASE pFmt
  OF Exp:CSV     ; RETURN SELF.Txt(Txt:HintCSV)
  OF Exp:CSVUTF8 ; RETURN SELF.Txt(Txt:HintCSVU)
  OF Exp:TSV     ; RETURN SELF.Txt(Txt:HintTSV)
  OF Exp:XML     ; RETURN SELF.Txt(Txt:HintXML)
  OF Exp:JSON    ; RETURN SELF.Txt(Txt:HintJSON)
  OF Exp:XLSX    ; RETURN SELF.Txt(Txt:HintXLSX)
  OF Exp:HTML    ; RETURN SELF.Txt(Txt:HintHTML)
  END
  RETURN ''


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
  IF ~s THEN s = SELF.Txt(Txt:ExportWord) .
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
!  Every word the user can see, in SELF.Language
! ############################################################################
!  The window structures below are declared with the English text - that is
!  only the design-time placeholder. At run time the dialog assigns every
!  caption from here, so this method is the single source of truth and the
!  English and Spanish wording can never drift apart.
!
!  TO ADD A LANGUAGE: derive the class and override this one method -
!
!      MyExporter  CLASS(ExportClass)
!      Txt           PROCEDURE(LONG pId),STRING,DERIVED
!                  END
!
!      MyExporter.Txt PROCEDURE(LONG pId)
!        CODE
!        IF SELF.Language = 3                             ! your own equate
!          CASE pId
!          OF Txt:ExportBtn ; RETURN '&Exporter'
!          ...
!          END
!        END
!        RETURN PARENT.Txt(pId)                           ! anything you skip
!
!  Accented letters are written as Clarion <nnn> escapes (CP1252) so this file
!  stays plain ASCII and survives any editor - see the note at the top.
ExportClass.Txt PROCEDURE(LONG pId)
  CODE
  IF SELF.Language = Exp:Spanish
    CASE pId
!    the export dialog
    OF Txt:WinTitle      ; RETURN 'Exportar datos'
    OF Txt:Subtitle      ; RETURN 'Elige un formato y un destino, y luego las columnas.'
    OF Txt:SubtitleNoCol ; RETURN 'Elige un formato y luego la carpeta y el nombre del archivo.'
    OF Txt:FormatLbl     ; RETURN '&Formato:'
    OF Txt:SaveToLbl     ; RETURN 'Guardar &en:'
    OF Txt:FileTip       ; RETURN 'D<243>nde se escribir<225> el archivo exportado'
    OF Txt:PickTip       ; RETURN 'Elegir la carpeta y el nombre del archivo'
    OF Txt:ColumnsLbl    ; RETURN 'Columnas'
    OF Txt:ColHint       ; RETURN 'Doble clic o Espacio para incluir o excluir.'
    OF Txt:ColUse        ; RETURN 'Usar'
    OF Txt:ColNum        ; RETURN '#'
    OF Txt:ColHeadFile   ; RETURN 'Encabezado en el archivo'
    OF Txt:ColPicture    ; RETURN 'Picture'
    OF Txt:ColOnList     ; RETURN 'Columna en la lista'
    OF Txt:ToggleBtn     ; RETURN '&Incluir / excluir'
    OF Txt:EditBtn       ; RETURN '&Renombrar / picture...'
    OF Txt:AllBtn        ; RETURN '&Todas'
    OF Txt:NoneBtn       ; RETURN '&Ninguna'
    OF Txt:DefBtn        ; RETURN '&Predeterminados'
    OF Txt:DefTip        ; RETURN 'Devolver cada encabezado y picture a como los tiene la lista'
    OF Txt:IncHeadings   ; RETURN 'Incluir los &encabezados de columna'
    OF Txt:ApplyPics     ; RETURN 'Aplicar el &picture de cada columna'
    OF Txt:ApplyPicsTip  ; RETURN 'Sin marcar = valores crudos; marcado = lo que muestra la lista'
    OF Txt:OpenAfter     ; RETURN '&Abrir el archivo al terminar'
    OF Txt:ExportBtn     ; RETURN 'E&xportar'
    OF Txt:Cancel        ; RETURN 'Cancelar'
    OF Txt:OfWord        ; RETURN ' de '
    OF Txt:SelectedWord  ; RETURN ' seleccionadas)'
!    the one-column popup
    OF Txt:EdTitle       ; RETURN 'Columna'
    OF Txt:EdHeading     ; RETURN 'Ajustes de la columna'
    OF Txt:OnTheList     ; RETURN 'En la lista:'
    OF Txt:HeadingLbl    ; RETURN '&Encabezado:'
    OF Txt:HeadTip       ; RETURN 'C<243>mo se llama esta columna en el archivo exportado'
    OF Txt:PictureLbl    ; RETURN '&Picture:'
    OF Txt:PicTip        ; RETURN 'En blanco = escribir el valor crudo'
    OF Txt:EdDefBtn      ; RETURN 'Pre&determinado'
    OF Txt:EdFoot        ; RETURN 'Encabezado en blanco = el de la lista.  Picture en blanco = el valor crudo.'
    OF Txt:OK            ; RETURN 'Aceptar'
!    the formats
    OF Txt:FmtCSV        ; RETURN 'CSV - separado por comas (*.csv)'
    OF Txt:FmtCSVU       ; RETURN 'CSV - separado por comas, UTF-8 (*.csv)'
    OF Txt:FmtTSV        ; RETURN 'TSV - separado por tabuladores (*.tsv)'
    OF Txt:FmtXML        ; RETURN 'Documento XML (*.xml)'
    OF Txt:FmtJSON       ; RETURN 'Documento JSON (*.json)'
    OF Txt:FmtXLSX       ; RETURN 'Libro de Excel (*.xlsx)'
    OF Txt:FmtHTML       ; RETURN 'Tabla HTML (*.html)'
!    the Save-As file types
    OF Txt:MaskCSV       ; RETURN 'Separado por comas'
    OF Txt:MaskTSV       ; RETURN 'Separado por tabuladores'
    OF Txt:MaskXML       ; RETURN 'Documentos XML'
    OF Txt:MaskJSON      ; RETURN 'Documentos JSON'
    OF Txt:MaskXLSX      ; RETURN 'Libros de Excel'
    OF Txt:MaskHTML      ; RETURN 'P<225>ginas web'
    OF Txt:MaskText      ; RETURN 'Archivos de texto'
    OF Txt:MaskAll       ; RETURN 'Todos los archivos'
!    the one-liner under the dialog
    OF Txt:HintCSV       ; RETURN 'S<243>lo se entrecomillan los valores que lo necesitan (RFC 4180).'
    OF Txt:HintCSVU      ; RETURN 'Lleva marca UTF-8 (BOM), as<237> Excel lee bien los acentos.'
    OF Txt:HintTSV       ; RETURN 'Los tabuladores y saltos de l<237>nea dentro de un valor pasan a espacios.'
    OF Txt:HintXML       ; RETURN 'UTF-8. Los encabezados se vuelven nombres de elemento: mantenlos simples.'
    OF Txt:HintJSON      ; RETURN 'UTF-8. Las columnas num<233>ricas se escriben como n<250>meros, no como texto.'
    OF Txt:HintXLSX      ; RETURN 'Un libro de verdad: n<250>meros como n<250>meros, encabezados fijos y autofiltro.'
    OF Txt:HintHTML      ; RETURN 'Una tabla con estilo: impr<237>mela o p<233>gala en Word o Excel.'
!    messages
    OF Txt:MsgTitle      ; RETURN 'Exportar'
    OF Txt:NoColumns     ; RETURN 'No hay nada que exportar: esta lista no tiene columnas de datos.'
    OF Txt:NoFormats     ; RETURN 'No se ha habilitado ning<250>n formato de exportaci<243>n.'
    OF Txt:NeedFile      ; RETURN 'Elige primero un nombre de archivo.'
    OF Txt:NeedColumn    ; RETURN 'Marca al menos una columna para exportar.'
    OF Txt:BadPicture    ; RETURN 'Un picture de Clarion empieza por @ - por ejemplo @n-11.2 o @d17.'
    OF Txt:BadPicture2   ; RETURN 'D<233>jalo en blanco para escribir el valor crudo.'
    OF Txt:PicTitle      ; RETURN 'Picture'
    OF Txt:FailTitle     ; RETURN 'La exportaci<243>n fall<243>'
    OF Txt:NoneSelected  ; RETURN 'No hay columnas seleccionadas para exportar.'
    OF Txt:NoFileName    ; RETURN 'No se indic<243> ning<250>n nombre de archivo.'
    OF Txt:CantCreate    ; RETURN 'No se pudo crear'
    OF Txt:CantCreate2   ; RETURN 'Comprueba que la carpeta existe y que el archivo no est<233> abierto.'
    OF Txt:CantWrite     ; RETURN 'No se pudo escribir en'
    OF Txt:CantWrite2    ; RETURN 'El disco puede estar lleno o protegido contra escritura.'
    OF Txt:RowsExported  ; RETURN ' fila(s) exportadas a'
    OF Txt:DoneTitle     ; RETURN 'Exportaci<243>n terminada'
    OF Txt:ExportToTitle ; RETURN 'Exportar a '
    OF Txt:RowsHtml      ; RETURN ' fila(s)'
    OF Txt:ColumnWord    ; RETURN 'Columna'
    OF Txt:ExportWord    ; RETURN 'Exportar'
    END
    RETURN ''
  END
  CASE pId
!  the export dialog
  OF Txt:WinTitle      ; RETURN 'Export data'
  OF Txt:Subtitle      ; RETURN 'Choose a format and a destination, then pick the columns.'
  OF Txt:SubtitleNoCol ; RETURN 'Choose a format, then the folder and file name.'
  OF Txt:FormatLbl     ; RETURN '&Format:'
  OF Txt:SaveToLbl     ; RETURN 'Save &to:'
  OF Txt:FileTip       ; RETURN 'Where the exported file will be written'
  OF Txt:PickTip       ; RETURN 'Choose the folder and the file name'
  OF Txt:ColumnsLbl    ; RETURN 'Columns'
  OF Txt:ColHint       ; RETURN 'Double-click or press Space to include or exclude.'
  OF Txt:ColUse        ; RETURN 'Use'
  OF Txt:ColNum        ; RETURN '#'
  OF Txt:ColHeadFile   ; RETURN 'Heading in the file'
  OF Txt:ColPicture    ; RETURN 'Picture'
  OF Txt:ColOnList     ; RETURN 'Column on the list'
  OF Txt:ToggleBtn     ; RETURN '&Include / exclude'
  OF Txt:EditBtn       ; RETURN '&Rename / picture...'
  OF Txt:AllBtn        ; RETURN '&All'
  OF Txt:NoneBtn       ; RETURN '&None'
  OF Txt:DefBtn        ; RETURN '&Defaults'
  OF Txt:DefTip        ; RETURN 'Put every heading and picture back the way the list has it'
  OF Txt:IncHeadings   ; RETURN 'Include the column &headings'
  OF Txt:ApplyPics     ; RETURN 'Apply each column''s &picture'
  OF Txt:ApplyPicsTip  ; RETURN 'Off = raw values, on = exactly what the list shows'
  OF Txt:OpenAfter     ; RETURN '&Open the file when it is done'
  OF Txt:ExportBtn     ; RETURN '&Export'
  OF Txt:Cancel        ; RETURN 'Cancel'
  OF Txt:OfWord        ; RETURN ' of '
  OF Txt:SelectedWord  ; RETURN ' selected)'
!  the one-column popup
  OF Txt:EdTitle       ; RETURN 'Column'
  OF Txt:EdHeading     ; RETURN 'Column settings'
  OF Txt:OnTheList     ; RETURN 'On the list:'
  OF Txt:HeadingLbl    ; RETURN '&Heading:'
  OF Txt:HeadTip       ; RETURN 'What this column is called in the exported file'
  OF Txt:PictureLbl    ; RETURN '&Picture:'
  OF Txt:PicTip        ; RETURN 'Blank = write the raw value'
  OF Txt:EdDefBtn      ; RETURN 'De&fault'
  OF Txt:EdFoot        ; RETURN 'Blank heading = the list''s own.  Blank picture = the raw value.'
  OF Txt:OK            ; RETURN 'OK'
!  the formats
  OF Txt:FmtCSV        ; RETURN 'CSV - comma separated (*.csv)'
  OF Txt:FmtCSVU       ; RETURN 'CSV - comma separated, UTF-8 (*.csv)'
  OF Txt:FmtTSV        ; RETURN 'TSV - tab separated (*.tsv)'
  OF Txt:FmtXML        ; RETURN 'XML document (*.xml)'
  OF Txt:FmtJSON       ; RETURN 'JSON document (*.json)'
  OF Txt:FmtXLSX       ; RETURN 'Excel workbook (*.xlsx)'
  OF Txt:FmtHTML       ; RETURN 'HTML table (*.html)'
!  the Save-As file types
  OF Txt:MaskCSV       ; RETURN 'Comma separated'
  OF Txt:MaskTSV       ; RETURN 'Tab separated'
  OF Txt:MaskXML       ; RETURN 'XML documents'
  OF Txt:MaskJSON      ; RETURN 'JSON documents'
  OF Txt:MaskXLSX      ; RETURN 'Excel workbooks'
  OF Txt:MaskHTML      ; RETURN 'Web pages'
  OF Txt:MaskText      ; RETURN 'Text files'
  OF Txt:MaskAll       ; RETURN 'All files'
!  the one-liner under the dialog
  OF Txt:HintCSV       ; RETURN 'Values are quoted only where they have to be (RFC 4180).'
  OF Txt:HintCSVU      ; RETURN 'Carries a UTF-8 byte-order mark, so Excel reads accented text correctly.'
  OF Txt:HintTSV       ; RETURN 'Tabs and line breaks inside a value become single spaces.'
  OF Txt:HintXML       ; RETURN 'UTF-8. Headings become element names, so keep them simple.'
  OF Txt:HintJSON      ; RETURN 'UTF-8. Numeric columns are written as numbers, not strings.'
  OF Txt:HintXLSX      ; RETURN 'A real workbook: numbers as numbers, frozen headings and an auto-filter.'
  OF Txt:HintHTML      ; RETURN 'A styled table - print it, or paste it into Word or Excel.'
!  messages
  OF Txt:MsgTitle      ; RETURN 'Export'
  OF Txt:NoColumns     ; RETURN 'There is nothing to export - this list has no data columns.'
  OF Txt:NoFormats     ; RETURN 'No export formats have been enabled.'
  OF Txt:NeedFile      ; RETURN 'Please choose a file name first.'
  OF Txt:NeedColumn    ; RETURN 'Please tick at least one column to export.'
  OF Txt:BadPicture    ; RETURN 'A Clarion picture starts with @ - for example @n-11.2 or @d17.'
  OF Txt:BadPicture2   ; RETURN 'Leave it blank to write the raw value.'
  OF Txt:PicTitle      ; RETURN 'Picture'
  OF Txt:FailTitle     ; RETURN 'Export failed'
  OF Txt:NoneSelected  ; RETURN 'No columns are selected for export.'
  OF Txt:NoFileName    ; RETURN 'No file name was given.'
  OF Txt:CantCreate    ; RETURN 'Could not create'
  OF Txt:CantCreate2   ; RETURN 'Check the folder exists and that the file is not already open.'
  OF Txt:CantWrite     ; RETURN 'Could not write to'
  OF Txt:CantWrite2    ; RETURN 'The disk may be full or write protected.'
  OF Txt:RowsExported  ; RETURN ' row(s) exported to'
  OF Txt:DoneTitle     ; RETURN 'Export complete'
  OF Txt:ExportToTitle ; RETURN 'Export to '
  OF Txt:RowsHtml      ; RETURN ' row(s)'
  OF Txt:ColumnWord    ; RETURN 'Column'
  OF Txt:ExportWord    ; RETURN 'Export'
  END
  RETURN ''


! ############################################################################
!  The run-time dialog:  which format, and where does it go
! ############################################################################
!  The columns LIST mirrors SELF.Cols one-for-one, so a row number in the
!  dialog IS the column's queue position - nothing to map.
!
!  Editing is a LIST plus buttons plus a small modal window, deliberately: an
!  edit-in-place manager driven outside a BrowseBox is unstable, and this is
!  both sturdier and easier to use with the keyboard.
ExportClass.Ask PROCEDURE()
FmtQ           QUEUE,PRE(FQ)
FName            STRING(40)
FId              LONG
               END
ColQ           QUEUE,PRE(CQ)
Mark             STRING(3)                            ! 'X' when the column is included
Num              LONG
Head             STRING(64)                           ! what the file will call it
Pic              STRING(32)
Src              STRING(64)                           ! what the LIST calls it
               END
i              LONG,AUTO
row            LONG,AUTO
Sel            LONG(1)
Ok             BYTE(0)
Shrink         LONG(0)
ExpFile        CSTRING(261)
ExpHdrs        BYTE
ExpPics        BYTE
ExpOpen        BYTE
EdHead         CSTRING(129)
EdPic          CSTRING(33)
EdOk           BYTE
BtnFeq         LONG,DIM(5)                          ! the column-picker button row
BtnCap         CSTRING(65)
BtnX           LONG
BtnW           LONG
ExpWnd WINDOW('Export data'),AT(,,436,344),FONT('Segoe UI',9,,FONT:regular,CHARSET:ANSI),CENTER,GRAY,SYSTEM,MODAL
         PANEL,AT(0,0,436,36),USE(?ExpBand),FILL(0603A1FH)
         STRING('Export data'),AT(14,7),USE(?ExpT1),FONT('Segoe UI',12,COLOR:White,FONT:bold),TRN
         STRING('Choose a format and a destination, then pick the columns.'),AT(14,23),USE(?ExpT2), |
           FONT('Segoe UI',8,0D8C8B4H),TRN
         PROMPT('&Format:'),AT(14,52),USE(?ExpP1)
         LIST,AT(76,50,346,10),USE(?ExpFmt),VSCROLL,DROP(8),FROM(FmtQ),FORMAT('190L(2)@s40@')
         PROMPT('Save &to:'),AT(14,72),USE(?ExpP2)
         ENTRY(@s255),AT(76,70,328,10),USE(ExpFile),TIP('Where the exported file will be written')
         BUTTON('...'),AT(406,70,16,10),USE(?ExpPick),TIP('Choose the folder and the file name')
         STRING('Columns'),AT(14,92),USE(?ExpP3),FONT('Segoe UI',9,,FONT:bold),TRN
         STRING(''),AT(62,92,180,10),USE(?ExpCount),FONT('Segoe UI',8,0757575H),TRN
         STRING('Double-click or press Space to include or exclude.'),AT(242,92,180,10),USE(?ExpHint), |
           FONT('Segoe UI',8,0757575H),TRN
         LIST,AT(14,104,408,118),USE(?ExpCols),FROM(ColQ),VSCROLL,ALRT(MouseLeft2),ALRT(SpaceKey), |
           FORMAT('20C|M~Use~@s3@24R(2)|M~#~@n3@136L(2)|M~Heading in the file~@s64@' & |
                  '62L(2)|M~Picture~@s32@136L(2)|M~Column on the list~@s64@')
         BUTTON('&Include / exclude'),AT(14,226,68,13),USE(?ExpToggle)
         BUTTON('&Rename / picture...'),AT(86,226,74,13),USE(?ExpEdit)
         BUTTON('&All'),AT(164,226,30,13),USE(?ExpAll)
         BUTTON('&None'),AT(198,226,30,13),USE(?ExpNone)
         BUTTON('&Defaults'),AT(232,226,40,13),USE(?ExpDef),TIP('Put every heading and picture back the way the list has it')
         CHECK('Include the column &headings'),AT(14,250),USE(ExpHdrs)
         CHECK('Apply each column''s &picture'),AT(14,262),USE(ExpPics),TIP('Off = raw values, on = exactly what the list shows')
         CHECK('&Open the file when it is done'),AT(14,274),USE(ExpOpen)
         PANEL,AT(14,294,408,1),USE(?ExpRule),FILL(0D4D0CCH)
         STRING(''),AT(14,302,408,10),USE(?ExpInfo),FONT('Segoe UI',8,0757575H),TRN
         BUTTON('&Export'),AT(308,320,54,14),USE(?ExpOk),DEFAULT
         BUTTON('Cancel'),AT(366,320,54,14),USE(?ExpCancel)
       END
EdWnd  WINDOW('Column'),AT(,,258,124),FONT('Segoe UI',9,,FONT:regular,CHARSET:ANSI),CENTER,GRAY,SYSTEM,MODAL
         PANEL,AT(0,0,258,28),USE(?EdBand),FILL(0603A1FH)
         STRING('Column settings'),AT(12,8),USE(?EdT1),FONT('Segoe UI',10,COLOR:White,FONT:bold),TRN
         PROMPT('On the list:'),AT(12,40),USE(?EdP0)
         STRING(''),AT(76,40,170,10),USE(?EdSrc),FONT('Segoe UI',9,,FONT:bold),TRN
         PROMPT('&Heading:'),AT(12,58),USE(?EdP1)
         ENTRY(@s128),AT(76,56,170,10),USE(EdHead),TIP('What this column is called in the exported file')
         PROMPT('&Picture:'),AT(12,76),USE(?EdP2)
         ENTRY(@s32),AT(76,74,104,10),USE(EdPic),TIP('Blank = write the raw value')
         BUTTON('De&fault'),AT(186,74,60,10),USE(?EdDef)
         STRING('Blank heading = the list''s own.  Blank picture = the raw value.'), |
           AT(12,92,234,10),USE(?EdHint),FONT('Segoe UI',8,0757575H),TRN
         BUTTON('OK'),AT(144,106,50,13),USE(?EdOk),DEFAULT
         BUTTON('Cancel'),AT(198,106,50,13),USE(?EdCancel)
       END
  CODE
  IF ~SELF.Columns() THEN SELF.ScanColumns() .
  IF ~SELF.Columns()
    SELF.Note(SELF.Txt(Txt:NoColumns),SELF.Txt(Txt:MsgTitle),ICON:Exclamation)
    RETURN 0
  END
!  Pick up where the user left off last time. This runs after the generated
!  code has applied the template's defaults, so the saved choices win - which
!  is the point.
  IF SELF.Persist AND ~SELF.Loaded THEN SELF.LoadSettings() .
  LOOP i = 1 TO Exp:Formats
    IF ~SELF.Allowed(i) THEN CYCLE .
    FQ:FName = SELF.FormatName(i)
    FQ:FId   = i
    ADD(FmtQ)
  END
  IF ~RECORDS(FmtQ)
    SELF.Note(SELF.Txt(Txt:NoFormats),SELF.Txt(Txt:MsgTitle),ICON:Exclamation)
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
  DO SpeakDialog                                          ! every caption, in SELF.Language
  ?ExpFmt{PROP:Selected} = Sel
  DO FillCols
  IF ~SELF.AllowColumns THEN DO HideCols .
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
            DO ShowInfo
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
    OF ?ExpCols
      CASE EVENT()
      OF EVENT:AlertKey
        CASE KEYCODE()
        OF MouseLeft2 ; DO ToggleRow
        OF SpaceKey   ; DO ToggleRow
        END
      END
    OF ?ExpToggle
      IF EVENT() = EVENT:Accepted THEN DO ToggleRow .
    OF ?ExpEdit
      IF EVENT() = EVENT:Accepted THEN DO EditRow .
    OF ?ExpAll
      IF EVENT() = EVENT:Accepted
        SELF.SelectAll(1)
        DO FillCols
      END
    OF ?ExpNone
      IF EVENT() = EVENT:Accepted
        SELF.SelectAll(0)
        DO FillCols
      END
    OF ?ExpDef
      IF EVENT() = EVENT:Accepted
        SELF.ResetColumns()
        DO FillCols
      END
    OF ?ExpOk
      CASE EVENT()
      OF EVENT:Accepted
        IF ~CLIP(LEFT(ExpFile))
          SELF.Note(SELF.Txt(Txt:NeedFile),SELF.Txt(Txt:MsgTitle),ICON:Exclamation)
          SELECT(?ExpFile)
          CYCLE
        END
        IF ~SELF.Selected()
          SELF.Note(SELF.Txt(Txt:NeedColumn),SELF.Txt(Txt:MsgTitle),ICON:Exclamation)
          SELECT(?ExpCols)
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

!  ---- rebuild the columns list from SELF.Cols, keeping the highlight -------
!  ---- the whole dialog speaks SELF.Language ---------------------------------
!  Run once, straight after OPEN. The English in the WINDOW structure above is
!  only what the designer sees; these assignments are what the user reads, so
!  there is exactly one place to change a word or add a language.
SpeakDialog ROUTINE
  ExpWnd{PROP:Text}     = SELF.Txt(Txt:WinTitle)
  ?ExpT1{PROP:Text}     = SELF.Txt(Txt:WinTitle)
  ?ExpT2{PROP:Text}     = SELF.Txt(Txt:Subtitle)
  ?ExpP1{PROP:Text}     = SELF.Txt(Txt:FormatLbl)
  ?ExpP2{PROP:Text}     = SELF.Txt(Txt:SaveToLbl)
  ?ExpFile{PROP:Tip}    = SELF.Txt(Txt:FileTip)
  ?ExpPick{PROP:Tip}    = SELF.Txt(Txt:PickTip)
  ?ExpP3{PROP:Text}     = SELF.Txt(Txt:ColumnsLbl)
  ?ExpHint{PROP:Text}   = SELF.Txt(Txt:ColHint)
  ?ExpCols{PROPLIST:Header,1} = SELF.Txt(Txt:ColUse)      ! the picker's own headings
  ?ExpCols{PROPLIST:Header,2} = SELF.Txt(Txt:ColNum)
  ?ExpCols{PROPLIST:Header,3} = SELF.Txt(Txt:ColHeadFile)
  ?ExpCols{PROPLIST:Header,4} = SELF.Txt(Txt:ColPicture)
  ?ExpCols{PROPLIST:Header,5} = SELF.Txt(Txt:ColOnList)
  ?ExpToggle{PROP:Text} = SELF.Txt(Txt:ToggleBtn)
  ?ExpEdit{PROP:Text}   = SELF.Txt(Txt:EditBtn)
  ?ExpAll{PROP:Text}    = SELF.Txt(Txt:AllBtn)
  ?ExpNone{PROP:Text}   = SELF.Txt(Txt:NoneBtn)
  ?ExpDef{PROP:Text}    = SELF.Txt(Txt:DefBtn)
  ?ExpDef{PROP:Tip}     = SELF.Txt(Txt:DefTip)
  ?ExpHdrs{PROP:Text}   = SELF.Txt(Txt:IncHeadings)
  ?ExpPics{PROP:Text}   = SELF.Txt(Txt:ApplyPics)
  ?ExpPics{PROP:Tip}    = SELF.Txt(Txt:ApplyPicsTip)
  ?ExpOpen{PROP:Text}   = SELF.Txt(Txt:OpenAfter)
  ?ExpOk{PROP:Text}     = SELF.Txt(Txt:ExportBtn)
  ?ExpCancel{PROP:Text} = SELF.Txt(Txt:Cancel)
  DO SizeButtons


!  ---- the button row fits its own words -------------------------------------
!  'Defaults' is 8 characters; 'Predeterminados' is 15, and a button sized for
!  the English would cut it in half. So the five picker buttons are laid out
!  here instead of trusting the widths in the WINDOW structure: each one gets a
!  width from its own caption and the row is packed left to right. There are
!  ~150 spare dialog units to the right of the row, so a longer language grows
!  into empty space rather than off the edge.
!
!  The 3 units per character (plus padding) is for the dialog's Segoe UI 9 and
!  reproduces the hand-picked English widths to within a unit or two. '&' is
!  the accelerator marker and takes no space, so it is not counted.
SizeButtons ROUTINE
  BtnFeq[1] = ?ExpToggle
  BtnFeq[2] = ?ExpEdit
  BtnFeq[3] = ?ExpAll
  BtnFeq[4] = ?ExpNone
  BtnFeq[5] = ?ExpDef
  BtnX = 14
  LOOP i = 1 TO 5
    BtnCap = BtnFeq[i]{PROP:Text}
    BtnW   = LEN(CLIP(BtnCap))
    IF INSTRING('&',BtnCap,1,1) THEN BtnW -= 1 .          ! the accelerator marker
    BtnW = BtnW * 3 + 16
    IF BtnW < 30 THEN BtnW = 30 .                         ! keep All/None clickable
    BtnFeq[i]{PROP:Xpos}  = BtnX
    BtnFeq[i]{PROP:Width} = BtnW
    BtnX += BtnW + 4
  END


SpeakColumn ROUTINE
  EdWnd{PROP:Text}      = SELF.Txt(Txt:EdTitle)
  ?EdT1{PROP:Text}      = SELF.Txt(Txt:EdHeading)
  ?EdP0{PROP:Text}      = SELF.Txt(Txt:OnTheList)
  ?EdP1{PROP:Text}      = SELF.Txt(Txt:HeadingLbl)
  ?EdHead{PROP:Tip}     = SELF.Txt(Txt:HeadTip)
  ?EdP2{PROP:Text}      = SELF.Txt(Txt:PictureLbl)
  ?EdPic{PROP:Tip}      = SELF.Txt(Txt:PicTip)
  ?EdDef{PROP:Text}     = SELF.Txt(Txt:EdDefBtn)
  ?EdHint{PROP:Text}    = SELF.Txt(Txt:EdFoot)
  ?EdOk{PROP:Text}      = SELF.Txt(Txt:OK)
  ?EdCancel{PROP:Text}  = SELF.Txt(Txt:Cancel)


FillCols ROUTINE
  DATA
keep  LONG,AUTO
c     LONG,AUTO
  CODE
  keep = CHOICE(?ExpCols)
  FREE(ColQ)
  LOOP c = 1 TO SELF.Columns()
    GET(SELF.Cols,c)
    IF ERRORCODE() THEN CYCLE .
    CQ:Mark = CHOOSE(SELF.Cols.Use = 1,'X','')
    CQ:Num  = c
    CQ:Head = SELF.Cols.Head
    CQ:Pic  = SELF.Cols.Pic
    CQ:Src  = SELF.Cols.HeadDef
    ADD(ColQ)
  END
  DISPLAY(?ExpCols)
  IF keep > 0 AND keep <= RECORDS(ColQ) THEN SELECT(?ExpCols,keep) .
  DO ShowInfo

ShowInfo ROUTINE
  ?ExpCount{PROP:Text} = '(' & SELF.Selected() & SELF.Txt(Txt:OfWord) & |
                         SELF.Columns() & SELF.Txt(Txt:SelectedWord)
  ?ExpInfo{PROP:Text}  = SELF.FormatHint(SELF.Fmt)

!  ---- include / exclude the highlighted column -----------------------------
ToggleRow ROUTINE
  row = CHOICE(?ExpCols)
  IF ~row THEN EXIT .
  SELF.ColumnUse(row,1 - SELF.ColumnOn(row))
  DO FillCols

!  ---- rename it, or give it a different picture ----------------------------
EditRow ROUTINE
  row = CHOICE(?ExpCols)
  IF ~row THEN EXIT .
  EdHead = SELF.ColumnHeading(row)
  EdPic  = SELF.ColumnPic(row)
  EdOk   = 0
  OPEN(EdWnd)
  DO SpeakColumn                                          ! every caption, in SELF.Language
  ?EdSrc{PROP:Text} = SELF.ColumnDefault(row)
  ACCEPT
    CASE EVENT()
    OF EVENT:OpenWindow
      SELECT(?EdHead)
    END
    CASE FIELD()
    OF ?EdDef
      IF EVENT() = EVENT:Accepted
        EdHead = SELF.ColumnDefault(row)                  ! back to what the LIST itself says
        EdPic  = SELF.ColumnDefaultPic(row)
        DISPLAY(?EdHead)
        DISPLAY(?EdPic)
      END
    OF ?EdOk
      IF EVENT() = EVENT:Accepted
        IF CLIP(LEFT(EdPic)) AND SUB(CLIP(LEFT(EdPic)),1,1) <> '@'
          SELF.Note(SELF.Txt(Txt:BadPicture) & |
                    Exp:CRLF & Exp:CRLF & SELF.Txt(Txt:BadPicture2), |
                    SELF.Txt(Txt:PicTitle),ICON:Exclamation)
          SELECT(?EdPic)
          CYCLE
        END
        EdOk = 1
        POST(EVENT:CloseWindow)
      END
    OF ?EdCancel
      IF EVENT() = EVENT:Accepted THEN POST(EVENT:CloseWindow) .
    END
  END
  CLOSE(EdWnd)
  IF EdOk
    SELF.ColumnRename(row,EdHead)
    SELF.ColumnPicture(row,EdPic)
    DO FillCols
  END

!  ---- no column picking: hide that block and close the gap -----------------
HideCols ROUTINE
  Shrink = 158                                            ! 92..250, the whole columns block
  ?ExpT2{PROP:Text}    = SELF.Txt(Txt:SubtitleNoCol)
  ?ExpP3{PROP:Hide}    = 1
  ?ExpCount{PROP:Hide} = 1
  ?ExpHint{PROP:Hide}  = 1
  ?ExpCols{PROP:Hide}  = 1
  ?ExpToggle{PROP:Hide}= 1
  ?ExpEdit{PROP:Hide}  = 1
  ?ExpAll{PROP:Hide}   = 1
  ?ExpNone{PROP:Hide}  = 1
  ?ExpDef{PROP:Hide}   = 1
  ?ExpHdrs{PROP:Ypos}  = 250 - Shrink
  ?ExpPics{PROP:Ypos}  = 262 - Shrink
  ?ExpOpen{PROP:Ypos}  = 274 - Shrink
  ?ExpRule{PROP:Ypos}  = 294 - Shrink
  ?ExpInfo{PROP:Ypos}  = 302 - Shrink
  ?ExpOk{PROP:Ypos}    = 320 - Shrink
  ?ExpCancel{PROP:Ypos}= 320 - Shrink
  0{PROP:Height}       = 0{PROP:Height} - Shrink
  0{PROP:Ypos}         = 0{PROP:Ypos} + Shrink / 2        ! stay centred


ExportClass.AskFileName PROCEDURE()
Name  CSTRING(261)
  CODE
  Name = CLIP(LEFT(SELF.FileName))
  IF ~Name THEN Name = SELF.SuggestName() & SELF.FormatExt(SELF.Fmt) .
  IF FILEDIALOG(SELF.Txt(Txt:ExportToTitle) & SELF.FormatName(SELF.Fmt),Name,SELF.FormatMask(SELF.Fmt), |
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
out   LONG,AUTO
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
    SELF.ErrText = SELF.Txt(Txt:NoColumns)
    RETURN 0
  END
  IF ~SELF.Selected()
    SELF.ErrCode = 3
    SELF.ErrText = SELF.Txt(Txt:NoneSelected)
    RETURN 0
  END
  IF ~CLIP(LEFT(SELF.FileName))
    SELF.ErrCode = 2
    SELF.ErrText = SELF.Txt(Txt:NoFileName)
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
      out = 0
      LOOP i = 1 TO n
        GET(SELF.Cols,i)
        IF ~SELF.Cols.Use THEN CYCLE .
        out += 1
        IF out > 1 THEN SELF.Cat(dlm) .
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
        GET(SELF.Cols,i)
        IF ~SELF.Cols.Use THEN CYCLE .
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
    out = 0
    LOOP i = 1 TO n
      GET(SELF.Cols,i)
      IF ~SELF.Cols.Use THEN CYCLE .
      out += 1
      w = SELF.Cols.Width / 4 + 2
      IF w < 6  THEN w = 6  .
      IF w > 70 THEN w = 70 .
      SELF.Cat('<col min="' & out & '" max="' & out & '" width="' & w & '" customWidth="1"/>')
    END
    SELF.Cat('</cols><sheetData>')
    IF SELF.Headers
      SELF.Cat('<row r="1">')
      out = 0
      LOOP i = 1 TO n
        GET(SELF.Cols,i)
        IF ~SELF.Cols.Use THEN CYCLE .
        out += 1
        SELF.Cat('<c r="' & SELF.ColRef(out) & '1" s="1" t="inlineStr"><is><t>')
        SELF.CatXmlText(SELF.HeaderText(i))
        SELF.Cat('</t></is></c>')
      END
      SELF.Cat('</row>')
    END
  END
  RETURN 1


!  Append whatever is in the QUEUE BUFFER right now.
!  `i` walks every column the LIST has; `out` counts only the ticked ones, so
!  the file's field order and its A/B/C spreadsheet letters stay contiguous no
!  matter which columns the user left out.
ExportClass.AddRow PROCEDURE
i     LONG,AUTO
n     LONG,AUTO
out   LONG,AUTO
num   BYTE,AUTO
rw    LONG,AUTO
dlm   STRING(1)
  CODE
  IF ~SELF.Started THEN RETURN .
  n = SELF.Columns()
  IF ~n THEN RETURN .
  dlm = SELF.Sep()
  out = 0

  CASE SELF.Fmt
  OF Exp:CSV OROF Exp:CSVUTF8 OROF Exp:TSV
    LOOP i = 1 TO n
      GET(SELF.Cols,i)
      IF ~SELF.Cols.Use THEN CYCLE .
      out += 1
      IF out > 1 THEN SELF.Cat(dlm) .
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
      IF ~SELF.Cols.Use THEN CYCLE .
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
      IF ~SELF.Cols.Use THEN CYCLE .
      num = SELF.Cols.IsNum
      out += 1
      IF out > 1 THEN SELF.Cat(',') .
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
      IF ~SELF.Cols.Use THEN CYCLE .
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
      IF ~SELF.Cols.Use THEN CYCLE .
      num = SELF.Cols.IsNum
      out += 1
      IF num                                              ! a true numeric cell: sums, sorts, charts
        SELF.Cat('<c r="' & SELF.ColRef(out) & rw & '"><v>' & SELF.CellNumber(i) & '</v></c>')
      ELSE
        SELF.Cat('<c r="' & SELF.ColRef(out) & rw & '" t="inlineStr"><is><t>')
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
      SELF.Note(SELF.ErrText,SELF.Txt(Txt:FailTitle),ICON:Hand)
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
    SELF.Cat('<p class="meta">' & CLIP(LEFT(FORMAT(SELF.RowsOut,@n_11))) & SELF.Txt(Txt:RowsHtml) & '</p>' & Exp:CRLF)
    SELF.Cat('</body></html>' & Exp:CRLF)
  OF Exp:XLSX
    SELF.Cat('</sheetData>')
    IF SELF.Headers AND SELF.RowsOut
      last = SELF.RowsOut + 1
      SELF.Cat('<autoFilter ref="A1:' & SELF.ColRef(SELF.Selected()) & last & '"/>')
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
    IF SELF.Confirm THEN SELF.Note(SELF.ErrText,SELF.Txt(Txt:FailTitle),ICON:Hand) .
    RETURN 0
  END
  IF SELF.Persist THEN SELF.SaveSettings() .              ! remember how they left it
  IF SELF.Confirm
    SELF.Note(CLIP(LEFT(FORMAT(SELF.RowsOut,@n_11))) & SELF.Txt(Txt:RowsExported) & Exp:CRLF & Exp:CRLF & |
              CLIP(SELF.FileName),SELF.Txt(Txt:DoneTitle),ICON:Asterisk)
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
    SELF.ErrText = SELF.Txt(Txt:CantCreate) & Exp:CRLF & Exp:CRLF & CLIP(nm) & Exp:CRLF & Exp:CRLF & |
                   SELF.Txt(Txt:CantCreate2)
    RETURN 0
  END
  IF pLen > 0
    wr = 0
    IF ~exWriteFile(h,pData,pLen,wr,0) OR wr <> pLen
      exCloseHandle(h)
      SELF.ErrCode = 11
      SELF.ErrText = SELF.Txt(Txt:CantWrite) & Exp:CRLF & Exp:CRLF & CLIP(nm) & Exp:CRLF & Exp:CRLF & |
                     SELF.Txt(Txt:CantWrite2)
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
