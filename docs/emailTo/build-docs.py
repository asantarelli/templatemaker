# -*- coding: latin-1 -*-
"""Build the emailTo manual: four linked volumes, published as four artifacts.

    python build-docs.py

Volume 4 is generated from the shipped sources by extract.py, so a signature
in the manual cannot drift from the signature in the build.  The build fails
loudly on drift: a nav entry that points at no heading, a heading in no nav,
or a class member with no worked example.
"""
import io
import os
import re
import sys
import html as _html

sys.dont_write_bytecode = True   # no __pycache__ beside the manual

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import extract                      # noqa: E402
from examples_data import EXAMPLES  # noqa: E402

PROBLEMS = []

CSS = io.open(os.path.join(HERE, '_doc.css'), encoding='utf-8', newline='').read()
JS = io.open(os.path.join(HERE, '_doc.js'), encoding='utf-8', newline='').read()

# ---------------------------------------------------------------- helpers
def esc(s):
    return _html.escape(s or '')


def slug(s):
    return re.sub(r'[^a-z0-9]+', '-', s.lower()).strip('-')


def code(txt, lang='clarion'):
    return ('<pre class="code" data-lang="%s"><code>%s</code></pre>'
            % (lang, esc(txt.strip('\n'))))


def usecode(txt):
    return '<pre class="code code--use" data-lang="use"><code>%s</code></pre>' % esc(txt)


def note(kind, title, body):
    #  'note' is the neutral one and takes the base style, so it gets no
    #  modifier class - an empty note--note rule would only look like an
    #  oversight to the next person reading the stylesheet.
    mod = '' if kind == 'note' else ' note--' + kind
    return ('<aside class="note%s"><p class="note__t">%s</p>'
            '<div class="note__b">%s</div></aside>' % (mod, esc(title), body))


def table(head, rows, cls=''):
    th = ''.join('<th>%s</th>' % h for h in head)
    tr = ''.join('<tr>%s</tr>' % ''.join('<td>%s</td>' % c for c in r) for r in rows)
    return ('<div class="tw"><table class="%s"><thead><tr>%s</tr></thead>'
            '<tbody>%s</tbody></table></div>' % (cls, th, tr))


def h2(aid, text):
    return '<h2 id="%s">%s</h2>' % (aid, esc(text))


def h3(aid, text):
    return '<h3 id="%s">%s</h3>' % (aid, esc(text))


def p(text):
    return '<p>%s</p>' % text


# ---------------------------------------------------------------- volumes
VOLUMES = [
    ('getting-started.html',   'Getting Started',
     'Install it and send the first message'),
    ('programmers-guide.html', "Programmer's Guide",
     'How it works, and how to make it do things'),
    ('template-guide.html',    'Template Guide',
     'Every template, tab, prompt and embed'),
    ('reference.html',         'Reference',
     'Every class, method, property and equate'),
]

#  Published, each volume is its own page at its own address, so a relative
#  filename never reaches the next one.  Filled in after the first publish.
PUBLISHED = {
    'getting-started.html':   'getting-started.html',
    'programmers-guide.html': 'programmers-guide.html',
    'template-guide.html':    'template-guide.html',
    'reference.html':         'reference.html',
}

_urls = os.path.join(HERE, 'published-urls.txt')
if os.path.exists(_urls):
    for line in io.open(_urls, encoding='utf-8'):
        line = line.strip()
        if line and '=' in line and not line.startswith('#'):
            k, v = line.split('=', 1)
            PUBLISHED[k.strip()] = v.strip()


def href(target, current):
    return '#' if target == current else PUBLISHED.get(target, target)


def volnav(current):
    out = ['<ul class="vols">']
    for i, (fn, name, blurb) in enumerate(VOLUMES):
        here = ' class="here"' if fn == current else ''
        out.append('<li><a href="%s"%s>%d. %s<small>%s</small></a></li>'
                   % (href(fn, current), here, i + 1, esc(name), esc(blurb)))
    out.append('</ul>')
    return ''.join(out)


def headings(body):
    """Every anchored id in the body, with the words actually printed above it."""
    out = {}
    for m in re.finditer(r'<h([23]) id="([^"]+)"[^>]*>(.*?)</h\1>', body, re.S):
        txt = re.sub(r'<span class="k">.*?</span>', '', m.group(3), flags=re.S)
        out[m.group(2)] = re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', '', txt)).strip()
    return out


def secnav(groups, titles):
    #  The sidebar prints the heading itself, never a second wording of it:
    #  two hand-kept lists drift, and a reader who clicks one wording and
    #  lands under another believes the link is broken.
    out = []
    for group, items in groups:
        if group:
            out.append('<p class="nav__g">%s</p>' % esc(group))
        out.append('<ul class="nav__l">')
        for aid, label in items:
            out.append('<li><a href="#%s">%s</a></li>' % (aid, esc(titles.get(aid, label))))
        out.append('</ul>')
    return ''.join(out)


def nextcards(names):
    cards = []
    for h in names:
        for fn, name, blurb in VOLUMES:
            if fn == h:
                cards.append('<a href="%s"><b>%s &rarr;</b><span>%s</span></a>'
                             % (PUBLISHED.get(fn, fn), esc(name), esc(blurb)))
    return '<div class="next">%s</div>' % ''.join(cards)


FOOT = ('emailTo &mdash; four volumes. The reference is generated from '
        '<code>EmailNetClass.inc</code>, <code>EmailMsgClass.inc</code> and '
        '<code>EmailToClass.inc</code>, so its signatures are the ones in the build.')


def page(filename, title, eyebrow, heading, sub, chips, groups, body, showfilter=False):
    titles = headings(body)
    linked = [aid for _, items in groups for aid, _ in items]
    for aid in linked:
        if aid not in titles:
            PROBLEMS.append('%s: the nav points at #%s, which is not a heading'
                            % (filename, aid))
    for aid in titles:
        if aid not in linked:
            PROBLEMS.append('%s: heading #%s (%s) is in no nav'
                            % (filename, aid, titles[aid]))
    nav = volnav(filename)
    if showfilter:
        nav += ('<label class="ui" style="font-size:11px;color:var(--faint);'
                'letter-spacing:.08em;text-transform:uppercase" for="filter">Filter</label>'
                '<input id="filter" class="filter" type="search" '
                'placeholder="SendSimple, Attach&hellip;" autocomplete="off">')
    nav += secnav(groups, titles)
    chiphtml = ''.join('<span class="chip">%s</span>' % c for c in chips)
    doc = ('<title>%s</title>\n'
           '<meta name="viewport" content="width=device-width,initial-scale=1">\n'
           '<link rel="preconnect" href="https://fonts.googleapis.com">\n'
           '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n'
           '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?'
           'family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;500;600&'
           'family=IBM+Plex+Serif:wght@400;600&display=swap">\n'
           '<style>%s</style>\n'
           '<div class="wrap">\n<nav class="side">\n'
           '  <p class="brand"><b>emailTo</b></p>\n%s\n</nav>\n'
           '<main class="main">\n'
           '  <header class="hero"><div class="inner">\n'
           '    <p class="eyebrow">%s</p>\n    <h1>%s</h1>\n    <p class="sub">%s</p>\n'
           '    <div class="chips">%s</div>\n'
           '  </div></header>\n  <div class="inner">%s\n'
           '    <footer>%s</footer>\n'
           '  </div>\n</main>\n</div>\n<script>%s</script>\n'
           % (esc(title), CSS, nav, esc(eyebrow), esc(heading), sub, chiphtml,
              body, FOOT, JS))
    io.open(os.path.join(HERE, filename), 'w', encoding='utf-8', newline='\n').write(doc)
    return len(doc)

