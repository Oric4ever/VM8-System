IMPLEMENTATION MODULE Variable;
IMPORT Stack;
FROM PC IMPORT NextByte, NextWord;
FROM Support  IMPORT ZtoWord, RetValue;
FROM GameFile IMPORT globalPtr;

VAR localVars   : ARRAY [1..255] OF CARDINAL; (* TODO: what happens when calling subroutines ? *)
    nbLocalVars : CARDINAL;

PROCEDURE Load(index: CARDINAL): CARDINAL;
BEGIN
  IF index = 0           THEN RETURN Stack.GetTop()        END;
  IF index < nbLocalVars THEN RETURN Stack.GetLocal(index) END;
  RETURN ZtoWord( globalPtr^[index-nbLocalVars] )
END Load;

PROCEDURE Put(index: CARDINAL; value: WORD);
BEGIN
  IF    index = 0           THEN Stack.SetTop(value)
  ELSIF index < nbLocalVars THEN Stack.SetLocal(index,value)
  ELSE  globalPtr^[index-nbLocalVars] := ZtoWord(CARDINAL(value))
  END;
END Put;

PROCEDURE Store(value: WORD);
VAR index: CARDINAL;
BEGIN
  index := NextByte();
  IF index = 0 THEN Stack.Push(value) ELSE Put(index, value) END;
END Store;

PROCEDURE Inc(index: CARDINAL);
BEGIN
  Put(index, CARDINAL(Load(index)) + 1)
END Inc;

PROCEDURE Dec(index: CARDINAL);
BEGIN
  Put(index, CARDINAL(Load(index)) - 1)
END Dec;

PROCEDURE IncChk(index: CARDINAL; threshold: INTEGER);
VAR value: INTEGER;
BEGIN
  value := Load(index);
  INC(value);
  Put(index, value);
  RetValue( value > threshold )
END IncChk;

PROCEDURE DecChk(index: CARDINAL; threshold: INTEGER);
VAR value: INTEGER;
BEGIN
  value := Load(index);
  DEC(value);
  Put(index, value);
  RetValue( value < threshold )
END DecChk;

PROCEDURE LoadOperand(mode: Mode): CARDINAL;
VAR index: CARDINAL;
BEGIN
  IF mode = IMMWORD THEN RETURN NextWord() END;
  IF mode = IMMBYTE THEN RETURN NextByte() END;

  (* mode = VARIABLE *)
  index := NextByte();
  IF index = 0 THEN RETURN Stack.Pull() END;
  RETURN Load(index)
END LoadOperand;

END Variable.