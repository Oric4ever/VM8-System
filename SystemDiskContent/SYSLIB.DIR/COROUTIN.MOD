IMPLEMENTATION MODULE Coroutines;
FROM SYSTEM IMPORT NEWPROCESS, TRANSFER, ADDRESS;
FROM STORAGE IMPORT ALLOCATE;

PROCEDURE Init(body: PROC; wrkSize: CARDINAL; VAR corout: PROCESS);
VAR wrkSpace: ADDRESS;
BEGIN
  ALLOCATE(wrkSpace, wrkSize);
  NEWPROCESS(body, wrkSpace, wrkSize, corout);
END Init;

PROCEDURE Transfer(VAR from, to: PROCESS);
BEGIN
  TRANSFER(from, to)
END Transfer;

END Coroutines.