MODULE MemSize0;
FROM STORAGE  IMPORT FREEMEM;

(*
  Displays memory size available to normally loaded modules.
  
  The Kernel plus a resident part of the shell is in memory, along with a number
  of modules.
*)

BEGIN
  WRITELN(FREEMEM(), ' bytes free.')
END MemSize0.