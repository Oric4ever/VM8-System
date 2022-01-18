MODULE ShowKeys;
VAR c: CHAR;
BEGIN
  REPEAT
    READ(c); WRITELN(ORD(c))
  UNTIL c = 03C
END ShowKeys.