# =====================================================================
#  1  GETTING STARTED
# =====================================================================
S_HELLO = """
  PROGRAM

  INCLUDE('EmailToClass.INC'),ONCE

  MAP
  END

Mailer  EmailToClass

  CODE
  Mailer.Init(PATH() & '\\mail.ini')          ! where the account is remembered

  Mailer.SetProvider(ETPrv:Gmail)             ! host, port, security, sign-in
  Mailer.Acc.UserName = 'you@gmail.com'
  Mailer.Acc.Password = 'abcd efgh ijkl mnop' ! a Google APP PASSWORD, not your own
  Mailer.Acc.FromAddr = 'you@gmail.com'
  Mailer.Acc.FromName = 'Acme Dispatch'

  IF Mailer.SendSimple('bob@example.com', 'It works', 'Sent from Clarion.')
    MESSAGE('Sent.')
  ELSE
    MESSAGE(CLIP(Mailer.LastErrorText))
  END
"""

S_PROJECT = """<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <DefineConstants>_ABCDllMode_=&gt;0%3b_ABCLinkMode_=&gt;1%3b_emailToDllMode_=&gt;0%3b_emailToLinkMode_=&gt;1</DefineConstants>
  </PropertyGroup>
</Project>"""

S_ATTACH = """
  Mailer.Msg.ClearAll()
  Mailer.Msg.AddTo('bob@example.com', 'Bob Smith')
  Mailer.Msg.AddCc('accounts@acme.com')
  Mailer.Msg.SetSubject('Invoice ' & CLIP(Inv:Number))
  Mailer.Msg.SetText('The invoice is attached.')
  Mailer.Msg.SetHtml('<p>The invoice is <b>attached</b>.</p>')
  Mailer.Msg.Attach('C:\\invoices\\INV-1042.pdf')

  IF NOT Mailer.Send(Mailer.Msg)
    Mailer.ShowError()
  END
"""


def build_getting_started():
    B = []
    add = B.append

    add(h2('what', 'What emailTo is'))
    add(p('emailTo sends e-mail from a Clarion application. It is three classes, one '
          'bundled C file and five templates, and it deploys as part of your '
          '<code>.EXE</code> &mdash; there is no DLL to ship, no .NET, no OpenSSL and '
          'nothing to register on the machine it runs on.'))
    add(p('It can put a message on the wire four ways, and they all send the same '
          'message: <b>SMTP</b> over plain, STARTTLS or implicit TLS; the <b>Gmail '
          'API</b>; <b>Microsoft Graph</b>; or a provider <b>API key</b> for SendGrid, '
          'Mailgun, Resend, Brevo, Postmark and Mailjet.'))
    add(table(['You have', 'Use', 'What you need'], [
        ['A Gmail account', 'SMTP + app password', 'Two-factor on, then an app password'],
        ['Outlook.com or Hotmail', 'SMTP + OAuth2', 'A desktop client ID from Azure'],
        ['Microsoft 365 at work', 'Graph, or SMTP + OAuth2', 'A desktop client ID, and your tenant'],
        ['A company mail server', 'SMTP + password', 'Host, port, and whether it wants STARTTLS'],
        ['None of the above', 'An API key service', 'A free key from Resend or Brevo'],
    ]))

    add(h2('install', 'Install'))
    add(p('Copy these seven files to a folder on the Clarion redirection path &mdash; '
          'the application folder, or <code>\\clarion12\\accessory\\libsrc\\win</code>:'))
    add(table(['File', 'What it is'], [
        ['<code>EmailNetClass.inc</code> / <code>.clw</code>',
         'Sockets, TLS, HTTPS, DPAPI. Compiles the C in.'],
        ['<code>EmailMsgClass.inc</code> / <code>.clw</code>',
         'The message and its MIME. Pure Clarion.'],
        ['<code>EmailToClass.inc</code> / <code>.clw</code>',
         'Accounts, the four transports, OAuth2, the windows.'],
        ['<code>emailc.c</code>',
         'Winsock, SCHANNEL, WinHTTP, DPAPI, SHA-256.'],
    ]))
    add(p('Put <code>emailTo.tpl</code> in <code>\\clarion12\\accessory\\template\\win</code> '
          'and register it &mdash; in the IDE, or from a command line:'))
    add(code('ClarionCL.exe -tr "C:\\clarion12\\accessory\\template\\win\\emailTo.tpl"', 'dos'))
    add(note('warn', 'The sources must be ANSI, with CRLF line endings',
             '<p>Clarion mis-parses an LF-only include: you get '
             '<code>Illegal data type: EMAILTOCLASS</code> reported at the '
             '<em>declaration</em>, with nothing flagged inside the include itself. '
             'If you have moved these files through a tool that rewrites line endings, '
             'convert them back before hunting for a phantom syntax error.</p>'))

    add(h2('hello', 'The smallest thing that sends'))
    add(p('No template, no window, no dictionary. This is a complete program:'))
    add(code(S_HELLO))
    add(p('Two things are worth noticing. <code>SetProvider</code> fills in the host, '
          'the port, the security and the sign-in method for you, so the only lines '
          'left are the ones that are actually about your account. And nothing here '
          'checks a return code except the send itself &mdash; every failure ends up in '
          '<code>LastErrorText</code> as a sentence you can show a user.'))
    add(note('tip', 'Where the app password comes from',
             '<p>Google, Yahoo and iCloud will not accept your normal password from a '
             'program. Turn on two-factor authentication, then generate an '
             '<b>app password</b> &mdash; a sixteen-character string issued for one '
             'application. Paste that into <code>Acc.Password</code>. Outlook.com no '
             'longer offers this route at all: it is OAuth2 or nothing, which the '
             "Programmer's Guide covers.</p>"))

    add(h2('handcoded', 'Building it by hand'))
    add(p('The class files pull themselves into the build through their <code>LINK</code> '
          'attribute, and <code>EmailNetClass.clw</code> pulls in the C through its '
          '<code>PRAGMA</code>, so a hand-coded project needs no file list. It does need '
          'the two link-mode defines that the template would otherwise write for you:'))
    add(code(S_PROJECT, 'xml'))
    add(note('danger', 'Leaving the defines out does not fail to link',
             '<p>Without <code>_emailToLinkMode_</code> the classes link as '
             '<em>imports</em> from a DLL that is not there, and the program takes an '
             'access violation inside a constructor before <code>main()</code> runs. '
             'The call stack shows nothing of yours on it, so it looks like anything '
             'except a project setting.</p>'))

    add(h2('fromappgen', 'The same thing from AppGen'))
    add(p('Two steps, and no code:'))
    add('<ol class="b">'
        '<li><b>Global Properties &rarr; Extensions &rarr; Insert &rarr; emailTo - Global.</b> '
        'Fill in the Account tab: provider, from address, user name. That declares the '
        'object, sets the defaults and loads the stored account at start-up.</li>'
        '<li><b>Drag <i>emailTo - E-mail button</i> onto a window.</b> Choose what it '
        'does &mdash; open the compose window, send a fixed message, or open the account '
        'setup window &mdash; and you are finished.</li>'
        '</ol>')
    add(p('From any embed anywhere else in the application, the object is simply there:'))
    add(usecode("Mailer.SendSimple(Cus:Email, 'Your statement', 'Attached.', Loc:PdfName)"))

    add(h2('attachments', 'A message with more in it'))
    add(p('<code>SendSimple</code> covers a note with one attachment. Anything richer is '
          'built on <code>Mailer.Msg</code> and handed to <code>Send</code>:'))
    add(code(S_ATTACH))
    add(p('You do not tell it what kind of MIME document to build. Text alone is '
          '<code>text/plain</code>; text and HTML together become '
          '<code>multipart/alternative</code>; an inline image makes it '
          '<code>multipart/related</code>; a file attachment wraps the lot in '
          '<code>multipart/mixed</code>. A plain note does not arrive as a four-part tree.'))

    add(h2('demo', 'The demo'))
    add(p('<code>examples/emailTo/emailToDemo.clw</code> is the hand-coded equivalent of '
          'what the templates generate: a window with <b>Account setup</b>, '
          '<b>Write a message</b> and <b>Send a test</b>, and the conversation log '
          'underneath. Build it and press the buttons before wiring anything into your '
          'own application.'))
    add(code('MSBuild emailToDemo.cwproj -t:Build -p:Configuration=Debug -p:Platform=Win32\n'
             'emailToDemo.exe            ! the demo window\n'
             'emailToDemo.exe /setup     ! straight to the account window', 'dos'))
    add(p('<b>Test account</b> is the button to press first. It connects, negotiates TLS '
          'and authenticates, then hangs up &mdash; it sends nothing to anybody, so you '
          'can prove the credentials without mailing a real person.'))

    add(h2('firstrun', 'When the first send does not work'))
    add(p('Turn the log on (<code>Mailer.Trace = 1</code>) and read the Log tab of the '
          'setup window. Every line the server said is there, with passwords masked. '
          'These are the answers that come up first:'))
    add(table(['What you see', 'What it means'], [
        ['<code>The password was refused</code> on Gmail',
         'A normal password, not an app password. Or two-factor is off, so Google will not issue one.'],
        ['<code>The password was refused</code> on Outlook.com',
         'Microsoft turned basic authentication off for personal accounts. Use OAuth2.'],
        ['<code>The TLS handshake failed</code>, Windows code 590624',
         'That is <code>SEC_I_INCOMPLETE_CREDENTIALS</code>. emailTo already handles it; '
         'if you see it, you are running an older copy of <code>emailc.c</code>.'],
        ['<code>Could not connect to the mail server</code>',
         'A firewall, or the wrong port. 587 is STARTTLS, 465 is implicit TLS, 25 is plain.'],
        ['<code>The sender was refused</code>',
         'The From address is not one the account is allowed to send as.'],
        ['<code>Illegal data type: EMAILTOCLASS</code> at compile time',
         'The includes arrived with LF line endings. Convert them to CRLF.'],
    ]))

    add(nextcards(['programmers-guide.html', 'template-guide.html', 'reference.html']))

    body = '\n'.join(B)
    groups = [
        ('Start here', [('what', 'What emailTo is'), ('install', 'Install')]),
        ('Send something', [('hello', 'The smallest thing that sends'),
                            ('handcoded', 'Building it by hand'),
                            ('fromappgen', 'The same thing from AppGen'),
                            ('attachments', 'A message with more in it')]),
        ('Then', [('demo', 'The demo'), ('firstrun', 'When the first send does not work')]),
    ]
    return page('getting-started.html', 'emailTo Getting Started', 'Volume 1',
                'Getting Started',
                'Install the classes, register the template, and get a message out of '
                'a Clarion program in about twenty lines.',
                ['No DLL to ship', 'No .NET', 'SMTP + OAuth2 + REST', 'Clarion 12'],
                groups, body)

