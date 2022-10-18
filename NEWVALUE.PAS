uses mysystem;

function NValue(sFrom,sTo,from:integer):integer;
const
 MaxTaxi = 14;
var
 T,sT:integer;
begin
  sT := Taxi(sFrom,sTo); {путь от стартовой точки до конечной}
  T  := Taxi(from,sTo);
  NValue := 2*sT  - 2 * MaxTaxi * T div sT;
end;

procedure PrintPieceAr(var F:Text; header:string; sFrom,sTo:integer);
var
 x,y:integer;
begin
  writeln(F,header, sFrom:3, sTo:3);
  for y := 0 to 7 do begin
    for x := 0 to 7 do
     write(F,NValue(sFrom,sTo,y*8+x):3,',');
    writeln(F);
  end;
  writeln(F);
end;

VAR
 F:Text;
 j:integer;
BEGIN
 assign(F,'newvalue.txt');
 rewrite(F);

 for j := 48 to 63 do
  PrintPieceAr(F,'white',j,63-j);
 close(F);
END.