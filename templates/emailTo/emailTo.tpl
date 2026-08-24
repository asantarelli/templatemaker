#TEMPLATE(emailTo,'emailTo - Send e-mail from Clarion: SMTP/TLS, OAuth2 (Gmail, Outlook, Microsoft 365) and REST APIs - v1.02 (2026-08-23 20:56)'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  emailTo template set  -  send e-mail from a Clarion application, four ways,
#!  with no third-party DLL, no .NET and no OpenSSL to deploy.
#!
#!      SMTP          plain / STARTTLS / implicit TLS, on any server, signing
#!                    in with AUTH LOGIN, AUTH PLAIN or OAuth2 (XOAUTH2).
#!      Gmail API     one https POST to gmail.googleapis.com.
#!      MS Graph      one https POST to graph.microsoft.com - the only route
#!                    many locked-down Microsoft 365 tenants still allow.
#!      API key       SendGrid / Mailgun / Resend / Brevo / Postmark / Mailjet.
#!
#!  HOW IT IS BUILT.  Everything is pure Clarion except one bundled C file,
#!  emailc.c, which is compiled into your .EXE by Clarion's own C compiler
#!  through PRAGMA('compile(emailc.c)'). That file exists because Clarion
#!  cannot do four things for itself: TCP sockets, the SCHANNEL TLS handshake,
#!  WinHTTP, and DPAPI. MIME, base64, quoted-printable, the SMTP conversation,
#!  OAuth2 with PKCE, JSON and every provider preset are Clarion source you can
#!  read and step through. Nothing is bound at link time to a DLL you have to
#!  ship: ws2_32, secur32, winhttp and crypt32 are all part of Windows and are
#!  loaded at run time, so a machine missing one gives a clean error message
#!  instead of failing to start.
#!
#!  THE TEMPLATES
#!    emailToGlobal   (APPLICATION) - REQUIRED once per app. Declares the mail
#!                    object, sets the account defaults, and - if you nominate
#!                    one - generates the code that reads and writes your own
#!                    settings TABLE.
#!    emailToButton   (CONTROL)     - drag onto any window for a ready-wired
#!                    "E-mail..." button.
#!    emailToSend     (CODE)        - send from any embed: your own button, a
#!                    menu item, the end of a report, a batch process.
#!    emailToCompose  (CODE)        - open the write-and-send window.
#!    emailToSetup    (CODE)        - open the account setup window, where the
#!                    end user types the server or presses "Sign in..." to run
#!                    the OAuth2 consent flow in their browser.
#!
#!  REQUIRED FILES: copy these (shipped beside this .tpl) to a folder on the
#!  Clarion redirection path (the app folder, or \clarion12\libsrc\win), ANSI:
#!      EmailNetClass.inc   EmailNetClass.clw
#!      EmailMsgClass.inc   EmailMsgClass.clw
#!      EmailToClass.inc    EmailToClass.clw
#!      emailc.c
#!  The .clw files pull themselves into the build through their LINK attribute,
#!  and EmailNetClass.clw pulls in emailc.c through its PRAGMA.
#!
#!  API (the object is global - call it from any embed in any procedure):
#!    Mailer.SendSimple(to, subject, body [, attachment])   1 = sent
#!    Mailer.Send(Mailer.Msg)      after composing Mailer.Msg yourself
#!    Mailer.Compose()             the write-and-send window
#!    Mailer.Setup()               the account setup window
#!    Mailer.TestAccount()         connect + sign in + hang up, sends nothing
#!    Mailer.LastErrorText         why the last call said no
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - emailToGlobal
#!#############################################################################
#EXTENSION(emailToGlobal,'emailTo - Global (add once per application)'),APPLICATION,HLP('~emailTo.htm')
#SHEET
  #TAB('&General')
    #BOXED('emailTo')
      #DISPLAY('emailTo v1.02  -  built 2026-08-23 20:56')
      #DISPLAY('Global extension - add once per application.')
      #DISPLAY('Makes the mail object available to every procedure in the app.')
      #DISPLAY('')
      #DISPLAY('IMPORTANT: copy these files to the redirection path (the app')
      #DISPLAY('folder, or \clarion12\libsrc\win). All must be ANSI:')
      #DISPLAY('    EmailNetClass.inc / .clw     EmailMsgClass.inc / .clw')
      #DISPLAY('    EmailToClass.inc  / .clw     emailc.c')
      #DISPLAY('')
      #DISPLAY('emailc.c is compiled into your EXE by Clarion''s own C')
      #DISPLAY('compiler. There is no DLL to ship and nothing to register.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%ETgDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%ETgObject,REQ,DEFAULT('Mailer')
      #PROMPT('&Language:',DROP('English[1]|Espa' & CHR(241) & 'ol (Spanish)[2]')),%ETgLanguage,DEFAULT('1')
      #PROMPT('&Keep a conversation log (for support)',CHECK),%ETgTrace,DEFAULT(1),AT(10)
      #DISPLAY('The log is what the Setup window shows on its Log tab.')
      #DISPLAY('Passwords and tokens are masked before they reach it.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Account')
    #BOXED('Where these settings come from')
      #DISPLAY('These are the DEFAULTS the object starts with. If you nominate')
      #DISPLAY('a settings table on the Table tab, whatever it holds overrides')
      #DISPLAY('them at start-up, and the Setup window writes changes back.')
      #DISPLAY('With no table, they are the defaults and the Setup window')
      #DISPLAY('saves to an INI file beside the EXE.')
    #ENDBOXED
    #BOXED('Account')
      #PROMPT('&Provider:',DROP('Other (SMTP)[0]|Gmail[1]|Outlook.com / Hotmail[2]|Microsoft 365[3]|Yahoo Mail[4]|iCloud Mail[5]|Zoho Mail[6]|Amazon SES[7]|SendGrid[8]|Mailgun[9]|Resend[10]|Brevo[11]|Postmark[12]|Mailjet[13]')),%ETgProvider,DEFAULT('0')
      #PROMPT('Send &using:',DROP('SMTP server[1]|Gmail API (https)[2]|Microsoft Graph (https)[3]|Provider API key (https)[4]')),%ETgTransport,DEFAULT('1')
      #PROMPT('&From address:',@s255),%ETgFromAddr,DEFAULT('')
      #PROMPT('From &name:',@s128),%ETgFromName,DEFAULT('')
      #PROMPT('&Reply to:',@s255),%ETgReplyTo,DEFAULT('')
    #ENDBOXED
    #BOXED('SMTP server')
      #PROMPT('&Server:',@s128),%ETgHost,DEFAULT('')
      #PROMPT('&Port:',@n5),%ETgPort,DEFAULT(587)
      #PROMPT('Se&curity:',DROP('None - plain, port 25[0]|STARTTLS - port 587[1]|TLS / SSL - port 465[2]')),%ETgSecurity,DEFAULT('1')
      #PROMPT('Sign in &with:',DROP('Nothing[0]|Password (AUTH LOGIN)[1]|Password (AUTH PLAIN)[2]|OAuth2 token (XOAUTH2)[3]')),%ETgAuth,DEFAULT('1')
      #PROMPT('&User name:',@s255),%ETgUser,DEFAULT('')
      #PROMPT('Pass&word:',@s255),%ETgPassword,DEFAULT('')
      #DISPLAY('A password typed here is COMPILED IN. For anything you would')
      #DISPLAY('not publish, leave it blank and let the Setup window store it -')
      #DISPLAY('that path encrypts it with DPAPI for the Windows user.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Sign-in')
    #BOXED('OAuth2 - Gmail, Outlook.com and Microsoft 365')
      #DISPLAY('Register a DESKTOP application with the provider and paste its')
      #DISPLAY('Client ID here. A desktop client ID is not a secret: emailTo')
      #DISPLAY('uses the PKCE flow, so nothing confidential is in your EXE.')
      #DISPLAY('')
      #DISPLAY('  Google     console.cloud.google.com > Credentials >')
      #DISPLAY('             OAuth client ID > Desktop app')
      #DISPLAY('  Microsoft  portal.azure.com > App registrations > New >')
      #DISPLAY('             Public client, redirect http://localhost')
      #DISPLAY('')
      #DISPLAY('Both must allow the loopback redirect http://127.0.0.1:<port>/')
      #DISPLAY('which is what a desktop app registration gives you.')
      #PROMPT('Client &ID:',@s255),%ETgClientId,DEFAULT('')
      #PROMPT('Client &secret:',@s255),%ETgClientSecret,DEFAULT('')
      #DISPLAY('(leave the secret blank for Microsoft, and for Google desktop')
      #DISPLAY(' clients that were not issued one)')
      #PROMPT('&Tenant:',@s128),%ETgTenant,DEFAULT('common')
      #DISPLAY('Microsoft only: common, organizations, or your tenant GUID.')
    #ENDBOXED
    #BOXED('API key services')
      #PROMPT('API &key:',@s255),%ETgApiKey,DEFAULT('')
      #PROMPT('API &domain:',@s128),%ETgApiDomain,DEFAULT('')
      #DISPLAY('The domain is Mailgun only - the domain you send from.')
      #DISPLAY('For Mailjet, put the PUBLIC key in User name (Account tab)')
      #DISPLAY('and the PRIVATE key here.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Table')
    #BOXED('Keep the account in one of your own tables')
      #DISPLAY('Nominate a table and emailTo generates the code that reads it')
      #DISPLAY('at start-up and writes it back when the Setup window saves.')
      #DISPLAY('Leave the table blank to use an INI file beside the EXE.')
      #DISPLAY('')
      #DISPLAY('EmailTables.txt (shipped beside this template) has a ready-made')
      #DISPLAY('structure you can paste straight into your dictionary.')
      #PROMPT('Settings &table:',FILE),%ETgFile
      #ENABLE(%ETgFile)
        #PROMPT('&Key to find the account by:',KEY(%ETgFile)),%ETgKey,REQ
        #PROMPT('&Account to load at start-up:',@s64),%ETgLoadName,DEFAULT('default')
        #DISPLAY('The value put in the Account name column before the GET.')
        #DISPLAY('Blank means: load the first record in the table.')
        #PROMPT('Create the row if it is &missing',CHECK),%ETgCreateRow,DEFAULT(1),AT(10)
      #ENDENABLE
    #ENDBOXED
    #ENABLE(%ETgFile)
      #BOXED('Columns - the account itself')
        #PROMPT('Account &name:',FIELD(%ETgFile)),%ETgColName,REQ
        #PROMPT('&Provider:',FIELD(%ETgFile)),%ETgColProvider
        #PROMPT('&Transport:',FIELD(%ETgFile)),%ETgColTransport
        #PROMPT('&Host:',FIELD(%ETgFile)),%ETgColHost
        #PROMPT('P&ort:',FIELD(%ETgFile)),%ETgColPort
        #PROMPT('&Security:',FIELD(%ETgFile)),%ETgColSecurity
        #PROMPT('&Auth mode:',FIELD(%ETgFile)),%ETgColAuth
      #ENDBOXED
    #ENDENABLE
  #ENDTAB
  #TAB('Ta&ble columns')
    #ENABLE(%ETgFile)
      #BOXED('Columns - credentials and addresses')
        #PROMPT('&User name:',FIELD(%ETgFile)),%ETgColUser
        #PROMPT('&Password:',FIELD(%ETgFile)),%ETgColPassword
        #PROMPT('&From address:',FIELD(%ETgFile)),%ETgColFromAddr
        #PROMPT('From &name:',FIELD(%ETgFile)),%ETgColFromName
        #PROMPT('&Reply to:',FIELD(%ETgFile)),%ETgColReplyTo
      #ENDBOXED
      #BOXED('Columns - OAuth2 and API keys')
        #PROMPT('Client &ID:',FIELD(%ETgFile)),%ETgColClientId
        #PROMPT('Client &secret:',FIELD(%ETgFile)),%ETgColSecret
        #PROMPT('&Tenant:',FIELD(%ETgFile)),%ETgColTenant
        #PROMPT('Re&fresh token:',FIELD(%ETgFile)),%ETgColRefresh
        #PROMPT('API &key:',FIELD(%ETgFile)),%ETgColApiKey
        #PROMPT('API &domain:',FIELD(%ETgFile)),%ETgColApiDomain
        #DISPLAY('')
        #DISPLAY('Password, client secret, refresh token and API key are stored')
        #DISPLAY('through Seal(): DPAPI encrypts them for the current Windows')
        #DISPLAY('user, then base64 makes the result safe for a text column.')
        #DISPLAY('Make those columns at least 400 characters, and the refresh')
        #DISPLAY('token column 2000. A row copied to another machine is useless.')
      #ENDBOXED
    #ENDENABLE
    #BOXED('')
      #DISPLAY('Every column is optional except the account name. A column you')
      #DISPLAY('leave blank simply keeps whatever the Account tab set.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Multi-DLL')
    #BOXED('Where the classes live')
      #DISPLAY('Out of the box emailTo follows this application''s own External')
      #DISPLAY('setting, which is already what a multi-DLL suite wants:')
      #DISPLAY('')
      #DISPLAY('  the app that owns the data (External: None) compiles the')
      #DISPLAY('  three classes in, exports them from its own .EXP and owns')
      #DISPLAY('  the mail object; every app set to External: DLL imports')
      #DISPLAY('  them instead of compiling its own copy.')
      #DISPLAY('')
      #DISPLAY('Add this extension to EVERY app in the suite and leave the')
      #DISPLAY('box below alone.')
      #DISPLAY('')
      #DISPLAY('emailc.c is compiled only into the app that owns the classes,')
      #DISPLAY('because the PRAGMA lives in EmailNetClass.clw.')
    #ENDBOXED
    #BOXED('Override - place the classes by hand')
      #INSERT(%AbcLibraryPrompts(ABC))
      #DISPLAY('')
      #DISPLAY('Linked in    - compile the classes into this app (and, if this')
      #DISPLAY('               app is a DLL, export them from it).')
      #DISPLAY('External DLL - import them from another DLL in the suite.')
      #DISPLAY('External LIB - link against a .LIB you built yourself.')
      #DISPLAY('None         - do neither; you add the .clw files yourself.')
    #ENDBOXED
    #BOXED('If the classes are missing from the generated .EXP')
      #DISPLAY('The export list is built from the IDE''s class registry. If')
      #DISPLAY('EmailToClass is not in it yet, press "Refresh Application')
      #DISPLAY('Builder Class Information" on the Global Properties Classes')
      #DISPLAY('tab (or close and re-open the application) and generate again.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#!--- the three includes -------------------------------------------------------
