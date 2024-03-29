MODULE Copy;
IMPORT Terminal, Texts, Files, ComLine, FileName;
FROM FileName IMPORT FileNameType, CheckFileName, BuildStdFileName;
FROM SYSTEM IMPORT ADDRESS;
FROM STORAGE IMPORT ALLOCATE, MARK, RELEASE, FREEMEM;

TYPE Name = ARRAY [0..15] OF CHAR;

  PROCEDURE CopyFile(srcName, destName: Name): BOOLEAN;
  VAR
      buffer, heapMark: ADDRESS;
      tmpName: Name;
      srcFile, destFile: Files.FILE;
      bufSize, readBytes: CARDINAL;
  BEGIN
    IF CheckFileName(destName) = NONAME THEN
      BuildStdFileName(destName, "", FALSE);
      BuildStdFileName(srcName, "", FALSE);
      tmpName := destName;
      destName := srcName;
    END;
    tmpName := destName;
    BuildStdFileName(tmpName, "$$$", TRUE);
    MARK(heapMark);
    Files.Create(destFile, tmpName);
    IF Files.Open(srcFile, srcName) THEN
      bufSize := FREEMEM() - 1000;
      ALLOCATE(buffer, bufSize);
      Files.NoTrailer(srcFile);
      Files.NoTrailer(destFile);
      REPEAT
        readBytes := Files.ReadBytes(srcFile, buffer, bufSize);
        Files.WriteBytes(destFile, buffer, readBytes);
      UNTIL readBytes < bufSize;
      Files.Close(srcFile);
      Files.Rename(destFile, destName);
    ELSE
      Files.Delete(destFile);
      Terminal.WriteString(srcName);
      Terminal.WriteString(" not found.");
      Terminal.WriteLn;
    END;
    RELEASE(heapMark);
    RETURN TRUE;

  EXCEPTION Files.DiskFull:
    Terminal.WriteString("WRITE ERROR: DISK FULL"); 
    Terminal.WriteLn;
    Files.Delete(destFile);
    RELEASE(heapMark);
    RETURN FALSE;
  END CopyFile;

  PROCEDURE IllegalFileName(name: Name);
  BEGIN
    Terminal.WriteString(name);
    Terminal.WriteString(" is illegal file name.");
    Terminal.WriteLn;
  END IllegalFileName;

VAR
    filename1, filename2: Name;
    fileCheck1, fileCheck2: FileNameType;
    success: BOOLEAN;
    char : CHAR;
BEGIN
  Texts.ReadString(ComLine.commandLine, filename1);
  Texts.ReadString(ComLine.commandLine, filename2);
  IF filename1[0] = 0C THEN
    Terminal.WriteString("Copy from: ");
    Terminal.ReadLine(filename1);
  END;
  IF filename1[0] <> 0C THEN
    IF filename2[0] = 0C THEN
      Terminal.WriteString("Copy to  : ");
      Terminal.ReadLine(filename2);
    END;
    fileCheck1 := CheckFileName(filename1);
    fileCheck2 := CheckFileName(filename2);
    IF (fileCheck2 = WILDCARD) OR (fileCheck2 = INVALID) THEN
      IllegalFileName(filename2)
    ELSIF (fileCheck1 = NONAME) OR (fileCheck1 = INVALID) THEN
      IllegalFileName(filename1)
    ELSIF fileCheck1 = WILDCARD THEN
      Terminal.WriteString("TODO: implement wildcard copy");
      Terminal.WriteLn;
(*
      IF fileCheck2 = NORMAL THEN
        Terminal.WriteString("TODO: implement wildcard copy");
        Terminal.WriteLn;
      ELSE
        proc23(filename1);
        global15 := FALSE;
        IF global12 <> 0 THEN
          local6 := 0;
          REPEAT
            INC(local6);
            local9 := ADR(global11[local6]);
            Terminal.WriteString("Copying ");
            Terminal.WriteString(local9^.fullname);
            Terminal.WriteLn;
            filename1 := local9^.fullname;
            success := CopyFile(filename1, filename2);
          UNTIL (NOT success) OR (local6 >= global12);
        ELSE
          Terminal.WriteString(NoFilesPresent);
          Terminal.WriteLn;
        END;
      END;
*)
    ELSE
      BuildStdFileName(filename1, "", FALSE);
      success := CopyFile(filename1, filename2);
    END;
  END;
END Copy.
