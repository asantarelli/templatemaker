  PROGRAM
! ============================================================================
!  GaugePlusPlayground - a live, hand-coded property playground for the
!  antialiased GaugePlusClass gauge. A big gauge fills the left; a tabbed
!  control panel on the right drives EVERY property in real time:
!
!    * Shape        - style preset (180/270/360/90/45/custom), custom angles,
!                     min/max range, a live VALUE slider, radius & track sliders
!    * Ticks & Text - major/minor ticks, tick labels + decimals, title, units,
!                     numeric readout + decimals
!    * Needle&Look  - needle style/width/length, show face/gloss/rim/track/arc
!    * Colors       - a colour picker + live swatch for every colour property
!    * Anim & Zones - eased sweep buttons, animation speed/step, colour bands
!
!  Change ANY control (drag a slider, tick a box, pick a colour) and the gauge
!  repaints instantly. This is the same class the myGaugePlus template wires up
!  - so whatever looks good here maps 1:1 to the template prompts.
!
!  Hand-coded (no AppGen). Compile GaugePlusPlayground.cwproj.
! ============================================================================
  INCLUDE('GaugePlusClass.INC'),ONCE
  MAP
  END

! ---- screen variables (each bound to a control; copied into the gauge) ------
StyleV         STRING(4)                                     ! '1'..'5' preset, '0' = custom
StartV         REAL                                          ! custom start angle
SweepV         REAL                                          ! custom sweep angle
MinV           LONG
MaxV           LONG
ValV           LONG                                          ! the live value (slider)
RadiusV        LONG                                          ! RadiusPct
TrackV         LONG                                          ! TrackPct (band thickness)
MajorV         LONG
MinorV         LONG
ShowLabelsV    LONG
LabelDPV       LONG
TitleV         CSTRING(64)
UnitsV         CSTRING(32)
ShowValueV     LONG
ValueDPV       LONG
NeedleStyleV   STRING(4)                                     ! '1' triangle, '0' line
NeedleWidthV   LONG
NeedleLenV     LONG                                          ! NeedleLenPct
ShowFaceV      LONG
ShowGlossV     LONG
ShowRimV       LONG
ShowTrackV     LONG
ShowValueArcV  LONG
ValueColorV    LONG
FaceColorV     LONG
FaceEdgeV      LONG
TrackColorV    LONG
TickColorV     LONG
TextColorV     LONG
NeedleColorV   LONG
BackColorV     LONG
AnimSpeedV     LONG
StepV          REAL
Zone1V         LONG
Zone2V         LONG
Zone3V         LONG
FaceImageV     CSTRING(256)                                 ! optional base-layer face image path