#AT(%AfterGlobalIncludes),WHERE(%ETgDisable=0)
INCLUDE('EmailToClass.INC'),ONCE                           #! pulls in EmailNetClass + EmailMsgClass
#ENDAT
#!
#!--- the global object ---------------------------------------------------------
#!  When a settings table is nominated the object is DERIVED, so LoadAccount and
#!  SaveAccount read and write that table instead of the built-in INI. The
#!  derived instance is declared only in the app that owns it; the other apps in
#!  a suite import it as the base type and still reach the derived methods,
#!  because both are VIRTUAL and dispatch through the object's own VMT.
#AT(%GlobalData),WHERE(%ETgDisable=0)
  #IF(%DefaultExternal = 'None External')
    #IF(%ETgFile)
%ETgObject             CLASS(EmailToClass)                 #<! the mail object, reading %ETgFile
LoadAccount              PROCEDURE(<STRING pName>),BYTE,PROC,DERIVED
SaveAccount              PROCEDURE(),BYTE,PROC,DERIVED
                       END
    #ELSE
%ETgObject             EmailToClass                        #<! the mail object
    #ENDIF
emailToLanguage        BYTE(%ETgLanguage)                  #<! 1 = English, 2 = Espanol
  #ELSE
%ETgObject             EmailToClass,EXTERNAL,DLL(dll_mode) #<! it lives in the data DLL
emailToLanguage        BYTE,EXTERNAL,DLL(dll_mode)
  #ENDIF
