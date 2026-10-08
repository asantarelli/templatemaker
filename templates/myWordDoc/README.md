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
| `WordDocTools.inc` / `.clw` | the RTF tool classes: search/replace, fonts, plain text, HTML, Markdown, mail merge |
| `myWordDoc.tpl` | the AppGen templates (editor control, report extension, print code template) |

Copy the five source files to `accessory\libsrc\win` and the `.tpl` to
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

## RTF tool classes (`WordDocTools`)

Six classes for working with a document beside the editor: search and replace,
fonts, plain text, HTML, Markdown and mail merge. They live in
`WordDocTools.inc` / `.clw` and do their work in `wdoc.c`, which walks the
RichEdit document itself. Any RTF the editor can open, they can read: Word's,
WordPad's, or your own.

![The tools working on a live editor: every "Clarion" highlighted, the font under the caret shown below](../../docs/myWordDoc-tools-window.png)

| Class | What it does |
|---|---|
| `RtfSearchClass` | find, find next/previous, count, replace, replace all, highlight every hit, the text around a hit |
| `RtfFontClass` | the font, size, style and colour at a position or in the selection; the fonts a document uses; replace a font; change or scale every size |
| `RtfTextClass` | RTF to plain text with lists and tables kept readable; word, character, paragraph, picture and table counts; an excerpt; plain text to RTF |
| `RtfHtmlClass` | RTF to HTML, as a full page or a fragment for an e-mail, with pictures embedded or written as files |
| `RtfMarkdownClass` | RTF to Markdown: headings, bold/italic/strike, lists, tables and pictures |
| `RtfMergeClass` | mail merge: fills `[[Name]]` placeholders from values you set, or straight from `BIND()`ed file fields |

### Which document a tool works on

Every class works one of two ways:

```clarion
Search  RtfSearchClass
  CODE
  Search.Attach(Doc1)             ! the editor on the window: the tool works on what the user sees
  ! - or -
  Search.LoadBlob(DOC:Body)       ! its own hidden document (also LoadString, LoadFile)
  ...
  Search.SaveBlob(DOC:Body)       ! keep the changes (also SaveFile, GetRtf)
```

`Attach` takes any `WordDocClass`: an editor on a form, or the hidden document
a report prints from. On a live editor the tools put the user's selection and
scroll position back when they finish. Find, FindNext and FindPrevious are the
exception, because they move the selection to the hit on purpose. A tool made
with `LoadBlob` cleans up its hidden document by itself. Positions are 0-based
character positions, the same ones `WordDocClass.SelectText` takes. A paragraph
break counts as one character.

Add the **myWordDocGlobal** extension to an application to make the classes
available in every procedure. A hand-coded program needs only
`INCLUDE('WordDocTools.INC'),ONCE`.

### Undo

The editor has always had undo and redo: Ctrl+Z / Ctrl+Y, the toolbar's two
arrows, and `Doc1.Undo()` / `Doc1.Redo()`. The tools work with it, and **each
tool operation is one step**. A `ReplaceAll` of 19 words, `SetFontAll`,
`ScaleSizes`, `ReplaceFont`, `HighlightAll` or a whole `Merge` comes back with
one Ctrl+Z, and Redo puts it back.

```clarion
Search.ReplaceAll('Acme Ltd', 'Acme Limited')
Search.Undo()                     ! all of them back (the same as Ctrl+Z or Doc1.Undo())
IF Doc1.CanUndo() THEN ENABLE(?UndoButton) ELSE DISABLE(?UndoButton).

Doc1.BeginUndoGroup()             ! your own edits as one step, too
Doc1.InsertText('Dear ' & CLIP(CUS:Name) & ',')
Doc1.SelectText(0, 4)
Doc1.Bold(WD:On)
Doc1.EndUndoGroup()               ! pairs nest

Doc1.ClearUndo()                  ! forget the history
Doc1.SetUndoLimit(500)            ! keep more steps than RichEdit's default of 100
```

Loading a document (`LoadBlob`, `LoadString`, `LoadFile`) clears the history,
so Undo never goes back to the previous record. The grouping uses the text
engine's own undo (TOM `BeginEditCollection`, Windows 8 and later). On older
Windows, undo still works, one change at a time.

### RtfSearchClass: find and replace

