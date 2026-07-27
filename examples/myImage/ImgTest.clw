  PROGRAM
  INCLUDE('ImageClass.INC'),ONCE
  INCLUDE('EQUATES.CLW'),ONCE
  MAP
  END
Here  EQUATE('C:\dev\clarion12\templatemaker\examples\myImage\')
INI   EQUATE('C:\dev\clarion12\templatemaker\examples\myImage\imgtest.ini')
Pic   ImageClass
Two   ImageClass
i     LONG
ok    LONG
  CODE
  PUTINI('t','start','yes',INI)
  IF NOT Pic.TestCard(480, 360)
    PUTINI('t','testcard','FAILED err=' & Pic.LastError(), INI)
    RETURN
  END
  PUTINI('t','testcard', Pic.Wide() & 'x' & Pic.High(), INI)
  PUTINI('t','save_png', Pic.SaveFile(Here & 'out_card.png'), INI)
  PUTINI('t','save_bmp', Pic.SaveFile(Here & 'out_card.bmp'), INI)
  PUTINI('t','save_jpg', Pic.SaveFile(Here & 'out_card.jpg'), INI)
  PUTINI('t','save_gif', Pic.SaveFile(Here & 'out_card.gif'), INI)
  PUTINI('t','save_tif', Pic.SaveFile(Here & 'out_card.tif'), INI)
  PUTINI('t','save_tga', Pic.SaveFile(Here & 'out_card.tga'), INI)
  PUTINI('t','save_qoi', Pic.SaveFile(Here & 'out_card.qoi'), INI)
  PUTINI('t','save_pcx', Pic.SaveFile(Here & 'out_card.pcx'), INI)
  PUTINI('t','save_pnm', Pic.SaveFile(Here & 'out_card.ppm'), INI)
  ! ---- round trip every format we can write ----
  LOOP i = 1 TO 9
    CASE i
    OF 1 ; ok = Two.LoadFile(Here & 'out_card.png')
    OF 2 ; ok = Two.LoadFile(Here & 'out_card.bmp')
    OF 3 ; ok = Two.LoadFile(Here & 'out_card.jpg')
    OF 4 ; ok = Two.LoadFile(Here & 'out_card.gif')
    OF 5 ; ok = Two.LoadFile(Here & 'out_card.tif')
    OF 6 ; ok = Two.LoadFile(Here & 'out_card.tga')
    OF 7 ; ok = Two.LoadFile(Here & 'out_card.qoi')
    OF 8 ; ok = Two.LoadFile(Here & 'out_card.pcx')
    OF 9 ; ok = Two.LoadFile(Here & 'out_card.ppm')
    END
    IF ok
      PUTINI('load', 'f' & i, CLIP(Two.FormatName()) & ' ' & Two.Wide() & 'x' & Two.High() & |
                              ' src' & Two.SrcDepth() & 'bit', INI)
    ELSE
      PUTINI('load', 'f' & i, 'FAILED err=' & Two.LastError(), INI)
    END
  END
  ! ---- colour conversions ----
  LOOP i = 1 TO 11
    Two.TestCard(240, 180)
    IF Two.Convert(i, CHOOSE(i > 4, 1, 0))
      PUTINI('conv', 'm' & i, CLIP(Two.ColorModeName()) & ' colors=' & Two.Colors(), INI)
      Two.SaveFile(Here & 'conv_' & i & '.bmp')
    ELSE
      PUTINI('conv', 'm' & i, 'FAILED err=' & Two.LastError(), INI)
    END
  END
  ! ---- geometry ----
  Pic.TestCard(400, 300)
  PUTINI('geo','rot90',   Pic.RotateRight() & ' ' & Pic.Wide() & 'x' & Pic.High(), INI)
  PUTINI('geo','mirror',  Pic.Mirror(), INI)
  PUTINI('geo','rot33',   Pic.Rotate(33) & ' ' & Pic.Wide() & 'x' & Pic.High(), INI)
  PUTINI('geo','resize',  Pic.Resize(200, 150, Img:Best) & ' ' & Pic.Wide() & 'x' & Pic.High(), INI)
  PUTINI('geo','fit',     Pic.Fit(320, 240, Img:Proportional, 0FF000000h) & ' ' & Pic.Wide() & 'x' & Pic.High(), INI)
  PUTINI('geo','crop',    Pic.Crop(10, 10, 100, 80) & ' ' & Pic.Wide() & 'x' & Pic.High(), INI)
  Pic.SaveFile(Here & 'out_geo.png')
  ! ---- adjustments ----
  Pic.TestCard(320, 240)
  PUTINI('adj','gamma',   Pic.Gamma(2.2), INI)
  PUTINI('adj','adjust',  Pic.Adjust(10, 20, -30), INI)
  PUTINI('adj','levels',  Pic.Levels(20, 235), INI)
  PUTINI('adj','blur',    Pic.Blur(3, 2), INI)
  PUTINI('adj','sharpen', Pic.Sharpen(120), INI)
  PUTINI('adj','sepia',   Pic.Sepia(), INI)
  PUTINI('adj','pre_hist','here',INI)
  ok = Pic.Histogram()
  PUTINI('adj','hist_peak',ok,INI)
  PUTINI('adj','hist_bins', Pic.HistogramBin(0) & ' ' & Pic.HistogramBin(128) & ' ' & Pic.HistogramBin(255), INI)
  Pic.SaveFile(Here & 'out_adj.png')
  PUTINI('t','done','yes',INI)
  RETURN