#ENDAT
#!
#AT(%DLLExportList),WHERE(%ETgDisable=0)
  #IF(%DefaultExternal = 'None External' AND %ProgramExtension='DLL' AND %DefaultExport)
  $%ETgObject                                              @?
  $emailToLanguage                                         @?
  #ENDIF
#ENDAT
#!
#!--- start-up: seed the account, then let the store override it ---------------
#AT(%ProgramSetup),WHERE(%ETgDisable=0 AND %DefaultExternal = 'None External'),PRIORITY(8000)
  %ETgObject.Init()
  %ETgObject.Language = emailToLanguage
  #IF(%ETgTrace)
  %ETgObject.Trace = 1
  #ENDIF
  #IF(%ETgProvider <> '0')
  %ETgObject.SetProvider(%ETgProvider)                     ! host, port, security and auth for the provider
  #ENDIF
  %ETgObject.Acc.Transport = %ETgTransport
  #IF(%ETgHost)
  %ETgObject.Acc.Host      = '%ETgHost'
  #ENDIF
  #IF(%ETgPort)
  %ETgObject.Acc.Port      = %ETgPort
  #ENDIF
  %ETgObject.Acc.Security  = %ETgSecurity
  %ETgObject.Acc.AuthMode  = %ETgAuth
  #IF(%ETgUser)
  %ETgObject.Acc.UserName  = '%ETgUser'
  #ENDIF
  #IF(%ETgPassword)
  %ETgObject.Acc.Password  = '%ETgPassword'
  #ENDIF
  #IF(%ETgFromAddr)
  %ETgObject.Acc.FromAddr  = '%ETgFromAddr'
  #ENDIF
  #IF(%ETgFromName)
  %ETgObject.Acc.FromName  = '%ETgFromName'
  #ENDIF
  #IF(%ETgReplyTo)
  %ETgObject.Acc.ReplyTo   = '%ETgReplyTo'
  #ENDIF
  #IF(%ETgClientId)
  %ETgObject.Acc.ClientId  = '%ETgClientId'
  #ENDIF
  #IF(%ETgClientSecret)
  %ETgObject.Acc.ClientSecret = '%ETgClientSecret'
  #ENDIF
  #IF(%ETgTenant)
  %ETgObject.Acc.TenantId  = '%ETgTenant'
  #ENDIF
  #IF(%ETgApiKey)
  %ETgObject.Acc.ApiKey    = '%ETgApiKey'
  #ENDIF
  #IF(%ETgApiDomain)
  %ETgObject.Acc.ApiDomain = '%ETgApiDomain'
  #ENDIF
  #IF(%ETgFile)
  %ETgObject.LoadAccount('%ETgLoadName')                   ! whatever %ETgFile holds wins
  #ELSE
  %ETgObject.LoadAccount()                                 ! the INI beside the EXE, if there is one
  #ENDIF
