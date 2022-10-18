{$A+,B-,D+,E+,F-,G+,I+,L+,N-,O-,P-,Q-,R-,S+,T-,V+,X+,Y+}
{$M 64000,0,655360}
(********************************************************
                 --- Baby Chess  ---
 @ver 6.10   11.01.2010-

 @author     Nifont.,  2004-2010
 @compiler   Turbo Pascal 7.2
 @site       http://evgeniy-korniloff/narod.ru
 @mail       evgeniy-korniloff@yandex.ru

**********************************************************)


uses graph, crt, uobj, mouse, mysystem;


var
 q_depth,q_cnt,q_mid:integer;


const
 time_per_move:longint  = 5000;




Const
 MaxPly = 60;
 MaxGame = 300;
 EmptyIndex = 32;
 HSIZE = 1 shl 4;
 MAX_LOOK = 6;
Type
  TPiece = (pawn,knight,bishop,rook,queen,king,nopiece,out);
  TColor = (white,black,neutral);
  TSquare = 0..63;
  TIndex = 0..31+1;{+EmptyIndex}
  TScore = integer;{16 bits}
  TMove = record
   case copy:byte of
   0:(
    mFrom,mTo:TSquare;
    mKind:byte;
    mNewPiece:TPiece;
    mSortValue:TScore;
    mCapSq:TSquare;
    mCapIndex:TIndex;);
    (*
   1:(
     m1,m2:longint;
   );
   *)
  end;{sizeof 8 bytes}
  PMove = ^TMove;
  TPieceItem = record
    iSq:TSquare;
    iPiece:TPiece;
    iColor:TColor;
    iEnable:boolean;
    iMoveCnt:LongInt;
  end;{sizeof 8 bytes}
  PPieceItem = ^TPieceItem;
  TPieceStack = record
    stack:array[0..7] of integer;
    top:integer;
  end;
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

  TSummKey = array[white..black] of TKey;
  TGame = record
    keypath:array[0..MaxGame+Maxply] of
      record
        keys:TSummKey;
      end;
    existSq:array[TIndex,TSquare] of byte;
    summKey:TSummKey; {⥪�騩 ����}
    pos:array[TSquare] of TIndex;
    PList:array[TIndex] of TPieceItem;
    PStart,PStop:array[white..black] of TIndex;
    isCastl:array[white..black] of boolean;
    side,xside:TColor;
    mtl,pmtl,stScore:array[white..black] of TScore;
    pCnt:array[white..black,pawn..out] of integer;
    pawnColCnt:array[white..black,0..7] of integer;
    kingSq:array[white..black] of TSquare;
    ply:integer;
    tempo:array[white..black] of integer;
    PieceStack:array[white..black,pawn..out] of TPieceStack;
    gamelist:array[0..MaxGame+MaxPly] of TMove;
    gameCnt,gameMax:integer;
    sideMachin:TColor;
    pawna1h8:array[0..14] of shortInt;{x+y=7}
    pawna8h1:array[-7..7] of shortInt;{x-y=0}
    gametmp:array[0..3] of LongInt;
  end;
  TStBoard = array[0..63] of integer;
Const
  null = 0; normal = 1; capture = 2; promote = 4; enpassant = 16;
  leftcastl = 32; rightcastl = 64;

  valueP = 100; valueN = 350; valueB = 360;
  valueR = 540; valueQ = 2*valueR+80; valueK = 2*valueQ;

  infinity = 30000;
  opSide:array[white..black] of TColor = (black,white);


  HUNG = 8;
  HUNG_EXT = 20;
  BLOCKED = 4;
  PASSED = 24;
  DOUBLE_PAWN = 8;

  ISOL:array[0..7] of integer = (8,10,12,14,14,12,10,8);

  passed_bonus:array[white..black,0..7] of integer =
  (
    (0,64,32,16,8,4,2,0),
    (0,2,4,8,16,32,64,0)
  );

  map:array[0..63] of ShortInt =
   (0,1,2,3,4,5,6,7,
    $10,$11,$12,$13,$14,$15,$16,$17,
    $20,$21,$22,$23,$24,$25,$26,$27,
    $30,$31,$32,$33,$34,$35,$36,$37,
    $40,$41,$42,$43,$44,$45,$46,$47,
    $50,$51,$52,$53,$54,$55,$56,$57,
    $60,$61,$62,$63,$64,$65,$66,$67,
    $70,$71,$72,$73,$74,$75,$76,$77);
  unmap:array[0..119] of integer =
   (0,1,2,3,4,5,6,7,-1,-1,-1,-1,-1,-1,-1,-1,
    8,9,10,11,12,13,14,15,-1,-1,-1,-1,-1,-1,-1,-1,
    16,17,18,19,20,21,22,23,-1,-1,-1,-1,-1,-1,-1,-1,
    24,25,26,27,28,29,30,31,-1,-1,-1,-1,-1,-1,-1,-1,
    32,33,34,35,36,37,38,39,-1,-1,-1,-1,-1,-1,-1,-1,
    40,41,42,43,44,45,46,47,-1,-1,-1,-1,-1,-1,-1,-1,
    48,49,50,51,52,53,54,55,-1,-1,-1,-1,-1,-1,-1,-1,
    56,57,58,59,60,61,62,63);
  DStart:array[pawn..king] of integer = (6,8,4,0,0,0);
  DStop:array[pawn..king] of integer  = (7,15,7,3,7,7);
  dir:array[0..15] of integer =
  (1,$10,-1,-$10,$0F,$11,-$0F,-$11,
  $0E,-$0E,$12,-$12,$1F,-$1F,$21,-$21);
  sweep:array[pawn..king] of boolean = (false,false,true,true,true,false);
  value:array[pawn..king] of integer = (valueP,valueN,valueB,valueR,valueQ,valueK);
  _ = nopiece;
  startPieces:array[0..63] of TPiece =
  (
    rook,knight,bishop,queen,king,bishop,knight,rook,
    pawn,pawn,pawn,pawn,pawn,pawn,pawn,pawn,
    _,_,_,_,_,_,_,_,
    _,_,_,_,_,_,_,_,
    _,_,_,_,_,_,_,_,
    _,_,_,_,_,_,_,_,
    pawn,pawn,pawn,pawn,pawn,pawn,pawn,pawn,
    rook,knight,bishop,queen,king,bishop,knight,rook
  );
  o = neutral;
  startColors:array[0..63] of TColor =
  (
    black,black,black,black,black,black,black,black,
    black,black,black,black,black,black,black,black,
    o,o,o,o,o,o,o,o,
    o,o,o,o,o,o,o,o,
    o,o,o,o,o,o,o,o,
    o,o,o,o,o,o,o,o,
    white,white,white,white,white,white,white,white,
    white,white,white,white,white,white,white,white
  );
 chb:array[TSquare] of string[2] =
   (
   'a8','b8','c8','d8','e8','f8','g8','h8',
   'a7','b7','c7','d7','e7','f7','g7','h7',
   'a6','b6','c6','d6','e6','f6','g6','h6',
   'a5','b5','c5','d5','e5','f5','g5','h5',
   'a4','b4','c4','d4','e4','f4','g4','h4',
   'a3','b3','c3','d3','e3','f3','g3','h3',
   'a2','b2','c2','d2','e2','f2','g2','h2',
   'a1','b1','c1','d1','e1','f1','g1','h1'
   );

Var

 game:TGame;
 row,column:array[TSquare] of ShortInt;
 tree:array[0..MaxPly*40] of TMove;
 treeCnt:array[0..MaxPly] of integer;
 history,mate_history:array[white..black,pawn..out,0..63] of byte;
 killer:array[0..MaxPly] of word;
 glDepth,glScore,glFrom,glTo:integer;
 pRnd:array[TIndex] of integer;
 rnd_table:TStBoard; { 003 }

 root_side:TColor;
procedure InsertPiece(i:TIndex);forward;
procedure RemovePiece(i:TIndex);forward;
procedure InitVar;forward;
procedure InitNewGame(var pieces:array of TPiece;
                      var colors:array of TColor;
                      isCastlWhite,isCastlBlack:boolean;
                      expectedMove:TColor);forward;
procedure InitDefaultGame;forward;
function abs(v:integer):integer;forward;
procedure InitAttack; forward;
function Attack(from,_to:integer; p:TPiece; c:TColor):boolean;forward;
function InCheck:boolean;forward;
procedure RemoveIllegalMoves(isCheck:boolean);forward;
function LegalCastl(var mv:TMove):boolean;forward;
procedure TimeReset;forward;
function TimeUp:boolean;forward;
function SqValue(p:TPiece; c:TColor;  sq:TSquare):TScore;forward;
procedure RootTreeEvaluate;forward;
function Evaluate(alpha,beta:TScore):TScore;forward;
procedure ShowSearchStatus(depth,score,from,_to:integer);forward;
function SqAttack(sq:TSquare; c:TColor):boolean;forward;
procedure  InitRndMoveOrder;forward;


function InsertMoveInGame(mv:TMove):boolean;forward;
function LibFind(var mv:TMove):boolean;forward;
procedure MakeKey(var key:TKey);forward;
procedure HashInit;forward;
procedure HashClear;forward;
procedure HashInsert(score,depth,color,moveFrom,moveTo,isExactScore:integer);forward;
procedure HashStep(c:TColor; p:TPiece; sq:TSquare);forward;
function HashLook(depth,color:integer;
                   var score,moveFrom,moveTo,isExactScore:integer):boolean;forward;
function HashStatus:integer;forward;
function Repetition:boolean;forward;

procedure myassert(expr:boolean);
begin
  if not expr then begin
    expr := false;
    {
    writeln('error');
    halt;
    }
  end;
end;

procedure Push(p:TPiece; c:TColor; sq:TSquare);
begin
 with game, PieceStack[c,p] do begin
   stack[top] := sq;
   top := top + 1;
   myassert(top <= 8);
 end;
end;

procedure Pop(p:TPiece; c:TColor; sq:TSquare);
var
 j,k:integer;
begin
 with game, PieceStack[c,p] do begin
    for j := 0 to top-1 do
     if stack[j] = sq then begin
      for k := j to top-2 do
         stack[k] := stack[k+1];
      top := top-1;
      exit;
     end;
 end;
 myassert(false);
end;


procedure InsertPiece(i:TIndex);   { 003 }
begin
 with game, PList[i] do begin
   pos[iSq] := i;
   iEnable  := true;
   inc(mtl[iColor], value[iPiece]);
   inc(stScore[iColor], SqValue(iPiece,iColor,iSq));
   inc(stScore[iColor], rnd_table[iSq]);
   inc(pCnt[iColor,iPiece]);
   if iPiece = pawn then begin
     inc( pmtl[iColor], value[pawn] );
     inc( pawnColCnt[iColor, column[iSq]] );
     inc(pawna1h8[column[iSq]+row[iSq]]);
     inc(pawna8h1[column[iSq]-row[iSq]]);
   end else if iPiece = king then
     kingSq[iColor] := iSq;
   HashStep(iColor,iPiece,iSq);
   if iColor = white then inc(tempo[iColor],8-row[iSq])
   else inc(tempo[iColor],1+row[iSq]);
   Push(iPiece,iColor,iSq);
 end;
