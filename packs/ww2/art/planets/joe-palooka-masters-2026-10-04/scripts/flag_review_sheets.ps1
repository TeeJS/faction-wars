$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$master='D:\Github\faction-wars\packs\ww2\art\planets\joe-palooka-masters-2026-10-04'
$cards=@(Get-ChildItem -LiteralPath (Join-Path $master 'game-size') -Filter '*.png' -File|Sort-Object Name)
for($start=0;$start -lt $cards.Count;$start+=15){
 $count=[Math]::Min(15,$cards.Count-$start)
 $sheet=[System.Drawing.Bitmap]::new(1200,200*[Math]::Ceiling($count/3.0))
 $g=[System.Drawing.Graphics]::FromImage($sheet);$g.Clear([System.Drawing.Color]::FromArgb(235,230,212))
 for($j=0;$j -lt $count;$j++){$img=[System.Drawing.Image]::FromFile($cards[$start+$j].FullName);$g.DrawImageUnscaled($img,400*($j%3),200*[Math]::Floor($j/3));$img.Dispose()}
 $g.Dispose();$path=Join-Path $master ('contact-sheet-'+([int]($start/15)+1)+'.png');$sheet.Save($path);$sheet.Dispose();Write-Output $path
}
