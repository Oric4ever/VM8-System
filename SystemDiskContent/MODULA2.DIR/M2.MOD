MODULE M2;
FROM Scanner IMPORT proc30;
FROM ComLine IMPORT commandLine, inName, PromptFor;
BEGIN
  PromptFor("File to compile: ", inName);
  proc30;
EXCEPTION
  ELSE
END M2.