# =====================================================================
#  2  PROGRAMMER'S GUIDE
# =====================================================================
S_OWNS = """
Mailer  EmailToClass          ! you declare this one

  !  and it builds, at Construct:
  !     Mailer.Net    EmailNetClass    the socket, TLS, HTTPS, DPAPI
  !     Mailer.Msg    EmailMsgClass    the message SendSimple and Compose use
  !     Mailer.OAuth  EmailOAuthClass  the sign-in
  !
  !  EmailOAuthClass only BORROWS Net and a second message object; it frees
  !  neither.  One owner, one Destruct, no double-dispose.
"""

S_OAUTHFLOW = """
  Mailer.Acc.Provider  = ETPrv:Office365
  Mailer.Acc.Transport = ETTrn:GraphApi
  Mailer.Acc.ClientId  = '11111111-2222-3333-4444-555555555555'
  Mailer.Acc.TenantId  = 'common'
  Mailer.Acc.UserName  = 'you@company.com'

  IF Mailer.Authorize()                     ! browser opens; user consents
    Mailer.SaveAccount()                    ! stores the refresh token, sealed
  ELSE
    MESSAGE(CLIP(Mailer.LastErrorText))
  END
"""

S_TABLE = """
Mailer.LoadAccount PROCEDURE(<STRING pName>)
  CODE
  IF NOT OMITTED(pName) AND CLIP(pName)
    SELF.Acc.Name = CLIP(pName)
  END
  Access:MailAcct.Open()
  Access:MailAcct.UseFile()
  CLEAR(MAI:Record)
  MAI:Name = SELF.Acc.Name
  GET(MailAcct, MAI:ByName)
  IF ERRORCODE()
    Access:MailAcct.Close()
    RETURN 0                                ! nothing stored yet - keep the defaults
  END
  SELF.Acc.Host     = CLIP(MAI:Host)
  SELF.Acc.Password = SELF.Unseal(MAI:Password)
  ! ... one line per mapped column ...
  Access:MailAcct.Close()
  RETURN 1
"""

S_DERIVE = """
MyMailer  CLASS(EmailToClass)
Txt         PROCEDURE(LONG pId),STRING,DERIVED
SendSmtp    PROCEDURE(EmailMsgClass pMsg),BYTE,PROC,DERIVED
          END

MyMailer.Txt PROCEDURE(LONG pId)
  CODE
  IF GlobalLanguage = LNG:Portuguese
    CASE pId
    OF ETTxt:Send  ; RETURN 'Enviar'
    OF ETTxt:Sent  ; RETURN 'A mensagem foi enviada.'
    END
  END
  RETURN PARENT.Txt(pId)                    ! English and Spanish still work

MyMailer.SendSmtp PROCEDURE(EmailMsgClass pMsg)
Ok  BYTE
  CODE
  Ok = PARENT.SendSmtp(pMsg)
  Log:Sent = Ok; Log:Reason = SELF.LastErrorText; ADD(SendLog)
  RETURN Ok
"""

S_INLINE = """
  Mailer.Msg.ClearAll()
  Mailer.Msg.AddTo(Cus:Email)
  Mailer.Msg.SetSubject('Your statement')
  Mailer.Msg.SetHtml('<p><img src="cid:logo" width="180"></p>' & |
                     '<p>Your statement is attached.</p>')
  Mailer.Msg.AttachInline('C:\\art\\logo.png', 'logo')
  Mailer.Msg.Attach('C:\\stmt\\' & CLIP(Cus:Id) & '.pdf')
  Mailer.Send(Mailer.Msg)
"""

S_CLEARTRAP = """
!  In the CLASS declaration:
ClearAll             PROCEDURE       ! correct
!  Clear              PROCEDURE      ! WRONG - redefines the CLEAR intrinsic

!  With a method called Clear, this line, in code that has nothing to do
!  with e-mail, stops compiling:
  CLEAR(GlobalRequest)               ! error: No matching prototype available
"""

S_STRINGTRAP = """
!  WRONG - a literal, on a control bound to a variable.  Survives on its own,
!  faults inside OPEN(Window) as soon as the window also holds a LIST.
         STRING(''),AT(10,130,280,10),USE(LocStatus),FONT(,8)

!  RIGHT - a picture wide enough for the variable
         STRING(@s128),AT(10,130,280,10),USE(LocStatus),FONT(,8)
"""

S_RETSTR = """
!  A method that returns a STRING cannot free the buffer it built the answer
!  in: the copy happens at the RETURN.  So the buffer belongs to the object.
EmailMsgClass.Base64 PROCEDURE(STRING pRaw)
  CODE
  SELF.EncBuf.ClearAll()
  ! ... fill SELF.EncBuf ...
  RETURN SELF.EncBuf.Value()

!  And each encoder gets its OWN buffer, because they nest: the inner result
!  is still live while the outer call reads it.
  pOut.Add(SELF.QuotedPrintable(SELF.Utf8(pBody.Value())))
"""


