  PROGRAM
!  ============================================================================
!  YuruDemo - a hand-coded standalone demo for YuruClass, mirroring the web app
!  at c:\ai\yuruyurau\index.html.  Pick a preset, set the ink color and speed,
!  and the animation plays live on an IMAGE control.  No dictionary, no
!  templates - just the class.
!
!  Build: 32-bit Clarion EXE. Project must compile YuruDemo.clw + YuruClass.clw.
!  ============================================================================

  INCLUDE('EQUATES.CLW'),ONCE
  INCLUDE('YuruClass.INC'),ONCE

  MAP
InkColorOf PROCEDURE(LONG pIx),LONG                           ! ink index (1..10) -> Clarion color
  END

Flow     YuruClass                                            ! the animation object

PresetTxt STRING(12)
SpeedV    REAL(1.0)
InkTxt    STRING(10)
Running   BYTE(1)
SaveName  STRING(261)

Win      WINDOW('Yuruyurau - Animated Flow Fields'),AT(,,340,362),CENTER,SYSTEM,GRAY,|
             FONT('Segoe UI',9),TIMER(4)
           IMAGE(''),AT(10,10,320,300),USE(?Canvas),CENTERED
           PROMPT('Preset:'),AT(10,320),USE(?PP)
           LIST,AT(42,318,84,10),USE(PresetTxt),DROP(6),|
             FROM('Ribbon|Seashell|Nebula|Lattice|Reeds|Plume')
           PROMPT('Ink:'),AT(134,320),USE(?IP)
           LIST,AT(150,318,70,10),USE(InkTxt),DROP(10),|
             FROM('Ink|Teal|Sky|Amber|Rose|Forest|Slate|White|Mint|Gold')
           PROMPT('Speed:'),AT(228,320),USE(?SP)
           SPIN(@n3.1),AT(258,318,34,10),USE(SpeedV),RANGE(0.1,5.0),STEP(0.1)
           BUTTON('Start'),AT(10,338,42,16),USE(?Start)
           BUTTON('Stop'),AT(54,338,42,16),USE(?Stop)
           BUTTON('Reset'),AT(98,338,42,16),USE(?Restart)
           BUTTON('Save BMP...'),AT(258,338,72,16),USE(?Save)
         END

  CODE
  OPEN(Win)
  ?PresetTxt{PROP:Selected} = 1 ; PresetTxt = 'Ribbon'
  ?InkTxt{PROP:Selected} = 8    ; InkTxt = 'White'           ! white glow by default
  Flow.Init(?Canvas)
  Flow.Preset   = Yuru:Ribbon
  Flow.InkColor = 00FFFFFFH
  Flow.Speed    = SpeedV
  Flow.Paint()                                               ! first frame at once
  ACCEPT
    CASE EVENT()
    OF EVENT:Timer
      IF Running THEN Flow.NextFrame().
    OF EVENT:CloseWindow
      BREAK
    END
    CASE ACCEPTED()
    OF ?PresetTxt ; Flow.Preset = CHOICE(?PresetTxt) ; Flow.Restart() ; Flow.Paint()
    OF ?InkTxt    ; Flow.InkColor = InkColorOf(CHOICE(?InkTxt)) ; Flow.Paint()
    OF ?SpeedV    ; Flow.Speed = SpeedV
    OF ?Start     ; Running = 1
    OF ?Stop      ; Running = 0
    OF ?Restart   ; Flow.Restart() ; Flow.Paint()
    OF ?Save      ; DO SaveFrame
    END
  END
  CLOSE(Win)
  RETURN

! ---------------------------------------------------------------------------
!  Save whatever frame is currently on screen to a user-chosen .bmp file.
SaveFrame ROUTINE
  SaveName = 'yuruyurau.bmp'
  IF FILEDIALOG('Save current frame', SaveName, 'Bitmap|*.bmp', FILE:Save + FILE:KeepDir)
    Flow.SaveAs(SaveName)
  END

! ===========================================================================
!  10 professional ink colors (no purple), matching the web app's palette.
!  Clarion color = 00BBGGRR.
! ===========================================================================
InkColorOf PROCEDURE(LONG pIx)!,LONG
  CODE
  CASE pIx
  OF  1 ; RETURN 002E2114H                                    ! Ink    #14212e
  OF  2 ; RETURN 006E760FH                                    ! Teal   #0f766e
  OF  3 ; RETURN 00A16903H                                    ! Sky    #0369a1
  OF  4 ; RETURN 000953B4H                                    ! Amber  #b45309
  OF  5 ; RETURN 0039129FH                                    ! Rose   #9f1239
  OF  6 ; RETURN 00346516H                                    ! Forest #166534
  OF  7 ; RETURN 00554133H                                    ! Slate  #334155
  OF  8 ; RETURN 00FFFFFFH                                    ! White  #ffffff
  OF  9 ; RETURN 00D4EA5EH                                    ! Mint   #5eead4
  OF 10 ; RETURN 004DD3FCH                                    ! Gold   #fcd34d
  END
  RETURN 00FFFFFFH
