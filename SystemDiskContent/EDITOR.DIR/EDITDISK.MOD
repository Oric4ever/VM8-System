IMPLEMENTATION MODULE EDITDISK;
FROM STORAGE IMPORT ALLOCATE, DEALLOCATE, MARK, RELEASE;
FROM SYSTEM  IMPORT ADR, MOVE, OUTOFMEMORY, WORD;
IMPORT Editor, Edit2, Terminal, Files, Texts, FATDIR;
FROM ComLine IMPORT inName;

CONST CR = 15C; EOF = 32C; ESC = 33C; DEL = 177C;
TYPE Extension = ARRAY [0..2] OF CHAR;
TYPE Record    = RECORD w0,w1,w2: CARDINAL; END;
     RecordPtr = POINTER TO Record;

CONST NOTFOUND = "*** Not found: ";

VAR nbSectors128: CARDINAL;
VAR fileIsNew: BOOLEAN;
VAR global10: ADDRESS;
(* strange variables, seem to work around bug in heap management
VAR global11: RecordPtr;
VAR global12: Record;
*)
(* FF: added variables *)
VAR t: Texts.TEXT; (* used at init for editkeys.txt, then for error file *)
    errorFilePresent: BOOLEAN;
    i: CARDINAL;

CONST NBCOMMANDS = 48;
CONST COMMANDS = "ABCDEFGHIJaabbcdefghiKLMjNOPoprstuvwSxyzQklmTRUV";