end;
procedure RemovePiece(i:TIndex);
begin
 with game, PList[i] do begin
   pos[iSq] := EmptyIndex;
   iEnable  := false;
   dec(mtl[iColor], value[iPiece]);
   dec(stScore[iColor], SqValue(iPiece,iColor,iSq));
   dec(stScore[iColor], rnd_table[iSq]);
   dec(pCnt[iColor,iPiece]);
   if iPiece = pawn then begin
     dec( pmtl[iColor], value[pawn] );
     dec( pawnColCnt[iColor, column[iSq]] );
     dec(pawna1h8[column[iSq]+row[iSq]]);
     dec(pawna8h1[column[iSq]-row[iSq]]);
   end;
   HashStep(iColor,iPiece,iSq);
   if iColor = white then dec(tempo[iColor],8-row[iSq])
   else dec(tempo[iColor],1+row[iSq]);
   Pop(iPiece,iColor,iSq);
 end;
end;

procedure InitVar;
var
 j:integer;
begin
   for j := 0 to 63 do begin
     row[j] := j div 8;
     column[j] := j mod 8;
   end;
   InitAttack;

   HashInit;
end;



procedure InitNewGame(var pieces:array of TPiece;
                      var colors:array of TColor;
                      isCastlWhite,isCastlBlack:boolean;
                      expectedMove:TColor);
var
 j,i:integer;
 p:TPiece;
 c:TColor;
begin
  with game do begin
    fillchar(game,sizeof(game),0);
    fillchar(mate_history,sizeof(mate_history),0);
{    HashInit;}
    side := expectedMove;
    xside := opSide[side];
    isCastl[white] := isCastlWhite;
    isCastl[black] := isCastlBLack;
    for j := 0 to 63 do
      pos[j] := EmptyIndex;
    PStart[white] := 0;  PStop[white]  := 0;
    PStart[black] := 16; PStop[black]  := 16;
    with PList[EmptyIndex] do begin
      iSq := 0;
      iPiece := nopiece;
      iColor := neutral;
      iEnable := false;
      iMoveCnt := 0;
    end;
    for p := pawn to king do begin
       for j := 0 to 63 do
        if pieces[j] = p then begin
          c := colors[j];
          i := PStop[c];
          inc(Pstop[c]);
          with PList[i] do begin
            iSq := j;
            iPiece := p;
            iColor := c;
            iEnable := false;
            iMoveCnt := 0;
            inc(existSq[i,iSq]);
          end;
          InsertPiece(i);
        end;
    end;
    dec(PStop[white]);
    dec(PStop[black]);
    sideMachin := black;
  end;
  InitRndMoveOrder;
end;

procedure InitDefaultGame;
begin
 InitNewGame(startPieces,startColors,false,false,white);
end;


procedure MakeMove(var move:TMove);
var
 i,rFrom,rTo,rI:integer;
begin
  with game,move do begin
    i := pos[mFrom];
    inc(existSq[i,mTo]);
    RemovePiece(i);
    if (mKind and capture) <> 0 then
      RemovePiece(mCapIndex);
    with PList[i] do begin
      iSq := mTo;
      if (mKind and promote) <> 0 then
        iPiece := mNewPiece;
      inc(iMoveCnt);
    end;
    InsertPiece(i);
    if (mKind and (leftcastl or rightcastl)) <> 0 then begin
       if (mKind and leftcastl) <> 0 then begin
         rFrom := mFrom - 4;
         rTo := mFrom - 1;
       end else begin
         rFrom := mFrom + 3;
         rTo := mFrom + 1;
       end;
       rI := pos[rFrom];
       RemovePiece(rI);
       with PList[rI] do begin
         iSq := rTo;
         isCastl[iColor] := true;
       end;
       InsertPiece(rI);
    end;
  end;
end;


procedure UnMakeMove(var move:TMove);
var
 i,rFrom,rTo,rI:integer;
begin
  with game,move do begin
    i := pos[mTo];
    dec(existSq[i,mTo]);
    RemovePiece(i);
    if (mKind and capture) <> 0 then
      InsertPiece(mCapIndex);
    with PList[i] do begin
      iSq := mFrom;
      if (mKind and promote) <> 0 then
        iPiece := pawn;
      dec(iMoveCnt);
    end;
    InsertPiece(i);
    if (mKind and (leftcastl or rightcastl)) <> 0 then begin
       if (mKind and leftcastl) <> 0 then begin
         rFrom := mFrom - 4;
         rTo := mFrom - 1;
       end else begin
         rFrom := mFrom + 3;
         rTo := mFrom + 1;
       end;
       rI := pos[rTo];
       RemovePiece(rI);
       with PList[rI] do begin
         iSq := rFrom;
         isCastl[iColor] := false;
       end;
       InsertPiece(rI);
    end;
  end;
end;

procedure Generate(isCheck,capOnly:boolean;  best:word);
var
 lastMove:TMove;
 from,_to,n0,n1,t,cnt,i,j,d,dp,firstP,promP,enpassSq,kind:integer;
 p:TPiece;


 procedure LinkMove(newKind:integer);
 var
  capP:TPiece;
 begin
    with game,tree[cnt] do begin
      cnt := cnt + 1;
      mFrom := from;
      mTo := _to;
      mNewPiece := p;
      mKind := newKind;

      {assign sort value}
      if (mKind and capture) <> 0 then begin
        mSortValue := 300;
        if (mKind and enpassant) <> 0 then mCapSq := mTo - dp
        else mCapSq := mTo;
        mCapIndex := pos[mCapSq];
        capP := PList[mCapIndex].iPiece;

        inc(mSortValue, value[capP] - integer(p));
        if mTo = lastMove.mTO then
           inc(mSortValue, valueR);
      end else
         mSortValue := history[side,mNewPiece,mTo];

      if (mKind and promote) <> 0 then begin
        mNewPiece := queen;
        inc(mSortValue,valueQ+300);
      end;

      {002 link move}
      if  ((from shl 6) or _to) = killer[ply] then
          inc(mSortValue, 300);

      if  ((from shl 6) or _to) = best then
          mSortValue := 30000; { the first move }


    end;
 end;
begin
 with game do begin
  cnt := treeCnt[ply];
   if ply < MaxPly - 2 then begin
     if side = white then begin
       dp := -8; firstP := 6; promP := 1;
     end else begin
       dp :=  8; firstP := 1; promP := 6;
     end;
     if gameCnt+ply-1 >= 0 then lastMove := gamelist[gameCnt+ply-1]
     else  lastMove.mKind := null;

     {enpassnat - capture last move pawn}
     enpassSq := -1;
     with lastMove do
      if mKind <> null then
       if mNewPiece = pawn then
        if abs( integer(row[mFrom]) - row[mTo] ) = 2 then
           enpassSq := mTo + dp;



     for i := PStart[side] to PStop[side] do
      with PList[pRnd[i]] do
       if iEnable then begin
         from := iSq; p := iPiece;
         if iPiece = pawn then begin
           _to := from + dp;
           kind := normal;
           if row[from] = promP then kind := kind or promote;
           if not capOnly or ((kind and promote) <> 0) then
            if pos[_to] = EmptyIndex then begin
             LinkMove(kind);
             if row[from] = firstP then
              if pos[_to+dp] = EmptyIndex then begin
                _to := _to + dp;
                LinkMove(kind);
              end;
            end;
           if column[from] < 7 then begin
             _to := from + dp + 1;
             t := pos[_to];
             if _to = enpassSq then LinkMove(kind or capture or enpassant)
             else if (t >= PStart[xside]) and (t <= PStop[xside]) then
               LinkMove(kind or capture);
           end;
           if column[from] > 0 then begin
             _to := from + dp - 1;
             t := pos[_to];
             if _to = enpassSq then LinkMove(kind or capture or enpassant)
             else if (t >= PStart[xside]) and (t <= PStop[xside]) then
               LinkMove(kind or capture);
           end;


         end else begin
           n0 := map[from];
           for j := DStart[p] to DStop[p] do begin
             d := dir[j];
             n1 := n0 + d;
             while (n1 and $88) = 0 do begin
               _to := unmap[n1];
               t := pos[_to];
               if t = EmptyIndex then begin
                 if not capOnly then
                   LinkMove(normal);
               end else begin
                 if (t >= PStart[xside]) and (t <= PStop[xside]) then
                   LinkMove(capture);
                 break;
               end;
               if not sweep[p] then
                 break;
               n1 := n1 + d;
             end;{while}
           end;{for j}

           {castling}
           if p = king then
            if not capOnly then
            if not isCHeck then
            if not isCastl[side] then
             if iMoveCnt = 0 then
              if (from = 4)or(from = 60) then begin

               if  (pos[from+1] = EmptyIndex) and
                   (pos[from+2] = EmptyIndex) then
                 with PList[pos[from+3]] do
                  if (iPiece = rook) and (iMoveCnt = 0) then begin
                    _to := from + 2;
                    LinkMove(rightcastl);
                  end;

               if  (pos[from-1] = EmptyIndex) and
                   (pos[from-2] = EmptyIndex) and
                   (pos[from-3] = EmptyIndex) then
                 with PList[pos[from-4]] do
                  if (iPiece = rook) and (iMoveCnt = 0) then begin
                    _to := from - 2;
                    LinkMove(leftcastl);
                  end;
             end;{if castl}
         end; {if not pawns}
       end;{for i}
   end;{if}
  treeCnt[ply+1] := cnt;
 end; {with}
end;


function abs(v:integer):integer;
begin
  if v >= 0 then abs := v
  else abs := -v;
end;


{********* attacks ************}
const
 base = 16*7 + 8 - 1;
var
 atkc:array[0..16*16-1] of byte;
 atkd:array[0..16*16-1] of ShortInt;
procedure InitAttack;
var
   p:TPiece;
   j,u:integer;
begin
      for p := knight to king do
        for j := DStart[p] to DStop[p] do  begin
          u := base;
          repeat
            u := u + dir[j];
            atkc[u] := atkc[u] or (1 shl ord(p));
            if (p = bishop) and (u - dir[j] = base) then
              atkc[u] := atkc[u] or (1 shl ord(pawn));
            atkd[u] := dir[j];
          until not( sweep[p] and  (u div 16 <> 0) and
                     (u div 16 <> 15) and (u mod 16 <> 0) and
                     (u mod 16 <> 15));
      end;
end;


function Attack(from,_to:integer; p:TPiece; c:TColor):boolean;
var
 u,d,i,n1:integer;
begin
   Attack := false;
   i := integer(map[from]) - map[_to] + base;
   if (atkc[i] and (1 shl ord(p))) <> 0 then
    case p of
     pawn:begin
        if c = black then begin
          if from < _to then Attack := true;
        end else begin
          if from > _to then Attack := true;
        end;
     end;
     knight,king:begin
       Attack := true;
     end;
     else begin   {queen,bishop,rook}
         d := atkd[i];
         n1 := map[_to] + d;
         while (n1 and $88) = 0 do begin
           u := unmap[n1];
           if u = from then begin
             Attack := true;
             exit;
           end;
           if game.pos[u] <> EmptyIndex then
             break;
           n1 := n1 + d;
         end;
     end;
   end;{case}
end;


function SqAttack(sq:TSquare; c:TColor):boolean;
var
 j:integer;
begin
 with game do
  for j := PStart[c] to PStop[c] do
   with PLIst[j] do
    if iEnable then
     if Attack(iSq,sq,iPiece,iColor) then begin
       SqAttack := true;
       exit;
     end;
  SqAttack := false;
end;


procedure RemoveIllegalMoves(isCheck:boolean);
var
 j,cnt:integer;
 a:boolean;
