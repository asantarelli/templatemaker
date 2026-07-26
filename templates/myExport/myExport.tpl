#TEMPLATE(myExport,'myExport - Export any browse or list to CSV / TSV / XML / JSON / Excel - v1.0'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  myExport template set  -  puts an "Export..." button on any browse or list.
#!
#!  Press it and a modal dialog asks for the FORMAT and for the FOLDER + FILE
#!  NAME (with a real Save-As browser), then writes the file:
#!
#!      CSV             comma separated, the machine's code page
#!      CSV (UTF-8)     comma separated, UTF-8 with a BOM - accents survive Excel
#!      TSV             tab separated
#!      XML             UTF-8, one element per column
#!      JSON            UTF-8, an array of objects; numeric columns stay numbers
#!      Excel .xlsx     a REAL OOXML workbook - frozen heading row, auto-filter,
#!                      on-screen column widths, numbers as numbers
#!      HTML            a styled table, ready to print or paste
#!
#!  NO external program is needed for the Excel format. An .xlsx is a ZIP of XML
#!  parts, and ExportClass builds both - so there is no helper .exe, no Python,
#!  no COM automation, no Excel installation and nothing extra to deploy.
#!
#!  It exports EXACTLY WHAT THE USER SEES. At run time it reads the LIST's own
#!  FORMAT (PROPLIST:Exists / FieldNo / Header / Picture) and pulls the values
#!  with WHAT(Queue,FieldNo) - so re-ordered, resized or hidden columns, and any
#!  column pictures, all carry across without you configuring a thing.
#!
#!  THE TEMPLATES
#!    myExportGlobal (APPLICATION) - INCLUDEs ExportClass. Add once, globally.
#!    myExportButton (CONTROL)     - THE EASY PATH: drag onto a browse window and
#!                   it drops a ready-wired Export button. Multiple per window.
#!                   Self-contained; the global extension is optional.
#!    myExportHere   (CODE)        - already have a button, menu item or toolbar
#!                   entry? Drop this code template into its Accepted embed.
#!
#!  REQUIRED FILES: copy these (shipped beside this .tpl) to a folder on the
#!  Clarion redirection path (the app folder or \clarion12\libsrc\win), ANSI:
#!      ExportClass.inc     ExportClass.clw
#!  ExportClass.clw is pulled into the build automatically by its LINK attribute.
#!
#!  API (the object lives in the procedure's data - call it from any embed):
#!    Exporter1.Ask()          modal format + file name dialog. 1 = go ahead
#!    Exporter1.ExportQueue()  write every record in the queue
#!    Exporter1.Run()          Ask + ExportQueue
#!    Exporter1.StartFile() / .AddRow() / .EndFile()   drive the rows yourself
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - myExportGlobal
#!#############################################################################
#EXTENSION(myExportGlobal,'myExport - Global (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('myExport')
      #DISPLAY('myExport Global - Version 1.0')
      #DISPLAY('Makes ExportClass available to every procedure in the app.')
      #DISPLAY('')
      #DISPLAY('IMPORTANT: copy ExportClass.inc and ExportClass.clw to the')
      #DISPLAY('redirection path (the app folder, or \clarion12\libsrc\win).')
      #DISPLAY('Both files must be ANSI. ExportClass.clw links itself in.')
      #DISPLAY('')
      #DISPLAY('This extension is OPTIONAL - the Export button control template')
      #DISPLAY('pulls the class in on its own. Add it if you want to call the')
      #DISPLAY('class from hand-written code in procedures with no button.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%xgDisable,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#AT(%AfterGlobalIncludes),WHERE(%xgDisable=0)
