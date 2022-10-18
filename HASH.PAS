unit hash;

interface

const
 HSIZE = 1 shl 12;
 MAX_LOOK = 6;
type
 TKey = record
  key0,key1:LongInt;
 end;
 THItem = record
   hKey:TKey;
   hScore:integer;
   hDepth:byte;
   hFlag:byte;
   hFrom,hTo:byte;
 end;
 PHItem = ^THItem;
 THTable =  array[0..HSIZE-1] of THItem;
 PHTable = ^THTable;

procedure HashInit;
procedure HashClear;
procedure HashInsert(score,depth,color,moveFrom,moveTo,isExactScore:integer);
procedure HashStep(c,p,sq:integer);
function HashLook(depth,color:integer;
                   var score,moveFrom,moveTo,isExactScore:integer):boolean;
function HashStatus:integer;

var
 key:TKey;


implementation
 const
  c_max = 1;
  p_max = 7;
  sq_max = 63;
 var
  randTable:array[0..c_max,0..p_max,0..sq_max] of TKey;
  hashTable:array[0..1] of PHTable;

 procedure HashInit;
 const
  first:boolean = true;
 var
  c,p,sq:integer;
 begin
  if first then begin
    first := false;
    for c := 0 to c_max do
     for p := 0 to p_max do
      for sq := 0 to sq_max do
       with randTable[c,p,sq] do begin
        Key0 := (LongInt(random($FFFF)) shl 16) or random($FFFF);
        Key1 := (LongInt(random($FFFF)) shl 16) or random($FFFF);
       end;
     GetMem(hashTable[0],sizeof(THTable));
     GetMem(hashTable[1],sizeof(THTable));
   end;
   key.key0 := 0;
   key.key1 := 0;
 end;
 procedure HashClear;
 begin
   fillchar(hashTable[0]^,sizeof(THTable),0);
   fillchar(hashTable[1]^,sizeof(THTable),0);
 end;
 function h(var k:TKey):integer;
 begin
   with k do
     h := key0 and (HSIZE-1);
 end;
 function rh(i:integer):integer;
 begin
    rh := (i+1) and (HSIZE-1);
 end;
 procedure HashInsert(score,depth,color,moveFrom,moveTo,isExactScore:integer);
 var
  cnt,sdepth,i:integer;
  p,ptmp:PHItem;
 begin
   p := NIL;
   cnt := 0;
   i := h(key);
   sdepth := depth;
   repeat
     ptmp := @(hashTable[color]^[i]);
     with ptmp^ do begin
      if hDepth <= sdepth then begin
         p := ptmp;
         sdepth := hDepth;
      end;
      if (hDepth <= 0) or
         ((hKey.key0 = key.key0) and (hKey.key1 = key.key1)) then begin
         p := ptmp;
         break;
      end;
     end;
     i := rh(i);
     cnt := cnt + 1;
   until cnt >= MAX_LOOK;

   if p <> NIL then with p^ do
    if hDepth <= depth then begin
     hKey := key;
     hScore := score;
     hDepth := depth;
     hFlag := isExactScore;
     hFrom := moveFrom;
     hTo := moveTo;
    end;
 end;

 function HashLook(depth,color:integer;
                   var score,moveFrom,moveTo,isExactScore:integer):boolean;
 var
  i,cnt:integer;
 begin
   HashLook := false;
   i := h(key);
   cnt := 0;
   while cnt < MAX_LOOK do begin

     with hashTable[color]^[i] do
      if (hKey.key0 = key.key0) and (hKey.key1 = key.key1) then begin
         if (hDepth >= depth) then begin
           score := hScore;
           moveFrom := hFrom;
           moveTo := hTo;
           isExactScore := hFlag;
           HashLook := true;
         end;
         exit;
      end;
     i := rh(i);
     cnt := cnt + 1;
   end;
 end;


 procedure HashStep(c,p,sq:integer);
 begin
   with randTable[c,p,sq] do begin
     key.key0 := key.key0 xor key0;
     key.key1 := key.key1 xor key1;
   end;
 end;

 function HashStatus:integer;
 var
  j,c:integer;
  cnt:LongInt;
 begin
   cnt := 0;
   for c := 0 to 1 do
    for j := low(THTable) to high(THTable) do
    if hashTable[c]^[j].hdepth > 0 then
      cnt := cnt + 1;
   HashStatus := cnt * 100 div HSIZE div 2;
 end;



end.