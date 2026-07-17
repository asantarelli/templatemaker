  PROGRAM
!  ============================================================================
!  YuruShots - render one still frame of every preset to a .bmp, for the docs
!  and as a headless smoke-test of YuruClass.  Opens a window (never enters an
!  ACCEPT loop), paints each preset at a fixed clock value, saves it, quits.
!  ============================================================================

  INCLUDE('EQUATES.CLW'),ONCE
  INCLUDE('YuruClass.INC'),ONCE

  MAP
  END

Flow     YuruClass
p        LONG
Names    STRING('ribbon  seashellnebula  lattice reeds   plume   ') ! 8 chars each

Win      WINDOW('shots'),AT(,,340,340),CENTER,SYSTEM
           IMAGE(''),AT(0,0,320,320),USE(?Canvas)
         END

  CODE
  OPEN(Win)
  Flow.Init(?Canvas)
  Flow.InkColor = 00FFFFFFH                                   ! white glow for the docs
  LOOP p = 1 TO 6
    Flow.Preset = p
    Flow.Restart()
    Flow.tVal = 8.0                                           ! a pleasing, animated moment
    Flow.Paint()
    Flow.SaveAs('shot_' & CLIP(Names[(p-1)*8+1 : (p-1)*8+8]) & '.bmp')
  END
  Flow.Preset = Yuru:Nebula ; Flow.InkColor = 006E760FH       ! Teal, to prove colored ink
  Flow.Restart() ; Flow.tVal = 8.0 ; Flow.Paint()
  Flow.SaveAs('shot_teal.bmp')
  CLOSE(Win)
  RETURN
