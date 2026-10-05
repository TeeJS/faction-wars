$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$repo='D:\Github\faction-wars'
$root=Join-Path $repo 'packs\ww2\art\planets'
$master=Join-Path $root 'vintage-1940s-comic-masters-2026-10-04'
$proposals=Join-Path $master '1939-proposals'
$rows=@(Get-Content -LiteralPath (Join-Path $proposals 'manifest.json') -Raw|ConvertFrom-Json)
$installation=@(Get-Content -LiteralPath (Join-Path $master 'installation-manifest.json') -Raw|ConvertFrom-Json)
foreach($row in $rows){
$id=$row.id
$cardPath=Join-Path $proposals ($id+'.png')
$card=[System.Drawing.Bitmap]::FromFile($cardPath)
$original=[System.Drawing.Bitmap]::FromFile((Join-Path (Join-Path $root 'backup-originals-2026-10-04') ($id+'.png')))
if($card.Width -ne 400 -or $card.Height -ne 200){throw 'Wrong card dimensions'}
for($y=0;$y -lt 200;$y++){
for($x=0;$x -lt 400;$x++){
if($x -ge 13 -and $x -lt 387 -and $y -ge 13 -and $y -lt 166){continue}
if($card.GetPixel($x,$y).ToArgb() -ne $original.GetPixel($x,$y).ToArgb()){throw ('Original frame/caption changed '+$id)}
}}
$card.Dispose();$original.Dispose()
$large=[System.Drawing.Image]::FromFile((Join-Path $proposals ($id+'-master.png')))
if($large.Width -ne 1600 -or $large.Height -ne 800){throw 'Wrong master dimensions'}
$large.Dispose()
Copy-Item -LiteralPath $cardPath -Destination (Join-Path $root ($id+'.png')) -Force
Copy-Item -LiteralPath $cardPath -Destination (Join-Path (Join-Path $master 'game-size') ($id+'.png')) -Force
Copy-Item -LiteralPath (Join-Path $proposals ($id+'-master.png')) -Destination (Join-Path $master ($id+'.png')) -Force
$row.status='approved_and_installed'
$row|Add-Member -NotePropertyName approval -NotePropertyValue 'User approved all five previews on 2026-10-04: approved' -Force
$installation+=[pscustomobject]@{name=$id+'.png';sha256=(Get-FileHash -LiteralPath (Join-Path $root ($id+'.png'))).Hash;status='approved_1939_replacement';outside_card_illustration_changed_pixels=0;source=$row.source;approval=$row.approval}
}
if($installation.Count -ne 88){throw 'Expected 88 installed cards'}
foreach($row in $installation){if((Get-FileHash -LiteralPath (Join-Path $root $row.name)).Hash -ne $row.sha256){throw ('Installed hash mismatch '+$row.name)}}
ConvertTo-Json -InputObject $rows -Depth 20|Set-Content -LiteralPath (Join-Path $proposals 'manifest.json')
ConvertTo-Json -InputObject $installation -Depth 20|Set-Content -LiteralPath (Join-Path $master 'installation-manifest.json')
ConvertTo-Json -InputObject ([ordered]@{scope='400x200 Encyclopedia cards only; 37x37 sprites retain original source records';approved='2026-10-04';records=$rows}) -Depth 20|Set-Content -LiteralPath (Join-Path $master 'approved-card-sources.json')
$creditsPath=Join-Path $repo 'packs\ww2\credits.json'
$raw=Get-Content -LiteralPath $creditsPath -Raw
foreach($row in $rows){$raw=$raw.Replace(', "art/planets/'+$row.id+'.png"','')}
$raw=$raw.Replace('Burma, Ceylon, Malta, Kazakhstan and Indochina await approval of separate 1939 proposals.','Burma, Ceylon, Malta, Kazakhstan and Indochina now use the five approved 1939 replacements, with separate source and licence entries.')
$entries=@()
foreach($row in $rows){
$s=$row.source
$entries+=[ordered]@{
title='1939 flag card: '+$row.id
what='Encyclopedia region flag card; replacement approved 2026-10-04'
author=$s.author
source=$s.page
licence=$s.license
licence_url=$s.licenseUrl
changes='Reference flag redrawn with OpenAI ImageGen in vintage 1940s comic style; period '+$s.period+'. Original card frame and caption preserved; flag balanced at 2:1. Installed 400 x 200 after explicit user approval. Adaptation shared under the same source licence where applicable. Source images, hashes and prompts: art/planets/vintage-1940s-comic-masters-2026-10-04/1939-proposals/manifest.json.'
files=@('art/planets/'+$row.id+'.png')
}
}
$extra=($entries|ForEach-Object {ConvertTo-Json -InputObject $_ -Depth 10}) -join ",`n"
$raw=[regex]::Replace($raw,'\}\s*\]\s*\}\s*$',"},`n"+$extra+"`n  ]`n}")
$parsed=$raw|ConvertFrom-Json
foreach($row in $rows){
$matches=@($parsed.assets|Where-Object {$_.files -contains ('art/planets/'+$row.id+'.png')})
if($matches.Count -ne 1 -or $matches[0].source -ne $row.source.page){throw ('Credit mapping failed '+$row.id)}
}
Set-Content -LiteralPath $creditsPath -Value $raw.TrimEnd()
$flagsPath=Join-Path $repo 'packs\ww2\art\FLAGS.md'
$doc=Get-Content -LiteralPath $flagsPath -Raw
$doc=$doc.Replace('83 of the 88 Encyclopedia cards','All 88 Encyclopedia cards')
$old='Burma, Ceylon, Malta, Kazakhstan and Indochina retain their original cards.'
$start=$doc.IndexOf($old)
$end=$doc.IndexOf('**Do not rerun',$start)
if($start -lt 0 -or $end -lt 0){throw 'Cannot find approval paragraph'}
$new=@'
The user approved all five 1939 replacement previews on 2026-10-04. Burma,
Ceylon and Malta now use their British colonial Blue Ensigns; Kazakhstan
uses its 1937–1940 inscriptions; Indochina uses the 1923–1949 yellow
swallowtail civil/naval ensign. Their original card borders and captions
are preserved, with flags balanced at 240 x 120. These five approved card
choices supersede the older country-identity presentation policy below.
The original source table below continues to describe the unchanged 37x37
sprites; approved card sources, attribution and licences are recorded in
the five separate pack-credit entries and in
`planets/vintage-1940s-comic-masters-2026-10-04/approved-card-sources.json`.
Burma adaptation: CC BY-SA 3.0; Ceylon: CC BY-SA 4.0; the other three
reference designs are public domain. See the archived comparison and
source README under `1939-proposals/`.

