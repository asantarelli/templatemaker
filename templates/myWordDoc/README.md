# myWordDoc

A **word processor for Clarion**, stored in a **BLOB**, that also **prints through
a Clarion REPORT**. Text, fonts, sizes, bold/italic/underline/strike, colour,
highlight, alignment, bullets, numbering, indents, pictures and tables. No COM,
no OCX, no DLL to ship.

![the editor on a Clarion window](../../docs/myWordDoc-editor.png)

## What it is

Our own control. `wdoc.c` registers a window class of its own (`myWordDocHost`)
whose window procedure lives in that file. The host paints its own toolbar,
handles its own buttons, colour picker, picture and table pickers, and holds the
editing surface.

The editing surface is the Windows text engine (`RICHEDIT50W` in `msftedit.dll`,
the engine behind WordPad), used as a component: it does the typing, line
breaking, selection, undo, the clipboard, accents and IME, and reads and writes
RTF. Because the host is its **parent**, every RichEdit notification comes to
*our* window procedure. The Clarion window is never subclassed.

`wdoc.c` is compiled into your executable by **Clarion's own C compiler**
(`PRAGMA('compile(wdoc.c)')` in `WordDocClass.clw`). Every Win32 call is bound
with `LoadLibrary`/`GetProcAddress`, so there is no import library and nothing
to install: `msftedit.dll` ships with every Windows since XP SP1.

| File | What it is |
|---|---|
| `wdoc.c` | the control: host window, toolbar, RichEdit, RTF streaming, pictures, tables, pagination, metafile rendering |
| `WordDocClass.inc` / `.clw` | the Clarion class: placement over a REGION, BLOB load/save, formatting API, report printing |
| `myWordDoc.tpl` | the AppGen templates (editor control, report extension, print code template) |

Copy the three source files to `accessory\libsrc\win` and the `.tpl` to
`accessory\template\win`, then register it.

## Storage: one BLOB, plain RTF

```clarion
Doc1.LoadBlob(DOC:Body)        ! after the window opens
Doc1.SaveBlob(DOC:Body)        ! before the record is written
```

The BLOB holds ordinary RTF, so Word and WordPad open it, and pictures travel
inside it (`{\pict\pngblip ...}`). A BLOB that holds plain text (not starting
with `{\rtf`) loads as plain text, so an existing MEMO-style column can be
switched over without a conversion. `GetText()` gives the plain text back for
searching or indexing.

## The toolbar

![toolbar state follows the selection](../../docs/myWordDoc-toolbar.png)

Font and size boxes, **B** *I* <u>U</u> ~~S~~, text colour and highlight (the
Windows colour dialog), left/centre/right/justify, bullets, numbering,
outdent/indent, insert picture (PNG, JPEG, BMP, EMF, WMF), insert table (a menu
of sizes), undo and redo. The buttons light up for the formatting under the
caret; the font and size boxes go blank when the selection mixes several. It
wraps onto a second row when the control is narrow.

Everything RichEdit already knows works too: Ctrl+B/I/U, Ctrl+L/E/R/J,
Ctrl+Z/Y, Ctrl+C/X/V (including **pasting a picture**, which is stored as a PNG
in the RTF), Tab, Enter, and the mouse and keyboard selection
users expect.

The class has the same operations as methods (`Bold()`, `SetFont()`,
`SetAlign()`, `SetList()`, `InsertImage()`, `InsertTable()`, `Find()`, ...) so
you can drive the document from your own buttons or code. Hide the built-in
toolbar with `ShowToolbar = 0` if you do.

## Page view: see the printed width

![page view](../../docs/myWordDoc-pageview.png)

Set `PageWidth` (twips; `WD:LetterWidth`, `WD:A4Width`) and the editor wraps
lines **exactly where the printer will**: the text is measured on the default
printer, not on the screen, the way WordPad does it. With `PageView = 1` the
document shows as a sheet of that width on a grey desk.

## Printing in a Clarion REPORT

Yes, it prints, and it prints as **vectors**: sharp at any zoom, small in a PDF.

![three report pages](../../docs/myWordDoc-report.png)

Put an IMAGE control in a DETAIL band, sized to the area the document may
fill. Then, for each record:

