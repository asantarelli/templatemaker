! ============================================================================
!  TaskPanelDemo - myTaskPanel on an MDI frame, hand-coded.
!
!  This is what the myTaskPanel template generates, written out by hand. Each
!  call is marked with the embed point the template emits it at.
!
!  Command line (any order):
!    engine=dx | engine=gdi     which painter (default gdi)
!    dock=left|right|float      where the panel starts
!    theme=1..6                 MTP:Slate .. MTP:Forest
!    sub=flyout                 submenus as pop-up menus instead of in place
!    lang=es                    Spanish captions
!    open=all|none              start with every group expanded / collapsed
!    child                      open two MDI browses at start
!    auto                       run the self-test, write TaskPanelTest.ini, exit
!    shot                       keep still for an external screenshot (no auto)
! ============================================================================
  PROGRAM

  INCLUDE('MyTaskPanel.INC'),ONCE
  INCLUDE('KEYCODES.CLW'),ONCE

  MAP
Main          PROCEDURE
FormDemo      PROCEDURE
BrowseWin     PROCEDURE(STRING title)
AboutWin      PROCEDURE
Arg           PROCEDURE(STRING name),STRING
SelfTest      PROCEDURE
    MODULE('Windows API')
d_FindWindowEx         PROCEDURE(LONG,LONG,LONG,LONG),LONG,PASCAL,NAME('FindWindowExA')
d_GetWindowRect        PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('GetWindowRect')
d_GetClientRect        PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('GetClientRect')
d_IsWindowVisible      PROCEDURE(LONG),LONG,PASCAL,NAME('IsWindowVisible')
d_SendMessage          PROCEDURE(LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('SendMessageA')
d_GetMenu              PROCEDURE(LONG),LONG,PASCAL,NAME('GetMenu')
d_SetCursorPos         PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('SetCursorPos')
d_ClientToScreen       PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('ClientToScreen')
    END
  END

! The test build exposes what the class keeps PROTECTED.
TestPanel            CLASS(MyTaskPanelClass)
GetDockHwnd                  PROCEDURE(),LONG
GetFloatHwnd                 PROCEDURE(),LONG
RowY                   PROCEDURE(LONG id),LONG
RowCount               PROCEDURE(),LONG
ShowFlyout             PROCEDURE(LONG id)
UsingD2D               PROCEDURE(),BYTE
                     END

TP                   TestPanel                ! %GlobalData / procedure data: the panel object
Clicks               LONG
MtT1                 LONG
LastClick            STRING(120)

  CODE
  IF Arg('win') THEN FormDemo() ELSE Main().

!-----------------------------------------------------------------------------
TestPanel.GetDockHwnd PROCEDURE
  CODE
  RETURN SELF.DockHwnd
TestPanel.GetFloatHwnd PROCEDURE
  CODE
  RETURN SELF.FloatHwnd
TestPanel.ShowFlyout PROCEDURE(LONG id)
pt GROUP
PX   LONG
PY   LONG
   END
  CODE
  pt.PX = SELF.PanelWidth - 24                         ! as if the row's arrow had been clicked
  pt.PY = SELF.RowY(id)
  d_ClientToScreen(SELF.DockHwnd, ADDRESS(pt))
  d_SetCursorPos(pt.PX, pt.PY)
  SELF.FlyoutMenu(id, SELF.DockHwnd)
TestPanel.RowCount PROCEDURE
  CODE
  RETURN RECORDS(SELF.Rows)
TestPanel.UsingD2D PROCEDURE
  CODE
  RETURN SELF.EngineInUse()
TestPanel.RowY PROCEDURE(LONG id)
i LONG
  CODE
  LOOP i = 1 TO RECORDS(SELF.Rows)
    GET(SELF.Rows, i)
    IF SELF.Rows.Id = id THEN RETURN SELF.Rows.Y + SELF.Rows.H / 2.
  END
  RETURN -1

Arg PROCEDURE(STRING name)
c   STRING(1024)
p   LONG
e   LONG
  CODE
  c = ' ' & LOWER(COMMAND('')) & ' '
  p = INSTRING(' ' & LOWER(name) & '=', c, 1, 1)
  IF p
    p += LEN(CLIP(name)) + 2
    e = INSTRING(' ', c, 1, p)
    RETURN SUB(c, p, e - p)
  END
  IF INSTRING(' ' & LOWER(name) & ' ', c, 1, 1) THEN RETURN '1'.
  RETURN ''

!-----------------------------------------------------------------------------
Main PROCEDURE
gCat   LONG
gRep   LONG
gExp   LONG
gHelp  LONG
geo    LONG
more   LONG
fin    LONG
i      LONG

AppFrame APPLICATION('myTaskPanel demo'),AT(,,560,340),CENTER,MASK,SYSTEM,MAX,STATUS(-1,160), |
           FONT('Segoe UI',9),RESIZE,IMM,ICON(ICON:Application)
       MENUBAR,USE(?Menubar)
         MENU('&File'),USE(?FileMenu)
           ITEM('&Print Setup...'),USE(?PrintSetup),STD(STD:PrintSetup)
           ITEM,SEPARATOR
           ITEM('E&xit'),USE(?Exit),STD(STD:Close)
         END
         MENU('&Browse'),USE(?BrowseMenu)
           ITEM('&Customers'),USE(?BrCustomers),KEY(CtrlU)
           ITEM('&Products'),USE(?BrProducts),KEY(CtrlP)
           MENU('&Geography'),USE(?GeoMenu)
             ITEM('C&ountries'),USE(?BrCountries)
             ITEM('&States'),USE(?BrStates)
             MENU('&More'),USE(?MoreMenu)
               ITEM('C&ities'),USE(?BrCities)
               ITEM('&Zip codes'),USE(?BrZip)
             END
           END
         END
         MENU('&Reports'),USE(?RepMenu)
           ITEM('Sales by &month'),USE(?RepSales)
           ITEM('&Inventory'),USE(?RepInv),DISABLE
         END
         MENU('&Window'),USE(?WinMenu),STD(STD:WindowList),LAST
           ITEM('T&ile'),USE(?Tile),STD(STD:TileWindow)
           ITEM('&Cascade'),USE(?Cascade),STD(STD:CascadeWindow)
         END
         MENU('&Help'),USE(?HelpMenu)
           ITEM('&About...'),USE(?About)
         END
       END
       TOOLBAR,AT(0,0,560,18),USE(?Toolbar)
         BUTTON('Panel'),AT(4,2,40,14),USE(?BtnToggle),TIP('Show / hide the task panel')
         BUTTON('Left'),AT(48,2,44,14),USE(?BtnLeft)
         BUTTON('Right'),AT(94,2,44,14),USE(?BtnRight)
         BUTTON('Float'),AT(140,2,44,14),USE(?BtnFloat)
       END
     END

  CODE
  OPEN(AppFrame)
  ACCEPT
    CASE EVENT()
    OF EVENT:OpenWindow
      ! ---- %WindowManagerMethodCodeSection 'TakeWindowEvent' / OpenWindow ----
      IF Arg('lang') = 'es' THEN DO Spanish.          ! the frame's own menu too: it is copied below
      TP.Init(AppFrame, CHOOSE(Arg('engine') = 'dx', MTP:DirectX, MTP:Clarion))
      TP.Title = CHOOSE(Arg('lang') = 'es', 'Tareas', 'Tasks')
      IF Arg('lang') = 'es' THEN TP.SetLanguage('ES').
      IF Arg('theme') THEN TP.SetTheme(Arg('theme')).
      IF Arg('sub') = 'flyout' THEN TP.SubStyle = MTP:Flyout.
      CASE Arg('dock')
      OF 'right' ; TP.DockSide = MTP:Right
      OF 'float' ; TP.DockSide = MTP:Float
      END
      TP.IniFile = ''                                  ! the template sets the INI when "remember" is on

      ! a group the developer built (template: Groups list)
      gCat = TP.AddGroup(CHOOSE(Arg('lang') = 'es', 'Cat<225>logos', 'Catalogs'), 'table', 1, 1)
      TP.AddItem(gCat, CHOOSE(Arg('lang') = 'es', 'Clientes', 'Customers'), 'user', 'cust')
      TP.AddItem(gCat, CHOOSE(Arg('lang') = 'es', 'Productos', 'Products'), 'box', 'prod')
      TP.AddItem(gCat, CHOOSE(Arg('lang') = 'es', 'Proveedores', 'Suppliers'), 'truck', 'supp')
      geo = TP.AddItem(gCat, CHOOSE(Arg('lang') = 'es', 'Geograf<237>a', 'Geography'), 'globe')
      TP.AddItem(geo, CHOOSE(Arg('lang') = 'es', 'Pa<237>ses', 'Countries'), , 'countries')
      TP.AddItem(geo, CHOOSE(Arg('lang') = 'es', 'Estados', 'States'), , 'states')
      more = TP.AddItem(geo, CHOOSE(Arg('lang') = 'es', 'M<225>s', 'More'))
      TP.AddItem(more, CHOOSE(Arg('lang') = 'es', 'Ciudades', 'Cities'), , 'cities')
      TP.AddItem(more, CHOOSE(Arg('lang') = 'es', 'C<243>digos postales', 'Zip codes'), , 'zip')
      TP.Expand(geo)

      gExp = TP.AddGroup(CHOOSE(Arg('lang') = 'es', 'Exportar', 'Exports'), 'export')
      TP.AddItem(gExp, 'Excel (.xlsx)', 'excel', 'x_xlsx')
      TP.AddItem(gExp, 'CSV', 'csv', 'x_csv')
      TP.AddItem(gExp, 'PDF', 'pdf', 'x_pdf')
      TP.AddItem(gExp, 'HTML', 'html', 'x_html')
      TP.AddSeparator(gExp)
      TP.AddItem(gExp, 'XML', 'xml', 'x_xml')
      TP.AddItem(gExp, 'JSON', 'json', 'x_json')

      gRep = TP.AddGroup(CHOOSE(Arg('lang') = 'es', 'Informes', 'Reports'), 'report')
      TP.AddItem(gRep, CHOOSE(Arg('lang') = 'es', 'Ventas por mes', 'Sales by month'), 'chart', 'r_sales')
      fin = TP.AddItem(gRep, CHOOSE(Arg('lang') = 'es', 'Financieros', 'Financial'), 'money')
      TP.AddItem(fin, CHOOSE(Arg('lang') = 'es', 'Balance general', 'Balance sheet'), , 'r_bal')
      TP.AddItem(fin, CHOOSE(Arg('lang') = 'es', 'Estado de resultados', 'Income statement'), , 'r_inc')
      TP.AddLabel(gRep, CHOOSE(Arg('lang') = 'es', 'Recientes', 'Recent'))
      TP.AddItem(gRep, CHOOSE(Arg('lang') = 'es', 'Clientes inactivos', 'Inactive customers'), 'doc', 'r_inact')

      gHelp = TP.AddGroup(CHOOSE(Arg('lang') = 'es', 'Ayuda', 'Help'), 'help', 0)
      TP.AddItem(gHelp, CHOOSE(Arg('lang') = 'es', 'Sitio web', 'Website'), 'globe', 'web')
      TP.AddItem(gHelp, CHOOSE(Arg('lang') = 'es', 'Enviar un correo', 'Email support'), 'mail', 'mail')
      TP.AddItem(gHelp, CHOOSE(Arg('lang') = 'es', 'Acerca de...', 'About...'), 'info', 'about')

      ! the frame's own menu, copied in (template: "Copy the system menu")
      TP.MirrorMenu(0, CHOOSE(Arg('lang') = 'es', 'Ventana', 'Window'), 1)

      IF Arg('open') = 'all' THEN TP.ExpandAll(1).
      IF Arg('open') = 'none' THEN TP.ExpandAll(0).
      IF Arg('open') = 'first'
        TP.ExpandAll(0)
        TP.Expand(gCat)
      END
      IF Arg('open') = 'menu'                          ! only the copied menu, opened down to Zip codes
        TP.ExpandAll(0)
        TP.Expand(TP.FindText(CHOOSE(Arg('lang') = 'es', 'Men<250>', 'Menu'), 0))
        TP.Expand(TP.FindText(CHOOSE(Arg('lang') = 'es', 'Consultas', 'Browse'), 0))
        TP.Expand(TP.FindText(CHOOSE(Arg('lang') = 'es', 'Consultas', 'Browse')))
        TP.Expand(TP.FindText(CHOOSE(Arg('lang') = 'es', 'Geograf<237>a', 'Geography'), TP.FindText(CHOOSE(Arg('lang') = 'es', 'Consultas', 'Browse'))))
        TP.Expand(TP.FindText(CHOOSE(Arg('lang') = 'es', 'M<225>s', 'More'), TP.FindText(CHOOSE(Arg('lang') = 'es', 'Geograf<237>a', 'Geography'), TP.FindText(CHOOSE(Arg('lang') = 'es', 'Consultas', 'Browse')))))
      END
      TP.ShowPanel()
      AppFrame{PROP:StatusText, 2} = CHOOSE(Arg('lang') = 'es', 'Motor: ', 'Engine: ') & CHOOSE(TP.UsingD2D() = MTP:DirectX, 'DirectX', 'Clarion (GDI)')
      IF Arg('flyout') THEN 0{PROP:Timer} = 60.          ! open a submenu as a pop-up, for a screenshot
      IF Arg('mt')                                     ! three child panels on three threads
        MtT1 = START(BrowseWin, 25000, 'Customers')
        START(BrowseWin, 25000, 'Products')
        START(BrowseWin, 25000, 'Suppliers')
        0{PROP:Timer} = 150
      END
      IF Arg('child')
        START(BrowseWin, 25000, CHOOSE(Arg('lang') = 'es', 'Clientes', 'Customers'))
        START(BrowseWin, 25000, CHOOSE(Arg('lang') = 'es', 'Productos', 'Products'))
      END
      IF Arg('auto') THEN POST(EVENT:User + 1).
    OF EVENT:User + 1
      SelfTest()                                       ! ends by clicking "Customers"
    OF EVENT:Timer                                     ! auto: the posted clicks have had time
      IF Arg('mt') AND MtT1                            ! close one child: its Kill must not hurt the others
        POST(EVENT:CloseWindow, , MtT1)
        MtT1 = 0
        0{PROP:Timer} = 0
        TP.Expand(TP.FindText('Exports', 0), 0)      ! and make the frame's panel repaint afterwards
      END
      IF Arg('flyout')
        0{PROP:Timer} = 0
        TP.ShowFlyout(TP.FindText(CHOOSE(Arg('lang') = 'es', 'Geograf<237>a', 'Geography'), 0 + TP.FindText(CHOOSE(Arg('lang') = 'es', 'Cat<225>logos', 'Catalogs'), 0)))
      END
      IF Arg('auto')
        0{PROP:Timer} = 0
        IF GETINI('t6', 'result', '', LONGPATH() & '\TaskPanelTest.ini') = ''
          PUTINI('t6', 'result', 'FAIL: no MTP:Event', LONGPATH() & '\TaskPanelTest.ini')
        END
        IF GETINI('t10', 'result', '', LONGPATH() & '\TaskPanelTest.ini') = ''
          PUTINI('t10', 'result', 'FAIL: the menu ITEM was not accepted', LONGPATH() & '\TaskPanelTest.ini')
        END
        POST(EVENT:CloseWindow)
      END
    OF MTP:Event
      ! ---- the template: TakeWindowEvent, CASE on the item's tag ----
      LOOP WHILE TP.NextClick()
        Clicks += 1
        IF Arg('auto')
          PUTINI('t6', 'result', CHOOSE(TP.ClickTag = 'cust', 'pass: real click arrived as tag ', 'FAIL: tag ') & TP.ClickTag, LONGPATH() & '\TaskPanelTest.ini')
          CYCLE
        END
        LastClick = TP.ClickTag
        AppFrame{PROP:StatusText, 1} = 'Clicked: ' & CLIP(TP.ClickText) & '  [' & CLIP(TP.ClickTag) & ']'
        CASE TP.ClickTag
        OF 'cust'    ; START(BrowseWin, 25000, 'Customers')
        OF 'prod'    ; START(BrowseWin, 25000, 'Products')
        OF 'supp'    ; START(BrowseWin, 25000, 'Suppliers')
        OF 'web'     ; TP.OpenUrl('https://github.com/robertorenz')
        OF 'about'   ; START(AboutWin, 25000)
        END
      END
    END
    CASE ACCEPTED()
    OF ?BrCustomers ; START(BrowseWin, 25000, 'Customers') ; LastClick = 'menu:customers'
    OF ?BrProducts  ; START(BrowseWin, 25000, 'Products')  ; LastClick = 'menu:products'
    OF ?BrCountries
      IF Arg('auto')
        PUTINI('t10', 'result', 'pass: the mirrored row POSTed EVENT:Accepted to ?BrCountries', LONGPATH() & '\TaskPanelTest.ini')
      ELSE
        START(BrowseWin, 25000, 'Countries')
      END
    OF ?BrStates    ; START(BrowseWin, 25000, 'States')    ; LastClick = 'menu:states'
    OF ?BrCities    ; START(BrowseWin, 25000, 'Cities')    ; LastClick = 'menu:cities'
    OF ?BrZip       ; START(BrowseWin, 25000, 'Zip codes') ; LastClick = 'menu:zip'
    OF ?RepSales    ; LastClick = 'menu:sales'
    OF ?About       ; START(AboutWin, 25000)
    OF ?BtnToggle   ; TP.TogglePanel()
    OF ?BtnLeft     ; TP.Dock(MTP:Left)
    OF ?BtnRight    ; TP.Dock(MTP:Right)
    OF ?BtnFloat    ; TP.Dock(MTP:Float)
    END
  END
  TP.Kill()                                             ! %WindowManagerMethodCodeSection 'Kill'

Spanish ROUTINE
  AppFrame{PROP:Text} = 'Demostraci<243>n de myTaskPanel'
  ?FileMenu{PROP:Text} = '&Archivo'
  ?PrintSetup{PROP:Text} = '&Configurar impresora...'
  ?Exit{PROP:Text} = '&Salir'
  ?BrowseMenu{PROP:Text} = '&Consultas'
  ?BrCustomers{PROP:Text} = '&Clientes'
  ?BrProducts{PROP:Text} = '&Productos'
  ?GeoMenu{PROP:Text} = '&Geograf<237>a'
  ?BrCountries{PROP:Text} = '&Pa<237>ses'
  ?BrStates{PROP:Text} = '&Estados'
  ?MoreMenu{PROP:Text} = '&M<225>s'
  ?BrCities{PROP:Text} = 'C&iudades'
  ?BrZip{PROP:Text} = 'C<243>digos &postales'
  ?RepMenu{PROP:Text} = '&Informes'
  ?RepSales{PROP:Text} = 'Ventas por &mes'
  ?RepInv{PROP:Text} = '&Inventario'
  ?WinMenu{PROP:Text} = '&Ventana'
  ?Tile{PROP:Text} = '&Mosaico'
  ?Cascade{PROP:Text} = '&Cascada'
  ?HelpMenu{PROP:Text} = 'A&yuda'
  ?About{PROP:Text} = '&Acerca de...'
  ?BtnToggle{PROP:Text} = 'Panel'
  ?BtnLeft{PROP:Text} = 'Izquierda'
  ?BtnRight{PROP:Text} = 'Derecha'
  ?BtnFloat{PROP:Text} = 'Flotante'

!-----------------------------------------------------------------------------
!  The self-test: real Win32 mouse messages at the panel, and the geometry of
!  the MDI client checked against the panel's width.
!-----------------------------------------------------------------------------
SelfTest PROCEDURE
ini     STRING(260)
mdi     LONG
cls     CSTRING('MDIClient')
r       GROUP
X1        LONG
Y1        LONG
X2        LONG
Y2        LONG
        END
rp      LIKE(r)
cr      LIKE(r)
fails   LONG
n       LONG
y       LONG
id      LONG
before  LONG
  CODE
  ini = LONGPATH() & '\TaskPanelTest.ini'
  REMOVE(ini)
  fails = 0
  mdi = d_FindWindowEx(0{PROP:Handle}, 0, ADDRESS(cls), 0)

  ! 1. the panel exists and is docked left, the MDI client starts after it
  d_GetWindowRect(TP.GetDockHwnd(), ADDRESS(rp))
  d_GetWindowRect(mdi, ADDRESS(r))
  PUTINI('t1', 'panel', rp.X1 & ',' & rp.Y1 & ',' & rp.X2 & ',' & rp.Y2, ini)
  PUTINI('t1', 'mdi', r.X1 & ',' & r.Y1 & ',' & r.X2 & ',' & r.Y2, ini)
  IF d_IsWindowVisible(TP.GetDockHwnd()) AND r.X1 >= rp.X2 - 1 AND rp.X2 - rp.X1 = TP.PanelWidth
    PUTINI('t1', 'result', 'pass: docked left, MDI client narrowed', ini)
  ELSE
    PUTINI('t1', 'result', 'FAIL', ini)
    fails += 1
  END

  ! 2. dock right
  TP.Dock(MTP:Right)
  d_GetWindowRect(TP.GetDockHwnd(), ADDRESS(rp))
  d_GetWindowRect(mdi, ADDRESS(r))
  IF rp.X1 >= r.X2 - 1 AND rp.X2 - rp.X1 = TP.PanelWidth
    PUTINI('t2', 'result', 'pass: docked right', ini)
  ELSE
    PUTINI('t2', 'result', 'FAIL ' & rp.X1 & ' vs ' & r.X2, ini)
    fails += 1
  END

  ! 3. float: the MDI client gets its full width back
  d_GetClientRect(0{PROP:Handle}, ADDRESS(cr))
  TP.Dock(MTP:Float)
  d_GetWindowRect(mdi, ADDRESS(r))
  IF d_IsWindowVisible(TP.GetFloatHwnd()) AND ~d_IsWindowVisible(TP.GetDockHwnd()) AND r.X2 - r.X1 >= cr.X2 - 2
    PUTINI('t3', 'result', 'pass: floating, MDI client full width (' & r.X2 - r.X1 & ')', ini)
  ELSE
    PUTINI('t3', 'result', 'FAIL width ' & r.X2 - r.X1 & ' of ' & cr.X2, ini)
    fails += 1
  END

  ! 4. back to the left, resized
  TP.Dock(MTP:Left)
  TP.SetWidth(300)
  d_GetWindowRect(TP.GetDockHwnd(), ADDRESS(rp))
  d_GetWindowRect(mdi, ADDRESS(r))
  IF rp.X2 - rp.X1 = 300 AND r.X1 >= rp.X2 - 1
    PUTINI('t4', 'result', 'pass: width 300, MDI client follows', ini)
  ELSE
    PUTINI('t4', 'result', 'FAIL', ini)
    fails += 1
  END

  ! 5. the mirrored menu arrived, nested
  n = TP.FindText('Zip codes')
  IF TP.FindText('Browse') AND n AND TP.FindText('Geography') AND ~TP.FindText('Window')
    PUTINI('t5', 'result', 'pass: menu mirrored with 3 levels, Window skipped (' & TP.ItemCount() & ' items)', ini)
  ELSE
    PUTINI('t5', 'result', 'FAIL', ini)
    fails += 1
  END

  ! 6. a real click on "Customers": WM_LBUTTONDOWN/UP at its row
  DISPLAY()
  d_SendMessage(TP.GetDockHwnd(), 000Fh, 0, 0)               ! lay out
  id = TP.FindTag('cust')
  y = TP.RowY(id)
  before = Clicks
  d_SendMessage(TP.GetDockHwnd(), 0201h, 1, y * 65536 + 60)
  d_SendMessage(TP.GetDockHwnd(), 0202h, 0, y * 65536 + 60)
  PUTINI('t6', 'row y', y, ini)

  ! 7. a group header click collapses it (the Customers click is still queued)
  id = TP.FindText('Exports', 0)
  y = TP.RowY(id)
  d_SendMessage(TP.GetDockHwnd(), 0201h, 1, y * 65536 + 60)
  d_SendMessage(TP.GetDockHwnd(), 0202h, 0, y * 65536 + 60)
  IF ~TP.IsExpanded(id)
    PUTINI('t7', 'result', 'pass: header click collapsed Exports', ini)
  ELSE
    PUTINI('t7', 'result', 'FAIL y=' & y, ini)
    fails += 1
  END

  ! 9. drag the splitter 60 pixels wider
  d_GetWindowRect(TP.GetDockHwnd(), ADDRESS(rp))
  before = TP.PanelWidth
  d_SetCursorPos(rp.X2 - 2, rp.Y1 + 200)
  d_SendMessage(TP.GetDockHwnd(), 0201h, 1, 200 * 65536 + (rp.X2 - rp.X1 - 2))
  d_SetCursorPos(rp.X2 + 58, rp.Y1 + 200)
  d_SendMessage(TP.GetDockHwnd(), 0200h, 1, 200 * 65536 + (rp.X2 - rp.X1 + 58))
  d_SendMessage(TP.GetDockHwnd(), 0202h, 0, 200 * 65536 + (rp.X2 - rp.X1 + 58))
  d_GetWindowRect(mdi, ADDRESS(r))
  IF TP.PanelWidth = before + 60 AND r.X1 >= rp.X1 + TP.PanelWidth - 1
    PUTINI('t9', 'result', 'pass: splitter drag ' & before & ' -> ' & TP.PanelWidth & ', MDI client follows', ini)
  ELSE
    PUTINI('t9', 'result', 'FAIL ' & before & ' -> ' & TP.PanelWidth, ini)
    fails += 1
  END

  ! 11. drag the title into the MDI area: it floats
  d_GetWindowRect(TP.GetDockHwnd(), ADDRESS(rp))
  d_SetCursorPos(rp.X1 + 40, rp.Y1 + 15)
  d_SendMessage(TP.GetDockHwnd(), 0201h, 1, 15 * 65536 + 40)
  d_SetCursorPos(rp.X2 + 300, rp.Y1 + 200)
  d_SendMessage(TP.GetDockHwnd(), 0200h, 1, 200 * 65536 + 300)
  IF d_IsWindowVisible(TP.GetFloatHwnd()) AND ~d_IsWindowVisible(TP.GetDockHwnd()) AND TP.DockSide = MTP:Float
    PUTINI('t11', 'result', 'pass: dragging the title undocked it', ini)
  ELSE
    PUTINI('t11', 'result', 'FAIL', ini)
    fails += 1
  END

  ! 12. let go of the floating panel at the right edge: it docks there
  d_GetWindowRect(mdi, ADDRESS(r))
  d_SetCursorPos(r.X2 - 12, (r.Y1 + r.Y2) / 2)
  d_SendMessage(TP.GetFloatHwnd(), 0232h, 0, 0)        ! WM_EXITSIZEMOVE
  d_GetWindowRect(TP.GetDockHwnd(), ADDRESS(rp))
  d_GetWindowRect(mdi, ADDRESS(r))
  IF TP.DockSide = MTP:Right AND d_IsWindowVisible(TP.GetDockHwnd()) AND rp.X1 >= r.X2 - 1
    PUTINI('t12', 'result', 'pass: dropped at the right edge, docked right', ini)
  ELSE
    PUTINI('t12', 'result', 'FAIL side=' & TP.DockSide, ini)
    fails += 1
  END
  TP.Dock(MTP:Left)

  ! 10. click a mirrored menu row (Browse > Geography > Countries)
  TP.Animate = 0
  TP.ExpandAll(0)
  TP.Expand(TP.FindText('Menu', 0))
  TP.Expand(TP.FindText('Browse'))
  TP.Expand(TP.FindText('Geography', TP.FindText('Browse')))
  d_SendMessage(TP.GetDockHwnd(), 000Fh, 0, 0)
  id = TP.FindText('Countries', TP.FindText('Geography', TP.FindText('Browse')))
  y = TP.RowY(id)
  d_SendMessage(TP.GetDockHwnd(), 0201h, 1, y * 65536 + 80)
  d_SendMessage(TP.GetDockHwnd(), 0202h, 0, y * 65536 + 80)
  PUTINI('t10', 'row y', y, ini)

  ! 8. engine
  PUTINI('t8', 'engine', CHOOSE(TP.UsingD2D() = MTP:DirectX, 'DirectX', 'Clarion'), ini)
  PUTINI('summary', 'fails', fails, ini)
  PUTINI('summary', 'rows', TP.RowCount(), ini)
  0{PROP:Timer} = 300                                  ! watchdog for t6

!-----------------------------------------------------------------------------
!  The panel on an ordinary WINDOW: the window's client area is narrowed and
!  the window grows by the panel's width, so the form keeps its room.
!-----------------------------------------------------------------------------
FormDemo PROCEDURE
FP      TestPanel
g       LONG
ini     STRING(260)
wr      GROUP
X1        LONG
Y1        LONG
X2        LONG
Y2        LONG
        END
er      LIKE(wr)
wr2     LIKE(wr)
er2     LIKE(wr)
CusName STRING(40)
CusCity STRING(30)
win     WINDOW('Customer'),AT(,,260,120),CENTER,SYSTEM,FONT('Segoe UI',9),GRAY,RESIZE
          PROMPT('&Name:'),AT(10,12),USE(?NamePrompt)
          ENTRY(@s40),AT(60,10,180,12),USE(CusName)
          PROMPT('&City:'),AT(10,32),USE(?CityPrompt)
          ENTRY(@s30),AT(60,30,180,12),USE(CusCity)
          BUTTON('&OK'),AT(150,96,44,14),USE(?OK),DEFAULT
          BUTTON('&Cancel'),AT(198,96,44,14),USE(?Cancel),STD(STD:Close)
        END
  CODE
  OPEN(win)
  ACCEPT
    CASE EVENT()
    OF EVENT:OpenWindow
      d_GetWindowRect(0{PROP:Handle}, ADDRESS(wr))
      d_GetWindowRect(?CusName{PROP:Handle}, ADDRESS(er))
      FP.Init(win, CHOOSE(Arg('engine') = 'dx', MTP:DirectX, MTP:Clarion))
      FP.Title = 'Customer'
      FP.PanelWidth = 190
      IF Arg('theme') THEN FP.SetTheme(Arg('theme')).
      g = FP.AddGroup('Record', 'doc', 1, 1)
      FP.AddItem(g, 'Save', 'plus', 'save', ?OK)       ! an item pointed at a BUTTON
      FP.AddItem(g, 'Print', 'print', 'print')
      FP.AddItem(g, 'Email', 'mail', 'mail')
      g = FP.AddGroup('Related', 'link')
      FP.AddItem(g, 'Invoices', 'money', 'inv')
      FP.AddItem(g, 'Orders', 'cart', 'ord')
      FP.ShowPanel()
      IF Arg('auto')
        ini = LONGPATH() & '\TaskPanelWinTest.ini'
        REMOVE(ini)
        d_GetWindowRect(0{PROP:Handle}, ADDRESS(wr2))
        d_GetWindowRect(?CusName{PROP:Handle}, ADDRESS(er2))
        PUTINI('w1', 'window', (wr.X2 - wr.X1) & ' -> ' & (wr2.X2 - wr2.X1), ini)
        PUTINI('w1', 'entry x', er.X1 & ' -> ' & er2.X1, ini)
        IF (wr2.X2 - wr2.X1) - (wr.X2 - wr.X1) = 190 AND er2.X1 - er.X1 = 190
          PUTINI('w1', 'result', 'pass: window grew by 190, the form moved right by 190', ini)
        ELSE
          PUTINI('w1', 'result', 'FAIL', ini)
        END
        FP.Dock(MTP:Float)
        d_GetWindowRect(0{PROP:Handle}, ADDRESS(wr2))
        d_GetWindowRect(?CusName{PROP:Handle}, ADDRESS(er2))
        IF wr2.X2 - wr2.X1 = wr.X2 - wr.X1 AND er2.X1 = er.X1
          PUTINI('w2', 'result', 'pass: floating gives the window its size and layout back', ini)
        ELSE
          PUTINI('w2', 'result', 'FAIL ' & (wr2.X2 - wr2.X1) & ' ' & er2.X1, ini)
        END
        FP.Dock(MTP:Right)
        d_GetWindowRect(?CusName{PROP:Handle}, ADDRESS(er2))
        d_GetWindowRect(FP.GetDockHwnd(), ADDRESS(wr2))
        IF er2.X1 = er.X1 AND wr2.X1 > er2.X2
          PUTINI('w3', 'result', 'pass: docked right, the form stays put', ini)
        ELSE
          PUTINI('w3', 'result', 'FAIL', ini)
        END
        POST(EVENT:CloseWindow)
      END
    OF MTP:Event
      LOOP WHILE FP.NextClick()
        0{PROP:Text} = 'Customer - ' & FP.ClickText
      END
    END
    CASE ACCEPTED()
    OF ?OK
      0{PROP:Text} = 'Customer - saved'
    END
  END
  FP.Kill()

!-----------------------------------------------------------------------------
BrowseWin PROCEDURE(STRING title)
CP     MyTaskPanelClass                         ! a panel on this MDI child's own thread
cg     LONG
Q      QUEUE
Name     STRING(40)
City     STRING(30)
       END
i      LONG
win    WINDOW('Browse'),AT(,,300,170),MDI,SYSTEM,RESIZE,FONT('Segoe UI',9),MAX
         LIST,AT(6,6,288,138),USE(?List),FULL,VSCROLL,FROM(Q),FORMAT('140L(2)|M~Name~@s40@120L(2)~City~@s30@')
         BUTTON('&Close'),AT(250,150,44,14),USE(?Close),STD(STD:Close)
       END
  CODE
  LOOP i = 1 TO 40
    Q.Name = CLIP(title) & ' ' & i
    Q.City = CHOOSE(i - INT(i / 4) * 4 + 1, 'Monterrey', 'Guadalajara', 'Austin', 'Madrid')
    ADD(Q)
  END
  OPEN(win)
  win{PROP:Text} = title
  IF Arg('lang') = 'es'
    ?List{PROPLIST:Header, 1} = 'Nombre'
    ?List{PROPLIST:Header, 2} = 'Ciudad'
    ?Close{PROP:Text} = '&Cerrar'
  END
  IF Arg('childpanel') OR Arg('mt')
    CP.Init(win, CHOOSE(Arg('engine') = 'dx', MTP:DirectX, MTP:Clarion))
    CP.Title = title
    CP.PanelWidth = 170
    CP.SetTheme(MTP:Teal)
    cg = CP.AddGroup('Record', 'doc', 1, 1)
    CP.AddItem(cg, 'Insert', 'plus')
    CP.AddItem(cg, 'Change', 'doc')
    CP.AddItem(cg, 'Print', 'print')
    CP.ShowPanel()
  END
  ACCEPT
    IF EVENT() = MTP:Event
      LOOP WHILE CP.NextClick()
      END
    END
  END
  CP.Kill()

AboutWin PROCEDURE
win    WINDOW('About'),AT(,,200,80),CENTER,MDI,SYSTEM,FONT('Segoe UI',9)
         STRING('myTaskPanel demo'),AT(10,10),FONT(,12,,FONT:bold)
         STRING('Task panels for Clarion - Clarion and DirectX engines.'),AT(10,30)
         BUTTON('OK'),AT(150,58,40,14),USE(?OK),STD(STD:Close),DEFAULT
       END
  CODE
  OPEN(win)
  ACCEPT
  END
