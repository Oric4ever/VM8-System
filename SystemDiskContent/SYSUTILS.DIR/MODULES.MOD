MODULE MODULES;
FROM SYSTEM IMPORT ADDRESS, ADR;

TYPE ModName    = ARRAY [0..7] OF CHAR;
     ModNamePtr = POINTER TO ModName;

VAR proc : RECORD
             CASE :CARDINAL OF
             | 1 : p : PROC
             | 2 : module : ADDRESS; procnum : CARDINAL
             END
           END;

PROCEDURE WriteHex(i: CARDINAL);
  PROCEDURE WriteHexDigit(i: CARDINAL);
  BEGIN
    IF i>9 THEN WRITE(CHR(i-10+ORD('A'))) ELSE WRITE(CHR(i+ORD('0'))) END;
  END WriteHexDigit;
BEGIN
  WriteHexDigit(i DIV 4096);
  WriteHexDigit(i DIV 256 MOD 16);
  WriteHexDigit(i DIV 16  MOD 16);
  WriteHexDigit(i MOD 16);
END WriteHex;

PROCEDURE ShowModules;
VAR moduleAddr: ADDRESS;
    versionPtr: POINTER TO CARDINAL;
    namePtr   : ModNamePtr;
    linkPtr   : POINTER TO ADDRESS;
BEGIN
  WRITELN("Module name     Version");
  moduleAddr := proc.module - 80;
  WHILE moduleAddr <> NIL DO
    namePtr := moduleAddr + 66;
    WRITE(namePtr^); WRITE("       "); WRITE(CHR(9));
    versionPtr := moduleAddr + 76;
    WriteHex(versionPtr^); WRITELN;
    linkPtr    := moduleAddr + 64;
    moduleAddr := linkPtr^;
  END;
END ShowModules;

BEGIN
  proc.p := ShowModules;
  ShowModules
END MODULES.
