!Test QR Draw program written July 2026 by Carl T. Barnes based somewhat in the myQRDraw.TPL by Roberto Renz released under the MIT License
!The purpose of this program is to try out and test the features of QRCodeClass

!Remember that you can hold your phone camera up to the generated QR Code to verify it works.
!To test if Clipping to Image border is working in the .Paint() method set Cell += 2 so it is too big and would overrun the Image

    PROGRAM
    INCLUDE('TplEqu.CLW')
    INCLUDE('KeyCodes.CLW')
    INCLUDE('QRCodeClass.INC'),ONCE   
    MAP
QRTestWnd   PROCEDURE()
DB          PROCEDURE(STRING DebugMessage)
      MODULE('api')
        OutputDebugString(*CSTRING cMsg),PASCAL,DLL(1),RAW,NAME('OutputDebugStringA')
      END
    END

    CODE
    QRTestWnd()
    RETURN
!----------------------------
QRTestWnd  PROCEDURE()
QRCodeObj  QRCodeClass

cDrawValue      CSTRING(1024)
myQRDrawValue   STRING(255)   !#PROMPT('&Value:',@s255),%myQRDrawValue,DEFAULT('https://www.softvelocity.com')
myQRDrawEcc     BYTE(2)             !#PROMPT('&Error correction level:',DROP('L - Low (most data)[1]|M - Medium[2]|Q - Quartile[3]|H - High (most robust)[4]')),%myQRDrawEcc,DEFAULT('2')
!myQRDrawDark    LONG(COLOR:Black)  !#PROMPT('&Dark (foreground) color:',COLOR),%myQRDrawDark,DEFAULT(00000000H)
!myQRDrawLight   LONG(COLOR:White)  !#PROMPT('&Light (background) color:',COLOR),%myQRDrawLight,DEFAULT(00FFFFFFH)
myQRDrawDark    LONG(Color:Navy)    !#PROMPT('&Dark (foreground) color:',COLOR),%myQRDrawDark,DEFAULT(00000000H)
myQRDrawLight   LONG(COLOR:Sand)    !#PROMPT('&Light (background) color:',COLOR),%myQRDrawLight,DEFAULT(00FFFFFFH)
myQRDrawQuiet   LONG(2)             !#PROMPT('&Quiet-zone modules (border):',SPIN(@n1,0,8,1)),%myQRDrawQuiet,DEFAULT(4)

AutoDraw        BYTE(1)
QRImageSizeWH   LONG        !Allow user to Size Image so not Window Base
Wd              LONG
Ht              LONG 
PixelWH         LONG 
DrawInfo        STRING(40)  
CheckerBrdCB    BYTE        !Draw Checker Board instead of QR
CheckerBrdVer   BYTE(10)    !Version ranges 1-10 so W=17+4 to 17+40 
CheckerBrdCls   CLASS(QRCodeClass)
BuildMatrix         PROCEDURE(*CSTRING NotUsed_pValue,LONG pVersion_in_pEcc),BYTE,DERIVED    !Override to Build Checker Board
                END    
