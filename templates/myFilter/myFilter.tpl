#TEMPLATE(myFilter,'myFilter - Build filters for any browse - v1.0'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  myFilter template set  -  puts a Filters button on any browse. Press it and
#!  a modal window lists the browse's own fields; tick one, say how to test it
#!  (equals, begins with, contains, a range, in the last N days...), press Add,
#!  and repeat. Apply hands the browse a real filter.
#!
#!  The fields come from the BROWSE ITSELF at generate time - the template
#!  walks the browse's queue back to the dictionary fields the same way the
#!  shipped QBE does - so there is nothing to list by hand and nothing to keep
#!  in step when the browse changes.
#!
#!  THE FILTER IS ANDed, NOT SUBSTITUTED
#!    BRW1.SetFilter(expression,'7 myFilter')
#!  ABC keeps filters in a named, conjunctive list. Ours sits in its own slot,
#!  so a range limit, a locator or a QBE still apply alongside it, and applying
#!  an empty filter deletes the slot instead of leaving a stale one behind.
#!
#!  ----------------------------------------------------------------------
#!  THE ONE PREREQUISITE: tick BINDABLE on the file in the dictionary
#!  ----------------------------------------------------------------------
#!  A filter is evaluated by field name at run time and the runtime refuses a
#!  field it was never told about - "BIND has not been called for CUS:Name".
#!  ABC calls BIND for you whenever it opens a file, but only for a file that
#!  carries the BINDABLE attribute. Nothing else is needed, and nothing else
#!  will do.
#!
#!  THE TEMPLATES
#!    myFilterGlobal (APPLICATION) - language, and where saved filters live.
#!    myFilterButton (CONTROL)     - THE EASY PATH: drop it on a browse window,
#!                   name the browse object, done. MULTI - one per browse.
#!    myFilterHere   (CODE)        - open the filter window from any embed, for
#!                   a button, a menu item or a hot key you already have.
#!
#!  REQUIRED FILES: copy these to a folder on the redirection path, ANSI:
#!      MyFilterClass.inc   MyFilterClass.clw
#!  MyFilterClass.clw links itself into the build. The sources are pure ASCII.
#!  FilterTables.txt has the table structures, if you want saved filters shared
#!  between users rather than kept per user in the application's own INI.
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GROUP - map a dictionary field to one of the class's field types
#!#############################################################################
#!  Picture first, because a date is very often held in a LONG and only the
#!  picture gives it away. Then the storage type.
#!#############################################################################
#GROUP(%mfTypeOf,%pType,%pPicture,*%pOut),AUTO
  #SET(%pOut,'Flt:String')
  #IF(%pPicture AND LEN(CLIP(%pPicture)) >= 2)
    #IF(UPPER(SLICE(%pPicture,1,2)) = '@D')
      #SET(%pOut,'Flt:Date')
      #RETURN
    #ENDIF
    #IF(UPPER(SLICE(%pPicture,1,2)) = '@T')
      #SET(%pOut,'Flt:Time')
      #RETURN
    #ENDIF
  #ENDIF
  #CASE(UPPER(%pType))
  #OF('DATE')
    #SET(%pOut,'Flt:Date')
  #OF('TIME')
    #SET(%pOut,'Flt:Time')
  #OF('BYTE')
    #SET(%pOut,'Flt:Number')
  #OF('SHORT') #OROF('USHORT') #OROF('LONG') #OROF('ULONG')
  #OROF('SREAL') #OROF('REAL') #OROF('DECIMAL') #OROF('PDECIMAL')
    #SET(%pOut,'Flt:Number')
  #ENDCASE