def build_programmers_guide():
    B = []
    add = B.append

    add(h2('model', 'The object model'))
    add(p('One object is yours. Everything under it is built and freed for you.'))
    add(code(S_OWNS))
    add(p('The split is deliberate and it is the reason emailTo needs no third-party '
          'library. <b>EmailNetClass</b> is the only place that touches C: sockets, the '
          'SCHANNEL handshake, WinHTTP, DPAPI, SHA-256. <b>EmailMsgClass</b> is pure '
          'Clarion and knows nothing about networks &mdash; it turns fields into an RFC '
          '5322 document. <b>EmailToClass</b> joins them: it owns an account and knows '
          'four ways to deliver the bytes the message class produced.'))
    add(note('note', 'Why the message class does not know about sockets',
             '<p>Because all four transports want the same bytes. SMTP writes them '
             'after <code>DATA</code>, the Gmail API base64url-encodes them into a JSON '
             'field, Graph posts them as base64 text, Mailgun uploads them as a file. '
             'Build the MIME once and every transport is a thin wrapper.</p>'))

    add(h2('account', 'The account'))
    add(p('<code>Mailer.Acc</code> is a <code>GROUP</code>, and it is the contract '
          'between the class and wherever you keep your settings. The template maps one '
          'table column onto each field. The fields that matter most:'))
    add(table(['Field', 'What it decides'], [
        ['<code>Transport</code>', 'SMTP, Gmail API, Graph, or a provider API key.'],
        ['<code>Provider</code>', 'Which preset filled the rest in, and which API shape to speak.'],
        ['<code>Host</code> / <code>Port</code> / <code>Security</code>', 'The SMTP connection.'],
        ['<code>AuthMode</code>', 'Nothing, AUTH LOGIN, AUTH PLAIN, or an OAuth2 token.'],
        ['<code>UserName</code> / <code>Password</code>', 'The credential, when it is a password.'],
        ['<code>ClientId</code> / <code>TenantId</code>', 'The registered application, when it is OAuth2.'],
        ['<code>RefreshToken</code>', 'What makes the second send need no browser.'],
        ['<code>ApiKey</code> / <code>ApiDomain</code>', 'SendGrid, Mailgun, Resend, Brevo, Postmark, Mailjet.'],
        ['<code>VerifyCert</code>', 'Leave it at 1 unless the server is yours and self-signed.'],
    ]))
    add(p('<code>SetProvider</code> fills in host, port, security and sign-in for '
          'fourteen providers, so an account is usually three lines: the provider, the '
          'address and the credential.'))

    add(h2('composing', 'Composing a message'))
    add(p('Recipients come in one at a time with <code>AddTo</code> / <code>AddCc</code> '
          '/ <code>AddBcc</code>, or all at once with <code>AddList</code>, which takes '
          'the way people actually type them &mdash; separated by <code>;</code> or '
          '<code>,</code>, with any amount of stray space.'))
    add(p('<b>Bcc behaves properly.</b> A Bcc address is added to the envelope as an '
          'extra <code>RCPT TO</code> and is deliberately <em>not</em> written into the '
          'headers, so the other recipients never see it.'))
    add(p('Bodies are set with <code>SetText</code> and <code>SetHtml</code>, appended '
          'with <code>AddText</code> and <code>AddHtml</code>. Attachments come from '
          'disk with <code>Attach</code>, from memory with <code>AttachData</code>, and '
          'an image the HTML refers to goes in with <code>AttachInline</code>:'))
    add(code(S_INLINE))

    add(h2('accents', 'Accents, and why they survive'))
    add(p('A Clarion <code>STRING</code> holds Windows-1252 bytes. Sent as-is, '
          '<i>Factura N&uacute;mero</i> arrives as mojibake, because nothing told the '
          'reader what those bytes meant.'))
    add(p('emailTo transcodes the subject, the display names, the bodies and the '
          'attachment file names to <b>UTF-8</b> and labels them. Headers are wrapped in '
          'RFC 2047 encoded words split on character boundaries &mdash; never through the '
          'middle of a character &mdash; and bodies go out quoted-printable. A plain '
          'English note is still sent as readable <code>7bit</code> text, because the '
          'encoder only reaches for quoted-printable when the content, or a 998-byte '
          'line, actually needs it.'))
    add(usecode("Mailer.Msg.CharSet = ETChs:Ansi   ! send the raw bytes labelled windows-1252 instead"))

    add(h2('transports', 'Choosing a transport'))
    add(table(['Transport', 'When it is the right one'], [
        ['<code>ETTrn:Smtp</code>',
         'Almost always. Any server, any provider that still allows a password or supports XOAUTH2.'],
        ['<code>ETTrn:GmailApi</code>',
         'A Google account where you would rather not enable SMTP at all. Needs OAuth2.'],
        ['<code>ETTrn:GraphApi</code>',
         'Microsoft 365 tenants that have SMTP AUTH disabled &mdash; increasingly, all of them.'],
        ['<code>ETTrn:ApiKey</code>',
         'A deployed application that must just send, on a network where port 587 may be blocked.'],
    ]))
    add(p('Switching is one field. The message, the attachments and the error handling '
          'are identical:'))
    add(usecode("Mailer.Acc.Transport = ETTrn:GraphApi"))

    add(h2('oauth', 'OAuth2, end to end'))
    add(p('Google and Microsoft no longer accept an ordinary password from a desktop '
          'program. The flow emailTo runs is the authorisation-code flow with PKCE, '
          'which is the one they document for native applications:'))
    add('<ol class="b">'
        '<li>Invent a random <b>verifier</b> and hash it with SHA-256 into a '
        '<b>challenge</b>.</li>'
        '<li>Open a listener on <code>http://127.0.0.1:&lt;a free port&gt;/</code> '
        '&mdash; before the browser, so no redirect can be missed.</li>'
        '<li>Open the user&rsquo;s own browser at the provider&rsquo;s consent screen, '
        'carrying the challenge and a random <b>state</b>.</li>'
        '<li>Catch the redirect, check the state matches, and swap the returned code '
        'plus the verifier for an <b>access token</b> and a <b>refresh token</b>.</li>'
        '</ol>')
    add(code(S_OAUTHFLOW))
    add(note('tip', 'A desktop client ID is not a secret',
             '<p>That is what PKCE is for. Microsoft public clients must send '
             '<em>no</em> client secret at all, and emailTo only sends one when the '
             'account actually has one. Nothing confidential is compiled into your '
             '<code>.EXE</code>.</p>'
             '<p>Register at <b>console.cloud.google.com</b> &rarr; Credentials &rarr; '
             'OAuth client ID &rarr; <b>Desktop app</b>, or <b>portal.azure.com</b> '
             '&rarr; App registrations &rarr; <b>Public client</b> with redirect '
             '<code>http://localhost</code>.</p>'))
    add(p('After the first consent nobody sees a browser again. <code>EnsureToken</code> '
          'runs before every send: if the access token is still good it does nothing, if '
          'it has expired it spends the refresh token silently, and only when there is '
          'no refresh token left does it ask the user to sign in.'))
    add(note('warn', 'Google only issues a refresh token when asked properly',
             '<p>It needs <code>access_type=offline</code> <em>and</em> '
             '<code>prompt=consent</code>, and without them the second send fails with '
             'no obvious cause. emailTo sends both. Microsoft instead <b>rotates</b> the '
             'refresh token on every use, so the new one has to be stored each time '
             '&mdash; which is why <code>Refresh</code> writes it back.</p>'))

    add(h2('settings', 'Where the settings live'))
    add(p('<code>LoadAccount</code> and <code>SaveAccount</code> are <code>VIRTUAL</code>. '
          'Out of the box they read and write an INI beside the <code>.EXE</code>, which '
          'is enough for a demo and for a single-user program. Nominate a table on the '
          'global extension and the template overrides them with code shaped like this:'))
    add(code(S_TABLE))
    add(p('Both methods open and close the file around their own work through the ABC '
          'FileManager, whose <code>Open</code> and <code>Close</code> are '
          'reference-counted &mdash; so it is safe whether or not the table is already '
          'open elsewhere in the program.'))

    add(h2('secrets', 'Secrets at rest'))
    add(p('Four fields are never stored in the clear: the password, the client secret, '
          'the refresh token and the API key. Each goes through <code>Seal()</code> '
          '&mdash; DPAPI encrypts it for the current Windows user, then base64 makes the '
          'result safe for a text column.'))
    add(usecode("Set:Password = Mailer.Seal(Loc:Typed)      ! 'dpapi:AQAAANCMnd8BFdERjHoAwE...'"))
    add(p('A row copied to another machine, or read by another Windows user, decrypts to '
          'nothing. Size those columns generously: the stored value is three to four '
          'times longer than what was typed.'))
    add(note('note', 'A password typed straight into the column still works',
             '<p><code>Unseal()</code> recognises a value that is not one of its own and '
             'hands it back unchanged, which makes seeding a test row easy. A machine '
             'with no DPAPI gets a <code>plain:</code> prefix instead, so nobody '
             'mistakes it for encrypted.</p>'))

    add(h2('errors', 'Errors, and the log'))
    add(p('Every public method answers <code>1</code> for worked and <code>0</code> for '
          'failed, and leaves the reason in <code>LastErrorText</code> as a sentence you '
          'can show a user. <code>LastServerReply</code> holds the last thing the server '
          'actually said, which is usually more specific than anything emailTo could '
          'invent.'))
    add(usecode("IF NOT Mailer.Send(Mailer.Msg) THEN Mailer.ShowError()."))
    add(p('With <code>Trace</code> on, the whole conversation is kept in '
          '<code>Mailer.Net.TraceQ</code> and shown on the Log tab of the setup window. '
          'Credentials are masked before they reach it, so a customer can send you the '
          'log of a failed send without sending you their password.'))
    add(note('danger', 'A LIST cannot be pointed at TraceQ directly',
             '<p><code>TraceQ</code> is a queue <em>reference</em>, and '
             '<code>FROM(Mailer.Net.TraceQ)</code> binds the control to the reference '
             'variable rather than to the queue. The window then faults on its first '
             'paint. Copy into a real local <code>QUEUE</code> for display &mdash; the '
             'demo and the setup window both do.</p>'))

    add(h2('deriving', 'Making it do something else'))
    add(p('The methods worth overriding are marked <code>VIRTUAL</code>: '
          '<code>Txt</code> for a third language, <code>LoadAccount</code> / '
          '<code>SaveAccount</code> for your own store, and the four '
          '<code>Send*</code> methods for logging, throttling or a retry policy.'))
    add(code(S_DERIVE))

    add(h2('notes', 'Clarion notes'))
    add(p('These are not emailTo behaviours &mdash; they belong to Clarion. Each one cost '
          'real time to find while this was being built, and each is the kind of thing '
          'that is invisible until it bites.'))

    add(h3('note-clear', 'A method named Clear breaks CLEAR() everywhere'))
    add(p('A class member whose label matches a Clarion intrinsic redefines that '
          'intrinsic for <em>every module that includes the file</em>. The compiler says '
          '<code>Redefining system intrinsic: CLEAR</code> at the include, and then '
          '<code>CLEAR(SomeVariable)</code> in code that has nothing to do with your '
          'class stops compiling.'))
    add(code(S_CLEARTRAP))
    add(p('This is why the buffer and message classes have <code>ClearAll</code>. '
          '<code>RESET</code>, <code>ADD</code>, <code>LEN</code> and <code>FREE</code> '
          'are the other names to keep away from.'))

    add(h3('note-string', 'A STRING bound to a variable needs a picture'))
    add(p('Written with a literal instead, the control survives on its own &mdash; and '
          'then faults inside <code>OPEN(Window)</code> as soon as the same window also '
          'holds a <code>LIST</code>. Nothing is drawn, so there is no clue on screen '
          'about which control is at fault.'))
    add(code(S_STRINGTRAP))
    add(p('The way to find one like this is to open variants of the window with one '
          'control removed at a time: the variant that opens names the culprit. Here '
          'two removals fixed it &mdash; the LIST, or the bound STRINGs &mdash; which is '
          'what said it was the combination rather than either one.'))

    add(h3('note-picture', 'No Clarion picture is wider than @s255'))
    add(p('<code>ENTRY(@s512)</code> is a compile error &mdash; <code>Invalid picture '
          'token</code>. In a <code>FORMAT</code> string it is worse, because '
          '<code>FORMAT</code> is just text to the compiler and nothing is reported at '
          'all. Keep list formats at <code>@s255</code> and give the entry a wider '
          'variable if you need one.'))

    add(h3('note-map', 'A MEMBER module with no MAP loses the built-ins'))
    add(p('A module-level <code>MAP</code> is what folds in <code>BUILTINS.CLW</code>. '
          'Without one &mdash; even an empty one &mdash; <code>CLIP</code>, '
          '<code>CHOOSE</code> and the rest come back as <code>Unknown function '
          'label</code>, dozens of times, which reads like a corrupt include rather '
          'than a missing four lines.'))
    add(code("  MEMBER\n\n  INCLUDE('EmailToClass.INC'),ONCE\n\n  MAP\n  END"))

    add(h3('note-return', 'A method returning STRING cannot free its own buffer'))
    add(p('The copy happens at the <code>RETURN</code>, so anything disposed first is '
          'gone before the caller sees it. The buffer has to outlive the return, which '
          'means it belongs to the object &mdash; and each encoder needs its own, '
          'because they nest.'))
    add(code(S_RETSTR))

    add(h3('note-crlf', 'Clarion source must be CRLF'))
    add(p('An LF-only include mis-parses as <code>Illegal data type: &lt;CLASS&gt;</code> '
          'at the <em>declaration</em>, with nothing flagged inside the include. Note '
          'that <code>sed -i</code> strips the CR and writes LF, so a one-line edit is '
          'enough to break a file that compiled a minute earlier.'))

    add(h3('note-schannel', 'SCHANNEL asks for a client certificate you do not have'))
    add(p('Google&rsquo;s SMTP, and Office 365, request an <em>optional</em> client '
          'certificate. With no certificate in the credential, '
          '<code>InitializeSecurityContext</code> returns '
          '<code>SEC_I_INCOMPLETE_CREDENTIALS</code> (<code>0x00090320</code>) rather '
          'than continuing, and the handshake stops. The fix is to re-issue the same '
          'token &mdash; loop again without reading more data &mdash; and the handshake '
          'completes anonymously. Without it every connection to Gmail fails.'))

    add(h3('note-dot', 'The lone full stop'))
    add(p('In SMTP, a line consisting of a single <code>.</code> ends the message. A '
          'body line that legitimately starts with a full stop must therefore be sent '
          'with two, and the receiving server removes one. Get this wrong and a message '
          'is silently truncated at the first such line &mdash; which is exactly the kind '
          'of thing that never shows up in testing and then happens to a customer.'))

    add(nextcards(['template-guide.html', 'reference.html', 'getting-started.html']))

    body = '\n'.join(B)
    groups = [
        ('How it fits together', [('model', 'The object model'), ('account', 'The account')]),
        ('Building a message', [('composing', 'Composing a message'),
                                ('accents', 'Accents')]),
        ('Getting it out', [('transports', 'Choosing a transport'),
                            ('oauth', 'OAuth2, end to end')]),
        ('Keeping it', [('settings', 'Where the settings live'),
                        ('secrets', 'Secrets at rest'),
                        ('errors', 'Errors, and the log'),
                        ('deriving', 'Making it do something else')]),
        ('Clarion notes', [('notes', 'Clarion notes'),
                           ('note-clear', 'Clear breaks CLEAR()'),
                           ('note-string', 'STRING needs a picture'),
                           ('note-picture', 'The @s255 ceiling'),
                           ('note-map', 'MEMBER needs a MAP'),
                           ('note-return', 'Returning a STRING'),
                           ('note-crlf', 'CRLF'),
                           ('note-schannel', 'The client certificate'),
                           ('note-dot', 'The lone full stop')]),
    ]
    return page('programmers-guide.html', "emailTo Programmer's Guide", 'Volume 2',
                "Programmer's Guide",
                'What the three classes own, how a message becomes MIME, how OAuth2 '
                'actually runs, and the Clarion behaviour that bit us on the way.',
                ['Object model', 'MIME', 'OAuth2 + PKCE', 'Clarion notes'],
                groups, body)

