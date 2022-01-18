MODULE ED;
FROM Editor  IMPORT editPosition, Edit;
FROM Terminal IMPORT WriteString, WriteLn;
IMPORT ComLine;
BEGIN
  IF ComLine.inName[0] = 0C THEN
    ComLine.PromptFor("File to edit: ", ComLine.inName)
  ELSE
    WriteString(ComLine.inName);
    WriteLn;
  END;
  editPosition := 0;
  Edit;
END ED.