Win  WINDOW('myGaugePlus - Live Property Playground'),AT(,,668,382),CENTER,SYSTEM,GRAY,FONT('Segoe UI',9)
       PANEL,AT(4,4,326,354),BEVEL(-1)
       IMAGE,AT(10,10,314,342),USE(?Img)
       STRING('Drag the Value slider or change any option - the gauge repaints live.'),AT(6,362,320,10),USE(?Hint),FONT(,8),CENTER
       SHEET,AT(334,6,330,352),USE(?Sheet)
         TAB('&Shape')
           OPTION('Gauge style'),AT(340,24,318,44),BOXED,USE(StyleV),TRN
             RADIO('180 Semi'),AT(348,36,72,10),VALUE('1')
             RADIO('270 Speedo'),AT(348,50,72,10),VALUE('2')
             RADIO('360 Full'),AT(424,36,72,10),VALUE('3')
             RADIO('90 Quarter'),AT(424,50,72,10),VALUE('4')
             RADIO('45 Narrow'),AT(500,36,60,10),VALUE('5')
             RADIO('Custom'),AT(500,50,60,10),VALUE('0')
           END
           PROMPT('Start:'),AT(342,74,28,10),USE(?PStart)
           SPIN(@n7.1),AT(372,72,54,11),USE(StartV),RANGE(-360,360),STEP(5)
           PROMPT('Sweep:'),AT(438,74,32,10),USE(?PSweep)
           SPIN(@n7.1),AT(472,72,54,11),USE(SweepV),RANGE(-360,360),STEP(5)
           PROMPT('Min:'),AT(342,92,24,10),USE(?PMin)
           SPIN(@n-7),AT(368,90,58,11),USE(MinV),RANGE(-100000,100000),STEP(1)
           PROMPT('Max:'),AT(438,92,24,10),USE(?PMax)
           SPIN(@n-7),AT(466,90,58,11),USE(MaxV),RANGE(-100000,100000),STEP(1)
           GROUP('Value'),AT(340,108,318,42),BOXED
             STRING(@n-11.2),AT(468,116,86,10),USE(?ValNum),RIGHT
             SLIDER,AT(348,130,304,12),USE(ValV),RANGE(-100000,100000)  ! wide so OPEN never clamps; retuned to Min/Max in ApplyDraw
           END
           PROMPT('Radius %:'),AT(342,158,44,10),USE(?PRad)
           SLIDER,AT(388,156,120,12),USE(RadiusV),RANGE(40,100)
           STRING(@n3),AT(514,158,20,10),USE(?RadNum)
           PROMPT('Track %:'),AT(342,176,44,10),USE(?PTrk)
           SLIDER,AT(388,174,120,12),USE(TrackV),RANGE(2,40)
           STRING(@n3),AT(514,176,20,10),USE(?TrkNum)
         END
         TAB('&Ticks && Text')
           PROMPT('Major ticks (divisions):'),AT(342,30,110,10),USE(?PMaj)
           SPIN(@n3),AT(456,28,44,11),USE(MajorV),RANGE(0,50),STEP(1)
           PROMPT('Minor ticks (between):'),AT(342,46,110,10),USE(?PMin2)
           SPIN(@n3),AT(456,44,44,11),USE(MinorV),RANGE(0,20),STEP(1)
           CHECK('Show tick labels'),AT(342,64,110,10),USE(ShowLabelsV)
           PROMPT('Label decimals:'),AT(342,80,80,10),USE(?PLdp)
           SPIN(@n1),AT(424,78,34,11),USE(LabelDPV),RANGE(0,4),STEP(1)
           PROMPT('Title:'),AT(342,102,30,10),USE(?PTit)
           ENTRY(@s63),AT(378,100,180,11),USE(TitleV)
           PROMPT('Units:'),AT(342,118,30,10),USE(?PUni)
           ENTRY(@s31),AT(378,116,180,11),USE(UnitsV)
           CHECK('Show numeric value'),AT(342,138,120,10),USE(ShowValueV)
           PROMPT('Value decimals:'),AT(342,154,80,10),USE(?PVdp)
           SPIN(@n1),AT(424,152,34,11),USE(ValueDPV),RANGE(0,4),STEP(1)
         END
         TAB('&Needle && Look')
           OPTION('Needle style'),AT(340,24,220,26),BOXED,USE(NeedleStyleV),TRN
             RADIO('Triangle'),AT(350,36,64,10),VALUE('1')
             RADIO('Line'),AT(430,36,50,10),VALUE('0')
           END
           PROMPT('Needle width:'),AT(342,58,66,10),USE(?PNw)
           SLIDER,AT(410,56,96,12),USE(NeedleWidthV),RANGE(1,20)
           STRING(@n2),AT(512,58,16,10),USE(?NwNum)
           PROMPT('Needle length %:'),AT(342,76,74,10),USE(?PNl)
           SLIDER,AT(418,74,88,12),USE(NeedleLenV),RANGE(30,100)
           STRING(@n3),AT(512,76,18,10),USE(?NlNum)
           GROUP('Show / hide'),AT(340,94,318,58),BOXED
             CHECK('Face'),AT(350,106,70,10),USE(ShowFaceV)
             CHECK('Gloss highlight'),AT(444,106,100,10),USE(ShowGlossV)
             CHECK('Rim'),AT(350,120,70,10),USE(ShowRimV)
             CHECK('Track'),AT(444,120,100,10),USE(ShowTrackV)
             CHECK('Value arc fill'),AT(350,134,100,10),USE(ShowValueArcV)
           END
         END
         TAB('&Colors')
           BUTTON('Value / accent...'),AT(342,28,120,14),USE(?BtnValueColor)
           REGION,AT(470,28,44,14),USE(?SwValue),FILL(00C86E28H),BEVEL(-1,-1)
           BUTTON('Face centre...'),AT(342,46,120,14),USE(?BtnFaceColor)
           REGION,AT(470,46,44,14),USE(?SwFace),FILL(00FAFAFAH),BEVEL(-1,-1)
           BUTTON('Face rim...'),AT(342,64,120,14),USE(?BtnFaceEdge)
           REGION,AT(470,64,44,14),USE(?SwEdge),FILL(00D4D4D4H),BEVEL(-1,-1)
           BUTTON('Track (empty)...'),AT(342,82,120,14),USE(?BtnTrackColor)
           REGION,AT(470,82,44,14),USE(?SwTrack),FILL(00E2E2E2H),BEVEL(-1,-1)
           BUTTON('Ticks...'),AT(342,100,120,14),USE(?BtnTickColor)
           REGION,AT(470,100,44,14),USE(?SwTick),FILL(00909090H),BEVEL(-1,-1)
           BUTTON('Text...'),AT(342,118,120,14),USE(?BtnTextColor)
           REGION,AT(470,118,44,14),USE(?SwText),FILL(003A3A3AH),BEVEL(-1,-1)
           BUTTON('Needle...'),AT(342,136,120,14),USE(?BtnNeedleColor)
           REGION,AT(470,136,44,14),USE(?SwNeedle),FILL(002B2B2BH),BEVEL(-1,-1)
           BUTTON('Background...'),AT(342,154,120,14),USE(?BtnBackColor)
           REGION,AT(470,154,44,14),USE(?SwBack),FILL(00F0F0F0H),BEVEL(-1,-1)
           BUTTON('Reset all to defaults'),AT(342,178,140,14),USE(?BtnReset)
           LINE,AT(342,198,314,0),USE(?Ln1)
           PROMPT('Face image (drawn as the base layer):'),AT(342,204,220,10),USE(?PFaceImg)
           BUTTON('Face image...'),AT(342,218,120,14),USE(?BtnFaceImage)
           BUTTON('Clear image'),AT(470,218,90,14),USE(?BtnClearImage)
           STRING('(none)'),AT(342,236,314,10),USE(?FaceImgName),FONT(,8)
         END
         TAB('&Anim && Zones')
           PROMPT('Timer interval (1/100 s):'),AT(342,30,110,10),USE(?PSpd)
           SPIN(@n4),AT(456,28,44,11),USE(AnimSpeedV),RANGE(1,200),STEP(1)
           PROMPT('Step per tick (% of range):'),AT(342,46,120,10),USE(?PStp)
           SPIN(@n5.1),AT(466,44,50,11),USE(StepV),RANGE(0.5,50),STEP(0.5)
           BUTTON('Sweep to Min'),AT(342,66,96,14),USE(?BtnSweepMin)
           BUTTON('Sweep to Max'),AT(446,66,96,14),USE(?BtnSweepMax)
           GROUP('Colour zones (bands over value ranges)'),AT(340,90,318,60),BOXED
             CHECK('Green band  - lower 60%'),AT(350,104,160,10),USE(Zone1V)
             CHECK('Amber band  - 60% to 85%'),AT(350,120,160,10),USE(Zone2V)
             CHECK('Red band    - upper 15%'),AT(350,136,160,10),USE(Zone3V)
           END
         END
       END
       BUTTON('&Quit'),AT(608,364,56,14),USE(?BtnQuit)
     END

