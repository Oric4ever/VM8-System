MODULE MemSize2;
FROM STORAGE  IMPORT FREEMEM;
FROM Terminal IMPORT WriteChar, WriteString, WriteLn;

(*
   Link as a system with 
   
   LINK MemSize2
   Output: memsize2.sys
   
   Then FINALIZE:
   Name:
   Name of Kernel module:
*)

PROCEDURE WriteCard(val: CARDINAL);
BEGIN
  IF val >= 10 THEN WriteCard(val DIV 10) END;
  WriteChar(CHR(val MOD 10 + ORD('0')))
END WriteCard;

BEGIN
  WriteCard(FREEMEM()); WriteString(' bytes free.'); WriteLn;
  LOOP END; (* loop forever *)
END MemSize2.
