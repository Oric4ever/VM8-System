MODULE Delete;
IMPORT Terminal, Texts, Files, ComLine, FileName;
FROM FileName IMPORT FileNameType, CheckFileName, BuildStdFileName;


PROCEDURE Delet(name: ARRAY OF CHAR);
VAR file: Files.FILE;
BEGIN
  IF Files.Open(file, name) THEN Files.Delete(file) END;
EXCEPTION Files.UseError:
  Files.ResetSys;
  Files.Delete(file);
END Delet;

VAR
    filename : ARRAY [0..15] OF CHAR;
    fileNameCheck : FileNameType;
    char : CHAR;
    file : Files.FILE;
BEGIN
  Texts.ReadString(ComLine.commandLine, filename);
  IF filename[0] = 0C THEN
    Terminal.WriteString("Delete file: ");
    Terminal.ReadLine(filename);
  END;
  IF filename[0] <> 0C THEN
    fileNameCheck := CheckFileName(filename);
    IF fileNameCheck = NORMAL THEN
      IF Files.Open(file, filename) THEN
        Files.Delete(file)
      ELSE
        Terminal.WriteString(filename);
        Terminal.WriteString(" not found.");
        Terminal.WriteLn;
      END;
    ELSIF fileNameCheck = WILDCARD THEN
      Terminal.WriteString("TODO: implement wildcards");
      Terminal.WriteLn;
(*
      IF (filename <> "*.*") OR Confirm("Delete all files") THEN
        proc23(filename);
        IF global12 <> 0 THEN
          local4 := 0;
          REPEAT
            INC(local4);
            local8 := ADR(global11[local4]);
            Terminal.WriteString("Deleting ");
            Terminal.WriteString(local8^.fullname);
            Terminal.WriteLn;
            Delet(local8^.fullname);
          UNTIL local4 >= global12;
        ELSE
          Terminal.WriteString(NoFilesPresent);
          Terminal.WriteLn;
        END;
      END;
*)
    ELSE
      Terminal.WriteString(filename);
      Terminal.WriteString(" is illegal file name.");
      Terminal.WriteLn;
    END;
  END;

EXCEPTION Files.UseError:
  Files.ResetSys;
  Files.Delete(file);
END Delete.
                                                                      
