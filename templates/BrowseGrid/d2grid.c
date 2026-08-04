/* ============================================================================
 *  d2grid.c - a grid drawn with Direct2D and DirectWrite, for Clarion.
 *
 *  WHY. Clarion's LIST is drawn by the runtime and looks it. This draws every
 *  pixel itself into an ordinary Clarion REGION - which owns a real HWND, like
 *  every Clarion control - so a browse can have banded rows, frozen columns,
 *  a proper header, smooth scrolling and any colour scheme you like, without
 *  giving up ABC's BrowseClass underneath.
 *
 *  WHAT IT DOES NOT DO. It holds no data. Clarion pushes the VISIBLE rows in
 *  before each paint - which is exactly what an ABC browse queue already
 *  contains - and the grid draws them. Scrolling posts an event back so the
 *  Clarion side can fetch the next page from the VIEW. The grid never owns the
 *  file, the sort order or the filter; BrowseClass keeps all of that.
 *
 *  BOUND AT RUN TIME. d2d1.dll and dwrite.dll are loaded with LoadLibrary, so
 *  there is no import library to link (Clarion cannot link MSVC COFF libs) and
 *  nothing to ship. Both have been part of Windows since 7.
 *
 *  COM WITHOUT A HEADER. Clacpp has no Windows SDK, so the interfaces are
 *  hand-declared. Every vtable index below was read out of the SDK's own
 *  d2d1.h / dwrite.h by walking each interface's declaration order, base class
 *  first - not remembered. They are named once, here, and nowhere else:
 *
 *    ID2D1Factory            2 Release  14 CreateHwndRenderTarget
 *    ID2D1HwndRenderTarget   2 Release   8 CreateSolidColorBrush
 *                           15 DrawLine 17 FillRectangle  27 DrawText
 *                           30 SetTransform 45 PushAxisAlignedClip
 *                           46 PopAxisAlignedClip 47 Clear 48 BeginDraw
 *                           49 EndDraw 58 Resize
 *    ID2D1SolidColorBrush    2 Release   8 SetColor
 *    IDWriteFactory          2 Release  15 CreateTextFormat
 *
 *  ABI notes:
 *    - 32-bit, stdcall (Clacpp spells it `pascal`).
 *    - D2D1_POINT_2F goes to DrawLine BY VALUE. Two floats on the stack is
 *      byte-identical to the struct, so they are declared as separate floats.
 *    - DrawText wants UTF-16. Clarion hands over ANSI, converted here.
 * ========================================================================== */

#define WINAPI pascal
typedef unsigned long  DWORD;
typedef unsigned int   UINT;
typedef int            BOOL;
typedef unsigned char  BYTE;
typedef unsigned short WCHAR;
typedef void*          HMODULE;
typedef void*          HWND;
typedef long           HRESULT;
typedef int (WINAPI *FARPROC)();
typedef long (WINAPI *WNDPROC)(HWND, UINT, UINT, long);

typedef struct { unsigned long Data1; unsigned short Data2; unsigned short Data3;
                 unsigned char Data4[8]; } GUID;
typedef struct { long left, top, right, bottom; } RECT;

#define LPTR         0x0040
#define CP_ACP       0
#define GWL_WNDPROC  (-4)
#define WM_PAINT      0x000F
#define WM_ERASEBKGND 0x0014