begin
 with game do begin

  cnt := treeCnt[ply];
  for j := treeCnt[ply] to treeCnt[ply+1]-1 do begin
    if (tree[j].mKind and (leftcastl or rightcastl)) <> 0 then
     if isCheck or not LegalCastl(tree[j]) then
      continue;
    MakeMove(tree[j]);

    a := InCheck;

    UnMakeMove(tree[j]);
    if not a then begin
      tree[cnt] := tree[j];
      cnt := cnt + 1;
    end;
  end;{for j}
  treeCnt[ply+1] := cnt;

 end;{with}
end;

function InCheck:boolean;
begin
  with game do
   InCheck := SqAttack(kingSq[side],xside);
end;

function LegalCastl(var mv:TMove):boolean;
var
 j,left,right:integer;
begin
  LegalCastl := true;
  with game, mv do
    if (mKind and (leftcastl or rightcastl)) <> 0 then begin
       if (mKind and leftcastl) <> 0 then begin
         left := mFrom-2; right := mFrom;
       end else begin
         left := mFrom;   right := mFrom+2;
       end;
       for j := left to right do
        if SqAttack(j,xside) then begin
          LegalCastl := false;
          exit;
        end;
    end;
end;

{***********time control******}
const
 MIN_DEPTH = 4;
var
 startTime,currTime,cntPos:LongInt;
 timeOver:boolean;
 s_depth:integer;
 iteration_cnt:integer;

procedure TimeReset;
begin
 startTime := TickCount;
 currTime := startTime;
 cntPos := 0;
 s_depth := 0;
 timeOver := false;
end;

function TimeUp:boolean;
var
 t:LongInt;
begin
 inc(cntPos);

 if not timeOver then
  if (cntPos and $FFF) = 0 then begin
    currTime := TickCOunt;
    if currTime < startTime then startTime := currTime;
    t := currTime - startTime;
    if s_depth > MIN_DEPTH then begin
       if t >= time_per_move then
        timeOver := true;
    end else if t >= 30 * 1000 then
        timeOver := true;
  end;
 TimeUp := timeOver;
end;



procedure  InitRndMoveOrder;
 { ���樠������ � ���ᨢ� �஬���⮪ �� low �� high
  � ��६�訢��� ��� ���砩��� ��ࠧ��}
  procedure RandomArray(var v:array of integer; low,high:integer);
  var
   j,i0,i1,tmp:integer;
  begin
    for j := low to high do
      v[j] := j;




    for j := 0 to 100 do begin
      i0 := random(high-low+1)+low;
      i1 := random(high-low+1)+low;
      tmp := v[i0];
      v[i0] := v[i1];
      v[i1] := tmp;
    end;

  end;

begin
 with game do begin
   RandomArray(pRnd,PStart[white],PStop[white]);
   RandomArray(pRnd,PStart[black],PStop[black]);
 end;
end;



{****** evaluate position *******}
const
st_black_pawn:TStBoard =
(
     0, 0, 0, 0, 0, 0, 0, 0,
     4, 4, 4, 0, 0, 4, 4, 4,
     6, 8, 2,10,10, 2, 8, 6,
     6, 8,12,16,16,12, 8, 6,
     8,12,16,24,24,16,12, 8,
    12,16,24,32,32,24,16,12,
    12,16,24,32,32,24,16,12,
     0, 0, 0, 0, 0, 0, 0, 0
);
st_knight:TStBoard =
(

     0, 4, 8,10,10, 8, 4, 0,
     4, 8,16,20,20,16, 8, 4,
     8,16,24,28,28,24,16, 8,
    10,20,28,32,32,28,20,10,
    10,20,28,32,32,28,20,10,
     8,16,24,28,28,24,16, 8,
     4, 8,16,20,20,16, 8, 4,
     0, 4, 8,10,10, 8, 4, 0

);
st_bishop:TStBoard =
(
 19, 16, 14, 13, 13, 14, 16, 19,
 16, 20, 18, 17, 17, 18, 20, 16,
 14, 18, 23, 22, 22, 23, 18, 14,
 13, 17, 22, 24, 24, 22, 17, 13,
 13, 17, 22, 24, 24, 22, 17, 13,
 14, 18, 23, 22, 22, 23, 18, 14,
 16, 20, 18, 17, 17, 18, 20, 16,
 19, 16, 14, 13, 13, 14, 16, 19
);
st_rook:TStBoard =
(
 0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0
);
st_queen:TStBoard =
(
  9, 10, 11, 11, 11, 11, 10,  9,
 10, 13, 13, 14, 14, 13, 13, 10,
 11, 13, 15, 16, 16, 15, 13, 11,
 11, 14, 16, 18, 18, 16, 14, 11,
 11, 14, 16, 18, 18, 16, 14, 11,
 11, 13, 15, 16, 16, 15, 13, 11,
 10, 13, 13, 14, 14, 13, 13, 10,
  9, 10, 11, 11, 11, 11, 10,  9
);

st_king_end:TStBoard =
(
     0, 4, 8,12,12, 8, 4, 0,
     4,16,20,24,24,20,16, 4,
     8,20,28,32,32,28,20, 8,
    12,24,32,36,36,32,24,12,
    12,24,32,36,36,32,24,12,
     8,20,28,32,32,28,20, 8,
     4,16,20,24,24,20,16, 4,
     0, 4, 8,12,12, 8, 4, 0
);

st_king_open:TStBoard =
(
      0,  0, -4,-10,-10, -4,  0,  0,
     -4, -4, -8,-12,-12, -8, -4, -4,
    -12,-16,-20,-20,-20,-20,-16,-12,
    -16,-20,-24,-24,-24,-24,-20,-16,
    -16,-20,-24,-24,-24,-24,-20,-16,
    -12,-16,-20,-20,-20,-20,-16,-12,
     -4, -4, -8,-12,-12, -8, -4, -4,
      0,  0, -4,-10,-10, -4,  0,  0
);

var
  st_king:TStBoard;
  score_table:array[white..black,pawn..king] of TStBoard;


procedure RootTreeEvaluate;
   function PassedPawnSq( sq:integer; c:TColor; var val:integer):boolean;
   const
     tbl:array[white..black, 0..7] of integer =
     (
      ( 0, 64, 32, 16, 8,  4,  2,  0 ),
      ( 0, 2,  4,  8,  16, 32, 64, 0 )
     );
   var
     d,u,k,j:integer;
   begin
    with game do begin
     if c = white then d := -8 else d := 8;
     u := sq+d;
     while (u > 0) and (u < 64) do
     begin
       for j := -1 to 1 do
        if (j + column[u] >= 0) and (j + column[u] <= 7) then
        begin
          k := j + u;
          if (PList[pos[k]].iColor = opside[c]) and
             (PList[pos[k]].iPiece = pawn) then
             begin
               PassedPawnSq := false;
               exit;
             end;
        end;
       u := u + d;
     end;{while}
    end; {with}

    val := tbl[c, row[sq]];
    PassedPawnSq := true;
   end;



   function DistanceDiag( sq1, sq2:integer ):integer;
   begin
    DistanceDiag :=
    min(
      abs(
         (7 + column[sq1] - row[sq1]) -
         (7 + column[sq2] - row[sq2])
         ),
      abs(
         ( column[sq1] + row[sq1]) -
         ( column[sq2] + row[sq2])
         )
       );
   end;

   function HasPawnOnRank(c:TColor; sq:integer):boolean;
   var
    j,u:integer;
   begin
    with game do
     for j := 0 to 7 do begin
       u := row[sq]*8 + j;
       if (PList[pos[u]].iPiece = pawn) and (PList[pos[u]].iColor=c) then
       begin
         HasPawnOnRank := true;
         exit;
       end;
     end;
     HasPawnOnRank := false;
   end;

   function OpenLine(c:TColor; sq:integer):boolean;
   begin
    with game do
     OpenLine := pawnColCnt[c, column[sq]] = 0;
   end;

   function OperationLine(  sq:integer):boolean;
   begin
    with game do
     OperationLine:= (pawnColCnt[white, column[sq]] = 0) and
                     (pawnColCnt[black, column[sq]] = 0);
   end;


var
 j:integer;
 c:TColor;
 p:TPiece;
 sq,val:integer;
const
  castl_pawn_fine:array[white..black,0..7] of integer =
  (
   ( 0, 0, -5, -5, -3, -1,  1, 0),
   ( 0, 1, -1, -3, -5, -5,  0, 0)
  );
var  rnd_tbl:array[pawn..king] of integer;
const  max_rnd = 100;
   {��� ���� �� ࠡ�⠥�}
   function RndVal( val:integer; p:TPiece ):integer;
   var
    actual_val,actual_rnd, actual_max, actual_add:integer;
   begin
     actual_val := rnd_tbl[p];
     actual_rnd := actual_val - max_rnd div 2; {-max/2 .. max/2 }
     actual_max := max_rnd * 20;
     actual_add := LongInt(actual_val) * actual_rnd div actual_max; {+- 5%}
     RndVal :=  actual_val + actual_add;
     RndVal := val;
   end;
begin
 with game do begin

   fillchar( score_table, sizeof(score_table), 0);

   randomize;
   for p := pawn to king do
     rnd_tbl[p] := random(max_rnd);


   for c := white to black do
   begin
     for p := pawn to king do begin
        case p of
          pawn:
            begin
              for j := 0 to 63 do begin
                if c = white then
                   score_table[c,pawn,j] := st_black_pawn[63-j]
                else
                   score_table[c,pawn,j] := st_black_pawn[j];

                if PassedPawnSq( j, c, val ) then
                   inc( score_table[c,pawn,j], val );

                if iscastl[c] and (pcnt[opside[c],queen] > 0) then
                begin
                   if (column[kingsq[c]] > 4)   {o-o}
                      and (column[j] > 4) then
                   begin
                     inc(  score_table[c,pawn,j],
                           castl_pawn_fine[c, row[j]] );
                   end else if (column[kingsq[c]] < 3) and
                               (column[j] < 3) then
                   begin
                     inc(  score_table[c,pawn,j],
                           castl_pawn_fine[c, row[j]] );
                   end;
                end;
              end;

            end;
          knight:
            begin
             for j := 0 to 63 do begin
                 score_table[c,knight,j] := RndVal(st_knight[j],knight) +
                  (7 - Distance(j, kingsq[ opside[c] ])) ;
             end;
            end;
          bishop:
            begin
             for j := 0 to 63 do begin
                 score_table[c,bishop,j] := RndVal( st_bishop[j], bishop );
                 if pcnt[c, queen] > 0 then
                   inc( score_table[c,bishop,j],
                        12 - DistanceDiag(j, kingsq[ opside[c]]));
             end;
            end;
          rook:
            begin
              for j := 0 to 63 do begin
                 score_table[c,rook,j] := RndVal(st_rook[j],rook) +
                  (14 - Taxi(j, kingsq[ opside[c] ])) div 2;

                if c = white then begin
                  if row[j] = 7 then inc( score_table[c,rook,j], 1)
                  else if (row[j] = 1) and HasPawnOnRank(opside[c],j) then
                    inc( score_table[c,rook,j], 7);

                end else begin
                  if row[j] = 0 then inc( score_table[c,rook,j], 1)
                  else if (row[j] = 6) and HasPawnOnRank(opside[c],j) then
                    inc( score_table[c,rook,j], 7);
                end;
                if OPenLine(c, j) then inc( score_table[c,rook,j], 4);
                if OperationLine(j) then inc( score_table[c,rook,j],6);
              end;
            end;
          queen:
            begin
             for j := 0 to 63 do begin
                 score_table[c,queen,j] := RndVal(st_queen[j],queen) +
                  (14 - Taxi(j, kingsq[ opside[c] ])) ;

             end;
            end;
          king:
            begin
            {�業�� �⠭������ >
             0 ����� ��� ����� � 2 ������ 䨣��}
             for j := 0 to 63 do begin
                   score_table[c,king,j] := RndVal( st_king_end[j],king) -
                   LongInt( RndVal(st_king_end[j],king) )
                     *
                   (
                     pcnt[opside[c],queen]*14  +
                     pcnt[opside[c],rook]*6    +
                     pcnt[opside[c],bishop]*4  +
                     pcnt[opside[c],knight]*3
                   )
                   div
                   (
                      14 + 2*6 + 2*4 + 2*3  - 7
                   );

             end;
            end;
        end; {case}
     end;
   end;

                                                   {recalculate}
   stScore[white] := 0;
   stScore[black] := 0;
   for j := 0 to 63 do
    if pos[j] <> EmptyIndex then
     with PList[pos[j]] do
       inc(stScore[iColor], SqValue(iPiece,iColor,iSq));
 end;