```clarion
Search.Attach(Doc1)
Search.MatchCase = FALSE          ! "Smith" also finds "smith"
Search.WholeWord = TRUE           ! "art" does not find "party"

IF Search.Find('invoice') >= 0    ! the first hit from the top, selected and scrolled into view
  MESSAGE(Search.Count('invoice') & ' found. The first: ' & Search.Context(30))
END
Search.FindNext()                 ! goes round to the top when Wrap is on (the default)
Search.FindPrevious()

Search.ReplaceAll('Acme Ltd', 'Acme Limited')   ! returns how many; each keeps its formatting
Search.Replace('colour', 'color')               ! like Word's Replace button: the first call finds,
                                                ! each later one replaces the hit and finds the next
Search.HighlightAll('urgent', COLOR:Yellow)     ! COLOR:None takes the highlight off again
```

`FoundAt` and `FoundEnd` give the last hit, and `TextAt(From, To)` gives the
plain text of any range. Set `SelectHits = FALSE` to search without moving the
user's selection. A replacement takes the formatting of the text it replaces,
so a bold name stays bold.

### RtfFontClass: which font am I on?

```clarion
Font.Attach(Doc1)
Font.Read()                       ! the user's selection; Font.Read(Pos) reads one character
?Status{PROP:Text} = Font.Describe()            ! "Georgia 12pt, bold, italic"
IF Font.Bold = 1 AND Font.Size >= 14            ! also Italic, Underline, Strike, Script,
  ! a heading                                    ! Color, Highlight, Align, List
END
```

Over a selection that mixes styles, a property says so: `Face` is blank,
`Size` is 0, `Bold` and the other on/off values are -1, and `Color` or
`Highlight` is -2. `Color = COLOR:None` means automatic (black).

```clarion
LOOP I# = 1 TO Font.FontCount()   ! the fonts the document really uses
  FontQ:Name = Font.FontName(I#)
  FontQ:Chars = Font.FontChars(I#)  ! how many characters are set in it
  ADD(FontQ)
END
Font.FontList()                   ! 'Georgia, Segoe UI'
Font.MainFont()                   ! the font most of the text is in

Font.ReplaceFont('Comic Sans MS', 'Segoe UI')   ! every stretch in that font
Font.SetFontAll('Calibri', 11)    ! the whole document; '' or 0 leaves that part as it is
Font.SetFontRange(0, 20, 'Georgia', 18)
Font.ScaleSizes(120)              ! every size 20% bigger, the headings with it
```

Only characters you can see count. Paragraph and table marks keep a font of
their own that formatting never changes, so they are left out of the list.

### RtfTextClass: RTF to plain text

```clarion
Text.LoadBlob(DOC:Body)
DOC:PlainText = Text.ToText()     ! for a search index, a LIST column or an SMS
Text.SaveText('letter.txt')
```

The text stays readable:

```
What it can do
- Formatting - bold, italic, underline, strike, colour and highlight.
- Paragraphs - left, centre, right and justified; indents; bullets and numbering.
Product	Units	Revenue
Widgets	1,200	$14,400
```

| Property | Default | Effect |
|---|---|---|
| `ListPrefixes` | on | `- ` for bullets, `1.` `b.` `iv.` for numbered items |
| `Bullet` | `'- '` | what a bullet becomes |
| `TabCells` | on | table cells separated by TAB (off: ` \| `) |
| `PictureMarks` | off | `[picture]` where a picture was |
| `Utf8` | off | UTF-8 instead of the ANSI code page |

```clarion
Text.WordCount()  Text.CharCount()  Text.CharCount(FALSE)   ! without spaces
Text.ParagraphCount()  Text.PictureCount()  Text.TableCount()
DOC:Summary = Text.Excerpt(120)   ! one line, cut at a word, with '...'
Text.IsRtf(L:Imported)            ! does a string start with {\rtf?
Doc1.LoadString(Text.TextToRtf(NOTE:Memo, 'Georgia', 12))   ! a MEMO into the editor
```

`TextToRtf` escapes `\`, `{` and `}`, turns line breaks into paragraphs and
accented letters into `\'e9`, so any plain text becomes a valid RTF document.

### RtfHtmlClass: RTF to HTML

```clarion
Html.LoadBlob(DOC:Body)
Html.Title = DOC:Title
Html.SaveHtml('letter.html')      ! a complete UTF-8 page

Html.FullPage = FALSE             ! only a <div>, for the body of an e-mail
Mail:Body = Html.ToHtml()
```

![sample.rtf as HTML in a browser](../../docs/myWordDoc-tools-html.png)

