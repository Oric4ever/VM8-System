MODULE Finalize;
(* Finalizes the build of a system:
    - Allocates the global arrays of all modules
    - Selects the Kernel module (its INIT will be executed first)
    - initializes the pointers to KERNEL module and EXCEPTIONS module
*)
FROM SYSTEM IMPORT ADR, BYTE, ADDRESS, FILL, TSIZE;
IMPORT Files, Strings;
FROM ComLine IMPORT PromptFor;

TYPE
     FCB        = ARRAY [0..35] OF BYTE;
     FLAGS      = (OVERLAY, Z80, INIT);
     ModulePtr  = POINTER TO Module;
     Module     = RECORD
                    flags  : SET OF FLAGS;
                    global1: CARDINAL;
                  END;
     ModDescPtr  = POINTER TO ModuleDesc;
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
     ProcDesc = RECORD
                  CASE : BOOLEAN OF
                  | TRUE : modbase, procnum: ADDRESS;
                  | FALSE: proc : PROC;
                  END
                END;
     PTR = POINTER TO CARDINAL;

VAR kernelName, name: ARRAY [0..7] OF CHAR;
    SYSname, BINname: ARRAY [0..11] OF CHAR;
    LNKfile, SYSfile: Files.FILE;
    readSize, allocAddr, moduleAddr, kernelBase, exceptionsBase: CARDINAL;
    varCount, varSize, i: CARDINAL;
    modulePtr: ModDescPtr;
    image : ARRAY [0100H..40000] OF BYTE;
    globalVarsPtr : POINTER TO ARRAY [0..255] OF CARDINAL;

PROCEDURE GetMem(addr: CARDINAL): CARDINAL;
VAR ptr: PTR;
BEGIN
  ptr := ADR(image[addr]); RETURN ptr^
END GetMem;

PROCEDURE SetMem(addr: CARDINAL; value: CARDINAL);
VAR ptr: PTR;
BEGIN
  ptr := ADR(image[addr]); ptr^ := value
END SetMem;

PROCEDURE IncMem(addr: CARDINAL; value: CARDINAL);
VAR ptr: PTR;
BEGIN
  ptr := ADR(image[addr]); INC(ptr^, value)
END IncMem;

BEGIN
  (* load the SYS file *)
  PromptFor('Linked file (without .SYS extension): ',name);
  SYSname := name; Strings.Append('.SYS', SYSname);
  BINname := name; Strings.Append('.BIN', BINname);

  IF NOT Files.Open(LNKfile, SYSname) THEN WRITE("Cannot find ",SYSname); HALT END;
  readSize := Files.ReadBytes(LNKfile, ADR(image), SIZE(image));
  Files.Close(LNKfile);

(*
  WRITE('Name of Kernel module: '); READLN(kernelName);
  FOR i:=0 TO 7 DO kernelName[i] := CAP(kernelName[i]) END;
*)
  allocAddr := GetMem(0316H) - 60;
  moduleAddr := GetMem(030CH); (* start of module chain *)

  (* allocate the RECORDs and ARRAYs of all modules.  *)
  WHILE moduleAddr <> 0 DO
    modulePtr := ADR(image[moduleAddr]);
    IF modulePtr^.name = "EXCEPTS" THEN
      WRITELN('Exceptions module found.');
      exceptionsBase := moduleAddr + 80
  (*
    ELSIF modulePtr^.name = kernelName THEN
      WRITELN('Kernel module found.');
      kernelBase := moduleAddr + 80;
      EXCL(modulePtr^.flags, INIT); (* prevents double initialization of kernel *)
  *)
    END;

    WRITELN('Allocating ',modulePtr^.name,' data.');
    varCount := ORD(modulePtr^.bytes[1]);
    globalVarsPtr := ADDRESS(modulePtr) + TSIZE(ModuleDesc);
    WHILE varCount <> 0 DO
      DEC(varCount);
      varSize := globalVarsPtr^[varCount];
      IF varSize <> 0 THEN
        FILL(ADR(image[allocAddr]), varSize, 0);
        globalVarsPtr^[varCount] := allocAddr;
        allocAddr := allocAddr + varSize;
      END;
    END;
    moduleAddr := CARDINAL(modulePtr^.link);
  END;

  (* copy the module chain start to page 1 *)
  SetMem(010CH, GetMem(030CH));
  (* update the stack limit *)
  SetMem(0316H, allocAddr + 60);
  (* set the Kernel and Exceptions module bases *)
  (* SetMem(0312H, kernelBase); *)
  SetMem(0120H, exceptionsBase);

  (* finally write the BIN file *)
  Files.Create(SYSfile, BINname);
  Files.WriteBytes(SYSfile, ADR(image), allocAddr-0100H);
  Files.Close(SYSfile);
END Finalize.