$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies @([System.Drawing.Bitmap].Assembly.Location,[System.Drawing.Color].Assembly.Location,[System.Reflection.Assembly]::Load('System.Private.Windows.GdiPlus').Location,[System.Reflection.Assembly]::Load('System.Private.Windows.Core').Location) -TypeDefinition @'
using System;
using System.Drawing;
public static class FlagBounds {
 static bool Dark(Color c){return c.R<110&&c.G<110&&c.B<110;}
 public static int[] FindGenerated(string path, int[] expected) {
  using(var b=new Bitmap(path)) {
   double s=b.Width/400.0;
   int left=Edge(b,expected,s,0),right=Edge(b,expected,s,1),top=Edge(b,expected,s,2),bottom=Edge(b,expected,s,3);
   return new int[]{left,top,right-left+1,bottom-top+1};
  }
 }
 static int Edge(Bitmap b,int[] e,double s,int side) {
  bool vertical=side<2, first=side==0||side==2;
  double at=(side==0?e[0]:side==1?e[0]+e[2]-1:side==2?e[1]:e[1]+e[3]-1)*s;
  int begin=(int)((vertical?e[1]+10:e[0]+10)*s),end=(int)((vertical?e[1]+e[3]-10:e[0]+e[2]-10)*s);
  int low=(int)(at-8*s),high=(int)(at+8*s),best=0,chosen=(int)at;
  int[] counts=new int[high-low+1];
  for(int k=low;k<=high;k++){int n=0;for(int j=begin;j<end;j++)if(Dark(b.GetPixel(vertical?k:j,vertical?j:k)))n++;counts[k-low]=n;if(n>best)best=n;}
  if(best<(end-begin)*0.5)throw new Exception("Weak generated edge: "+side);
  for(int k=low;k<=high;k++)if(counts[k-low]>=best*0.9){chosen=k;if(first)break;}
  return chosen;
 }
 public static int[] Find(string path) {
  using(var b=new Bitmap(path)) {
   double scale=b.Width/400.0;
   int left=0,right=0,top=0;
   bool found=false;
   for(int y=(int)(20*scale);y<(int)(95*scale)&&!found;y++) {
    int start=-1;
    for(int x=(int)(65*scale);x<=(int)(335*scale);x++) {
     if(Dark(b.GetPixel(x,y))){if(start<0)start=x;}
     else if(start>=0){if(x-start>100*scale){left=start;right=x-1;top=y;found=true;break;}start=-1;}
    }
   }
   if(!found)throw new Exception("No flag border: "+path);
   int bottom=top;
   for(int y=top;y<(int)(165*scale);y++) {
    bool edge=false;
    for(int x=left;x<Math.Min(right,left+Math.Max(2,(int)(2*scale)));x++)if(Dark(b.GetPixel(x,y))){edge=true;break;}
    if(!edge)break;
    bottom=y;
   }
   if(bottom-top<25*scale)throw new Exception("Short flag border: "+path);
   return new int[]{left,top,right-left+1,bottom-top+1};
  }
 }
}
'@
$root='D:\Github\faction-wars\packs\ww2\art\planets'
$rows=@(Get-ChildItem -LiteralPath $root -Filter '*.png' -File | ForEach-Object {[pscustomobject]@{id=$_.BaseName;rect=[FlagBounds]::Find($_.FullName)}})
ConvertTo-Json -InputObject $rows -Depth 4
