# Screenshot driver for the weatherWidget demo.
#   powershell -File shoot.ps1 -Steps steps.txt -OutDir ..\..\docs
#
# The card is a window of its own, so every shot names the window it wants by
# a fragment of its title rather than assuming the process has just one.
#
# Steps file, one per line:
#   wait <ms>
#   key  <SendKeys>                  e.g.  %c  {ESC}  {TAB}
#   text <literal>
#   shot <name> <title fragment>     PrintWindow that window
#   list                             log every visible window (for debugging)
param([string]$Steps, [string]$OutDir = ".")

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System; using System.Collections.Generic; using System.Runtime.InteropServices; using System.Text;
public class WW {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EP cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int m);
  public delegate bool EP(IntPtr h, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  public static uint target;
  public static List<IntPtr> found = new List<IntPtr>();
  public static void Scan() { found.Clear();
    EnumWindows(delegate(IntPtr h, IntPtr l) { uint pid; GetWindowThreadProcessId(h, out pid);
      if (pid == target && IsWindowVisible(h)) found.Add(h); return true; }, IntPtr.Zero); }
  public static string Title(IntPtr h) { var sb = new StringBuilder(256); GetWindowText(h, sb, 256); return sb.ToString(); }
}
"@

$proc = Get-Process WeatherDemo -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc) { throw "WeatherDemo is not running" }
[WW]::target = $proc.Id
$OutDir = (Resolve-Path $OutDir).Path

function Windows { [WW]::Scan(); return [WW]::found }

# An exact title wins over a substring: the card is called 'Weather', and the
# demo window's own caption contains the word too.
function Find([string]$frag) {
  foreach ($h in Windows) { if ([WW]::Title($h) -eq $frag) { return $h } }
  foreach ($h in Windows) { if ([WW]::Title($h) -like "*$frag*") { return $h } }
  return [IntPtr]::Zero
}

# SendKeys goes to whatever is in front, so anything that types has to put the
# right window there first.
function Focus([string]$frag) {
  $h = Find $frag
  if ($h -eq [IntPtr]::Zero) { Write-Host "  !! no window matching '$frag'"; return }
  [void][WW]::SetForegroundWindow($h)
  Start-Sleep -Milliseconds 400
}

# A card is fetched, then drawn - so a shot taken at a fixed offset can land
# mid-paint and come out half empty. These two wait for the window itself.
function WaitFor([string]$frag, [int]$timeout = 30000) {
  $t = 0
  while ($t -lt $timeout) {
    if ((Find $frag) -ne [IntPtr]::Zero) { return $true }
    Start-Sleep -Milliseconds 250; $t += 250
  }
  Write-Host "  !! timed out waiting for '$frag'"
  return $false
}

function WaitGone([string]$frag, [int]$timeout = 30000) {
  $t = 0
  while ($t -lt $timeout) {
    if ((Find $frag) -eq [IntPtr]::Zero) { return $true }
    Start-Sleep -Milliseconds 250; $t += 250
  }
  Write-Host "  !! '$frag' is still there"
  return $false
}

function Shot([string]$name, [string]$frag) {
  Start-Sleep -Milliseconds 400
  $h = Find $frag
  if ($h -eq [IntPtr]::Zero) { Write-Host "  !! no window matching '$frag'"; return }
  [void][WW]::SetForegroundWindow($h); Start-Sleep -Milliseconds 300
  $r = New-Object WW+RECT; [void][WW]::GetWindowRect($h, [ref]$r)
  $w = $r.R - $r.L; $ht = $r.B - $r.T
  $bmp = New-Object System.Drawing.Bitmap $w, $ht
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $hdc = $g.GetHdc(); [void][WW]::PrintWindow($h, $hdc, 2); $g.ReleaseHdc($hdc)
  $path = Join-Path $OutDir "$name.png"
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  Write-Host ("  -> {0} ({1}x{2})" -f $path, $w, $ht)
  $g.Dispose(); $bmp.Dispose()
}

foreach ($line in Get-Content $Steps) {
  $line = $line.Trim()
  if ($line -eq '' -or $line.StartsWith('#')) { continue }
  $a = $line -split '\s+', 3
  Write-Host $line
  switch ($a[0]) {
    'wait'     { Start-Sleep -Milliseconds ([int]$a[1]) }
    'waitfor'  { [void](WaitFor  (($line -split '\s+', 2)[1])) ; Start-Sleep -Milliseconds 2500 }
    'waitgone' { [void](WaitGone (($line -split '\s+', 2)[1])) }
    'focus'    { Focus (($line -split '\s+', 2)[1]) }
    'key'  { [System.Windows.Forms.SendKeys]::SendWait(($a[1] -replace '\{SPACE\}', ' ')); Start-Sleep -Milliseconds 400 }
    'text' { [System.Windows.Forms.SendKeys]::SendWait(($line -split '\s+', 2)[1]); Start-Sleep -Milliseconds 300 }
    'shot' { Shot $a[1] $a[2] }
    'list' { foreach ($h in Windows) { Write-Host ("   '" + [WW]::Title($h) + "'") } }
    default { Write-Host "  ?? unknown step" }
  }
}
Write-Host "done"