# =====================================================================
#  3  TEMPLATE GUIDE
# =====================================================================
S_GEN_GLOBAL = """
!  %AfterGlobalIncludes
INCLUDE('EmailToClass.INC'),ONCE

!  %GlobalData
Mailer             EmailToClass                            ! the mail object
emailToLanguage        BYTE(1)                             ! 1 = English, 2 = Espanol

!  %ProgramSetup, PRIORITY(8000)
    Mailer.Init()
    Mailer.Language = emailToLanguage
    Mailer.Trace = 1
    Mailer.SetProvider(1)                     ! host, port, security and auth
    Mailer.Acc.Transport = 1
    Mailer.Acc.Host      = 'smtp.gmail.com'
    Mailer.Acc.Port      = 587
    Mailer.Acc.Security  = 1
    Mailer.Acc.AuthMode  = 1
    Mailer.Acc.UserName  = 'sales@acme.com'
    Mailer.Acc.FromAddr  = 'sales@acme.com'
    Mailer.LoadAccount()
"""

S_GEN_DERIVED = """
!  %GlobalData, when a settings table is nominated
Mailer             CLASS(EmailToClass)
LoadAccount              PROCEDURE(<STRING pName>),BYTE,PROC,DERIVED
SaveAccount              PROCEDURE(),BYTE,PROC,DERIVED
                       END

!  %ProgramProcedures - the whole binding, written from your column mapping
Mailer.LoadAccount PROCEDURE(<STRING pName>)
  CODE
  ...
"""

