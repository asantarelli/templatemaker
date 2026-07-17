/* ============================================================================
 *  yurucanvas.c - a DIRECT2D direct-to-window blit shim for myYuru.
 *
 *  myYuru renders its ~10-30k particle "yuruyurau" sketch by plotting them
 *  ADDITIVELY into an in-memory 24-bit BGR buffer on the Clarion side each frame.
 *  The classic backend then writes that buffer to a temp .bmp and reloads the
 *  IMAGE control - a file round-trip that dominates the frame time.
 *
 *  This shim kills that round-trip: it hosts a bare child window over the IMAGE
 *  control and owns a GPU-accelerated Direct2D render target on it, so each
 *  frame's pixel buffer is uploaded as a bitmap and BLITTED straight to the
 *  screen (DrawBitmap + Present), no file, no PROP:Text reload. This is the
 *  same "direct-to-window, no PNG" win added to CapeSoft Draw / DrawPlus, ported
 *  to myYuru's per-pixel model - the GPU does the scale + present; the particle
 *  math stays in Clarion.
 *
 *  Direct2D is a COM API (not flat exports), so we bind the one flat entry point
 *  d2d1.dll exposes (D2D1CreateFactory) and call every interface method through a
 *  hand-declared COM vtable (Clacpp has no DirectX headers). Only the vtable
 *  slots we call are typed; the rest are void* padding to keep each method at its
 *  correct index. Direct2D ships with every Windows 7+, so NO redistributable.
 *
 *  Symbols are yuru_d2d_* so this coexists with DrawPlus's dpcanvas.c (dp_*),
 *  d2dcanvas.c (dpcanvas_d2d_*) and gpcanvas.c (gp_*) in one app - no collision.
 *  Compiled by Clacpp via PRAGMA('compile(yurucanvas.c)') in YuruClass.clw.
 *
 *  ABI: coords cross as C double (Clarion REAL); the pixel buffer as a raw
 *  char* (*STRING,RAW). WINAPI == Clacpp 'pascal' (== __stdcall, also the COM
 *  calling convention).
 * ========================================================================== */

#define WINAPI pascal
typedef long           HRESULT;
typedef unsigned long  DWORD;
typedef unsigned int   UINT;
typedef void*          HMODULE;
typedef int (WINAPI *FARPROC)();
typedef struct { unsigned long Data1; unsigned short Data2; unsigned short Data3; unsigned char Data4[8]; } GUID;

#define S_OK   0