#ENDAT
#!
#!--- the generated table binding ----------------------------------------------
#AT(%ProgramProcedures),WHERE(%ETgDisable=0 AND %ETgFile AND %DefaultExternal = 'None External')

!-----------------------------------------------------------------------------
!  %ETgObject.LoadAccount / .SaveAccount - generated by the emailTo template
!  from the Table tab. They replace the class's built-in INI store with
!  %ETgFile, so the account lives in your data with your own backup and
!  security around it.
!
!  The four secrets go through Seal() / Unseal(): DPAPI encrypts them for the
!  current Windows user and base64 makes the result safe for a text column, so
!  a row copied off this machine cannot be read anywhere else.
!-----------------------------------------------------------------------------
%ETgObject.LoadAccount PROCEDURE(<STRING pName>)
  CODE
  IF NOT OMITTED(pName) AND CLIP(pName)
    SELF.Acc.Name = CLIP(pName)
  END
  Access:%ETgFile.Open()
  Access:%ETgFile.UseFile()
  CLEAR(%ETgFile:Record)
  %ETgColName = SELF.Acc.Name
  #IF(%ETgLoadName)
  GET(%ETgFile, %ETgKey)
  #ELSE
  SET(%ETgFile)
  NEXT(%ETgFile)
  #ENDIF
  IF ERRORCODE()
    Access:%ETgFile.Close()
    RETURN 0                                               ! nothing stored yet - keep the defaults
  END
  SELF.Acc.Name         = %ETgColName
  #IF(%ETgColProvider)
  SELF.Acc.Provider     = %ETgColProvider
  #ENDIF
  #IF(%ETgColTransport)
  IF %ETgColTransport THEN SELF.Acc.Transport = %ETgColTransport.
  #ENDIF
  #IF(%ETgColHost)
  IF CLIP(%ETgColHost) THEN SELF.Acc.Host = CLIP(%ETgColHost).
  #ENDIF
  #IF(%ETgColPort)
  IF %ETgColPort THEN SELF.Acc.Port = %ETgColPort.
  #ENDIF
  #IF(%ETgColSecurity)
  SELF.Acc.Security     = %ETgColSecurity
  #ENDIF
  #IF(%ETgColAuth)
  SELF.Acc.AuthMode     = %ETgColAuth
  #ENDIF
  #IF(%ETgColUser)
  SELF.Acc.UserName     = CLIP(%ETgColUser)
  #ENDIF
  #IF(%ETgColPassword)
  SELF.Acc.Password     = SELF.Unseal(%ETgColPassword)
  #ENDIF
  #IF(%ETgColFromAddr)
  IF CLIP(%ETgColFromAddr) THEN SELF.Acc.FromAddr = CLIP(%ETgColFromAddr).
  #ENDIF
  #IF(%ETgColFromName)
  SELF.Acc.FromName     = CLIP(%ETgColFromName)
  #ENDIF
  #IF(%ETgColReplyTo)
  SELF.Acc.ReplyTo      = CLIP(%ETgColReplyTo)
  #ENDIF
  #IF(%ETgColClientId)
  IF CLIP(%ETgColClientId) THEN SELF.Acc.ClientId = CLIP(%ETgColClientId).
  #ENDIF
  #IF(%ETgColSecret)
  SELF.Acc.ClientSecret = SELF.Unseal(%ETgColSecret)
  #ENDIF
  #IF(%ETgColTenant)
  IF CLIP(%ETgColTenant) THEN SELF.Acc.TenantId = CLIP(%ETgColTenant).
  #ENDIF
  #IF(%ETgColRefresh)
  SELF.Acc.RefreshToken = SELF.Unseal(%ETgColRefresh)
  #ENDIF
  #IF(%ETgColApiKey)
  IF CLIP(%ETgColApiKey) THEN SELF.Acc.ApiKey = SELF.Unseal(%ETgColApiKey).
  #ENDIF
  #IF(%ETgColApiDomain)
  IF CLIP(%ETgColApiDomain) THEN SELF.Acc.ApiDomain = CLIP(%ETgColApiDomain).
  #ENDIF
  !  An access token is short-lived; the refresh token buys a new one.
  SELF.Acc.AccessToken  = ''
  SELF.Acc.TokenExpDate = 0
  Access:%ETgFile.Close()
  RETURN 1