INCLUDE('ExportClass.INC'),ONCE
#ENDAT
#!#############################################################################
#!  CONTROL TEMPLATE - myExportButton  -  drag an Export button onto a browse
#!#############################################################################
#!  Drops a BUTTON and wires the whole export to it in one drag. Self-contained:
#!  it emits INCLUDE('ExportClass.INC'),ONCE at %CustomGlobalDeclarations - the
#!  per-MODULE compile-global embed (corpus: ABDROPS.TPW:65, a control template
#!  writing a global declaration). ,ONCE keys on the filename across the whole
#!  compile, so the class is pulled in exactly once even when the global
#!  extension is present too.
#!
#!  The button's own field equate is captured in %xbBtn with the shipped
#!  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance) idiom
#!  (corpus: CONTROL.TPW:107, CloseButton) so it tracks AppGen's auto-uniqued
#!  feq and MULTI drops keep working.
#!
#!  The QUEUE is read out of the LIST's own FROM() attribute at generate time -
#!  EXTRACT(%ControlStatement,'FROM',1), the same call the shipped BrowseBox
#!  makes at ABBROWSE.TPW:825. So it just works for an ABC BrowseBox
#!  (FROM(Queue:Browse)) and for any hand-coded LIST, with nothing to type.
#!
#!  The export code is emitted INLINE in the button's Accepted handler rather
#!  than as a ROUTINE: %ControlEventHandling lands inside ThisWindow's methods,
#!  and no shipped template calls a procedure ROUTINE from there.
#!#############################################################################
#CONTROL(myExportButton,'myExport - Export button for a browse/list (drag onto a window)'),WINDOW,MULTI,DESCRIPTION('Export ' & %xbList & ' to a file'),HLP('~myExport.htm')
  CONTROLS
    BUTTON('&Export...'),AT(,,54,14),USE(?ExportBtn),TIP('Export this list to a file')
  END
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #PROMPT('&Disable this button',CHECK),%xbDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%xbObject,REQ,DEFAULT('Exporter' & %ActiveTemplateInstance)
    #ENDBOXED
    #BOXED('What to export')
      #PROMPT('&List control to export:',CONTROL),%xbList,REQ
      #PROMPT('&Records:',DROP('Every record in the browse - walks the view[1]|Only the rows currently loaded in the list queue[0]')),%xbScope,DEFAULT('1')
      #ENABLE(%xbScope='1')
        #PROMPT('&Browse object:',@s64),%xbBrowse,DEFAULT('BRW1')
        #DISPLAY('The ABC BrowseBox object that fills the list - BRW1, BRW2...')
        #DISPLAY('(see the BrowseBox extension''s Classes tab if you are unsure).')
      #ENDENABLE
      #DISPLAY('')
      #PROMPT('&Queue (blank = read it from the list''s FROM):',@s64),%xbQueueOver,DEFAULT('')
      #DISPLAY('Only fill this in when the list is bound with PROP:From at run')
      #DISPLAY('time, so there is no FROM() in the window for us to read.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Formats')
    #BOXED('Offer these formats in the export dialog')
      #PROMPT('&CSV - comma separated',CHECK),%xbCSV,DEFAULT(1),AT(10)
      #PROMPT('CSV - comma separated, &UTF-8 (accents survive Excel)',CHECK),%xbCSVU,DEFAULT(1),AT(10)
      #PROMPT('&TSV - tab separated',CHECK),%xbTSV,DEFAULT(1),AT(10)
      #PROMPT('&XML document',CHECK),%xbXML,DEFAULT(1),AT(10)
      #PROMPT('&JSON document',CHECK),%xbJSON,DEFAULT(1),AT(10)
      #PROMPT('&Excel workbook (.xlsx)',CHECK),%xbXLSX,DEFAULT(1),AT(10)
      #PROMPT('&HTML table',CHECK),%xbHTML,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('About the Excel format')
      #DISPLAY('The .xlsx is written here, in Clarion - a real OOXML workbook')
      #DISPLAY('with a frozen heading row, an auto-filter, the on-screen column')
      #DISPLAY('widths and numbers stored as numbers. No Excel, no COM, no')
      #DISPLAY('helper program, nothing extra to deploy.')
      #DISPLAY('')
      #DISPLAY('Its parts are STORED (an uncompressed but perfectly valid ZIP).')
      #DISPLAY('For a smaller file on very large exports, set _ExportDeflate_')
      #DISPLAY('to 1 at the top of ExportClass.inc and put CompressClass.inc /')
      #DISPLAY('.clw (the myCompress template) on the redirection path.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Options')
    #BOXED('Content')
      #PROMPT('&Title (sheet name, XML root, HTML heading):',@s64),%xbTitle,DEFAULT(%Procedure)
      #PROMPT('XML &row element:',@s32),%xbRowTag,DEFAULT('Row')
      #PROMPT('CSV &separator:',@s1),%xbDelim,DEFAULT(',')
      #PROMPT('Include the column &headings',CHECK),%xbHeaders,DEFAULT(1),AT(10)
      #PROMPT('Apply each column''s &picture',CHECK),%xbPictures,DEFAULT(1),AT(10)
      #PROMPT('&Visible columns only (skip hidden and icon columns)',CHECK),%xbVisible,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('Afterwards')
      #PROMPT('&Open the file in its default program',CHECK),%xbOpenAfter,DEFAULT(1),AT(10)
      #PROMPT('Show the "N rows exported" &confirmation',CHECK),%xbConfirm,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('Starting folder')
      #PROMPT('&Suggest this folder (blank = the current directory):',@s128),%xbFolder,DEFAULT('')
      #DISPLAY('Only a suggestion - the user still picks the folder and name.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#ATSTART
  #DECLARE(%xbBtn)
  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance)
    #SET(%xbBtn,%Control)
  #ENDFOR
  #DECLARE(%xbQueue)
  #SET(%xbQueue,%xbQueueOver)
  #IF(~%xbQueue)
    #FOR(%Control),WHERE(%Control=%xbList)
      #SET(%xbQueue,EXTRACT(%ControlStatement,'FROM',1))
    #ENDFOR
  #ENDIF
  #DECLARE(%xbMask)
  #SET(%xbMask,0)
  #IF(%xbCSV)
    #SET(%xbMask,%xbMask+1)
  #ENDIF
  #IF(%xbCSVU)
    #SET(%xbMask,%xbMask+2)
  #ENDIF
  #IF(%xbTSV)
    #SET(%xbMask,%xbMask+4)
  #ENDIF
  #IF(%xbXML)
    #SET(%xbMask,%xbMask+8)
  #ENDIF
  #IF(%xbJSON)
    #SET(%xbMask,%xbMask+16)
  #ENDIF
  #IF(%xbXLSX)
    #SET(%xbMask,%xbMask+32)
  #ENDIF
  #IF(%xbHTML)
    #SET(%xbMask,%xbMask+64)
  #ENDIF
  #IF(%xbMask=0)
    #SET(%xbMask,127)
  #ENDIF
