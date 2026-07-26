!ABCIncludeFile
! ============================================================================
!  ExportClass - export ANY Clarion LIST / browse to a file.
!
!  Formats:  CSV | CSV (UTF-8) | TSV | XML | JSON | HTML | Excel .xlsx
!
!  Pure Clarion + the Win32 API that ships with Windows. No DLL, no OCX, no
!  Excel installation, no external helper program. The .xlsx it writes is a
!  real OOXML workbook (a ZIP of XML parts, built here) - Excel, LibreOffice,
!  Google Sheets and every xlsx reader open it directly.
!
!  HOW IT KNOWS WHAT TO EXPORT
!  ---------------------------
!  It reads the LIST control's own FORMAT at run time:
!      ?List{PROPLIST:Exists,c}   - is there a column c
!      ?List{PROPLIST:FieldNo,c}  - which QUEUE field that column shows
!      ?List{PROPLIST:Header,c}   - the column heading (becomes the file's)
!      ?List{PROPLIST:Picture,c}  - the column picture (formats the value)
!  and pulls each value out of the queue with WHAT(Queue, FieldNo). So the
!  export always matches what the user sees: same columns, same order, same
!  headings, same pictures - including columns the user re-ordered or resized
!  at run time. (This is the same recipe the shipped brwext.clw uses.)
!
!  USAGE (the myExport template does all of this for you)
!  ------------------------------------------------------
!    INCLUDE('ExportClass.INC'),ONCE
!    Exporter1  ExportClass
!
!      Exporter1.Init(?Browse:1, Queue:Browse:1)   ! list feq + its queue
!      Exporter1.Title = 'Customers'
!      IF Exporter1.Ask()                          ! modal format+filename dialog
!         Exporter1.StartFile()
!         BRW1.Reset()                             ! walk the WHOLE view...
!         LOOP
!           IF BRW1.Next() THEN BREAK .
!           BRW1.SetQueueRecord()                  ! ...fill the queue buffer
!           Exporter1.AddRow()
!         END
!         Exporter1.EndFile()
!      END
!
!    For a plain hand-coded LIST + QUEUE the whole job is one call:
!      IF Exporter1.Ask() THEN Exporter1.ExportQueue() .
!    or simply
!      Exporter1.Run()
!
!  FILES
!  -----
!    ExportClass.inc / ExportClass.clw   - put both on the redirection path
!                                          (the app folder, or \clarion12\libsrc\win)
!    Both files must be stored ANSI with CRLF line endings.
!
!  OPTIONAL: COMPRESSED .xlsx
!  --------------------------
!  By default the .xlsx parts are STORED (a valid, uncompressed ZIP) so the
!  class has zero dependencies. If you also own the myExport sibling template
!  myCompress, set _ExportDeflate_ to 1 below and put CompressClass.inc /
!  CompressClass.clw on the redirection path - the parts are then DEFLATEd and
!  a big workbook shrinks by roughly 8-10x. Nothing else changes.
! ============================================================================

_ExportDeflate_    EQUATE(0)                    ! 1 = deflate .xlsx parts with CompressClass (myCompress)

  COMPILE('_EndDeflateInc_',_ExportDeflate_)
INCLUDE('CompressClass.INC'),ONCE
  _EndDeflateInc_

! ---- the formats ----------------------------------------------------------
Exp:CSV            EQUATE(1)                    ! comma separated, system code page
Exp:CSVUTF8        EQUATE(2)                    ! comma separated, UTF-8 + BOM (Excel-safe accents)
Exp:TSV            EQUATE(3)                    ! tab separated
Exp:XML            EQUATE(4)                    ! UTF-8 XML, one element per column
Exp:JSON           EQUATE(5)                    ! UTF-8 array of objects
Exp:XLSX           EQUATE(6)                    ! real Excel workbook (OOXML)
Exp:HTML           EQUATE(7)                    ! styled HTML table
Exp:Formats        EQUATE(7)                    ! how many of the above there are

! ---- Allow bit mask (Allow = BOR of these; default = all) ------------------
Exp:AllowCSV       EQUATE(1)
Exp:AllowCSVUTF8   EQUATE(2)
Exp:AllowTSV       EQUATE(4)
Exp:AllowXML       EQUATE(8)
Exp:AllowJSON      EQUATE(16)
Exp:AllowXLSX      EQUATE(32)
Exp:AllowHTML      EQUATE(64)
Exp:AllowAll       EQUATE(127)

! ---- one row per exportable LIST column -----------------------------------
ExportColumnQueue  QUEUE,TYPE
ColNo                LONG                       ! the LIST column number
FldNo                LONG                       ! the QUEUE field it displays
Head                 CSTRING(129)               ! the column heading, as shown
Pic                  CSTRING(33)                ! the column picture, as shown
Tag                  CSTRING(65)                ! Head made safe for an XML/JSON name
IsNum                BYTE                       ! 1 = write unquoted in JSON / as a number in xlsx
Width                LONG                       ! the column width, in dialog units
                   END

! ---- one row per part written into the .xlsx archive ----------------------
ExportZipQueue     QUEUE,TYPE
EName                CSTRING(65)
ECrc                 ULONG
ECSize               ULONG
EUSize               ULONG
EOfs                 ULONG
EMeth                USHORT
                   END

ExportClass        CLASS,TYPE,MODULE('ExportClass.CLW'),LINK('ExportClass.CLW')
! ---- what to export -------------------------------------------------------
ListControl          SIGNED                     ! the LIST field equate
Q                    &QUEUE                     ! the queue that LIST displays
! ---- what the user chose (Ask fills these; set them yourself to skip Ask) --
Fmt                  LONG(1)                    ! Exp:CSV .. Exp:HTML
FileName             CSTRING(261)               ! full path of the file to write
! ---- options --------------------------------------------------------------
Allow                LONG(127)                  ! Exp:AllowAll, or a BOR of the Exp:Allow* bits
Title                CSTRING(65)                ! sheet name / XML root / HTML heading
RowTag               CSTRING(33)                ! XML element for one row (default 'Row')
Headers              BYTE(1)                    ! write a heading row
Pictures             BYTE(1)                    ! run each value through its column picture
VisibleOnly          BYTE(1)                    ! skip hidden (zero width) and icon columns
OpenWhenDone         BYTE(1)                    ! open the file in its default program
Confirm              BYTE(1)                    ! show the "N rows exported" popup
Delim                STRING(1)                  ! CSV separator; blank = comma
! ---- results --------------------------------------------------------------
RowsOut              LONG                       ! rows written by the last export
ErrCode              LONG                       ! 0 = ok
ErrText              CSTRING(161)
! ---- internals ------------------------------------------------------------
Cols                 &ExportColumnQueue,PROTECTED
Parts                &ExportZipQueue,PROTECTED
Buf                  &STRING,PROTECTED          ! the file text (or the xlsx sheet) being built
BufLen               LONG,PROTECTED
BufCap               LONG,PROTECTED
Arc                  &STRING,PROTECTED          ! the .xlsx archive being assembled
ArcLen               LONG,PROTECTED
ArcCap               LONG,PROTECTED
U8                   &STRING,PROTECTED          ! UTF-8 scratch
U8Len                LONG,PROTECTED
U8Cap                LONG,PROTECTED
CrcTab               ULONG,DIM(256),PROTECTED
CrcReady             BYTE,PROTECTED
Started              BYTE,PROTECTED

! ---- setup ----------------------------------------------------------------
Construct            PROCEDURE
Destruct             PROCEDURE
Init                 PROCEDURE(SIGNED pList,*QUEUE pQ)
Kill                 PROCEDURE
ScanColumns          PROCEDURE(),LONG,PROC      ! (re)read the LIST format -> column count
Columns              PROCEDURE(),LONG           ! how many columns will be exported

! ---- the run-time dialog --------------------------------------------------
Ask                  PROCEDURE(),BYTE,VIRTUAL   ! modal format + file name dialog. 1 = go
AskFileName          PROCEDURE(),BYTE,VIRTUAL   ! just the Save-As dialog, for SELF.Fmt
FormatName           PROCEDURE(LONG pFmt),STRING
FormatExt            PROCEDURE(LONG pFmt),STRING
FormatMask           PROCEDURE(LONG pFmt),STRING
Allowed              PROCEDURE(LONG pFmt),BYTE
SuggestName          PROCEDURE(),STRING         ! Title (or the window title) + today's date
ForceExt             PROCEDURE(LONG pFmt)       ! swap SELF.FileName's extension to match pFmt
Note                 PROCEDURE(STRING pText,STRING pTitle,LONG pIcon),VIRTUAL   ! modal popup

! ---- writing --------------------------------------------------------------
StartFile            PROCEDURE(),BYTE           ! begin; writes the preamble + heading row
AddRow               PROCEDURE()                ! append the row now in the QUEUE BUFFER
EndFile              PROCEDURE(),BYTE,PROC      ! finish, write to disk, optionally open it
ExportQueue          PROCEDURE(),BYTE,PROC      ! StartFile + every record in SELF.Q + EndFile
Run                  PROCEDURE(),BYTE,PROC      ! Ask + ExportQueue

! ---- one cell (VIRTUAL - override to reshape a value) ---------------------
HeaderText           PROCEDURE(LONG pCol),STRING,VIRTUAL
CellText             PROCEDURE(LONG pCol),STRING,VIRTUAL   ! display text (picture applied)
CellNumber           PROCEDURE(LONG pCol),STRING,VIRTUAL   ! raw numeric literal

! ---- helpers (protected) --------------------------------------------------
Need                 PROCEDURE(LONG pAdd),PROTECTED         ! grow Buf to hold pAdd more bytes
Cat                  PROCEDURE(STRING pText),PROTECTED      ! append to Buf
ArcNeed              PROCEDURE(LONG pAdd),PROTECTED
ArcCat               PROCEDURE(STRING pText),PROTECTED      ! append to Arc
U8Need               PROCEDURE(LONG pSize),PROTECTED
FreeBuffers          PROCEDURE,PROTECTED
Sep                  PROCEDURE(),STRING,PROTECTED           ! the delimited-format separator
! ...the Cat*Field/Text helpers escape straight into Buf: a value with nothing
! to escape costs one Cat, so a big export never pays per-character overhead.
CatCsvField          PROCEDURE(STRING pText,STRING pDelim),PROTECTED
CatFlatField         PROCEDURE(STRING pText),PROTECTED      ! TSV: no tabs/newlines survive
CatXmlText           PROCEDURE(STRING pText),PROTECTED
CatJsonText          PROCEDURE(STRING pText),PROTECTED
CatHtmlText          PROCEDURE(STRING pText),PROTECTED
SafeTag              PROCEDURE(STRING pText,LONG pCol),STRING,PROTECTED
SheetName            PROCEDURE(STRING pText),STRING,PROTECTED
ColRef               PROCEDURE(LONG pCol),STRING,PROTECTED  ! 1 -> A, 27 -> AA
IsAscii              PROCEDURE(*STRING pData,LONG pLen),BYTE,PROTECTED
ToUTF8               PROCEDURE(*STRING pData,LONG pLen),PROTECTED   ! -> SELF.U8 / SELF.U8Len
WriteDisk            PROCEDURE(STRING pFile,*STRING pData,LONG pLen),BYTE,PROTECTED
ShellOpen            PROCEDURE(STRING pFile),PROTECTED
CrcInit              PROCEDURE,PROTECTED
CRC32                PROCEDURE(*STRING pData,LONG pLen),ULONG,PROTECTED
Le16                 PROCEDURE(ULONG pVal),STRING,PROTECTED
Le32                 PROCEDURE(ULONG pVal),STRING,PROTECTED
ZipAdd               PROCEDURE(STRING pName,*STRING pData,LONG pLen),PROTECTED
ZipFinish            PROCEDURE,PROTECTED
XlsxWrite            PROCEDURE(),BYTE,PROTECTED             ! zip the parts and write the .xlsx
                   END