#!#############################################################################
#!  GROUP - the AddField calls, from the procedure's file schematic
#!#############################################################################
#!  NOT from the browse queue. %QueueField belongs to the BROWSE template's own
#!  instance and is simply not in scope for an independent control template -
#!  asking for it fails at generate time with
#!      variable %QueueField is not defined
#!  The file schematic is procedure-wide, so %Primary and its joined
#!  %Secondary files are reachable from here, and every field of them is
#!  offered rather than only the columns on display. That is the better answer
#!  anyway: filtering on a field the browse does not happen to show is a normal
#!  thing to want, and BINDABLE covers the whole record either way.
#!#############################################################################
#GROUP(%mfAddFields,%pObject)
  #DECLARE(%mfType)
  #DECLARE(%mfLabel)
  #DECLARE(%mfAny,LONG)
  #SET(%mfAny,0)
  #IF(%Primary)
    #FIX(%File,%Primary)
    #FOR(%Field)
      #CALL(%mfEmitField,%pObject)
    #ENDFOR
    #FOR(%Secondary),WHERE(%SecondaryTo=%Primary)
      #FIX(%File,%Secondary)
      #FOR(%Field)
        #CALL(%mfEmitField,%pObject)
      #ENDFOR
    #ENDFOR
  #ENDIF
  #IF(~%mfAny)
    ! myFilter: this procedure has no file schematic, so there are no fields to
    ! offer. Add the file to the procedure, or call AddField yourself here.
  #ENDIF
#!-----------------------------------------------------------------------------
#GROUP(%mfEmitField,%pObject)
  #!  GROUP/END are structure markers, and MEMO/BLOB cannot go in a filter.
  #IF(UPPER(%FieldType) = 'GROUP' OR UPPER(%FieldType) = 'END' OR UPPER(%FieldType) = 'MEMO' OR UPPER(%FieldType) = 'BLOB')
    #RETURN
  #ENDIF
  #SET(%mfLabel,CLIP(%FieldHeader))
  #IF(~%mfLabel)
    #SET(%mfLabel,CLIP(%FieldDescription))
  #ENDIF
  #IF(~%mfLabel)
    #SET(%mfLabel,CLIP(%FieldID))
  #ENDIF
  #!  An apostrophe in a header ("Teacher's name") would close the Clarion
  #!  literal early and the generated line would not compile. The field id
  #!  cannot contain one, so fall back to that.
  #IF(INSTRING('''',%mfLabel,1,1))
    #SET(%mfLabel,CLIP(%FieldID))
  #ENDIF
  #CALL(%mfTypeOf,%FieldType,%FieldPicture,%mfType)
  #SET(%mfAny,1)
  %pObject.AddField('%Field','%mfLabel',%mfType,'%FieldPicture')
#!#############################################################################
#!  GLOBAL EXTENSION - myFilterGlobal
#!#############################################################################
#EXTENSION(myFilterGlobal,'myFilter - Global (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('myFilter')
      #DISPLAY('myFilter Global - Version 1.0')
      #DISPLAY('Makes MyFilterClass available to every procedure in the app.')
      #DISPLAY('')
      #DISPLAY('IMPORTANT: copy MyFilterClass.inc and MyFilterClass.clw to the')
      #DISPLAY('redirection path (the app folder, or \clarion12\libsrc\win).')
      #DISPLAY('Both must be ANSI. MyFilterClass.clw links itself in.')
      #DISPLAY('')
      #DISPLAY('AND TICK "BINDABLE" ON THE FILES YOU FILTER, in the')
      #DISPLAY('dictionary. A filter is evaluated by field name at run time,')
      #DISPLAY('and an unbound field fails with "BIND has not been called".')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%mfgDisable,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Defaults')
    #BOXED('Language')
      #PROMPT('Filter window &language:',DROP('English[1]|Espanol (Spanish)[2]')),%mfgLanguage,DEFAULT('1')
      #DISPLAY('The language every filter window opens in: the labels, the')
      #DISPLAY('test names and the buttons. Each button can override it.')
    #ENDBOXED
    #BOXED('Where saved filters are kept')
      #PROMPT('&Storage:',DROP('The application''s own INI file[0]|A table (FilterHdr / FilterLine)[1]')),%mfgStorage,DEFAULT('0')
      #DISPLAY('The INI needs no setup and keeps each user''s filters to')
      #DISPLAY('themselves. Choose the table when filters should be shared, or')
      #DISPLAY('live on the server beside the data - see FilterTables.txt for')
      #DISPLAY('the structures, and derive the class to fill in SaveTable,')
      #DISPLAY('LoadTable, DeleteTable and TableNames.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#AT(%AfterGlobalIncludes),WHERE(%mfgDisable=0)
