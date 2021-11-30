MODULE KERNEL4;
FROM SYSTEM   IMPORT WORD, ADR, ADDRESS;
IMPORT EXCEPTS;
FROM Terminal IMPORT WriteString, WriteLn;

PROCEDURE Halt;
BEGIN
  WriteLn;
  WriteString('Halted.');
  LOOP END;
END Halt;

TYPE
     BYTE       = [0..255];
     FLAGS      = (OVERLAY, Z80, INIT);
     ModDescPtr = POINTER TO ModuleDesc;
     ModuleDesc = RECORD
                    procs: ARRAY [0..31] OF ADDRESS;
                    link : ModDescPtr;
                    name : ARRAY [0..7] OF CHAR;
                    loadAddr,checksum,endAddr: ADDRESS;
                    CASE : BOOLEAN OF
                    | TRUE : flags : SET OF FLAGS;
                    | FALSE: bytes : ARRAY [0..1] OF BYTE;
                    END;
                    global1 : CARDINAL;
                  END;
     ProcAddr = RECORD
                  CASE : BOOLEAN OF
                  | TRUE : modbase, procnum: ADDRESS;
                  | FALSE: proc : PROC;
                  END
                END;

VAR
    firstModule    [030CH]: ModDescPtr;
    modulePtr : ModDescPtr;
    proc      : ProcAddr;

BEGIN
  (* init the modules that requires it. *)
  modulePtr  := firstModule;
  WHILE modulePtr <> NIL DO
    proc.modbase := ADR(modulePtr^.flags); (* procnum is 0 *)
    proc.proc();  (* call the module's INIT *)
    (* Argh! the module's INIT ends with an implicit HALT (opcode 50),
             which should end the current's process *)
    modulePtr := modulePtr^.link;
  END; (* normally, the main module's INIT is an endless loop (eg. SHELLRES) *)
  Halt;
END KERNEL4.