%ETgObject.SaveAccount PROCEDURE()
ETFound  BYTE
  CODE
  Access:%ETgFile.Open()
  Access:%ETgFile.UseFile()
  CLEAR(%ETgFile:Record)
  %ETgColName = SELF.Acc.Name
  GET(%ETgFile, %ETgKey)
  ETFound = CHOOSE(ERRORCODE() = 0, 1, 0)
  IF NOT ETFound
  #IF(%ETgCreateRow)
    CLEAR(%ETgFile:Record)
    %ETgColName = SELF.Acc.Name
  #ELSE
    Access:%ETgFile.Close()
    RETURN 0                                               ! not allowed to create the row
  #ENDIF
  END
  #IF(%ETgColProvider)
  %ETgColProvider     = SELF.Acc.Provider
  #ENDIF
  #IF(%ETgColTransport)
  %ETgColTransport    = SELF.Acc.Transport
  #ENDIF
  #IF(%ETgColHost)
  %ETgColHost         = CLIP(SELF.Acc.Host)
  #ENDIF
  #IF(%ETgColPort)
  %ETgColPort         = SELF.Acc.Port
  #ENDIF
  #IF(%ETgColSecurity)
  %ETgColSecurity     = SELF.Acc.Security
  #ENDIF
  #IF(%ETgColAuth)
  %ETgColAuth         = SELF.Acc.AuthMode
  #ENDIF
  #IF(%ETgColUser)
  %ETgColUser         = CLIP(SELF.Acc.UserName)
  #ENDIF
  #IF(%ETgColPassword)
  %ETgColPassword     = SELF.Seal(SELF.Acc.Password)
  #ENDIF
  #IF(%ETgColFromAddr)
  %ETgColFromAddr     = CLIP(SELF.Acc.FromAddr)
  #ENDIF
  #IF(%ETgColFromName)
  %ETgColFromName     = CLIP(SELF.Acc.FromName)
  #ENDIF
  #IF(%ETgColReplyTo)
  %ETgColReplyTo      = CLIP(SELF.Acc.ReplyTo)
  #ENDIF
  #IF(%ETgColClientId)
  %ETgColClientId     = CLIP(SELF.Acc.ClientId)
  #ENDIF
  #IF(%ETgColSecret)
  %ETgColSecret       = SELF.Seal(SELF.Acc.ClientSecret)
  #ENDIF
  #IF(%ETgColTenant)
  %ETgColTenant       = CLIP(SELF.Acc.TenantId)
  #ENDIF
  #IF(%ETgColRefresh)
  %ETgColRefresh      = SELF.Seal(SELF.Acc.RefreshToken)
  #ENDIF
  #IF(%ETgColApiKey)
  %ETgColApiKey       = SELF.Seal(SELF.Acc.ApiKey)
  #ENDIF
  #IF(%ETgColApiDomain)
  %ETgColApiDomain    = CLIP(SELF.Acc.ApiDomain)
  #ENDIF
  IF ETFound
    PUT(%ETgFile)
  ELSE
    ADD(%ETgFile)
  END
  IF ERRORCODE()
    Access:%ETgFile.Close()
    RETURN 0
  END
  Access:%ETgFile.Close()
  RETURN 1
#ENDAT
#!
#!-----------------------------------------------------------------------------
#!  MULTI-DLL. The three class files carry the tag !ABCIncludeFile(EMAILTO) on
#!  line 1, so the IDE's class registry files them under category EMAILTO.
#!  Registering that category here hands the whole job to the shipped ABC
#!  machinery:
#!
#!    ABPROGRM.TPW  #CALL(%DefineCategoryPragmas) writes the project defines
#!                  _emailToLinkMode_ / _emailToDllMode_ that the classes'
#!                  LINK() and DLL() attributes read.
#!    ABBLDEXP.TPW  while building the .EXP of a DLL, walks the registry and
#!                  emits VMT$ / TYPE$ / every non-private method of every
#!                  link-mode category class, name-mangled by LINKNAME().
#!
#!  That is why nothing here lists a mangled symbol: add a method to a class
#!  and the export list follows on the next generate.
#!
#!  Corpus precedent for a third-party class registering its own category:
#!  svgraph.tpl:38, qcenter.tpw:98, abmail.tpl:310.
#!-----------------------------------------------------------------------------
#AT(%BeforeGenerateApplication),WHERE(%ETgDisable=0)
  #CALL(%AddCategory(ABC),'EMAILTO')
  #CALL(%SetCategoryLocationFromPrompts(ABC),'EMAILTO','emailTo','')
#ENDAT
#!#############################################################################
#!  CONTROL TEMPLATE - emailToButton
#!#############################################################################
#!  Drag onto any window and it drops a wired "E-mail..." button. What the
#!  button does is a prompt: open the compose window, or send a message you
#!  described here without asking. Both routes go through the same global
#!  object, so the account, the log and the error text are shared.
#!#############################################################################
#CONTROL(emailToButton,'emailTo - E-mail button (drag onto a window)'),WINDOW,MULTI,DESCRIPTION('E-mail button - ' & CHOOSE(%ETbAction='3','opens ACCOUNT SETUP',CHOOSE(%ETbAction='2','SENDS straight away','opens the COMPOSE window'))),HLP('~emailTo.htm')
  CONTROLS
    BUTTON('&E-mail...'),AT(,,54,14),USE(?EmailBtn),TIP('Send this by e-mail')
  END