end;




function SqValue(p:TPiece; c:TColor;  sq:TSquare):TScore;
var
 s:TScore;
begin
   s := 0;
   {
   if game.pCnt[white][pawn] + game.pCnt[black][pawn] > 0 then
   begin
     if c = white then s := 63 - sq
     else s := sq;

   end;

   s := s + score_table[c,p,sq];
   }

   SqValue := s;
end;


function CanMated(c:TColor):boolean;
begin
 with game do begin
   if (pCnt[c,pawn] = 0) and
      (pCnt[c,queen] = 0) and
      (pCnt[c,rook]  = 0) and
      (pCnt[c,bishop] * 4  + pCnt[c,knight] * 3 < 8)
      then CanMated := false
   else
      CanMated := true;
 end;
end;


function IsolPawnCnt( c: TColor ):integer;
var
 cnt,j:integer;
begin
 cnt := 0;
 with game do begin
   if c = white then
   begin
     if pawnColCnt[white,1] = 0 then
       cnt := cnt + pawnColCnt[white,0];
     if pawnColCnt[white,6] = 0 then
       cnt := cnt + pawnColCnt[white,7];
     for j := 1 to 6 do
       if pawnColCnt[white,j-1] + pawnColCnt[white,j+1] = 0 then
          cnt := cnt + pawnColCnt[white,j];
   end else begin
     if pawnColCnt[black,1] = 0 then
       cnt := cnt + pawnColCnt[black,0];
     if pawnColCnt[black,6] = 0 then
       cnt := cnt + pawnColCnt[black,7];
     for j := 1 to 6 do
       if pawnColCnt[black,j-1] + pawnColCnt[black,j+1] = 0 then
          cnt := cnt + pawnColCnt[black,j];
   end;
 end;
 IsolPawnCnt := cnt;
end;


function PieceActive( c:TColor; p:TPiece; sq:integer ):integer;
var
 n0,n1,d,u,i,j:integer;
 mobile,atk,first_pawn_row:integer;
begin
 mobile := 0;
 atk := 0;
    with game do begin
      if p = pawn then begin
          if c = white then d := -8 else d := 8;
          if pos[sq+d] = EMptyIndex then begin
              inc(mobile);
              if c = white then begin
                if row[sq] = 6 then
                  if pos[sq+d+d] = EmptyIndex then
                    inc(mobile);
              end else begin
                 if row[sq] = 1 then
                  if pos[sq+d+d] = EmptyIndex then
                    inc(mobile);

              end;
          end;
          if column[sq] > 0 then
            with PList[pos[sq+d-1]] do
              if iColor = opside[c] then
              begin
                inc(mobile);
                inc( atk, ord(iPiece));
              end;
          if column[sq] < 7 then
            with PList[pos[sq+d+1]] do
              if iColor = opside[c] then
              begin
                inc(mobile);
                inc( atk, ord(iPiece));
              end;

      end else begin
           n0 := map[sq];
           for j := DStart[p] to DStop[p] do begin
             d := dir[j];
             n1 := n0 + d;
             while (n1 and $88) = 0 do begin
               u := unmap[n1];
               i := pos[u];
               if i = EmptyIndex then begin
                 inc( mobile );
               end else with PList[i] do begin
                 if iColor = opside[c] then begin
                   inc( mobile );
                   inc( atk, ord(iPiece));
                 end;
                 break;
               end;
               if not sweep[p] then
                 break;
               n1 := n1 + d;
             end;{while}
           end;{for j}
        end; {if not pawn}
    end; {with}
   if p = queen then mobile := mobile div 2
   else if p = king then mobile := 0;
   PieceActive := mobile; { + atk;}
end;

function Evaluate(alpha,beta:TScore):TScore;

var
 s:array[white..black] of TScore;
 margin,score,i:integer;
begin
with game do begin
  if not CanMated(white) and not CanMated(black) then
  begin
    s[white] := 0;
    s[black] := 0;
  end else begin
    s[white] := mtl[white];
    s[black] := mtl[black];
  end;



   s[white] := s[white] + stScore[white];
   s[black] := s[black] + stScore[black];

   margin := 300 - ply;
   score  := s[side] - s[xside];



   if( score + margin < alpha ) or
     ( score - margin > beta ) then
   begin
     evaluate := score;
     exit;
   end;



   if pcnt[white,queen] > 0 then                  {CASTLING BONUS}
     if iscastl[black] then begin
       if column[ kingsq[black] ] > 4 then        {o-o}
         inc(  s[black], 16 )
       else
         inc(  s[black], 4 );
     end else if PList[ pos[ kingsq[black]]].iMoveCnt > 0 then  {move before castl}
         dec( s[black], 4 );

   if pcnt[black,queen] > 0 then
     if iscastl[white] then begin
       if column[ kingsq[white] ] > 4 then                      {o-o}
         inc(  s[white], 16 )
       else
         inc(  s[white], 4 );
     end else if PList[ pos[ kingsq[white]]].iMoveCnt > 0 then  {move before castl}
         dec( s[white], 4 );


                                               {PAWN STRUCT}
   dec(  s[white], IsolPawnCnt(white) shl 2 );
   dec(  s[black], IsolPawnCnt(black) shl 2 );
                                                {ACTIVE}

    for i := PStart[white] to PStop[white] do
      with PList[i] do
       if iEnable then
       { if iPiece in [knight,bishop,rook,queen] then}
         inc( s[white], PieceActive( white,iPiece,iSq ));

    for i := PStart[black] to PStop[black] do
      with PList[i] do
       if iEnable then
{        if iPiece in [knight,bishop,rook,queen] then}
          inc( s[black], PieceActive( black,iPiece,iSq ));



   Evaluate := s[side] - s[xside];
 end;{with}
end;





{*********search*********}

procedure Pick(N1,N2:integer);
var
 maxIndex,j:integer;
 maxVal:TScore;
 temp:TMove;
begin

  maxVal := tree[N1].mSortValue;
  maxIndex := N1;
  for j := N1+1 to N2 do
   with tree[j] do
    if mSortValue > maxVal then begin
        maxVal := mSortValue;
        maxIndex := j;
    end;
  if maxIndex <> N1 then begin

    temp := tree[N1];
    tree[N1] := tree[maxIndex];
    tree[maxIndex] := temp;
    {
    temp.m1 := tree[N1].m1;
    temp.m2 := tree[N1].m2;
    tree[N1].m1 := tree[maxIndex].m1;
    tree[N1].m2 := tree[maxIndex].m2;
    tree[maxIndex].m1 := temp.m1;
    tree[maxIndex].m2 := temp.m2;
     }
  end;
end;

var do_reduction:boolean;

function Search(  alpha,beta,depth:integer; in_check:boolean;
                 _in_mv:integer; var _out_mv:integer
                ): integer;

var
 tmp:TScore;
 next_check,save_do_reduction:boolean;
 d:word;
 j:integer;
 tmp_mv_i,next_depth,lgCnt,margin:integer;
begin
 {002}
 _out_mv := 0;

 tmp_mv_i := -1;


 with game do begin

  if TimeUp then begin
    Search := 0;
    exit;
  end;



  if (beta <  -(infinity - (ply+1))) and (ply > 2) then begin
    Search := beta;
    exit;
  end;


  if (ply >= MaxPly-4) or (ply > glDepth+20)  then begin
     Search := evaluate(alpha,beta);
     exit;
  end;





  if depth <= 0 then begin                               {static cutoff}
    tmp := evaluate(alpha,beta);
    if tmp > alpha then alpha := tmp;
    if alpha >= beta then begin
      Search := alpha;
      exit;
    end;
  end else if ply > 0 then begin

      if not in_check and Repetition then begin
         if side = root_side then
           search := -8
         else search := 0;
         exit;
      end;

  end;





if ply > 0 then begin
 {002 search}
 if depth <= 0 then begin
      generate(in_check,true, 0 );       {captures}
 end else begin
      generate(in_check,false, _in_mv ); {all moves}
 end;

end;



  lgCnt := 0;
  for j := treeCnt[ply] to treeCnt[ply+1]-1 do begin
     Pick(j,treeCnt[ply+1]-1);
   with tree[j] do begin


     if (mKind and (leftcastl or rightcastl)) <> 0 then
      if not LegalCastl(tree[j]) then
       continue;
     MakeMove(tree[j]);

     if InCheck then begin
        UnMakeMove( tree[j] );
        continue;
     end;

     inc(lgCnt);

     gamelist[gamecnt+ply] := tree[j];
     keypath[gamecnt+ply].keys := summkey;

     next_depth := depth - 1;

if depth <= 0 then next_check := false
else begin
     next_check := SqAttack(kingSq[xside],side);


     if(next_Check) then begin
        next_depth := depth;
     end else if mNewPiece = pawn then
       if (row[mTo] = 6) or (row[mTo] = 1) then
         next_depth := depth;
