$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$taskRoot='C:\Users\tschmitz\.codex\visualizations\2026\10\04\01a1057c-8f88-73b2-a4a2-f23faa440ea7'
$flagRoot='D:\Github\faction-wars\packs\ww2\art\planets'
$master=Join-Path $flagRoot 'vintage-1940s-comic-masters-2026-10-04'
$proposalRoot=Join-Path $master '1939-proposals'
New-Item -ItemType Directory -Path $proposalRoot -Force|Out-Null
$blank=[System.Drawing.Image]::FromFile('C:\Users\tschmitz\.codex\generated_images\01a1057c-8f88-73b2-a4a2-f23faa440ea7\exec-9e109827-c7c1-4052-b8b1-21628dc7435f.png')
Copy-Item -LiteralPath 'C:\Users\tschmitz\.codex\generated_images\01a1057c-8f88-73b2-a4a2-f23faa440ea7\exec-9e109827-c7c1-4052-b8b1-21628dc7435f.png' -Destination (Join-Path $proposalRoot 'blank-card-template.png') -Force
$rows=@()
foreach($id in @('burma','ceylon','malta','kazakhstan','indochina')){
$row=Get-Content -LiteralPath (Join-Path $taskRoot ('flag-full-'+$id+'.json')) -Raw|ConvertFrom-Json
$flag=[System.Drawing.Bitmap]::FromFile($row.path)
if($id -eq 'indochina'){
Write-Output ('Indochina notch alpha: '+$flag.GetPixel($flag.Width-20,[int]($flag.Height/2)).A)
if($flag.GetPixel($flag.Width-20,[int]($flag.Height/2)).A -ne 0){throw 'Indochina notch is not transparent'}
}
Copy-Item -LiteralPath $row.path -Destination (Join-Path $proposalRoot ($id+'-flag.png')) -Force
Copy-Item -LiteralPath $row.source.path -Destination (Join-Path $proposalRoot ($id+'-reference.png')) -Force
$original=[System.Drawing.Image]::FromFile((Join-Path (Join-Path $flagRoot 'backup-originals-2026-10-04') ($id+'.png')))
foreach($scale in @(1,4)){
$canvas=[System.Drawing.Bitmap]::new(400*$scale,200*$scale)
$g=[System.Drawing.Graphics]::FromImage($canvas)
$g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
if($scale -eq 1){$g.DrawImageUnscaled($original,0,0)}else{$g.DrawImage($original,0,0,400*$scale,200*$scale)}
$interior=[System.Drawing.RectangleF]::new(13*$scale,13*$scale,374*$scale,153*$scale)
$g.DrawImage($blank,$interior,[System.Drawing.RectangleF]::new(13*$blank.Width/400,13*$blank.Height/200,374*$blank.Width/400,153*$blank.Height/200),[System.Drawing.GraphicsUnit]::Pixel)
$g.DrawImage($flag,80*$scale,31*$scale,240*$scale,120*$scale)
$g.Dispose()
$name=if($scale -eq 1){$id+'.png'}else{$id+'-master.png'}
$canvas.Save((Join-Path $proposalRoot $name),[System.Drawing.Imaging.ImageFormat]::Png)
$canvas.Dispose()
}
$original.Dispose();$flag.Dispose();$rows+=$row
}
$blank.Dispose()
ConvertTo-Json -InputObject $rows -Depth 15|Set-Content -LiteralPath (Join-Path $proposalRoot 'manifest.json')
$sheet=[System.Drawing.Bitmap]::new(800,1040);$g=[System.Drawing.Graphics]::FromImage($sheet)
$g.Clear([System.Drawing.Color]::FromArgb(235,230,212))
$font=[System.Drawing.Font]::new('Arial',15)
$g.DrawString('EXISTING DESIGN',[System.Drawing.Font]$font,[System.Drawing.Brushes]::Black,95,7)
$g.DrawString('PROPOSED 1939 DESIGN',[System.Drawing.Font]$font,[System.Drawing.Brushes]::Black,480,7)
$i=0
foreach($row in $rows){
$a=[System.Drawing.Image]::FromFile((Join-Path (Join-Path $flagRoot 'backup-originals-2026-10-04') ($row.id+'.png')))
$b=[System.Drawing.Image]::FromFile((Join-Path $proposalRoot ($row.id+'.png')))
$g.DrawImageUnscaled($a,0,40+200*$i);$g.DrawImageUnscaled($b,400,40+200*$i)
$a.Dispose();$b.Dispose();$i++
}
$font.Dispose();$g.Dispose();$sheet.Save((Join-Path $proposalRoot 'approval-comparison.png'));$sheet.Dispose()
Write-Output 'Five proposals assembled; not installed.'