extern "C" {

HMODULE WINAPI LoadLibraryA(const char*);
FARPROC WINAPI GetProcAddress(HMODULE, const char*);

/* ---- opaque COM interface pointers ---- */
typedef struct ID2D1Factory      ID2D1Factory;
typedef struct ID2D1RenderTarget ID2D1RenderTarget;

/* ---- D2D value structs (must match the SDK layout exactly) ---- */
typedef struct { float r, g, b, a; }              D2D1_COLOR_F;
typedef struct { float left, top, right, bottom; } D2D1_RECT_F;
typedef struct { int format; int alphaMode; }     D2D1_PIXEL_FORMAT;
typedef struct { int type; D2D1_PIXEL_FORMAT pixelFormat;
                 float dpiX, dpiY; int usage; int minLevel; } D2D1_RENDER_TARGET_PROPERTIES;
typedef struct { unsigned int w, h; }             D2D1_SIZE_U;
typedef struct { void* hwnd; D2D1_SIZE_U pixelSize; int presentOptions; } D2D1_HWND_RT_PROPS;
typedef struct { D2D1_PIXEL_FORMAT pixelFormat; float dpiX, dpiY; } D2D1_BITMAP_PROPERTIES;

/* ---- IUnknown (generic Release for any COM object) ---- */
typedef struct { void* QueryInterface; void* AddRef; unsigned long (WINAPI* Release)(void*); } IUnknownVtbl;
typedef struct { IUnknownVtbl* v; } IUnknownObj;
static void rel(void* p) { if (p) ((IUnknownObj*)p)->v->Release(p); }

/* ---- ID2D1Factory: CreateHwndRenderTarget(14) ---- */
typedef struct {
    void* QueryInterface; void* AddRef; void* Release;                 /* 0..2 */
    void* ReloadSystemMetrics; void* GetDesktopDpi;                    /* 3,4  */
    void* CreateRectangleGeometry; void* CreateRoundedRectangleGeometry;
    void* CreateEllipseGeometry; void* CreateGeometryGroup;
    void* CreateTransformedGeometry;                                  /* 5..9 */
    void* CreatePathGeometry; void* CreateStrokeStyle;                /* 10,11 */
    void* CreateDrawingStateBlock;                                    /* 12   */
    void* CreateWicBitmapRenderTarget;                                /* 13   */
    HRESULT (WINAPI* CreateHwndRenderTarget)(ID2D1Factory*, const D2D1_RENDER_TARGET_PROPERTIES*,
             const D2D1_HWND_RT_PROPS*, ID2D1RenderTarget**);         /* 14 (HwndRT derives from RenderTarget) */
} ID2D1FactoryVtbl;
struct ID2D1Factory { ID2D1FactoryVtbl* v; };

/* ---- ID2D1RenderTarget: CreateBitmap(4), DrawBitmap(26), Clear(47),
        BeginDraw(48), EndDraw(49) ---- */
typedef struct {
    void* QueryInterface; void* AddRef; void* Release; void* GetFactory; /* 0..3 */
    HRESULT (WINAPI* CreateBitmap)(ID2D1RenderTarget*, D2D1_SIZE_U, const void*, UINT,
             const D2D1_BITMAP_PROPERTIES*, void**);                     /* 4 -> ID2D1Bitmap** */
    void* CreateBitmapFromWicBitmap; void* CreateSharedBitmap; void* CreateBitmapBrush; /* 5..7 */
    void* CreateSolidColorBrush; void* CreateGradientStopCollection;    /* 8,9   */
    void* CreateLinearGradientBrush; void* CreateRadialGradientBrush;   /* 10,11 */
    void* CreateCompatibleRenderTarget; void* CreateLayer; void* CreateMesh; /* 12..14 */
    void* DrawLine; void* DrawRectangle; void* FillRectangle;           /* 15..17 */
    void* DrawRoundedRectangle; void* FillRoundedRectangle;             /* 18,19 */
    void* DrawEllipse; void* FillEllipse;                              /* 20,21 */
    void* DrawGeometry; void* FillGeometry;                            /* 22,23 */
    void* FillMesh; void* FillOpacityMask;                            /* 24,25 */
    void (WINAPI* DrawBitmap)(ID2D1RenderTarget*, void*, const D2D1_RECT_F*, float, int, const D2D1_RECT_F*); /* 26 */
    void* DrawText; void* DrawTextLayout; void* DrawGlyphRun;          /* 27..29 */
    void* SetTransform; void* GetTransform;                           /* 30,31 */
    void* SetAntialiasMode; void* GetAntialiasMode;                   /* 32,33 */
    void* SetTextAntialiasMode; void* GetTextAntialiasMode;           /* 34,35 */
    void* SetTextRenderingParams; void* GetTextRenderingParams;       /* 36,37 */
    void* SetTags; void* GetTags; void* PushLayer; void* PopLayer;    /* 38..41 */
    void* Flush; void* SaveDrawingState; void* RestoreDrawingState;   /* 42..44 */
    void* PushAxisAlignedClip; void* PopAxisAlignedClip;              /* 45,46 */
    void (WINAPI* Clear)(ID2D1RenderTarget*, const D2D1_COLOR_F*);     /* 47 */
    void (WINAPI* BeginDraw)(ID2D1RenderTarget*);                     /* 48 */
    HRESULT (WINAPI* EndDraw)(ID2D1RenderTarget*, void*, void*);      /* 49 */
} ID2D1RenderTargetVtbl;
struct ID2D1RenderTarget { ID2D1RenderTargetVtbl* v; };

/* ---- flat DLL entry points ---- */
typedef HRESULT (WINAPI *PFN_D2D1CreateFactory)(int, const GUID*, const void*, void**);
/* user32 - the child host window over the IMAGE control */
typedef void* (WINAPI *PFN_CreateWindowExA)(DWORD, const char*, const char*, DWORD,
              int, int, int, int, void*, void*, void*, void*);
typedef int   (WINAPI *PFN_DestroyWindow)(void*);
typedef int   (WINAPI *PFN_SetWindowPos)(void*, void*, int, int, int, int, unsigned int);

/* ---- GUIDs ---- */
static GUID IID_ID2D1Factory = {0x06152247,0x6f50,0x465a,{0x92,0x45,0x11,0x8b,0xfd,0x3b,0x60,0x07}};

/* ---- module state ---- */
static int                 g_inited = 0;
static ID2D1Factory*       g_d2d = 0;
static PFN_CreateWindowExA p_CreateWin = 0;
static PFN_DestroyWindow   p_DestroyWin = 0;
static PFN_SetWindowPos    p_SetWinPos = 0;
static int                 g_step = 0;
static HRESULT             g_hr = 0;

#define YU_MAX 16
static struct { ID2D1RenderTarget* rt; int w, h, drawing; } g_cv[YU_MAX+1];

/* staging buffer for the 24bpp->32bpp conversion (myYuru's canvas is 400x400) */
#define STAGE_MAX_PX (640*640)
static unsigned char g_stage[STAGE_MAX_PX*4];

/* ========================================================================== */
int yuru_d2d_init(void) {
    HMODULE hD2D, hU;
    PFN_D2D1CreateFactory pD2D;
    if (g_inited) return 0;
    hD2D = LoadLibraryA("d2d1.dll"); if (!hD2D) { g_step=-1; return -1; }
    hU   = LoadLibraryA("user32.dll");
    if (hU) {
        *(FARPROC*)&p_CreateWin  = GetProcAddress(hU, "CreateWindowExA");
        *(FARPROC*)&p_DestroyWin = GetProcAddress(hU, "DestroyWindow");
        *(FARPROC*)&p_SetWinPos  = GetProcAddress(hU, "SetWindowPos");
    }
    *(FARPROC*)&pD2D = GetProcAddress(hD2D, "D2D1CreateFactory");
    if (!pD2D) { g_step=-2; return -2; }
    g_hr = pD2D(0 /*SINGLE_THREADED*/, &IID_ID2D1Factory, 0, (void**)&g_d2d);
    if (g_hr != S_OK || !g_d2d) { g_step=-3; return -3; }
    g_inited = 1;
    return 0;
}
int  yuru_d2d_last_step(void) { return g_step; }
long yuru_d2d_last_hr(void)   { return g_hr;   }

/* ---- child HOST window: a bare WS_CHILD over the IMAGE control's rectangle, so
   the animation owns a real HWND for the Direct2D target. x,y,w,h are pixels in
   the PARENT window's client coords. Returns the child HWND (0 = failed). ---- */
int yuru_d2d_make_child(int parent, int x, int y, int w, int h) {
    void* hwnd;
    if (!g_inited && yuru_d2d_init() != 0) return 0;
    if (!p_CreateWin) return 0;
    hwnd = p_CreateWin(0, "STATIC", "",
                       0x50000000,              /* WS_CHILD | WS_VISIBLE */
                       x, y, w, h, (void*)(unsigned long)parent, 0, 0, 0);
    return (int)(unsigned long)hwnd;
}
void yuru_d2d_move_child(int hwnd, int x, int y, int w, int h) {
    if (p_SetWinPos && hwnd)
        p_SetWinPos((void*)(unsigned long)hwnd, 0, x, y, w, h, 0x14); /* SWP_NOZORDER|SWP_NOACTIVATE */
}
void yuru_d2d_destroy_child(int hwnd) {
    if (p_DestroyWin && hwnd) p_DestroyWin((void*)(unsigned long)hwnd);
}

/* ---- create a GPU-composited Direct2D render target ON a window HWND. It
   derives from ID2D1RenderTarget so the blit below works on it unchanged.
   presentOptions=3 == RETAIN_CONTENTS|IMMEDIATELY: keep the last frame on expose,
   no vsync wait. Returns a canvas handle (0 = failed). ---- */
int yuru_d2d_begin_hwnd(int hwnd, int w, int h) {
    int i; ID2D1RenderTarget* rt = 0;
    D2D1_RENDER_TARGET_PROPERTIES p; D2D1_HWND_RT_PROPS hp;
    if (!g_inited && yuru_d2d_init() != 0) return 0;
    if (w < 1) w = 1;  if (h < 1) h = 1;
    for (i = 1; i <= YU_MAX; i++) if (!g_cv[i].rt) break;
    if (i > YU_MAX) { g_step = -10; return 0; }
    p.type = 0;                         /* DEFAULT: hardware if available, else WARP */
    p.pixelFormat.format = 0; p.pixelFormat.alphaMode = 1; /* UNKNOWN + PREMULTIPLIED */
    p.dpiX = 0; p.dpiY = 0; p.usage = 0; p.minLevel = 0;
    hp.hwnd = (void*)(unsigned long)hwnd;
    hp.pixelSize.w = (unsigned int)w; hp.pixelSize.h = (unsigned int)h;
    hp.presentOptions = 3;
    g_hr = g_d2d->v->CreateHwndRenderTarget(g_d2d, &p, &hp, &rt);
    if (g_hr != S_OK || !rt) { g_step = -11; return 0; }
    rt->v->BeginDraw(rt);
    g_cv[i].rt = rt; g_cv[i].w = w; g_cv[i].h = h; g_cv[i].drawing = 1;
    return i;
}

static ID2D1RenderTarget* RT(int h) {
    if (h < 1 || h > YU_MAX) return 0;
    return g_cv[h].rt;
}

/* ---- BLIT the frame: upload the 24bpp BGR buffer as a GPU bitmap, scale it into
   (dx,dy,dw,dh), draw. bottomup!=0 means the source rows run bottom->top (BMP
   convention, as myYuru's buffer does). No file, no reload. ---- */
void yuru_d2d_blit_bgr24(int h, const unsigned char* bgr, int bw, int bh, int bottomup,
                         double dx, double dy, double dw, double dh) {
    ID2D1RenderTarget* rt = RT(h);
    void* bmp = 0;
    D2D1_SIZE_U sz; D2D1_BITMAP_PROPERTIES bp; D2D1_RECT_F dst;
    int x, y, srcrow;
    const unsigned char* sp; unsigned char* dp;
    if (!rt || !bgr || bw < 1 || bh < 1) return;
    if (bw * bh > STAGE_MAX_PX) return;
    for (y = 0; y < bh; y++) {
        srcrow = bottomup ? (bh - 1 - y) : y;
        sp = bgr + srcrow * bw * 3;
        dp = g_stage + y * bw * 4;
        for (x = 0; x < bw; x++) {
            dp[0] = sp[0]; dp[1] = sp[1]; dp[2] = sp[2]; dp[3] = 255; /* B G R A(opaque) */
            sp += 3; dp += 4;
        }
    }
    sz.w = (unsigned int)bw; sz.h = (unsigned int)bh;
    bp.pixelFormat.format = 87;    /* DXGI_FORMAT_B8G8R8A8_UNORM */
    bp.pixelFormat.alphaMode = 1;  /* PREMULTIPLIED (a=255 => same as straight) */
    bp.dpiX = 0; bp.dpiY = 0;
    if (rt->v->CreateBitmap(rt, sz, g_stage, (UINT)(bw*4), &bp, &bmp) != S_OK || !bmp) return;
    dst.left=(float)dx; dst.top=(float)dy; dst.right=(float)(dx+dw); dst.bottom=(float)(dy+dh);
    rt->v->DrawBitmap(rt, bmp, &dst, 1.0f, 1 /*LINEAR*/, 0);
    rel(bmp);
}

/* present the window canvas: EndDraw flips it to the screen, then re-open for next frame */
void yuru_d2d_present(int h) {
    ID2D1RenderTarget* rt = RT(h);
    if (!rt) return;
    if (g_cv[h].drawing) { rt->v->EndDraw(rt, 0, 0); g_cv[h].drawing = 0; }
    rt->v->BeginDraw(rt); g_cv[h].drawing = 1;
}

void yuru_d2d_end(int h) {
    if (h < 1 || h > YU_MAX) return;
    if (g_cv[h].rt && g_cv[h].drawing) { g_cv[h].rt->v->EndDraw(g_cv[h].rt, 0, 0); g_cv[h].drawing = 0; }
    if (g_cv[h].rt) { rel(g_cv[h].rt); g_cv[h].rt = 0; }
}

}  /* extern "C" */
