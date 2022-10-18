{$A+,B-,D+,E+,F-,G+,I+,L+,N-,O-,P-,Q-,R-,S-,T-,V+,X+,Y+}
{$M 64000,0,655360}
{
 поддержка мыши
 реальный и защищенный режим
  2-12-01
}
unit mouse;
                INTERFACE
uses DOS;

{кнопки мыши}
CONST
  LEFT_BUTTON   = 1;
  RIGHT_BUTTON  = 2;



function  mouseEnable:boolean; {доступна ли мышь}
procedure mouseInit;           {инициализация мыши}
procedure mouseClose;          {завершение работы с мышью}
procedure mouseShow;           {показ указателя}
procedure mouseHide;
procedure mouseCurrPos(var x:integer;  var y:integer); {текущие координаты}
procedure mouseCurrButton(var button:integer); {текущее состояние кнопок}
{информация о последнем нажатии заданной кнопки button}
procedure mouseButtonDown(button:integer;          {какая кнопка}
                          var countPress:integer;  {сколько раз была нажата}
                          var lastX:integer;       {координаты последнего}
                          var lastY:integer        {нажатия}
                          );


{информация о последнем отпускании заданной кнопки button}
procedure mouseButtonUp(button:integer;            {какая кнопка}
                          var countPress:integer;  {сколько раз была нажата}
                          var lastX:integer;       {координаты последнего}
                          var lastY:integer        {нажатия}
                          );
{скорость перемещения}
procedure mouseSpeed(delX,delY:integer);
procedure mouseSetVisualPage(N:integer);

                IMPLEMENTATION
CONST
 __mouseEnable:boolean = false;
 __mouseShow:boolean   = false;
VAR
 regs: Registers;



{скорость перемещения}
procedure mouseSpeed(delX,delY:integer);
begin
   with regs do
    begin
       ax := $0F;
       cx := delX;
       dx := delY;
       intr($33,regs);
    end;
end;

function mouseEnable:boolean;
begin
    with regs do
    begin
       ax := 0;
       intr($33,regs);
       mouseEnable := ax = $FFFF;
       __mouseShow := false;
    end;
end;

procedure mouseInit;
begin
    with regs do
    begin
       ax := 0;
       intr($33,regs);
       __mouseEnable := ax = $FFFF;
       __mouseShow   := false;
    end;
end;

procedure mouseClose;
begin
    with regs do
    begin
       ax := 0;
       intr($33,regs);
       __mouseEnable := false;
       __mouseShow   := false;
    end;
end;


procedure mouseShow;
begin
  if __mouseEnable  and  not __mouseShow   then
  begin
      regs.ax := 1;
      intr($33,regs);
      __mouseShow := true;
  end;
end;


procedure mouseHide;
begin
  if __mouseEnable  and  __mouseShow   then
  begin
      regs.ax := 2;
      intr($33,regs);
      __mouseShow := false;
  end;
end;

procedure mouseSetVisualPage(N:integer);
begin
  if __mouseEnable  then
  begin
      regs.ax := $1D;
      regs.bx := N;
      intr($33,regs);
  end;
end;


procedure mouseCurrPos(var x:integer;  var y:integer);
begin
  if __mouseEnable then
  begin
      with regs do
      begin
        ax := 3;
        intr($33,regs);
        x := cx;
        y := dx;
      end;
  end;
end;


procedure mouseCurrButton(var button:integer);
begin
  if __mouseEnable then
  begin
      with regs do
      begin
        ax := 3;
        intr($33,regs);
        button := bx;
      end;
  end;
end;

procedure mouseButtonDown(button:integer;          {какая кнопка}
                          var countPress:integer;  {сколько раз была нажата}
                          var lastX:integer;       {координаты последнего}
                          var lastY:integer        {нажатия}
                          );
begin
  if __mouseEnable then
  begin
       case button of
          LEFT_BUTTON:button := 0;
          RIGHT_BUTTON:button := 1;
          else exit;
       end;
       with regs do
       begin
         ax := 5;
         bx := button;
         intr($33,regs);
         countPress := bx;
         lastX := cx;
         lastY := dx;
       end;
  end;
end;



procedure mouseButtonUp(button:integer;          {какая кнопка}
                          var countPress:integer;  {сколько раз была нажата}
                          var lastX:integer;       {координаты последнего}
                          var lastY:integer        {нажатия}
                          );
begin
  if __mouseEnable then
  begin
      case button of
          LEFT_BUTTON:button := 0;
          RIGHT_BUTTON:button := 1;
          else exit;
       end;
       with regs do
       begin
         ax := 6;
         bx := button;
         intr($33,regs);
         countPress := bx;
         lastX := cx;
         lastY := dx;
       end;
  end;
end;

                END.