(* $[+ remove procedure names *)

(* strange procedure, bug workaround?
PROCEDURE proc18;
VAR local2: ADDRESS;
    local3: RecordPtr;
BEGIN
  ALLOCATE(local2, 58);
  ALLOCATE(local3, 6);
  local3 := global11;
  DEALLOCATE(local3, 512);
  DEALLOCATE(local2, 58);
END proc18;
*)

(* $[- keep procedure names *)
(* proc 19 *)
PROCEDURE DoCreate(VAR file: Files.FILE; VAR name: ARRAY OF CHAR);
BEGIN
  Files.Create(file, name);
EXCEPTION Files.UseError :
  Files.ResetSys();
  Files.Create(file, name);
END DoCreate;

(* $[+ remove procedure names *)
(* proc 20 *)
PROCEDURE addExtension(VAR name: ARRAY OF CHAR; ext: Extension; forceExt: BOOLEAN);
VAR i,j : CARDINAL;
BEGIN
  i := 0; REPEAT INC(i) UNTIL (i >= HIGH(name) - 4) OR (name[i]='.') OR (name[i]=0C);
  IF forceExt OR (name[i] <> '.') THEN
    name[i] := '.';
    j := 0; REPEAT INC(i); name[i] := ext[j]; INC(j) UNTIL j > 2;
    name[i + 1] := 0C;
  END;
END addExtension;

PROCEDURE proc1(): BOOLEAN;
VAR char   : CHAR;
VAR filename : ARRAY [0..20] OF CHAR;
BEGIN
  global7 := 0;
  global3 := 0;
  MARK(global10);
(*  proc18; *)
  addExtension(inName, "OBN", FALSE);
  fileIsNew := NOT Files.Open(global4, inName);
  IF fileIsNew THEN
    Terminal.WriteLn;
    Terminal.WriteString(inName);
    Terminal.WriteString(" is new.   OK? (Y/N) ");
    Terminal.ReadChar(char);
    char := CAP(char);
    Terminal.WriteChar(char);
    Terminal.WriteLn;
    IF char # 'Y' THEN RETURN FALSE END;
    DoCreate(global4, inName);
  END;
  Files.GetName(global4, inName);
  filename := inName;
  addExtension(filename, "$$$", TRUE);
  global6^ := inName;
  addExtension(global6^, "BAK", TRUE);
(*  proc18; *)
  DoCreate(global5, filename);

  addExtension(filename, "ERR", TRUE);
  errorFilePresent := Texts.OpenText(t, filename);

  Files.NoTrailer(global4);
  Files.NoTrailer(global5);
  nbSectors128 := CARD((Files.FileSize(global4) + LONG(127)) DIV LONG(128));
  global2 := (nbSectors128 = 0);
  IF NOT global2 THEN
    proc2;
    IF NOT global2 THEN proc2 END;
  END;
(*   proc18; *)
(*  global12 := global11^; *)
  RETURN TRUE
END proc1;

PROCEDURE nextError(VAR line, column: CARDINAL; VAR msg: ARRAY OF CHAR);
VAR str: ARRAY [0..7] OF CHAR;
    i : CARDINAL;
BEGIN
  line := 0;
  IF errorFilePresent AND NOT Texts.EOT(t) THEN
    Texts.ReadString(t, str);
    IF str # "line" THEN RETURN END;
    Texts.ReadCard(t, line);
    Texts.ReadString(t, str); (* "col" *)
    Texts.ReadCard(t, column);
    Texts.ReadLine(t, msg);
  ELSE msg := "no error message"
  END;
  i := 0; REPEAT INC(i) UNTIL msg[i] = 0C;
  msg[i] := CR;
END nextError;

PROCEDURE proc2;
CONST EOF = 32C;
VAR oldCursor: ADDRESS;
VAR local3: ADDRESS;
VAR local4: ADDRESS;
VAR local5: ADDRESS;
VAR local6: POINTER TO ARRAY [0..0] OF CHAR;
VAR local7: CARDINAL;
BEGIN
  IF ADDRESS(Editor.afterCursor) - ADDRESS(Editor.beforeCursor) < Editor.global15 + 10 THEN proc3 END;
  oldCursor := Editor.afterCursor;
  Editor.afterCursor := ADDRESS(Editor.afterCursor) - Editor.global15;
  MOVE(oldCursor, Editor.afterCursor, Editor.endBuffer - ADDRESS(Editor.afterCursor));
  local4 := Editor.endBuffer - Editor.global15;
  local5 := Files.ReadBytes(global4, local4, Editor.global15) + local4;
(*  global11^ := global12; *)
  global7 := global7 + Editor.nbSectors;
  global2 := (global7 >= nbSectors128);
  IF global2 THEN
    local6 := local5 - 128; IF ADDRESS(local6) < local4 THEN local6 := local4 END;
    WHILE (local6 # local5) AND (local6^[0] # EOF) AND (local6^[0] # 0C) DO
      local6 := ADDRESS(local6) + 1
    END;
    local3 := Editor.afterCursor;
    Editor.afterCursor := ADDRESS(Editor.afterCursor) + Editor.endBuffer - ADDRESS(local6);
    MOVE(local3, Editor.afterCursor, ADDRESS(local6) - local3);
  END; (* 01E8 *)
  local7 := oldCursor - ADDRESS(Editor.afterCursor);
  IF Editor.selectionStart >= oldCursor THEN DEC(Editor.selectionStart, local7) END;
  IF Editor.selectionEnd   >  oldCursor THEN DEC(Editor.selectionEnd, local7) END;
END proc2;

PROCEDURE proc21(param1: CARDINAL);
  (* $[- keep procedure name because of exception handler *)
  (* proc 22 *)
  PROCEDURE WriteText(addr: ADDRESS; length: CARDINAL): BOOLEAN;
  BEGIN
    Files.WriteBytes(global5, addr, length);
    Files.Flush(global5);
(*    global11^ := global12; *)
    RETURN TRUE
  EXCEPTION Files.DiskFull:
(*    global11^ := global12; *)
    RETURN FALSE
  END WriteText;
  (* $[+ remove procedure names *)
VAR local2: FILE;
VAR local3: ADDRESS;
VAR local4: BOOLEAN;
BEGIN
  local3 := Editor.editBuffer;
  local4 := FALSE;
  LOOP
    WHILE (param1 > 512) AND WriteText(local3, 512) DO
      DEC(param1, 512);
      INC(local3, 512);
    END; (* 0253 *)
    IF (param1 <= 512) AND WriteText(local3, param1) THEN RETURN END;
    Files.SetPos(global5, LONG(global3)*LONG(Editor.global15)+LONG(local3-Editor.editBuffer));
    IF local4 OR NOT Files.Open(local2, global6^) THEN
      Files.SetPos(global5, LONG(global3)*LONG(Editor.global15));
      RAISE DiskIsFull
    END; (* 0293 *)
    local4 := TRUE;
    Editor.PrintStatusLine("*** WARNING: DELETING OLD BACKUP FILE *** ", 6);
    Files.Delete(local2);
  END; (* 02CC *)
END proc21;

PROCEDURE proc3;
BEGIN
  proc21(Editor.global15);
  INC(global3);
  IF  (Editor.selectionStart # NIL)
  AND (Editor.selectionStart < ADDRESS(Editor.beforeCursor))
  THEN
    DEC(Editor.selectionStart, Editor.global15);
    IF Editor.selectionStart < Editor.editBuffer THEN
      Editor.selectionStart := NIL;
      Edit2.global2 := FALSE;
    END;
  END;
  IF  (Editor.selectionEnd # NIL)
  AND (Editor.selectionEnd <= ADDRESS(Editor.beforeCursor))
  THEN
    DEC(Editor.selectionEnd, Editor.global15);
    IF Editor.selectionEnd <= Editor.editBuffer THEN
      Editor.selectionEnd := NIL;
      Edit2.global2 := FALSE;
    END;
  END; 
  Editor.beforeCursor := ADDRESS(Editor.beforeCursor) - Editor.global15;
  MOVE(Editor.editBuffer + Editor.global15, Editor.editBuffer,
        ADDRESS(Editor.beforeCursor) - Editor.editBuffer)
END proc3;

PROCEDURE proc5;
BEGIN
  Files.Delete(global5);
  IF fileIsNew THEN Files.Delete(global4) ELSE Files.Close(global4) END;
END proc5;

PROCEDURE proc4;
BEGIN
  REPEAT
    WHILE NOT global2
    AND (ADDRESS(Editor.beforeCursor)+Editor.global15 < ADDRESS(Editor.afterCursor))
    DO proc2
    END;
    Editor.MoveBytesAfterCursorToBefore(Editor.endBuffer - ADDRESS(Editor.afterCursor));
    WHILE ADDRESS(Editor.beforeCursor) >= Editor.editBuffer + Editor.global15
    DO proc3
    END;
  UNTIL global2;
  Editor.beforeCursor^[0] := EOF;
  proc21(ADDRESS(Editor.beforeCursor)+1-Editor.editBuffer);
  IF fileIsNew THEN Files.Delete(global4) ELSE Files.Rename(global4, global6^) END;
  Files.Rename(global5, inName);
  RELEASE(global10)
END proc4;

PROCEDURE proc6;
BEGIN
  global4 := NIL;
  global5 := NIL;
(*  ALLOCATE(global11, 512); *)
  NEW(global6);
END proc6;

PROCEDURE proc10(p2: ARRAY OF CHAR; p1: ARRAY OF CHAR);
BEGIN
  Editor.PrintStatusLine(p2, 6);
  Terminal.GotoXY(HIGH(p2)+7, 0);
  Terminal.Highlight;
  Terminal.WriteString(p1);
  Terminal.WriteString(" ***  Press <ESC>");
  Terminal.Normal;
  REPEAT UNTIL Editor.GetKey() = ESC;
END proc10;

PROCEDURE proc11(p: ARRAY OF CHAR);
BEGIN
  proc10("*** Error: ", p);
  RAISE Edit2.QuitCommand
END proc11;

PROCEDURE proc12;
BEGIN
  IF global3 <> 0 THEN
    Editor.PrintStatusLine("*** Can't go further back, use ^KS to go to beginning *** ", 6);
    Editor.global21 := TRUE;
  END;
END proc12;

PROCEDURE proc15;
BEGIN
  IF NOT global2 THEN
    WHILE ADDRESS(Editor.afterCursor) + Editor.global15 > Editor.endBuffer DO
      Editor.lineUp
    END;
  END;
  Editor.currentRow := Editor.lastRow - 1;
  Editor.UpdateColumn;
  Editor.Proc2;
  proc10("Error: ","DISK FULL");
END proc15;

PROCEDURE proc23(VAR f: FILE; VAR name: Name): BOOLEAN;
BEGIN
  IF Files.Open(f, name) THEN
    Files.GetName(f, name);
    IF name = inName THEN
      Files.Close(f);
      proc11("File in use");
    END;
    Files.NoTrailer(f);
    RETURN TRUE
  ELSE
    RETURN FALSE
  END;
END proc23;

PROCEDURE proc9;
VAR name: Name;
VAR file: FILE;
BEGIN
  IF Edit2.proc5("DELETE FILE: ",6, name) <> 0 THEN
    IF NOT proc23(file, name) THEN proc10(NOTFOUND, name)
    ELSE Terminal.GotoXY(0,0); Files.Delete(file)
    END;
  END;
END proc9;

(* $[- keep procedure name for exception handler *)

(* proc 7 *)
PROCEDURE ReadFile(): BOOLEAN;
VAR name: Name;
VAR local3: CARDINAL;
VAR local4: CARDINAL;
VAR file  : FILE;
VAR local6: POINTER TO ARRAY [0..0] OF CHAR;
BEGIN
  local3 := 0;
  IF Edit2.proc5("READ FILE: ", 6, name) <> 0 THEN
    IF Files.Open(file, name) THEN
      Terminal.GotoXY(0,0);
      Files.NoTrailer(file);
      local3 := CARD(Files.FileSize(file) MOD 65536L);
      WHILE ADDRESS(Editor.afterCursor) - ADDRESS(Editor.beforeCursor) <= local3 + 1 DO
        Editor.Proc14
      END;
      local3 := Files.ReadBytes(file, Editor.beforeCursor, local3);
      Files.Close(file);
      IF local3 <> 0 THEN
        local4 := local3 - 128;
        local6 := ADDRESS(Editor.beforeCursor) + local4;
        WHILE (local4 < local3) AND (local6^[0] # EOF) AND (local6^[0] # 0C) DO
          INC(local4);
          local6 := ADDRESS(local6) + 1;
        END; (* 058d *)
        Editor.selectionStart := Editor.beforeCursor;
        Editor.selectionEnd   := ADDRESS(local6);
        Edit2.global2         := TRUE;
        Editor.beforeCursor   := ADDRESS(local6);
        Editor.currentFileLine:=  Editor.Proc6(Editor.selectionStart, local6)
                                + Editor.currentFileLine;
        Editor.UpdateFirstModifiedPos(Editor.selectionStart);
        Editor.UpdateColumn
      END; (* 05AA *)
    ELSE proc10(NOTFOUND, name)
    END;
  END; (* 05b3 *)
  RETURN local3 <> 0
EXCEPTION Edit2.QuitCommand:
  Files.Close(file);
  RETURN FALSE
END ReadFile;

(* proc8 *)
PROCEDURE WriteFile;
VAR file: FILE;
VAR name: Name;
VAR length: CARDINAL;
BEGIN 
  length := Edit2.proc3();
  IF Edit2.proc5("WRITE TO FILE: ", 6, name) <> 0 THEN
    IF proc23(file, name) THEN
      Files.Close(file);
      IF NOT Edit2.proc4("FILE EXISTS, OVERWRITE ") THEN RETURN END;
    END; (* 0619 *)
    Terminal.GotoXY(0,0);
    Files.Create(file, name);
    Files.NoTrailer(file);
    Files.WriteBytes(file, Editor.selectionStart, length);
    Files.WriteByte(file, EOF);
    Files.Close(file);
  END;
EXCEPTION Files.DiskFull:
  Files.Delete(file);
  proc11("DISK FULL");
END WriteFile;

(* $[+ remove procedure names *)
PROCEDURE proc13(p5: NamePtr; p4,p3: CARDINAL; p2,p1: ADDRESS):CARDINAL;
VAR char: CHAR;
BEGIN
  WHILE p4 < p3 DO
    char := p5^[0];
    p5   := ADDRESS(p5) + 1;
    IF char <= DEL THEN
      IF char < ' ' THEN
        IF char = CR  THEN RETURN p4 END;
        Terminal.WriteChar(CHR(0E2H));
        Terminal.WriteChar(CHR(090H));
        Terminal.WriteChar(CHR(ORD(char) + 080H));
      ELSE
        Terminal.WriteChar(char)
      END; (* 0682 *)
    ELSE
      IF    ORD(char) < 0C2H THEN Terminal.WriteChar('?')
      ELSIF ORD(char) < 0E0H THEN
        Terminal.WriteChar(char);
        Terminal.WriteChar(p5^[0]);
        p5 := ADDRESS(p5) + 1;
      ELSE
        Terminal.WriteChar(char);
        Terminal.WriteChar(p5^[0]);
        Terminal.WriteChar(p5^[1]);
        p5 := ADDRESS(p5) + 2;
      END;
    END;
    INC(p4);
  END;
  RETURN p4;
END proc13;

TYPE VarString = RECORD
                   CASE : CARDINAL OF
                   | 1: size1: ARRAY [0..0] OF CHAR;
                   | 2: size2: ARRAY [0..1] OF CHAR;
                   | 3: size3: ARRAY [0..2] OF CHAR;
                   | 4: size4: ARRAY [0..3] OF CHAR;
                   | 5: size5: ARRAY [0..4] OF CHAR;
                   | 6: size6: ARRAY [0..5] OF CHAR;
                   | 7: size7: ARRAY [0..6] OF CHAR;
                   | 8: full : ARRAY [0..7] OF CHAR;
                   END;
                 END;
VAR editKeys: ARRAY [1..NBCOMMANDS] OF VarString;
VAR commands: ARRAY [1..NBCOMMANDS] OF CHAR;


PROCEDURE proc14(char: CHAR):CARDINAL;
  PROCEDURE IsSubSequence(VAR seq: ARRAY OF CHAR; size: CARDINAL): BOOLEAN;
    VAR i: CARDINAL;
  BEGIN
    CASE size OF
    | 1: FOR i:=1 TO NBCOMMANDS DO IF seq = editKeys[i].size1 THEN RETURN TRUE END END
    | 2: FOR i:=1 TO NBCOMMANDS DO IF seq = editKeys[i].size2 THEN RETURN TRUE END END
    | 3: FOR i:=1 TO NBCOMMANDS DO IF seq = editKeys[i].size3 THEN RETURN TRUE END END
    | 4: FOR i:=1 TO NBCOMMANDS DO IF seq = editKeys[i].size4 THEN RETURN TRUE END END
    | 5: FOR i:=1 TO NBCOMMANDS DO IF seq = editKeys[i].size5 THEN RETURN TRUE END END
    | 6: FOR i:=1 TO NBCOMMANDS DO IF seq = editKeys[i].size6 THEN RETURN TRUE END END
    | 7: FOR i:=1 TO NBCOMMANDS DO IF seq = editKeys[i].size7 THEN RETURN TRUE END END
    END;
    RETURN FALSE
  END IsSubSequence;
VAR buffer : ARRAY [0..7] OF CHAR;
VAR i, size: CARDINAL;
VAR showSeq: BOOLEAN;
BEGIN
  size      := 1;
  buffer[0] := char;
  buffer[1] := 0C;
  showSeq   := (char # ESC);
  FOR i:=1 TO NBCOMMANDS DO IF buffer = editKeys[i].full THEN RETURN ORD(commands[i]) END END;
  IF showSeq THEN
    Terminal.GotoXY(0,0);
    Terminal.Highlight;
    Terminal.WriteChar('^');
    Terminal.Normal;
  END;
  char := CHR(ORD(char)+64);
  WHILE IsSubSequence(buffer, size) DO
    IF showSeq THEN
      Terminal.Highlight; Terminal.WriteChar(char); Terminal.Normal;
    END;
    char := Editor.GetKey(); IF size <= 2 THEN char := CAP(char) END;
    buffer[size] := char;
    INC(size); IF size <= HIGH(buffer) THEN buffer[size] := 0C END;
    FOR i:=1 TO NBCOMMANDS DO IF buffer = editKeys[i].full THEN RETURN ORD(commands[i]) END END;
  END;
  RETURN 0
END proc14;

(* $[- keep procedure name for exception handler *)
BEGIN
  commands := COMMANDS;
  FATDIR.SaveCurrentDir;
  FATDIR.EnterRootDir;
  IF FATDIR.EnterDir("EDITOR") AND Texts.OpenText(t,"EditKeys.txt") THEN
    FOR i:=1 TO NBCOMMANDS DO
      Texts.ReadString(t, editKeys[i].full);
      Texts.ReadLn(t);
      editKeys[i].full[0] := CHR(CARDINAL( BITSET(editKeys[i].full[0]) / {6} ));
      commands[i] := CHR( ORD(commands[i]) - 64 );
    END;
    Texts.CloseText(t);
  END;
  FATDIR.BackToSavedDir;
EXCEPTION ELSE
  FATDIR.BackToSavedDir;
END EDITDISK.