The page keeps the fonts, sizes, colours, highlight, bold/italic/underline/strike,
super- and subscript, alignment, indents, spacing, bullets and numbering
(`<ul>`/`<ol>`), tables and pictures. Styles are inline, so the HTML survives
mail clients that drop `<style>` blocks. The font most of the text uses becomes
the page's font, and only text that differs from it carries a `<span>`.

Pictures are embedded as `data:` URIs by default, so the HTML is one
self-contained file. To keep it small, write them as files instead:

```clarion
Html.ImageFolder = 'C:\Site\img'  ! image1.png, image2.jpg ... are written here
Html.ImageUrl = 'img/'            ! and linked as img/image1.png
Html.SkipPictures = TRUE          ! or leave them out
```

PNG and JPEG pictures are copied byte for byte. EMF, WMF and BMP pictures are
drawn at twice their size and saved as PNG through GDI+, so they stay sharp on
high-DPI screens.

### RtfMarkdownClass: RTF to Markdown

```clarion
Md.LoadBlob(DOC:Body)
Md.SaveMarkdown('letter.md')      ! UTF-8
```

```markdown
# Customer letter

### What it can do

- **Formatting** - bold, *italic*, underline, ~~strike~~, colour and highlight.

| **Product** | **Units** | **Revenue** |
| --- | --- | --- |
| Widgets | 1,200 | $14,400 |
```

A short paragraph in large type becomes a heading: `#` at 1.6 times the body
size, `##` at 1.3 times, and `###` at 1.12 times when it is all bold. Emphasis
markers stay next to the words, so `** word**` never happens. Characters that
mean something in Markdown are escaped. Pictures work as they do in HTML:
`ImageFolder`, `ImageUrl` and `SkipPictures`.

### RtfMergeClass: mail merge

Write a letter in the editor with placeholders, and store it as the template:

> Dear **[[CUS:Name]]**, your order [[ORD:Number]] ships [[When]].

```clarion
Merge.LoadBlob(TPL:Body)          ! the template letter
BIND(CUS:Record)                  ! fields you BIND fill their placeholders by themselves
BIND('ORD:Number', ORD:Number)
Merge.SetField('When', 'on ' & FORMAT(ORD:ShipDate, @D17))   ! or set a value yourself
IF Merge.Missing() <> ''          ! placeholders nothing will fill
  MESSAGE('No value for: ' & Merge.Missing())
END
Merge.Merge()                     ! returns how many placeholders were replaced
Merge.SaveBlob(LET:Body)          ! the finished letter, ready to print or e-mail
```

Each value takes the formatting of its placeholder, so a bold `[[CUS:Name]]`
prints the name in bold. `FieldCount()` and `FieldName(N)` list the
placeholders a template uses. `FieldOpen` and `FieldClose` change the `[[ ]]`
markers. `UseBound = FALSE` turns off the `BIND` lookup, and
`BlankUnknown = TRUE` empties the placeholders nothing filled. Merge into a
fresh copy of the template for each record: `LoadBlob`, `Merge`, `SaveBlob`.

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

`Tools.clw` (built the same way from `Tools.cwproj`) proves the tool classes:

- `Tools.exe AUTO`: 60 headless checks into `tools_result.ini`, with every
  export written to `tools_out\`. They cover find, next, previous, whole word,
  match case, replace, replace all, highlight on and off, the font at a
  position, the fonts in use, replace/scale/set fonts, plain text with
  bullets, numbers and table cells, the counts, an excerpt, a text-to-RTF round
  trip with braces, backslashes and accents, HTML pages and fragments with
  tables, lists, colours and pictures (embedded and as files), BMP/EMF/WMF
  pictures converted to PNG, Markdown headings, lists, tables and pictures, and
  a merge from `SetField` values and a `BIND`ed variable that keeps the
  placeholder's bold, and undo: nothing to undo after a load, one Undo for
  each tool operation and for a merge, Redo, and grouped edits of your own.
- `Tools.exe` opens the window in the screenshot above: the editor with find,
  replace and highlight, the font under the caret, and the exports.

`Flow.clw` (built the same way from `Flow.cwproj`) prints a short note, the
long letter and another note in one report, as `WD:Flow` or, with `PAGES` on
the command line, as `WD:Pages`. The comparison image above comes from it.

`examples/myWordDoc/WordDemo/` proves the templates through AppGen: `build_demo.sh`
registers the template through a local redirection file, so nothing is copied
into a Clarion install. It then builds the dictionary from `WordDemoDict.dctx`,
imports `WordDemo.txa` (browse, form, a report with the extension, a report with
the code template), generates and compiles `WordDemo.exe`. Both reports were
run against three records and printed four correct pages.