Window WINDOW('Test QR Draw Class by Reberto Renz'),AT(,,378,225),CENTER,GRAY,IMM,SYSTEM,ICON(ICON:Application), |
            FONT('Segoe UI',9),RESIZE
        PROMPT('QR &Value:'),AT(6,4),USE(?PROMPT1)
        TEXT,AT(42,4,,11),FULL,USE(myQRDrawValue),SINGLE
        PROMPT('Error Correction Level:'),AT(6,28,31,29),USE(?PROMPT2),CENTER
        LIST,AT(43,29,78,35),USE(myQRDrawEcc),FROM('L - Low (most data)|#1|M - Medium|#2|Q - Quartil' & |
                'e|#3|H - High (most robust)|#4'),FORMAT('20L(2)')
        PROMPT('Quiet-Zone Modules (border):'),AT(6,70),USE(?myQRDrawQuiet:Prompt)
        SPIN(@n1),AT(133,88,16,10),USE(myQRDrawQuiet),RANGE(0,8)
        SLIDER,AT(8,81,119),USE(myQRDrawQuiet,, ?myQRDrawQuiet:2),IMM,RANGE(0,8),STEP(1),ABOVE
        BUTTON('&Draw QR'),AT(5,106,52,17),USE(?QrButton1)
        CHECK('Auto'),AT(73,112),USE(AutoDraw),SKIP,TIP('Draw QR on every change')
        PROMPT('QR Size:'),AT(133,22,,7),USE(?GaugeImageSizeWH:Pmt)
        SPIN(@n3),AT(133,33,32,10),USE(QRImageSizeWH),HVSCROLL,TIP('Image Width and Height to place Gauge'), |
                RANGE(50,999),STEP(5)
        ENTRY(@n6),AT(133,46,32,10),USE(PixelWH),SKIP,FLAT,COLOR(COLOR:BTNFACE),TIP('Image Size in Pixels'), |
                READONLY
        STRING(@s40),AT(6,127,153),USE(DrawInfo)
        IMAGE,AT(170,20,200,200),USE(?QrDrawImage)
        BOX,AT(169,19,202,202),USE(?QRDrawBox),COLOR(COLOR:Gray),LINEWIDTH(1)
        BOX,AT(19,139,82,82),USE(?QrStaticBOX),LINEWIDTH(1)
        IMAGE,AT(20,140,80,80),USE(?QrStaticImage)
        STRING(' QR Static - Test BLANK'),AT(2,139,10,74),USE(?QrStaticFYI),ANGLE(900)
        BUTTON('Blank'),AT(133,140,26),USE(?BlankBtn),TIP('Test Blank()')
        LIST,AT(109,163,56,11),USE(myQRDrawLight),VSCROLL,TIP('Light Color i.e. Background'),DROP(9), |
                FROM('White|Sand|Runtime')
        LIST,AT(109,177,56,11),USE(myQRDrawDark),VSCROLL,TIP('Dark Color i.e. Boxes'),DROP(9), |
                FROM('Black|Navy|Runtime')
        CHECK('Checker Brd'),AT(109,198,,10),USE(CheckerBrdCB),TIP('Draw Checker Board instead of QR')
        SPIN(@n2),AT(109,211,27,10),USE(CheckerBrdVer),HVSCROLL,TIP('Checker Board Version from 1 to 10'), |
                RANGE(1,10)
    END

    CODE          
    myQRDrawValue = 'https://www.softvelocity.com'
    myQRDrawValue = 'https://www.ClarionLive.com'
    myQRDrawValue = 'https://www.clarionlive.com/resources/pre-youtube-webinar-archive'
    OPEN(WINDOW)
    0{PROP:text}=clip(0{PROP:text}) &' - Library ' & system{PROP:LibVersion,2} &'.'& system{PROP:LibVersion,3} &' - '& Command('0') 
    ?myQRDrawLight{PROP:From}='White|#' & COLOR:White &'|Sand|#'& COLOR:Sand & '|None|#-1' 
    myQRDrawLight=COLOR:Sand 
    ?myQRDrawDark{PROP:From}='Black|#' & COLOR:Black &'|Navy|#'& COLOR:Navy & '|None|#-1' 
    myQRDrawDark=COLOR:Navy    
    DO DrawStaticQrOnceRtn
    GETPOSITION(?QrDrawImage,,,Wd,Ht)
    QRImageSizeWH = CHOOSE(Wd<Ht,Wd,Ht)    
    ACCEPT
        CASE EVENT()
        OF EVENT:OpenWindow  ; IF AutoDraw THEN DO DrawQrRtn.
        OF EVENT:CloseWindow
        OF EVENT:PreAlertKey
        OF EVENT:AlertKey
        OF EVENT:Timer
        END
        CASE ACCEPTED()
        OF ?BlankBtn     ; BLANK() ; AutoDraw=0 ; DISPLAY ; CYCLE
        OF ?QrButton1    ; DO DrawQrRtn 
        END
        IF AutoDraw THEN
           CASE EVENT()
           OF EVENT:Accepted OROF EVENT:NewSelection ; DO DrawQrRtn
           END 
        END         
    END
    CLOSE(WINDOW)

DrawQrRtn ROUTINE
    Wd=QRImageSizeWH
    SETPOSITION(?QrDrawImage,,,Wd,Wd)       
    SETPOSITION(?QRDrawBox  ,,,Wd+2,Wd+2) 
    0{PROP:Pixels}=TRUE ; PixelWH=?QrDrawImage{PROP:Width} ; 0{PROP:Pixels}=False 
    IF CheckerBrdCB THEN DO CheckerBoardRtn ; EXIT.
    
    cDrawValue=CLIP(LEFT(myQRDrawValue))  
    !Draw  PROCEDURE(SIGNED pImageFeq,*CSTRING pValue,LONG pEcc,LONG pDark,LONG pLight,LONG pQuiet)
    IF ~QRCodeObj.Draw(?QrDrawImage, cDrawValue , myQRDrawEcc, myQRDrawDark, myQRDrawLight, myQRDrawQuiet) THEN 
        Message('The '& LEN(CLIP(cDrawValue)) &' byte value: "' & CLIP(cDrawValue) &'"'& |
                '|to be coded at the selected Error Correction Level '& myQRDrawEcc & |
                '|is too much to encode in the maximum 57x57 grid.' & |
                '||Please reduce Value, ECL or both','QR Draw',ICON:Asterisk)
    END 
    DO SetDrawInfoRtn 
    DISPLAY
    