S_GEN_BUTTON = """
!  %ControlEventHandling, on this button's Accepted
    OF ?EmailBtn
      ThisWindow.Update()
        Mailer.Compose('bob@example.com', 'Hello from Clarion', 'It works.', '')
    OF ?EmailBtn:2
      ThisWindow.Update()
          Mailer.Msg.ClearAll()
          Mailer.Msg.AddList('ops@example.com', ETAddr:To)
          Mailer.Msg.AddList('audit@example.com', ETAddr:Cc)
          Mailer.Msg.SetSubject('Nightly run finished')
          Mailer.Msg.SetHtml('<p>Fixed <b>HTML</b> body.</p>')
        IF Mailer.Send(Mailer.Msg)
          MESSAGE(Mailer.Txt(ETTxt:Sent), Mailer.Txt(ETTxt:Compose), ICON:Asterisk)
        ELSE
          Mailer.ShowError()
        END
    OF ?EmailBtn:3
      ThisWindow.Update()
        Mailer.Setup()
"""


def build_template_guide():
    B = []
    add = B.append

    add(h2('five', 'The five templates'))
    add(table(['Template', 'Kind', 'What it is for'], [
        ['<b>emailTo - Global</b>', 'Application extension',
         'Required, once per app. Declares the object, sets the defaults, '
         'generates the settings-table binding.'],
        ['<b>emailTo - E-mail button</b>', 'Control template, MULTI',
         'Drag onto a window. Compose, send straight away, or open the account window.'],
        ['<b>emailTo - Send an e-mail here</b>', 'Code template',
         'Any embed: after a report, on a menu item, inside a batch process.'],
        ['<b>emailTo - Open the compose window here</b>', 'Code template',
         'The write-and-send window, optionally pre-filled.'],
        ['<b>emailTo - Open the mail account setup window here</b>', 'Code template',
         'The account window, for a Setup menu.'],
    ]))
    add(note('tip', 'Only the first one is required',
             '<p>Add <b>emailTo - Global</b> and the object exists everywhere. The other '
             'four are conveniences that call it &mdash; anything they do, you can do '
             'from a hand-written embed with the same one-line calls.</p>'))

    add(h2('global', 'emailTo - Global'))
    add(p('Global Properties &rarr; Extensions &rarr; Insert. Six tabs.'))

    add(h3('global-general', 'General'))
    add(table(['Prompt', 'Default', 'What it does'], [
        ['Disable this template', 'off', 'Generates nothing at all. Use it to bisect a build.'],
        ['Object name', '<code>Mailer</code>', 'The label every other template refers to.'],
        ['Language', 'English', 'Sets <code>emailToLanguage</code>, which the object reads at start-up.'],
        ['Keep a conversation log', 'on', 'Sets <code>Trace</code>. Passwords are masked before they reach it.'],
    ]))

    add(h3('global-account', 'Account'))
    add(p('The defaults the object starts with. If a settings table is nominated, '
          'whatever it holds overrides these at start-up and the setup window writes '
          'changes back; with no table these <em>are</em> the settings and the setup '
          'window saves to an INI.'))
    add(table(['Prompt', 'Notes'], [
        ['Provider', 'Fourteen presets. Choosing one fills in server, port, security and sign-in.'],
        ['Send using', 'SMTP, Gmail API, Microsoft Graph, or a provider API key.'],
        ['From address / From name / Reply to', 'Used when the message does not set its own.'],
        ['Server / Port / Security', 'Only for the SMTP transport.'],
        ['Sign in with', 'Nothing, AUTH LOGIN, AUTH PLAIN, or OAuth2 XOAUTH2.'],
        ['User name / Password', 'A password typed here is compiled into the <code>.EXE</code>.'],
    ]))
    add(note('warn', 'A password on this tab is in your executable',
             '<p>Anyone with the <code>.EXE</code> has it. For anything you would not '
             'publish, leave it blank and let the setup window store it &mdash; that '
             'path puts it through DPAPI for the Windows user.</p>'))

    add(h3('global-signin', 'Sign-in'))
    add(p('The OAuth2 application and the API keys. <b>Client ID</b> is the desktop '
          'client you registered with Google or Microsoft; it is not a secret. '
          '<b>Client secret</b> stays blank for Microsoft public clients. <b>Tenant</b> '
          'is Microsoft only &mdash; <code>common</code> accepts both a personal account '
          'and a work one, which is what an application shipped to unknown customers '
          'needs. <b>API domain</b> is Mailgun only; for Mailjet the public key goes in '
          'User name and the private key in API key.'))

    add(h3('global-table', 'Table, and Table columns'))
    add(p('Nominate a table and the template generates <code>LoadAccount</code> and '
          '<code>SaveAccount</code> against it. Pick the key it finds an account by, '
          'name the account to load at start-up, then map a column onto each field.'))
    add(table(['Prompt', 'Notes'], [
        ['Settings table', 'Blank means use an INI beside the <code>.EXE</code>.'],
        ['Key to find the account by', 'Used for the <code>GET</code> in both directions.'],
        ['Account to load at start-up', 'Blank loads the first record instead.'],
        ['Create the row if it is missing', 'On, the setup window can <code>ADD</code> the account.'],
        ['Account name', 'The only required column.'],
        ['Every other column', 'Optional. Unmapped keeps whatever the Account tab set.'],
    ]))
    add(note('note', 'Four columns need to be wide',
             '<p>Password, client secret, refresh token and API key are stored sealed, '
             'so they are three to four times longer than what was typed. Make them at '
             'least 400 characters, and the refresh token 2000. '
             '<code>EmailTables.txt</code> ships a structure ready to paste into a '
             'dictionary.</p>'))

    add(h3('global-multidll', 'Multi-DLL'))
    add(p('Add the extension to every application in the suite and leave the box alone. '
          'The app that owns the data compiles the classes in and exports them; the '
          'others import them. The classes are tagged '
          '<code>!ABCIncludeFile(EMAILTO)</code>, and registering that category hands '
          'the whole job to the shipped ABC machinery &mdash; it writes the project '
          'defines and walks the registry to build the <code>.EXP</code>.'))
    add(code('#pragma define(_emailToDllMode_=>0)\n#pragma define(_emailToLinkMode_=>1)', 'dos'))
    add(p('That is why nothing in the template lists a mangled symbol: add a method to a '
          'class and the export list follows on the next generate. <code>emailc.c</code> '
          'is compiled only into the application that owns the classes, because the '
          '<code>PRAGMA</code> lives in <code>EmailNetClass.clw</code>.'))

    add(h2('global-writes', 'What the global extension writes'))
    add(p('With no settings table, into the <code>PROGRAM</code> module:'))
    add(code(S_GEN_GLOBAL))
    add(p('With one, the object is <em>derived</em> instead, and the binding is written '
          'out in full at <code>%ProgramProcedures</code>:'))
    add(code(S_GEN_DERIVED))
    add(note('note', 'Why deriving still works across a suite',
             '<p>The derived instance is declared only in the application that owns it. '
             'The others import it as the base type and still reach the derived methods, '
             'because both are <code>VIRTUAL</code> and dispatch through the '
             'object&rsquo;s own VMT.</p>'))

    add(h2('button', 'emailTo - E-mail button'))
    add(p('Drag it onto any window; drop it more than once if you want to. AppGen uniques '
          'the field equate (<code>?EmailBtn</code>, <code>?EmailBtn:2</code>&hellip;) '
          'and the template attaches the handler to whichever one this instance got.'))
    add(table(['Prompt', 'What it does'], [
        ['Action', 'Open the compose window, send straight away with no window, or open the account window.'],
        ['Mail object name', 'Must match the global extension. <code>Mailer</code> by default.'],
        ['Tell the user it worked', 'Only for the send-straight-away action.'],
        ['Show the error if it failed', 'Calls <code>ShowError</code>. Off, the reason is still in <code>LastErrorText</code>.'],
        ['To / Cc / Subject / Body', 'Literals for a button that always sends the same thing.'],
        ['&hellip;or take it from a variable', 'A field picker. Overrides the literal beside it.'],
        ['Body is HTML', 'Calls <code>SetHtml</code> instead of <code>SetText</code>.'],
        ['Attachment', 'A literal path, or a variable holding one.'],
    ]))
    add(p('Here are all three actions, as generated:'))
    add(code(S_GEN_BUTTON))

    add(h2('codetemplates', 'The three code templates'))
    add(p('<b>Send an e-mail here</b> is the one that gets used most. Its prompts mirror '
          'the button&rsquo;s Message tab, plus a place to put the result:'))
    add(table(['Prompt', 'What it does'], [
        ['To / Cc / Bcc', 'Literals, or a variable for To.'],
        ['Subject / Body', 'Literals, or variables. Body can be HTML.'],
        ['Attachment', 'A literal path, or a variable &mdash; this is how a report gets mailed.'],
        ['Put the result in', 'A field that receives 1 for sent, 0 for not.'],
        ['Tell the user it worked / Show the error', 'Both optional; the reason is always in <code>LastErrorText</code>.'],
    ]))
    add(note('tip', 'Mailing a report',
             '<p>Write the PDF, then drop <b>Send an e-mail here</b> immediately after '
             'it and point the attachment prompt at the variable holding the file name. '
             'That is the whole recipe &mdash; there is no separate report template '
             'because there does not need to be one.</p>'))
    add(p('<b>Open the compose window here</b> pre-fills and opens the write-and-send '
          'window. <b>Open the mail account setup window here</b> opens the account '
          'window &mdash; put it on a Setup menu and your users can configure their own '
          'mail without you.'))

    add(h2('embeds', 'Where the generated code lands'))
    add(table(['Template', 'Embed point', 'What arrives'], [
        ['Global', '<code>%AfterGlobalIncludes</code>', 'One <code>INCLUDE</code>, <code>ONCE</code>.'],
        ['Global', '<code>%GlobalData</code>', 'The object and <code>emailToLanguage</code>.'],
        ['Global', '<code>%ProgramSetup</code> PRIORITY(8000)', 'Init, the defaults, <code>LoadAccount</code>.'],
        ['Global', '<code>%ProgramProcedures</code>', 'The table binding, when one is mapped.'],
        ['Global', '<code>%DLLExportList</code>', 'The object and the language byte, when this app is the owner.'],
        ['Global', '<code>%BeforeGenerateApplication</code>', 'Registers the <code>EMAILTO</code> class category.'],
        ['Button', '<code>%CustomGlobalDeclarations</code>', 'The <code>INCLUDE</code>, so the module sees the class.'],
        ['Button', '<code>%ControlEventHandling</code>', 'The handler, on this instance&rsquo;s own equate.'],
        ['Code templates', 'wherever you drop them', 'The calls, inline.'],
    ]))

    add(nextcards(['reference.html', 'programmers-guide.html', 'getting-started.html']))

    body = '\n'.join(B)
    groups = [
        ('Overview', [('five', 'The five templates')]),
        ('The global extension', [('global', 'emailTo - Global'),
                                  ('global-general', 'General'),
                                  ('global-account', 'Account'),
                                  ('global-signin', 'Sign-in'),
                                  ('global-table', 'Table'),
                                  ('global-multidll', 'Multi-DLL'),
                                  ('global-writes', 'What it writes')]),
        ('The rest', [('button', 'The e-mail button'),
                      ('codetemplates', 'The code templates'),
                      ('embeds', 'Where the code lands')]),
    ]
    return page('template-guide.html', 'emailTo Template Guide', 'Volume 3',
                'Template Guide',
                'Every template, every tab, every prompt &mdash; and the code the '
                'generator actually writes into your application.',
                ['5 templates', 'Every prompt', 'Generated code', 'Multi-DLL'],
                groups, body)


