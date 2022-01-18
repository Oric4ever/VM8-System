IMPLEMENTATION MODULE Support;
FROM SYSTEM   IMPORT BYTE, ADDRESS;
FROM PC       IMPORT Jump, Rtn, NextByte;
IMPORT Stack;
FROM Variable IMPORT PutVar;

PROCEDURE ZtoWord(w: CARDINAL): CARDINAL;
BEGIN
  RETURN (w MOD 256) * 256 + (w DIV 256)
END ZtoWord;

PROCEDURE RetValue(condition: BOOLEAN);
VAR offset: CARDINAL;
BEGIN
  offset := ORD( NextByte() );
  IF offset >= 80H THEN DEC(offset, 128) ELSE condition := NOT condition END;
  IF offset >= 40H THEN DEC(offset, 64)
  ELSE
    offset := offset * 256 + ORD(NextByte());
    IF offset >= 2000H THEN DEC(offset, 4000H) END;
  END;
  IF condition THEN
    IF    offset = 0 THEN Rtn(FALSE)
    ELSIF offset = 1 THEN Rtn(TRUE)
    ELSE  Jump(offset)
    END;
  END;
END RetValue;

PROCEDURE Store(value: WORD);
VAR varIndex: CARDINAL;
BEGIN
  varIndex := NextByte();
  IF varIndex = 0 THEN Stack.Push(value) ELSE PutVar(varIndex, value) END;
END Store;

PROCEDURE ChangeStatus;
BEGIN
END ChangeStatus;

PROCEDURE Restart;
BEGIN
END Restart;

PROCEDURE Quit;
BEGIN
END Quit;

PROCEDURE DoVerify(): BOOLEAN;
BEGIN
END DoVerify;

PROCEDURE Verify;
BEGIN
END Verify;

PROCEDURE Error(buffer: ARRAY OF CHAR; value: CARDINAL);
BEGIN
END Error;

PROCEDURE AskQuit;
BEGIN
END AskQuit;

END Support.