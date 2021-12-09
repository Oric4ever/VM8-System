MODULE Test;
FROM Texts2 IMPORT TEXT, OpenText, Done, ReadString, ReadInt, ReadCard, ReadChar, EOT;
FROM Terminal IMPORT WriteString, WriteLn;
FROM Strings IMPORT Length;
VAR t: TEXT;
    a: ARRAY [0..255] OF CHAR;
    b: INTEGER;
    c: CARDINAL;
    ch: CHAR;
BEGIN
  IF OpenText(t, "input.txt") THEN
    WHILE NOT EOT(t) DO
      ReadString(t, a); WRITELN('[',a,"], size=",Length(a));
    END
  END
END Test.