#SHEET
  #TAB('&General')
    #BOXED('Button')
      #DISPLAY('emailTo v1.02  -  built 2026-08-23 20:56')
      #PROMPT('&Disable this button',CHECK),%ETbDisable,DEFAULT(0),AT(10)
      #PROMPT('Mail &object name:',@s64),%ETbObject,REQ,DEFAULT('Mailer')
      #DISPLAY('The object the emailToGlobal extension declared. Add that')
      #DISPLAY('extension to this application if you have not already.')
    #ENDBOXED
    #BOXED('What this button does')
      #PROMPT('&Action:',DROP('Open the compose window[1]|Send straight away, no window[2]|Open the account setup window[3]')),%ETbAction,DEFAULT('1')
      #DISPLAY('')
      #DISPLAY('Compose window     - the Message tab only PRE-FILLS what opens.')
      #DISPLAY('Send straight away - the Message tab IS the message.')
      #DISPLAY('Account setup      - the Message tab does not apply (greyed).')
      #DISPLAY('')
      #DISPLAY('All three start life labelled "E-mail..." - rename the button')
      #DISPLAY('in the window designer so two of them tell each other apart.')
    #ENDBOXED
    #ENABLE(%ETbAction='2')
      #BOXED('After it runs (send straight away only)')
        #PROMPT('Tell the user it &worked',CHECK),%ETbSayOk,DEFAULT(1),AT(10)
        #PROMPT('Show the &error if it failed',CHECK),%ETbSayError,DEFAULT(1),AT(10)
      #ENDBOXED
    #ENDENABLE
  #ENDTAB
  #TAB('&Account')
    #BOXED('The sender address and password are NOT set here')
      #DISPLAY('This button only says WHAT to do. Who the mail comes FROM -')
      #DISPLAY('the server, the sender address, the user name, the password,')
      #DISPLAY('the OAuth2 client - belongs to the whole application, not to')
      #DISPLAY('one button, so it is set in ONE place:')
      #DISPLAY('')
      #DISPLAY('   Application - Global Properties - Extensions')
      #DISPLAY('      - "emailTo - Global" - Account tab')
      #DISPLAY('')
      #DISPLAY('Add that extension once per application. Every button and')
      #DISPLAY('every embed in the app then shares that one account.')
    #ENDBOXED
    #BOXED('Letting the end user change it')
      #DISPLAY('Give them a button with Action = "Open the account setup')
      #DISPLAY('window". What they save there overrides the Account tab -')
      #DISPLAY('into your settings table if you nominated one on the global')
      #DISPLAY('extension''s Table tab, otherwise into an INI beside the EXE.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Message')
    #BOXED('')
      #DISPLAY('This tab is only who the mail goes TO and what it says.')
      #DISPLAY('Who it comes FROM is on the Account tab, not here.')
      #DISPLAY('Greyed out below means this button''s Action sends nothing.')
    #ENDBOXED
    #ENABLE(%ETbAction<>'3')
    #BOXED('Who it goes to')
      #PROMPT('&To:',@s255),%ETbTo,DEFAULT('')
      #PROMPT('&Cc:',@s255),%ETbCc,DEFAULT('')
      #DISPLAY('Type addresses, separated by ; or , - or name a variable or')
      #DISPLAY('a field to take them from at run time (see below).')
      #PROMPT('Take To from a &variable instead:',FIELD),%ETbToVar
    #ENDBOXED
    #BOXED('What it says')
      #PROMPT('&Subject:',@s255),%ETbSubject,DEFAULT('')
      #PROMPT('Take the subject from a v&ariable:',FIELD),%ETbSubjectVar
      #PROMPT('&Body:',@s255),%ETbBody,DEFAULT('')
      #PROMPT('Take the body from a va&riable:',FIELD),%ETbBodyVar
      #PROMPT('Body is &HTML',CHECK),%ETbHtml,DEFAULT(0),AT(10)
    #ENDBOXED
    #BOXED('Attachment')
      #PROMPT('&File name:',@s255),%ETbAttach,DEFAULT('')
      #PROMPT('Take the file name from a variab&le:',FIELD),%ETbAttachVar
    #ENDBOXED
    #ENDENABLE
  #ENDTAB
#ENDSHEET
#!
#!  The class has to be visible to THIS module even when the global extension
#!  is on a different one; ,ONCE keys on the file name across the whole compile
#!  so it is still pulled in exactly once. (Corpus: ABDROPS.TPW:65.)
#AT(%CustomGlobalDeclarations),WHERE(%ETbDisable=0)
INCLUDE('EmailToClass.INC'),ONCE
#ENDAT
#!
#!  Capture THIS instance's real field equate before anything else runs: AppGen
#!  uniques the USE() when the button is dropped more than once (?EmailBtn,
#!  ?EmailBtn:2, ...), so the event handler has to be attached to whatever this
#!  instance actually got.  #ATSTART + the shipped #FOR(%Control) idiom is how
#!  every MULTI control template does it (corpus: CONTROL.TPW:107, CloseButton).
#ATSTART
  #DECLARE(%ETbBtn)
  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance)
    #SET(%ETbBtn,%Control)
  #ENDFOR
  #!  Each of the four values is either a variable the user named or a literal
  #!  they typed.  Resolving that HERE, into one symbol each, keeps the emitted
  #!  call on a single line - Clarion has no free line continuation, so an
  #!  argument list split across output lines simply does not compile.
  #DECLARE(%ETbToExpr)
  #DECLARE(%ETbSubjExpr)
  #DECLARE(%ETbBodyExpr)
  #DECLARE(%ETbAttachExpr)
  #IF(%ETbToVar)
    #SET(%ETbToExpr,%ETbToVar)
  #ELSE
    #SET(%ETbToExpr,'''' & %ETbTo & '''')
  #ENDIF
  #IF(%ETbSubjectVar)
    #SET(%ETbSubjExpr,%ETbSubjectVar)
  #ELSE
    #SET(%ETbSubjExpr,'''' & %ETbSubject & '''')
  #ENDIF
  #IF(%ETbBodyVar)
    #SET(%ETbBodyExpr,%ETbBodyVar)
  #ELSE
    #SET(%ETbBodyExpr,'''' & %ETbBody & '''')
  #ENDIF
  #IF(%ETbAttachVar)
    #SET(%ETbAttachExpr,%ETbAttachVar)
  #ELSE
    #SET(%ETbAttachExpr,'''' & %ETbAttach & '''')
  #ENDIF
