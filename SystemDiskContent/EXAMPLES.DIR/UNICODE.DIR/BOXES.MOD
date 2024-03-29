IMPLEMENTATION MODULE Boxes;
FROM Terminal IMPORT GotoXY, ClearScreen, numRows, numCols;
FROM Unicode IMPORT WriteUTF8;
FROM SYSTEM  IMPORT BYTE,FILL,ADR;
FROM STORAGE IMPORT ALLOCATE;

CONST ROWS=50; COLUMNS=128;
CONST MAP =
" $(%HI)JK&0.DdeFhi*,1EfgGjk'@A2TU/VY<\]LlmNps=^_MnoQtw+BC-WZ3X[>`aOquPry?bcRvxSz{";

TYPE Element= (Left, Up, Right, Down);
     Screen = ARRAY [0..ROWS-1],[0..COLUMNS-1] OF BYTE;

VAR screen: Screen;
    map : ARRAY [0..80] OF CHAR;

PROCEDURE Clear;
BEGIN
  FILL(ADR(screen), ROWS*COLUMNS, 0)
END Clear;

PROCEDURE SetElem(x,y: CARDINAL; element: Element; style: Style);
VAR code: CARDINAL;
BEGIN
  code := ORD(screen[y][x]);
  CASE element OF
  | Left : code := code DIV 3 * 3 + ORD(style)
  | Up   : code := code MOD 3 + code DIV 9 * 9 + 3 * ORD(style)
  | Right: code := code MOD 9 + code DIV 27 * 27 + 9 * ORD(style)
  | Down : code := code MOD 27 + 27 * ORD(style)
  END;
  screen[y][x] := code;
END SetElem;

PROCEDURE Redraw(code: CARDINAL);
BEGIN
  IF code = 0
  THEN WriteUTF8(0020H)
  ELSE
    code := ORD(map[code]);
    IF code < 30H
    THEN WriteUTF8(2550H + code)
    ELSE WriteUTF8(24D0H + code)
    END
  END
END Redraw;

PROCEDURE HorizLine(x,y,x2: CARDINAL; style: Style);
BEGIN
  IF x = x2 THEN RETURN END;
  GotoXY(x,y);
  REPEAT
    SetElem(x,y,Right,style); Redraw(ORD(screen[y][x])); INC(x); SetElem(x,y,Left,style);
  UNTIL x = x2;
  Redraw(ORD(screen[y][x]))
END HorizLine;

PROCEDURE VertLine(x,y,y2: CARDINAL; style: Style);
BEGIN
  IF y = y2 THEN RETURN END;
  GotoXY(x,y);
  REPEAT
    SetElem(x,y,Down,style); Redraw(ORD(screen[y][x])); INC(y); SetElem(x,y,Up,style);
    GotoXY(x,y);
  UNTIL y = y2;
  Redraw(ORD(screen[y][x]))
END VertLine;

PROCEDURE Box(x1,y1,x2,y2: CARDINAL; style: Style);
BEGIN
   VertLine(x1,y1,y2,style); HorizLine(x1,y1,x2,style);
  HorizLine(x1,y2,x2,style);  VertLine(x2,y1,y2,style);
END Box;

BEGIN
  map := MAP;
END Boxes.                                                         