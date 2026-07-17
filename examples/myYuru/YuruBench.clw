  PROGRAM
!  ============================================================================
!  YuruBench - times the Clarion particle loop vs the native C engine for the
!  heaviest preset (Lattice, 30,000 particles), to show why the Direct2D
!  backend is fast: the win is native compute, not the blit. Headless: writes
!  the result to bench.ini.
!  ============================================================================

  INCLUDE('EQUATES.CLW'),ONCE
  INCLUDE('YuruClass.INC'),ONCE

  MAP
    MODULE('yurucanvas.c')
yuru_native_frame   PROCEDURE(LONG,REAL,LONG,LONG,LONG,LONG,LONG),NAME('_yuru_native_frame')
    END
  END

CanW     EQUATE(400)
N        EQUATE(100)
Flow     YuruClass
i        LONG
t0       LONG
t1       LONG
claMs    REAL
natMs    REAL
msg      CSTRING(300)

Win      WINDOW('bench'),AT(,,200,100),CENTER,SYSTEM
           IMAGE(''),AT(0,0,160,160),USE(?Canvas)
         END

  CODE
  OPEN(Win)
  Flow.Init(?Canvas)
  Flow.Preset   = Yuru:Lattice
  Flow.InkColor = 00FFFFFFH
  Flow.tVal     = 8.0
  Flow.RecalcInc()

  t0 = CLOCK()                                                ! --- Clarion compute: fill + 30k-particle Lattice ---
  LOOP i = 1 TO N
    Flow.ClearBuf()
    Flow.Lattice()
  END
  claMs = (CLOCK() - t0) * 10.0 / N                           ! CLOCK() is centiseconds

  t0 = CLOCK()                                                ! --- native C compute: the same 30k Lattice ---
  LOOP i = 1 TO N
    yuru_native_frame(Yuru:Lattice, 8.0, 55, 55, 55, 9, CanW)
  END
  natMs = (CLOCK() - t0) * 10.0 / N

  msg = 'Lattice 30k particles, avg/' & N & ' frames -- Clarion ' & |
        CLIP(LEFT(FORMAT(claMs,@n7.2))) & ' ms  |  Native C ' & |
        CLIP(LEFT(FORMAT(natMs,@n7.2))) & ' ms  |  Speedup ' & |
        CLIP(LEFT(FORMAT(claMs/(natMs+0.001),@n7.1))) & 'x'
  PUTINI('bench','result',msg,'.\bench.ini')
  CLOSE(Win)
  RETURN