extern "C" {

HMODULE WINAPI LoadLibraryA(const char*);
FARPROC WINAPI GetProcAddress(HMODULE, const char*);
void*   WINAPI LocalAlloc(UINT, unsigned long);
void*   WINAPI LocalFree(void*);
long    WINAPI SetWindowLongA(HWND, int, long);
long    WINAPI GetWindowLongA(HWND, int);
long    WINAPI CallWindowProcA(WNDPROC, HWND, UINT, UINT, long);
long    WINAPI DefWindowProcA(HWND, UINT, UINT, long);
BOOL    WINAPI InvalidateRect(HWND, const RECT*, BOOL);
BOOL    WINAPI GetClientRect(HWND, RECT*);
void*   WINAPI BeginPaint(HWND, void*);
BOOL    WINAPI EndPaint(HWND, const void*);
BOOL    WINAPI IsWindow(HWND);
int     WINAPI MultiByteToWideChar(UINT, DWORD, const char*, int, WCHAR*, int);

/* ---- Direct2D / DirectWrite types, exactly as the SDK lays them out ------ */
typedef struct { unsigned int w, h; }                SIZEU;
typedef struct { float l, t, r, b; }                 RECTF;
typedef struct { float r, g, b, a; }                 COLORF;
typedef struct { int format; int alphaMode; }        PIXFMT;
typedef struct { int type; PIXFMT pf; float dpiX, dpiY;
                 int usage; int minLevel; }          RTPROPS;
typedef struct { HWND hwnd; SIZEU size; int present; } HRTPROPS;

#define DXGI_B8G8R8A8_UNORM  87
#define ALPHA_IGNORE          3
#define FACTORY_SINGLE        0
#define DW_FACTORY_SHARED     0
#define FONT_NORMAL         400
#define FONT_BOLD           700
#define STYLE_NORMAL          0
#define STRETCH_NORMAL        5
#define AA_ALIASED            1     /* D2D1_ANTIALIAS_MODE_ALIASED */
/* IDWriteTextFormat, which inherits straight from IUnknown:
     3 SetTextAlignment   4 SetParagraphAlignment   5 SetWordWrapping        */
#define DW_LEADING            0     /* left   */
#define DW_TRAILING           1     /* right  */
#define DW_CENTER             2
#define DW_PARA_CENTER        2     /* centred down the row, not hugging the top */
#define DW_NO_WRAP            1     /* a cell is one line; clip, never wrap      */

#define VT(o) (*(void***)(o))

typedef HRESULT (WINAPI *PFN_D2D1CreateFactory)(int, const GUID*, const void*, void**);
typedef HRESULT (WINAPI *PFN_DWriteCreateFactory)(int, const GUID*, void**);

#define G_MAX      8            /* grids at once                              */
#define G_COLS    32            /* columns                                    */
#define G_VIS    128            /* visible rows the Clarion side pushes in     */
#define G_TEXT    64            /* characters per cell                        */

typedef struct {
    int   used;
    HWND  hwnd;
    void* rt;                   /* ID2D1HwndRenderTarget */
    void* fmt;                  /* IDWriteTextFormat - the body font   */
    void* fmtHdr;               /* ... and the header font             */
    void* brush;                /* one brush, recoloured as it goes    */
    WNDPROC oldProc;

    int   cols;
    int   colW[G_COLS];
    int   colAlign[G_COLS];     /* 0 left 1 right 2 centre */
    char  colTitle[G_COLS][G_TEXT];
    int   frozen;               /* how many columns stay put while scrolling  */

    int   rtW, rtH;             /* what the render target is currently sized to */
    int   rowH, hdrH;
    int   visRows;              /* rows the Clarion side has pushed in        */
    int   firstRow;             /* which record visRow 0 is                   */
    int   totalRows;
    int   selRow;               /* selected, in absolute row numbers          */
    int   scrollX;
    int   scrollY;              /* pixels the page is nudged UP by; 0..rowH-1
                                   is a part-row at the top, which is what
                                   makes scrolling smooth rather than jumpy   */
    char  cell[G_VIS][G_COLS][G_TEXT];

    unsigned int cBack, cBand, cGrid, cText, cHdrBack, cHdrText, cSelBack, cSelText;

    /* our own vertical scrollbar. Windows' one cannot be made to track: it
       drags inside a message loop of its own, and moving the browse needs
       records, which needs Clarion's ACCEPT, which that loop is holding up.
       Drawn here it is just pixels, and dragging it is an ordinary mouse
       event like any other. */
    int   vBar;                 /* drawn at all?                            */
    int   vPos;                 /* 0..100, the browse's own scale           */
    int   vPct;                 /* how much of the trough the thumb takes   */

    char  face[64];             /* kept so the font can be rebuilt bigger   */
    int   pt;
} Grid;

#define D2G_BARW 15

static Grid  g_g[G_MAX + 1];
static void* g_d2d = 0;
static void* g_dw  = 0;
static int   g_tried = 0;

static long WINAPI d2g_WndProc(HWND h, UINT msg, UINT wp, long lp);

/* How tall a row and a heading are for a given point size. Leading has to grow
   WITH the type, not sit at a fixed number of pixels above it: pt + 10 is
   roomy at 9 point and cramped at 24, where the descenders start being cut off
   by the row below. Three halves and a bit keeps the same look all the way up,
   and lands on the same numbers as the old rule at the default size, so
   nothing moves for anyone who never touches it. */
#define D2G_ROWFOR(pt) ((pt) * 3 / 2 + 6)
#define D2G_HDRFOR(pt) ((pt) * 3 / 2 + 8)
static void d2g_VGeom(Grid* c, int* top, int* len, int* tTop, int* tLen);

/* ---- the two factories --------------------------------------------------- */
static int d2g_Factories(void) {
    HMODULE d2dDll, dwDll;
    PFN_D2D1CreateFactory   mkD2D;
    PFN_DWriteCreateFactory mkDW;
    GUID iid;

    if (g_d2d && g_dw) return 1;
    if (g_tried) return 0;
    g_tried = 1;

    d2dDll = LoadLibraryA("d2d1.dll");
    dwDll  = LoadLibraryA("dwrite.dll");
    if (!d2dDll || !dwDll) return 0;
    mkD2D = (PFN_D2D1CreateFactory)GetProcAddress(d2dDll, "D2D1CreateFactory");
    mkDW  = (PFN_DWriteCreateFactory)GetProcAddress(dwDll, "DWriteCreateFactory");
    if (!mkD2D || !mkDW) return 0;

    /* IID_ID2D1Factory {06152247-6f50-465a-9245-118bfd3b6007} */
    iid.Data1 = 0x06152247; iid.Data2 = 0x6f50; iid.Data3 = 0x465a;
    iid.Data4[0]=0x92; iid.Data4[1]=0x45; iid.Data4[2]=0x11; iid.Data4[3]=0x8b;
    iid.Data4[4]=0xfd; iid.Data4[5]=0x3b; iid.Data4[6]=0x60; iid.Data4[7]=0x07;
    if (mkD2D(FACTORY_SINGLE, &iid, 0, &g_d2d) < 0) { g_d2d = 0; return 0; }

    /* IID_IDWriteFactory {b859ee5a-d838-4b5b-a2e8-1adc7d93db48} */
    iid.Data1 = 0xb859ee5a; iid.Data2 = 0xd838; iid.Data3 = 0x4b5b;
    iid.Data4[0]=0xa2; iid.Data4[1]=0xe8; iid.Data4[2]=0x1a; iid.Data4[3]=0xdc;
    iid.Data4[4]=0x7d; iid.Data4[5]=0x93; iid.Data4[6]=0xdb; iid.Data4[7]=0x48;
    if (mkDW(DW_FACTORY_SHARED, &iid, &g_dw) < 0) { g_dw = 0; return 0; }
    return 1;
}

static Grid* slot(int h) {
    if (h < 1 || h > G_MAX || !g_g[h].used) return 0;
    return &g_g[h];
}

static void wide(const char* src, WCHAR* dst, int cap) {
    int n = MultiByteToWideChar(CP_ACP, 0, src, -1, dst, cap);
    if (n <= 0) dst[0] = 0;
}

/* one text format (a font) */
static void* d2g_Font(const char* face, float size, int bold) {
    WCHAR wf[64], wl[8];
    void* fmt = 0;
    if (!g_dw) return 0;
    wide(face, wf, 64);
    wl[0] = 'e'; wl[1] = 'n'; wl[2] = '-'; wl[3] = 'u'; wl[4] = 's'; wl[5] = 0;
    /* IDWriteFactory::CreateTextFormat - slot 15 */
    if (((HRESULT (WINAPI*)(void*, const WCHAR*, void*, int, int, int, float,
                            const WCHAR*, void**))VT(g_dw)[15])
        (g_dw, wf, 0, bold ? FONT_BOLD : FONT_NORMAL, STYLE_NORMAL,
         STRETCH_NORMAL, size, wl, &fmt) < 0) return 0;
    /* down the middle of the row, and one line only */
    ((HRESULT (WINAPI*)(void*, int))VT(fmt)[4])(fmt, DW_PARA_CENTER);
    ((HRESULT (WINAPI*)(void*, int))VT(fmt)[5])(fmt, DW_NO_WRAP);
    return fmt;
}

static int d2g_MakeTarget(Grid* c) {
    RTPROPS  rp;
    HRTPROPS hp;
    RECT     r;
    COLORF   col;

    if (!d2g_Factories() || !c->hwnd || !IsWindow(c->hwnd)) return 0;
    if (c->rt) return 1;
    GetClientRect(c->hwnd, &r);
    if (r.right - r.left < 1 || r.bottom - r.top < 1) return 0;

    rp.type = 0; rp.pf.format = DXGI_B8G8R8A8_UNORM; rp.pf.alphaMode = ALPHA_IGNORE;
    rp.dpiX = 96.0f; rp.dpiY = 96.0f; rp.usage = 0; rp.minLevel = 0;
    hp.hwnd = c->hwnd;
    hp.size.w = (unsigned)(r.right - r.left);
    hp.size.h = (unsigned)(r.bottom - r.top);
    hp.present = 0;
    if (((HRESULT (WINAPI*)(void*, const RTPROPS*, const HRTPROPS*, void**))
         VT(g_d2d)[14])(g_d2d, &rp, &hp, &c->rt) < 0) { c->rt = 0; return 0; }
    c->rtW = r.right - r.left;                     /* what it was built at */
    c->rtH = r.bottom - r.top;

    col.r = col.g = col.b = 0.0f; col.a = 1.0f;
    /* ID2D1RenderTarget::CreateSolidColorBrush - slot 8 */
    ((HRESULT (WINAPI*)(void*, const COLORF*, const void*, void**))
     VT(c->rt)[8])(c->rt, &col, 0, &c->brush);
    return c->brush ? 1 : 0;
}

static void setColour(Grid* c, unsigned int rgb) {
    COLORF col;
    col.r = (float)((rgb >> 16) & 0xFF) / 255.0f;
    col.g = (float)((rgb >>  8) & 0xFF) / 255.0f;
    col.b = (float)( rgb        & 0xFF) / 255.0f;
    col.a = 1.0f;
    ((void (WINAPI*)(void*, const COLORF*))VT(c->brush)[8])(c->brush, &col);  /* SetColor */
}

static void fillRect(Grid* c, float l, float t, float r, float b, unsigned int rgb) {
    RECTF rc;
    rc.l = l; rc.t = t; rc.r = r; rc.b = b;
    setColour(c, rgb);
    ((void (WINAPI*)(void*, const RECTF*, void*))VT(c->rt)[17])(c->rt, &rc, c->brush);
}

static void line(Grid* c, float x1, float y1, float x2, float y2, unsigned int rgb) {
    setColour(c, rgb);
    /* DrawLine - slot 15. Two POINT_2F by value = four floats on the stack. */
    ((void (WINAPI*)(void*, float, float, float, float, void*, float, void*))
     VT(c->rt)[15])(c->rt, x1, y1, x2, y2, c->brush, 1.0f, 0);
}

static void text(Grid* c, const char* s, float l, float t, float r, float b,
                 unsigned int rgb, int align, void* fmt) {
    WCHAR w[G_TEXT * 2];
    RECTF rc;
    int   n = 0;
    if (!s || !s[0]) return;
    wide(s, w, G_TEXT * 2);
    while (w[n]) n++;
    if (!n) return;
    /* the caller has already reserved the padding it wants */
    rc.l = l; rc.t = t; rc.r = r; rc.b = b;
    setColour(c, rgb);
    /* IDWriteTextFormat::SetTextAlignment - slot 3. Set it per cell rather
       than keeping six formats about; it is a field assignment, not work. */
    ((HRESULT (WINAPI*)(void*, int))VT(fmt)[3])(fmt,
        align == 1 ? DW_TRAILING : (align == 2 ? DW_CENTER : DW_LEADING));
    ((void (WINAPI*)(void*, const WCHAR*, unsigned, void*, const RECTF*, void*, int, int))
     VT(c->rt)[27])(c->rt, w, (unsigned)n, fmt, &rc, c->brush, 0, 0);
}

/* ---- the paint -----------------------------------------------------------
   Frozen columns are drawn LAST, on top, and the scrolling ones are clipped to
   the right of them. Drawn in plain left-to-right order the scrolling columns
   come after the frozen ones and paint straight over them, which is exactly
   what you see if you freeze two columns and scroll: the third slides over the
   first two instead of under them.                                          */
static void d2g_Draw(Grid* c) {
    RECT  r;
    RECTF clip;
    int   i, col, x, fx, rowsDrawn, absRow, frozenW, barW;
    float top, bot, cl, cr;

    if (!c->rt && !d2g_MakeTarget(c)) return;
    GetClientRect(c->hwnd, &r);
    barW = c->vBar ? D2G_BARW : 0;
    r.right -= barW;                       /* the columns stop at the scrollbar */

    frozenW = 0;
    for (col = 0; col < c->frozen && col < c->cols; col++) frozenW += c->colW[col];

    ((void (WINAPI*)(void*))VT(c->rt)[48])(c->rt);                     /* BeginDraw */
    {
        COLORF bg;
        bg.r = (float)((c->cBack >> 16) & 0xFF) / 255.0f;
        bg.g = (float)((c->cBack >>  8) & 0xFF) / 255.0f;
        bg.b = (float)( c->cBack        & 0xFF) / 255.0f;
        bg.a = 1.0f;
        ((void (WINAPI*)(void*, const COLORF*))VT(c->rt)[47])(c->rt, &bg);   /* Clear */
    }

    /* everything below the header is clipped, so a part-row at the top cannot
       paint over the titles - that is what makes pixel scrolling possible */
    clip.l = 0.0f; clip.t = (float)c->hdrH;
    clip.r = (float)r.right; clip.b = (float)r.bottom;
    ((void (WINAPI*)(void*, const RECTF*, int))VT(c->rt)[45])(c->rt, &clip, AA_ALIASED);

    rowsDrawn = c->visRows;
    for (i = 0; i < rowsDrawn; i++) {
        unsigned int back, fore;
        top = (float)(c->hdrH + i * c->rowH - c->scrollY);
        bot = top + c->rowH;
        if (bot < (float)c->hdrH) continue;
        if (top > (float)r.bottom) break;
        absRow = c->firstRow + i;
        if (absRow == c->selRow)      { back = c->cSelBack; fore = c->cSelText; }
        else if (i & 1)               { back = c->cBand;    fore = c->cText;    }
        else                          { back = c->cBack;    fore = c->cText;    }
        fillRect(c, 0.0f, top, (float)r.right, bot, back);

        /* --- the scrolling columns, kept off the frozen strip -------------- */
        clip.l = (float)frozenW; clip.t = top;
        clip.r = (float)r.right; clip.b = bot;
        ((void (WINAPI*)(void*, const RECTF*, int))VT(c->rt)[45])(c->rt, &clip, AA_ALIASED);
        x = -c->scrollX;
        for (col = 0; col < c->cols; col++) {
            cl = (float)x;
            cr = cl + c->colW[col];
            if (col >= c->frozen && cr > (float)frozenW && cl < (float)r.right)
                text(c, c->cell[i][col], cl + 4.0f, top + 1.0f, cr - 4.0f, bot,
                     fore, c->colAlign[col], c->fmt);
            x += c->colW[col];
        }
        ((void (WINAPI*)(void*))VT(c->rt)[46])(c->rt);

        /* --- then the frozen ones, on top of them ------------------------- */
        if (c->frozen > 0) {
            fillRect(c, 0.0f, top, (float)frozenW, bot, back);         /* wipe what slid under */
            clip.l = 0.0f; clip.t = top; clip.r = (float)frozenW; clip.b = bot;
            ((void (WINAPI*)(void*, const RECTF*, int))VT(c->rt)[45])(c->rt, &clip, AA_ALIASED);
            fx = 0;
            for (col = 0; col < c->frozen && col < c->cols; col++) {
                text(c, c->cell[i][col], (float)fx + 4.0f, top + 1.0f,
                     (float)(fx + c->colW[col]) - 4.0f, bot, fore, c->colAlign[col], c->fmt);
                fx += c->colW[col];
            }
            ((void (WINAPI*)(void*))VT(c->rt)[46])(c->rt);
        }
        line(c, 0.0f, bot - 0.5f, (float)r.right, bot - 0.5f, c->cGrid);
    }
    ((void (WINAPI*)(void*))VT(c->rt)[46])(c->rt);                     /* done with the rows */

    /* ---- the column lines, scrolling ones clipped the same way ---------- */
    clip.l = (float)frozenW; clip.t = 0.0f;
    clip.r = (float)r.right; clip.b = (float)r.bottom;
    ((void (WINAPI*)(void*, const RECTF*, int))VT(c->rt)[45])(c->rt, &clip, AA_ALIASED);
    x = -c->scrollX;
    for (col = 0; col < c->cols; col++) {
        x += c->colW[col];
        if (col >= c->frozen && (float)x > (float)frozenW && (float)x < (float)r.right)
            line(c, (float)x - 0.5f, 0.0f, (float)x - 0.5f, (float)r.bottom, c->cGrid);
    }
    ((void (WINAPI*)(void*))VT(c->rt)[46])(c->rt);

    /* ---- the header, over the rows -------------------------------------- */
    fillRect(c, 0.0f, 0.0f, (float)r.right, (float)c->hdrH, c->cHdrBack);
    clip.l = (float)frozenW; clip.t = 0.0f;
    clip.r = (float)r.right; clip.b = (float)c->hdrH;
    ((void (WINAPI*)(void*, const RECTF*, int))VT(c->rt)[45])(c->rt, &clip, AA_ALIASED);
    x = -c->scrollX;
    for (col = 0; col < c->cols; col++) {
        cl = (float)x;
        cr = cl + c->colW[col];
        if (col >= c->frozen && cr > (float)frozenW && cl < (float)r.right) {
            text(c, c->colTitle[col], cl + 4.0f, 2.0f, cr - 4.0f, (float)c->hdrH,
                 c->cHdrText, c->colAlign[col], c->fmtHdr);
            line(c, cr - 0.5f, 0.0f, cr - 0.5f, (float)c->hdrH, c->cGrid);
        }
        x += c->colW[col];
    }
    ((void (WINAPI*)(void*))VT(c->rt)[46])(c->rt);

    if (c->frozen > 0) {                                    /* frozen headings on top */
        fillRect(c, 0.0f, 0.0f, (float)frozenW, (float)c->hdrH, c->cHdrBack);
        clip.l = 0.0f; clip.t = 0.0f; clip.r = (float)frozenW; clip.b = (float)c->hdrH;
        ((void (WINAPI*)(void*, const RECTF*, int))VT(c->rt)[45])(c->rt, &clip, AA_ALIASED);
        fx = 0;
        for (col = 0; col < c->frozen && col < c->cols; col++) {
            text(c, c->colTitle[col], (float)fx + 4.0f, 2.0f,
                 (float)(fx + c->colW[col]) - 4.0f, (float)c->hdrH,
                 c->cHdrText, c->colAlign[col], c->fmtHdr);
            fx += c->colW[col];
            line(c, (float)fx - 0.5f, 0.0f, (float)fx - 0.5f, (float)c->hdrH, c->cGrid);
        }
        ((void (WINAPI*)(void*))VT(c->rt)[46])(c->rt);
        /* the edge of the frozen block, so it reads as a seam */
        line(c, (float)frozenW - 0.5f, 0.0f, (float)frozenW - 0.5f, (float)r.bottom, c->cGrid);
    }
    line(c, 0.0f, (float)c->hdrH - 0.5f, (float)r.right, (float)c->hdrH - 0.5f, c->cGrid);

    /* ---- our own vertical scrollbar, drawn last ------------------------- */
    if (barW) {
        int top, len, tTop, tLen;
        float bl = (float)r.right, br = (float)(r.right + barW);
        d2g_VGeom(c, &top, &len, &tTop, &tLen);
        fillRect(c, bl, 0.0f, br, (float)(r.bottom), c->cBand);        /* the trough */
        line(c, bl + 0.5f, 0.0f, bl + 0.5f, (float)r.bottom, c->cGrid);
        fillRect(c, bl + 3.0f, (float)tTop + 2.0f,
                    br - 3.0f, (float)(tTop + tLen) - 2.0f, c->cHdrBack);  /* the thumb */
    }

    if (((HRESULT (WINAPI*)(void*, void*, void*))VT(c->rt)[49])(c->rt, 0, 0) < 0) {
        if (c->brush) { ((unsigned long (WINAPI*)(void*))VT(c->brush)[2])(c->brush); c->brush = 0; }
        if (c->rt)    { ((unsigned long (WINAPI*)(void*))VT(c->rt)[2])(c->rt);       c->rt = 0; }
        InvalidateRect(c->hwnd, 0, 0);
    }
}

static long WINAPI d2g_WndProc(HWND h, UINT msg, UINT wp, long lp) {
    int i;
    Grid* c = 0;
    char ps[128];
    for (i = 1; i <= G_MAX; i++) if (g_g[i].used && g_g[i].hwnd == h) { c = &g_g[i]; break; }
    if (!c) return DefWindowProcA(h, msg, wp, lp);
    if (msg == WM_PAINT)      { BeginPaint(h, ps); d2g_Draw(c); EndPaint(h, ps); return 0; }
    if (msg == WM_ERASEBKGND) return 1;
    return CallWindowProcA(c->oldProc, h, msg, wp, lp);
}

/* ========================================================================== */
/*  What Clarion calls                                                        */
/* ========================================================================== */

int d2g_Available(void) { return d2g_Factories() ? 1 : 0; }

int d2g_Attach(void* hwnd, const char* face, int pt) {
    int i;
    Grid* c;
    if (!hwnd || !IsWindow((HWND)hwnd) || !d2g_Factories()) return 0;
    for (i = 1; i <= G_MAX; i++) if (!g_g[i].used) break;
    if (i > G_MAX) return 0;
    c = &g_g[i];
    c->used = 1; c->hwnd = (HWND)hwnd; c->rt = 0; c->brush = 0;
    c->cols = 0; c->frozen = 0; c->visRows = 0; c->firstRow = 0;
    c->totalRows = 0; c->selRow = -1; c->scrollX = 0;
    c->rowH = D2G_ROWFOR(pt); c->hdrH = D2G_HDRFOR(pt);
    c->cBack = 0xFFFFFF; c->cBand = 0xF5F7FA; c->cGrid = 0xE1E5EA;
    c->cText = 0x1F2933; c->cHdrBack = 0x2B3A4A; c->cHdrText = 0xFFFFFF;
    c->cSelBack = 0x2F6FB5; c->cSelText = 0xFFFFFF;
    if (!d2g_MakeTarget(c)) { c->used = 0; return 0; }
    c->fmt    = d2g_Font(face, (float)pt, 0);
    c->fmtHdr = d2g_Font(face, (float)pt, 1);
    if (!c->fmt || !c->fmtHdr) { c->used = 0; return 0; }
    { int k; for (k = 0; k < 63 && face[k]; k++) c->face[k] = face[k]; c->face[k] = 0; }
    c->pt = pt;
    c->oldProc = (WNDPROC)GetWindowLongA((HWND)hwnd, GWL_WNDPROC);
    SetWindowLongA((HWND)hwnd, GWL_WNDPROC, (long)d2g_WndProc);
    return i;
}

void d2g_Detach(int h) {
    Grid* c = slot(h);
    if (!c) return;
    if (c->oldProc && IsWindow(c->hwnd))
        SetWindowLongA(c->hwnd, GWL_WNDPROC, (long)c->oldProc);
    if (c->brush)  ((unsigned long (WINAPI*)(void*))VT(c->brush)[2])(c->brush);
    if (c->fmt)    ((unsigned long (WINAPI*)(void*))VT(c->fmt)[2])(c->fmt);
    if (c->fmtHdr) ((unsigned long (WINAPI*)(void*))VT(c->fmtHdr)[2])(c->fmtHdr);
    if (c->rt)     ((unsigned long (WINAPI*)(void*))VT(c->rt)[2])(c->rt);
    c->used = 0; c->hwnd = 0; c->rt = 0; c->brush = 0;
}

/* ---- shape ---------------------------------------------------------------- */
void d2g_Columns(int h, int n) {
    Grid* c = slot(h);
    if (!c) return;
    if (n < 0) n = 0;
    if (n > G_COLS) n = G_COLS;
    c->cols = n;
}

void d2g_Column(int h, int col, int width, int align, const char* title) {
    Grid* c = slot(h);
    int i;
    if (!c || col < 0 || col >= G_COLS) return;
    c->colW[col] = width < 8 ? 8 : width;
    c->colAlign[col] = align;
    for (i = 0; i < G_TEXT - 1 && title && title[i]; i++) c->colTitle[col][i] = title[i];
    c->colTitle[col][i] = 0;
}

void d2g_Frozen(int h, int n)      { Grid* c = slot(h); if (c) c->frozen = n; }
/* A row can never be shorter than the type needs. Whatever asks - the LIST's
   line height, the developer's own setting - it is clamped here, because the
   alternative is big type crammed into short rows with its descenders cut off
   by the row below, and there are several paths that can ask. One place, once,
   instead of trusting all of them to have thought about it. */
void d2g_RowHeight(int h, int px) {
    Grid* c = slot(h);
    int   need;
    if (!c || px <= 4) return;
    need = D2G_ROWFOR(c->pt);
    c->rowH = px < need ? need : px;
}

/* what the type needs, so the Clarion side can keep the LIST in step */
int d2g_RowNeed(int h) { Grid* c = slot(h); return c ? D2G_ROWFOR(c->pt) : 0; }
void d2g_HeaderHeight(int h,int px){
    Grid* c = slot(h);
    int   need;
    if (!c || px < 0) return;
    need = D2G_HDRFOR(c->pt);
    c->hdrH = (px && px < need) ? need : px;   /* 0 means no heading at all */
}
void d2g_Total(int h, int n)       { Grid* c = slot(h); if (c) c->totalRows = n; }
void d2g_Select(int h, int row)    { Grid* c = slot(h); if (c) c->selRow = row; }
void d2g_ScrollX(int h, int x)     { Grid* c = slot(h); if (c) c->scrollX = x < 0 ? 0 : x; }
void d2g_ScrollY(int h, int y)     { Grid* c = slot(h); if (c) c->scrollY = y < 0 ? 0 : y; }
int  d2g_RowH(int h)               { Grid* c = slot(h); return c ? c->rowH : 0; }
int  d2g_HeaderH(int h)            { Grid* c = slot(h); return c ? c->hdrH : 0; }

void d2g_Colours(int h, unsigned int back, unsigned int band, unsigned int grid,
                 unsigned int txt, unsigned int hdrBack, unsigned int hdrText,
                 unsigned int selBack, unsigned int selText) {
    Grid* c = slot(h);
    if (!c) return;
    c->cBack = back; c->cBand = band; c->cGrid = grid; c->cText = txt;
    c->cHdrBack = hdrBack; c->cHdrText = hdrText;
    c->cSelBack = selBack; c->cSelText = selText;
}

/* ---- the page of rows Clarion pushes in ---------------------------------- */
void d2g_Page(int h, int firstRow, int rows) {
    Grid* c = slot(h);
    if (!c) return;
    if (rows < 0) rows = 0;
    if (rows > G_VIS) rows = G_VIS;
    c->firstRow = firstRow;
    c->visRows  = rows;
}

void d2g_Cell(int h, int visRow, int col, const char* s) {
    Grid* c = slot(h);
    int i;
    if (!c || visRow < 0 || visRow >= G_VIS || col < 0 || col >= G_COLS) return;
    for (i = 0; i < G_TEXT - 1 && s && s[i]; i++) c->cell[visRow][col][i] = s[i];
    c->cell[visRow][col][i] = 0;
}

void d2g_Repaint(int h) { Grid* c = slot(h); if (c) InvalidateRect(c->hwnd, 0, 0); }

int d2g_PaintNow(int h) { Grid* c = slot(h); if (!c) return 0; d2g_Draw(c); return 1; }

/* Cheap enough to call whenever anything MIGHT have changed the client area -
   it does nothing at all unless it actually did. That matters because a
   scrollbar appearing or disappearing resizes the client area behind your
   back: hide the horizontal bar and the client grows by its height, and the
   strip it vacated is not covered by the render target until this has run. */
int d2g_Resize(int h) {
    Grid* c = slot(h);
    RECT  r;
    SIZEU s;
    if (!c) return 0;
    if (!c->rt && !d2g_MakeTarget(c)) return 0;
    GetClientRect(c->hwnd, &r);
    s.w = (unsigned)(r.right - r.left);
    s.h = (unsigned)(r.bottom - r.top);
    if (s.w < 1 || s.h < 1) return 0;
    if ((int)s.w == c->rtW && (int)s.h == c->rtH) return 1;    /* nothing moved */
    ((HRESULT (WINAPI*)(void*, const SIZEU*))VT(c->rt)[58])(c->rt, &s);
    c->rtW = (int)s.w;
    c->rtH = (int)s.h;
    InvalidateRect(c->hwnd, 0, 0);
    return 1;
}

/* how many whole rows fit below the header - what the Clarion side needs to
   know to fill a page */
/* how wide every column is together, and how wide the view is - what a
   horizontal scrollbar needs to size itself */
int d2g_TotalWidth(int h) {
    Grid* c = slot(h);
    int col, w = 0;
    if (!c) return 0;
    for (col = 0; col < c->cols; col++) w += c->colW[col];
    return w;
}

int d2g_ViewWidth(int h) {
    Grid* c = slot(h);
    RECT  r;
    if (!c || !IsWindow(c->hwnd)) return 0;
    GetClientRect(c->hwnd, &r);
    if (c->vBar) r.right -= D2G_BARW;
    return (int)(r.right - r.left);
}

int d2g_PageSize(int h) {
    Grid* c = slot(h);
    RECT  r;
    if (!c || !IsWindow(c->hwnd)) return 0;
    GetClientRect(c->hwnd, &r);
    if (c->rowH < 1) return 0;
    return (int)((r.bottom - r.top - c->hdrH) / c->rowH);
}

/* which row and column a point landed on; row is absolute, -1 for the header */
int d2g_HitRow(int h, int y) {
    Grid* c = slot(h);
    if (!c) return -1;
    if (y < c->hdrH) return -1;
    return c->firstRow + (int)((y - c->hdrH + c->scrollY) / c->rowH);
}

/* Which column's RIGHT edge is under x, within a few pixels - the grab handle
   for resizing. Frozen columns keep their own edges, unscrolled. -1 for none. */
int d2g_HitEdge(int h, int x) {
    Grid* c = slot(h);
    int col, at, fx = 0;
    const int grab = 4;
    if (!c) return -1;
    for (col = 0; col < c->frozen && col < c->cols; col++) {
        fx += c->colW[col];
        if (x >= fx - grab && x <= fx + grab) return col;
    }
    at = -c->scrollX;
    for (col = 0; col < c->cols; col++) {
        at += c->colW[col];
        if (col >= c->frozen && at > fx && x >= at - grab && x <= at + grab) return col;
    }
    return -1;
}

/* Which grid is drawn on this window? A scrollbar callback is handed an HWND
   and nothing else, and it has to be able to reach the grid from there. */
int d2g_FromHwnd(void* hwnd) {
    int i;
    for (i = 1; i <= G_MAX; i++)
        if (g_g[i].used && g_g[i].hwnd == (HWND)hwnd) return i;
    return 0;
}

/* ---- our own vertical scrollbar ---------------------------------------- */
void d2g_VBar(int h, int show, int pos, int pct) {
    Grid* c = slot(h);
    if (!c) return;
    c->vBar = show ? 1 : 0;
    c->vPos = pos < 0 ? 0 : (pos > 100 ? 100 : pos);
    c->vPct = pct < 4 ? 4 : (pct > 100 ? 100 : pct);
}

int d2g_VBarW(int h) { Grid* c = slot(h); return (c && c->vBar) ? D2G_BARW : 0; }

/* where the trough runs, and where the thumb sits inside it */
static void d2g_VGeom(Grid* c, int* top, int* len, int* tTop, int* tLen) {
    RECT r;
    int  t, l, tl;
    GetClientRect(c->hwnd, &r);
    t  = c->hdrH;
    l  = (r.bottom - r.top) - t;
    if (l < 0) l = 0;
    tl = l * c->vPct / 100;
    if (tl < 24) tl = 24;
    if (tl > l)  tl = l;
    *top = t; *len = l; *tLen = tl;
    *tTop = t + (l - tl) * c->vPos / 100;
}

/* 0 nowhere near it, 1 on the thumb, 2 above it, 3 below it */
int d2g_VHit(int h, int x, int y) {
    Grid* c = slot(h);
    RECT  r;
    int   top, len, tTop, tLen;
    if (!c || !c->vBar) return 0;
    GetClientRect(c->hwnd, &r);
    if (x < r.right - D2G_BARW) return 0;
    d2g_VGeom(c, &top, &len, &tTop, &tLen);
    if (y < top) return 0;
    if (y < tTop) return 2;
    if (y < tTop + tLen) return 1;
    return 3;
}

/* how far down the thumb the pointer took hold - so the drag is anchored and
   the thumb does not jump under the cursor when it starts */
int d2g_VGrab(int h, int y) {
    Grid* c = slot(h);
    int   top, len, tTop, tLen;
    if (!c || !c->vBar) return 0;
    d2g_VGeom(c, &top, &len, &tTop, &tLen);
    return y - tTop;
}

/* where the thumb has been dragged to, back on the browse's 0..100 scale */
int d2g_VDrag(int h, int y, int grab) {
    Grid* c = slot(h);
    int   top, len, tTop, tLen, room, pos;
    if (!c || !c->vBar) return 0;
    d2g_VGeom(c, &top, &len, &tTop, &tLen);
    room = len - tLen;
    if (room < 1) return 0;
    pos = (y - grab - top) * 100 / room;
    return pos < 0 ? 0 : (pos > 100 ? 100 : pos);
}

/* Build the text formats again at a new size, and grow the rows to match -
   Ctrl and the wheel, the way every other program does it. Returns the size
   actually used, so the caller can see where it stopped. */
int d2g_FontSize(int h, int pt) {
    Grid* c = slot(h);
    void *f, *fh;
    if (!c) return 0;
    if (pt < 6)  pt = 6;
    if (pt > 32) pt = 32;
    if (pt == c->pt) return c->pt;
    f  = d2g_Font(c->face, (float)pt, 0);
    fh = d2g_Font(c->face, (float)pt, 1);
    if (!f || !fh) {
        if (f)  ((unsigned long (WINAPI*)(void*))VT(f)[2])(f);
        if (fh) ((unsigned long (WINAPI*)(void*))VT(fh)[2])(fh);
        return c->pt;
    }
    if (c->fmt)    ((unsigned long (WINAPI*)(void*))VT(c->fmt)[2])(c->fmt);
    if (c->fmtHdr) ((unsigned long (WINAPI*)(void*))VT(c->fmtHdr)[2])(c->fmtHdr);
    c->fmt = f; c->fmtHdr = fh;
    c->rowH = D2G_ROWFOR(pt);                   /* the same rule d2g_Attach uses */
    c->hdrH = D2G_HDRFOR(pt);
    c->pt = pt;
    InvalidateRect(c->hwnd, 0, 0);
    return c->pt;
}

int d2g_FontPt(int h) { Grid* c = slot(h); return c ? c->pt : 0; }

int d2g_HdrHeight(int h) {
    Grid* c = slot(h);
    return c ? c->hdrH : 0;
}

int d2g_ColWidth(int h, int col) {
    Grid* c = slot(h);
    if (!c || col < 0 || col >= c->cols) return 0;
    return c->colW[col];
}

/* just the width - d2g_Column would want the title and alignment again */
void d2g_SetWidth(int h, int col, int w) {
    Grid* c = slot(h);
    if (!c || col < 0 || col >= c->cols) return;
    c->colW[col] = w < 16 ? 16 : w;
}

int d2g_HitCol(int h, int x) {
    Grid* c = slot(h);
    int col, at, fx = 0;
    if (!c) return -1;
    for (col = 0; col < c->frozen && col < c->cols; col++) {   /* the frozen strip first */
        if (x >= fx && x < fx + c->colW[col]) return col;
        fx += c->colW[col];
    }
    if (x < fx) return -1;
    at = -c->scrollX;
    for (col = 0; col < c->cols; col++) {
        if (col >= c->frozen && x >= at && x < at + c->colW[col]) return col;
        at += c->colW[col];
    }
    return -1;
}

}  /* extern "C" */
