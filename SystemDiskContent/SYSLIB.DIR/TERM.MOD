IMPLEMENTATION MODULE Term;
FROM SYSTEM IMPORT BIOS,IORESULT;
CONST BACKSP=010C; TAB=011C; CR=015C; LF=012C; CANCEL=030C; ESC=033C; DEL=177C;
CONST CONSTAT = 1; CONIN = 2; CONOUT = 3;

(* $[+ remove procedure names *)
VAR lastReadChar : CHAR;
    mustReadAgain: BOOLEAN;
    initialized  : BOOLEAN;

PROCEDURE ReadChar(VAR ch: CHAR);
BEGIN
  IF mustReadAgain THEN ch := lastReadChar
  ELSE BIOS(CONIN,0); ch := CHR(IORESULT) END;
  lastReadChar  := ch;
  mustReadAgain := FALSE;
END ReadChar;

PROCEDURE BusyRead(VAR ch: CHAR);
VAR c: CHAR;
BEGIN
  IF mustReadAgain THEN ch := lastReadChar;
  ELSE
    BIOS(CONSTAT,0);
    IF IORESULT = 0
    THEN ch := 0C
    ELSE BIOS(CONIN,0); ch := CHR(IORESULT);
         IF ch <> 0C THEN lastReadChar := ch END;
    END;
  END;
  mustReadAgain := FALSE;
END BusyRead;

PROCEDURE ReadAgain;
BEGIN
  mustReadAgain := TRUE
END ReadAgain;

PROCEDURE ReadLine(VAR s: ARRAY OF CHAR);
VAR ch  : CHAR;
    length : CARDINAL;
BEGIN
  length := 0;
  REPEAT
    ReadChar(ch);
    IF ch = TAB THEN ch := ' ' END;
    IF (ch = BACKSP) OR (ch = DEL) THEN
      IF length <> 0 THEN
        WriteChar(BACKSP); WriteChar(' '); WriteChar(BACKSP);
        DEC(length)
      END;
    ELSIF ch = CANCEL THEN
      WHILE length <> 0 DO
        WriteChar(BACKSP); WriteChar(' '); WriteChar(BACKSP);
        DEC(length)
      END;
    ELSIF (ch < DEL) AND (ch <> CR) THEN
      s[length] := ch;
      IF ch < ' ' THEN Highlight; WriteChar(CHR(ORD(ch)+64)); Normal
      ELSE WriteChar(ch)
      END;
      INC(length)
    END;
  UNTIL (ch = CR) OR (length > HIGH(s));
  IF length <= HIGH(s) THEN s[length] := 0C END;
  WriteLn
END ReadLine;

PROCEDURE WriteChar(ch: CHAR);
BEGIN
  BIOS(CONOUT, ch)
END WriteChar;

PROCEDURE WriteLn;
BEGIN
  WriteChar(CR); WriteChar(LF)
END WriteLn;

PROCEDURE WriteString(s: ARRAY OF CHAR);
VAR i: CARDINAL;
BEGIN
  i := 0;
  WHILE (i <= HIGH(s)) AND (s[i] <> 0C) DO
    WriteChar(s[i]);
    INC(i);
  END;
END WriteString;

PROCEDURE WriteCard(val: CARDINAL);
BEGIN
  IF val >= 10 THEN WriteCard(val DIV 10) END;
  WriteChar(CHR(val MOD 10 + ORD('0')))
END WriteCard;

PROCEDURE SendCommand(command: CHAR);
BEGIN
  WriteChar(ESC); WriteChar('['); WriteChar(command);
END SendCommand;

PROCEDURE SendCommand1(param: CARDINAL; command: CHAR);
BEGIN
  WriteChar(ESC); WriteChar('['); WriteCard(param); WriteChar(command);
END SendCommand1;

PROCEDURE GotoXY(col,row: CARDINAL);
BEGIN
  WriteChar(ESC); WriteChar('[');
  WriteCard(row+1); WriteChar(';'); WriteCard(col+1);
  WriteChar('H');
END GotoXY;

PROCEDURE ClearScreen; BEGIN SendCommand('H'); SendCommand('J')   END ClearScreen;
PROCEDURE ClearToEOL;  BEGIN SendCommand('K')                     END ClearToEOL;
PROCEDURE InsertLine;  BEGIN SendCommand('L')                     END InsertLine;
PROCEDURE DeleteLine;  BEGIN SendCommand('M')                     END DeleteLine;
PROCEDURE Highlight;   BEGIN SendCommand1(1,'m')                  END Highlight;
PROCEDURE Normal;      BEGIN SendCommand('m')                     END Normal;
PROCEDURE ExitScreen;  BEGIN                                      END ExitScreen;
PROCEDURE CursorOff;   BEGIN WriteChar(ESC); WriteString("[?25l") END CursorOff;
PROCEDURE CursorOn;    BEGIN WriteChar(ESC); WriteString("[?25h") END CursorOn;

(* Send a Device Status Request (DSR) for Cursor Position Report (CPR) *)
(* and return the current row                                          *)
PROCEDURE RequestRow():CARDINAL;
VAR char : CHAR;
    row  : CARDINAL;
BEGIN
  SendCommand1(6,'n');
  ReadChar(char); (* should be ESC *)
  ReadChar(char); (* should be [   *)
  ReadChar(char); (* should be 0-9 *)
  row := 0;
  WHILE (char >= '0') AND (char <= '9') DO
    row := row * 10 + ORD(char) - ORD('0');
    ReadChar(char);
  END;
  REPEAT ReadChar(char) UNTIL char = 'R';
  RETURN row
END RequestRow;

PROCEDURE InitScreen; (* automatically determine the number of rows and columns *)
BEGIN
  ClearScreen; CursorOff;
  numCols := 0; WriteChar('-');
  WHILE RequestRow() = 1 DO INC(numCols); WriteChar('-') END;
  FOR numRows:=1 TO 99 DO WriteLn END;
  numRows := RequestRow();
  ClearScreen; CursorOn;
  initialized := TRUE;
END InitScreen;

BEGIN
  available := OpSet{clearEol, insertDelete, highlightNormal};
  IF NOT initialized THEN InitScreen END;
END Term.