end;

     side := opside[side]; xside := opside[xside]; inc(ply);


     tmp_mv_i := -1;

     if next_depth <= 0  then begin
                         {capture search}
       tmp := -search(-beta,-alpha,next_depth, next_check, tmp_mv_i, tmp_mv_i);

     end else begin
       {001 search}

       tmp := -search(-beta,-alpha,next_depth, next_check, tmp_mv_i, tmp_mv_i);

       (*********************
       if (depth <= 2) and (next_depth < depth) and
          (-Evaluate(-(alpha+1),-alpha) <= alpha) then begin

          tmp := alpha;   {static cut-off}
       end else begin

          {001}
          if (lgCnt=1) then begin    {NEGA SCOUT}

             tmp := -search(-beta,-alpha,next_depth, next_check, tmp_mv_i, tmp_mv_i);

          end else begin

                {save_do_reduction := do_reduction;
                do_reduction := true;}
               tmp := -search(-(alpha+1),-alpha,next_depth, next_check, tmp_mv_i, tmp_mv_i);
              { do_reduction := save_do_reduction;}

               if (tmp > alpha) and (tmp < beta) then
                  tmp := -search(-beta,-alpha,next_depth, next_check, tmp_mv_i, tmp_mv_i);
          end;
       end;
       ********************)

     end;
     side := opside[side]; xside := opside[xside]; dec(ply);




     UnMakeMove(tree[j]);
     if TimeUp then break
     else if tmp > alpha then
     begin
        alpha := tmp;
        {002 search}
        _out_mv := (word(mFrom) shl 6)  or  (word(mTo));

        if ply = 0 then begin

          mSortValue := 15000 + depth*100 + lgcnt;
          ShowSearchStatus(depth,alpha,mFrom,mTo);
          glScore := alpha; glFrom := mFrom; glTo := mTo;
        end;
       if (mkind and capture) = 0 then
        history[side,mNewPiece,mTo] := min(255,
                                        integer(history[side,mNewPiece,mTo])+1);
       if alpha>(infinity-100) then begin
         mate_history[side,mNewPiece,mTo] :=
           min(255,mate_history[side,mNewPiece,mTo]+1);
         history[side,mNewPiece,mTo] := min(255,
                                        integer(history[side,mNewPiece,mTo])+1+random(2));
       end;

       {002 search}
       if ply > 0 then
         if mTo <>  gamelist[gameCnt+ply-1].mTo then
            killer[ply] :=  (word(mFrom) shl 6)  or  (word(mTo));


       if alpha >= beta then break;
     end;



    end;{with tree[j]}
  end;{for j}

 search := alpha;

 if (lgCnt = 0) and (depth > 0)   then  begin
    if in_check then  Search := -(infinity - (ply+1))  {mate}
      else
     Search := 0;                                  {stalemate}

 end;

 end;{with}

end;{search}



