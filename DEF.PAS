 {$A+,B-,D+,E+,F-,G+,I+,L+,N-,O-,P-,Q-,R-,S-,T-,V+,X+,Y+}
 {$M 64000,0,655360}

unit def;
interface
type
  TPiece = (pawn,king,nopiece);
  TColor = (white,black,neutral,out);
  TIndex = 0..12*2+2-1;
  TSquare = 0..10*10-1;
  TPieceItem = record
    iPiece:TPiece;
    iColor:TColor;
    iEnable:boolean;
    iSquare:TSquare;
  end;
  TMove = record
    mFrom,mTo:TSquare;
    mPiece,mNewPiece:TPiece;
    MCapIndex:LongInt;
    mSortVal:LongInt;
  end;
  PMove = ^TMove;
Squares = (
Z9,A9,B9,C9,D9,E9,F9,G9,H9, X9,

Z8, A8,B8,C8,D8,E8,F8,G8,H8, X8,
Z7, A7,B7,C7,D7,E7,F7,G7,H7, X7,
Z6, A6,B6,C6,D6,E6,F6,G6,H6, X6,
Z5, A5,B5,C5,D5,E5,F5,G5,H5, X5,
Z4, A4,B4,C4,D4,E4,F4,G4,H4, X4,
Z3, A3,B3,C3,D3,E3,F3,G3,H3, X3,
Z2, A2,B2,C2,D2,E2,F2,G2,H2, X2,
Z1, A1,B1,C1,D1,E1,F1,G1,H1, X1,

Z0,A0,B0,C0,D0,E0,F0,G0,H0, X0
);
const
  EmptyIndex = 12*2;
  OutIndex   = EmptyIndex+1;
  Max_Game   = 200;
  Max_Ply    = 60;
  valueP     = 200;
  valueK     = 3*valueP;
  value:array[pawn..king] of integer = (valueP,valueK);
  opSide:array[white..black] of TColor = (black,white);
  infinity = 20000;
  zerroMv:TMove =
  (
    mFrom:0; mTo:0;
    mPiece:nopiece; mNewPiece:nopiece;
    MCapIndex:0;
    mSortVal:0
  );
implementation



end.