# =====================================================================
#  4  REFERENCE   (generated from the sources)
# =====================================================================
CLASS_BLURB = {
    'EmailNetClass':
        'The transport primitives, and the only class that touches C. A socket, '
        'optionally wrapped in TLS; an HTTPS request; the OAuth2 loopback redirect; '
        'DPAPI, SHA-256 and secure random.',
    'EmailBufClass':
        'A growing byte buffer. Building MIME means appending thousands of small pieces '
        'to something that ends up megabytes long, and Clarion has no string builder - '
        'this doubles its capacity instead, so building stays linear.',
    'EmailMsgClass':
        'The message, and the MIME document it turns into. Pure Clarion: nothing here '
        'touches a socket, which is why all four transports can share it.',
    'EmailOAuthClass':
        'The OAuth2 authorisation-code flow with PKCE. It borrows the network and '
        'encoder objects from EmailToClass and owns neither.',
    'EmailToClass':
        'The sender. It owns an account and knows four ways to put a message on the '
        'wire, plus the setup and compose windows.',
}


def methrow(cls, m):
    key = cls + '.' + m['name']
    ex = EXAMPLES.get(key)
    if not ex:
        PROBLEMS.append('reference.html: %s has no worked example' % key)
        ex = ''
    doc = m['doc'] or m['lead']
    attrs = []
    if 'VIRTUAL' in m['attrs']:
        attrs.append('<span class="tag">VIRTUAL</span>')
    if 'DERIVED' in m['attrs']:
        attrs.append('<span class="tag">DERIVED</span>')
    return ('<tr class="fn"><td><code class="mem">%s</code>%s<div class="sig">%s</div>'
            '%s%s</td></tr>'
            % (esc(m['name']), ' ' + ''.join(attrs) if attrs else '',
               esc(m['sig']),
               '<p class="mdoc">%s</p>' % esc(doc) if doc else '',
               usecode(ex)))