INCLUDE('MyFilterClass.INC'),ONCE
#ENDAT
#!
#AT(%GlobalData),WHERE(%mfgDisable=0)
#IF(%mfgLanguage)
myFilterLanguage     BYTE(%mfgLanguage)                   ! 1 = English, 2 = Espanol
#ELSE
myFilterLanguage     BYTE(1)                              ! 1 = English, 2 = Espanol
#ENDIF
myFilterStorage      BYTE(%mfgStorage)                    ! 0 = INI, 1 = table
#ENDAT
#!#############################################################################
#!  CONTROL TEMPLATE - myFilterButton  -  a Filters button on a browse
#!#############################################################################
#CONTROL(myFilterButton,'myFilter - Filters button for a browse'),WINDOW,MULTI,REQ(myFilterGlobal),DESCRIPTION('Filters for ' & %mfBrowse),HLP('~myFilter.htm')
  CONTROLS
    BUTTON('&Filters...'),AT(,,56,14),USE(?FilterBtn),TIP('Build a filter for this list')
  END
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #PROMPT('&Disable this button',CHECK),%mfDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%mfObject,REQ,DEFAULT('Flt' & %ActiveTemplateInstance)
    #ENDBOXED
    #BOXED('The browse it filters')
      #PROMPT('&Browse object:',@s64),%mfBrowse,REQ,DEFAULT('BRW1')
      #DISPLAY('The ABC browse object on this window - BRW1 unless there is')
      #DISPLAY('more than one browse, in which case check the Browse Box')
      #DISPLAY('extension for the name.')
      #PROMPT('&Window title (blank = the localised word):',@s64),%mfTitle,DEFAULT('')
    #ENDBOXED
    #BOXED('The button')
      #DISPLAY('Change the button text the normal way, on the control itself.')
      #PROMPT('Show the &condition count on the button',CHECK),%mfCount,DEFAULT(1),AT(10)
      #DISPLAY('The button reads "Filters (3)" while three conditions are on,')
      #DISPLAY('so it is obvious the list is not showing everything.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Options')
    #BOXED('Searching')
      #PROMPT('&Case sensitive text compares',CHECK),%mfCase,DEFAULT(0),AT(10)
      #DISPLAY('Off (the normal choice) wraps text compares in UPPER(), so')
      #DISPLAY('smith finds Smith and SMITH.')
    #ENDBOXED
    #BOXED('Saved filters')
      #PROMPT('&Profile name (blank = this procedure):',@s64),%mfProfile,DEFAULT('')
      #DISPLAY('Saved filters are grouped under this name. Leave it blank and')
      #DISPLAY('each browse keeps its own; give two browses the same profile')
      #DISPLAY('on purpose and they share.')
      #PROMPT('&INI file (blank = the application''s own):',@s128),%mfIni,DEFAULT('')
    #ENDBOXED
    #BOXED('Language')
      #PROMPT('&Language:',DROP('Use the application setting[0]|English[1]|Espanol (Spanish)[2]')),%mfLang,DEFAULT('0')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#ATSTART
  #DECLARE(%mfBtn)
  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance)
    #SET(%mfBtn,%Control)
  #ENDFOR
#ENDAT
#!
#AT(%CustomGlobalDeclarations),WHERE(%mfDisable=0)
INCLUDE('MyFilterClass.INC'),ONCE
#ENDAT
#!
#AT(%DataSection),WHERE(%mfDisable=0)
%mfObject            MyFilterClass                        ! filters for %mfBrowse
#ENDAT
#!
#AT(%ControlEventHandling,%mfBtn,'Accepted'),WHERE(%mfDisable=0)
!  The field list is built on the first press rather than at window open, so
!  the button costs nothing on a window where nobody filters.
  IF ~%mfObject.FieldCount()
