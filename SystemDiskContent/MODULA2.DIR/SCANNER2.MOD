IMPLEMENTATION MODULE Scanner;
IMPORT Compiler, Files, Texts, ComLine, Loader, Doubles, Errors, SymTab, CodeGen;
FROM SYSTEM IMPORT ADR, MOVE, CODE, TSIZE, OVERFLOW, REALOVERFLOW;
FROM STORAGE IMPORT ALLOCATE,DEALLOCATE,MARK,RELEASE;

VAR global29: Scope;
    global30: CARDINAL;

CONST FREEMARKER = 3AE3H;
CONST EOT = 032C; DEL = 177C;
CONST LINEFEED = 012C; TAB = 011C; CR = 015C;

CONST COLUMN = 2; DOT = 3; ELLIPSIS = 4;
      RIGHTINDEXBRACKET = 6; RIGHTSETBRACKET = 7;
      PIPE = 8; ALPHA = 10; DIGIT = 11; QUOTE = 12; BECOMES = 27;
      LEFTPARENTHESIS = 43; LEFTINDEXBRACKET = 44; LEFTSETBRACKET = 45;
      NOTEQUAL = 53; LESS = 54; GREATER = 55; LESSOREQUAL = 56; GREATEROREQUAL = 57;
      BOOLEANNOT = 66;

(* trying to remove fixed-address variables...
VAR stackLimit [0316H]: ADDRESS;
VAR fileBuf [0080H]: ARRAY [0..127] OF CHAR;
VAR bufIndex[006CH]: CARDINAL;
VAR filePos [006EH]: CARDINAL;
VAR column  [0070H]: CARDINAL;
VAR console [0072H]: CARDINAL;
*)

VAR filePos : CARDINAL;
VAR fileBuf : ARRAY [0..127] OF CHAR;
VAR column  : CARDINAL;
VAR console : BOOLEAN;
VAR bufIndex: CARDINAL;

CONST EXPECTED = " expected, but ";

