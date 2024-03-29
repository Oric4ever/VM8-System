MODULE Connect4;
CONST COLUMNS = 4; ROWS = 4;
      WIN = +1; DRAW = 0; LOSE = -1;

TYPE Color  = (EMPTY, RED, YELLOW, OUTSIDE);
     Column = [0..COLUMNS+1];
     Row    = [0..7]; (* thus a row is 16 bytes *)

VAR board : ARRAY Column,Row OF Color;
    height: ARRAY Column OF CARDINAL;

PROCEDURE InitBoard;
VAR i : Column;
    j : Row;
BEGIN
  FOR i:=0 TO COLUMNS+1 DO
    FOR j:=0 TO ROWS+1 DO
      IF (i=0) OR (i>COLUMNS) OR (j=0) OR (j>ROWS)
      THEN board[i][j] := OUTSIDE
      ELSE board[i][j] := EMPTY
      END;
    END;
  END;
END InitBoard;

PROCEDURE Play(column: Column; color: Color);
VAR row: Row;
BEGIN
  INC(height[column]);
  board[column][height[column]] := color;
END Play;

PROCEDURE BackPlay(column: Column);
BEGIN
  board[column][height[column]] := EMPTY;
  DEC(height[column])
END BackPlay;

PROCEDURE MakesConnect4(column: Column; row: Row; color: Color): BOOLEAN;
VAR i: Column;
    j: Row;
    count : CARDINAL;
BEGIN
  count := 1; (* count below *)
  i := column;
  j := row-1; WHILE board[i][j]=color DO INC(count); DEC(j) END;
  IF count >= 4 THEN RETURN TRUE END;

  count := 1; (* count horizontally *)
  j := row;
  i := column-1; WHILE board[i][j]=color DO INC(count); DEC(i) END;
  i := column+1; WHILE board[i][j]=color DO INC(count); INC(i) END;
  IF count >= 4 THEN RETURN TRUE END;
  
  count := 1; (* count first diagonal *)
  i := column-1; j := row-1; WHILE board[i][j]=color DO INC(count); DEC(i); DEC(j) END;
  i := column+1; j := row+1; WHILE board[i][j]=color DO INC(count); INC(i); INC(j) END;
  IF count >= 4 THEN RETURN TRUE END;
  
  count := 1; (* count second diagonal *)
  i := column-1; j := row+1; WHILE board[i][j]=color DO INC(count); DEC(i); INC(j) END;
  i := column+1; j := row-1; WHILE board[i][j]=color DO INC(count); INC(i); DEC(j) END;
  IF count >= 4 THEN RETURN TRUE END;

  RETURN FALSE
END MakesConnect4;

PROCEDURE HasWinningMove(color: Color): BOOLEAN;
VAR column: Column;
    row : Row;
BEGIN
  FOR column := 1 TO COLUMNS DO
    row := height[column];
    IF (row < ROWS) AND MakesConnect4(column,row,color) THEN RETURN TRUE END;
  END;
  RETURN FALSE
END HasWinningMove;

PROCEDURE Minimax(color: Color; depth: CARDINAL): INTEGER; FORWARD;

VAR nodes: CARDINAL;
PROCEDURE Maximin(color: Color; depth: CARDINAL): INTEGER;
VAR column : Column;
    eval, best : INTEGER;
BEGIN
INC(nodes);
  IF HasWinningMove(color) THEN RETURN LOSE END;
  IF depth = ROWS*COLUMNS-1 THEN RETURN DRAW END;
  best := MAX(INTEGER);
  FOR column := 1 TO COLUMNS DO
    IF height[column] < ROWS THEN
      Play(column, color);
      eval := Minimax(Color(3-ORD(color)), depth+1);
      BackPlay(column);
      IF eval<best THEN best := eval END;
    END;
  END;
  RETURN best
END Maximin;

PROCEDURE Minimax(color: Color; depth: CARDINAL): INTEGER;
VAR column : Column;
    eval, best : INTEGER;
BEGIN
INC(nodes);
  IF HasWinningMove(color) THEN RETURN WIN END;
  IF depth = ROWS*COLUMNS-1 THEN RETURN DRAW END;
  best := MIN(INTEGER);
  FOR column := 1 TO COLUMNS DO
    IF height[column] < ROWS THEN
      Play(column, color);
      eval := Maximin(Color(3-ORD(color)), depth+1);
      BackPlay(column);
      IF eval>best THEN best := eval END;
    END;
  END;
  RETURN best
END Minimax;

BEGIN
  InitBoard;
  Play(1, RED); Play(1, YELLOW);
  WRITELN('Result: ', Minimax(RED,2));
  WRITELN(nodes,' nodes');
END Connect4.                                                                                    