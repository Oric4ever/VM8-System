(*
    Decompilation of original Texts module, plus some changes:

    - WriteChar written in Modula-2 instead of assembler code
    - ADR used instead of Z80-coded procedure, now that compiler has been
      modified to accept ADR of scalar variables
    - number reading modified to stop of first non-numeric char

    TODO: decide what to do with old CP/M device names (CON:, PUN:, etc.)
*)
IMPLEMENTATION MODULE Texts;
FROM SYSTEM IMPORT BDOS, IORESULT, CODE, BYTE, ADDRESS, ADR;
IMPORT Files;
IMPORT Convert;
IMPORT Terminal;

CONST CR = 15C; LF = 12C; CTRLC = 3C; XOFF = 23C; EOF = 32C;

CONST AREAD  = 3; (* Auxiliary input *)
      AWRITE = 4; (* Auxiliary output *)
      LWRITE = 5; (* LinePrinter output *)

TYPE DRIVER = (FILEINPUT, FILEOUTPUT, TERMINAL, CUSTOM, NONE);
     COLUMN = [0..255];

VAR convertDone : ARRAY [0..17] OF BOOLEAN;
    currentColumn : ARRAY [0..17] OF COLUMN;
    lastReadChar : ARRAY [0..17] OF CHAR;
    mustReadAgain : ARRAY [0..17] OF BOOLEAN;
    driverType: ARRAY [0..17] OF DRIVER;
    textFile: ARRAY [0..16] OF FILE;
    drivers : ARRAY [0..16] OF TextDriver;
    termBuffer: ARRAY [0..127] OF CHAR;
    global14: CARDINAL;