G    GaugePlusClass
  CODE
  DO SetDefaults
  OPEN(Win)
  ?ValV{PROP:RangeLow}  = MinV                              ! widen the value slider BEFORE the first
  ?ValV{PROP:RangeHigh} = MaxV                              ! DISPLAY, else it clamps ValV to RANGE(0,100)
  DISPLAY                                                    ! push defaults into the controls
  ACCEPT
    CASE EVENT()
    OF EVENT:OpenWindow
      DO ApplyDraw
    OF EVENT:Sized
      G.Draw(Win, ?Img)
    OF EVENT:NewSelection                                    ! slider drags land here
      DO ApplyDraw
    OF EVENT:Timer
      IF G.AnimStep()
        G.Draw(Win, ?Img)
        ValV = G.Value
        DISPLAY(?ValV)
        DO SyncNums
      END
      IF G.Value = G.Target THEN 0{PROP:Timer} = 0.
    END
    CASE ACCEPTED()
    OF ?BtnValueColor;  IF COLORDIALOG('Value / accent colour', ValueColorV) THEN DO ApplyDraw.
    OF ?BtnFaceColor;   IF COLORDIALOG('Face centre colour', FaceColorV)     THEN DO ApplyDraw.
    OF ?BtnFaceEdge;    IF COLORDIALOG('Face rim colour', FaceEdgeV)         THEN DO ApplyDraw.
    OF ?BtnTrackColor;  IF COLORDIALOG('Track (empty) colour', TrackColorV)  THEN DO ApplyDraw.
    OF ?BtnTickColor;   IF COLORDIALOG('Tick colour', TickColorV)            THEN DO ApplyDraw.
    OF ?BtnTextColor;   IF COLORDIALOG('Text colour', TextColorV)            THEN DO ApplyDraw.
    OF ?BtnNeedleColor; IF COLORDIALOG('Needle colour', NeedleColorV)        THEN DO ApplyDraw.
    OF ?BtnBackColor;   IF COLORDIALOG('Canvas background colour', BackColorV) THEN DO ApplyDraw.
    OF ?BtnReset;       DO SetDefaults; DISPLAY; DO ApplyDraw
    OF ?BtnFaceImage;   IF FILEDIALOG('Choose a face image', FaceImageV, 'Image files|*.png;*.jpg;*.jpeg;*.bmp;*.gif|All files|*.*') THEN DO ApplyDraw.
    OF ?BtnClearImage;  FaceImageV = ''; DO ApplyDraw
    OF ?BtnSweepMin;    G.AnimateTo(MinV); 0{PROP:Timer} = AnimSpeedV
    OF ?BtnSweepMax;    G.AnimateTo(MaxV); 0{PROP:Timer} = AnimSpeedV
    OF ?BtnQuit;        POST(EVENT:CloseWindow)
    ELSE
      DO ApplyDraw                                           ! any other field changed
    END
  END
  CLOSE(Win)
  RETURN