def proprow(cls, pr):
    key = cls + '.' + pr['name']
    ex = EXAMPLES.get(key)
    if not ex:
        PROBLEMS.append('reference.html: %s has no worked example' % key)
        ex = ''
    doc = pr['doc'] or pr['lead']
    return ('<tr class="fn"><td><code class="mem">%s</code>'
            '<div class="sig">%s</div>%s%s</td></tr>'
            % (esc(pr['name']), esc(pr['type']),
               '<p class="mdoc">%s</p>' % esc(doc) if doc else '',
               usecode(ex)))


def build_reference():
    B = []
    add = B.append
    cs = extract.classes()

    add(h2('how', 'How to read this'))
    add(p('Every signature on this page was read out of the shipped '
          '<code>.inc</code> files when the page was built, so it is the signature in '
          'your build. Every member carries a line of real code &mdash; the build fails '
          'if one does not.'))
    add(p('<code>Mailer</code> throughout is the global <code>EmailToClass</code> object '
          'the template declares. <code>PROC</code> on a signature means the return '
          'value may be ignored; <code>VIRTUAL</code> means it is meant to be '
          'overridden.'))
    add(table(['Class', 'Lives in', 'What it is'],
              [['<code>%s</code>' % c['name'], '<code>%s</code>' % c['inc'],
                esc(CLASS_BLURB.get(c['name'], ''))] for c in cs]))

    for c in cs:
        cid = slug(c['name'])
        add(h2(cid, c['name']))
        add(p(esc(CLASS_BLURB.get(c['name'], ''))))
        props = [x for x in c['props'] if not x['private']]
        meths = [x for x in c['methods'] if not x['private']]
        if props:
            add(h3(cid + '-props', c['name'] + ' properties'))
            add('<div class="tw"><table class="api"><tbody>%s</tbody></table></div>'
                % ''.join(proprow(c['name'], x) for x in props))
        if meths:
            add(h3(cid + '-meths', c['name'] + ' methods'))
            add('<div class="tw"><table class="api"><tbody>%s</tbody></table></div>'
                % ''.join(methrow(c['name'], x) for x in meths))

    #  ---- the account group ----
    add(h2('account-group', 'EmailAccountGroup'))
    add(p('The account, field by field. This is the structure the template maps your '
          'table columns onto.'))
    for gname, inc, fields in extract.groups():
        if gname != 'EmailAccountGroup':
            continue
        add(table(['Field', 'Type', 'What it is'],
                  [['<code>%s</code>' % esc(f[0]), '<code>%s</code>' % esc(f[1]),
                    esc(f[2])] for f in fields]))

    #  ---- the queues ----
    add(h2('queues', 'The queues'))
    add(p('Four <code>TYPE</code>d queues are part of the public surface. Walk them with '
          '<code>RECORDS</code> and <code>GET</code>; do not <code>ADD</code> to them '
          'directly &mdash; the <code>AddTo</code> / <code>Attach</code> / '
          '<code>AddHeader</code> methods keep them consistent.'))
    for qname, inc, fields in extract.queues():
        add(h3(slug(qname), qname))
        add(table(['Field', 'Type', 'What it is'],
                  [['<code>%s</code>' % esc(f[0]), '<code>%s</code>' % esc(f[1]),
                    esc(f[2])] for f in fields]))

    #  ---- the equates ----
    add(h2('equates', 'The equates'))
    add(p('Every equate emailTo defines, grouped by prefix. They all begin '
          '<code>ET</code> so nothing collides with another template.'))
    eq = extract.equates()
    order = ['ETTrn', 'ETPrv', 'ETSec', 'ETAuth', 'ETLng', 'ETSend',
             'ETMsg', 'ETAddr', 'ETChs', 'ETPri', 'ETNet', 'ETTxt']
    titles = {
        'ETTrn': 'Transports', 'ETPrv': 'Providers', 'ETSec': 'Connection security',
        'ETAuth': 'Authentication', 'ETLng': 'Language', 'ETSend': 'Send errors',
        'ETMsg': 'Message errors', 'ETAddr': 'Recipient kinds',
        'ETChs': 'Character sets', 'ETPri': 'Priority',
        'ETNet': 'Network errors', 'ETTxt': 'Translatable strings',
    }
    for prefix in order:
        if prefix not in eq:
            continue
        items = eq[prefix]['items']
        add(h3('eq-' + prefix.lower(), titles.get(prefix, prefix)))
        add(table(['Equate', 'Value', 'Notes'],
                  [['<code>%s</code>' % esc(n), '<code>%s</code>' % esc(v), esc(cm)]
                   for n, v, cm in items]))

    #  ---- the C layer ----
    add(h2('capi', 'The C layer'))
    add(p('<code>emailc.c</code> is compiled into your <code>.EXE</code> by '
          'Clarion&rsquo;s own C compiler. You do not call these directly &mdash; '
          '<code>EmailNetClass</code> wraps every one &mdash; but the list is here '
          'because it is the whole of what emailTo cannot do in Clarion.'))
    add(table(['Function', 'Prototype'],
              [['<code>%s</code>' % esc(n), '<code>%s</code>' % esc(s)]
               for n, s in extract.c_api()]))
    add(note('note', 'Every one of these DLLs ships with Windows',
             '<p><code>ws2_32</code>, <code>secur32</code>, <code>winhttp</code>, '
             '<code>crypt32</code>, <code>advapi32</code> and <code>shell32</code> are '
             'bound at run time with <code>LoadLibrary</code>, so there is no import '
             'library, nothing to redistribute, and a machine missing one gives a clean '
             'error code rather than failing to start.</p>'))

    add(nextcards(['getting-started.html', 'programmers-guide.html', 'template-guide.html']))

    body = '\n'.join(B)
    groups = [('', [('how', 'How to read this')])]
    for c in cs:
        cid = slug(c['name'])
        items = [(cid, c['name'])]
        if [x for x in c['props'] if not x['private']]:
            items.append((cid + '-props', 'Properties'))
        if [x for x in c['methods'] if not x['private']]:
            items.append((cid + '-meths', 'Methods'))
        groups.append((c['name'], items))
    groups.append(('Structures', [('account-group', 'EmailAccountGroup'),
                                  ('queues', 'The queues')] +
                   [(slug(q[0]), q[0]) for q in extract.queues()]))
    groups.append(('Equates', [('equates', 'The equates')] +
                   [('eq-' + pfx.lower(), titles.get(pfx, pfx))
                    for pfx in order if pfx in eq]))
    groups.append(('C', [('capi', 'The C layer')]))

    return page('reference.html', 'emailTo Reference', 'Volume 4', 'Reference',
                'Every class, method, property, equate and structure &mdash; read out '
                'of the sources when this page was built.',
                ['5 classes', '%d members' % len(EXAMPLES), 'Generated', 'Every one worked'],
                groups, body, showfilter=True)


# =====================================================================
NEWLINE = chr(10)

if __name__ == '__main__':
    built = [
        ('getting-started.html',   build_getting_started()),
        ('programmers-guide.html', build_programmers_guide()),
        ('template-guide.html',    build_template_guide()),
        ('reference.html',         build_reference()),
    ]
    for name, size in built:
        print('  %-24s %7d bytes' % (name, size))
    if PROBLEMS:
        print(NEWLINE + '%d problem(s) - the manual has drifted from the code:' % len(PROBLEMS))
        for x in PROBLEMS:
            print('   ', x)
        raise SystemExit(1)
    print(NEWLINE + 'no drift: every nav entry lands on a heading, every heading is in a nav,')
    print('and all %d public members carry a worked example.' % len(EXAMPLES))