'@
$doc=$doc.Substring(0,$start)+$new.TrimEnd()+[Environment]::NewLine+[Environment]::NewLine+$doc.Substring($end)
$doc=$doc.Replace('outside the flag interiors remains unchanged','outside the illustration area remains unchanged for all 88 cards; for the 83 style-only cards, every pixel outside the flag interiors remains unchanged')
Set-Content -LiteralPath $flagsPath -Value $doc.TrimEnd()
$p=Join-Path $master 'README.md'
$t=Get-Content -LiteralPath $p -Raw
$t=$t.Replace('- 83 installed style-only cards, 67 distinct generated flags.','- All 88 cards installed: 83 style-only cards from 67 distinct flags, plus five approved 1939 replacements.').Replace('all 83 installed style-only cards for review.','all 88 installed cards for review.').Replace('five previews, not installed.','five approved replacement designs, installed on 2026-10-04.')
$t=$t.Replace('Only flag interiors were replaced; original parchment, frame, labels and drop shadows were preserved pixel-for-pixel in installed cards.','The 83 style-only cards preserve all pixels outside the flag interiors. The five approved replacement cards preserve original frames and labels, with new parchment interiors and balanced 2:1 flags.')
Set-Content -LiteralPath $p -Value $t.TrimEnd()
$p=Join-Path $proposals 'README.md'
$t=Get-Content -LiteralPath $p -Raw
$t=$t.Replace('# 1939 replacement proposals — awaiting approval','# Approved 1939 replacements — installed 2026-10-04').Replace('These five designs are preview candidates only; their game cards remain unchanged.','The user approved all five comparison previews on 2026-10-04; all five are now installed.').Replace('these replace local/national designs and need approval.','these replace local/national designs with explicit user approval.').Replace('Do not copy these previews into the game until the user approves the specific design changes. The 37x37 sprites and generator source data would need a separate consistency decision if these previews are approved.','Approved game cards are installed. The 37x37 sprites and original generator source data remain unchanged because this batch covers Encyclopedia cards in art/planets only. Card source overrides are recorded in ../approved-card-sources.json and separate pack-credit entries.')
Set-Content -LiteralPath $p -Value $t.TrimEnd()
Write-Output 'PASS: all five approved cards installed; all 88 installed hashes verified; original borders/captions preserved; credits and card source records updated.'
