/* ============================================================================
 *  wdoc.c - myWordDoc: a word-processing control for Clarion, with NO COM.
 *
 *  WHAT THIS IS
 *  ------------
 *  Our own control. It registers its own window class ("myWordDocHost") whose
 *  window procedure lives in this file, and that host owns everything the user
 *  sees: a toolbar it paints itself (font, size, bold/italic/underline/strike,
 *  text colour, highlight, alignment, bullets, numbering, indent, picture,
 *  table, undo/redo), an optional "page view" that shows the document at its
 *  printed width on a grey desk, and the editing surface.
 *
 *  The editing surface is the Windows text engine - RICHEDIT50W in msftedit.dll,
 *  the engine behind WordPad - used as a component: it does the typing, line
 *  breaking, selection, undo, clipboard, accents/IME and the RTF format. The
 *  host is its PARENT, so its WM_NOTIFY / WM_COMMAND notifications come to OUR
 *  window procedure. The Clarion window is never subclassed.
 *
 *  STORAGE: the document is RTF (Word opens it). The Clarion class streams it
 *  into and out of a BLOB through wdoc_load / wdoc_save / wdoc_copy.
 *
 *  PRINTING: wdoc_paginate splits the document into pages (or band-sized
 *  chunks) of any size in twips, and wdoc_render_page draws one of them into an
 *  enhanced metafile. A Clarion report IMAGE pointing at that .emf plays its
 *  records straight into the page, so the text stays vector (sharp, small PDFs).
 *  A control created with no parent window is an invisible document - that is
 *  how a REPORT procedure renders a BLOB it never showed on screen.
 *
 *  Everything is bound at run time with LoadLibrary/GetProcAddress, so there is
 *  no import library. Compiled into the exe by Clacpp via PRAGMA('compile(wdoc.c)').
 *
 *  ABI: ints by value, strings/buffers as char* (RAW). Results come back one
 *  value at a time through getters - no structs cross into Clarion.
 *  WINAPI == Clacpp 'pascal' == __stdcall. Win32 (32-bit) target.
 * ========================================================================== */

#define WINAPI pascal

typedef unsigned long  DWORD;
typedef unsigned int   UINT;
typedef unsigned short WORD;
typedef unsigned short WCHAR;
typedef unsigned char  BYTE;
typedef int            BOOL;
typedef void*          HMODULE;
typedef void*          HANDLE;
typedef int (WINAPI *FARPROC)();

/* ---- window styles ---- */
#define WS_CHILD          0x40000000
#define WS_VISIBLE        0x10000000
#define WS_POPUP          0x80000000
#define WS_VSCROLL        0x00200000
#define WS_HSCROLL        0x00100000
#define WS_TABSTOP        0x00010000
#define WS_CLIPCHILDREN   0x02000000
#define WS_CLIPSIBLINGS   0x04000000
#define CBS_DROPDOWNLIST  0x0003
#define CBS_SORT          0x0100
#define CBS_HASSTRINGS    0x0200

/* ---- edit / richedit styles ---- */
#define ES_MULTILINE      0x0004
#define ES_AUTOVSCROLL    0x0040
#define ES_NOHIDESEL      0x0100
#define ES_WANTRETURN     0x1000
#define ES_SAVESEL        0x8000

/* ---- messages ---- */
#define WM_DESTROY        0x0002
#define WM_SIZE           0x0005
#define WM_SETFOCUS       0x0007
#define WM_PAINT          0x000F
#define WM_ERASEBKGND     0x0014
#define WM_SETFONT        0x0030
#define WM_NOTIFY         0x004E
#define WM_KEYDOWN        0x0100
#define WM_CHAR           0x0102
#define WM_COMMAND        0x0111
#define WM_GETDLGCODE     0x0087
#define WM_MOUSEMOVE      0x0200
#define WM_LBUTTONDOWN    0x0201
#define WM_LBUTTONUP      0x0202
#define WM_MOUSELEAVE     0x02A3
#define WM_CUT            0x0300
#define WM_COPY           0x0301
#define WM_PASTE          0x0302
#define WM_CLEAR          0x0303
#define WM_UNDO           0x0304
#define WM_USER           0x0400

#define EM_GETSEL         0x00B0
#define EM_SETSEL         0x00B1
#define EM_GETMODIFY      0x00B8
#define EM_SETMODIFY      0x00B9
#define EM_REPLACESEL     0x00C2
#define EM_SETREADONLY    0x00CF
#define EM_SETMARGINS     0x00D3
#define EM_EXGETSEL       (WM_USER + 52)
#define EM_EXLIMITTEXT    (WM_USER + 53)
#define EM_EXSETSEL       (WM_USER + 55)
#define EM_FORMATRANGE    (WM_USER + 57)
#define EM_GETCHARFORMAT  (WM_USER + 58)
#define EM_GETPARAFORMAT  (WM_USER + 61)
#define EM_SETBKGNDCOLOR  (WM_USER + 67)
#define EM_SETCHARFORMAT  (WM_USER + 68)
#define EM_SETEVENTMASK   (WM_USER + 69)
#define EM_SETPARAFORMAT  (WM_USER + 71)
#define EM_SETTARGETDEVICE (WM_USER + 72)
#define EM_STREAMIN       (WM_USER + 73)
#define EM_STREAMOUT      (WM_USER + 74)
#define EM_FINDTEXTEXW    (WM_USER + 124)   /* RICHEDIT50W is Unicode: search with W text */
#define EM_REDO           (WM_USER + 84)
#define EM_CANUNDO        0x00C6
#define EM_UNDO           0x00C7
#define EM_CANREDO        (WM_USER + 85)
#define EM_GETTEXTLENGTHEX (WM_USER + 95)
#define EM_SETZOOM        (WM_USER + 225)

#define CB_ADDSTRING      0x0143
#define CB_GETCURSEL      0x0147
#define CB_GETLBTEXT      0x0148
#define CB_RESETCONTENT   0x014B
#define CB_FINDSTRINGEXACT 0x0158
#define CB_SETCURSEL      0x014E
#define CB_SETDROPPEDWIDTH 0x0160
#define CBN_SELCHANGE     1
#define CBN_CLOSEUP       8
#define EN_CHANGE         0x0300
#define EN_SELCHANGE      0x0702

#define ENM_CHANGE        0x00000001
#define ENM_SELCHANGE     0x00080000

#define SF_TEXT           0x0001
#define SF_RTF            0x0002
#define SFF_SELECTION     0x8000
#define SCF_SELECTION     0x0001
#define SCF_ALL           0x0004
#define GTL_PRECISE       2
#define GTL_NUMCHARS      8

/* CHARFORMAT masks / effects */
#define CFM_BOLD          0x00000001
#define CFM_ITALIC        0x00000002
#define CFM_UNDERLINE     0x00000004
#define CFM_STRIKEOUT     0x00000008
#define CFM_SIZE          0x80000000
#define CFM_COLOR         0x40000000
#define CFM_FACE          0x20000000
#define CFM_CHARSET       0x08000000
#define CFM_BACKCOLOR     0x04000000
#define CFE_AUTOCOLOR     0x40000000
#define CFE_AUTOBACKCOLOR 0x04000000

/* PARAFORMAT masks */
#define PFM_STARTINDENT   0x00000001
#define PFM_OFFSET        0x00000004
#define PFM_ALIGNMENT     0x00000008
#define PFM_NUMBERING     0x00000020
#define PFM_OFFSETINDENT  0x80000000
#define PFM_NUMBERINGSTYLE 0x00002000
#define PFM_NUMBERINGTAB  0x00004000
#define PFM_NUMBERINGSTART 0x00008000

#define FR_DOWN           0x00000001
#define FR_WHOLEWORD      0x00000002
#define FR_MATCHCASE      0x00000004

#define EC_LEFTMARGIN     0x0001
#define EC_RIGHTMARGIN    0x0002

#define SWP_NOSIZE        0x0001
#define SWP_NOMOVE        0x0002
#define SWP_NOZORDER      0x0004
#define SWP_NOACTIVATE    0x0010
#define SWP_FRAMECHANGED  0x0020
#define SWP_SHOWWINDOW    0x0040
#define GWL_STYLE         (-16)
#define LOGPIXELSX        88
#define LOGPIXELSY        90
#define TRANSPARENT       1
#define PS_SOLID          0
#define DT_CENTER         0x0001
#define DT_VCENTER        0x0004
#define DT_SINGLELINE     0x0020
#define DT_NOPREFIX       0x0800
#define TME_LEAVE         0x00000002
#define CC_RGBINIT        0x00000001
#define CC_FULLOPEN       0x00000002
#define OFN_FILEMUSTEXIST 0x00001000
#define OFN_PATHMUSTEXIST 0x00000800
#define OFN_HIDEREADONLY  0x00000004
#define OFN_NOCHANGEDIR   0x00000008
#define TPM_RETURNCMD     0x0100
#define TPM_LEFTALIGN     0x0000
#define MF_STRING         0x0000
#define MF_SEPARATOR      0x0800
#define GENERIC_READ      0x80000000
#define GENERIC_WRITE     0x40000000
#define OPEN_EXISTING     3
#define CREATE_ALWAYS     2
#define FILE_SHARE_READ   1
#define DEFAULT_CHARSET   1
#define IDC_ARROW         32512
#define IDC_HAND          32649

#define WD_MAX       32
#define TB_ROWH      30     /* one toolbar row, in 96-dpi pixels */
#define TB_BTN       26     /* button square */
#define TB_GAP       2
#define ID_EDIT      100
#define ID_FONT      101
#define ID_SIZE      102

/* create() flags - must match WD:Flag* in WordDocClass.inc */
#define WDF_TOOLBAR   0x0001
#define WDF_READONLY  0x0002
#define WDF_PAGEVIEW  0x0004
#define WDF_NOBORDER  0x0008

/* palette (COLORREF is 0x00BBGGRR) - neutral slate with a blue accent */
#define C_BAR      0x00F6F4F3   /* toolbar background  #F3F4F6 */
#define C_BARLINE  0x00DBD5D1   /* separators/border   #D1D5DB */
#define C_HOVER    0x00EBE7E5   /* hover               #E5E7EB */
#define C_ON       0x00FEEADB   /* pressed fill        #DBEAFE */
#define C_ONLINE   0x00F6823B   /* pressed edge        #3B82F6 */
#define C_INK      0x00372D1F   /* glyph ink           #1F2D37 */
#define C_DIM      0x00AFA39C   /* disabled ink        #9CA3AF */
#define C_DESK     0x00E1DCD8   /* page-view desk      #D8DCE1 */
#define C_FRAME    0x00E1D5CB   /* outer frame         #CBD5E1 */

