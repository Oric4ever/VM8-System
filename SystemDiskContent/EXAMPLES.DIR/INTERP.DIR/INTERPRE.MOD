IMPLEMENTATION MODULE Interpreter;
FROM SYSTEM IMPORT BYTE, WORD, ADDRESS, ADR, MOVE, FILL, TRANSFER, PROCESS;
FROM STORAGE IMPORT ALLOCATE, DEALLOCATE, FREEMEM, MARK, RELEASE;
FROM Stack  IMPORT Push, Load, DPush, FPush, QPush, Pop, BPop, IPop, DPop, FPop, QPop,
                   Dup, Swap, Top, Drop, DropN, Reserve, ReserveString, PointerPop,
                   NewFrame, ResetFrame;
FROM Instruction IMPORT NextByte, NextSigned, NextWord, LoadNextDouble, LoadString,
                        ProcCall, ExternProcCall1, ExternProcCall2, ExternProcCall3,
                        ProcLeave, Enter, Case, PushPCrelative, instructionPointer,
                        Jump, JumpBackward, AndThen, OrElse, Return;
FROM MiscOp IMPORT CopyBlock, CopyString, ShiftLeft, ShiftRight, StringCompare,
                   DoubleCompare, RealCompare, CardRangeCheck, IntRangeCheck;

IMPORT Local, Global, Indirect, Extern, Array, Extended;
FROM Loader2 IMPORT Call;

EXCEPTION IllegalInstruction, Unimplemented, RangeError;

CONST TRACE = FALSE;

