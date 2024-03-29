IMPLEMENTATION MODULE Unicode;

PROCEDURE WriteUTF8(code: CARDINAL);
BEGIN
  IF    code < 0080H THEN WRITE(CHR(code))
  ELSIF code < 0800H THEN WRITE(CHR(0C0H + code DIV 64), CHR(80H + code MOD 64))
  ELSE
    WRITE(CHR(0E0H + code DIV 4096));
    code := code MOD 4096;
    WRITE(CHR(080H + code DIV 64), CHR(080H + code MOD 64));
  END
END WriteUTF8;

PROCEDURE WritePlan1(code: CARDINAL);
BEGIN
  WRITE(CHR(0F0H), CHR(090H + code DIV 4096));
  code := code MOD 4096;
  WRITE(CHR(080H + code DIV 64), CHR(080H + code MOD 64));
END WritePlan1;

END Unicode.                                                             