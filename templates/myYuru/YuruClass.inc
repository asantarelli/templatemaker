!ABCIncludeFile
! ============================================================================
!  YuruClass - "yuruyurau" animated flow-field / particle art for Clarion.
!
!  Renders the pure-trigonometry point sketches of the generative artist
!  @yuruyurau onto a Clarion IMAGE control. Clarion has no per-pixel canvas,
!  so each frame the class:
!    1. computes the formula for every particle (10,000 - or 30,000 Lattice),
!    2. plots each point ADDITIVELY into an in-memory 24-bit BMP byte buffer,
!       so overlapping points brighten (mimics the alpha-stroke glow of the
!       p5.js originals),
!    3. writes the buffer to a temp .bmp file,
!    4. loads it into the IMAGE control with feq{PROP:Text} = filename.
!  Two temp files are alternated per object so the control never holds a lock
!  on the file the next frame is being written to.
!
!  Pure Clarion - no dictionary, no third-party classes, no external libs.
!  The internal bitmap is a fixed 400x400; the IMAGE control scales it to
!  whatever display size you give the control.
!
!  USAGE (handled by the myYuru template, or call it yourself):
!    INCLUDE('YuruClass.INC'),ONCE     then one instance per animation:
!      Flow   YuruClass
!    Flow.Init(?Canvas)                 ! remember the IMAGE control
!    Flow.Preset   = Yuru:Ribbon
!    Flow.InkColor = COLOR:White        ! any Clarion 00BBGGRR color
!    Flow.Speed    = 1.0
!    Flow.Paint()                       ! draw the first frame
!    ...on each window EVENT:Timer:  Flow.NextFrame()   ! advance + repaint
!
!  This file MUST be stored in ANSI/CRLF (not UTF-8, not LF-only).
! ============================================================================

Yuru:Ribbon        EQUATE(1)                                 ! 10k particles, single loop
Yuru:Seashell      EQUATE(2)                                 ! atan2 petal bloom
Yuru:Nebula        EQUATE(3)                                 ! atan2 orbital rings
Yuru:Lattice       EQUATE(4)                                 ! 30k, modular interference
Yuru:Reeds         EQUATE(5)                                 ! swaying strands, reads the loop index
Yuru:Plume         EQUATE(6)                                 ! atan2 fast feather

YuruClass CLASS,TYPE,MODULE('YuruClass.CLW'),LINK('YuruClass.CLW')
Feq                SIGNED                                    ! the IMAGE control we paint into
Preset             LONG                                      ! one of the Yuru:xxx equates
tVal               REAL                                      ! animation clock
Speed              REAL                                      ! time-step multiplier (0.1 .. 5.0)
InkColor           LONG                                      ! particle color, Clarion 00BBGGRR
BackGray           LONG                                      ! background grey level 0..255 (near-black looks best)
Brightness         LONG                                      ! additive brightness per plotted point (1..255)
! ---- internal (per instance) ----------------------------------------------
IncR               LONG                                      ! per-channel additive step (derived from InkColor+Brightness)
IncG               LONG
IncB               LONG
FileA              CSTRING(261)                              ! two temp .bmp files, alternated
FileB              CSTRING(261)
Toggle             BYTE
Inited             BYTE
! ---- methods --------------------------------------------------------------
Construct          PROCEDURE
Destruct           PROCEDURE                                 ! best-effort temp-file cleanup
Init               PROCEDURE(SIGNED pImageFeq)               ! remember the control, build unique temp names
Restart            PROCEDURE                                 ! zero the clock
Dt                 PROCEDURE(),REAL                          ! time step for the current preset
Paint              PROCEDURE                                 ! render the current frame into the image
NextFrame          PROCEDURE                                 ! advance the clock one step, then Paint
SaveAs             PROCEDURE(STRING pFile)                   ! write the last-rendered frame to a named .bmp
! ---- internal -------------------------------------------------------------
RecalcInc          PROCEDURE                                 ! derive IncR/IncG/IncB from InkColor+Brightness
Plot               PROCEDURE(REAL pX,REAL pY)                ! additive plot of one point (off-canvas ignored)
Ribbon             PROCEDURE
Seashell           PROCEDURE
Nebula             PROCEDURE
Lattice            PROCEDURE
Reeds              PROCEDURE
Plume              PROCEDURE
                   END