(* $O- don't check overflows except when explicitly required *)
(* $T- don't test array indices *)


PROCEDURE WriteHexByte(i: CARDINAL);
  PROCEDURE WriteHexDigit(i: CARDINAL);
  BEGIN
    IF i>9 THEN WRITE(CHR(i-10+ORD('A'))) ELSE WRITE(CHR(i+ORD('0'))) END;
  END WriteHexDigit;
BEGIN
  WriteHexDigit(i DIV 16);
  WriteHexDigit(i MOD 16);
END WriteHexByte;

PROCEDURE WriteHex(i: CARDINAL);
BEGIN
  WriteHexByte(i DIV 256);
  WriteHexByte(i MOD 256);
END WriteHex;

PROCEDURE LongRealOpcode(opcode: CARDINAL);
VAR res : LONGREAL;
BEGIN
  CASE opcode OF
  | 00H:    Local. LoadQuad (NextSigned())
  | 01H:   Global. LoadQuad (NextByte())
  | 02H: Indirect. LoadQuad (NextByte())
  | 03H:   Extern. LoadQuad (NextByte(), NextByte())
  | 04H:    Local.StoreQuad (NextSigned())
  | 05H:   Global.StoreQuad (NextByte())
  | 06H: Indirect.StoreQuad (NextByte())
  | 07H:   Extern.StoreQuad (NextByte(), NextByte())
  | 08H:    Array. LoadQuad (Pop())
  | 09H:    Array.StoreQuad (QPop(), Pop())
  | 0AH: (* Fonction leave *) res := QPop(); ProcLeave(NextByte()); QPush(res)
  ELSE RAISE IllegalInstruction
  END;
END LongRealOpcode;

PROCEDURE Run;
VAR opcode, op, res, modNum : CARDINAL;
    iop : INTEGER;
    dop, dres: LONGINT;
    fop : REAL;
BEGIN
  REPEAT
    IF TRACE THEN
      WRITE('     TOP='); WriteHex(Top()); WRITELN; WRITELN;
      WRITE('IP='); WriteHex(CARDINAL(instructionPointer))
    END;
    opcode := NextByte();
    IF TRACE THEN WRITE(', OP='); WriteHexByte(opcode); WRITELN; WRITELN END;
    CASE opcode OF
    |  00H : RAISE IllegalInstruction
    |  01H : (* Raise exception *) RAISE Unimplemented,"Exceptions aren't implemented"
    |  02H :   Global.LoadProcAddr(NextByte())
    |  03H
       ..
       07H :    Local.LoadParam (opcode MOD 8)
    |  08H :    Local.LoadDouble(NextSigned())
    |  09H :   Global.LoadDouble(NextByte())
    |  0AH : Indirect.LoadDouble(NextByte())
    |  0BH :   Extern.LoadDouble(NextByte(), NextByte())
    |  0CH :   Extern.Load2     (NextByte())
    |  0DH :    Array.LoadByte  (Pop())
    |  0EH :    Array.LoadWord  (Pop())
    |  0FH :    Array.LoadDouble(Pop())

    |  10H :    Local.LoadUpperFrame(1)
    |  11H :    Local.LoadUpperFrame(NextByte())
    |  12H : LongRealOpcode(NextByte())
    |  13H
       ..
       17H :    Local.StoreParam (opcode MOD 8)
    |  18H :    Local.StoreDouble(NextSigned())
    |  19H :   Global.StoreDouble(NextByte())
    |  1AH : Indirect.StoreDouble(NextByte())
    |  1BH :   Extern.StoreDouble(NextByte(), NextByte())
    |  1CH :   Extern.Store2     (NextByte())
    |  1DH :    Array.StoreByte  ( Pop(), Pop())
    |  1EH :    Array.StoreWord  ( Pop(), Pop())
    |  1FH :    Array.StoreDouble(DPop(), Pop())

    |  20H : Dup
    |  21H : Swap
    |  22H
       ..
       2BH :    Local.Load(-INTEGER(opcode MOD 16))
    |  2CH :    Local.Load(NextSigned())
    |  2DH :   Global.Load(NextByte())
    |  2EH : Indirect.Load(NextByte())
    |  2FH :   Extern.Load(NextByte(), NextByte())

    |  30H : CopyBlock
    |  31H : CopyString
    |  32H
       ..
       3BH :    Local.Store(-INTEGER(opcode MOD 16))
    |  3CH :    Local.Store(NextSigned())
    |  3DH :   Global.Store(NextByte())
    |  3EH : Indirect.Store(NextByte())
    |  3FH :   Extern.Store(NextByte(), NextByte())

    |  40H : Extended.Opcode(NextByte())
    |  41H : Indirect.LoadDouble(0)
    |  42H
       ..
       4FH :   Global.Load (opcode MOD 16)

    |  50H : (* HALT *) RETURN (* processes not implemented *)
    |  51H : Indirect.StoreDouble(0)
    |  52H
       ..
       5FH :   Global.Store(opcode MOD 16)

    |  60H
       ..
       6FH : Indirect.Load (opcode MOD 16)

    |  70H
       ..
       7FH : Indirect.Store(opcode MOD 16)

    |  80H :    Local.LoadAddr(NextSigned())
    |  81H :   Global.LoadAddr(NextByte())
    |  82H : Indirect.LoadAddr(NextByte())
    |  83H :   Extern.LoadAddr(NextByte(), NextByte())
    |  84H : ProcLeave(NextByte())
    |  85H : (* Fct leave      *)  res := Pop(); ProcLeave(NextByte()); Push(res)
    |  86H : (* Long fct leave *) dres :=DPop(); ProcLeave(NextByte()); DPush(dres)
    |  87H : (* Z80 Assembly code *) RAISE Unimplemented,"ASM not implemented"
    |  88H
       ..
       8BH : ProcLeave(opcode - 8)
    |  8CH : LoadString(NextByte())
    |  8DH : Load(NextByte())
    |  8EH : Load(NextWord())
    |  8FH : LoadNextDouble

    |  90H
       ..
       9FH : Load(opcode MOD 16)

    | 0A0H : (* Equal        *) op := Pop(); Push( Pop() =  op )
    | 0A1H : (* NotEqual     *) op := Pop(); Push( Pop() #  op )
    | 0A2H : (* Before       *) op := Pop(); Push( Pop() <  op )
    | 0A3H : (* After        *) op := Pop(); Push( Pop() >  op )
    | 0A4H : (* BeforeOrSame *) op := Pop(); Push( Pop() <= op )
    | 0A5H : (* AfterOrSame  *) op := Pop(); Push( Pop() >= op )
    | 0A6H : (* Add          *) op := Pop(); Push( Pop() + op )
    | 0A7H : (* Sub          *) op := Pop(); Push( Pop() - op )
    | 0A8H : (* Mul          *) op := Pop(); Push( Pop() * op )
    | 0A9H : (* Div          *) op := Pop(); Push( Pop() DIV op)
    | 0AAH : (* Mod          *) op := Pop(); Push( Pop() MOD op)
    | 0ABH : (* Equal0       *) Push( Pop() = 0 )
    | 0ACH : (* Increment    *) Push( Pop() + 1 )
    | 0ADH : (* Decrement    *) Push( Pop() - 1 )
    | 0AEH : (* Increment by *) Push( Pop() + NextByte() )
    | 0AFH : (* Decrement by *) Push( Pop() - NextByte() )

    | 0B0H : (* Shift left   *) Push( ShiftLeft (Pop(), NextByte()) )
    | 0B1H : (* Shift right  *) Push( ShiftRight(Pop(), NextByte()) )
    | 0B2H : (* Less than    *) iop := IPop(); Push( IPop() <  iop )
    | 0B3H : (* Greater than *) iop := IPop(); Push( IPop() >  iop )
    | 0B4H : (* Less or eq   *) iop := IPop(); Push( IPop() <= iop )
    | 0B5H : (* Greater or eq*) iop := IPop(); Push( IPop() >= iop )
    | 0B6H : (* Not          *) Push( NOT(BPop()) )
    | 0B7H : (* Complement   *) Push( 0FFFFH - Pop() )
    | 0B8H : (* Signed mul   *) iop := IPop(); Push( IPop() * iop )
    | 0B9H : (* Signed div   *) iop := IPop(); Push( IPop() DIV iop )
    | 0BAH : (* Long to card *) Push( CARD( DPop() ) )
    | 0BBH : (* Long to int  *) Push( INT(  DPop() ) )
    | 0BCH : (* Abs          *) Push( ABS( IPop() ) )
    | 0BDH : (* Int to long  *) DPush( LONG( IPop() ) )
    | 0BEH : (* Long to float*) FPush( FLOAT( DPop() ) )
    | 0BFH : (* Float to long*) DPush( LONG( FPop() ) )

    | 0C0H : (* checked add  *) op := Pop(); (* $O+ *) Push( Pop() + op ) (* $O- *)
    | 0C1H : (* checked sub  *) op := Pop(); (* $O+ *) Push( Pop() - op ) (* $O- *)
    | 0C2H : (* checked mul  *) op := Pop(); (* $O+ *) Push( Pop() * op ) (* $O- *)
    | 0C3H : (* BDOS call    *) RAISE Unimplemented,"SYSTEM not implemented"
    | 0C4H : (* string comp  *) StringCompare
    | 0C5H : (* long compare *) DoubleCompare
    | 0C6H : (* long add     *) dop := DPop(); DPush( DPop() + dop )
    | 0C7H : (* long sub     *) dop := DPop(); DPush( DPop() - dop )
    | 0C8H : (* long mul     *) dop := DPop(); DPush( DPop() * dop )
    | 0C9H : (* long div     *) dop := DPop(); DPush( DPop() DIV dop )
    | 0CAH : (* long mod     *) dop := DPop(); DPush( DPop() MOD dop )
    | 0CBH : (* Not zero     *) Push( Pop() # 0 )
    | 0CCH : (* long abs     *) DPush( ABS( DPop() ) )
    | 0CDH : (* Case         *) Case( Pop() )
    | 0CEH : (* Return       *) Return
    | 0CFH : (* PushPCrelat  *) PushPCrelative(NextWord())

    | 0D0H : (* checked int+ *) iop := IPop(); (* $O+ *) Push( IPop() + iop ) (* $O- *)
    | 0D1H : (* checked int- *) iop := IPop(); (* $O+ *) Push( IPop() - iop ) (* $O- *)
    | 0D2H : (* stack reserv *) Push( Reserve( Pop() ) )
    | 0D3H : (* reserv string*) ReserveString
    | 0D4H : (* enter proc   *) Enter(NextByte())
    | 0D5H : (* real compare *) RealCompare
    | 0D6H : (* real add     *) fop := FPop(); FPush( FPop() + fop )
    | 0D7H : (* real sub     *) fop := FPop(); FPush( FPop() - fop )
    | 0D8H : (* real mul     *) fop := FPop(); FPush( FPop() * fop )
    | 0D9H : (* real div     *) fop := FPop(); FPush( FPop() / fop )
    | 0DAH : (* range check  *) CardRangeCheck
    | 0DBH : (* int range chk*) IntRangeCheck
    | 0DCH : (* limit check  *) op := Pop(); IF Top() > op THEN RAISE RangeError END
    | 0DDH : (* positive chk *) IF INTEGER(Top()) < 0 THEN RAISE RangeError END
    | 0DEH : (* AND THEN     *) AndThen(NextByte())
    | 0DFH : (* OR ELSE      *) OrElse(NextByte())

    | 0E0H : (* Jump         *) Jump(NextWord()-1)
    | 0E1H : (* Cond Jump    *) op := NextWord()-1; IF NOT BPop() THEN Jump(op) END;
    | 0E2H : (* Jump forward *) Jump(NextByte())
    | 0E3H : (* Cond Jp forwd*) op := NextByte(); IF NOT BPop() THEN Jump(op) END;
    | 0E4H : (* Jump backwd  *) JumpBackward(NextByte())
    | 0E5H : (* Cond Jp back *) op := NextByte(); IF NOT BPop() THEN JumpBackward(op) END;
    | 0E6H : (* bitwise OR   *) op := Pop(); Push( BITSET(Pop()) + BITSET(op) )
    | 0E7H : (* bitwise IN   *) op := Pop(); Push( Pop() IN BITSET(op) )
    | 0E8H : (* bitwise AND  *) op := Pop(); Push( BITSET(Pop()) * BITSET(op) )
    | 0E9H : (* bitwise XOR  *) op := Pop(); Push( BITSET(Pop()) / BITSET(op) )
    | 0EAH : (* power 2      *) Push( ShiftLeft(1, Pop()) )
    | 0EBH : (* extern call  *) ExternProcCall1(Pop(), Pop())
    | 0ECH : (* nested call  *) ProcCall(NextByte(), Local.framePointer)
    | 0EDH : (* proc call    *) ProcCall(NextByte(), NIL)
    | 0EEH : (* call frame   *) ProcCall(NextByte(), Pop())
    | 0EFH : (* extern call  *) ExternProcCall3(NextByte(), NextByte())

    | 0F0H : (* extern call  *) ExternProcCall2(NextByte())
    | 0F1H
       ..
      0FFH : (* proc call    *) ProcCall(opcode MOD 16, NIL)
    END;
  UNTIL Global.globalPointer=ADDRESS(1);
END Run;

END Interpreter.
