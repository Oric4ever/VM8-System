MODULE MemSize3;
FROM STORAGE IMPORT FREEMEM;
FROM SYSTEM  IMPORT BIOS;

CONST CONOUT=3; (* BIOS function *)

PROCEDURE WriteChar(c: CHAR);
BEGIN
  BIOS(CONOUT, c)
END WriteChar;

PROCEDURE WriteLn;
BEGIN
  WriteChar(15C); WriteChar(12C)
END WriteLn;

PROCEDURE WriteString(s: ARRAY OF CHAR);
VAR i: CARDINAL;
BEGIN
  i := 0;
  WHILE (i <= HIGH(s)) AND (s[i] <> 0C) DO
    WriteChar(s[i]);
    INC(i)
  END;
END WriteString;

PROCEDURE WriteCard(val: CARDINAL);
BEGIN
  IF val >= 10 THEN WriteCard(val DIV 10) END;
  WriteChar(CHR(val MOD 10 + ORD('0')))
END WriteCard;

BEGIN
  WriteCard(FREEMEM()); WriteString(' bytes free.'); WriteLn;
  LOOP END;
END MemSize3.
