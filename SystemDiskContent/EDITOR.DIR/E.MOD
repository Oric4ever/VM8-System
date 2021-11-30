MODULE ED;
FROM SYSTEM  IMPORT ADDRESS;
FROM STORAGE IMPORT ALLOCATE;
FROM Editor  IMPORT editPosition, Edit;
FROM Texts   IMPORT ReadString;
IMPORT FATDIR, Texts, ComLine, ShellRes;
VAR filename: ARRAY [0..19] OF CHAR;
    dummy: ADDRESS;
BEGIN
  FATDIR.SaveCurrentDir;
  ReadString(ComLine.commandLine, filename);
  IF filename[0] <> 0C THEN ComLine.inName := filename
  ELSIF ShellRes.tabNames[ShellRes.currentTab][0] <> 0C THEN
    FATDIR.SetCurrentDir( ShellRes.tabDirs [ShellRes.currentTab] );
    ComLine.inName     := ShellRes.tabNames[ShellRes.currentTab]
  ELSE
    ComLine.PromptFor("File to edit: ", ComLine.inName)
  END;

  editPosition := 0;
  Edit;
  FATDIR.BackToSavedDir;
END ED.