(* $[+ remove procedure names *)

(* proc 30 *)
PROCEDURE AuxiliaryWrite(t: TEXT; VAR ch: CHAR);
BEGIN
(*
  IF ch = EOL THEN BDOS(AWRITE, CR); ch := LF; END;
  BDOS(AWRITE, ch)
*)
END AuxiliaryWrite;

(* proc 31 *)
PROCEDURE LinePrinterWrite(t: TEXT; VAR ch: CHAR);
BEGIN
(*
  IF ch = EOL THEN BDOS(LWRITE, CR); ch := LF; END;
  BDOS(LWRITE, ch)
*)
END LinePrinterWrite;

(* proc 32 *)
PROCEDURE TerminalRead(t: TEXT; VAR char: CHAR);
VAR ch: CHAR;
BEGIN
  IF (global14 = 0) OR (termBuffer[global14-1] = 0C) THEN
    IF haltOnControlC THEN
      Terminal.ReadChar(ch);
      IF ch = CTRLC THEN HALT END;
      Terminal.ReadAgain;
    END;
    Terminal.ReadLine(termBuffer);
    termBuffer[127] := 0C;
    global14 := 0;
  END;
  char := termBuffer[global14];
  INC(global14);
  IF char = 0C THEN char := EOL END;
END TerminalRead;

(* proc 33 *)
PROCEDURE AuxiliaryRead(t: TEXT; VAR char: CHAR);
BEGIN
(*
  BDOS(AREAD, 0);
  char := CHR(IORESULT);
  IF char = CR THEN char := EOL END;
*)
END AuxiliaryRead;

(* proc 34 *)
PROCEDURE ErrorDriver(t: TEXT; VAR param1: CHAR);
BEGIN
  RAISE TextNotOpen;
END ErrorDriver;

(* "proc" 35 *)
CONST CONSOLE = "CON:";

MODULE Internal[1];
IMPORT TEXT, FILE, DRIVER, Files, TextDriver, EOF, EOL, input, output, console,
        TooManyTexts, haltOnControlC, ADDRESS, CODE, ADR,
        currentColumn, lastReadChar, mustReadAgain, driverType, textFile, drivers, global14,
        AuxiliaryWrite, LinePrinterWrite, TerminalRead, AuxiliaryRead, ErrorDriver, CONSOLE, WriteChar;
EXPORT OpenText, CreateText, CloseText, ConnectDriver, Init;

(* proc 36 : return an available Text,
except that findAvailableText(input) always return 1,
and findAvailableText(output) always return 2,
because this means we are trying to redirect the standard input/output.
*)
PROCEDURE findAvailableText(VAR t: TEXT);
VAR text: CARDINAL;
BEGIN
  (* compiler has now been modified to accept ADR of scalar variables *)
  IF ADR(t) = ADR(input)  THEN t := 1; RETURN END;
  IF ADR(t) = ADR(output) THEN t := 2; RETURN END;
  text := 3;
  REPEAT
    IF driverType[text] = NONE THEN t := text; RETURN END;
    INC(text);
  UNTIL text > 16;
  RAISE TooManyTexts
END findAvailableText;

(* proc 38 *)
PROCEDURE SetText(t: TEXT; type: DRIVER; driver: TextDriver);
BEGIN
  currentColumn[t] := 0;
  mustReadAgain[t] := FALSE;
  lastReadChar [t] := EOL;
  driverType   [t] := type;
  drivers      [t] := driver;
END SetText;

(* $[- retain procedure names for debugging purposes *)

PROCEDURE OpenText   (VAR t: TEXT; name: ARRAY OF CHAR): BOOLEAN;
VAR i: CARDINAL;
BEGIN
  i := 0; REPEAT name[i] := CAP(name[i]); INC(i) UNTIL i > HIGH(name);
  findAvailableText(t);
  IF t = 2 THEN RETURN FALSE END; (* cannot open standard output for reading *)
  IF name = CONSOLE THEN
    SetText(t, CUSTOM, TerminalRead);
    global14 := 0
  ELSIF name = "RDR:" THEN
    SetText(t, CUSTOM, AuxiliaryRead);
  ELSIF Files.Open(textFile[t], name) THEN
    Files.NoTrailer(textFile[t]);
    SetText(t, FILEINPUT, ErrorDriver)
  ELSE
    RETURN FALSE
  END;
  lastReadChar[t] := 0C;
  RETURN TRUE
END OpenText;

PROCEDURE CreateText (VAR t: TEXT; name: ARRAY OF CHAR);
(* TODO: plan what to do with old CP/M device names *)
VAR i: CARDINAL;
BEGIN
  i := 0; REPEAT name[i] := CAP(name[i]); INC(i) UNTIL i > HIGH(name);
  findAvailableText(t);
  IF t <> 1 THEN    (*  CreateText cannot be invoked on standard input *)
    IF    name = CONSOLE THEN SetText(t, TERMINAL, ErrorDriver)
    ELSIF name = "PUN:"  THEN SetText(t, CUSTOM, AuxiliaryWrite)
    ELSIF name = "LST:"  THEN SetText(t, CUSTOM, LinePrinterWrite)
    ELSE
      Files.Create(textFile[t], name);
      Files.NoTrailer(textFile[t]);
      SetText(t, FILEOUTPUT, ErrorDriver);
    END;
  END;
END CreateText;

PROCEDURE CloseText  (VAR t: TEXT);
VAR success : BOOLEAN;
BEGIN
  IF t-1 <= 15 THEN
    IF driverType[t] <= FILEOUTPUT THEN (* FILEINPUT or FILEOUTPUT *)
      IF driverType[t] = FILEOUTPUT THEN WriteChar(t, EOF) END;
      Files.Close(textFile[t])
    END;
    SetText(t, NONE, ErrorDriver);
    IF    t = 1 THEN success := OpenText(t, CONSOLE) (* reopen standard input *)
    ELSIF t = 2 THEN CreateText(t, CONSOLE)          (* reopen standard output *)
    ELSE  t := TEXT(0)
    END;
  END;
END CloseText;

PROCEDURE ConnectDriver(VAR t: TEXT; p: TextDriver);
BEGIN
  findAvailableText(t);
  SetText(t, CUSTOM, p);
END ConnectDriver;

(* $[+ remove procedure names *)

PROCEDURE Init;
VAR t: CARDINAL;
    success: BOOLEAN;
BEGIN
  t := 0;
  REPEAT
    SetText(t, NONE, ErrorDriver);
    textFile[t] := FILE(0);
    INC(t)
  UNTIL t > 16;
  success := OpenText(input, CONSOLE);
  CreateText(output, CONSOLE);
  CreateText(console, CONSOLE);
  haltOnControlC := TRUE;
END Init;

END Internal;

PROCEDURE Done       (t: TEXT): BOOLEAN;
BEGIN
  RETURN convertDone[t]
END Done;

PROCEDURE EOLN       (t: TEXT): BOOLEAN;
BEGIN
  RETURN (ORD(lastReadChar[t]) - ORD(EOF)) IN {0,4}
END EOLN;

PROCEDURE EOT        (t: TEXT): BOOLEAN;
BEGIN
  RETURN lastReadChar[t] = EOF
END EOT;

PROCEDURE Col        (t: TEXT): CARDINAL;
BEGIN
  RETURN currentColumn[t]
END Col;

PROCEDURE TextFile   (t: TEXT): FILE;
BEGIN
  RETURN textFile[t]
END TextFile;

(* $[- retain procedure names for debugging purposes *)

PROCEDURE ReadChar   (t: TEXT; VAR ch: CHAR);
VAR driver: TextDriver;
BEGIN
  IF t-1 > 15 THEN RAISE TextNotOpen END;
  IF mustReadAgain[t] THEN
    ch := lastReadChar[t];
    mustReadAgain[t] := FALSE
  ELSE
    IF driverType[t] = FILEINPUT THEN
      Files.ReadByte(textFile[t], ch);
      IF ch = CR THEN Files.ReadByte(textFile[t], ch); ch := EOL END;
    ELSE
      driver := drivers[t];
      driver(t, ch);
    END;
  END;
  lastReadChar[t] := ch;
END ReadChar;

PROCEDURE SkipWhiteChars(t: TEXT);
VAR ch: CHAR;
BEGIN
  REPEAT ReadChar(t, ch) UNTIL (ch > ' ') OR (ch = EOF);
  ReadAgain(t);
END SkipWhiteChars;

PROCEDURE ReadString (t: TEXT; VAR s : ARRAY OF CHAR);
VAR i : CARDINAL;
    ch: CHAR;
BEGIN
  s := "";
  i := 0;
  SkipWhiteChars(t);
  ReadChar(t, ch);
  WHILE ch > ' ' DO
    IF i <= HIGH(s) THEN s[i] := ch; INC(i) END;
    ReadChar(t, ch);
  END
END ReadString;

PROCEDURE ReadLine   (t: TEXT; VAR s: ARRAY OF CHAR);
VAR i : CARDINAL;
    ch: CHAR;
BEGIN
  s := "";
  i := 0;
  ReadChar(t, ch);
  WHILE NOT ((ORD(ch) - ORD(EOF)) IN {0,4}) DO
    IF i <= HIGH(s) THEN s[i] := ch; INC(i) END;
    ReadChar(t, ch);
  END;
END ReadLine;

PROCEDURE ReadNum(t: TEXT; signed: BOOLEAN; VAR buf: ARRAY OF CHAR);
VAR ch: CHAR;
    n : CARDINAL;
BEGIN
  SkipWhiteChars(t);
  IF signed THEN
    ReadChar(t, ch);
    IF (ORD(ch) - ORD('+')) IN {0,2}
    THEN buf[0] := ch; n := 1
    ELSE ReadAgain(t); n := 0
    END
  END;
  REPEAT
    ReadChar(t, ch); buf[n] := ch; INC(n)
  UNTIL (n > HIGH(buf)) OR (ORD(ch) - ORD('0') > 9);
  ReadAgain(t);
  buf[n-1] := 0C;
END ReadNum;

PROCEDURE ReadInt    (t: TEXT; VAR i : INTEGER);
VAR buf: ARRAY [0..20] OF CHAR;
BEGIN
  ReadNum(t, TRUE, buf);
  i := 0;
  convertDone[t] := Convert.StrToInt(buf, i);
END ReadInt;

PROCEDURE ReadCard   (t: TEXT; VAR c : CARDINAL);
VAR buf: ARRAY [0..20] OF CHAR;
BEGIN
  ReadNum(t, FALSE, buf);
  c := 0;
  convertDone[t] := Convert.StrToCard(buf, c);
END ReadCard;

PROCEDURE ReadLong   (t: TEXT; VAR l : LONGINT);
VAR buf: ARRAY [0..20] OF CHAR;
BEGIN
  ReadNum(t, TRUE, buf);
  l := LONG(0);
  convertDone[t] := Convert.StrToLong(buf, l);
END ReadLong;

PROCEDURE ReadReal   (t: TEXT; VAR r : REAL);
VAR buf: ARRAY [0..20] OF CHAR;
BEGIN
  r := 0.0;
  ReadString(t, buf);
  convertDone[t] := Convert.StrToReal(buf, r);
END ReadReal;

PROCEDURE ReadLn     (t: TEXT);
VAR ch: CHAR;
BEGIN
  WHILE NOT EOLN(t) DO ReadChar(t, ch) END;
  lastReadChar[t] := 0C
END ReadLn;

(* $[+ remove procedure names *)
PROCEDURE ReadAgain  (t: TEXT);
BEGIN
  IF t-1 <= 15 THEN mustReadAgain[t] := TRUE END;
END ReadAgain;

(* $[- retain procedure names for debugging purposes *)

PROCEDURE WriteChar  (t: TEXT; ch: CHAR); (* recoded, was in Z80 *)
VAR f: FILE;
    endOfLine: BOOLEAN;
    type : DRIVER;
    column : CARDINAL;
    driver : TextDriver;
BEGIN
  IF t-1 >= 16 THEN RAISE TextNotOpen END;
  endOfLine :=  ch = EOL ;
  IF endOfLine THEN column := 0 ELSE column := currentColumn[t] + 1 END;
  currentColumn[t] := column;
  type := driverType[t];
  IF type = FILEOUTPUT THEN
    f := textFile[t];
    IF endOfLine THEN Files.WriteWord(f,0A0DH) ELSE Files.WriteByte(f,ch) END;
  ELSIF type = TERMINAL THEN
    IF endOfLine THEN Terminal.WriteLn ELSE Terminal.WriteChar(ch) END;
  ELSE
      driver := drivers[t];
      driver(t, ch)
  END;
END WriteChar;

PROCEDURE WriteString(t: TEXT; s : ARRAY OF CHAR);
VAR i: CARDINAL;
BEGIN
  i := 0;
  WHILE (i <= HIGH(s)) AND (s[i] <> 0C) DO
    WriteChar(t, s[i]);
    INC(i)
  END;
END WriteString;

(* $[+ remove procedure names *)
(* proc 39 *)
PROCEDURE proc39(t: TEXT; VAR str: ARRAY OF CHAR; n: CARDINAL);
BEGIN
  WHILE n > HIGH(str)+1 DO WriteChar(t, ' '); DEC(n) END;
  n := HIGH(str) + 1 - n;
  WHILE (n <> 0) AND (str[n-1] <> ' ') DO DEC(n) END;
  WHILE n <= HIGH(str) DO WriteChar(t,str[n]); INC(n) END;
END proc39;

(* $[- retain procedure names for debugging purposes *)

PROCEDURE WriteInt   (t: TEXT; i : INTEGER; n: CARDINAL);
VAR buf: ARRAY [0..5] OF CHAR;
BEGIN
  Convert.IntToStr(i,buf);
  proc39(t,buf,n);
END WriteInt;

PROCEDURE WriteCard  (t: TEXT; c,n:CARDINAL);
VAR buf: ARRAY [0..4] OF CHAR;
    i : CARDINAL;  
BEGIN
  i := 0;
  REPEAT
    buf[i] := CHR(c MOD 10 + ORD('0'));
    c := c DIV 10;
    INC(i)
  UNTIL c = 0;
  WHILE n > i DO WriteChar(t, ' '); DEC(n) END;
  REPEAT DEC(i); WriteChar(t, buf[i]) UNTIL i = 0;
END WriteCard;

PROCEDURE WriteLong  (t: TEXT; l : LONGINT; n: CARDINAL);
VAR buf: ARRAY [0..10] OF CHAR;
BEGIN
  Convert.LongToStr(l,buf);
  proc39(t,buf,n);
END WriteLong;

PROCEDURE WriteReal  (t: TEXT; r : REAL; n: CARDINAL; digits: INTEGER);
VAR buf: ARRAY [0..50] OF CHAR;
BEGIN
  Convert.RealToStr(r,buf,digits);
  proc39(t,buf,n);
END WriteReal;

PROCEDURE WriteLn    (t: TEXT);
VAR ch: CHAR;
BEGIN
  IF haltOnControlC AND (driverType[t] = TERMINAL) THEN
    Terminal.BusyRead(ch);
    IF ch <> 0C THEN
      IF ch = XOFF THEN
        REPEAT
          Terminal.ReadChar(ch);
          IF ch = CTRLC THEN HALT END;
        UNTIL ch = XOFF;
      ELSIF ch = CTRLC THEN HALT
      ELSE Terminal.ReadAgain
      END;
    END;
  END;
  WriteChar(t, EOL);
END WriteLn;

PROCEDURE SetCol     (t: TEXT; column: CARDINAL);
BEGIN 
  WHILE currentColumn[t] < column DO WriteChar(t,' ') END;
END SetCol;

(* $[+ remove procedure names *)
BEGIN
  Init
END Texts.
