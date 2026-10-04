$ErrorActionPreference='Stop'
. 'C:\Users\tschmitz\.codex\visualizations\2026\10\04\01a1057c-8f88-73b2-a4a2-f23faa440ea7\flag_bounds.ps1'|Out-Null
Add-Type -TypeDefinition @'
using System; using System.Drawing;
public class CardVerify {
 public static int[] Compare(string original,string candidate,int[] bounds){
 using(var a=new Bitmap(original))using(var b=new Bitmap(candidate)){
 if(b.Width!=400||b.Height!=200)throw new Exception("Wrong card dimensions");
 int outside=0,inside=0;
 for(int y=0;y<200;y++)for(int x=0;x<400;x++){
 bool interior=x>=bounds[0]+2&&x<bounds[0]+bounds[2]-2&&y>=bounds[1]+2&&y<bounds[1]+bounds[3]-2;
 if(a.GetPixel(x,y).ToArgb()!=b.GetPixel(x,y).ToArgb()){if(interior)inside++;else outside++;}
 }
 return new int[]{outside,inside};
 }}
}
'@ -ReferencedAssemblies @([System.Drawing.Bitmap].Assembly.Location,[System.Drawing.Color].Assembly.Location,[System.Reflection.Assembly]::Load('System.Private.Windows.GdiPlus').Location,[System.Reflection.Assembly]::Load('System.Private.Windows.Core').Location)
$root='D:\Github\faction-wars\packs\ww2\art\planets'
$backup=Join-Path $root 'backup-originals-2026-10-04'
$master=Join-Path $root 'joe-palooka-masters-2026-10-04'
$originals=@(Get-Content -LiteralPath (Join-Path $backup 'manifest.json') -Raw|ConvertFrom-Json)
foreach($row in $originals){
if((Get-FileHash -LiteralPath (Join-Path $backup $row.name) -Algorithm SHA256).Hash -ne $row.sha256){throw ('Backup hash mismatch '+$row.name)}
if((Get-FileHash -LiteralPath (Join-Path $root $row.name) -Algorithm SHA256).Hash -ne $row.sha256){throw ('Root was changed before validation '+$row.name)}
}
$cards=@(Get-ChildItem -LiteralPath (Join-Path $master 'game-size') -Filter '*.png' -File)
if($cards.Count -ne 83){throw 'Expected 83 cards'}
$result=@()
foreach($file in $cards){
$original=Join-Path $backup $file.Name
$bounds=[FlagBounds]::Find($original)
$diff=[CardVerify]::Compare($original,$file.FullName,$bounds)
if($diff[0] -ne 0 -or $diff[1] -lt 1000){throw ('Pixel preservation check failed '+$file.Name+' '+$diff)}
$high=[System.Drawing.Image]::FromFile((Join-Path $master $file.Name))
if($high.Width -ne 1600 -or $high.Height -ne 800){throw 'Master wrong size'}
$high.Dispose()
$result+=[pscustomobject]@{name=$file.Name;sha256=(Get-FileHash -LiteralPath $file.FullName).Hash;outside_flag_changed_pixels=$diff[0];inside_flag_changed_pixels=$diff[1];status='installed_style_only'}
}
foreach($file in $cards){Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $root $file.Name) -Force}
foreach($id in @('burma','ceylon','malta','kazakhstan','indochina')){
$name=$id+'.png';$row=$originals|Where-Object name -eq $name
if((Get-FileHash -LiteralPath (Join-Path $root $name)).Hash -ne $row.sha256){throw ('Unapproved replacement changed '+$name)}
}
ConvertTo-Json -InputObject $result -Depth 5|Set-Content -LiteralPath (Join-Path $master 'installation-manifest.json')
Write-Output 'PASS: all 88 backup hashes verified; 83 cards installed at 400x200 with exact original pixels outside flag interiors; all five pending proposals remain unchanged.'