#ENDAT
#!
#AT(%ControlEventHandling,%ETbBtn,'Accepted'),WHERE(%ETbDisable=0)
  #CASE(%ETbAction)
  #OF('3')
  %ETbObject.Setup()
  #OF('1')
    #IF(%ETbToVar OR %ETbTo OR %ETbSubject OR %ETbSubjectVar OR %ETbBody OR %ETbBodyVar OR %ETbAttach OR %ETbAttachVar)
  %ETbObject.Compose(%ETbToExpr, %ETbSubjExpr, %ETbBodyExpr, %ETbAttachExpr)
    #ELSE
  %ETbObject.Compose()
    #ENDIF
  #ELSE
  #INSERT(%ETbBuildMessage)
  IF %ETbObject.Send(%ETbObject.Msg)
    #IF(%ETbSayOk)
    MESSAGE(%ETbObject.Txt(ETTxt:Sent), %ETbObject.Txt(ETTxt:Compose), ICON:Asterisk)
    #ENDIF
    #IF(NOT %ETbSayOk)
    !  nothing to report - the send succeeded quietly
    #ENDIF
  ELSE
    #IF(%ETbSayError)
    %ETbObject.ShowError()
    #ENDIF
    #IF(NOT %ETbSayError)
    !  the failure is in %ETbObject.LastErrorText for your own handling
    #ENDIF
  END
  #ENDCASE
#ENDAT
#!
#!--- the message builder, shared by the button and the code template --------
#GROUP(%ETbBuildMessage)
  %ETbObject.Msg.ClearAll()
  #IF(%ETbToVar)
  %ETbObject.Msg.AddList(%ETbToVar, ETAddr:To)
  #ELSE
  %ETbObject.Msg.AddList('%ETbTo', ETAddr:To)
  #ENDIF
  #IF(%ETbCc)
  %ETbObject.Msg.AddList('%ETbCc', ETAddr:Cc)
  #ENDIF
  #IF(%ETbSubjectVar)
  %ETbObject.Msg.SetSubject(%ETbSubjectVar)
  #ELSE
  %ETbObject.Msg.SetSubject('%ETbSubject')
  #ENDIF
  #IF(%ETbHtml)
    #IF(%ETbBodyVar)
  %ETbObject.Msg.SetHtml(%ETbBodyVar)
    #ELSE
  %ETbObject.Msg.SetHtml('%ETbBody')
    #ENDIF
  #ELSE
    #IF(%ETbBodyVar)
  %ETbObject.Msg.SetText(%ETbBodyVar)
    #ELSE
  %ETbObject.Msg.SetText('%ETbBody')
    #ENDIF
  #ENDIF
  #IF(%ETbAttachVar)
  IF CLIP(%ETbAttachVar) THEN %ETbObject.Msg.Attach(%ETbAttachVar).
  #ENDIF
  #IF(%ETbAttach AND NOT %ETbAttachVar)
  %ETbObject.Msg.Attach('%ETbAttach')
  #ENDIF
#!#############################################################################
#!  CODE TEMPLATE - emailToSend  -  send from any embed
#!#############################################################################
#CODE(emailToSend,'emailTo - Send an e-mail here'),HLP('~emailTo.htm')
#SHEET
  #TAB('&Message')
    #BOXED('Object')
      #DISPLAY('emailTo v1.02  -  built 2026-08-23 20:56')
      #PROMPT('Mail &object name:',@s64),%ETcObject,REQ,DEFAULT('Mailer')
      #DISPLAY('')
      #DISPLAY('The sender address, server and password are NOT set here.')
      #DISPLAY('They are on the "emailTo - Global" extension, Account tab')
      #DISPLAY('(Application - Global Properties - Extensions), set once')
      #DISPLAY('for the whole application.')
    #ENDBOXED
    #BOXED('Who it goes to')
      #PROMPT('&To:',@s255),%ETcTo,DEFAULT('')
      #PROMPT('...or take To from this &variable:',FIELD),%ETcToVar
      #PROMPT('&Cc:',@s255),%ETcCc,DEFAULT('')
      #PROMPT('&Bcc:',@s255),%ETcBcc,DEFAULT('')
    #ENDBOXED
    #BOXED('What it says')
      #PROMPT('&Subject:',@s255),%ETcSubject,DEFAULT('')
      #PROMPT('...or from this varia&ble:',FIELD),%ETcSubjectVar
      #PROMPT('B&ody:',@s255),%ETcBody,DEFAULT('')
      #PROMPT('...or from this varia&ble:',FIELD),%ETcBodyVar
      #PROMPT('The body is &HTML',CHECK),%ETcHtml,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Attachment && result')
    #BOXED('Attachment')
      #PROMPT('&File name:',@s255),%ETcAttach,DEFAULT('')
      #PROMPT('...or from this &variable:',FIELD),%ETcAttachVar
      #DISPLAY('')
      #DISPLAY('This is the usual way to e-mail a report: write the PDF, then')
      #DISPLAY('drop this template after it and point the file name here.')
    #ENDBOXED
    #BOXED('What to do with the result')
      #PROMPT('Put the &result (1 = sent) in:',FIELD),%ETcResult
      #PROMPT('Tell the user it &worked',CHECK),%ETcSayOk,DEFAULT(0),AT(10)
      #PROMPT('Show the &error if it failed',CHECK),%ETcSayError,DEFAULT(1),AT(10)
      #DISPLAY('')
      #DISPLAY('Whatever you choose, the reason is always left in')
      #DISPLAY('<object>.LastErrorText for your own code to use.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
  %ETcObject.Msg.ClearAll()
#IF(%ETcToVar)
  %ETcObject.Msg.AddList(%ETcToVar, ETAddr:To)
#ELSE
  %ETcObject.Msg.AddList('%ETcTo', ETAddr:To)
#ENDIF
#IF(%ETcCc)
  %ETcObject.Msg.AddList('%ETcCc', ETAddr:Cc)
#ENDIF
#IF(%ETcBcc)
  %ETcObject.Msg.AddList('%ETcBcc', ETAddr:Bcc)
#ENDIF
#IF(%ETcSubjectVar)
  %ETcObject.Msg.SetSubject(%ETcSubjectVar)
#ELSE
  %ETcObject.Msg.SetSubject('%ETcSubject')
