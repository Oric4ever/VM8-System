MODULE Options;
IMPORT Terminal;
FROM Scanner IMPORT compilerOptions;

CONST CTRLC = 03C; BackSpace = 10C; TAB = 11C; LF = 12C; CR = 15C;
      XOFF = 23C; CTRLX = 30C; EOT = 32C; ESC = 033C; DEL = 177C;
CONST OPTIONS = "LNXTOUQ[";
CONST FIRSTOPTION = 'L';

PROCEDURE GetChoice(prompt: CHAR; commands : ARRAY OF CHAR): CARDINAL;
VAR i : CARDINAL;
    ch : CHAR;
BEGIN
  Terminal.WriteChar(prompt);
  Terminal.WriteChar(' ');
  Terminal.ReadChar(ch);
  ch := CAP(ch);
  FOR i := 0 TO HIGH(commands) DO
    IF ch = commands[i] THEN RETURN i + 1 END;
  END;
  RETURN 0
END GetChoice;

PROCEDURE WriteCommandItem(string: ARRAY OF CHAR);
VAR i: CARDINAL;
BEGIN
  Terminal.Highlight;
  Terminal.WriteChar(string[0]);
  Terminal.Normal;
  i := 0; REPEAT INC(i); Terminal.WriteChar(string[i]) UNTIL i = HIGH(string);
END WriteCommandItem;

PROCEDURE ToggleOption(optionNum: CARDINAL; optionLetters: ARRAY OF CHAR);
VAR option: CARDINAL;
BEGIN
  option := ORD(optionLetters[optionNum]) - ORD(FIRSTOPTION);
  IF option IN compilerOptions
  THEN EXCL(compilerOptions, option)
  ELSE INCL(compilerOptions, option)
  END
END ToggleOption;

PROCEDURE ShowOptionStatus(letter: CHAR);
VAR option: CARDINAL;
BEGIN
  option := ORD(letter) - ORD(FIRSTOPTION);
  Terminal.WriteString(" (O");
  IF option IN compilerOptions
  THEN Terminal.WriteString("N ")
  ELSE Terminal.WriteString("FF");
  END;
  Terminal.WriteString(")  ");
END ShowOptionStatus;

VAR command: CARDINAL;

BEGIN
  REPEAT
    Terminal.ClearScreen;
    Terminal.WriteString("Compiler options: ");
    Terminal.WriteLn;
    Terminal.WriteLn;

    WriteCommandItem("List");         ShowOptionStatus('L'); Terminal.WriteChar(' ');
    WriteCommandItem("Native (Z80)"); ShowOptionStatus('N'); Terminal.WriteChar(' ');
    WriteCommandItem("Xtensions  ");  ShowOptionStatus('X'); Terminal.WriteLn;

    WriteCommandItem("Test");         ShowOptionStatus('T'); Terminal.WriteChar(' ');
    WriteCommandItem("Overflow    "); ShowOptionStatus('O'); Terminal.WriteChar(' ');
    WriteCommandItem("Upper=lower");  ShowOptionStatus('U'); Terminal.WriteLn;

    Terminal.WriteLn; Terminal.WriteString("show ");
    WriteCommandItem("Quantity of free memory");      ShowOptionStatus('Q'); Terminal.WriteLn;
    WriteCommandItem("[ remove procedure names    "); ShowOptionStatus('['); Terminal.WriteLn;
    Terminal.WriteLn;

    command := GetChoice('>', OPTIONS);
    IF command-1 < 8 THEN ToggleOption(command-1, OPTIONS) END;
  UNTIL (command = 0);
  Terminal.WriteString("Options saved.");
  Terminal.WriteLn
END Options.