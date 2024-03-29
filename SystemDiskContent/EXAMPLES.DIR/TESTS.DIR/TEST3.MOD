MODULE TEST3;
FROM SYSTEM IMPORT ADR;
IMPORT NEWFAT32, FATDIR;
FROM Files3 IMPORT FILE, Open, Create, GetName, Close, ReadByte, WriteBytes, WriteByte, EOF, FileSize;
FROM Terminal IMPORT WriteChar;

VAR f, f2: FILE;
    i: CARDINAL;
    ch: CHAR;
    s: ARRAY [0..79] OF CHAR;
BEGIN
  WRITELN("Starting...");
  NEWFAT32.InitFS;
  IF NOT FATDIR.EnterDir("EDITOR  DIR") THEN WRITELN("Cannot change dir to EDITOR"); HALT END;
  Create(f2,"toto.txt");
  IF Open(f,"manual.txt") THEN
    WHILE NOT EOF(f) DO
      ReadByte(f, ch); WriteByte(f2,ch)
    END;
    Close(f);
  ELSE WRITELN("Cannot open manual.txt")
  END;
  Close(f2);
(*
  FATDIR.InitFind("TEST1234MOD");
  IF FATDIR.FindNextMatch(entry) THEN
    entry.desc.nameAndType.fullName := "TEST1234MOD";
    FATDIR.UpdateEntry(entry);
  END;
*)
  WRITELN("BYE.");
END TEST3.                                      