extern "C" {

HMODULE WINAPI LoadLibraryA(const char*);
FARPROC WINAPI GetProcAddress(HMODULE, const char*);

/* ---- plain value structs (must match the Win32 layout exactly) ---------- */
typedef struct { long left, top, right, bottom; } RECT;
typedef struct { long x, y; } POINT;
typedef struct { long cpMin, cpMax; } CHARRANGE;
typedef struct { void* hwndFrom; UINT idFrom; UINT code; } NMHDR;
typedef struct { NMHDR nmhdr; CHARRANGE chrg; WORD seltyp; } SELCHANGE;
typedef struct { void* hdc; void* hdcTarget; RECT rc; RECT rcPage; CHARRANGE chrg; } FORMATRANGE;
typedef struct { DWORD flags; UINT codepage; } GETTEXTLENGTHEX;
typedef struct { CHARRANGE chrg; const WCHAR* lpstrText; CHARRANGE chrgText; } FINDTEXTEXW;
typedef DWORD (WINAPI *EDITSTREAMCALLBACK)(DWORD, BYTE*, long, long*);
typedef struct { DWORD dwCookie; DWORD dwError; EDITSTREAMCALLBACK pfnCallback; } EDITSTREAM;

/* CHARFORMAT2A - 84 bytes. Clacpp packs structs on 2-byte boundaries, so the
   hole Win32 leaves before crBackColor (offset 62 -> 64) is spelled out. */
typedef struct {
    UINT  cbSize; DWORD dwMask; DWORD dwEffects; long yHeight; long yOffset;
    DWORD crTextColor; BYTE bCharSet; BYTE bPitchAndFamily; char szFaceName[32];
    WORD  wWeight; short sSpacing; WORD wPad; DWORD crBackColor; DWORD lcid; DWORD dwReserved;
    short sStyle; WORD wKerning; BYTE bUnderlineType, bAnimation, bRevAuthor, bUnderlineColor;
} CF2A;

/* PARAFORMAT2 - 188 bytes */
typedef struct {
    UINT  cbSize; DWORD dwMask; WORD wNumbering; WORD wEffects;
    long  dxStartIndent; long dxRightIndent; long dxOffset; WORD wAlignment; short cTabCount;
    long  rgxTabs[32];
    long  dySpaceBefore; long dySpaceAfter; long dyLineSpacing; short sStyle;
    BYTE  bLineSpacingRule; BYTE bOutlineLevel; WORD wShadingWeight; WORD wShadingStyle;
    WORD  wNumberingStart; WORD wNumberingStyle; WORD wNumberingTab;
    WORD  wBorderSpace; WORD wBorderWidth; WORD wBorders;
} PF2;

typedef long (WINAPI *WNDPROC)(void*, UINT, unsigned long, unsigned long);
typedef struct {
    UINT style; WNDPROC lpfnWndProc; int cbClsExtra; int cbWndExtra; void* hInstance;
    void* hIcon; void* hCursor; void* hbrBackground; const char* lpszMenuName; const char* lpszClassName;
} WNDCLASSA;
typedef struct { void* hdc; BOOL fErase; RECT rc; BOOL fRestore; BOOL fIncUpdate; BYTE rgb[32]; } PAINTSTRUCT;
typedef struct { DWORD cbSize; DWORD dwFlags; void* hwndTrack; DWORD dwHoverTime; } TRACKMOUSEEVENT;
typedef struct {
    DWORD lStructSize; void* hwndOwner; void* hInstance; DWORD rgbResult; DWORD* lpCustColors;
    DWORD Flags; long lCustData; void* lpfnHook; const char* lpTemplateName;
} CHOOSECOLORA;
typedef struct {
    DWORD lStructSize; void* hwndOwner; void* hInstance; const char* lpstrFilter;
    char* lpstrCustomFilter; DWORD nMaxCustFilter; DWORD nFilterIndex; char* lpstrFile;
    DWORD nMaxFile; char* lpstrFileTitle; DWORD nMaxFileTitle; const char* lpstrInitialDir;
    const char* lpstrTitle; DWORD Flags; WORD nFileOffset; WORD nFileExtension;
    const char* lpstrDefExt; long lCustData; void* lpfnHook; const char* lpTemplateName;
} OPENFILENAMEA;
typedef struct {
    long lfHeight, lfWidth, lfEscapement, lfOrientation, lfWeight;
    BYTE lfItalic, lfUnderline, lfStrikeOut, lfCharSet, lfOutPrecision, lfClipPrecision,
         lfQuality, lfPitchAndFamily;
    char lfFaceName[32];
} LOGFONTA;
typedef int (WINAPI *FONTENUMPROCA)(const LOGFONTA*, const void*, DWORD, long);

/* ---- dynamically bound entry points ------------------------------------- */
#define FN(ret, name, args) typedef ret (WINAPI *PFN_##name) args; static PFN_##name p_##name = 0;
FN(void*, CreateWindowExA, (DWORD, const char*, const char*, DWORD, int, int, int, int, void*, void*, void*, void*))
FN(long,  SendMessageA,   (void*, UINT, unsigned long, unsigned long))
FN(long,  DefWindowProcA, (void*, UINT, unsigned long, unsigned long))
FN(WORD,  RegisterClassA, (const WNDCLASSA*))
FN(int,   DestroyWindow,  (void*))
FN(int,   SetWindowPos,   (void*, void*, int, int, int, int, UINT))
FN(int,   MoveWindow,     (void*, int, int, int, int, int))
FN(int,   ShowWindow,     (void*, int))
FN(void*, SetFocus,       (void*))
FN(void*, GetFocus,       (void))
FN(int,   IsChild,        (void*, void*))
FN(int,   EnableWindow,   (void*, int))
FN(int,   InvalidateRect, (void*, const RECT*, int))
FN(int,   GetClientRect,  (void*, RECT*))
FN(long,  GetWindowLongA, (void*, int))
FN(long,  SetWindowLongA, (void*, int, long))
FN(void*, GetParent,      (void*))
FN(void*, BeginPaint,     (void*, PAINTSTRUCT*))
FN(int,   EndPaint,       (void*, const PAINTSTRUCT*))
FN(void*, GetDC,          (void*))
FN(int,   ReleaseDC,      (void*, void*))
FN(int,   FillRect,       (void*, const RECT*, void*))
FN(int,   DrawTextA,      (void*, const char*, int, RECT*, UINT))
FN(void*, LoadCursorA,    (void*, const char*))
FN(void*, SetCursor,      (void*))
FN(int,   TrackMouseEvent,(TRACKMOUSEEVENT*))
FN(int,   ClientToScreen, (void*, POINT*))
FN(void*, CreatePopupMenu,(void))
FN(int,   AppendMenuA,    (void*, UINT, UINT, const char*))
FN(int,   TrackPopupMenu, (void*, UINT, int, int, int, void*, const RECT*))
FN(int,   DestroyMenu,    (void*))
FN(void*, GetModuleHandleA, (const char*))
FN(int,   GetDeviceCaps,  (void*, int))
FN(void*, CreateFontA,    (int, int, int, int, int, DWORD, DWORD, DWORD, DWORD, DWORD, DWORD, DWORD, DWORD, const char*))
FN(void*, CreateSolidBrush, (DWORD))
FN(void*, CreatePen,      (int, int, DWORD))
FN(void*, SelectObject,   (void*, void*))
FN(int,   DeleteObject,   (void*))
FN(DWORD, SetTextColor,   (void*, DWORD))
FN(int,   SetBkMode,      (void*, int))
FN(int,   MoveToEx,       (void*, int, int, POINT*))
FN(int,   LineTo,         (void*, int, int))
FN(int,   Rectangle,      (void*, int, int, int, int))
FN(int,   Ellipse,        (void*, int, int, int, int))
FN(int,   Polygon,        (void*, const POINT*, int))
FN(int,   TextOutW,       (void*, int, int, const WCHAR*, int))
FN(void*, CreateCompatibleDC, (void*))
FN(void*, CreateCompatibleBitmap, (void*, int, int))
FN(int,   BitBlt,         (void*, int, int, int, int, void*, int, int, DWORD))
FN(int,   DeleteDC,       (void*))
FN(void*, CreateDCA,      (const char*, const char*, const char*, void*))
FN(void*, CreateEnhMetaFileA, (void*, const char*, const RECT*, const char*))
FN(void*, CloseEnhMetaFile, (void*))
FN(int,   DeleteEnhMetaFile, (void*))
FN(UINT,  GetWinMetaFileBits, (void*, UINT, BYTE*, int, void*))
FN(void*, CreateICA,      (const char*, const char*, const char*, void*))
FN(UINT,  GetEnhMetaFileBits, (void*, UINT, BYTE*))
FN(void*, SetEnhMetaFileBits, (UINT, const BYTE*))
FN(int,   GetDefaultPrinterA, (char*, DWORD*))
FN(int,   EnumFontFamiliesExA, (void*, LOGFONTA*, FONTENUMPROCA, long, DWORD))
FN(int,   SetMapMode,     (void*, int))
FN(int,   ChooseColorA,   (CHOOSECOLORA*))
FN(int,   GetOpenFileNameA, (OPENFILENAMEA*))
FN(void*, CreateFileA,    (const char*, DWORD, DWORD, void*, DWORD, DWORD, void*))
FN(int,   ReadFile,       (void*, void*, DWORD, DWORD*, void*))
FN(int,   WriteFile,      (void*, const void*, DWORD, DWORD*, void*))
FN(DWORD, GetFileSize,    (void*, DWORD*))
FN(int,   CloseHandle,    (void*))
FN(void*, GetProcessHeap, (void))
FN(void*, HeapAlloc,      (void*, DWORD, DWORD))
FN(void*, HeapReAlloc,    (void*, DWORD, void*, DWORD))
FN(int,   HeapFree,       (void*, DWORD, void*))
FN(long,  OleInitialize,  (void*))
FN(int,   MultiByteToWideChar, (UINT, DWORD, const char*, int, WCHAR*, int))
FN(DWORD, GetTempPathA,   (DWORD, char*))
FN(DWORD, GetCurrentProcessId, (void))
FN(int,   DeleteFileA,    (const char*))

/* ---- toolbar buttons ---------------------------------------------------- */
enum {
    B_NONE = 0, B_BOLD, B_ITALIC, B_UNDER, B_STRIKE, B_COLOR, B_HILITE,
    B_LEFT, B_CENTER, B_RIGHT, B_JUSTIFY, B_BULLETS, B_NUMBERS, B_OUTDENT, B_INDENT,
    B_PICTURE, B_TABLE, B_UNDO, B_REDO, B_SEP, B_FONT, B_SIZE
};
/* the order they appear in; B_SEP draws a divider */
static const int g_layout[] = {
    B_FONT, B_SIZE, B_SEP, B_BOLD, B_ITALIC, B_UNDER, B_STRIKE, B_SEP, B_COLOR, B_HILITE, B_SEP,
    B_LEFT, B_CENTER, B_RIGHT, B_JUSTIFY, B_SEP, B_BULLETS, B_NUMBERS, B_OUTDENT, B_INDENT, B_SEP,
    B_PICTURE, B_TABLE, B_SEP, B_UNDO, B_REDO, -1
};
#define NBTN 32

/* ---- per-document state ------------------------------------------------- */
typedef struct {
    void* host;          /* our myWordDocHost window (0 for an invisible doc) */
    void* edit;          /* the RICHEDIT50W window                         */
    void* cbFont;        /* toolbar combos                                 */
    void* cbSize;
    int   flags;
    int   pageTw;        /* printed line width in twips, 0 = wrap to window */
    int   tbH;           /* toolbar height in px (0 when hidden)           */
    int   seq;           /* bumped on every edit                           */
    int   selseq;        /* bumped on every selection move                 */
    int   hot;           /* button under the mouse                         */
    int   down;          /* button being pressed                           */
    int   tracking;
    RECT  br[NBTN];      /* button rectangles, by layout index             */
    int   state[NBTN];   /* 1 = shown pressed                              */
    DWORD fore, back;    /* last colours chosen from the toolbar           */
    int   lastPick;      /* toolbar pick count, readable from Clarion      */
    int   lastCmd;
    /* stream-out buffer */
    char* buf; long len, cap;
    /* pagination */
    long* pstart; long* pused; int pages, pcap;
} WDOC;

static WDOC  g_d[WD_MAX + 1];
static int   g_inited = 0;
static int   g_step   = 0;
static void* g_heap   = 0;
static void* g_inst   = 0;
static void* g_refDC  = 0;    /* measuring device for edit, paginate and render: the default printer */
static void* g_scrDC  = 0;    /* the display */
static void* g_fUI    = 0;    /* toolbar fonts */
static void* g_fBold  = 0;
static void* g_fItal  = 0;
static void* g_fUnd   = 0;
static void* g_fStrk  = 0;
static void* g_fIcon  = 0;
static void* g_curArrow = 0;
static DWORD g_custColors[16];
static int   g_dpi = 96;

static long WINAPI host_proc(void* w, UINT m, unsigned long wp, unsigned long lp);

/* ========================================================================== */
static void* mem_alloc(long n) { return p_HeapAlloc(g_heap, 8 /*ZERO*/, (DWORD)n); }
static void* mem_grow(void* p, long n) { return p ? p_HeapReAlloc(g_heap, 8, p, (DWORD)n) : mem_alloc(n); }
static void  mem_free(void* p) { if (p) p_HeapFree(g_heap, 0, p); }
static int   px(int v) { return v * g_dpi / 96; }
static int   slen(const char* s) { int n = 0; if (s) while (s[n]) n++; return n; }
static void  scpy(char* d, const char* s, int cap) { int i = 0; if (cap <= 0) return; while (s && s[i] && i < cap - 1) { d[i] = s[i]; i++; } d[i] = 0; }
static void  zero(void* p, int n) { char* c = (char*)p; while (n-- > 0) *c++ = 0; }
static int   seq_ci(const char* a, const char* b) {
    while (*a && *b) { char x = *a, y = *b; if (x >= 'A' && x <= 'Z') x += 32; if (y >= 'A' && y <= 'Z') y += 32; if (x != y) return 0; a++; b++; }
    return *a == *b;
}

#define BIND(mod, name) *(FARPROC*)&p_##name = GetProcAddress(mod, #name)

int wdoc_init(void) {
    HMODULE hU, hG, hK, hC, hR, hO;
    WNDCLASSA wc;
    if (g_inited) return 0;
    hU = LoadLibraryA("user32.dll");   if (!hU) { g_step = -1; return -1; }
    hG = LoadLibraryA("gdi32.dll");    if (!hG) { g_step = -2; return -2; }
    hK = LoadLibraryA("kernel32.dll"); if (!hK) { g_step = -3; return -3; }
    hR = LoadLibraryA("msftedit.dll"); if (!hR) { g_step = -4; return -4; }   /* registers RICHEDIT50W */
    hC = LoadLibraryA("comdlg32.dll");
    hO = LoadLibraryA("ole32.dll");

    BIND(hU, CreateWindowExA); BIND(hU, SendMessageA); BIND(hU, DefWindowProcA); BIND(hU, RegisterClassA);
    BIND(hU, DestroyWindow); BIND(hU, SetWindowPos); BIND(hU, MoveWindow); BIND(hU, ShowWindow);
    BIND(hU, SetFocus); BIND(hU, GetFocus); BIND(hU, IsChild); BIND(hU, EnableWindow);
    BIND(hU, InvalidateRect); BIND(hU, GetClientRect); BIND(hU, GetWindowLongA); BIND(hU, SetWindowLongA);
    BIND(hU, GetParent); BIND(hU, BeginPaint); BIND(hU, EndPaint); BIND(hU, GetDC); BIND(hU, ReleaseDC);
    BIND(hU, FillRect); BIND(hU, DrawTextA); BIND(hU, LoadCursorA); BIND(hU, SetCursor);
    BIND(hU, TrackMouseEvent); BIND(hU, ClientToScreen); BIND(hU, CreatePopupMenu); BIND(hU, AppendMenuA);
    BIND(hU, TrackPopupMenu); BIND(hU, DestroyMenu);
    BIND(hK, GetModuleHandleA); BIND(hK, CreateFileA); BIND(hK, ReadFile); BIND(hK, WriteFile);
    BIND(hK, GetFileSize); BIND(hK, CloseHandle); BIND(hK, GetProcessHeap); BIND(hK, HeapAlloc);
    BIND(hK, HeapReAlloc); BIND(hK, HeapFree); BIND(hK, GetTempPathA); BIND(hK, GetCurrentProcessId);
    BIND(hK, DeleteFileA); BIND(hK, MultiByteToWideChar);
    BIND(hG, GetDeviceCaps); BIND(hG, CreateFontA); BIND(hG, CreateSolidBrush); BIND(hG, CreatePen);
    BIND(hG, SelectObject); BIND(hG, DeleteObject); BIND(hG, SetTextColor); BIND(hG, SetBkMode);
    BIND(hG, MoveToEx); BIND(hG, LineTo); BIND(hG, Rectangle); BIND(hG, Ellipse); BIND(hG, Polygon);
    BIND(hG, TextOutW); BIND(hG, CreateCompatibleDC); BIND(hG, CreateCompatibleBitmap); BIND(hG, BitBlt);
    BIND(hG, DeleteDC); BIND(hG, CreateDCA); BIND(hG, CreateEnhMetaFileA); BIND(hG, CloseEnhMetaFile);
    BIND(hG, DeleteEnhMetaFile); BIND(hG, GetWinMetaFileBits); BIND(hG, CreateICA); BIND(hG, GetEnhMetaFileBits); BIND(hG, SetEnhMetaFileBits); BIND(hG, EnumFontFamiliesExA); BIND(hG, SetMapMode);
    if (hC) { BIND(hC, ChooseColorA); BIND(hC, GetOpenFileNameA); }
    if (hO) { BIND(hO, OleInitialize); }

    if (!p_CreateWindowExA || !p_SendMessageA || !p_RegisterClassA || !p_HeapAlloc || !p_CreateEnhMetaFileA) {
        g_step = -5; return -5;
    }
    /* Pictures inside RTF are OLE static objects to RichEdit; it needs OLE up
       on this thread. Harmless if the RTL already did it (returns S_FALSE). */
    if (p_OleInitialize) p_OleInitialize(0);

    g_heap = p_GetProcessHeap();
    g_inst = p_GetModuleHandleA(0);
    /* The screen is the UI's device (toolbar sizes)... */
    g_scrDC = p_CreateDCA("DISPLAY", 0, 0, 0);
    if (!g_scrDC) { g_step = -6; return -6; }
    g_dpi = p_GetDeviceCaps(g_scrDC, LOGPIXELSY);
    if (g_dpi < 96) g_dpi = 96;
    /* ...but text is MEASURED on the default printer. At 96 dpi glyph widths are
       hinted to whole pixels, so a line measured on screen prints wider at true
       scale and runs off the right edge of the report IMAGE. Measuring at
       printer resolution keeps editor line breaks, pagination and the printed
       page in step (WordPad does the same). No printer -> the screen. */
    {   HMODULE hW = LoadLibraryA("winspool.drv");
        char pn[260]; DWORD pl = sizeof(pn);
        if (hW) *(FARPROC*)&p_GetDefaultPrinterA = GetProcAddress(hW, "GetDefaultPrinterA");
        if (p_GetDefaultPrinterA && p_CreateICA && p_GetDefaultPrinterA(pn, &pl))
            g_refDC = p_CreateICA("WINSPOOL", pn, 0, 0);
        if (!g_refDC) g_refDC = g_scrDC;
    }
    g_curArrow = p_LoadCursorA(0, (const char*)IDC_ARROW);

    zero(&wc, sizeof(wc));
    wc.lpfnWndProc   = host_proc;
    wc.hInstance     = g_inst;
    wc.hCursor       = g_curArrow;
    wc.lpszClassName = "myWordDocHost";
    p_RegisterClassA(&wc);          /* fails harmlessly if already registered */

    g_fUI   = p_CreateFontA(-px(12), 0, 0, 0, 400, 0, 0, 0, DEFAULT_CHARSET, 0, 0, 5, 0, "Segoe UI");
    g_fBold = p_CreateFontA(-px(15), 0, 0, 0, 700, 0, 0, 0, DEFAULT_CHARSET, 0, 0, 5, 0, "Segoe UI");
    g_fItal = p_CreateFontA(-px(16), 0, 0, 0, 400, 1, 0, 0, DEFAULT_CHARSET, 0, 0, 5, 0, "Georgia");
    g_fUnd  = p_CreateFontA(-px(15), 0, 0, 0, 400, 0, 1, 0, DEFAULT_CHARSET, 0, 0, 5, 0, "Segoe UI");
    g_fStrk = p_CreateFontA(-px(15), 0, 0, 0, 400, 0, 0, 1, DEFAULT_CHARSET, 0, 0, 5, 0, "Segoe UI");
    g_fIcon = p_CreateFontA(-px(15), 0, 0, 0, 400, 0, 0, 0, DEFAULT_CHARSET, 0, 0, 5, 0, "Segoe MDL2 Assets");
    {   int i; for (i = 0; i < 16; i++) g_custColors[i] = 0x00FFFFFF; }

    g_inited = 1;
    return 0;
}

int wdoc_last_step(void) { return g_step; }
int wdoc_struct_sizes(void) { return (int)sizeof(CF2A) * 1000 + (int)sizeof(PF2); }  /* expect 84188 */

/* ---- helpers ------------------------------------------------------------- */
static WDOC* D(int h) {
    if (h < 1 || h > WD_MAX || !g_d[h].edit) return 0;
    return &g_d[h];
}
static long E(WDOC* d, UINT m, unsigned long wp, unsigned long lp) {
    return d && d->edit ? p_SendMessageA(d->edit, m, wp, lp) : 0;
}
static int slot_of_host(void* w) {
    int i; for (i = 1; i <= WD_MAX; i++) if (g_d[i].host == w && w) return i; return 0;
}

/* ---- streaming ----------------------------------------------------------- */
typedef struct { const char* p; long len, pos; } MEMIN;

static DWORD WINAPI cb_in(DWORD cookie, BYTE* buf, long cb, long* pcb) {
    MEMIN* m = (MEMIN*)cookie;
    long n = m->len - m->pos;
    if (n > cb) n = cb;
    if (n < 0) n = 0;
    {   long i; for (i = 0; i < n; i++) buf[i] = (BYTE)m->p[m->pos + i]; }
    m->pos += n;
    *pcb = n;
    return 0;
}
static DWORD WINAPI cb_out(DWORD cookie, BYTE* buf, long cb, long* pcb) {
    WDOC* d = (WDOC*)cookie;
    if (d->len + cb + 1 > d->cap) {
        long nc = d->cap ? d->cap * 2 : 65536;
        char* nb;
        while (nc < d->len + cb + 1) nc *= 2;
        nb = (char*)mem_grow(d->buf, nc);
        if (!nb) { *pcb = 0; return 1; }
        d->buf = nb; d->cap = nc;
    }
    {   long i; for (i = 0; i < cb; i++) d->buf[d->len + i] = (char)buf[i]; }
    d->len += cb;
    d->buf[d->len] = 0;
    *pcb = cb;
    return 0;
}
static int stream_in(WDOC* d, const char* p, long len, int selection) {
    MEMIN m; EDITSTREAM es; int fmt;
    m.p = p; m.len = len; m.pos = 0;
    es.dwCookie = (DWORD)&m; es.dwError = 0; es.pfnCallback = cb_in;
    /* "{\rtf" is RTF; anything else is plain text in the ANSI code page */
    fmt = (len >= 5 && p[0] == '{' && p[1] == '\\' && p[2] == 'r' && p[3] == 't' && p[4] == 'f') ? SF_RTF : SF_TEXT;
    if (selection) fmt |= SFF_SELECTION;
    E(d, EM_STREAMIN, fmt, (unsigned long)&es);
    return es.dwError == 0 ? 1 : 0;
}

/* ---- layout -------------------------------------------------------------- */
static int btn_w(int b) {
    if (b == B_SEP)  return px(9);
    if (b == B_FONT) return px(150);
    if (b == B_SIZE) return px(52);
    return px(TB_BTN);
}
/* lays the toolbar out in rows that wrap at the host width; returns its height */
static int layout_toolbar(WDOC* d, int width) {
    int i, x = px(6), row = 0, rowH = px(TB_ROWH);
    if (!(d->flags & WDF_TOOLBAR)) return 0;
    for (i = 0; g_layout[i] >= 0 && i < NBTN; i++) {
        int b = g_layout[i], w = btn_w(b);
        if (b == B_SEP && x == px(6)) { d->br[i].left = d->br[i].right = -1; continue; }
        if (x + w > width - px(4) && x > px(6)) {
            row++; x = px(6);
            if (b == B_SEP) { d->br[i].left = d->br[i].right = -1; continue; }
        }
        d->br[i].left   = x;
        d->br[i].top    = row * rowH + (rowH - px(TB_BTN)) / 2 + px(1);
        d->br[i].right  = x + w;
        d->br[i].bottom = d->br[i].top + px(TB_BTN);
        x += w + px(TB_GAP);
    }
    return (row + 1) * rowH + px(2);
}
static void layout(WDOC* d) {
    RECT rc; int w, h, ex, ew, i;
    if (!d->host) return;
    p_GetClientRect(d->host, &rc);
    w = rc.right; h = rc.bottom;
    d->tbH = layout_toolbar(d, w);
    for (i = 0; g_layout[i] >= 0; i++) {
        void* cb = g_layout[i] == B_FONT ? d->cbFont : g_layout[i] == B_SIZE ? d->cbSize : 0;
        if (cb) p_MoveWindow(cb, d->br[i].left, d->br[i].top + px(1), d->br[i].right - d->br[i].left, px(300), 1);
    }
    /* page view: the editor is a sheet of the printed width, centred on a desk */
    ex = 1; ew = w - 2;
    if ((d->flags & WDF_PAGEVIEW) && d->pageTw > 0) {
        int pagePx = d->pageTw * g_dpi / 1440 + px(48);     /* + the sheet's own margins */
        if (pagePx < ew - px(24)) { ex = (w - pagePx) / 2; ew = pagePx; }
    }
    p_MoveWindow(d->edit, ex, d->tbH + (d->flags & WDF_PAGEVIEW ? px(8) : 1), ew,
                 h - d->tbH - (d->flags & WDF_PAGEVIEW ? px(8) : 2), 1);
    p_InvalidateRect(d->host, 0, 0);
}

/* ---- reading the selection's format back into the toolbar ----------------- */
static void refresh_state(WDOC* d) {
    CF2A cf; PF2 pf; int i;
    if (!d->host || !(d->flags & WDF_TOOLBAR)) return;
    zero(&cf, sizeof(cf)); cf.cbSize = sizeof(cf);
    E(d, EM_GETCHARFORMAT, SCF_SELECTION, (unsigned long)&cf);
    zero(&pf, sizeof(pf)); pf.cbSize = sizeof(pf);
    E(d, EM_GETPARAFORMAT, 0, (unsigned long)&pf);
    for (i = 0; g_layout[i] >= 0; i++) {
        int b = g_layout[i], on = 0;
        switch (b) {
        case B_BOLD:    on = (cf.dwMask & CFM_BOLD)      && (cf.dwEffects & CFM_BOLD); break;
        case B_ITALIC:  on = (cf.dwMask & CFM_ITALIC)    && (cf.dwEffects & CFM_ITALIC); break;
        case B_UNDER:   on = (cf.dwMask & CFM_UNDERLINE) && (cf.dwEffects & CFM_UNDERLINE); break;
        case B_STRIKE:  on = (cf.dwMask & CFM_STRIKEOUT) && (cf.dwEffects & CFM_STRIKEOUT); break;
        case B_LEFT:    on = (pf.dwMask & PFM_ALIGNMENT) && (pf.wAlignment == 1 || pf.wAlignment == 0); break;
        case B_RIGHT:   on = (pf.dwMask & PFM_ALIGNMENT) && pf.wAlignment == 2; break;
        case B_CENTER:  on = (pf.dwMask & PFM_ALIGNMENT) && pf.wAlignment == 3; break;
        case B_JUSTIFY: on = (pf.dwMask & PFM_ALIGNMENT) && pf.wAlignment == 4; break;
        case B_BULLETS: on = (pf.dwMask & PFM_NUMBERING) && pf.wNumbering == 1; break;
        case B_NUMBERS: on = (pf.dwMask & PFM_NUMBERING) && pf.wNumbering >= 2; break;
        }
        if (d->state[i] != on) { d->state[i] = on; p_InvalidateRect(d->host, &d->br[i], 0); }
    }
    /* font + size combos */
    if (d->cbFont) {
        long k = (cf.dwMask & CFM_FACE) ? p_SendMessageA(d->cbFont, CB_FINDSTRINGEXACT, (unsigned long)-1, (unsigned long)cf.szFaceName) : -1;
        p_SendMessageA(d->cbFont, CB_SETCURSEL, (unsigned long)k, 0);
    }
    if (d->cbSize) {
        long k = -1;
        if (cf.dwMask & CFM_SIZE) {
            char s[8]; int pt = (int)(cf.yHeight / 20), n = 0;
            if (pt >= 100) s[n++] = (char)('0' + pt / 100);
            if (pt >= 10)  s[n++] = (char)('0' + (pt / 10) % 10);
            s[n++] = (char)('0' + pt % 10); s[n] = 0;
            k = p_SendMessageA(d->cbSize, CB_FINDSTRINGEXACT, (unsigned long)-1, (unsigned long)s);
        }
        p_SendMessageA(d->cbSize, CB_SETCURSEL, (unsigned long)k, 0);
    }
}

/* ---- formatting primitives (shared by the toolbar and the Clarion API) ---- */
static void set_char(WDOC* d, DWORD mask, DWORD effects, CF2A* src) {
    CF2A cf;
    if (src) cf = *src; else zero(&cf, sizeof(cf));
    cf.cbSize = sizeof(cf); cf.dwMask = mask; cf.dwEffects = effects;
    E(d, EM_SETCHARFORMAT, SCF_SELECTION, (unsigned long)&cf);
}
static void effect(WDOC* d, DWORD bit, int how) {     /* how: 0 off, 1 on, 2 toggle */
    CF2A cf; int on;
    if (how == 2) {
        zero(&cf, sizeof(cf)); cf.cbSize = sizeof(cf);
        E(d, EM_GETCHARFORMAT, SCF_SELECTION, (unsigned long)&cf);
        on = !((cf.dwMask & bit) && (cf.dwEffects & bit));
    } else on = how;
    set_char(d, bit, on ? bit : 0, 0);
}
static void para_align(WDOC* d, int a) {
    PF2 pf; zero(&pf, sizeof(pf)); pf.cbSize = sizeof(pf);
    pf.dwMask = PFM_ALIGNMENT; pf.wAlignment = (WORD)a;
    E(d, EM_SETPARAFORMAT, 0, (unsigned long)&pf);
}
/* 0 none, 1 bullet, 2 1.2.3., 3 a.b.c., 4 A.B.C., 5 i.ii., 6 I.II. ; toggles off if already that */
static void para_numbering(WDOC* d, int style, int toggle) {
    PF2 pf, cur;
    zero(&cur, sizeof(cur)); cur.cbSize = sizeof(cur);
    E(d, EM_GETPARAFORMAT, 0, (unsigned long)&cur);
    if (toggle && (cur.dwMask & PFM_NUMBERING) &&
        ((style == 1 && cur.wNumbering == 1) || (style >= 2 && cur.wNumbering >= 2))) style = 0;
    zero(&pf, sizeof(pf)); pf.cbSize = sizeof(pf);
    pf.dwMask = PFM_NUMBERING | PFM_OFFSET | PFM_NUMBERINGSTYLE | PFM_NUMBERINGTAB | PFM_NUMBERINGSTART;
    pf.wNumbering = (WORD)style;
    pf.dxOffset = style ? 360 : 0;
    pf.wNumberingStyle = style >= 2 ? 0x0200 /* PFNS_PERIOD */ : 0;
    pf.wNumberingTab = style ? 360 : 0;
    pf.wNumberingStart = 1;
    E(d, EM_SETPARAFORMAT, 0, (unsigned long)&pf);
}
static void para_indent(WDOC* d, int deltaTw) {
    PF2 pf; zero(&pf, sizeof(pf)); pf.cbSize = sizeof(pf);
    pf.dwMask = PFM_OFFSETINDENT; pf.dxStartIndent = deltaTw;
    E(d, EM_SETPARAFORMAT, 0, (unsigned long)&pf);
}
static void set_color(WDOC* d, DWORD c, int back) {
    CF2A cf; zero(&cf, sizeof(cf)); cf.cbSize = sizeof(cf);
    if (back) { cf.dwMask = CFM_BACKCOLOR; if (c == 0xFFFFFFFF) cf.dwEffects = CFE_AUTOBACKCOLOR; else cf.crBackColor = c; }
    else      { cf.dwMask = CFM_COLOR;     if (c == 0xFFFFFFFF) cf.dwEffects = CFE_AUTOCOLOR;     else cf.crTextColor = c; }
    E(d, EM_SETCHARFORMAT, SCF_SELECTION, (unsigned long)&cf);
}
static void set_face(WDOC* d, const char* face) {
    CF2A cf; zero(&cf, sizeof(cf)); cf.cbSize = sizeof(cf);
    cf.dwMask = CFM_FACE | CFM_CHARSET; cf.bCharSet = DEFAULT_CHARSET;
    scpy(cf.szFaceName, face, 32);
    E(d, EM_SETCHARFORMAT, SCF_SELECTION, (unsigned long)&cf);
}
static void set_size(WDOC* d, int pt10) {      /* tenths of a point */
    CF2A cf; zero(&cf, sizeof(cf)); cf.cbSize = sizeof(cf);
    cf.dwMask = CFM_SIZE; cf.yHeight = pt10 * 2;
    E(d, EM_SETCHARFORMAT, SCF_SELECTION, (unsigned long)&cf);
}

/* ---- pictures -------------------------------------------------------------
   A picture is inserted as RTF - {\pict\pngblip ...hex...} - streamed into the
   selection. That is the same thing Word writes, so the BLOB stays plain RTF
   and the picture travels with the text. */
static unsigned long be32(const BYTE* p) { return ((unsigned long)p[0] << 24) | ((unsigned long)p[1] << 16) | ((unsigned long)p[2] << 8) | p[3]; }
static unsigned long le32(const BYTE* p) { return ((unsigned long)p[3] << 24) | ((unsigned long)p[2] << 16) | ((unsigned long)p[1] << 8) | p[0]; }
static int le16s(const BYTE* p) { return (short)(p[0] | (p[1] << 8)); }

static char* put(char* o, const char* s) { while (*s) *o++ = *s++; return o; }
static char* putn(char* o, long v) {
    char t[12]; int n = 0;
    if (v < 0) { *o++ = '-'; v = -v; }
    do { t[n++] = (char)('0' + v % 10); v /= 10; } while (v);
    while (n) *o++ = t[--n];
    return o;
}

/* returns 1 ok, -1 cannot read, -2 unknown format, -3 out of memory */
int wdoc_insert_image(int h, const char* path, int maxWidthTw) {
    WDOC* d = D(h);
    void* f; DWORD sz, got = 0; BYTE* data; char* rtf; char* o;
    long skip = 0, wPx = 0, hPx = 0, picw = 0, pich = 0, goalW, goalH;
    const char* kind = 0;
    static const char hex[] = "0123456789abcdef";
    long i;
    if (!d) return 0;
    f = p_CreateFileA(path, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, 0, 0);
    if (!f || f == (void*)-1) return -1;
    sz = p_GetFileSize(f, 0);
    data = (BYTE*)mem_alloc((long)sz + 4);
    if (!data) { p_CloseHandle(f); return -3; }
    p_ReadFile(f, data, sz, &got, 0);
    p_CloseHandle(f);
    if (got < 32) { mem_free(data); return -1; }

    if (data[0] == 0x89 && data[1] == 'P' && data[2] == 'N' && data[3] == 'G') {
        kind = "\\pngblip"; wPx = (long)be32(data + 16); hPx = (long)be32(data + 20);
    } else if (data[0] == 0xFF && data[1] == 0xD8) {
        unsigned long p = 2;
        kind = "\\jpegblip";
        while (p + 9 < got) {                          /* walk to the SOFn marker */
            BYTE mk;
            if (data[p] != 0xFF) { p++; continue; }
            mk = data[p + 1];
            if (mk >= 0xC0 && mk <= 0xCF && mk != 0xC4 && mk != 0xC8 && mk != 0xCC) {
                hPx = (data[p + 5] << 8) | data[p + 6];
                wPx = (data[p + 7] << 8) | data[p + 8];
                break;
            }
            if (mk == 0xD8 || mk == 0x01 || (mk >= 0xD0 && mk <= 0xD7)) { p += 2; continue; }
            p += 2 + ((data[p + 2] << 8) | data[p + 3]);
        }
    } else if (data[0] == 'B' && data[1] == 'M') {
        kind = "\\dibitmap0"; skip = 14;               /* RTF wants the DIB, not the file header */
        wPx = (long)le32(data + 18); hPx = (long)le32(data + 22); if (hPx < 0) hPx = -hPx;
    } else if (le32(data) == 1 && le32(data + 40) == 0x464D4520) {   /* EMF: " EMF" signature */
        RECT fr; kind = "\\emfblip";
        fr.left = (long)le32(data + 24); fr.top = (long)le32(data + 28);
        fr.right = (long)le32(data + 32); fr.bottom = (long)le32(data + 36);
        picw = fr.right - fr.left; pich = fr.bottom - fr.top;         /* .01 mm */
        wPx = picw * 96 / 2540; hPx = pich * 96 / 2540;
    } else if (le32(data) == 0x9AC6CDD7) {                            /* placeable WMF */
        int inch = data[14] | (data[15] << 8);
        long ww = le16s(data + 10) - le16s(data + 6), hh = le16s(data + 12) - le16s(data + 8);
        if (inch <= 0) inch = 1440;
        if (ww < 0) ww = -ww; if (hh < 0) hh = -hh;
        kind = "\\wmetafile8"; skip = 22;
        picw = ww * 2540 / inch; pich = hh * 2540 / inch;
        wPx = ww * 96 / inch; hPx = hh * 96 / inch;
    }
    if (!kind || wPx <= 0 || hPx <= 0) { mem_free(data); return -2; }

    goalW = wPx * 15; goalH = hPx * 15;               /* 96 dpi pixels -> twips */
    if (maxWidthTw <= 0) maxWidthTw = d->pageTw > 0 ? d->pageTw : 9360;
    if (goalW > maxWidthTw) { goalH = goalH * maxWidthTw / goalW; goalW = maxWidthTw; }
    if (!picw) { picw = wPx; pich = hPx; }

    rtf = (char*)mem_alloc((long)(got - skip) * 2 + (long)(got - skip) / 32 + 256);   /* hex + a CRLF per 64 bytes */
    if (!rtf) { mem_free(data); return -3; }
    o = put(rtf, "{\\rtf1{\\pict");
    o = put(o, kind);
    o = put(o, "\\picw"); o = putn(o, picw); o = put(o, "\\pich"); o = putn(o, pich);
    o = put(o, "\\picwgoal"); o = putn(o, goalW); o = put(o, "\\pichgoal"); o = putn(o, goalH);
    o = put(o, "\r\n");
    for (i = skip; i < (long)got; i++) {
        *o++ = hex[data[i] >> 4]; *o++ = hex[data[i] & 15];
        if (((i - skip) & 63) == 63) { *o++ = '\r'; *o++ = '\n'; }
    }
    o = put(o, "}}");
    *o = 0;
    stream_in(d, rtf, (long)(o - rtf), 1);
    mem_free(rtf); mem_free(data);
    d->seq++;
    return 1;
}

/* a rows x cols grid with thin borders, spread across the line width */
int wdoc_insert_table(int h, int rows, int cols, int widthTw) {
    WDOC* d = D(h);
    char* rtf; char* o; int r, c; long cw;
    if (!d || rows < 1 || cols < 1 || rows > 200 || cols > 30) return 0;
    if (widthTw <= 0) widthTw = d->pageTw > 0 ? d->pageTw : 9360;
    cw = widthTw / cols;
    rtf = (char*)mem_alloc(rows * (cols * 160 + 64) + 64);
    if (!rtf) return 0;
    o = put(rtf, "{\\rtf1");
    for (r = 0; r < rows; r++) {
        o = put(o, "\\trowd\\trgaph108\\trleft0");
        for (c = 0; c < cols; c++) {
            o = put(o, "\\clbrdrt\\brdrs\\brdrw10\\clbrdrl\\brdrs\\brdrw10\\clbrdrb\\brdrs\\brdrw10\\clbrdrr\\brdrs\\brdrw10\\cellx");
            o = putn(o, cw * (c + 1));
        }
        o = put(o, "\\pard\\intbl");
        for (c = 0; c < cols; c++) o = put(o, "\\cell");
        o = put(o, "\\row");
    }
    o = put(o, "\\pard\\par}");
    *o = 0;
    stream_in(d, rtf, (long)(o - rtf), 1);
    mem_free(rtf);
    d->seq++;
    return 1;
}

/* ---- toolbar actions ------------------------------------------------------ */
static void pick_colour(WDOC* d, int back) {
    CHOOSECOLORA cc;
    if (!p_ChooseColorA) return;
    zero(&cc, sizeof(cc));
    cc.lStructSize = sizeof(cc); cc.hwndOwner = d->host;
    cc.rgbResult = back ? d->back : d->fore;
    cc.lpCustColors = g_custColors; cc.Flags = CC_RGBINIT | CC_FULLOPEN;
    if (p_ChooseColorA(&cc)) {
        if (back) d->back = cc.rgbResult; else d->fore = cc.rgbResult;
        set_color(d, cc.rgbResult, back);
        p_InvalidateRect(d->host, 0, 0);
    }
}
static void pick_picture(WDOC* d) {
    OPENFILENAMEA of; char file[520];
    if (!p_GetOpenFileNameA) return;
    zero(&of, sizeof(of)); file[0] = 0;
    of.lStructSize = 76;            /* OPENFILENAME_SIZE_VERSION_400 */
    of.hwndOwner = d->host;
    of.lpstrFilter = "Pictures (*.png;*.jpg;*.jpeg;*.bmp;*.emf;*.wmf)\0*.png;*.jpg;*.jpeg;*.bmp;*.emf;*.wmf\0All files\0*.*\0";
    of.lpstrFile = file; of.nMaxFile = sizeof(file);
    of.lpstrTitle = "Insert picture";
    of.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_HIDEREADONLY | OFN_NOCHANGEDIR;
    if (p_GetOpenFileNameA(&of)) wdoc_insert_image((int)(d - g_d), file, 0);
}
static void pick_table(WDOC* d, RECT* br) {
    static const int dims[][2] = { {2,2}, {2,3}, {3,3}, {3,4}, {4,4}, {5,3}, {6,4}, {8,5} };
    void* m; POINT pt; int i, r;
    char lab[24];
    m = p_CreatePopupMenu();
    for (i = 0; i < 8; i++) {
        char* o = lab;
        o = putn(o, dims[i][0]); o = put(o, " rows x "); o = putn(o, dims[i][1]); o = put(o, " columns"); *o = 0;
        p_AppendMenuA(m, MF_STRING, (UINT)(i + 1), lab);
    }
    pt.x = br->left; pt.y = br->bottom;
    p_ClientToScreen(d->host, &pt);
    r = p_TrackPopupMenu(m, TPM_RETURNCMD | TPM_LEFTALIGN, pt.x, pt.y, 0, d->host, 0);
    p_DestroyMenu(m);
    if (r >= 1 && r <= 8) wdoc_insert_table((int)(d - g_d), dims[r - 1][0], dims[r - 1][1], 0);
}
static void run_button(WDOC* d, int b, RECT* br) {
    switch (b) {
    case B_BOLD:    effect(d, CFM_BOLD, 2); break;
    case B_ITALIC:  effect(d, CFM_ITALIC, 2); break;
    case B_UNDER:   effect(d, CFM_UNDERLINE, 2); break;
    case B_STRIKE:  effect(d, CFM_STRIKEOUT, 2); break;
    case B_COLOR:   pick_colour(d, 0); break;
    case B_HILITE:  pick_colour(d, 1); break;
    case B_LEFT:    para_align(d, 1); break;
    case B_CENTER:  para_align(d, 3); break;
    case B_RIGHT:   para_align(d, 2); break;
    case B_JUSTIFY: para_align(d, 4); break;
    case B_BULLETS: para_numbering(d, 1, 1); break;
    case B_NUMBERS: para_numbering(d, 2, 1); break;
    case B_OUTDENT: para_indent(d, -360); break;
    case B_INDENT:  para_indent(d, 360); break;
    case B_PICTURE: pick_picture(d); break;
    case B_TABLE:   pick_table(d, br); break;
    case B_UNDO:    E(d, EM_UNDO, 0, 0); break;
    case B_REDO:    E(d, EM_REDO, 0, 0); break;
    }
    d->lastCmd = b; d->lastPick++;
    p_SetFocus(d->edit);
    refresh_state(d);
}

/* ---- painting the toolbar ------------------------------------------------- */
static void hline(void* dc, int x1, int x2, int y) { p_MoveToEx(dc, x1, y, 0); p_LineTo(dc, x2, y); }
static void fill(void* dc, int l, int t, int r, int b, DWORD c) {
    RECT rc; void* br = p_CreateSolidBrush(c);
    rc.left = l; rc.top = t; rc.right = r; rc.bottom = b;
    p_FillRect(dc, &rc, br); p_DeleteObject(br);
}
static void text_in(void* dc, void* font, const char* s, RECT* r, DWORD ink) {
    void* of = p_SelectObject(dc, font);
    RECT t = *r;
    p_SetTextColor(dc, ink);
    p_DrawTextA(dc, s, -1, &t, DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX);
    p_SelectObject(dc, of);
}
static void glyph(void* dc, WCHAR g, RECT* r, DWORD ink) {
    void* of = p_SelectObject(dc, g_fIcon);
    int cx = (r->left + r->right) / 2 - px(8), cy = (r->top + r->bottom) / 2 - px(8);
    p_SetTextColor(dc, ink);
    p_TextOutW(dc, cx, cy, &g, 1);
    p_SelectObject(dc, of);
}
/* four "lines of text" drawn with the requested alignment */
static void lines_icon(void* dc, RECT* r, int align, int bullets) {
    int cx = (r->left + r->right) / 2, cy = (r->top + r->bottom) / 2, i;
    int full = px(14), part = px(9);
    for (i = 0; i < 4; i++) {
        int y = cy - px(6) + i * px(4), w = (i & 1) ? part : full, x1;
        if (bullets) {
            int bx = cx - px(7);
            if (bullets == 1) fill(dc, bx, y - px(1), bx + px(2), y + px(1), C_INK);
            else { fill(dc, bx, y - px(1), bx + px(1), y + px(1), C_INK); }
            x1 = cx - px(3); w = px(10);
            if (i == 3) break;
            hline(dc, x1, x1 + w, y);
            continue;
        }
        if (align == 2)      x1 = cx + full / 2 - w;
        else if (align == 3) x1 = cx - w / 2;
        else                 x1 = cx - full / 2;
        if (align == 4) w = full;
        hline(dc, x1, x1 + w, y);
    }
}
static void indent_icon(void* dc, RECT* r, int in) {
    int cx = (r->left + r->right) / 2, cy = (r->top + r->bottom) / 2, i;
    POINT tri[3];
    for (i = 0; i < 4; i++) {
        int y = cy - px(6) + i * px(4);
        if (i == 0 || i == 3) hline(dc, cx - px(7), cx + px(7), y);
        else hline(dc, cx - px(1), cx + px(7), y);
    }
    if (in) { tri[0].x = cx - px(7); tri[0].y = cy - px(3); tri[1].x = cx - px(3); tri[1].y = cy; tri[2].x = cx - px(7); tri[2].y = cy + px(3); }
    else    { tri[0].x = cx - px(3); tri[0].y = cy - px(3); tri[1].x = cx - px(7); tri[1].y = cy; tri[2].x = cx - px(3); tri[2].y = cy + px(3); }
    p_Polygon(dc, tri, 3);
}
static void picture_icon(void* dc, RECT* r) {
    int cx = (r->left + r->right) / 2, cy = (r->top + r->bottom) / 2;
    void* ob = p_SelectObject(dc, p_CreateSolidBrush(0x00FFFFFF));
    POINT m[3];
    p_Rectangle(dc, cx - px(8), cy - px(6), cx + px(8), cy + px(7));
    p_DeleteObject(p_SelectObject(dc, p_CreateSolidBrush(0x0000A5F5)));    /* sun, amber */
    p_Ellipse(dc, cx + px(1), cy - px(4), cx + px(5), cy);
    p_DeleteObject(p_SelectObject(dc, p_CreateSolidBrush(0x00609B10)));    /* hill, green */
    m[0].x = cx - px(7); m[0].y = cy + px(6); m[1].x = cx - px(2); m[1].y = cy - px(1); m[2].x = cx + px(5); m[2].y = cy + px(6);
    p_Polygon(dc, m, 3);
    p_DeleteObject(p_SelectObject(dc, ob));
}
static void table_icon(void* dc, RECT* r) {
    int cx = (r->left + r->right) / 2, cy = (r->top + r->bottom) / 2, i;
    void* ob = p_SelectObject(dc, p_CreateSolidBrush(0x00FFFFFF));
    p_Rectangle(dc, cx - px(8), cy - px(7), cx + px(8), cy + px(7));
    p_DeleteObject(p_SelectObject(dc, ob));
    fill(dc, cx - px(8), cy - px(7), cx + px(8), cy - px(3), 0x00E6B98A);  /* header row tint */
    for (i = 1; i < 3; i++) hline(dc, cx - px(8), cx + px(8), cy - px(7) + i * px(14) / 3);
    for (i = 1; i < 3; i++) { int x = cx - px(8) + i * px(16) / 3; p_MoveToEx(dc, x, cy - px(7), 0); p_LineTo(dc, x, cy + px(7)); }
}
static void paint_button(WDOC* d, void* dc, int i) {
    int b = g_layout[i];
    RECT r = d->br[i];
    DWORD ink = C_INK;
    if (r.right <= r.left || b == B_FONT || b == B_SIZE) return;
    if (b == B_SEP) {
        int x = (r.left + r.right) / 2;
        fill(dc, x, r.top + px(3), x + 1, r.bottom - px(3), C_BARLINE);
        return;
    }
    if (d->state[i] || d->down == i) {
        void* pen = p_CreatePen(PS_SOLID, 1, C_ONLINE);
        void* br  = p_CreateSolidBrush(C_ON);
        void* op = p_SelectObject(dc, pen); void* ob = p_SelectObject(dc, br);
        p_Rectangle(dc, r.left, r.top, r.right, r.bottom);
        p_SelectObject(dc, op); p_SelectObject(dc, ob); p_DeleteObject(pen); p_DeleteObject(br);
    } else if (d->hot == i) {
        fill(dc, r.left, r.top, r.right, r.bottom, C_HOVER);
    }
    if (b == B_UNDO && !E(d, EM_CANUNDO, 0, 0)) ink = C_DIM;
    if (b == B_REDO && !E(d, EM_CANREDO, 0, 0)) ink = C_DIM;
    {
        void* pen = p_CreatePen(PS_SOLID, px(1) < 2 ? 1 : 2, ink);
        void* br  = p_CreateSolidBrush(ink);
        void* op = p_SelectObject(dc, pen); void* ob = p_SelectObject(dc, br);
        switch (b) {
        case B_BOLD:    text_in(dc, g_fBold, "B", &r, ink); break;
        case B_ITALIC:  text_in(dc, g_fItal, "I", &r, ink); break;
        case B_UNDER:   text_in(dc, g_fUnd,  "U", &r, ink); break;
        case B_STRIKE:  text_in(dc, g_fStrk, "S", &r, ink); break;
        case B_COLOR: {
            RECT t = r; t.bottom -= px(5);
            text_in(dc, g_fBold, "A", &t, ink);
            fill(dc, r.left + px(5), r.bottom - px(7), r.right - px(5), r.bottom - px(4), d->fore);
            break; }
        case B_HILITE: {
            RECT t = r; t.bottom -= px(5);
            text_in(dc, g_fUI, "ab", &t, ink);
            fill(dc, r.left + px(5), r.bottom - px(7), r.right - px(5), r.bottom - px(4), d->back);
            break; }
        case B_LEFT:    lines_icon(dc, &r, 1, 0); break;
        case B_CENTER:  lines_icon(dc, &r, 3, 0); break;
        case B_RIGHT:   lines_icon(dc, &r, 2, 0); break;
        case B_JUSTIFY: lines_icon(dc, &r, 4, 0); break;
        case B_BULLETS: lines_icon(dc, &r, 1, 1); break;
        case B_NUMBERS: lines_icon(dc, &r, 1, 2); break;
        case B_OUTDENT: indent_icon(dc, &r, 0); break;
        case B_INDENT:  indent_icon(dc, &r, 1); break;
        case B_PICTURE: { void* p2 = p_CreatePen(PS_SOLID, 1, ink); void* o2 = p_SelectObject(dc, p2); picture_icon(dc, &r); p_SelectObject(dc, o2); p_DeleteObject(p2); break; }
        case B_TABLE:   { void* p2 = p_CreatePen(PS_SOLID, 1, ink); void* o2 = p_SelectObject(dc, p2); table_icon(dc, &r); p_SelectObject(dc, o2); p_DeleteObject(p2); break; }
        case B_UNDO:    glyph(dc, 0xE7A7, &r, ink); break;
        case B_REDO:    glyph(dc, 0xE7A6, &r, ink); break;
        }
        p_SelectObject(dc, op); p_SelectObject(dc, ob); p_DeleteObject(pen); p_DeleteObject(br);
    }
}
static void paint_host(WDOC* d) {
    PAINTSTRUCT ps; RECT rc; void* dc; void* mdc; void* bmp; void* ob; int i;
    dc = p_BeginPaint(d->host, &ps);
    p_GetClientRect(d->host, &rc);
    mdc = p_CreateCompatibleDC(dc);
    bmp = p_CreateCompatibleBitmap(dc, rc.right, rc.bottom);
    ob = p_SelectObject(mdc, bmp);
    p_SetBkMode(mdc, TRANSPARENT);
    /* desk / frame behind the editor */
    fill(mdc, 0, 0, rc.right, rc.bottom, (d->flags & WDF_PAGEVIEW) ? C_DESK : 0x00FFFFFF);
    if (d->tbH) {
        fill(mdc, 0, 0, rc.right, d->tbH, C_BAR);
        fill(mdc, 0, d->tbH - 1, rc.right, d->tbH, C_BARLINE);
        for (i = 0; g_layout[i] >= 0; i++) paint_button(d, mdc, i);
    }
    if (!(d->flags & WDF_NOBORDER)) {
        void* pen = p_CreatePen(PS_SOLID, 1, C_FRAME);
        void* op = p_SelectObject(mdc, pen);
        hline(mdc, 0, rc.right, 0); hline(mdc, 0, rc.right, rc.bottom - 1);
        p_MoveToEx(mdc, 0, 0, 0); p_LineTo(mdc, 0, rc.bottom);
        p_MoveToEx(mdc, rc.right - 1, 0, 0); p_LineTo(mdc, rc.right - 1, rc.bottom);
        p_SelectObject(mdc, op); p_DeleteObject(pen);
    }
    p_BitBlt(dc, 0, 0, rc.right, rc.bottom, mdc, 0, 0, 0x00CC0020 /*SRCCOPY*/);
    p_SelectObject(mdc, ob); p_DeleteObject(bmp); p_DeleteDC(mdc);
    p_EndPaint(d->host, &ps);
}
static int hit(WDOC* d, int x, int y) {
    int i;
    for (i = 0; g_layout[i] >= 0; i++) {
        int b = g_layout[i];
        if (b == B_SEP || b == B_FONT || b == B_SIZE) continue;
        if (x >= d->br[i].left && x < d->br[i].right && y >= d->br[i].top && y < d->br[i].bottom) return i;
    }
    return -1;
}

/* ---- the host window procedure: OUR window, so its notifications are ours -- */
static int WINAPI font_enum(const LOGFONTA* lf, const void* tm, DWORD type, long lp) {
    void* cb = (void*)lp;
    if (lf->lfFaceName[0] == '@') return 1;            /* vertical variants */
    if (p_SendMessageA(cb, CB_FINDSTRINGEXACT, (unsigned long)-1, (unsigned long)lf->lfFaceName) < 0)
        p_SendMessageA(cb, CB_ADDSTRING, 0, (unsigned long)lf->lfFaceName);
    return 1;
}
static long WINAPI host_proc(void* w, UINT m, unsigned long wp, unsigned long lp) {
    int s = slot_of_host(w);
    WDOC* d = s ? &g_d[s] : 0;
    if (!d) return p_DefWindowProcA(w, m, wp, lp);
    switch (m) {
    case WM_ERASEBKGND: return 1;
    case WM_PAINT:      paint_host(d); return 0;
    case WM_SIZE:       if (d->edit) layout(d); return 0;
    case WM_SETFOCUS:   if (d->edit) p_SetFocus(d->edit); return 0;
    case WM_MOUSEMOVE: {
        int x = (short)(lp & 0xFFFF), y = (short)(lp >> 16), i = hit(d, x, y);
        if (!d->tracking) {
            TRACKMOUSEEVENT t; t.cbSize = sizeof(t); t.dwFlags = TME_LEAVE; t.hwndTrack = w; t.dwHoverTime = 0;
            p_TrackMouseEvent(&t); d->tracking = 1;
        }
        if (i != d->hot) {
            if (d->hot >= 0) p_InvalidateRect(w, &d->br[d->hot], 0);
            d->hot = i;
            if (i >= 0) p_InvalidateRect(w, &d->br[i], 0);
        }
        return 0; }
    case WM_MOUSELEAVE:
        d->tracking = 0;
        if (d->hot >= 0) { p_InvalidateRect(w, &d->br[d->hot], 0); d->hot = -1; }
        return 0;
    case WM_LBUTTONDOWN: {
        int x = (short)(lp & 0xFFFF), y = (short)(lp >> 16), i = hit(d, x, y);
        if (i >= 0) { d->down = i; p_InvalidateRect(w, &d->br[i], 0); }
        return 0; }
    case WM_LBUTTONUP: {
        int x = (short)(lp & 0xFFFF), y = (short)(lp >> 16), i = hit(d, x, y), was = d->down;
        d->down = -1;
        if (was >= 0) p_InvalidateRect(w, &d->br[was], 0);
        if (i >= 0 && i == was && !(d->flags & WDF_READONLY)) run_button(d, g_layout[i], &d->br[i]);
        return 0; }
    case WM_COMMAND: {
        int id = (int)(wp & 0xFFFF), code = (int)(wp >> 16);
        if (id == ID_EDIT && code == EN_CHANGE) {
            d->seq++;
            p_InvalidateRect(w, 0, 0);       /* undo/redo enablement */
        } else if ((id == ID_FONT || id == ID_SIZE) && code == CBN_SELCHANGE) {
            void* cb = id == ID_FONT ? d->cbFont : d->cbSize;
            long k = p_SendMessageA(cb, CB_GETCURSEL, 0, 0);
            char txt[64];
            if (k >= 0) {
                p_SendMessageA(cb, CB_GETLBTEXT, (unsigned long)k, (unsigned long)txt);
                if (id == ID_FONT) set_face(d, txt);
                else { int v = 0, j; for (j = 0; txt[j] >= '0' && txt[j] <= '9'; j++) v = v * 10 + txt[j] - '0'; if (v > 0) set_size(d, v * 10); }
                d->lastPick++;
            }
        } else if ((id == ID_FONT || id == ID_SIZE) && code == CBN_CLOSEUP) {
            p_SetFocus(d->edit);
        }
        return 0; }
    case WM_NOTIFY: {
        NMHDR* n = (NMHDR*)lp;
        if (n->idFrom == ID_EDIT && n->code == EN_SELCHANGE) { d->selseq++; refresh_state(d); }
        return 0; }
    }
    return p_DefWindowProcA(w, m, wp, lp);
}

/* ========================================================================== */
/*  Creating and destroying                                                    */
/* ========================================================================== */
static void clip_children(void* w) {
    long st;
    if (!w || !p_GetWindowLongA) return;
    st = p_GetWindowLongA(w, GWL_STYLE);
    if (st & WS_CLIPCHILDREN) return;
    p_SetWindowLongA(w, GWL_STYLE, st | WS_CLIPCHILDREN);
    p_SetWindowPos(w, 0, 0, 0, 0, 0, SWP_NOSIZE | SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
}

/* parent == 0 makes an invisible document: no host, no toolbar - for reports */
int wdoc_create(int parent, int x, int y, int w, int h, int flags) {
    int s;
    WDOC* d;
    DWORD es = WS_CHILD | WS_VISIBLE | WS_VSCROLL | WS_TABSTOP | ES_MULTILINE | ES_AUTOVSCROLL | ES_WANTRETURN | ES_NOHIDESEL | ES_SAVESEL;
    if (!g_inited && wdoc_init() != 0) return 0;
    for (s = 1; s <= WD_MAX; s++) if (!g_d[s].edit) break;
    if (s > WD_MAX) return 0;
    d = &g_d[s];
    zero(d, sizeof(WDOC));
    d->flags = flags; d->hot = -1; d->down = -1;
    d->fore = 0x00262DDC;            /* red-ish default ink for the A bar  #DC2626 */
    d->back = 0x0000FFFF;            /* yellow highlighter                 */

    if (!parent) {
        d->flags = 0;
        d->edit = p_CreateWindowExA(0, "RICHEDIT50W", "", WS_POPUP | ES_MULTILINE | ES_WANTRETURN,
                                    0, 0, w > 0 ? w : 800, h > 0 ? h : 600, 0, 0, g_inst, 0);
        if (!d->edit) { g_step = -10; return 0; }
    } else {
        clip_children((void*)parent);
        d->host = p_CreateWindowExA(0, "myWordDocHost", "", WS_CHILD | WS_CLIPCHILDREN | WS_CLIPSIBLINGS,
                                    x, y, w, h, (void*)parent, 0, g_inst, 0);
        if (!d->host) { g_step = -11; return 0; }
        d->edit = p_CreateWindowExA(0, "RICHEDIT50W", "", es, 0, 0, 10, 10, d->host, (void*)ID_EDIT, g_inst, 0);
        if (!d->edit) { p_DestroyWindow(d->host); d->host = 0; g_step = -12; return 0; }
        if (flags & WDF_TOOLBAR) {
            static const char* sizes[] = { "8","9","10","11","12","14","16","18","20","22","24","26","28","36","48","72", 0 };
            LOGFONTA lf; int i;
            d->cbFont = p_CreateWindowExA(0, "COMBOBOX", "", WS_CHILD | WS_VISIBLE | WS_VSCROLL | CBS_DROPDOWNLIST | CBS_SORT | CBS_HASSTRINGS,
                                          0, 0, 10, 10, d->host, (void*)ID_FONT, g_inst, 0);
            d->cbSize = p_CreateWindowExA(0, "COMBOBOX", "", WS_CHILD | WS_VISIBLE | WS_VSCROLL | CBS_DROPDOWNLIST | CBS_HASSTRINGS,
                                          0, 0, 10, 10, d->host, (void*)ID_SIZE, g_inst, 0);
            p_SendMessageA(d->cbFont, WM_SETFONT, (unsigned long)g_fUI, 0);
            p_SendMessageA(d->cbSize, WM_SETFONT, (unsigned long)g_fUI, 0);
            p_SendMessageA(d->cbFont, CB_SETDROPPEDWIDTH, (unsigned long)px(220), 0);
            zero(&lf, sizeof(lf)); lf.lfCharSet = DEFAULT_CHARSET;
            p_EnumFontFamiliesExA(g_scrDC, &lf, font_enum, (long)d->cbFont, 0);
            for (i = 0; sizes[i]; i++) p_SendMessageA(d->cbSize, CB_ADDSTRING, 0, (unsigned long)sizes[i]);
        }
        p_SendMessageA(d->edit, EM_SETMARGINS, EC_LEFTMARGIN | EC_RIGHTMARGIN, (unsigned long)((px(12) << 16) | px(12)));
        p_SendMessageA(d->edit, EM_SETEVENTMASK, 0, ENM_CHANGE | ENM_SELCHANGE);
    }
    p_SendMessageA(d->edit, EM_EXLIMITTEXT, 0, 0x7FFFFFFF);
    if (flags & WDF_READONLY) p_SendMessageA(d->edit, EM_SETREADONLY, 1, 0);
    /* default typing font: Segoe UI 11pt */
    {   CF2A cf; zero(&cf, sizeof(cf)); cf.cbSize = sizeof(cf);
        cf.dwMask = CFM_FACE | CFM_SIZE | CFM_CHARSET | CFM_COLOR; cf.dwEffects = CFE_AUTOCOLOR;
        cf.yHeight = 220; cf.bCharSet = DEFAULT_CHARSET; scpy(cf.szFaceName, "Segoe UI", 32);
        p_SendMessageA(d->edit, EM_SETCHARFORMAT, SCF_ALL, (unsigned long)&cf);
    }
    p_SendMessageA(d->edit, EM_SETMODIFY, 0, 0);
    if (d->host) {
        layout(d);
        p_SetWindowPos(d->host, 0 /*HWND_TOP*/, 0, 0, 0, 0, SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
        refresh_state(d);
    }
    return s;
}

void wdoc_destroy(int h) {
    WDOC* d = D(h);
    if (!d) return;
    if (d->host) p_DestroyWindow(d->host);      /* takes the editor + combos with it */
    else p_DestroyWindow(d->edit);
    mem_free(d->buf); mem_free(d->pstart); mem_free(d->pused);
    zero(d, sizeof(WDOC));
}

int  wdoc_alive(int h)  { return D(h) ? 1 : 0; }
int  wdoc_hwnd(int h)   { WDOC* d = D(h); return d ? (int)(d->host ? d->host : d->edit) : 0; }
int  wdoc_edit_hwnd(int h) { WDOC* d = D(h); return d ? (int)d->edit : 0; }
void wdoc_move(int h, int x, int y, int w, int hh) { WDOC* d = D(h); if (d && d->host) p_MoveWindow(d->host, x, y, w, hh, 1); }
void wdoc_show(int h, int on) { WDOC* d = D(h); if (d && d->host) p_ShowWindow(d->host, on ? 5 : 0); }
void wdoc_enable(int h, int on) { WDOC* d = D(h); if (d && d->host) { p_EnableWindow(d->host, on); p_EnableWindow(d->edit, on); } }
void wdoc_focus(int h) { WDOC* d = D(h); if (d) p_SetFocus(d->edit); }
int  wdoc_has_focus(int h) {
    WDOC* d = D(h); void* f;
    if (!d) return 0;
    f = p_GetFocus();
    return f && (f == d->edit || (d->host && (f == d->host || p_IsChild(d->host, f)))) ? 1 : 0;
}
void wdoc_set_flags(int h, int flags) {
    WDOC* d = D(h);
    if (!d || !d->host) return;
    if ((flags & WDF_TOOLBAR) && !d->cbFont) flags &= ~WDF_TOOLBAR;   /* combos are made at create time */
    d->flags = flags;
    p_SendMessageA(d->edit, EM_SETREADONLY, (flags & WDF_READONLY) ? 1 : 0, 0);
    if (d->cbFont) { p_ShowWindow(d->cbFont, (flags & WDF_TOOLBAR) ? 5 : 0); p_ShowWindow(d->cbSize, (flags & WDF_TOOLBAR) ? 5 : 0); }
    layout(d);
}

/* ========================================================================== */
/*  Content                                                                    */
/* ========================================================================== */
int wdoc_load(int h, const char* buf, int len) {
    WDOC* d = D(h); int ok;
    if (!d) return 0;
    if (len <= 0) { E(d, EM_SETSEL, 0, (unsigned long)-1); E(d, EM_REPLACESEL, 0, (unsigned long)""); ok = 1; }
    else ok = stream_in(d, buf, len, 0);
    E(d, EM_SETSEL, 0, 0);
    E(d, EM_SETMODIFY, 0, 0);
    d->seq++;
    refresh_state(d);
    return ok;
}
/* fmt 0 = RTF, 1 = plain text. Returns the length; fetch it with wdoc_copy. */
int wdoc_save(int h, int fmt) {
    WDOC* d = D(h); EDITSTREAM es;
    if (!d) return 0;
    d->len = 0;
    es.dwCookie = (DWORD)d; es.dwError = 0; es.pfnCallback = cb_out;
    E(d, EM_STREAMOUT, fmt == 1 ? SF_TEXT : SF_RTF, (unsigned long)&es);
    return (int)d->len;
}
int wdoc_copy(int h, char* dst, int cap) {
    WDOC* d = D(h); long n, i;
    if (!d || !d->buf) return 0;
    n = d->len < cap ? d->len : cap;
    for (i = 0; i < n; i++) dst[i] = d->buf[i];
    return (int)n;
}
int wdoc_insert_rtf(int h, const char* buf, int len) { WDOC* d = D(h); int r; if (!d) return 0; r = stream_in(d, buf, len, 1); d->seq++; return r; }
void wdoc_insert_text(int h, const char* s) { WDOC* d = D(h); if (d) { E(d, EM_REPLACESEL, 1, (unsigned long)s); d->seq++; } }
int wdoc_length(int h) {
    WDOC* d = D(h); GETTEXTLENGTHEX g;
    if (!d) return 0;
    g.flags = GTL_PRECISE | GTL_NUMCHARS; g.codepage = 1200;
    return (int)E(d, EM_GETTEXTLENGTHEX, (unsigned long)&g, 0);
}
int  wdoc_get_modified(int h) { WDOC* d = D(h); return d ? (E(d, EM_GETMODIFY, 0, 0) ? 1 : 0) : 0; }
void wdoc_set_modified(int h, int on) { WDOC* d = D(h); if (d) E(d, EM_SETMODIFY, on ? 1 : 0, 0); }
int  wdoc_seq(int h)    { WDOC* d = D(h); return d ? d->seq : 0; }
int  wdoc_selseq(int h) { WDOC* d = D(h); return d ? d->selseq : 0; }
int  wdoc_picks(int h)  { WDOC* d = D(h); return d ? d->lastPick : 0; }

/* ========================================================================== */
/*  Formatting API                                                             */
/* ========================================================================== */
/* effect: 1 bold, 2 italic, 3 underline, 4 strikeout; how: 0 off, 1 on, 2 toggle */
void wdoc_effect(int h, int which, int how) {
    static const DWORD bits[] = { 0, CFM_BOLD, CFM_ITALIC, CFM_UNDERLINE, CFM_STRIKEOUT };
    WDOC* d = D(h);
    if (!d || which < 1 || which > 4) return;
    effect(d, bits[which], how); d->seq++; refresh_state(d);
}
void wdoc_set_face(int h, const char* face) { WDOC* d = D(h); if (d) { set_face(d, face); refresh_state(d); } }
void wdoc_set_size(int h, int pt10)         { WDOC* d = D(h); if (d && pt10 > 0) { set_size(d, pt10); refresh_state(d); } }
void wdoc_set_color(int h, int c)           { WDOC* d = D(h); if (d) set_color(d, (DWORD)c, 0); }
void wdoc_set_back(int h, int c)            { WDOC* d = D(h); if (d) set_color(d, (DWORD)c, 1); }
void wdoc_set_align(int h, int a)           { WDOC* d = D(h); if (d) { para_align(d, a); refresh_state(d); } }
void wdoc_set_numbering(int h, int style)   { WDOC* d = D(h); if (d) { para_numbering(d, style, 0); refresh_state(d); } }
void wdoc_indent(int h, int deltaTw)        { WDOC* d = D(h); if (d) para_indent(d, deltaTw); }

/* which: 1 bold 2 italic 3 underline 4 strike 5 size(pt*10) 6 colour 7 back colour
          8 align 9 numbering ; -1 = mixed across the selection */
int wdoc_get_format(int h, int which) {
    WDOC* d = D(h); CF2A cf; PF2 pf;
    if (!d) return 0;
    if (which <= 7) {
        zero(&cf, sizeof(cf)); cf.cbSize = sizeof(cf);
        E(d, EM_GETCHARFORMAT, SCF_SELECTION, (unsigned long)&cf);
        switch (which) {
        case 1: return (cf.dwMask & CFM_BOLD) ? ((cf.dwEffects & CFM_BOLD) ? 1 : 0) : -1;
        case 2: return (cf.dwMask & CFM_ITALIC) ? ((cf.dwEffects & CFM_ITALIC) ? 1 : 0) : -1;
        case 3: return (cf.dwMask & CFM_UNDERLINE) ? ((cf.dwEffects & CFM_UNDERLINE) ? 1 : 0) : -1;
        case 4: return (cf.dwMask & CFM_STRIKEOUT) ? ((cf.dwEffects & CFM_STRIKEOUT) ? 1 : 0) : -1;
        case 5: return (cf.dwMask & CFM_SIZE) ? (int)(cf.yHeight / 2) : -1;
        case 6: return (cf.dwMask & CFM_COLOR) ? ((cf.dwEffects & CFE_AUTOCOLOR) ? 0 : (int)cf.crTextColor) : -1;
        case 7: return (cf.dwMask & CFM_BACKCOLOR) ? ((cf.dwEffects & CFE_AUTOBACKCOLOR) ? 0x00FFFFFF : (int)cf.crBackColor) : -1;
        }
        return 0;
    }
    zero(&pf, sizeof(pf)); pf.cbSize = sizeof(pf);
    E(d, EM_GETPARAFORMAT, 0, (unsigned long)&pf);
    if (which == 8) return (pf.dwMask & PFM_ALIGNMENT) ? (pf.wAlignment ? pf.wAlignment : 1) : -1;
    if (which == 9) return (pf.dwMask & PFM_NUMBERING) ? pf.wNumbering : -1;
    return 0;
}
int wdoc_get_face(int h, char* dst, int cap) {
    WDOC* d = D(h); CF2A cf;
    if (!d || cap <= 0) return 0;
    zero(&cf, sizeof(cf)); cf.cbSize = sizeof(cf);
    E(d, EM_GETCHARFORMAT, SCF_SELECTION, (unsigned long)&cf);
    if (!(cf.dwMask & CFM_FACE)) { dst[0] = 0; return 0; }
    scpy(dst, cf.szFaceName, cap);
    return slen(dst);
}

/* 1 undo 2 redo 3 cut 4 copy 5 paste 6 select all 7 delete selection 8 select none */
void wdoc_command(int h, int cmd) {
    WDOC* d = D(h);
    if (!d) return;
    switch (cmd) {
    case 1: E(d, EM_UNDO, 0, 0); break;
    case 2: E(d, EM_REDO, 0, 0); break;
    case 3: E(d, WM_CUT, 0, 0); break;
    case 4: E(d, WM_COPY, 0, 0); break;
    case 5: E(d, WM_PASTE, 0, 0); break;
    case 6: E(d, EM_SETSEL, 0, (unsigned long)-1); break;
    case 7: E(d, WM_CLEAR, 0, 0); break;
    case 8: E(d, EM_SETSEL, (unsigned long)-1, 0); break;
    }
    refresh_state(d);
}
int wdoc_can(int h, int what) {           /* 1 undo, 2 redo */
    WDOC* d = D(h);
    if (!d) return 0;
    return (int)E(d, what == 2 ? EM_CANREDO : EM_CANUNDO, 0, 0) ? 1 : 0;
}
void wdoc_set_readonly(int h, int on) {
    WDOC* d = D(h);
    if (!d) return;
    if (on) d->flags |= WDF_READONLY; else d->flags &= ~WDF_READONLY;
    E(d, EM_SETREADONLY, on ? 1 : 0, 0);
}
void wdoc_set_zoom(int h, int pct) { WDOC* d = D(h); if (d) E(d, EM_SETZOOM, pct > 0 ? (unsigned long)pct : 0, pct > 0 ? 100 : 0); }
void wdoc_set_paper(int h, int c) { WDOC* d = D(h); if (d) E(d, EM_SETBKGNDCOLOR, c < 0 ? 1 : 0, (unsigned long)(c < 0 ? 0 : c)); }
/* wrap the editor at the PRINTED width (twips), so lines break where they will
   on paper. 0 = wrap at the window edge. */
void wdoc_set_page_width(int h, int tw) {
    WDOC* d = D(h);
    if (!d) return;
    d->pageTw = tw > 0 ? tw : 0;
    E(d, EM_SETTARGETDEVICE, d->pageTw ? (unsigned long)g_refDC : 0, (unsigned long)d->pageTw);
    if (d->host) layout(d);
}
void wdoc_select(int h, int from, int to) { WDOC* d = D(h); if (d) { CHARRANGE r; r.cpMin = from; r.cpMax = to; E(d, EM_EXSETSEL, 0, (unsigned long)&r); } }
int  wdoc_sel(int h, int which) { WDOC* d = D(h); CHARRANGE r; if (!d) return 0; E(d, EM_EXGETSEL, 0, (unsigned long)&r); return which == 2 ? r.cpMax : r.cpMin; }
/* finds forward from the caret and selects the hit; returns its position or -1 */
int wdoc_find(int h, const char* text, int matchCase, int wholeWord) {
    WDOC* d = D(h); FINDTEXTEXW ft; CHARRANGE cur; long r; WCHAR w[256]; DWORD fl;
    if (!d || !text || !text[0]) return -1;
    if (!p_MultiByteToWideChar(0 /*CP_ACP*/, 0, text, -1, w, 256)) return -1;
    fl = FR_DOWN | (matchCase ? FR_MATCHCASE : 0) | (wholeWord ? FR_WHOLEWORD : 0);
    E(d, EM_EXGETSEL, 0, (unsigned long)&cur);
    ft.chrg.cpMin = cur.cpMax; ft.chrg.cpMax = -1; ft.lpstrText = w;
    r = E(d, EM_FINDTEXTEXW, fl, (unsigned long)&ft);
    if (r < 0 && cur.cpMax > 0) {       /* wrap around to the top */
        ft.chrg.cpMin = 0; ft.chrg.cpMax = -1;
        r = E(d, EM_FINDTEXTEXW, fl, (unsigned long)&ft);
    }
    if (r >= 0) E(d, EM_EXSETSEL, 0, (unsigned long)&ft.chrgText);
    return (int)r;
}

/* ========================================================================== */
/*  Printing: pages / band chunks as vector metafiles                          */
/* ========================================================================== */
static void fr_setup(WDOC* d, FORMATRANGE* fr, void* dc, int wTw, int hTw, long from) {
    fr->hdc = dc; fr->hdcTarget = g_refDC;
    fr->rc.left = 0; fr->rc.top = 0; fr->rc.right = wTw; fr->rc.bottom = hTw;
    fr->rcPage = fr->rc;
    fr->chrg.cpMin = from; fr->chrg.cpMax = -1;
}
/* Splits the document into pages wTw x hTw (twips). Returns the page count.
   Use a band's size to flow a long document across many report pages. */
int wdoc_paginate(int h, int wTw, int hTw) {
    WDOC* d = D(h); FORMATRANGE fr; long cp = 0, total, next; int guard = 0;
    if (!d || wTw <= 0 || hTw <= 0) return 0;
    total = wdoc_length(h);
    d->pages = 0;
    do {
        if (d->pages >= d->pcap) {
            int nc = d->pcap ? d->pcap * 2 : 64;
            long* a = (long*)mem_grow(d->pstart, nc * 4);
            long* b = (long*)mem_grow(d->pused, nc * 4);
            if (!a || !b) break;
            d->pstart = a; d->pused = b; d->pcap = nc;
        }
        fr_setup(d, &fr, g_refDC, wTw, hTw, cp);
        next = E(d, EM_FORMATRANGE, 0, (unsigned long)&fr);   /* measure only */
        d->pstart[d->pages] = cp;
        d->pused[d->pages]  = fr.rc.bottom;                    /* RichEdit trims this to what it used */
        d->pages++;
        if (next <= cp) next = cp + 1;                         /* an object taller than the page: skip on */
        cp = next;
    } while (cp < total && ++guard < 100000);
    E(d, EM_FORMATRANGE, 0, 0);                                /* release RichEdit's cache */
    return d->pages;
}
int wdoc_page_start(int h, int page) { WDOC* d = D(h); return d && page >= 1 && page <= d->pages ? (int)d->pstart[page - 1] : -1; }
int wdoc_page_used(int h, int page)  { WDOC* d = D(h); return d && page >= 1 && page <= d->pages ? (int)d->pused[page - 1] : 0; }

/* ---- pictures for the WMF -------------------------------------------------
   RichEdit draws a picture with AlphaBlend, pre-scaled to the reference
   device (a 360x200 PNG arrives as a 2250x1250 32-bit bitmap at 600 dpi).
   A Windows metafile has no alpha blend, so GetWinMetaFileBits just drops
   it. We walk the EMF ourselves, composite each such bitmap onto white,
   box-filter it down to PIC_DPI, and hand it on as a META_STRETCHDIB record.
   The WMF's logical units are the EMF's device pixels (its SETWINDOWEXT is
   the frame in reference-device pixels), so the destination carries over. */
#define PIC_DPI 200
typedef struct { BYTE* p; long len, cap; } GROW;
static int grow_put(GROW* g, const void* src, long n) {
    long i;
    if (g->len + n > g->cap) {
        long nc = g->cap ? g->cap * 2 : 65536; BYTE* nb;
        while (nc < g->len + n) nc *= 2;
        nb = (BYTE*)mem_grow(g->p, nc);
        if (!nb) return 0;
        g->p = nb; g->cap = nc;
    }
    for (i = 0; i < n; i++) g->p[g->len + i] = ((const BYTE*)src)[i];
    g->len += n;
    return 1;
}
static void put16(BYTE* o, long v) { o[0] = (BYTE)v; o[1] = (BYTE)(v >> 8); }
static void put32(BYTE* o, long v) { o[0] = (BYTE)v; o[1] = (BYTE)(v >> 8); o[2] = (BYTE)(v >> 16); o[3] = (BYTE)(v >> 24); }

/* EMR_ALPHABLEND: rclBounds@8 xDest@24 yDest@28 cxDest@32 cyDest@36 blend@40
   xSrc@44 ySrc@48 xform@52 bk@76 usage@80 offBmi@84 cbBmi@88 offBits@92
   cbBits@96 cxSrc@100 cySrc@104 */
static void alphablend_to_stretchdib(const BYTE* r, long rsz, GROW* out) {
    long xD = (long)le32(r + 24), yD = (long)le32(r + 28), cxD = (long)le32(r + 32), cyD = (long)le32(r + 36);
    BYTE konst = r[42];                              /* BLENDFUNCTION.SourceConstantAlpha */
    BYTE flags = r[43];                              /* BLENDFUNCTION.AlphaFormat (1 = per-pixel) */
    long xS = (long)le32(r + 44), yS = (long)le32(r + 48);
    long offBmi = (long)le32(r + 84), offBits = (long)le32(r + 92);
    long cxS = (long)le32(r + 100), cyS = (long)le32(r + 104);
    const BYTE* bmi; const BYTE* bits;
    long bw, bh, bpp, stride, k, ow, oh, ostride, dib, x, y, rec;
    int topdown, dpi;
    BYTE* recb;
    if (offBmi <= 0 || offBits <= 0 || offBmi + 40 > rsz || cxS <= 0 || cyS <= 0 || cxD <= 0 || cyD <= 0) return;
    bmi = r + offBmi; bits = r + offBits;
    bw = (long)le32(bmi + 4); bh = (long)le32(bmi + 8);
    bpp = bmi[14] | (bmi[15] << 8);
    if (bpp != 32 && bpp != 24) return;
    topdown = bh < 0; if (bh < 0) bh = -bh;
    stride = ((bw * bpp + 31) / 32) * 4;
    if (offBits + stride * bh > rsz) return;
    if (xS < 0 || yS < 0 || xS + cxS > bw || yS + cyS > bh) return;
    /* how far to shrink: never sharper than PIC_DPI on paper */
    dpi = p_GetDeviceCaps(g_refDC, LOGPIXELSX); if (dpi <= 0) dpi = 96;
    {   long want = cxD * PIC_DPI / dpi; if (want < 1) want = 1;
        k = (cxS + want - 1) / want; if (k < 1) k = 1; }
    ow = (cxS + k - 1) / k; oh = (cyS + k - 1) / k;
    ostride = ((ow * 24 + 31) / 32) * 4;
    dib = 40 + ostride * oh;
    rec = 6 + 22 + dib;
    recb = (BYTE*)mem_alloc(rec);
    if (!recb) return;
    put32(recb, rec / 2); put16(recb + 4, 0x0F43);              /* META_STRETCHDIB */
    put16(recb + 6, 0x0020); put16(recb + 8, 0x00CC);          /* SRCCOPY */
    put16(recb + 10, 0);                                        /* DIB_RGB_COLORS */
    put16(recb + 12, oh); put16(recb + 14, ow); put16(recb + 16, 0); put16(recb + 18, 0);
    put16(recb + 20, cyD); put16(recb + 22, cxD); put16(recb + 24, yD); put16(recb + 26, xD);
    {   BYTE* hd = recb + 28;
        put32(hd, 40); put32(hd + 4, ow); put32(hd + 8, oh); put16(hd + 12, 1); put16(hd + 14, 24);
        put32(hd + 16, 0); put32(hd + 20, ostride * oh);
    }
    for (y = 0; y < oh; y++) {                 /* y counts from the TOP of the picture */
        BYTE* orow = recb + 28 + 40 + (oh - 1 - y) * ostride;   /* written bottom-up */
        for (x = 0; x < ow; x++) {
            long sb = 0, sg = 0, sr = 0, n = 0, yy, xx;
            for (yy = y * k; yy < y * k + k && yy < cyS; yy++) {
                long srow = yS + yy;
                const BYTE* row = bits + (topdown ? srow : bh - 1 - srow) * stride;
                for (xx = x * k; xx < x * k + k && xx < cxS; xx++) {
                    const BYTE* q = row + (xS + xx) * (bpp / 8);
                    long b = q[0], g = q[1], rr = q[2];
                    if (bpp == 32) {
                        if (flags & 1) {               /* premultiplied: over white */
                            long a = q[3];
                            b += 255 - a; g += 255 - a; rr += 255 - a;
                        }
                        if (konst < 255) {
                            b  = (b  * konst + 255 * (255 - konst)) / 255;
                            g  = (g  * konst + 255 * (255 - konst)) / 255;
                            rr = (rr * konst + 255 * (255 - konst)) / 255;
                        }
                        if (b > 255) b = 255;
                        if (g > 255) g = 255;
                        if (rr > 255) rr = 255;
                    }
                    sb += b; sg += g; sr += rr; n++;
                }
            }
            if (n) { orow[x * 3] = (BYTE)(sb / n); orow[x * 3 + 1] = (BYTE)(sg / n); orow[x * 3 + 2] = (BYTE)(sr / n); }
        }
    }
    grow_put(out, recb, rec);
    mem_free(recb);
}
/* Reads the EMF once, on the way: collects its pictures (above) and fixes its
   symbol-font text. RichEdit writes a Symbol/Wingdings character as U+F0xx -
   the private-use range symbol fonts are addressed through - and the ANSI
   conversion into a WMF has no mapping for it, so a bullet prints as "?".
   U+F0xx -> U+00xx is the same character to a symbol font, and converts.
   Returns a fresh EMF handle (the caller deletes it), or 0 to use the original. */
static void* prepare_emf(void* emf, GROW* out) {
    UINT n = p_GetEnhMetaFileBits ? p_GetEnhMetaFileBits(emf, 0, 0) : 0;
    BYTE* e; long p = 0; int fixed = 0; void* again = 0;
    if (!n) return 0;
    e = (BYTE*)mem_alloc((long)n);
    if (!e) return 0;
    p_GetEnhMetaFileBits(emf, n, e);
    while (p + 8 <= (long)n) {
        DWORD t = le32(e + p), sz = le32(e + p + 4);
        if (sz < 8 || p + (long)sz > (long)n) break;
        if (t == 114 /*EMR_ALPHABLEND*/ && sz >= 108) alphablend_to_stretchdib(e + p, (long)sz, out);
        if (t == 84 /*EMR_EXTTEXTOUTW*/ && sz >= 76) {
            long nch = (long)le32(e + p + 44), off = (long)le32(e + p + 48), i;
            if (off > 0 && off + nch * 2 <= (long)sz)
                for (i = 0; i < nch; i++) {
                    BYTE* c = e + p + off + i * 2;
                    WORD  u = (WORD)(c[0] | (c[1] << 8));
                    if (c[1] == 0xF0) { c[1] = 0; fixed = 1; }
                    /* RichEdit draws list bullets as U+2981 in Segoe UI Symbol;
                       U+2022 is the same dot and exists in the ANSI code page */
                    else if (u == 0x2981 || u == 0x25CF || u == 0x2219) { c[0] = 0x22; c[1] = 0x20; fixed = 1; }
                }
        }
        if (t == 14 /*EMR_EOF*/) break;
        p += (long)sz;
    }
    if (fixed && p_SetEnhMetaFileBits) again = p_SetEnhMetaFileBits(n, e);
    mem_free(e);
    return again;
}

/* Writes a placeable WMF: the 22-byte Aldus header (bounding box in twips,
   1440 units per inch) followed by the Windows-format records. */
static int write_wmf(void* emf, const char* path, int wTw, int hTw) {
    UINT n; BYTE* bits; BYTE* out; BYTE hdr[22]; WORD* w = (WORD*)hdr; WORD sum = 0; int i;
    void* f; DWORD put_ = 0, maxRec = 0; long ip, op; int ok;
    GROW pics;
    void* fixedEmf;
    pics.p = 0; pics.len = 0; pics.cap = 0;
    fixedEmf = prepare_emf(emf, &pics);
    if (fixedEmf) emf = fixedEmf;
    n = p_GetWinMetaFileBits(emf, 0, 0, 8 /*MM_ANISOTROPIC*/, g_refDC);
    bits = n ? (BYTE*)mem_alloc((long)n) : 0;
    out  = n ? (BYTE*)mem_alloc((long)n + (long)n / 2 + pics.len + 64) : 0;
    if (!bits || !out) { mem_free(bits); mem_free(out); mem_free(pics.p); if (fixedEmf) p_DeleteEnhMetaFile(fixedEmf); return 0; }
    p_GetWinMetaFileBits(emf, n, bits, 8, g_refDC);
    if (fixedEmf) p_DeleteEnhMetaFile(fixedEmf);

    /* Copy the records. Three edits on the way:
       - our converted pictures go in just before the EOF record;
       - the "WMFC" comments are dropped (see below);
       - a META_DIBBITBLT that carries a bitmap becomes META_STRETCHDIB, the
         record Clarion's own IMAGE control emits. */
    for (i = 0; i < 18; i++) out[i] = bits[i];
    ip = 18; op = 18;
    while (ip + 6 <= (long)n) {
        DWORD rs = le32(bits + ip);                       /* record size in WORDs */
        WORD  fn = (WORD)(bits[ip + 4] | (bits[ip + 5] << 8));
        if (rs < 3 || ip + (long)rs * 2 > (long)n) break;
        if (fn == 0 && pics.len) {
            long k = 0, j;
            while (k < pics.len) {
                DWORD prs = le32(pics.p + k);
                for (j = 0; j < (long)prs * 2; j++) out[op + j] = pics.p[k + j];
                op += (long)prs * 2; k += (long)prs * 2;
                if (prs > maxRec) maxRec = prs;
            }
        }
        /* MFCOMMENT "WMFC": GetWinMetaFileBits tucks a whole copy of the EMF
           into the WMF so it can be converted back. Nothing here reads it, and
           with a picture on the page it is megabytes. */
        if (fn == 0x0626 && rs >= 7 && bits[ip + 6] == 15 && bits[ip + 10] == 'W' &&
            bits[ip + 11] == 'M' && bits[ip + 12] == 'F' && bits[ip + 13] == 'C') {
            ip += (long)rs * 2;
            continue;
        }
        if (fn == 0x0940 && rs * 2 > 6 + 16 + 40) {
            /* DIBBITBLT params: rop(2w) ySrc xSrc h w yDst xDst, then the DIB
               STRETCHDIB params: rop(2w) usage srcH srcW ySrc xSrc dstH dstW yDst xDst, DIB */
            const BYTE* pr = bits + ip + 6;
            WORD ySrc = (WORD)(pr[4] | pr[5] << 8), xSrc = (WORD)(pr[6] | pr[7] << 8);
            WORD hh = (WORD)(pr[8] | pr[9] << 8),   ww = (WORD)(pr[10] | pr[11] << 8);
            WORD yD = (WORD)(pr[12] | pr[13] << 8), xD = (WORD)(pr[14] | pr[15] << 8);
            long dib = (long)rs * 2 - 6 - 16;
            long bw = (long)le32(pr + 16 + 4), bh = (long)le32(pr + 16 + 8);
            DWORD nrs = rs + 3; WORD* o;
            long k;
            if (bh < 0) bh = -bh;
            out[op] = (BYTE)nrs; out[op + 1] = (BYTE)(nrs >> 8); out[op + 2] = (BYTE)(nrs >> 16); out[op + 3] = (BYTE)(nrs >> 24);
            out[op + 4] = 0x43; out[op + 5] = 0x0F;
            o = (WORD*)(out + op + 6);
            o[0] = (WORD)(pr[0] | pr[1] << 8); o[1] = (WORD)(pr[2] | pr[3] << 8);   /* rop */
            o[2] = 0;                                                                /* DIB_RGB_COLORS */
            o[3] = (WORD)(hh < bh ? hh : bh); o[4] = (WORD)(ww < bw ? ww : bw);      /* source extent, DIB pixels */
            o[5] = ySrc; o[6] = xSrc;
            o[7] = hh; o[8] = ww; o[9] = yD; o[10] = xD;
            for (k = 0; k < dib; k++) out[op + 6 + 22 + k] = pr[16 + k];
            op += (long)nrs * 2;
            if (nrs > maxRec) maxRec = nrs;
        } else {
            long k;
            for (k = 0; k < (long)rs * 2; k++) out[op + k] = bits[ip + k];
            op += (long)rs * 2;
            if (rs > maxRec) maxRec = rs;
        }
        ip += (long)rs * 2;
    }
    /* fix the header: total size and largest record, in WORDs */
    {   DWORD tot = (DWORD)(op / 2);
        out[6] = (BYTE)tot; out[7] = (BYTE)(tot >> 8); out[8] = (BYTE)(tot >> 16); out[9] = (BYTE)(tot >> 24);
        out[12] = (BYTE)maxRec; out[13] = (BYTE)(maxRec >> 8); out[14] = (BYTE)(maxRec >> 16); out[15] = (BYTE)(maxRec >> 24);
    }

    zero(hdr, sizeof(hdr));
    w[0] = 0xCDD7; w[1] = 0x9AC6;            /* key */
    w[3] = 0; w[4] = 0;                        /* bbox left, top */
    w[5] = (WORD)wTw; w[6] = (WORD)hTw;        /* bbox right, bottom */
    w[7] = 1440;                               /* units per inch */
    for (i = 0; i < 10; i++) sum ^= w[i];
    w[10] = sum;
    f = p_CreateFileA(path, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, 0, 0);
    if (!f || f == (void*)-1) { mem_free(bits); mem_free(out); mem_free(pics.p); return 0; }
    ok = p_WriteFile(f, hdr, 22, &put_, 0) && p_WriteFile(f, out, (DWORD)op, &put_, 0);
    p_CloseHandle(f);
    mem_free(bits); mem_free(out); mem_free(pics.p);
    return ok ? 1 : 0;
}

static int ends_with_wmf(const char* p) {
    int n = slen(p);
    return n > 4 && p[n - 4] == '.' && (p[n - 3] | 32) == 'w' && (p[n - 2] | 32) == 'm' && (p[n - 1] | 32) == 'f';
}

/* Draws page N (from the last wdoc_paginate) into a metafile: an enhanced
   metafile for a .emf path, a placeable Windows metafile for .wmf (which is
   what a Clarion REPORT IMAGE plays). hTw may be less than the paginated
   height to trim the last page. 1 = ok. */
int wdoc_render_page(int h, int page, int wTw, int hTw, const char* path) {
    WDOC* d = D(h); FORMATRANGE fr; RECT frame; void* mdc; void* emf; int wmf, ok = 1;
    if (!d || page < 1 || page > d->pages || wTw <= 0 || hTw <= 0) return 0;
    wmf = ends_with_wmf(path);
    frame.left = 0; frame.top = 0;
    frame.right = wTw * 2540 / 1440; frame.bottom = hTw * 2540 / 1440;    /* .01 mm */
    mdc = p_CreateEnhMetaFileA(g_refDC, wmf ? 0 : path, &frame, "myWordDoc\0page\0");
    if (!mdc) return 0;
    fr_setup(d, &fr, mdc, wTw, hTw, d->pstart[page - 1]);
    fr.chrg.cpMax = page < d->pages ? d->pstart[page] : -1;
    E(d, EM_FORMATRANGE, 1, (unsigned long)&fr);
    E(d, EM_FORMATRANGE, 0, 0);
    emf = p_CloseEnhMetaFile(mdc);
    if (!emf) return 0;
    if (wmf) ok = write_wmf(emf, path, wTw, hTw);
    p_DeleteEnhMetaFile(emf);       /* the handle only - an .emf stays on disk */
    return ok;
}

/* %TEMP%\wdoc_<pid>_<slot>_<page>.wmf - unique per process, document and page */
int wdoc_temp_name(int h, int page, char* dst, int cap) {
    char t[300]; char* o; DWORD n;
    if (cap < 64) return 0;
    n = p_GetTempPathA(260, t);
    if (n == 0 || n > 259) { t[0] = '.'; t[1] = 92; n = 2; }
    o = t + n;
    o = put(o, "wdoc_"); o = putn(o, (long)p_GetCurrentProcessId()); *o++ = '_';
    o = putn(o, h); *o++ = '_'; o = putn(o, page); o = put(o, ".wmf"); *o = 0;
    scpy(dst, t, cap);
    return slen(dst);
}
int wdoc_delete_file(const char* path) { return p_DeleteFileA ? p_DeleteFileA(path) : 0; }

}   /* extern "C" */
