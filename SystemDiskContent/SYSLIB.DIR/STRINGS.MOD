IMPLEMENTATION MODULE Strings;
FROM SYSTEM IMPORT ADR, CODE, ADDRESS, MOVE, FILL;
FROM STORAGE IMPORT ALLOCATE;

(* $[+ remove procedure names *)

PROCEDURE SearchChar(str: ADDRESS; size: CARDINAL; char: CHAR): ADDRESS;
(* was in Z80 code:
CODE("CharIndx");
*)
VAR ptr: POINTER TO ARRAY [0..0FFFFH] OF CHAR;
BEGIN
  ptr := str;
  WHILE size # 0 DO
    IF ptr^[0] = char THEN RETURN ptr END;
    ptr := ADDRESS(ptr) + 1;
    DEC(size)
  END;
  RETURN NIL
END SearchChar;

PROCEDURE Length (VAR str: ARRAY OF CHAR): CARDINAL;
VAR addr: ADDRESS;
BEGIN
  addr := SearchChar(ADR(str), HIGH(str)+1, 0C);
  IF addr = NIL THEN RETURN HIGH(str)+1 END;
  RETURN addr - ADR(str)
END Length;

PROCEDURE Pos    (substr,str: ARRAY OF CHAR): CARDINAL;
(* TODO: find a way to generate D3 opcode instead of 40 12 *)
VAR limit : ADDRESS;
    ptr : POINTER TO ARRAY [0..0FFFFH] OF CHAR;
    subStrLen, strLen : CARDINAL;
    i : CARDINAL;
BEGIN
  subStrLen := Length(substr);
  strLen := Length(str);
  IF (subStrLen <> 0) AND (subStrLen <= strLen) THEN
    ptr := ADR(str) - 1;
    limit := ADR(str) + (strLen - subStrLen);
    LOOP
      ptr := SearchChar(ADDRESS(ptr)+1, limit-ADDRESS(ptr), substr[0]);
      IF ptr = NIL THEN EXIT END;
      i := 0;
      WHILE ptr^[i] = substr[i] DO
        INC(i);
        IF i = subStrLen THEN RETURN ADDRESS(ptr) - ADR(str) END;
      END;
      IF ptr = limit THEN EXIT END;
    END;
  END;
  RETURN HIGH(str) + 1
END Pos;

(* $[- store procedure names *)

PROCEDURE Insert (substr : ARRAY OF CHAR; VAR str: ARRAY OF CHAR;
                     inx : CARDINAL);
(* TODO: find a way to generate D3 opcode instead of 40 12 *)
VAR sublen, strlen: CARDINAL;
BEGIN
  strlen := Length(str);
  sublen := Length(substr);
  IF inx <= strlen THEN
    IF sublen + strlen > HIGH(str)+1 THEN RAISE StringError END;
    MOVE(ADR(str)+inx, ADR(str)+(inx+sublen), HIGH(str)+1-(inx+sublen));
    MOVE(ADR(substr), ADR(str)+inx, sublen);
  END; (* 00D8 *)
END Insert;

(* $[+ remove procedure names *)

PROCEDURE Delete (VAR str: ARRAY OF CHAR; inx,len: CARDINAL);
VAR strlen: CARDINAL;
BEGIN
  strlen := Length(str);
  IF inx < strlen THEN
    IF inx + len > strlen THEN len := strlen - inx END;
    MOVE(ADR(str)+(inx+len), ADR(str)+inx, HIGH(str)+1-(inx+len));
    FILL(ADR(str)+(strlen-len), len, 0);
  END; (* 010a *)
END Delete;

(* $[- store procedure names *)

PROCEDURE Append (substr : ARRAY OF CHAR; VAR str: ARRAY OF CHAR);
(* TODO: find a way to generate D3 opcode instead of 40 12 *)
VAR strlen, sublen, newlen: CARDINAL;
BEGIN
  strlen := Length(str);
  sublen := Length(substr);
  newlen := strlen + sublen;
  IF newlen > HIGH(str)+1 THEN RAISE StringError END;
  MOVE(ADR(substr), ADR(str)+strlen, sublen);
  IF newlen <= HIGH(str) THEN str[newlen] := 0C END;
END Append;

PROCEDURE Copy   (VAR str: ARRAY OF CHAR; inx,len: CARDINAL;
                  VAR result: ARRAY OF CHAR);
VAR strlen: CARDINAL;
BEGIN
  result := "";
  strlen := Length(str);
  IF inx < strlen THEN
    IF inx + len > strlen THEN len := strlen - inx END;
    IF len > HIGH(str)+1  THEN RAISE StringError END;
    MOVE(ADR(str)+inx, ADR(result), len);
  END; (* 017C *)
END Copy;

(* $[+ remove procedure names *)

PROCEDURE CAPS   (VAR str: ARRAY OF CHAR);
VAR i: CARDINAL;
BEGIN
  i := 0; REPEAT str[i] := CAP(str[i]); INC(i) UNTIL i > HIGH(str)
END CAPS;

END Strings.
                                                                                                 