{ ////////////////  main search ///////////}
function main_search(  alpha,beta,depth:integer; in_check:boolean;
                 _in_mv:integer; var _out_mv:integer
                ): integer;

var
 tmp:TScore;
 next_check,save_do_reduction:boolean;
 d:word;
 j:integer;
 tmp_mv_i,next_depth,lgCnt:integer;
 fixed_depth:integer;
 peeck_depth:integer;
 start_score:integer;
begin

 {002 main_search}
 {_out_mv := 0;}

{ fixed_depth := max(3, s_depth div 3 + 1); }

 {001}
 fixed_depth := 2; {max(3, s_depth div 3 + 1);}

 if(depth <= fixed_depth) then begin
     main_search := search(alpha,beta,depth,in_check, _in_mv, _out_mv);
     exit;
 end;


 tmp_mv_i := -1;

 with game do begin

  if TimeUp then begin
    main_search:= 0;
    exit;
  end;



  if (beta <  -(infinity - (ply+1))) and (ply > 2) then begin
    main_search := beta;
    exit;
  end;


  if (ply >= MaxPly-4) or (ply > glDepth+20)  then begin
     main_search := evaluate(alpha,beta);
     exit;
  end;





  if depth <= 0 then begin                               {static cutoff}
    tmp := evaluate(alpha,beta);
    if tmp > alpha then alpha := tmp;
    if alpha >= beta then begin
      main_search := alpha;
      exit;
    end;
  end else if ply > 0 then begin

      if not in_check and Repetition then begin
         if side = root_side then
           main_search := -8
         else main_search:= 0;
         exit;
      end;



  end;





if ply > 0 then begin
 {002 main search}
 if depth <= 0 then begin
      generate(in_check,true, 0 );  {captures}
 end else begin
      generate(in_check,false, _in_mv ); {all moves}
 end;

end;



  lgCnt := 0;
  for j := treeCnt[ply] to treeCnt[ply+1]-1 do begin
     Pick(j,treeCnt[ply+1]-1);
   with tree[j] do begin


     if (mKind and (leftcastl or rightcastl)) <> 0 then
      if not LegalCastl(tree[j]) then
       continue;
     MakeMove(tree[j]);

     if InCheck then begin
        UnMakeMove( tree[j] );
        continue;
     end;

     inc(lgCnt);

     gamelist[gamecnt+ply] := tree[j];
     keypath[gamecnt+ply].keys := summkey;

     next_depth := depth - 1;

if depth <= 0 then next_check := false
else begin
     next_check := SqAttack(kingSq[xside],side);

{
     if(next_Check) then begin
        next_depth := max( depth, 1 );
     end else if mNewPiece = pawn then
       if (row[mTo] = 6) or (row[mTo] = 1) then
         next_depth := depth;
         }
end;

     side := opside[side]; xside := opside[xside]; inc(ply);


     tmp_mv_i := 0;

     if next_depth <= fixed_depth  then begin

       tmp := -search(-beta,-alpha,next_depth, next_check, tmp_mv_i, tmp_mv_i);

     end else begin
    {001ms}
       tmp := -search(-beta,-alpha,
                      fixed_depth,
                      next_check, tmp_mv_i, tmp_mv_i);

       peeck_depth := fixed_depth+1;
       while (tmp > alpha) and (peeck_depth <= next_depth) do
       begin
           tmp := -main_search(-beta,
                             -alpha,
                             peeck_depth, next_check, tmp_mv_i, tmp_mv_i);

           inc(peeck_depth);
       end;
     end;




     side := opside[side]; xside := opside[xside]; dec(ply);




     UnMakeMove(tree[j]);
     if TimeUp then break
     else if tmp > alpha then
     begin
        alpha := tmp;

        {002  main_search}
        _out_mv :=  (word(mFrom) shl 6)  or  (word(mTo));

        if ply = 0 then begin

          mSortValue := 15000 + iteration_cnt*100 + lgcnt;
          ShowSearchStatus(depth,alpha,mFrom,mTo);
          glScore := alpha; glFrom := mFrom; glTo := mTo;
        end;
       if (mkind and capture) = 0 then
        history[side,mNewPiece,mTo] := min(255,
                                        integer(history[side,mNewPiece,mTo])+1);
       if alpha>(infinity-100) then begin
         mate_history[side,mNewPiece,mTo] :=
           min(255,mate_history[side,mNewPiece,mTo]+1);
         history[side,mNewPiece,mTo] := min(255,
                                        integer(history[side,mNewPiece,mTo])+1+random(2));
       end;


       if ply > 0 then
         if mTo <>    gamelist[gameCnt+ply-1].mTo then
            killer[ply] :=  (word(mFrom) shl 6)  or  (word(mTo));


       if alpha >= beta then break;
     end;



    end;{with tree[j]}
  end;{for j}

 main_search:= alpha;
 {
 if alpha > beta then
  if random(3)=0 then
    main_search := beta;
    }

 if (lgCnt = 0) and (depth > 0)   then  begin
    if in_check then  main_search:= -(infinity - (ply+1))  {mate}
      else
     main_search:= 0;                                  {stalemate}

 end;

 end;{with}

end;{search}




{/////////////////  end main search ////////////}




{  003 }
function SearchMove(var mv:TMove):boolean;
var

 c:TColor;
 j,d:integer;
 out_mv:word;
 a,b,t,old_result,tmp_i:integer;
 N1,N2:integer;
 temp_move:TMove;
 inc_a,inc_b:integer;
 x,y:integer;
 f:text;
 p:TPiece;
 bb:byte;
begin



   for y := 0 to 7 do
    for x := 0 to 7 do
     if (y in [2..5]) and
        (x in [2..5]) and
        (random(2)=0) then
        rnd_table[y*8 + x] := 1
     else
        rnd_table[y*8 + x] := 0;



   root_side := game.side;
   glDepth := 0; glScore := 0; glFrom := 0; glTo := 0;
   SearchMove := false;
   HashClear;
   TimeReset;
   RootTreeEvaluate;
   InitRndMoveOrder;

  randomize;

  (* fillchar(history,sizeof(history),0);*)
   for c := white to black do
    for p := pawn to king do
     for j := 0 to 63 do begin
        bb := mate_history[c,p,j];
        if bb>0 then
          bb := random(bb div 2 + 2);
        history[c,p,j] := bb;
       { mate_history[c,p,j] := mate_history[c,p,j] div 2;}
     end;



   if (random(20) <> 1) and LibFind(mv) then begin
     ShowSearchStatus(glDepth,glScore,mv.mFrom,mv.mTo);
     SearchMove := true;
     mysystem.delay(600);
     exit;
   end;

  evaluate(-infinity,infinity);
  generate(InCHeck,false,0);
  RemoveIllegalMoves(InCHeck);
  if ( treeCnt[1] = treeCnt[0]) then begin
     SearchMove := false;
     exit;
  end;
  if  treeCnt[1] = treeCnt[0] + 1 then begin
     mv := tree[0];
     ShowSearchStatus(0,0,mv.mFrom,mv.mTo);
     SearchMove := true;
     mysystem.delay(600);
     exit;
  end;



  for j := 0 to treeCnt[1]-1 do
    tree[j].mSortValue := random(100);



  for j := 1 to 40 do begin

    N1 := random( treeCnt[1] );
    N2 := random( treeCnt[1] );

    temp_move := tree[N1];
    tree[N1]  := tree[N2];
    tree[N2]  := temp_move;

  end;


   { 001  }
   inc_a := 4 - random(8);
   inc_b := 4 - random(8);

   glScore := evaluate(-infinity,infinity);
   old_result := glScore;
   d := 2;
   tree[ random( treeCnt[1] ) ].msortvalue  :=  10000;


   iteration_cnt := 1;

   while (d < MaxPly-10) and not TimeUp and
{   while (d < 15) and not TimeUp and}
         (glScore < INFINITY-100) do begin

      s_depth := d;
      glDepth := d;




    { a := glScore - 16 + inc_a;
     b := glSCore + 24 + inc_b;}

    { a := -infinity;}
     a := -infinity+100;      { 001 }
     b := infinity-100;

{      a := glscore - random(5) - 4;
      b := glscore + random(32) + 8;}



     {002 search move}
     t := main_search(a,b,glDepth,incheck, 0, tmp_i);
     inc(iteration_cnt);

     if timeup then break;
     if t >= b then begin
       t := main_search(b,infinity,glDepth,incheck, 0, tmp_i);
       inc(iteration_cnt);
     end else if t <= a then begin
       t := main_search(-infinity,a,glDepth,incheck, 0, tmp_i);
       inc(iteration_cnt);
     end;
     if timeup then break;

     glScore := t;

     if abs(glScore - old_result) < 30 then begin
         if trunc((currTime - startTime)*2)  > time_per_move  then break;
     end;
     old_result := t;
     inc(d,1);
   end;

   {iid;}
   {
   assign(f,'debug.txt');
   rewrite(f);
   writeln(f, 'search depth = ', d, ' search score = ',glScore );
   close(f);
   }

   q_depth := q_depth + s_depth;
   q_cnt := q_cnt + 1;
   q_mid := q_depth div q_cnt;


 {002}
   ShowSearchStatus(glDepth,glScore,glFrom,glTo);
   Pick(0,treeCnt[1]-1);
   mv := tree[0];
   old_result := glScore;
   SearchMove := true;
end;




{***  book ***}
const
 LibMax = 1 shl 8;
 {score book-line (for white pieces)}
 Lib_Better = 1;
 Lib_Worse  = 2;
 Lib_Better1 = 4;
 Lib_Worse1  = 8;
 Lib_Win    = 16;
 Lib_Lose   = 32;
 Lib_Equally = 0;
 Lib_Score_Enum:array[0..6] of integer = (0,1,2,4,8,16,32);
 Lib_Score_Str:array[0..32] of string[4] = (
   '=', '+/=', '=/+', '', '+/-', '', '', '', '-/+', {8}
   '','','','','','','', '+-',
   '','','','','','','','','','','','','','','','-+'
 );
 (*
 Lib_Score_Prioritet:array[White..Black, 0..32] of byte =
 (
   (4,
   5,3,0,6,0,0,0,2,
   0,0,0,0,0,0,0,7,
   0,0,0,0,0,0,0,0,
   0,0,0,0,0,0,0,1
   ),
   (4,
   3,5,0,2,0,0,0,6,
   0,0,0,0,0,0,0,1,
   0,0,0,0,0,0,0,0,
   0,0,0,0,0,0,0,7
   )
 );
 Lib_Score_Rang:array[0..7] of integer =
 (
   0, 2, 4, 8, 16, 32, 64, 128
 );
 *)
type
 TBytePos = array[0..63] of byte;
 PLibItem = ^TLibItem;
 TLibItem = record
   bPackPos:^TBytePos;
   bSize:byte;
   bPly:byte;
   bmoveFlag:byte;
   bMv:byte;
   bdepth:byte;
   bSide:TColor;
   bPrioritet:byte;
   bKey:TKey;
   bNext:PLibItem;
   bScore:TScore;
 end;

var
 lib:array[0..LibMax-1] of PLibItem;

procedure WriteBit(var data:array of byte; N,bit:word);
var
 b:byte;
begin
  b := data[N div 8];
  b := b and not (1 shl (N mod 8)); {reset bit}
  b := b or (bit shl (N mod 8));    {set bit}
  data[N div 8] := b;
end;

{�����뢠�� ⥪���� ������� ������ ���䬠�� � �����}
procedure WritePos(var data:array of byte; var size:integer);
const
 Z = 2; {䫠� ����� ��ப�}
 pieceCode:array[pawn..nopiece] of array[0..7] of byte =
 (
   (1,0, Z,Z,Z,Z,Z,Z),  {pawn}
   (1,1,0,0, Z,Z,Z,Z),  {knight}
   (1,1,0,1, Z,Z,Z,Z),  {bishop}
   (1,1,1,0, Z,Z,Z,Z),  {rook}
   (1,1,1,1,0, Z,Z,Z),  {queen}
   (1,1,1,1,1, Z,Z,Z),  {king}
   (0, Z,Z,Z,Z,Z,Z,Z)   {nopiece}
 );
var
 j,k:integer;
 p:TPiece;
 cnt:word;
begin
 with game do begin
  cnt := 0;
  for j := 0 to 63 do
   with PList[pos[j]] do begin
     if not iEnable then p := nopiece
     else p := iPiece;
     k := 0;
     while pieceCode[p,k] <> Z do begin
       WriteBit(data,cnt,pieceCode[p,k]);
       k := k + 1;
       cnt := cnt + 1;
     end;
     if p <> nopiece then begin
        WriteBit(data,cnt,ord(iColor));
        cnt := cnt + 1;
     end;
   end;
   while (cnt mod 8) <> 0 do begin
     WriteBit(data,cnt,0);
     cnt := cnt + 1;
   end;
   size := cnt div 8;
 end;{with}
end;


function CompPos(var data1:array of byte; size1:integer;
                 var data2:array of byte; size2:integer):boolean;
var
 j:integer;
begin
  CompPos := false;
  if size1 = size2 then begin
   for j := 0 to size1-1 do
    if data1[j] <> data2[j] then exit;
   CompPos := true;
  end;
end;


function MoveFlag:byte;
begin
 with game do begin
   MoveFlag := ord(PList[pos[0]].iMoveCnt > 0) or
               (ord(PList[pos[7]].iMoveCnt > 0) shl 1) or
               (ord(PList[pos[4]].iMoveCnt > 0) shl 2) or

               (ord(PList[pos[56]].iMoveCnt > 0) shl 3) or
               (ord(PList[pos[63]].iMoveCnt > 0) shl 4) or
               (ord(PList[pos[60]].iMoveCnt > 0) shl 5);
 end;
end;



function LibLook(var p:PLibItem):boolean;
var
 buf:array[0..63] of byte;
 size:integer;
 key:TKey;
begin
 with game do begin
  LibLook := false;
  MakeKey(key);
  p := lib[key.key0 and (LibMax-1)];
  while p <> NIL do
    with p^ do begin
      if (bKey.key0 = key.key0) and (bKey.key1 = key.key1) then
       if bSide = game.side then
        if bMoveFlag = MoveFlag then begin
         WritePos(buf,size);
         if CompPos(buf,size,
                    bPackPos^,bSize) then begin
           LibLook := true;
           exit;
         end;
       end;
      p := bNext;
    end;
 end;
end;



procedure NewItem(var p:PLibItem; score,depth,mv:integer);
var
 buf:array[0..63] of byte;
 cnt,j:integer;
begin
  GetMem(p,sizeof(TLibItem));
  WritePos(buf,cnt);
  with game,p^ do begin
    GetMem(bPackPos,cnt);
    for j := 0 to cnt-1 do bPackPos^[j] := buf[j];
    bSize := cnt;
    bPly := ply+gamecnt;
    {bKey := key;}
    MakeKey(bKey);
    bNext := NIL;
    bmoveFlag := MoveFlag;
    bMv := mv;
    bdepth := depth;
    bPrioritet := 0;
    bScore := score;
    bSide := side;
  end;
end;


procedure LibWrite(score,depth,mv,pr:integer);
var
 p:PLibItem;
 key:TKey;
begin
  with game do begin
    if not LibLook(p) then begin
       NewItem(p,score,depth,mv);
       MakeKey(key);
       p^.bNext := lib[key.key0 and (LibMax-1)];
       lib[key.key0 and (LibMax-1)] := p;
       p^.bPrioritet := p^.bPrioritet or pr;
       end else  with p^ do if bDepth <= depth then begin
       bScore := score;
       bDepth := depth;
       bMv := mv;
    end;

  end;
end;

function Repetition:boolean;
var
 j,k,repCnt:integer;
begin
  Repetition := false;
  with game do begin
    j := gamecnt+ply-1;
    repCnt := 0;
    if j > 1 then
     with gamelist[j] do if mKind <> null then
      if existSq[pos[mTo],mTo] > 1 then
       with gamelist[j-1] do if mKind <> null then
        if existSq[pos[mTo],mTo] > 1 then
         for k := j downto 0 do begin
           with gamelist[k] do
            if(mKind = null) or
              ((mKind and (capture or promote or leftcastl or rightcastl)) <> 0) or
               (mNewPiece = pawn) then exit;
            if k < j then
             with keypath[k] do
              if keys[white].key0 = summKey[white].key0 then
               if keys[white].key1 = summKey[white].key1 then
                if keys[black].key0 = summKey[black].key0 then
                 if keys[black].key1 = summKey[black].key1 then
                 begin
                   inc(repCnt);
                   if (k >= gamecnt-1) or (repCnt >= 2) then
                   begin
                     repetition := true;
                     exit;
                   end;
                 end;
            if j - k > 50 then begin
              repetition := true;
              exit;
            end;
         end;{for k}
  end;{with}
end;


function LibFind(var mv:TMove):boolean;
 function GetMaxPr(v:integer; c:TColor):integer;
 begin
     if v = Lib_Equally then GetMaxPr := 8
     else if c = white then begin
       if      (v and Lib_Win) <> 0     then GetMaxPr := 64
       else if (v and Lib_Better1) <> 0 then GetMaxPr := 32
       else if (v and Lib_Better) <> 0  then GetMaxPr := 16
       else if (v and Lib_Worse) <> 0   then GetMaxPr := 4
       else if (v and Lib_Worse1) <> 0  then GetMaxPr := 2
       else if (v and Lib_Lose) <> 0    then GetMaxPr := 1;
     end else begin
       if      (v and Lib_Lose) <> 0     then GetMaxPr := 64
       else if (v and Lib_Worse1) <> 0 then GetMaxPr := 32
       else if (v and Lib_WOrse) <> 0  then GetMaxPr := 16
       else if (v and Lib_Better) <> 0   then GetMaxPr := 4
       else if (v and Lib_Better1) <> 0  then GetMaxPr := 2
       else if (v and Lib_Win) <> 0    then GetMaxPr := 1;
     end;


 end;
var
 buf,rnd:array[0..200] of integer;
 cnt,tmp,pr,bestVal,bestI,i1,i2,k:integer;
 p0,p1:PLibItem;
 capKing:boolean;
 j:integer;
begin
  with game do begin
    cnt := 0;
    if LibLook(p0) then
      if p0^.bDepth = MaxPly then begin
         generate(InCheck,false,0);
         RemoveIllegalMoves(InCheck);
         for j := treeCnt[ply] to treeCnt[ply+1]-1 do
         begin
           MakeMove(tree[j]);
           gamelist[gamecnt+ply] := tree[j];
           keypath[gamecnt+ply].keys := summkey;
           side := opside[side]; xside := opside[xside]; inc(ply);
           if LibLook(p1) then
            if p1^.bDepth = MaxPly then
             if not Repetition then begin
               pr := GetMaxPr( p1^.bPrioritet, xside );
               tmp := random( pr );
               buf[cnt] := j;
               rnd[cnt] := tmp;
               cnt := cnt + 1;
             end;
           side := opside[side]; xside := opside[xside]; dec(ply);
           UnMakeMove(tree[j]);
         end;
         if cnt > 0 then begin
           {random the array}
           for k := 0 to cnt do begin
             i1 := random(cnt);
             i2 := random(cnt);
             tmp := buf[i1]; buf[i1] := buf[i2]; buf[i2] := tmp;
             tmp := rnd[i1]; rnd[i1] := rnd[i2]; rnd[i2] := tmp;
           end;
           {Pick best move}
           bestVal := rnd[0];
           bestI   := buf[0];
           for k := 1 to cnt-1 do
            if rnd[k] > bestVal then begin
              bestVal := rnd[k];
              bestI := buf[k];
            end;

           mv := tree[bestI];
           {mv := tree[ buf[ random(cnt) ]];}
           LibFind := true;
           exit;
         end;
      end;
  end;
  LibFind := false;
end;


function SqIndex(s:string; var N:integer):boolean;
var
 j:integer;
begin
  SqIndex := false;
  for j := 0 to 63 do
   if chb[j] = s then begin
     N := j;
     SqIndex := true;
     exit;
   end;
end;


function StrToMove(s:string; var mv:TMove):boolean;
label
 error;

 function GetPromotePiece(c:char; var p:TPiece):boolean;
 begin
    GetPromotePiece := true;
    case c of
      'Q': p := queen;
      'R': p := rook;
      'B': p := bishop;
      'N': p := knight;
      else GetPromotePiece := false;
    end;
 end;
 function GetPiece(c:char; var p:TPiece):boolean;
 begin
    GetPiece := true;
    case c of
      'Q': p := queen;
      'R': p := rook;
      'B': p := bishop;
      'N': p := knight;
      'P': p := pawn;
      'K': p := king;
      else GetPiece := false;
    end;
 end;
 function GetSqY(c:char; var v:integer):boolean;
 begin
    GetSqY := true;
    case c of
     '1': v := 7;
     '2': v := 6;
     '3': v := 5;
     '4': v := 4;
     '5': v := 3;
     '6': v := 2;
     '7': v := 1;
     '8': v := 0;
     else GetSqY := false;
    end;
 end;
 function GetSqX(c:char; var v:integer):boolean;
 begin
    GetSqX := true;
    case c of
      'a': v := 0;
      'b': v := 1;
      'c': v := 2;
      'd': v := 3;
      'e': v := 4;
      'f': v := 5;
      'g': v := 6;
      'h': v := 7;
      else GetSqX := false;
    end;
 end;

var
 fromX,fromY,toX,toY,j,k,cntFind:integer;
 capStr:string;
 isPromote:boolean;
 piece,newPiece:TPiece;
 capKing:boolean;
begin
 with game do begin
   fromX := -1; fromY := -1; toX := -1; toY := -1;
   capStr := ''; piece := pawn; newPiece := nopiece;
   isPromote := false;
   if s = 'o-o' then begin
      piece := king;
      if side = white then begin
        fromX := column[60]; fromY := row[60];
        toX := column[62]; toY := row[62];
      end else begin
        fromX := column[4]; fromY := row[4];
        toX := column[6]; toY := row[6];
      end;
   end else if s = 'o-o-o' then begin
      piece := king;
      if side = white then begin
        fromX := column[60]; fromY := row[60];
        toX := column[58]; toY := row[58];
      end else begin
        fromX := column[4]; fromY := row[4];
        toX := column[2]; toY := row[2];
      end;
   end else begin


     j := length(s);
     while (j >= 1) and (s[j] in ['!','?','#','+']) do
       j := j - 1;
     if (j >= 1) and GetPromotePiece(s[j],newPiece) then begin
       j := j-1;
       isPromote := true;
     end;
     if(j >= 1) and GetSqY(s[j],toY) then j := j - 1;
     if(j >= 1) and GetSqX(s[j],toX) then j := j - 1;
     if(j >= 1) and (s[j] in [':','-','x','X']) then begin
        capStr := s[j];
        j := j - 1;
     end;
     if(j >= 1) and GetSqY(s[j],fromY) then j := j - 1;
     if(j >= 1) and GetSqX(s[j],fromX) then j := j - 1;
     if(j >= 1) and GetPiece(s[j],piece) then j := j-1
     else if(fromX <> -1) and (fromY <> -1) then
      piece := PList[pos[fromY*8+fromX]].iPiece;
     if j <> 0 then goto error;
     if (piece = pawn) and ((toY = 0) or (toY = 7)) then begin
       isPromote := true;
       if newPiece = nopiece then newPiece := queen;
     end;
 end;

     cntFind := 0;
     generate(InCheck,false,0);
     RemoveIllegalMoves(InCheck);
     for k := 0 to treeCnt[1]-1 do
      with tree[k] do
        if PList[pos[mFrom]].iPiece = piece then
         if(fromY = -1) or (fromY = row[mFrom]) then
          if(fromX = -1) or (fromX = column[mFrom]) then
           if(toY = -1) or (toY = row[mTo]) then
            if(toX = -1) or (toX = column[mTo]) then
             if (capStr = '') or
                ((capStr[1] in [':','x','X']) and ((mKind and capture) <> 0)) or
                ((capStr = '-') and ((mKind and capture) =  0)) then
              if (isPromote and ((mKind and promote) <> 0)) or
                 (not isPromote and ((mKind and promote) = 0)) then
             begin
               mv := tree[k];
               if isPromote and (newPiece <> nopiece) then
                mv.mNewPiece := newPiece;
               inc(cntFind);
             end;
     if cntFind <> 1 then goto error;

 StrToMove := true;
 exit;

error:
 StrToMove := false;
 end;{with}
end;




procedure LibLoad;
const
 ERR_FILE = 'lib.err';
 LIB_FILE = 'lib.dat';
var
 name,firstLine,currLine:string;
 cnt,j:integer;
 F:Text;
 procedure LibError(msg:string);
 const cnt:integer = 0;
 var
  ferr:Text;
 begin

   if cnt = 0 then begin
     assign(ferr,ERR_FILE);
     {$I-}
     rewrite(ferr);
     {$I+}
   end else begin
     assign(ferr,ERR_FILE);
     {$I-}
     append(ferr);
     {$I+}
   end;
   if IOResult = 0 then begin

      writeln(ferr,name + ': ' + msg);
      close(ferr);
      cnt := cnt + 1;
   end;
 end;
 procedure SaveLine(S:String);
 var
   j,k:integer;
   lex,prStr:string;
   mv:TMove;
   cnt,pr:integer;
 begin
   InitDefaultGame;
   LibWrite(0,MaxPly,0, Lib_Equally);
   {Get score line}
    {Get Last Lexem   exemple line:  ' e2e4 e7e5 h2h3 -/+  '
                                                      | last lexem '-/+' is score
    }
   j := length(s);
   prStr := '';
   while ( j > 1 ) and (s[j] = ' ') do dec(j);
   k := j;
   while ( k > 1 ) and (s[k] in ['+','-','/','=']) do dec(k);
   if k < j then begin
     k := k + 1;
     while k <= j do begin
       prStr := prStr + s[k];
       s[k] := ' ';
       k := k + 1;
     end;

     for k := low(Lib_Score_Enum) to high(Lib_Score_Enum) do
       if Lib_Score_Str[Lib_Score_Enum[k]] = prStr then begin
          pr := Lib_Score_Enum[k];
          break;
       end;
   end;

   j := 1;
   cnt := 0;
   while true do begin
     while (j <= length(s)) and (s[j] = ' ') do inc(j); {�஡���}
     if (cnt and 1) = 0 then  {����� 室�}
      while (j <= length(s)) and (s[j] in ['0','1','2','3','4','5','6','7','8','9','.']) do
        inc(j);
     while (j <= length(s)) and (s[j] = ' ') do inc(j); {�஡���}
     if j >= length(s) then exit;
     lex := '';
     while (j <= length(s)) and (s[j] <> ' ') do begin
       lex := lex + s[j];
       inc(j);
     end;

     if StrToMove(lex,mv) then begin
         InsertMoveInGame(mv);
         LibWrite(0,MaxPly,0,pr);
         cnt := cnt + 1;
     end else begin
       LibError(lex);
       exit;
     end;
   end;{while}
 end;



begin
{
  assign(ferr,ERR_FILE);
  rewrite(ferr);
  close(ferr);
}

  Assign(F,LIB_FILE);
  {$I-}
  Reset(F);
  {$I+}
  if IOResult = 0 then begin
     while not EOF(F) do begin
       readln(F,name);
       readln(F,cnt);
       if cnt > 0 then begin
         readln(F,firstLine);
         currLine := firstLine;
         while true do begin
           SaveLine(currLine);
           cnt := cnt-1;
           if cnt = 0 then break;
           if eof(F) then break;
           firstLine := currLine;
           readln(F,currLine);
           for j := 1 to length(currLine) do
            if currLine[j] = ' ' then
             currLine[j] := firstLine[j]
            else break;
         end;{while}
       end;
     end;{while}
     close(F);
  end;
end;


{*** HASH ****}
procedure MakeKey(var key:TKey);
begin
 with game do begin
   key.key0 := summKey[white].key0 xor summKey[black].key0;
   key.key1 := summKey[white].key1 xor summKey[black].key1;
 end;
end;


 var
  randTable:array[white..black,pawn..out,0..63] of TKey;
  hashTable:array[0..1] of PHTable;



 procedure HashInit;
 const
  first:boolean = true;
 var
  c:TColor;
  p:TPiece;
  sq:integer;
 begin
  if first then begin
    first := false;
    for c := white to black do
     for p := pawn to out do
      for sq := 0 to 63 do
       with randTable[c,p,sq] do begin
        Key0 := (LongInt(random($FFFF)) shl 16) or random($FFFF);
        Key1 := (LongInt(random($FFFF)) shl 16) or random($FFFF);
       end;
     GetMem(hashTable[0],sizeof(THTable));
     GetMem(hashTable[1],sizeof(THTable));
   end;
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
  key:TKey;
 begin
   MakeKey(key);
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
  key:TKey;
 begin
   HashLook := false;
   MakeKey(key);
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


 procedure HashStep(c:TColor; p:TPiece; sq:TSquare);
 begin
   with game,randTable[c,p,sq] do begin
     summKey[c].key0 := summkey[c].key0 xor key0;
     summKey[c].key1 := summkey[c].key1 xor key1;
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









{************  grafics interface **********}
function ImageIndex(p:TPiece; c:TColor; isBlackSq:boolean):integer;
const
 dec:array[pawn..king] of integer =
 (5,4,3,2,1,0);
var
 v:integer;
begin
    if p = nopiece then begin
       if isBlackSq then v := 24
       else v := 25;
    end else begin
       if c = black then v := dec[p]
       else v := dec[p] + 12;
       if not isBlackSq then v := v + 6;
    end;
    ImageIndex := v;
end;


procedure ClearRectangle(x,y,W,H:integer);
var
   v: array[1..4] of PointType;
   c:integer;
begin
    c := GetColor;
    SetColor(graph.black);
    SetFillStyle(3,graph.black);
    v[1].x := x; v[1].y := y;
    v[2].x := x+W; v[2].y := y;
    v[3].x := x+W; v[3].y := y+H;
    v[4].x := x; v[4].y := y+H;
    FillPoly(4,v);
    SetColor(c);
end;


const
 brd_left = 20;
 brd_top  = 20;
 ch_width = 50;
 ch_height = 50;
 desc:array[TSquare] of byte =
 (
   0,1,0,1,0,1,0,1,
   1,0,1,0,1,0,1,0,
   0,1,0,1,0,1,0,1,
   1,0,1,0,1,0,1,0,
   0,1,0,1,0,1,0,1,
   1,0,1,0,1,0,1,0,
   0,1,0,1,0,1,0,1,
   1,0,1,0,1,0,1,0
 );
 firstShow:boolean = true;
var
 showSave:array[TSquare] of LongInt;
 sel:array[TSquare] of 0..2;
procedure ShowPos;
const
 msg1 = 'BabyChess';
 menu:array[0..5] of string =
 (
   'Cntrl-A   move (go)',
{   'Cntrl-Z   undo',
   'Cntrl-X   redo', }
   'Cntrl-W   new (white)',
   'Cntrl-B   new (black)',
   'Cntrl-S   save ',
   'Cntrl-D   load ',
   'Esc       exit'
 );
 liters:array[0..7] of char = ('a','b','c','d','e','f','g','h');
var
 j,left,top:integer;
 t:LongInt;
begin
 MouseHide;
 with game do begin
  if firstShow then begin
     firstShow := false;

  {   ClearDevice;}
     for j := low(TSquare) to high(TSquare) do
      showSave[j] := -1;
     MouseShow;

     {header}
     SetTextStyle(DefaultFont,HorizDir,2);
{     OutTextXY((GetMaxX - TextWIdth(msg1)) div 2,4,msg1);}
     OutTextXY((GetMaxX - TextWIdth(msg1)-35),30,   msg1); {X,Y,STR}
     {menu}
     left := GetMaxY - 30;
     top  := 200;
     SetTextStyle(DefaultFont,HorizDir,1);
     for j := low(menu) to high(menu) do begin
       OutTextXY(left,top,menu[j]);
       top := top + 20;
     end;

     {board notation}
     left := brd_left +  ch_width div 2;
     top  := brd_top + 8*ch_height + 4;
     for j := 0 to 7 do begin
       ClearRectangle(left,top,10,10);

       if game.sideMachin = black then
          OutTextXY(left,top,liters[j])
       else
          OutTextXY(left,top,liters[7-j]);

       left := left + ch_width;
     end;

     left := brd_left - 12;
     top  := brd_top + ch_height div 2;
     for j := 8 downto 1 do begin
       ClearRectangle(left,top,10,10);

       if game.sideMachin = black then
         OutTextXY(left,top,IntToStr(j))
       else
         OutTextXY(left,top,IntToStr(9-j));

       top := top + ch_height;
     end;

     ShowSearchStatus(0,0,0,0);
     MouseHide;
  end;

  for j := low(TSquare) to high(TSquare) do
   with PList[pos[j]] do begin
     t := (LongInt(iPiece) shl 24) or
          (LongInt(iColor) shl 16) or
          (LongInt(iSq) shl 8) or
          (LongInt(iEnable) shl 4) or
          LongInt(sel[j]);
     if showSave[j] <> t then begin
        showSave[j] := t;
        if sideMachin = black then begin
          left := brd_left + column[j]*ch_width;
          top := brd_top  + row[j]*ch_height;
        end else begin
          left := brd_left + column[63-j]*ch_width;
          top := brd_top  + row[63-j]*ch_height;
        end;
        ShowFigure(left,top,ImageIndex(iPiece,iColor,desc[j]=1));
        if sel[j] <> 0 then
           {SetColor(graph.white);}
          Rectangle(left+2,top+2,
                    left+ch_width-2,top+ch_height-2);

     end;{if}
   end;{for j}

 end;{with}
 MouseShow;
end;{ShowPos}



procedure ShowSearchStatus(depth,score,from,_to:integer);
  function IntToStr(I: Longint): String;
    var
       S: string[11];
  begin
      Str(I, S);
      IntToStr := S;
  end;
var
   v: array[1..4] of PointType;
   x,y,W,H:integer;
begin

    {0001}
    exit;

    MouseHide;
    W := 100;
    H := 80; {46;}
    x := GetMaxX - W - 30;
    y := GetMaxY - H - 20;
    SetColor(graph.white);
    SetFillStyle(3,graph.black);
    v[1].x := x; v[1].y := y;
    v[2].x := x+W; v[2].y := y;
    v[3].x := x+W; v[3].y := y+H;
    v[4].x := x; v[4].y := y+H;
    FillPoly(4,v);
    OutTextXY(x+4, y+10, 'depth ' + IntToStr(depth));
    OutTextXY(x+4, y + 26, 'score ' + IntToStr(Score));
    OutTextXY(x+4, y + 42, 'time  ' + IntToStr((currTime-startTime)div 1000));
    if From = _To then
       OutTextXY(x+4, y + 58, 'move  ' + 'empty')
    else
       OutTextXY(x+4, y + 58, 'move  ' + chb[from] + chb[_to]);
    MouseShow;
end;




function MouseClick(var N:integer):boolean;
var
   countPress,mx,my,x,y:integer;
begin
       MouseClick := false;
       mouseButtonDown (LEFT_BUTTON,   {����� ������}
                       countPress,   {᪮�쪮 ࠧ �뫠 ������}
                       mX,           {���न���� ��᫥�����}
                       mY            {�������}
                      );
       if countPress > 0 then begin
         x := (mx - brd_left) div ch_width;
         y := (my - brd_top) div ch_height;
         if (word(x) < 8) and (word(y) < 8) then begin
           N := y*8 + x;
           if game.sideMachin = white then N := 63-N;
           MouseClick := true;
         end;
       end;
end;


procedure MoveToStr(mv:TMove; isCheck:boolean; var s:string);
const
 pieceCh:array[pawn..king] of char = ('P','N','B','R','Q','K');
var
 piece:TPiece;
begin
  s := '';
  with game, mv do begin
   if (mKind and (leftcastl or rightcastl)) = 0 then
   begin
    if (mKind and promote) = 0 then begin
      piece := mNewPiece;
      if piece <> pawn then
        s := pieceCh[ piece ];
    end else piece := pawn;
    s := s + chb[mFrom];
    if (mKind and capture) = 0 then s := s + '-'
    else s := s + ':';
    s := s + chb[mTo];
    if (mKind and promote) <> 0 then s := s + pieceCh[mNewPiece];
    if isCheck then s := s + '+';
   end else begin
     s := 'o-o';
     if mTo < mFrom then s := s + '-o';
   end;
  end;
end;



procedure SaveGameList(var F:Text);
var
 j,saveCnt:integer;
 s:string;
begin
  with game do begin
    saveCnt := gamecnt;
    for j := saveCnt-1 downto 0 do begin
     UnMakeMove(gamelist[j]);
     dec(gamecnt);
     side := opside[side];
     xside := opside[xside];
    end;

    for j := 0 to saveCnt-1 do begin
     if j mod 2 = 0 then begin
       if j <> 0 then writeln(f);
       write(f, j div 2 + 1:3, '.');
     end;
     MakeMove(gamelist[j]);
     inc(gamecnt);
     side := opside[side];
     xside := opside[xside];
     MoveToStr(gamelist[j], InCHeck , s);
     write(f,s:8);
    end;
  end;
end;




const
 FILE_NAME = 'lstgame.dat';
var
 grDriver: Integer;
 grMode: Integer;
 ErrCode: Integer;
 c:TColor;
 p:TPiece;
 left:integer;
 sq,selN,j:integer;
 capKing:boolean;
 f:FILE;
 ftext:Text;
 function ControlSumm:LongInt;
   type
     bytearray = array[0..$FFFF-128] of byte;
     pByteArray = ^bytearray;
   var
     p:pbytearray;
     j:integer;
     s:LongInt;
 begin
     s := 0;
     p := @game;
     for j := 0 to sizeof(game)-1 do
      s := s + p^[j];
     ControlSumm := s;
 end;
 function InsertMoveInGame(mv:TMove):boolean;
 var
  s:LongInt;
 begin
  InsertMoveInGame := false;
  with game,mv do begin
   if ((mKind and capture) <> 0) and
      (PList[mCapIndex].iPiece = king) then
      exit;
   if gameCnt < MaxGame then begin
      s := ControlSumm;
      MakeMove(mv);
      UnMakeMove(mv);
      if s <> ControlSumm then
        myassert(false);
      MakeMove(mv);

      gameList[gamecnt] := mv;
      keypath[gamecnt].keys := summkey;
      inc(gamecnt);
      gamemax := gamecnt;
      side := opside[side];
      xside := opside[xside];
      InsertMoveInGame := true;
   end;
  end;{with}
 end;{InsertMoveInGame}

 function Go:boolean;
 var
  mv:TMove;
  tmp:integer;
 begin
   Go := false;
   {clear sel}
   fillchar(sel,sizeof(sel),0);
   selN := -1;
   showpos;

   if game.gamecnt < MaxGame then
    if SearchMove(mv) then
     if InsertMoveInGame(mv) then
     begin
        fillchar(sel,sizeof(sel),0);
        selN := -1;
        with mv do begin
          sel[mFrom] := 2;
          sel[mTo] := 2;
        end;
        showpos;
        Go := true;;
     end;

     {clear input}
     while  keypressed do readkey;
     MouseClick(tmp);

 end;
 procedure beep;
 begin
 (*
  Sound(220);        { Beep }
  MySystem.Delay(200);        { For 200 ms }
  NoSound;           { Relief! }
  *)
 end;


BEGIN


 chb[0] := chb[0];

 InitVar; {before randomize!!!}
 highvideo;
 writeln('load library, please wait...');
 LibLoad;

 if not MouseEnable then
   writeln('mouse not found')
 else begin

  grDriver := Detect;
  InitGraph(grDriver, grMode,' ');
  ErrCode := GraphResult;
  if ErrCode <> grOk then
    Writeln('Graphics error:', GraphErrorMsg(ErrCode))
  else begin  { Do graphics }


     randomize;
{     InitVar;}
     InitDefaultGame;
     LoadPic;
     MouseInit;
     MouseShow;
     MouseSpeed(4,4);
     ShowPos;


     selN := -1;
   with game do
   while true do begin

     if keypressed then
        case ord(readkey) of

          27: break; {esc}
          26: {Cntrl-Z  back}
            if gamecnt > 0 then
            begin
              dec(gamecnt);
              UnMakeMove(gamelist[gamecnt]);
              side := opside[side];
              xside := opside[xside];
              fillchar(sel,sizeof(sel),0);
              selN := -1;
              showpos;
            end;
          24: {Ctrl-X next}
            if gamecnt < gamemax then
            begin
              MakeMove(gamelist[gamecnt]);
              keypath[gamecnt].keys := summkey;
              inc(gamecnt);
              side := opside[side];
              xside := opside[xside];
              fillchar(sel,sizeof(sel),0);
              selN := -1;
              showpos;
            end else beep;
          19:
            begin     {Cntrl-S,  save game}
              Assign(f,FILE_NAME);
              Rewrite(f,1);
              BlockWrite(f,game,sizeof(game));
              Close(f);

              assign(ftext,'list.dat');
              rewrite(ftext);
              SaveGameList(ftext);
              close(ftext);
            end;
          4:
            begin     {Cntrl-D, load game}
              {$I-}
              Assign(f,FILE_NAME);
              Reset(f,1);
              {$I+}
              if IOResult = 0 then begin
                BlockRead(f,game,sizeof(game));
                Close(f);
                fillchar(sel,sizeof(sel),0);
                selN := -1;
                firstShow := true;
                showpos;
              end;
            end;
          23: begin   {Cntrl-W, new game WHITE}
             InitDefaultGame;
             fillchar(sel,sizeof(sel),0);
             selN := -1;
             firstShow := true;
             ShowPos;
          end;
          2:begin  {CNtrl-B  new game black}
             InitDefaultGame;
             game.sideMachin := white;
             fillchar(sel,sizeof(sel),0);
             selN := -1;
             firstSHow := true;
             ShowPos;
             Go;
          end;
          1: begin      {Cntrl-A,  Go}
             if not Go then
               beep;
          end;
          0: readkey;

        end;{case}
     if (pCNt[white,king] = 1) and (pCnt[black,king] = 1) then
     if MouseClick(sq) then
      if side <> sideMachin then  begin

       if PList[pos[sq]].iColor = side then begin
         fillchar(sel,sizeof(sel),0);
         selN := -1;
         generate(InCheck,false,0);
         RemoveIllegalMoves(InCheck);
         for j := 0 to treeCnt[1]-1 do
          with tree[j] do
           if (mFrom = sq) then begin
             selN := sq;
             sel[mTo] := 1;
           end;
         showpos;
       end else begin
         if selN <> -1 then
          if PList[pos[selN]].iColor = side then
          begin
           generate(InCheck,false,0);
           RemoveIllegalMoves(InCheck);
           for j := 0 to treeCnt[1]-1 do
            with tree[j] do
             if (selN = mFrom) and (sq = mTo) then
              if InsertMoveInGame(tree[j]) then
              begin
               fillchar(sel,sizeof(sel),0);
               selN := -1;
               showpos;
               Go;
               break;
              end;
          end;{if}
        end;
         {
         fillchar(sel,sizeof(sel),0);
         sel[sq] := 1;
         showpos;
        }
      end;  {if mouseclick}


   end;{while}

    CloseGraph;
  end
 end; {if mouse found}

 highvideo;
 writeln('*** BabyChess 6.50 ***');
 writeln(' Nifont I, 2004-2010');
 writeln(' free ware ');
 writeln(' free royalty:  http://evgeniy-korniloff.narod.ru/money.html ');
 writeln('...');
{ writeln(' Press any key ');
 readkey;}
 {mysystem.delay(3000);}
 lowvideo;
 writeln('done...');


END.