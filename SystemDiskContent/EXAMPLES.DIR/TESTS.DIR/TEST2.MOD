MODULE TEST2;
IMPORT TEST1;
IMPORT Terminal;
IMPORT KERNEL2;
BEGIN
  Terminal.WriteString('TEST2 started');
  Terminal.WriteLn;
  TEST1.PROC1;
  Terminal.WriteString('returned successfully to TEST2')
END TEST2.                                    