```clarion
Doc1.InitHidden()                                  ! once, after OPEN(Report)
...
Doc1.LoadBlob(DOC:Body)
LOOP Page# = 1 TO Doc1.PaginateForReport(Report, ?DocImage, WD:Flow)
  Doc1.PreparePage(Report, ?DocImage, Page#)       ! piece N into the IMAGE
  PRINT(RPT:DocBand)
END
...
Doc1.Kill()                                        ! deletes the temp files
```

`PaginateForReport` reads the IMAGE's size in any report units. It switches the
report to thousandths for the read and back, as ABC's own
ReportAttributeManager does. Then it cuts the document in one of two ways.

### WD:Flow: fill the room left on the page

![the same three records printed both ways](../../docs/myWordDoc-flow-vs-pages.png)

**`WD:Flow`** (the template's default) cuts the document **one line per
piece**. Each line is printed as its own band, the height of that line. The
report engine places every band itself: if it fits on this page it goes here,
and if not it starts the next page. So a long document starts in whatever room
the previous record left. It fills that page, carries on over as many pages as
it needs, and whatever prints after it follows straight on.

The report engine cannot tell a program how much room is left on a page, and it
moves a band that doesn't fit whole to the next page. Letting the engine place
one line at a time avoids both problems, and nothing has to be measured.

- A line is never split: a picture or a table row that doesn't fit moves to the
  next page whole, as in Word.
- In this mode the band is cut down to the line, so **keep the IMAGE alone in
  its band**. Its top is moved to 0 while printing and put back afterwards.
- One small metafile is written per line, and all of them are deleted by
  `Kill()`. A 3-page letter is about 70 files.

### WD:Pages: pieces the size of the IMAGE

**`WD:Pages`** (the class default, and what earlier versions did) cuts the
document into pieces exactly the size of the IMAGE. When the next piece won't
fit in the room left, the engine starts a new page, which can leave most of a
page empty. With `pShrinkLast` (on by default) the **last** piece's IMAGE and
band are shrunk to the text actually there, so whatever prints next follows
straight on.

Each piece is rendered by RichEdit (`EM_FORMATRANGE`) into an enhanced
metafile, then written as a placeable WMF in `%TEMP%`. The report engine plays
a WMF's records straight into the page.

### Why WMF, and the three things the conversion needed

An `.emf` on a report IMAGE prints **nothing**, so the page is converted with
`GetWinMetaFileBits`. Three things go wrong in that conversion, and `wdoc.c`
fixes each:

1. **Pictures disappear.** RichEdit draws a picture with `AlphaBlend`, which a
   WMF cannot express, so the converter drops it. `wdoc.c` walks the EMF
   itself, composites each alpha-blended bitmap onto white, scales it to 200 dpi
   and writes it into the WMF as a `STRETCHDIB` record: the one Clarion's own
   IMAGE control produces.
2. **The WMF is huge.** The converter tucks a complete copy of the EMF into the
   WMF as comment records ("WMFC"). With one picture on the page that was
   11 MB. They are dropped; the same page is now 0.9 MB, nearly all of it the
   picture.
3. **Bullets print as "?".** RichEdit draws bullets as U+2981 (and symbol-font
   characters as U+F0xx), which have no ANSI equivalent. They are mapped to the
   same glyphs in the ANSI range before conversion.

### Measured on the printer, not the screen

Text measured on a 96-dpi screen comes out **wider** at true scale (glyph widths
are hinted to whole pixels), so justified lines ran off the right of the IMAGE.
Measuring, paginating and rendering all use the default printer as the
reference device. With no printer installed it falls back to the screen.

![report detail](../../docs/myWordDoc-report-zoom.png)

## The templates (`myWordDoc.tpl`)

Four templates, ABC chain. You can use them without writing any of the code above.

| Template | Kind | What it does |
|---|---|---|
| `myWordDocGlobal` | application extension (optional) | One switch that turns the whole thing off. The class is included automatically wherever it is used. |
| `myWordDocEditor` | control template (populate a REGION) | The editor on a window or form, tied to a BLOB field. |
| `myWordDocReport` | report extension | Prints each record's BLOB document through a report IMAGE. |
| `myWordDocPrintBlob` | code template | The same print loop, put into any embed you choose. |

### Editor on a form

Populate **myWordDocEditor** on the form and size the region. Then pick the
**BLOB field**.

- **General** tab: object name and "Save it with the record".
- **Appearance** tab: toolbar, read only, page view, page width (Letter, A4,
  custom twips or the window's width), default font and default size.

What it generates:

- **Init** (right after the window opens): load the BLOB. On a View request
  the editor is read only.
- **TakeEvent**: the editor follows the region as the resizer moves it, hides
  it or disables it.
- **TakeCompleted** (before ABC writes the record): `SaveBlob` runs on an
  Insert, or on a Change when the document was edited. An untouched form
  closes without an update.
- **Kill**: the editor is destroyed.

The field must be a dictionary BLOB; anything else stops generation with an
error.

![the generated form, editing the letter stored in the record's BLOB](../../docs/myWordDoc-demo-form.png)

*The generated `UpdateDoc` form: the record's BLOB, loaded into the editor.*

### Printing every record's document

Put an IMAGE in a DETAIL band of a Report procedure, sized to the area the
document may fill. Add **myWordDocReport** and pick the BLOB and the IMAGE.
The band is found from the image. Choose whether the document prints before
or after the record's other detail bands.

The extension takes that band out of ABC's own print loop (the same mechanism
ABC's Child File extension uses), so it never prints twice. For each record it:

1. re-reads the record by its primary key, because a VIEW read leaves BLOBs
   untouched;
2. loads the document;
3. prints it, cut as **Cut the document** says. The default is *Fill the room
   left on each page, line by line* (`WD:Flow`). *In pieces the size of the
   image* (`WD:Pages`) brings back the **Shrink the last piece** option.

![three records through the generated report](../../docs/myWordDoc-demo-report.png)

*The generated `PrintDocs` report over three records. The letter starts right
under its title on page 1, fills every page down to the footer, and the third
note follows straight after it.*

![the report preview, page 2](../../docs/myWordDoc-demo-preview.png)

*Pressing Print opens ABC's normal Report Preview. This is page 2: the letter's
heading, bullets, picture and table.*

### Printing from your own code

Use **myWordDocPrintBlob** in any embed. Name the report, the IMAGE and the
band to PRINT. In the report designer, set that band's **Detail Filter** to
`False` so ABC does not print it as well.

## Known limits

| Limit | Why | Workaround |
|---|---|---|
| GIF, TIFF and ICO cannot be inserted from the toolbar | RTF has no blip type for them | Convert to PNG first (or paste them: the clipboard gives RichEdit a bitmap) |
| Printed text is limited to the ANSI code page | WMF text records are 8-bit | Fine for Western languages; Greek/Cyrillic/CJK show on screen and in the BLOB but not in print |
| Printed pictures are 200 dpi | keeps report pages and PDFs small | `PIC_DPI` in `wdoc.c` |
| No headers/footers/page numbers inside the document | the document is a band, not a page | use the REPORT's own header/footer |
| `WD:Flow` keeps a paragraph's space-before when it starts a page | each line is printed exactly as laid out | barely visible; use `WD:Pages` if it matters |

## Verified

`examples/myWordDoc/Spike.clw` is the hand-coded proof (no AppGen), built by
`build.sh`:

- `Spike.exe AUTO`: 30 headless checks (struct layout against Win32, every
  format getter after its setter, tables, PNG/JPEG/BMP pictures, a missing
  file, Find, a **BLOB round trip through a real TopSpeed record** with the text
  compared, pagination, metafile output) into `spike_result.ini`.
- `Spike.exe REPORT`: prints `sample.rtf` through a REPORT into `PROP:Preview`
  and copies the pages out; `wmf2png.ps1` renders them for inspection.
- `keys.ps1` posts real keystrokes through the app's message queue: Tab and
  Enter reach the document through Clarion's ACCEPT loop.
- `click.ps1` clicks the toolbar the same way and photographs the result.
- `shot.ps1` takes screen captures (not `PrintWindow`, which hides a hosted
  control that is being painted over).

`Flow.clw` (built the same way from `Flow.cwproj`) prints a short note, the
long letter and another note in one report, as `WD:Flow` or, with `PAGES` on
the command line, as `WD:Pages`. The comparison image above comes from it.

`examples/myWordDoc/WordDemo/` proves the templates through AppGen: `build_demo.sh`
registers the template through a local redirection file, so nothing is copied
into a Clarion install. It then builds the dictionary from `WordDemoDict.dctx`,
imports `WordDemo.txa` (browse, form, a report with the extension, a report with
the code template), generates and compiles `WordDemo.exe`. Both reports were
run against three records and printed four correct pages.