!===========================================================================
SetDefaults ROUTINE
  StyleV = '2';        StartV = 225;      SweepV = -270
  MinV = 0;            MaxV = 220;        ValV = 146
  RadiusV = 92;        TrackV = 12
  MajorV = 11;         MinorV = 1
  ShowLabelsV = 1;     LabelDPV = 0
  TitleV = 'SPEED';    UnitsV = 'km/h'
  ShowValueV = 1;      ValueDPV = 0
  NeedleStyleV = '1';  NeedleWidthV = 5;  NeedleLenV = 78
  ShowFaceV = 1;       ShowGlossV = 1;    ShowRimV = 1
  ShowTrackV = 1;      ShowValueArcV = 1
  ValueColorV = 00C86E28H
  FaceColorV  = 00FAFAFAH
  FaceEdgeV   = 00D4D4D4H
  TrackColorV = 00E2E2E2H
  TickColorV  = 00909090H
  TextColorV  = 003A3A3AH
  NeedleColorV= 002B2B2BH
  BackColorV  = COLOR:None
  AnimSpeedV = 4;      StepV = 5
  Zone1V = 1;          Zone2V = 1;        Zone3V = 1
  FaceImageV = ''

!===========================================================================
ApplyDraw ROUTINE
DATA
span  REAL
  CODE
  ! ---- shape ----
  IF StyleV = '0'
    G.SetSpan(StartV, SweepV)
    ENABLE(?StartV); ENABLE(?SweepV)
  ELSE
    G.Preset(StyleV)
    DISABLE(?StartV); DISABLE(?SweepV)
  END
  ! ---- range (keep max > min, clamp value, retune the value slider) ----
  IF MaxV <= MinV THEN MaxV = MinV + 1.
  G.SetRange(MinV, MaxV)
  ?ValV{PROP:RangeLow}  = MinV
  ?ValV{PROP:RangeHigh} = MaxV
  IF ValV < MinV THEN ValV = MinV.
  IF ValV > MaxV THEN ValV = MaxV.
  ! ---- geometry ----
  G.RadiusPct = RadiusV
  G.TrackPct  = TrackV
  ! ---- ticks & text ----
  G.MajorTicks = MajorV
  G.MinorTicks = MinorV
  G.ShowLabels = ShowLabelsV
  G.LabelDP    = LabelDPV
  G.ShowValue  = ShowValueV
  G.ValueDP    = ValueDPV
  G.Title      = TitleV
  G.Units      = UnitsV
  ! ---- needle & look ----
  G.NeedleStyle  = NeedleStyleV
  G.NeedleWidth  = NeedleWidthV
  G.NeedleLenPct = NeedleLenV
  G.ShowFace     = ShowFaceV
  G.ShowGloss    = ShowGlossV
  G.ShowRim      = ShowRimV
  G.ShowTrack    = ShowTrackV
  G.ShowValueArc = ShowValueArcV
  ! ---- colours ----
  G.ValueColor  = ValueColorV
  G.FaceColor   = FaceColorV
  G.FaceEdge    = FaceEdgeV
  G.TrackColor  = TrackColorV
  G.TickColor   = TickColorV
  G.TextColor   = TextColorV
  G.NeedleColor = NeedleColorV
  G.BackColor   = BackColorV
  G.FaceImage   = FaceImageV
  G.AnimStepPct = StepV
  ! ---- zones (rebuilt every time from the three check boxes) ----
  G.ClearZones()
  span = MaxV - MinV
  IF Zone1V THEN G.AddZone(MinV,              MinV + span*0.60, 02CA02CH).  ! green
  IF Zone2V THEN G.AddZone(MinV + span*0.60,  MinV + span*0.85, 020C0F0H).  ! amber
  IF Zone3V THEN G.AddZone(MinV + span*0.85,  MaxV,             02020E0H).  ! red
  ! ---- value + paint ----
  G.SetValue(ValV)
  G.Draw(Win, ?Img)
  DO SyncSwatch
  DO SyncNums
  DISPLAY

