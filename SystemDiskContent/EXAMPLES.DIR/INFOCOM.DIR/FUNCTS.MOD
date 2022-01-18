IMPLEMENTATION MODULE Functs;
FROM Support IMPORT Store, RetValue;

PROCEDURE Add(a,b : CARDINAL);
BEGIN
  Store(a + b)
END Add;

PROCEDURE Sub(a,b : CARDINAL);
BEGIN
  Store(a - b)
END Sub;

PROCEDURE Mul(a,b : CARDINAL);
BEGIN
  Store(a * b)
END Mul;

PROCEDURE Div(a,b : CARDINAL);
BEGIN
  Store(a DIV b)
END Div;

PROCEDURE Mod(a,b : CARDINAL);
BEGIN
  Store(a MOD b)
END Mod;

VAR random1, random2: CARDINAL;

PROCEDURE PickRandom(num : CARDINAL);
VAR temp: CARDINAL;
    
BEGIN
  temp    := random1 * 2;
  random1 := random2;
  IF random2 >= 8000H THEN INC(temp) END;
  random2 := CARDINAL( BITSET(random2) / BITSET(temp) );
  IF num = 0 THEN Store(0) ELSE Store( random2 MOD 32768 MOD num + 1 ) END;
END PickRandom;

PROCEDURE JumpLess(a,b : INTEGER);
BEGIN
  RetValue( a < b )
END JumpLess;

PROCEDURE JumpGreater(a,b : INTEGER);
BEGIN
  RetValue( a > b )
END JumpGreater;

PROCEDURE JumpEqual(a,b : CARDINAL);
BEGIN
  RetValue( a = b )
END JumpEqual;

PROCEDURE JumpMember(a: ARRAY OF WORD);
VAR i, e: CARDINAL;
BEGIN
  e := CARDINAL(a[0]);
  FOR i:=1 TO HIGH(a) DO
    IF e = CARDINAL(a[i]) THEN RetValue(TRUE); RETURN END;
  END;
  RetValue(FALSE)
END JumpEqual;

PROCEDURE Test     (a,b : BITSET);
BEGIN
  RetValue( b - a = {} )   (* TODO: check *)
END Test;

PROCEDURE Or      (a,b : BITSET);
BEGIN
  Store( a + b )
END Or;

PROCEDURE And     (a,b : BITSET);
BEGIN
  Store( a * b )
END And;

PROCEDURE Not     (a   : BITSET);
BEGIN
  Store( {0..15} - a )
END Not;

END Functs.