#ENDIF
#IF(%ETcHtml)
  #IF(%ETcBodyVar)
  %ETcObject.Msg.SetHtml(%ETcBodyVar)
  #ELSE
  %ETcObject.Msg.SetHtml('%ETcBody')
  #ENDIF
#ELSE
  #IF(%ETcBodyVar)
  %ETcObject.Msg.SetText(%ETcBodyVar)
  #ELSE
  %ETcObject.Msg.SetText('%ETcBody')
  #ENDIF
#ENDIF
#IF(%ETcAttachVar)
  IF CLIP(%ETcAttachVar) THEN %ETcObject.Msg.Attach(%ETcAttachVar).
#ENDIF
#IF(%ETcAttach AND NOT %ETcAttachVar)
  %ETcObject.Msg.Attach('%ETcAttach')
#ENDIF
#IF(%ETcResult)
  %ETcResult = %ETcObject.Send(%ETcObject.Msg)
  IF NOT %ETcResult
  #IF(%ETcSayError)
    %ETcObject.ShowError()
  #ELSE
    !  the reason is in %ETcObject.LastErrorText
  #ENDIF
  #IF(%ETcSayOk)
  ELSE
    MESSAGE(%ETcObject.Txt(ETTxt:Sent), %ETcObject.Txt(ETTxt:Compose), ICON:Asterisk)
  #ENDIF
  END
#ELSE
  IF %ETcObject.Send(%ETcObject.Msg)
  #IF(%ETcSayOk)
    MESSAGE(%ETcObject.Txt(ETTxt:Sent), %ETcObject.Txt(ETTxt:Compose), ICON:Asterisk)
  #ELSE
    !  sent
  #ENDIF
  ELSE
  #IF(%ETcSayError)
    %ETcObject.ShowError()
  #ELSE
    !  the reason is in %ETcObject.LastErrorText
  #ENDIF
  END
#ENDIF
#!#############################################################################
#!  CODE TEMPLATE - emailToCompose
#!#############################################################################
#CODE(emailToCompose,'emailTo - Open the compose window here'),HLP('~emailTo.htm')
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #DISPLAY('emailTo v1.02  -  built 2026-08-23 20:56')
      #PROMPT('Mail &object name:',@s64),%ETmObject,REQ,DEFAULT('Mailer')
      #DISPLAY('')
      #DISPLAY('The sender address, server and password are NOT set here.')
      #DISPLAY('They are on the "emailTo - Global" extension, Account tab')
      #DISPLAY('(Application - Global Properties - Extensions), set once')
      #DISPLAY('for the whole application.')
    #ENDBOXED
    #BOXED('Pre-fill the window (all optional)')
      #PROMPT('&To:',@s255),%ETmTo,DEFAULT('')
      #PROMPT('...or from this &variable:',FIELD),%ETmToVar
      #PROMPT('&Subject:',@s255),%ETmSubject,DEFAULT('')
      #PROMPT('...or from this v&ariable:',FIELD),%ETmSubjectVar
      #PROMPT('&Body:',@s255),%ETmBody,DEFAULT('')
      #PROMPT('&Attach this file:',@s255),%ETmAttach,DEFAULT('')
      #PROMPT('...or from this varia&ble:',FIELD),%ETmAttachVar
    #ENDBOXED
    #BOXED('Result')
      #PROMPT('Put the &result (1 = sent) in:',FIELD),%ETmResult
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!  Resolve each argument into one symbol first, then emit the call on a
#!  single line - see the note in the button template above.
#DECLARE(%ETmToExpr)
#DECLARE(%ETmSubjExpr)
#DECLARE(%ETmAttachExpr)
#IF(%ETmToVar)
  #SET(%ETmToExpr,%ETmToVar)
#ELSE
  #SET(%ETmToExpr,'''' & %ETmTo & '''')
#ENDIF
#IF(%ETmSubjectVar)
  #SET(%ETmSubjExpr,%ETmSubjectVar)
#ELSE
  #SET(%ETmSubjExpr,'''' & %ETmSubject & '''')
#ENDIF
#IF(%ETmAttachVar)
  #SET(%ETmAttachExpr,%ETmAttachVar)
#ELSE
  #SET(%ETmAttachExpr,'''' & %ETmAttach & '''')
#ENDIF
#IF(%ETmResult)
  %ETmResult = %ETmObject.Compose(%ETmToExpr, %ETmSubjExpr, '%ETmBody', %ETmAttachExpr)
#ELSE
  %ETmObject.Compose(%ETmToExpr, %ETmSubjExpr, '%ETmBody', %ETmAttachExpr)
#ENDIF
#!#############################################################################
#!  CODE TEMPLATE - emailToSetup
#!#############################################################################
#CODE(emailToSetup,'emailTo - Open the mail account setup window here'),HLP('~emailTo.htm')
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #DISPLAY('emailTo v1.02  -  built 2026-08-23 20:56')
      #PROMPT('Mail &object name:',@s64),%ETsObject,REQ,DEFAULT('Mailer')
      #DISPLAY('')
      #DISPLAY('This is where the END USER sets the account. The values it')
      #DISPLAY('starts from are the ones you put on the "emailTo - Global"')
      #DISPLAY('extension, Account tab.')
    #ENDBOXED
    #BOXED('What it does')
      #DISPLAY('Opens the account window: provider, server, port, security,')
      #DISPLAY('user name and password - plus a "Sign in..." button that runs')
      #DISPLAY('the OAuth2 consent flow in the user''s own browser, a "Test')
      #DISPLAY('account" button that connects and signs in without sending')
      #DISPLAY('anything, and a Log tab showing the whole conversation.')
      #DISPLAY('')
      #DISPLAY('Saving calls SaveAccount(), which writes to the settings table')
      #DISPLAY('you nominated in the global extension, or to the INI file.')
      #PROMPT('Put the &result (1 = saved) in:',FIELD),%ETsResult
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#IF(%ETsResult)
  %ETsResult = %ETsObject.Setup()
#ELSE
  %ETsObject.Setup()
#ENDIF
