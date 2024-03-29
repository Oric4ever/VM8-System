IMPLEMENTATION MODULE InOut;
IMPORT Texts, Files, ComLine;
TYPE FileName = ARRAY [0..20] OF CHAR;

PROCEDURE UseExtension(VAR name: FileName; ext: ARRAY OF CHAR);
VAR i,j: CARDINAL;
BEGIN
  i := 0;
  WHILE (i < 17) AND (name[i] # 0C) DO
    IF name[i] = "." THEN RETURN END;
    INC(i);
  END;
  name[i] := ".";
  j := 0;
  WHILE (j <= 2) AND (j <= HIGH(ext)) DO
    INC(i);
    name[i] := ext[j];
    INC(j);
  END;
  IF i < 20 THEN name[i+1] := 0C END;
END UseExtension;

PROCEDURE OpenInput (defext: ARRAY OF CHAR);
 (* Requests a file name at the terminal and connects input with that
    file. The file name may indicate one of the logical devices of
    CP/M. If the file name does not contain an extension itself, the
    default extension defext is appended.
 *)
VAR name: FileName;
BEGIN
  ComLine.PromptFor("Input from: ", name);
  IF name[0] # 0C THEN
    IF name[3] # ":" THEN UseExtension(name, defext) END;
    IF NOT Texts.OpenText(Texts.input, name) THEN
      Texts.WriteLn    (Texts.console);
      Texts.WriteString(Texts.console, "INPUT FILE NOT FOUND");
      Texts.WriteLn    (Texts.console);
      HALT
    END;
  END;
END OpenInput;

PROCEDURE OpenOutput (defext: ARRAY OF CHAR);
 (* Same as above but for output *)
VAR name: FileName;
BEGIN
  ComLine.PromptFor("Output to : ", name);
  IF name[0] # 0C THEN
    IF name[3] # ":" THEN UseExtension(name, defext) END;
    Texts.CreateText(Texts.output, name);
  END;
END OpenOutput;

PROCEDURE CloseInput;
 (* Closes input file, returns input to terminal. *)
BEGIN
  Texts.CloseText(Texts.input)
END CloseInput;

PROCEDURE CloseOutput;
 (* Closes output file, returns output to terminal. *)
BEGIN
  Texts.CloseText(Texts.output)
END CloseOutput;

PROCEDURE Read (VAR ch: CHAR);
 (* Done := Not past end of input *)
BEGIN
  Texts.ReadChar(Texts.input, ch);
  Done := NOT Texts.EOT(Texts.input);
  termCH := ch;
END Read;

PROCEDURE ReadString (VAR s: ARRAY OF CHAR);
 (* Reads string as in Texts. Done := the returned string is not empty *)
BEGIN
  Texts.ReadString(Texts.input, s);
  Texts.ReadAgain (Texts.input);
  Texts.ReadChar  (Texts.input, termCH);
END ReadString;

PROCEDURE ReadInt (VAR x: INTEGER);
 (* Reads integer as in Texts. Done := integer was read *)
BEGIN
  Texts.ReadInt  (Texts.input, x);
  Done := Texts.Done(Texts.input);
  Texts.ReadAgain(Texts.input);
  Texts.ReadChar (Texts.input, termCH);
END ReadInt;

PROCEDURE ReadCard (VAR x: CARDINAL);
 (* Done := cardinal was read *)
BEGIN
  Texts.ReadCard (Texts.input, x);
  Done := Texts.Done(Texts.input);
  Texts.ReadAgain(Texts.input);
  Texts.ReadChar (Texts.input, termCH);
END ReadCard;

PROCEDURE Write(ch: CHAR);
BEGIN
  Texts.WriteChar(Texts.output, ch)
END Write;

PROCEDURE WriteLn;
BEGIN
  Texts.WriteLn(Texts.output)
END WriteLn;

PROCEDURE WriteString(s: ARRAY OF CHAR);
BEGIN
  Texts.WriteString(Texts.output, s)
END WriteString;

PROCEDURE WriteInt(x: INTEGER; n: CARDINAL);
BEGIN
  Texts.WriteInt(Texts.output, x, n)
END WriteInt;

PROCEDURE WriteCard(x,n: CARDINAL);
BEGIN
  Texts.WriteCard(Texts.output, x, n)
END WriteCard;

PROCEDURE WriteHex(x,n: CARDINAL);
VAR i, digit: CARDINAL;
    str: ARRAY [0..5] OF CHAR;
BEGIN
  i := 0;
  REPEAT
    digit := x MOD 16;
    x := x DIV 16;
    IF digit > 9 THEN INC(digit, 7) END;
    str[i] := CHR(digit + 30H);
    INC(i);
  UNTIL x = 0;
  WHILE n > i DO Texts.WriteChar(Texts.output, " "); DEC(n) END;
  REPEAT DEC(i); Texts.WriteChar(Texts.output, str[i]) UNTIL i = 0;
END WriteHex;

PROCEDURE WriteOct(x,n: CARDINAL);
VAR i: CARDINAL;
    str: ARRAY [0..5] OF CHAR;
BEGIN
  i := 0;
  REPEAT
    str[i] := CHR(x MOD 8 + 30H);
    x := x DIV 8;
    INC(i)
  UNTIL x = 0;
  WHILE n > i DO Texts.WriteChar(Texts.output, " "); DEC(n) END;
  REPEAT DEC(i); Texts.WriteChar(Texts.output, str[i]) UNTIL i = 0;
END WriteOct;

PROCEDURE ReadReal (VAR x: REAL);
BEGIN
  Texts.ReadReal(Texts.input, x);
  Done := Texts.Done(Texts.input);
  Texts.ReadAgain(Texts.input);
  Texts.ReadChar (Texts.input, termCH);
END ReadReal;

PROCEDURE WriteReal(x: REAL; n,digits: CARDINAL);
BEGIN
  Texts.WriteReal(Texts.output, x, n, digits)
END WriteReal;

BEGIN
  Done := TRUE
END InOut.
        