#ENDAT
#!
#! Self-contained: pull in the class (,ONCE = safe alongside the global extension).
#AT(%CustomGlobalDeclarations),WHERE(%xbDisable=0)
INCLUDE('ExportClass.INC'),ONCE
#ENDAT
#!
#AT(%DataSection),WHERE(%xbDisable=0 AND %xbList AND %xbQueue)
%xbObject            ExportClass                          ! exports %xbList to a file
#ENDAT
#!
#! Everything is set up at click time, not at open time, so a column the user
#! re-ordered, resized or hid since the window opened is honoured.
#AT(%ControlEventHandling,%xbBtn,'Accepted'),WHERE(%xbDisable=0 AND %xbList AND %xbQueue)
  %xbObject.Init(%xbList,%xbQueue)                         ! re-reads the list's live layout
  %xbObject.Title        = '%xbTitle'
#IF(%xbRowTag)
  %xbObject.RowTag       = '%xbRowTag'
#ENDIF
#IF(%xbDelim)
  %xbObject.Delim        = '%xbDelim'
#ENDIF
  %xbObject.Headers      = %xbHeaders
  %xbObject.Pictures     = %xbPictures
  %xbObject.VisibleOnly  = %xbVisible
  %xbObject.OpenWhenDone = %xbOpenAfter
  %xbObject.Confirm      = %xbConfirm
  %xbObject.Allow        = %xbMask
