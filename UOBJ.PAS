unit uobj;
INTERFACE

 {
    линкование файла масок картинок
    и вывод одной фигуры на экран
 }
CONST
 sq_width = 50;   {клетки доски}
 sq_height = 50;

type
TByteArray = array[0..64000] of byte;
PByteArray = ^TByteArray;

procedure LoadPic;
procedure ShowFigure(left,top,number:word);


IMPLEMENTATION
uses graph;
{$L pic.obj}
procedure picdat;external;

var pic:PByteArray;

procedure LoadPic;
begin
    pic := @picdat;
end;

procedure vga_mode;
begin
   port[$3CE] := 5;
   port[$3CF] := 2;
end;


procedure vga_mask(x:word);
begin
   port[$3CE] := 8;
   port[$3CF] := 1 shl (7 - (x and 7));
end;


procedure vga_put(x,y:word; c:byte);
var
 d:word;
 tmp:byte;
begin
   {!!! CALL  vga_mode  AND vga_mask before }

   d := y*(640 shr 3) + (x shr 3);
   tmp := mem[$A000:d];
   mem[$A000:d] := c;
end;
{*************
function vga_get(x,y:word):byte;
begin
   vga_get := mem[$A000: y*(640 shr 3) + (x shr 3)];
end;
*************}

procedure ShowFigure(left,top,number:word);
var
 p:PByteArray;
 x,y,mask,color:integer;
begin

  vga_mode;

  p := @pic^[number*sq_width*sq_height];

 for x := 0 to sq_width-1 do
 begin
   vga_mask(left+x);

   for y := 0 to sq_height-1 do
    begin
     mask := p^[y*sq_width + x];
     if (mask = 0) then color := BLACK
     else color := LightGray;

     vga_put(left+x,top+y,color);

   end;
 end;
end;



END.