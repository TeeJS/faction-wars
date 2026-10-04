$ErrorActionPreference='Stop'
. 'C:\Users\tschmitz\.codex\visualizations\2026\10\04\01a1057c-8f88-73b2-a4a2-f23faa440ea7\flag_bounds.ps1' | Out-Null
$taskRoot='C:\Users\tschmitz\.codex\visualizations\2026\10\04\01a1057c-8f88-73b2-a4a2-f23faa440ea7'
$flagRoot='D:\Github\faction-wars\packs\ww2\art\planets'
$masterRoot=Join-Path $flagRoot 'vintage-1940s-comic-masters-2026-10-04'
$sourceData=Get-Content -LiteralPath (Join-Path $masterRoot 'original-sources.json') -Raw | ConvertFrom-Json
$rows=@(Get-ChildItem -LiteralPath $taskRoot -Filter 'flag-progress-*.json' -File|ForEach-Object {Get-Content -LiteralPath $_.FullName -Raw|ConvertFrom-Json})
$assembled=@()
foreach($row in $rows) {
 $rawPath=Join-Path (Join-Path $masterRoot 'generated-raw') ($row.flag+'.png')
 Copy-Item -LiteralPath $row.path -Destination $rawPath -Force
 $expected=[FlagBounds]::Find((Join-Path (Join-Path $flagRoot 'backup-originals-2026-10-04') ($row.id+'.png')))
 $rect=if($row.fullBleed){@(0,0,1500,1050)}else{[FlagBounds]::FindGenerated($row.path,$expected)}
 $generated=[System.Drawing.Image]::FromFile($row.path)
 $generatedScale=$generated.Width/400.0
 $sourceRect=if($row.fullBleed){[System.Drawing.RectangleF]::new(0,0,$generated.Width,$generated.Height)}else{[System.Drawing.RectangleF]::new(($rect[0]+1.5*$generatedScale),($rect[1]+1.5*$generatedScale),($rect[2]-3*$generatedScale),($rect[3]-3*$generatedScale))}
 $regions=@($sourceData.systems.psobject.Properties | Where-Object {$_.Value.flag -eq $row.flag})
 foreach($region in $regions) {
  $id=$region.Name; $name=$id+'.png'
  $originalPath=Join-Path (Join-Path $flagRoot 'backup-originals-2026-10-04') $name
  $original=[System.Drawing.Image]::FromFile($originalPath)
  $bounds=[FlagBounds]::Find($originalPath)
  foreach($scale in @(1,4)) {
   $canvas=New-Object System.Drawing.Bitmap (400*$scale),(200*$scale)
   $g=[System.Drawing.Graphics]::FromImage($canvas)
   $g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
   if($scale -eq 1) {$g.DrawImageUnscaled($original,0,0)} else {$g.DrawImage($original,0,0,400*$scale,200*$scale)}
   $dest=[System.Drawing.RectangleF]::new(($bounds[0]+2)*$scale,($bounds[1]+2)*$scale,($bounds[2]-4)*$scale,($bounds[3]-4)*$scale)
   $g.SetClip($dest)
   $g.DrawImage($generated,$dest,$sourceRect,[System.Drawing.GraphicsUnit]::Pixel)
   $g.Dispose()
   $outPath=if($scale -eq 1){Join-Path (Join-Path $masterRoot 'game-size') $name}else{Join-Path $masterRoot $name}
   $canvas.Save($outPath,[System.Drawing.Imaging.ImageFormat]::Png)
   $canvas.Dispose()
  }
  $original.Dispose()
  $assembled+=[pscustomobject]@{id=$id;flag=$row.flag;sourceRegion=$row.id;originalBounds=$bounds;generatedBounds=$rect;status='style_only'}
 }
 $generated.Dispose()
}
ConvertTo-Json -InputObject $rows -Depth 15|Set-Content -LiteralPath (Join-Path $masterRoot 'generation-manifest.json')
ConvertTo-Json -InputObject $assembled -Depth 8|Set-Content -LiteralPath (Join-Path $masterRoot 'assembly-manifest.json')
Write-Output ('Assembled '+$assembled.Count+' region cards from '+$rows.Count+' unique flag redraws.')
