unit mysystem;

interface

function TickCount:LongInt;
procedure delay(ms:word);
function abs(N:integer):integer;
function Taxi(N1,N2:integer):integer;
function IntToStr(I: Longint): String;
function Distance(N1,N2:integer):integer;
function Max(N1,N2:integer):integer;
function Min(N1,N2:integer):integer;
implementation

function TickCount:LongInt;
var
 timer:LongInt absolute $40:$6C;
begin
  TickCount := timer * 1000  div  18;
end;

procedure delay(ms:word);
var
 t0,t1:LongInt;
begin
    t0 := TickCount;
    while true do begin
      t1 := TickCount;
      if t1 < t0 then t0 := t1;
      if t1-t0 >= ms then break;
    end;
end;

function abs(N:integer):integer;
begin
  if N >= 0 then abs := N
  else abs := -N;
end;

function Taxi(N1,N2:integer):integer;
begin
  Taxi := abs( (N1 and 7) - (N2 and 7) ) +
          abs( (N1 shr 3) - (N2 shr 3) );
end;

function Max(N1,N2:integer):integer;
begin
  if N1 > N2 then Max := N1
  else Max := N2;
end;
function Min(N1,N2:integer):integer;
begin
  if N1 < N2 then Min := N1
  else Min := N2;
end;

function Distance(N1,N2:integer):integer;
begin
  Distance :=
  Max(abs( (N1 and 7) - (N2 and 7) ),
      abs( (N1 shr 3) - (N2 shr 3) ));

end;


function IntToStr(I: Longint): String;
    var
       S: string[11];
begin
      Str(I, S);
      IntToStr := S;
end;


end.