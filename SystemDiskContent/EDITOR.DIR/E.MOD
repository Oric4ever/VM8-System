MODULE ED;
FROM SYSTEM  IMPORT ADDRESS;
FROM STORAGE IMPORT ALLOCATE;
FROM Editor  IMPORT editPosition, Edit;
FROM Texts   IMPORT ReadString;
IMPORT FATDIR, Texts, ComLine;
VAR filename: ARRAY [0..19] OF CHAR;
    dummy: ADDRESS;
BEGIN
  FATDIR.SaveCurrentDir;
  ReadString(ComLine.commandLine, filename);
  IF filename[0] <> 0C THEN ComLine.inName := filename
  ELSIF ComLine.tabNames[ComLine.currentTab][0] <> 0C THEN
    FATDIR.SetCurrentDir( ComLine.tabDirs [ComLine.currentTab] );
    ComLine.inName     := ComLine.tabNames[ComLine.currentTab]
  ELSE
    ComLine.PromptFor("File to edit: ", ComLine.inName)
  END;

  editPosition := 0;
  Edit;
  FATDIR.BackToSavedDir;
END ED.