SetDrawInfoRtn ROUTINE 
    DrawInfo=CHOOSE(myQRDrawEcc,'L','M','Q','H','?') & myQRDrawEcc & |
           ' v'&    QRCodeObj.Ver & |    !10 Versions decided by ???
           ' n'&    QRCodeObj.N & |        !Side current dimension (17+4*version)
           ' Side'& QRCodeObj.LastDraw.Side & |        !N + Border
           ' Cell'& QRCodeObj.LastDraw.Cell & |        !How many Blocks per Cell
           ''
    ?DrawInfo{PROP:Tip}='ECL '& CHOOSE(myQRDrawEcc,'L','M','Q','H','?') & myQRDrawEcc & |
           '<13,10> Ver='&  QRCodeObj.Ver &' Version 1 to 10 smallest that fits, 0=Failed ' & |
           '<13,10> N='&    QRCodeObj.N &' Side dimension (17+4*version) = 21 to 57 in 4 steps' & |
           '<13,10> Side='& QRCodeObj.LastDraw.Side &' Side with Border i.e. Quite='& myQRDrawQuiet & |
           '<13,10> Cell='& QRCodeObj.LastDraw.Cell &' Cell Width in Pixels (Units)' & |
           '<13,10> QPix='& QRCodeObj.LastDraw.QPix &' Cell * Side' & |
           '<13,10> Img='&  QRCodeObj.LastDraw.ImgXYWH &' (x,y,w,h)' & |
           '<13,10> OffsetXY='&  QRCodeObj.LastDraw.OffsetXY &' Offset adjust to Center' & |
           '<13,10> Prop:Pixels='& 0{PROP:Pixels} & |    !See if Left on at the end       
           ''
    EXIT
!------------------------
CheckerBoardRtn ROUTINE
    DATA
N     LONG    
ChkValue    CSTRING('Checker Board')   
ChkECC      LONG 
    CODE
    ChkECC = CheckerBrdVer      !The Version is passed in Ecc 
    IF ~CheckerBrdCls.Draw(?QrDrawImage, ChkValue , ChkECC, myQRDrawDark, myQRDrawLight, myQRDrawQuiet) THEN 
        N = CheckerBrdVer * 4 + 17
        Message('The Checkboard Version '& CheckerBrdVer &' with Dims '& N &' x' & N & |
                '|is too much to encode in the maximum 57x57 grid.' & |
                '||This should never happen','QR CheckerBoardRtn',ICON:Asterisk)                        
    END        
    DO SetDrawInfoRtn 
    DrawInfo='ChkBrd ' & DrawInfo
    EXIT
!------------------------
DrawStaticQrOnceRtn ROUTINE     !Place a 2nd QR on Window to be sure does not get Blanked by draing main QR
    GETPOSITION(?QrStaticImage,,,Wd,Ht) 
    Wd = CHOOSE(Wd<Ht,Wd,Ht) 
    SETPOSITION(?QrStaticImage,,,Wd,Wd)         !Be sure Square
    cDrawValue=CLIP(LEFT(myQRDrawValue))
    QRCodeObj.Draw(?QrStaticImage, cDrawValue , 4, myQRDrawDark, myQRDrawLight, 1)  
    DISPLAY
    EXIT
!===============================
CheckerBrdCls.BuildMatrix PROCEDURE(*CSTRING NotUsed_pValue,LONG pVersion_in_pEcc) !,BOOL,DERIVED  !Override to Build Checker Board
N     LONG                !This Class could be included
r     LONG    
c     LONG 
OnOff SHORT    
    CODE
    IF ~INRANGE(pVersion_in_pEcc,1,10) THEN Message('pVersion_in_pEcc='& pVersion_in_pEcc ).
    IF pVersion_in_pEcc < 1  THEN pVersion_in_pEcc=1.
    IF pVersion_in_pEcc > 10 THEN pVersion_in_pEcc=10.
    N = pVersion_in_pEcc * 4 + 17
    SELF.Ver = pVersion_in_pEcc 
    SELF.N = N
    CLEAR(SELF.Cells[])
    LOOP r = 0 TO n-1
      OnOff = BAND(r+1,1)       !Even Rows Start ON, Odd Rows OFF
      LOOP c = 0 TO n-1
           SELF.Cells[r+1,c+1] = OnOff
           OnOff = 1 - OnOff
      END
   END
   RETURN TRUE
!===============================
DB   PROCEDURE(STRING xMessage)
Prfx EQUATE('Scratch: ')
sz   CSTRING(SIZE(Prfx)+SIZE(xMessage)+1),AUTO
  CODE 
  sz  = Prfx & CLIP(xMessage)
  OutputDebugString( sz )