#IF(%xbFolder)
  IF ~%xbObject.FileName                                   ! only the first time
    %xbObject.FileName = CLIP('%xbFolder') & '\' & %xbObject.SuggestName()
  END
#ENDIF
#EMBED(%myExportBeforeAsk,'myExport - before the export dialog opens'),%ActiveTemplateInstance,HIDE
  IF %xbObject.Ask()                                       ! format + folder + file name
#IF(%xbScope='1')
    IF %xbObject.StartFile()
      %xbBrowse.Reset()                                    ! the top of the current sort order
      LOOP
        IF %xbBrowse.Next() THEN BREAK .                   ! Level:Notify = end of the view
        %xbBrowse.SetQueueRecord()                         ! view record -> the queue buffer
        %xbObject.AddRow()
      END
      %xbObject.EndFile()
      %xbBrowse.ResetSort(1)                               ! refill the browse we just walked
      %xbBrowse.UpdateWindow()
    END
#ELSE
    %xbObject.ExportQueue()
#ENDIF
#EMBED(%myExportAfterExport,'myExport - after the file has been written'),%ActiveTemplateInstance,HIDE
  END
#ENDAT
#!#############################################################################
#!  CODE TEMPLATE - myExportHere  -  export from an existing button/menu/toolbar
#!#############################################################################
#!  Same engine, dropped wherever you want it: a menu item's Accepted embed, an
#!  existing button, a toolbar entry, a hot key. ,PROCEDURE lets a #CODE template
#!  own procedure-scope #AT sections (corpus: ABPOPUP.TPW:1, DisplayPopupMenu),
#!  which is how it declares its own object in %DataSection.
#!#############################################################################
#CODE(myExportHere,'myExport - Export a list to a file (CSV/TSV/XML/JSON/Excel)'),MULTI,PROCEDURE,DESCRIPTION('Export ' & %xcList & ' to a file'),HLP('~myExport.htm')
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #PROMPT('&Object name:',@s64),%xcObject,REQ,DEFAULT('Exporter' & %ActiveTemplateInstance)
    #ENDBOXED
    #BOXED('What to export')
      #PROMPT('&List control to export:',CONTROL),%xcList,REQ
      #PROMPT('&Records:',DROP('Every record in the browse - walks the view[1]|Only the rows currently loaded in the list queue[0]')),%xcScope,DEFAULT('1')
      #ENABLE(%xcScope='1')
        #PROMPT('&Browse object:',@s64),%xcBrowse,DEFAULT('BRW1')
      #ENDENABLE
      #PROMPT('&Queue (blank = read it from the list''s FROM):',@s64),%xcQueueOver,DEFAULT('')
    #ENDBOXED
  #ENDTAB
  #TAB('&Formats')
    #BOXED('Offer these formats in the export dialog')
      #PROMPT('&CSV - comma separated',CHECK),%xcCSV,DEFAULT(1),AT(10)
      #PROMPT('CSV - comma separated, &UTF-8',CHECK),%xcCSVU,DEFAULT(1),AT(10)
      #PROMPT('&TSV - tab separated',CHECK),%xcTSV,DEFAULT(1),AT(10)
      #PROMPT('&XML document',CHECK),%xcXML,DEFAULT(1),AT(10)
      #PROMPT('&JSON document',CHECK),%xcJSON,DEFAULT(1),AT(10)
      #PROMPT('&Excel workbook (.xlsx)',CHECK),%xcXLSX,DEFAULT(1),AT(10)
      #PROMPT('&HTML table',CHECK),%xcHTML,DEFAULT(1),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Options')
    #BOXED('Content')
      #PROMPT('&Title (sheet name, XML root, HTML heading):',@s64),%xcTitle,DEFAULT(%Procedure)
      #PROMPT('XML &row element:',@s32),%xcRowTag,DEFAULT('Row')
      #PROMPT('CSV &separator:',@s1),%xcDelim,DEFAULT(',')
      #PROMPT('Include the column &headings',CHECK),%xcHeaders,DEFAULT(1),AT(10)
      #PROMPT('Apply each column''s &picture',CHECK),%xcPictures,DEFAULT(1),AT(10)
      #PROMPT('&Visible columns only',CHECK),%xcVisible,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('Afterwards')
      #PROMPT('&Open the file in its default program',CHECK),%xcOpenAfter,DEFAULT(1),AT(10)
      #PROMPT('Show the "N rows exported" &confirmation',CHECK),%xcConfirm,DEFAULT(1),AT(10)
      #PROMPT('&Suggest this folder (blank = the current directory):',@s128),%xcFolder,DEFAULT('')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#ATSTART
  #DECLARE(%xcQueue)
  #SET(%xcQueue,%xcQueueOver)
  #IF(~%xcQueue)
    #FOR(%Control),WHERE(%Control=%xcList)
      #SET(%xcQueue,EXTRACT(%ControlStatement,'FROM',1))
    #ENDFOR
  #ENDIF
  #DECLARE(%xcMask)
  #SET(%xcMask,0)
  #IF(%xcCSV)
    #SET(%xcMask,%xcMask+1)
  #ENDIF
  #IF(%xcCSVU)
    #SET(%xcMask,%xcMask+2)
  #ENDIF
  #IF(%xcTSV)
    #SET(%xcMask,%xcMask+4)
  #ENDIF
  #IF(%xcXML)
    #SET(%xcMask,%xcMask+8)
  #ENDIF
  #IF(%xcJSON)
    #SET(%xcMask,%xcMask+16)
  #ENDIF
  #IF(%xcXLSX)
    #SET(%xcMask,%xcMask+32)
  #ENDIF
  #IF(%xcHTML)
    #SET(%xcMask,%xcMask+64)
  #ENDIF
  #IF(%xcMask=0)
    #SET(%xcMask,127)
  #ENDIF