#INSERT(%mfAddFields,%mfObject)
  END
#IF(%mfTitle)
  %mfObject.Title         = '%mfTitle'
#ENDIF
#IF(%mfLang AND %mfLang <> '0')
  %mfObject.Language      = %mfLang                        ! this button overrides
#ELSE
  %mfObject.Language      = myFilterLanguage               ! whatever the global says
#ENDIF
  %mfObject.Storage       = myFilterStorage
  %mfObject.CaseSensitive = %mfCase
#IF(%mfProfile)
  %mfObject.Profile       = '%mfProfile'
#ELSE
  %mfObject.Profile       = '%Procedure'
#ENDIF
#IF(%mfIni)
  %mfObject.IniFile       = '%mfIni'
#ENDIF
#EMBED(%myFilterBeforeOpen,'myFilter - before the filter window opens'),%ActiveTemplateInstance,HIDE
  IF %mfObject.Ask()
    %mfBrowse.SetFilter(%mfObject.Expression(),Flt:Slot)    ! ANDed with the browse's own
    %mfBrowse.ResetSort(1)
#IF(%mfCount)
    IF %mfObject.CondCount()
      ?%mfBtn{PROP:Text} = CLIP(%mfObject.Txt(FTx:Title)) & ' (' & %mfObject.CondCount() & ')'
    ELSE
      ?%mfBtn{PROP:Text} = %mfObject.Txt(FTx:Title)
    END
#ENDIF
#EMBED(%myFilterAfterApply,'myFilter - after the filter was applied'),%ActiveTemplateInstance,HIDE
  END
#ENDAT
#!#############################################################################
#!  CODE TEMPLATE - myFilterHere  -  from a button or menu you already have
#!#############################################################################
#CODE(myFilterHere,'myFilter - Open the filter window for a browse'),MULTI,PROCEDURE,REQ(myFilterGlobal),DESCRIPTION('Filters for ' & %mhBrowse),HLP('~myFilter.htm')
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #PROMPT('&Object name:',@s64),%mhObject,REQ,DEFAULT('Flt' & %ActiveTemplateInstance)
      #PROMPT('&Browse object:',@s64),%mhBrowse,REQ,DEFAULT('BRW1')
      #PROMPT('&Window title (blank = the localised word):',@s64),%mhTitle,DEFAULT('')
      #PROMPT('&Case sensitive text compares',CHECK),%mhCase,DEFAULT(0),AT(10)
      #PROMPT('&Profile name (blank = this procedure):',@s64),%mhProfile,DEFAULT('')
      #PROMPT('&Language:',DROP('Use the application setting[0]|English[1]|Espanol (Spanish)[2]')),%mhLang,DEFAULT('0')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#AT(%CustomGlobalDeclarations)
INCLUDE('MyFilterClass.INC'),ONCE
#ENDAT
#!
#AT(%DataSection)
%mhObject            MyFilterClass                        ! filters for %mhBrowse
#ENDAT
#!
IF ~%mhObject.FieldCount()
#INSERT(%mfAddFields,%mhObject)
END
#IF(%mhTitle)
%mhObject.Title         = '%mhTitle'
#ENDIF
#IF(%mhLang AND %mhLang <> '0')
%mhObject.Language      = %mhLang
#ELSE
%mhObject.Language      = myFilterLanguage
#ENDIF
%mhObject.Storage       = myFilterStorage
%mhObject.CaseSensitive = %mhCase
#IF(%mhProfile)
%mhObject.Profile       = '%mhProfile'
#ELSE
%mhObject.Profile       = '%Procedure'
#ENDIF
IF %mhObject.Ask()
  %mhBrowse.SetFilter(%mhObject.Expression(),Flt:Slot)
  %mhBrowse.ResetSort(1)
END
#!-----------------------------------------------------------------------------
#! End of myFilter template set
#!-----------------------------------------------------------------------------