(* $[+ remove procedure names *)

PROCEDURE Error(param1: CARDINAL);
BEGIN
  Errors.proc1(param1);
END Error;

PROCEDURE proc25(VAR s: ARRAY OF CHAR; ext: Ext; b: BOOLEAN);
VAR i: CARDINAL;
BEGIN
  i := 0;
  WHILE (i < HIGH(s) - 3) AND (s[i] <> 0C) AND (s[i] <> '.') DO
    INC(i)
  END;
  IF b OR (s[i] <> '.') THEN
    s[i] := '.';
    MOVE(ADR(ext), ADR(s[i+1]), 3);
  END;
END proc25;

(* proc27: import MODULE *)
PROCEDURE ImportModule(modName: ARRAY OF CHAR; version: CARDINAL): CARDINAL;
VAR i: CARDINAL;
    ptr : POINTER TO SymTab.Import;
BEGIN
  (* try to find module in already imported modules *)
  i := 0;
  WHILE (i < SymTab.NbImports) AND (SymTab.Imports^[i].modName <> modName) DO
    INC(i)
  END; 
  ptr := ADR(SymTab.Imports^[i]);
  IF i < SymTab.NbImports THEN (* found it, check version *)
    IF ptr^.version <> version THEN Errors.proc2(12, ptr^.modName) END;
  ELSE (* not found, add it *)
    IF i > 15 THEN Error(84) END; (* Error, too many imported modules *)
    ptr^.modName := modName;
    ptr^.version := version;
    INC(SymTab.NbImports);
  END;
  RETURN i
END ImportModule;

PROCEDURE Allocate(VAR a:ADDRESS; n:CARDINAL); (* was in Z80 code *)
(* CODE("ALLOCATE") *)
BEGIN
  ALLOCATE(a, n);
END Allocate;

PROCEDURE GetHeapEnd(VAR param1: ADDRESS);
VAR addr: ADDRESS;
BEGIN
  ALLOCATE(addr, 1);
  param1 := addr;
  DEALLOCATE(addr, 1);
(*  param1 := stackLimit - 60; *)
END GetHeapEnd;

PROCEDURE SetHeapEnd(param1: ADDRESS);
VAR heap: ADDRESS;
BEGIN 
  GetHeapEnd(heap);
  IF param1 < heap THEN DEALLOCATE(param1, heap-param1)
  ELSE ALLOCATE(heap, param1-heap)
  END;
(*
  stackLimit := param1 + 60;
  param1^ := FREEMARKER;
*)
END SetHeapEnd;

(* proc 22: find buffer in keyword list *)
PROCEDURE FindIdent(VAR list: Object; buffer: ADDRESS; caseInsensitive: BOOLEAN): Object;
(* CODE("FINDKEYW"); *)
VAR current: Object;
BEGIN
  current := list;
  WHILE current <> NIL DO
    IF StrCmp(buffer, current^.name, caseInsensitive) THEN 
      RETURN ADDRESS(current)
    END;
    current := current^.next;
  END;
  RETURN NIL;
END FindIdent;

(* proc 23: original was in Z80 code, removed caseInsensitive comparison *)
PROCEDURE StrCmp(ptr1, ptr2: Ident; caseInsensitive: BOOLEAN):BOOLEAN;
(* CODE("STRCMP"); *)
BEGIN
  WHILE ptr1^[0] = ptr2^[0] DO
    IF ptr1^[0] = 0C THEN RETURN TRUE END;
    ptr1 := ADDRESS(ptr1)+1;
    ptr2 := ADDRESS(ptr2)+1;
  END;
  RETURN FALSE;
END StrCmp;

(* proc24: original was in Z80 code, never returns a zero length *)
PROCEDURE StrLen(VAR s: ARRAY OF CHAR): CARDINAL;
(* CODE("STRLEN"); *)
VAR i: CARDINAL;
BEGIN
  i := 0;
  WHILE (i < HIGH(s)) AND (s[i] # 0C) DO INC(i) END;
  IF i # 0 THEN RETURN i END;
  RETURN 1;  (* never return a zero length *)
END StrLen;

PROCEDURE AllocateString(VAR a: ADDRESS; VAR s: ARRAY OF CHAR);
VAR length: CARDINAL;
BEGIN
  length := StrLen(s);
  Allocate(a, length+1);
  MOVE(ADR(s), a, length);
END AllocateString;

(* proc 15 *)
PROCEDURE AllocateObject(class: CARDINAL): Object;
VAR obj: Object;
BEGIN
  Allocate(obj, 14);
  obj^.class := class;
  RETURN obj
END AllocateObject;

(* proc 14 *)
PROCEDURE AllocateType(typenum: CARDINAL): Type;
VAR type: Type;
BEGIN
  IF    typenum <=  1 THEN Allocate(type, 14)
  ELSIF typenum <=  6 THEN Allocate(type, 10)
  ELSIF typenum <= 11 THEN Allocate(type, 12)
  ELSE                     Allocate(type, 16)
  END;
  type^.typenum := typenum;
  RETURN type
END AllocateType;

PROCEDURE proc18(class: CARDINAL): ADDRESS;
VAR obj : Object;
BEGIN
  proc12;
  IF global13 = SymTab.global9 THEN Errors.proc2(1, buffer) END;
  obj := AllocateObject(class);
  AllocateString(obj^.name, buffer);
  proc1;
  RETURN obj
END proc18;

PROCEDURE proc20(obj: Object);
BEGIN
  IF FindIdent(SymTab.global9^.firstSym, obj^.name, 9 IN CompilerOptions) # NIL THEN
    Errors.proc2(1, obj^.name^)
  END;
  obj^.next := SymTab.global9^.firstSym;
  SymTab.global9^.firstSym := obj;
END proc20;

PROCEDURE proc19(class: CARDINAL): ADDRESS;
VAR obj: Object;
BEGIN
  obj := proc18(class);
  obj^.next := SymTab.global9^.firstSym;
  SymTab.global9^.firstSym := obj;
  RETURN obj
END proc19;

PROCEDURE proc17(a:ADDRESS; next: ADDRESS);
BEGIN
  Allocate(SymTab.global9, 14);
  SymTab.global9^.nextScope := a;
  SymTab.global9^.firstSym  := next;
END proc17;

PROCEDURE proc32;
VAR PipeChar[034EH]: CHAR;
BEGIN
  Texts.WriteLn(2);
  IF global23 
  THEN Texts.WriteCard(2, CodeGen.global2 - global22, 4)
  ELSE Texts.SetCol(2, 4)
  END;
  Texts.WriteChar(2, PipeChar);
  Texts.WriteChar(2, ' ')
END proc32;

PROCEDURE proc33;
BEGIN
  IF (ORD(lastCh) + 1) MOD 256 > 32 THEN Texts.WriteChar(2, lastCh); RETURN END;
  IF lastCh = LINEFEED THEN column := 0; proc32; RETURN END;
  IF lastCh = TAB      THEN 
    REPEAT Texts.WriteChar(2," "); INC(column) UNTIL column MOD 8 = 0;
  ELSIF (lastCh < " ") AND (lastCh # CR) THEN
    Texts.WriteChar(2, "^");
    Texts.WriteChar(2, CHR(ORD(lastCh)+40H))
  END;
END proc33;

PROCEDURE proc34;
VAR nbRead: CARDINAL;
BEGIN
  nbRead := Files.ReadBytes(global16, ADR(fileBuf), 128);
  IF nbRead < 128 THEN fileBuf[nbRead] := EOT END;
  bufIndex := 0;
  ReadNextChar
END proc34;

PROCEDURE proc28;
BEGIN
  lastCh  := ' ';
  column   := 0;
  bufIndex := 128;
  IF 0 IN CompilerOptions THEN proc32 END;
  Files.NoTrailer(global16)
END proc28;

PROCEDURE proc29;
VAR nbRead: CARDINAL;
BEGIN
  IF NOT Files.Open(global16, ComLine.inName) THEN HALT END;
  proc28;
  Files.SetPos(global16, LONG((global25 DIV 128) * 128));
  nbRead   := Files.ReadBytes(global16, ADR(fileBuf), 128);
  bufIndex := global25 MOD 128;
  filePos  := global25;
  proc1
END proc29;

PROCEDURE ReadNextChar; (* original was in Z80 code *)
(* CODE("READNEXT"); *)
VAR ch: CHAR;
BEGIN
  IF bufIndex = 128 THEN proc34
  ELSE
    ch := fileBuf[bufIndex];
    INC(bufIndex);
    IF ch = EOT THEN lastCh := 377C ELSE lastCh := ch END;
    INC(filePos);
    IF 0 IN CompilerOptions THEN (* List option *)
      IF ch >= ' ' THEN
        INC(column);
        IF console THEN Texts.WriteChar(3, ch); RETURN END;
      END;
      proc33
    END;
  END;
END ReadNextChar;

PROCEDURE proc1;
(* $[- keep procedure names *)

  (* proc 35 *)
  PROCEDURE Number;
  VAR local2: CARDINAL;
  VAR local3: CARDINAL;
  VAR local4: CARDINAL;
  VAR local5: CARDINAL;
  VAR local6: CARDINAL;
  VAR local7: INTEGER;
  VAR local8: BOOLEAN;
  VAR local9 : BOOLEAN;
  VAR local10: BOOLEAN;
  VAR local12: LONGINT;
  VAR local14: LONGINT;
  VAR local16: LONGINT;
  VAR local18: LONGINT;
  
  (* $[+ remove procedure names *)
  
    (* proc 36 *)
    PROCEDURE Ten(exp: CARDINAL): REAL;
    VAR n: CARDINAL;
    VAR r: REAL;
    BEGIN
      n := 0;
      r := 1.0;
      REPEAT
        IF ODD(exp) THEN
          CASE n OF
          | 0 : r := r * 1.0E01
          | 1 : r := r * 1.0E02
          | 2 : r := r * 1.0E04
          | 3 : r := r * 1.0E08
          | 4 : r := r * 1.0E16
          | 5 : r := r * 1.0E32
          ELSE RAISE REALOVERFLOW
          END;
        END;
        exp := exp DIV 2;
        INC(n);
      UNTIL exp = 0;
      RETURN r
    END Ten;
  
    PROCEDURE proc37;
    VAR digit: CARDINAL;
    BEGIN
      IF global30 < 128 THEN buffer[global30] := lastCh; INC(global30) END;
      ReadNextChar;
      digit := ORD(lastCh) - ORD('0');
      IF digit > 9 THEN
        IF digit >= 17 THEN digit := digit - 7 ELSE digit := 16 END;
      END; (* 043C *)
      local4 := digit
    END proc37;
  
  (* $[- keep procedure names *)
  BEGIN (* Number *)
    local2  := 0;
    local12 := LONG(0);
    local7  := 0;
    local18 := local12;
    local16 := local12;
    local14 := local12;
    global30:= 0;
    local4  := ORD(lastCh) - ORD('0');
    local5  := local4;
    local10 := TRUE;
    local9  := TRUE;
    REPEAT
      IF local5 > 7 THEN
        local10 := FALSE;
        IF local5 > 9 THEN local9 := FALSE END;
      END;
      IF local4 <= 9 THEN
        local14 := local14 * LONG(10) + LONG(local4);
        IF local14 < 3355443L THEN local12 := local14 ELSE INC(local7) END;
        IF local4 <= 7 THEN local16 := local16 * LONG(8) + LONG(local4) END;
      END; (* 04b1 *)
      IF local18 <= LONG(65535) THEN local18 := local18 * LONG(16) + LONG(local4) END;
      local5 := local4;
      proc37;
    UNTIL local4 > 15;
    global12 := Compiler.CardType;
    IF lastCh = '.' THEN
      proc37;
      IF    lastCh = '.' THEN lastCh := DEL; DEC(global30)
      ELSIF lastCh = ')' THEN lastCh := ']'; DEC(global30)
      ELSE
        IF NOT local9 THEN Error(30) END;
        global12 := Compiler.RealType;
        WHILE local4 <= 9 DO
          IF local12 < 3355443L THEN
            local12 := local12 * LONG(10) + LONG(local4);
            DEC(local7)
          END; (* 0527 *)
          proc37;
        END; (* 052B *)
        IF local4 IN {13, 14} THEN
          IF local4 = 13 THEN global12 := Compiler.LongrealType END;
          local3 := 0;
          proc37;
          local8 := (lastCh = '-');
          IF local8 OR (lastCh = '+') THEN proc37 END;
          IF local4 > 9 THEN Error(30) END;
          REPEAT
            IF local3 < 255 THEN local3 := local3 * 10 + local4 END;
            proc37;
          UNTIL local4 > 9;
          IF local8
          THEN DEC(local7, local3)
          ELSE INC(local7, local3)
          END;
        END; (* 0577 *)
        IF global12 = Compiler.RealType THEN
          IF local12 >= 16777216L
          THEN global14 := FLOAT((local12 + LONG(1)) DIV LONG(2)) * 2.0
          ELSE global14 := FLOAT(local12)
          END;
          IF    local7 < 0 THEN global14 := global14 / Ten(-local7)
          ELSIF local7 # 0 THEN global14 := global14 * Ten(local7)
          END;
        ELSE
          buffer[global30] := 0C;
          IF NOT Doubles.StrToDouble(buffer, global17) THEN Error(74) END;
        END;
      END;
    END; (* 05D4 *)
    IF global12^.typenum # 8 THEN
      IF lastCh = 'L' THEN
        proc37;
        global14 := REAL(local14);
        global12 := Compiler.LongintType;
      ELSE
        local6 := 65535;
        IF lastCh = 'H' THEN proc37; local12 := local18
        ELSE
          IF local5 IN {11, 12} THEN
            IF NOT local10 THEN Error(30) END;
            local12 := local16;
            IF local5 = 12 THEN global12 := Compiler.CharType; local6 := 255 END;
          ELSE
            IF NOT local9 OR (local5 > 9) THEN Error(30) END;
            local12 := local14;
          END;
        END; (* 062e *)
        IF local12 > LONG(local6) THEN Error(73) END;
        global7 := CARD(local12);
      END;
    END; (* 063f *)
    IF CharTable^[lastCh] = ALPHA THEN Error(30) END;
  EXCEPTION
  | OVERFLOW: Error(73)
  | REALOVERFLOW: 
      IF local7 >= 0 THEN Error(74) END;
      global14 := REAL(0L);
  END Number;
  
(* $[+ remove procedure names *)
  PROCEDURE proc38;
  VAR local2: CARDINAL;
  BEGIN
    REPEAT
      REPEAT
        IF lastCh = CHR(255) THEN Error(29) END;
        ReadNextChar;
        IF lastCh = '(' THEN
          REPEAT ReadNextChar UNTIL lastCh # '(';
          IF lastCh = '*' THEN proc38 END; (* recursive call *)
        END;
        IF lastCh = '$' THEN
          ReadNextChar;
          local2 := CARDINAL(BITSET(lastCh) * {0,1,2,3,4,6}) - ORD('L');
          IF local2 <= 15 THEN
            ReadNextChar;
            IF    lastCh = '-' THEN EXCL(CompilerOptions, local2)
            ELSIF lastCh = '+' THEN INCL(CompilerOptions, local2)
            END;
            IF local2 = 0 THEN Texts.WriteLn(2) END;
          END;
        END; (* 06c6 *)
      UNTIL lastCh = '*';
      REPEAT ReadNextChar UNTIL lastCh # '*';
    UNTIL lastCh = ')';
  END proc38;

  PROCEDURE scanNextToken():BOOLEAN; (* original was in Z80 code *)
  (* CODE("NEXTTOKN"); *)
  VAR i: CARDINAL;
  VAR typeOfChar: CARDINAL;
  BEGIN
    global6 := FALSE;
    global9 := 7;
    WHILE lastCh <= ' ' DO ReadNextChar END;
    global25 := filePos - 1;
    global26 := column;
    IF lastCh < CHR(128)
    THEN token := CharTable^[lastCh]
    ELSE token := 0
    END;
    IF token = ALPHA THEN
      i := 0;
      REPEAT
        IF i # 128 THEN buffer[i] := lastCh; INC(i) END;
        ReadNextChar;
        typeOfChar := CharTable^[lastCh];
      UNTIL (typeOfChar # ALPHA) AND (typeOfChar # DIGIT);
      buffer[i] := 0C;
      RETURN TRUE
    END; (* 0730 *)
    RETURN FALSE;
  END scanNextToken;

VAR local2: BOOLEAN;
    strLen: CARDINAL;
    noCase: BOOLEAN;
    quoteChar: CHAR;
BEGIN
  REPEAT
    IF scanNextToken() THEN
      noCase := 9 IN CompilerOptions; (* option 9: Upper = lower *)
      token := procPtr27(ADR(buffer), ORD(noCase));
      IF token # 0 THEN
        global9 := 7;
        IF ((token = 14) OR (token = 39))
        AND NOT (12 IN CompilerOptions) (* option 12: TurboM2 eXtensions *)
        THEN Errors.proc3(2) END;
        RETURN
      END;
      global13 := SymTab.global9;
      REPEAT
        global8  := FindIdent(global13^.firstSym, ADR(buffer), noCase);
        IF global8 # NIL THEN
          global12 := global8^.base;
          global9  := global8^.class;
          global10 := global8^.word3;
          RETURN
        END;
        global13 := global13^.nextScope;
      UNTIL global13 = NIL;
      global9 := 0;
      RETURN
    END;
    local2 := TRUE;
    CASE token OF
    | 0 : Error(31 - ORD(lastCh = CHR(255)) * 2)
    | COLUMN : 
          ReadNextChar;
          IF    lastCh = '=' THEN token := BECOMES; ReadNextChar
          ELSIF lastCh = ')' THEN token := RIGHTSETBRACKET; ReadNextChar
          END;
    | DOT : 
          ReadNextChar;
          IF    lastCh = '.' THEN token := ELLIPSIS; ReadNextChar
          ELSIF lastCh = ')' THEN token := RIGHTINDEXBRACKET; ReadNextChar
          END;
    | DIGIT :
          global6 := TRUE;
          global9 := 1;
          token   := 0;
          Number;
          buffer[global30] := 0C
    | QUOTE :
          strLen    := 0;
          global6   := TRUE;
          global9   := 1;
          token     := 0;
          quoteChar := lastCh;
          ReadNextChar;
          WHILE lastCh # quoteChar DO
            IF lastCh = LINEFEED THEN Error(28) END;
            IF lastCh = CHR(255) THEN Error(29) END;
            IF strLen < 128 THEN buffer[strLen] := lastCh; INC(strLen); END;
            ReadNextChar;
          END;
          buffer[strLen] := 0C;
          ReadNextChar;
          global12 := Compiler.StringType;
          IF strLen = 1 THEN
            global12 := Compiler.CharType;
            global7  := ORD(buffer[0]);
          END;
    ELSE
          ReadNextChar;
          CASE token OF
          | LEFTPARENTHESIS:
              IF    lastCh = '*' THEN proc38; ReadNextChar; local2 := FALSE
              ELSIF lastCh = '.' THEN token := LEFTINDEXBRACKET; ReadNextChar
              ELSIF lastCh = ':' THEN token := LEFTSETBRACKET; ReadNextChar
              END;
          | LESS:
              IF    lastCh = '=' THEN token := LESSOREQUAL; ReadNextChar 
              ELSIF lastCh = '>' THEN token := NOTEQUAL; ReadNextChar
              END;
          | GREATER:
              IF    lastCh = '=' THEN token := GREATEROREQUAL; ReadNextChar END;
          END;
    END;
  UNTIL local2;
END proc1;

PROCEDURE proc4(param1: CARDINAL): BOOLEAN;
BEGIN
  IF token = param1 THEN proc1; RETURN TRUE END;
  RETURN FALSE
END proc4;

PROCEDURE proc3;
BEGIN
  IF global9 = 6 THEN
    global29^.firstSym  := global8^.objects;
    global29^.nextScope := SymTab.global9;
    SymTab.global9      := global29;
    proc1;
    proc8(3);
    proc12;
    IF global13 # global29 THEN Errors.proc2(3, buffer) END;
    SymTab.global9  := SymTab.global9^.nextScope;
  END;
END proc3;

PROCEDURE proc8(param1:CARDINAL);
VAR local2: BITSET;
VAR local3: CARDINAL;
BEGIN
  IF token = param1 THEN proc1; RETURN END;
  local3 := 0;
  local2 := {};
  IF    param1 >= 51 THEN local3 := 51
  ELSIF param1 >= 40 THEN local3 := 40
  ELSIF param1 >= 27 THEN local3 := 27
  ELSIF param1 >= 13 THEN local3 := 13
  END;
  local2 := local2 + {param1 - local3};
  Errors.proc16(local2, local3)
END proc8;

PROCEDURE proc9(param1: BITSET);
BEGIN
  IF NOT (token IN param1) THEN Errors.proc16(param1, 0) END;
END proc9;

PROCEDURE proc10(param1: BITSET);
BEGIN
  IF NOT ((token-40) IN param1) THEN Errors.proc16(param1, 40) END;
END proc10;

PROCEDURE proc11(param1: BITSET);
BEGIN
  IF NOT ((token-13) IN param1) THEN Errors.proc16(param1, 13) END;
END proc11;

PROCEDURE proc12;
BEGIN
  IF (global9 = 7) OR global6 THEN
    Errors.proc8('A');
    Texts.WriteString(3, "Identifier");
    Texts.WriteString(3, EXPECTED);
    Errors.proc7;
    Errors.proc9;
  END;
END proc12;

PROCEDURE proc21(VAR param2: ARRAY OF CHAR);
BEGIN
  proc12;
  IF StrCmp(ADR(buffer), ADR(param2), 9 IN CompilerOptions) THEN proc1; RETURN END;
  Errors.proc2(9, param2);
END proc21;

PROCEDURE proc13(param1: CARDINAL);
BEGIN
  IF global9 # param1 THEN
    proc12;
    IF global9 = 0 THEN Errors.proc2(0, buffer) END;
    Errors.proc8('B');
    Errors.proc6(param1);
    Texts.WriteString(3, EXPECTED);
    Errors.proc6(global9);
    Texts.WriteString(3, " found");
    Errors.proc9;
  END;
END proc13;

PROCEDURE Compile;

(* Z80 proc 40 can be removed, now that compiler has been modified to accept VAR(scalar) *)
(*
  PROCEDURE VarAddress(VAR v: WORD):ADDRESS;
  CODE("Z80RET")
  END VarAddress;
*)

VAR addr: ADDRESS;
(*
    ptr       [006EH]: CARDINAL;
    console   [0072H]: BOOLEAN;
    jmpOpcode [0074H]: CARDINAL;
    jmpAddress[0075H]: CARDINAL;
*)
(* $[- keep procedure names *)

BEGIN
(*
(* inits Z80 jmp to ReadNextChar *)
  jmpOpcode := 0C3H;
  addr      := VarAddress(CompilerOptions)-6;
  (* CompilerOptions is first variable of module => addr is pointer to procedure table  *)
  addr      := ADDRESS(addr^) - 4;      (* addr points now the proc2 relative addr *)
  jmpAddress:= addr + CARDINAL(addr^) + 3; (* jmpAddress points to body of ReadNextChar *)
  ptr       := 0;
*)
  filePos   := 0;
  console   := (ComLine.outName = "CON:");
  MARK(addr);
  global23  := FALSE;
  global25  := 0;
  Allocate(global29, 14);
  Compiler.GETINP;
  IF global16 <> NIL THEN
    Allocate(WorkSpace, 4096);
    Loader.Call("COMPILE");
(* 
    IF Compiler.global25 THEN
      SetHeapEnd(WorkSpace + CodeGen.global2);
      IF CodeGen.global3 <> 0 THEN
        MOVE(WorkSpace, WorkSpace + CodeGen.global3, CodeGen.global2 - CodeGen.global3);
        Files.SetPos(OutputFile, LONG(0));
        IF Files.ReadBytes(OutputFile, WorkSpace, CodeGen.global3) <> CodeGen.global3 THEN
          RAISE Files.EndError
        END;
      END;
      Files.SetPos(OutputFile, LONG(0));
      Loader.Call("GENZ80");
    END;
*)
  END;
  Texts.CloseText(Texts.output);
  RELEASE(addr);

EXCEPTION Loader.LoadError:
  Texts.WriteLn(3); (* console *)
  Texts.WriteString(3,"ERROR: CANNOT LOAD OVERLAY");
  Texts.WriteLn(3);
  Files.Delete(OutputFile);
  RELEASE(addr)
END Compile;

(* $[+ remove procedure names *)
END Scanner.
                                                                                                   