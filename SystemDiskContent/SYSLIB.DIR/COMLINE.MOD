IMPLEMENTATION MODULE ComLine;
FROM Terminal IMPORT WriteString, ReadLine;
IMPORT Texts;

PROCEDURE Chain(prog,in,out: ARRAY OF CHAR);
BEGIN
  progName := prog;
    inName := in;
   outName := out;
  execute  := 1;
END Chain;

EXCEPTION NoInputFile;

PROCEDURE RedirectInput;
BEGIN
  IF NOT Texts.OpenText(Texts.input, inName) THEN
    RAISE NoInputFile
  END;
END RedirectInput;

PROCEDURE RedirectOutput;
BEGIN
  Texts.CreateText(Texts.output, outName)
END RedirectOutput;

PROCEDURE PromptFor(prompt:ARRAY OF CHAR; VAR s:ARRAY OF CHAR);
VAR i: CARDINAL;
BEGIN
  Texts.ReadString(commandLine, s);
  IF s[0] = 0C THEN
    WriteString(prompt); ReadLine(s);
    i := 0; REPEAT s[i] := CAP(s[i]); INC(i) UNTIL i = HIGH(s);
  END
END PromptFor;

END ComLine.