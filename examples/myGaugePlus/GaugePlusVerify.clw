  PROGRAM
! ============================================================================
!  GaugePlusVerify - headless render check. Paints each preset (and a face
!  image) straight onto the canvas and saves a PNG - no window needed - so the
!  centring fix (90/45/180/custom) and the face-image layer can be eyeballed.
! ============================================================================
  INCLUDE('GaugePlusClass.INC'),ONCE
  MAP
Shot PROCEDURE(STRING pName,LONG pStyle,STRING pFaceImg)
  END

G    GaugePlusClass
  CODE
  Shot('test_90.png',  GaugeP:Arc90,  '')
  Shot('test_45.png',  GaugeP:Arc45,  '')
  Shot('test_180.png', GaugeP:Arc180, '')
  Shot('test_270.png', GaugeP:Arc270, '')
  Shot('test_360.png', GaugeP:Arc360, '')
  Shot('test_face.png',GaugeP:Arc360, 'gaugeplus_out.png')   ! face image as the base layer
  ! ---- font family + per-element sizes ----
  G.ClearZones()
  G.SetRange(0, 100); G.Preset(GaugeP:Arc270); G.SetValue(64)
  G.MajorTicks = 10; G.MinorTicks = 1
  G.Title = 'CONSOLAS'; G.Units = 'bar'
  G.FaceImage = ''
  G.FontName = 'Consolas'
  G.LabelSize = 130; G.ValueSize = 175; G.TitleSize = 120; G.UnitsSize = 130
  G.LabelBold = 1;   G.ValueBold = 1
  IF G.Cv.BeginCanvas(420, 420)
    G.Render(420, 420)
    G.Cv.SavePng('test_font.png')
    G.Cv.EndCanvas()
  END

Shot PROCEDURE(STRING pName,LONG pStyle,STRING pFaceImg)
path CSTRING(261)
  CODE
  G.ClearZones()
  G.SetRange(0, 100)
  G.Preset(pStyle)
  G.MajorTicks = 10; G.MinorTicks = 1
  G.AddZone(0, 60, 02CA02Ch); G.AddZone(60, 85, 020C0F0h); G.AddZone(85, 100, 02020E0h)
  G.Title = 'DEMO'; G.Units = 'psi'
  G.FaceImage = pFaceImg
  G.SetValue(64)
  IF G.Cv.BeginCanvas(420, 420)
    G.Render(420, 420)
    path = pName
    G.Cv.SavePng(path)
    G.Cv.EndCanvas()
  END