!===========================================================================
SyncNums ROUTINE                                             ! live numeric read-outs beside the sliders
  ?ValNum{PROP:Text} = CLIP(LEFT(FORMAT(ValV, @n-11.2)))
  ?RadNum{PROP:Text} = RadiusV
  ?TrkNum{PROP:Text} = TrackV
  ?NwNum{PROP:Text}  = NeedleWidthV
  ?NlNum{PROP:Text}  = NeedleLenV
  IF FaceImageV = ''
    ?FaceImgName{PROP:Text} = '(none)'
  ELSE
    ?FaceImgName{PROP:Text} = FaceImageV
  END

!===========================================================================
SyncSwatch ROUTINE                                           ! live colour chips on the Colors tab
  ?SwValue{PROP:Fill}  = ValueColorV
  ?SwFace{PROP:Fill}   = FaceColorV
  ?SwEdge{PROP:Fill}   = FaceEdgeV
  ?SwTrack{PROP:Fill}  = TrackColorV
  ?SwTick{PROP:Fill}   = TickColorV
  ?SwText{PROP:Fill}   = TextColorV
  ?SwNeedle{PROP:Fill} = NeedleColorV
  IF BackColorV = COLOR:None
    ?SwBack{PROP:Fill} = 00F0F0F0H
  ELSE
    ?SwBack{PROP:Fill} = BackColorV
  END
