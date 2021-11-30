IMPLEMENTATION MODULE ShellRes;
FROM Texts    IMPORT TEXT, Init, haltOnControlC, ConnectDriver;
FROM Loader   IMPORT Call, LoadError;
FROM ComLine  IMPORT commandLine, progName, execute;
FROM Terminal IMPORT WriteString, WriteLn;
FROM EditPos  IMPORT editPos;
(* comment the following two lines to not link with editor and compiler *)
FROM Editor   IMPORT Edit;
FROM Scanner  IMPORT global2;

(* comment the following three lines to not link with ObnScan and ObnSymb *)
FROM OScanner IMPORT Ident;
FROM OSymTab  IMPORT universe;
FROM ObnGen1  IMPORT Item;

IMPORT Excepts;

VAR index : CARDINAL;
    buffer [0081H]: ARRAY [0..126] OF CHAR;

PROCEDURE RunModule;
BEGIN
  Call(progName)
EXCEPTION
| LoadError :
  WriteString(progName);
  WriteString(" not loaded.");
  WriteLn;
END RunModule;

PROCEDURE textDriver(text: TEXT; VAR ch: CHAR);
CONST EOF = 032C;
BEGIN
  IF (ORD(buffer[index]) - ORD('<')) IN {0,2} THEN
    REPEAT INC(index) UNTIL buffer[index]<=' '
  END;
  ch := buffer[index];
  IF ch = 0C THEN ch := EOF ELSE INC(index) END;
END textDriver;

BEGIN
  LOOP
    (* Re-initialize the Texts module *)
    Init;

    (* load the shell if we haven't a program to chain *)
    IF execute = 0 THEN
      haltOnControlC := FALSE;
      Call("SHELL3");
      haltOnControlC := TRUE;
    END;

    (* once it has returned, we have more memory for the program to run *)
    index := 0;
    ConnectDriver(commandLine, textDriver);
    execute := 0;
    RunModule;
  END;
END ShellRes.