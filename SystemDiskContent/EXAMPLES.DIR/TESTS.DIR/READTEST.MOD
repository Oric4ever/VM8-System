MODULE READTEST;
IMPORT Texts;
VAR t: Texts.TEXT;
    n: CARDINAL;
    str: ARRAY [0..80] OF CHAR;
BEGIN
  IF Texts.OpenText(t, "STRINGS.TXT") THEN
    FOR n:=1 TO 5 DO
      Texts.ReadString(t, str); WRITELN(str)
    END;
  END;
  Texts.CloseText(t);
END READTEST.                                                                                                          