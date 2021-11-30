MODULE ED;
FROM Editor  IMPORT editPosition, Edit;
IMPORT ComLine;
BEGIN
  IF ComLine.inName[0] = 0C THEN
    ComLine.PromptFor("File to edit: ", ComLine.inName)
  END;
  editPosition := 0;
  Edit;
END ED.