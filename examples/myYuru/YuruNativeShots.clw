  PROGRAM
!  ============================================================================
!  YuruNativeShots - headless verification of the NATIVE C particle engine.
!  Renders every preset at the same clock (tVal=8.0) the Clarion YuruShots uses,
!  via yuru_native_frame(), and writes native_<preset>.bmp. Compare byte-for-byte
!  against the Clarion-rendered shot_<preset>.bmp to prove the C port matches.
!  ============================================================================

  INCLUDE('EQUATES.CLW'),ONCE

  PRAGMA('compile(yurucanvas.c)')

  MAP
    MODULE('yurucanvas.c')
yuru_native_frame   PROCEDURE(LONG,REAL,LONG,LONG,LONG,LONG,LONG),NAME('_yuru_native_frame')
yuru_native_copy24  PROCEDURE(*STRING,LONG),RAW,NAME('_yuru_native_copy24')
    END
  END

CanW     EQUATE(400)
NBytes   EQUATE(480000)
Buf      STRING(NBytes)
CurFile  STRING(261)
p        LONG
Names    STRING('ribbon  seashellnebula  lattice reeds   plume   ') ! 8 chars each

BmpOut   FILE,DRIVER('DOS'),NAME(CurFile),CREATE,PRE(BO),THREAD
Rec        RECORD
fType        USHORT
fSize        ULONG
fRes         ULONG
fOff         ULONG
iSize        ULONG
iWidth       LONG
iHeight      LONG
iPlanes      USHORT
iBitCt       USHORT
iComp        ULONG
iImgSz       ULONG
iXppm        LONG
iYppm        LONG
iClrU        ULONG
iClrI        ULONG
Bits         STRING(NBytes)
           END
         END

  CODE
  BO:fType=19778 ; BO:fSize=54+NBytes ; BO:fRes=0 ; BO:fOff=54
  BO:iSize=40 ; BO:iWidth=CanW ; BO:iHeight=CanW ; BO:iPlanes=1 ; BO:iBitCt=24
  BO:iComp=0 ; BO:iImgSz=NBytes ; BO:iXppm=2835 ; BO:iYppm=2835 ; BO:iClrU=0 ; BO:iClrI=0
  LOOP p = 1 TO 6
    yuru_native_frame(p, 8.0, 55, 55, 55, 9, CanW)             ! white ink glow 55, bg grey 9
    yuru_native_copy24(Buf, CanW)
    BO:Bits = Buf
    CurFile = 'native_' & CLIP(Names[(p-1)*8+1 : (p-1)*8+8]) & '.bmp'
    CREATE(BmpOut) ; OPEN(BmpOut, 22H)
    IF ~ERRORCODE() ; ADD(BmpOut) ; CLOSE(BmpOut) .
  END
  RETURN