#ENDAT
#!
#AT(%CustomGlobalDeclarations)
INCLUDE('ExportClass.INC'),ONCE
#ENDAT
#!
#AT(%DataSection),WHERE(%xcList AND %xcQueue)
%xcObject            ExportClass                          ! exports %xcList to a file
#ENDAT
#!
#! ...and the code template's own output, right where it was dropped:
#IF(%xcList AND %xcQueue)
%xcObject.Init(%xcList,%xcQueue)
%xcObject.Title        = '%xcTitle'
#IF(%xcRowTag)
%xcObject.RowTag       = '%xcRowTag'
#ENDIF
#IF(%xcDelim)
%xcObject.Delim        = '%xcDelim'
#ENDIF
%xcObject.Headers      = %xcHeaders
%xcObject.Pictures     = %xcPictures
%xcObject.VisibleOnly  = %xcVisible
%xcObject.OpenWhenDone = %xcOpenAfter
%xcObject.Confirm      = %xcConfirm
%xcObject.Allow        = %xcMask
#IF(%xcFolder)
IF ~%xcObject.FileName
  %xcObject.FileName = CLIP('%xcFolder') & '\' & %xcObject.SuggestName()
END
#ENDIF
IF %xcObject.Ask()
#IF(%xcScope='1')
  IF %xcObject.StartFile()
    %xcBrowse.Reset()
    LOOP
      IF %xcBrowse.Next() THEN BREAK .
      %xcBrowse.SetQueueRecord()
      %xcObject.AddRow()
    END
    %xcObject.EndFile()
    %xcBrowse.ResetSort(1)
    %xcBrowse.UpdateWindow()
  END
#ELSE
  %xcObject.ExportQueue()
#ENDIF
END
#ELSE
! myExport: pick a List control in the code template's prompts, and give it a
! Queue if the list has no FROM() attribute for the template to read.
#ENDIF
#!-----------------------------------------------------------------------------
#! End of myExport template set
#!-----------------------------------------------------------------------------
