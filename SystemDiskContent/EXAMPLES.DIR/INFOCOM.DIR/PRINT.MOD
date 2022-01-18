IMPLEMENTATION MODULE Print;
IMPORT Terminal, GameFile;

CONST BLOCKSIZE = 512;

TYPE Code = [0..31];
     Byte = [0..255];
     PrintMode = (A0, A1, A2, COMMONWORD, ASCIIHIGH, ASCIILOW);


VAR columnCount : CARDINAL;
    printMode, singleMode: PrintMode;
    table    : ARRAY [A0..A2],[6..31] OF CHAR;
    wordBank, ascii : CARDINAL;

PROCEDURE NewLine;
BEGIN
  Terminal.WriteLn;
  columnCount := 0;
END NewLine;

PROCEDURE PrintChar (char: CHAR);
BEGIN
  (* very crude word-wrapping for now *)
  IF (char = ' ') AND (columnCount > 70) THEN NewLine END;
  Terminal.WriteChar(char);
  INC(columnCount);
END PrintChar;

PROCEDURE Letter(ch: CARDINAL);
BEGIN
  IF    ch = 0 THEN PrintChar(' '); singleMode := printMode
  ELSIF ch < 4 THEN singleMode := COMMONWORD; wordBank := ch
  ELSIF ch < 6 THEN (* Switch printing modes *)
    IF singleMode = A0 THEN singleMode := PrintMode(ch - 3)
    ELSE
      IF singleMode = PrintMode(ch - 3) THEN singleMode := A0 END;
      printMode := singleMode;
    END;
  ELSIF (ch = 6) AND (singleMode = A2) THEN singleMode := ASCIIHIGH
  ELSIF (ch = 7) AND (singleMode = A2) THEN (* carriage return *)
    NewLine;
    singleMode := printMode;
  ELSE
    PrintChar(table[singleMode][ch]);
    singleMode := printMode;
  END;
END Letter;

PROCEDURE Decode(word: CARDINAL);
VAR chars: ARRAY [0..2] OF Code;
    i, page, offset : CARDINAL;
    addr : POINTER TO ARRAY [0..1] OF Byte;
BEGIN
  FOR i := 0 TO 2 DO
    chars[i] := word MOD 32;
    word     := word DIV 32
  END;
  FOR i := 2 TO 0 BY -1 DO
    IF    singleMode <= A2      THEN Letter(chars[i])
    ELSIF singleMode = COMMONWORD  THEN (* Print a special word *)
      addr   := GameFile.commonWordPtr + (wordBank-1) * 64 + chars[i] * 2;
      page   := addr^[0];
      offset := addr^[1];
      PrintZ(page, offset);
      singleMode := printMode;
    ELSIF singleMode = ASCIIHIGH   THEN (* ASCII character, upper 3 bits *)
      ascii  := (chars[i] MOD 4) * 32; (* keep only 2 bits actually *)
      singleMode := ASCIILOW;
    ELSIF singleMode = ASCIILOW    THEN (* ASCII character, lower 5 bits *)
      INC(ascii, chars[i]);
      PrintChar(CHR(ascii));
      singleMode := printMode;
    END;
  END;
END Decode;

PROCEDURE PrintZ(VAR page, offset: CARDINAL);
VAR word: CARDINAL;
BEGIN
  REPEAT
    word := GameFile.GetWord(page, offset);
    Decode(word);
  UNTIL word >= 8000H;
END PrintZ;

PROCEDURE PrintAddr (addr : CARDINAL);
VAR page, offset: CARDINAL;
BEGIN
  page   := addr DIV BLOCKSIZE;
  offset := addr MOD BLOCKSIZE;
  PrintZ(page, offset);
END PrintAddr;

PROCEDURE PrintPAddr(paddr : CARDINAL);
VAR page, offset: CARDINAL;
BEGIN
  page   := paddr DIV 256;
  offset := paddr MOD 256 * 2;
  PrintZ(page, offset);
END PrintPAddr;

PROCEDURE PrintCard (value: CARDINAL);
BEGIN
  IF value > 9 THEN PrintCard(value DIV 10) END;
  PrintChar(CHR(value MOD 10 + ORD('0')));
END PrintCard;

PROCEDURE PrintNum  (value: INTEGER);
BEGIN
  IF value < 0 THEN PrintChar('-'); value := ABS(value) END;
  PrintCard(CARDINAL(value))
END PrintNum;

END Print.