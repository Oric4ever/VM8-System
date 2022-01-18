IMPLEMENTATION MODULE Out;
FROM SYSTEM IMPORT BIOS;
IMPORT Convert;

CONST CONOUT = 3; CR = 015C; LF = 012C;

PROCEDURE Char  (ch: CHAR);
BEGIN BIOS(CONOUT, ch)
END Char;

PROCEDURE String(s: ARRAY OF CHAR);
VAR i: CARDINAL;
BEGIN
  i := 0;
  WHILE (i <= HIGH(s)) & (s[i] # 0C) DO
    Char(s[i]);
    INC(i)
  END
END String;

PROCEDURE Int   (i, n: INTEGER);
VAR s: ARRAY [0..5] OF CHAR;
BEGIN
  Convert.IntToStr(i, s);
  WHILE n > 6 DO Char(' ');    DEC(n) END;
  WHILE n > 0 DO Char(s[6-n]); DEC(n) END;
END Int;

PROCEDURE Card   (i, n: INTEGER);
VAR s: ARRAY [0..5] OF CHAR;
BEGIN
  Convert.CardToStr(i, s);
  WHILE n > 6 DO Char(' ');    DEC(n) END;
  WHILE n > 0 DO Char(s[6-n]); DEC(n) END;
END Card;

PROCEDURE Long  (l: LONGINT; n: INTEGER);
VAR s: ARRAY [0..9] OF CHAR;
BEGIN
  Convert.LongToStr(l, s);
  WHILE n > 10 DO Char(' ');     DEC(n) END;
  WHILE n > 0  DO Char(s[10-n]); DEC(n) END;
END Long;

PROCEDURE Hex   (i: INTEGER);
  PROCEDURE HexByte(i: CARDINAL);
    PROCEDURE HexDigit(i: CARDINAL);
    BEGIN
      IF i < 10
      THEN Char(CHR(i + ORD('0')))
      ELSE Char(CHR(i + ORD('A') - 10))
      END
    END HexDigit;
  BEGIN
    HexDigit(i DIV 16);
    HexDigit(i MOD 16);
  END HexByte;
BEGIN
  Char(' ');
  HexByte( CARDINAL(i) DIV 256 );
  HexByte( CARDINAL(i) MOD 256 );
END Hex;

PROCEDURE Real  (x: REAL; n: INTEGER);
VAR s: ARRAY [0..11] OF CHAR;
BEGIN
  Convert.RealToStr(x, s, n);
  FOR n:=0 TO 11 DO Char(s[n]) END;
END Real;

PROCEDURE Ln;
BEGIN Char(CR); Char(LF)
END Ln;

END Out.