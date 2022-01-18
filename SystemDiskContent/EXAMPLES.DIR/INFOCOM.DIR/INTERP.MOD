IMPLEMENTATION MODULE Interp;
FROM SYSTEM IMPORT BYTE, WORD;

FROM GameFile IMPORT Save, Restore;
FROM Support  IMPORT Restart, Quit, Verify, Error, RetValue, Store;
FROM PC       IMPORT Rtn, Rts, Print, PrintRet, Jump;
FROM Print    IMPORT NewLine, ShowStatus, PrintAddr, PrintPAddr;
FROM Objects  IMPORT JumpIn, GetParent, GetSibling, GetChild, InsertObj,
                     RemoveObj, PrintObj, TestAttr, ClearAttr, SetAttr;
FROM Property IMPORT GetPropLen, GetProp, GetPropAddr, GetNextProp;
FROM Variable IMPORT LoadOperand, Mode, Inc, Dec, IncChk, DecChk, Load, Put;
FROM Functs   IMPORT Add, Sub, Mul, Div, Mod, PickRandom, 
                     JumpEqual, JumpLess, JumpGreater, Test, Or, And, Not;
FROM Misc     IMPORT Loadw, Loadb;
IMPORT Stack;

CONST INVALIDOPCODE = "Invalid ZCode : ";

PROCEDURE Execute(opcode, nbParams: CARDINAL; params: ARRAY OF CARDINAL);
VAR oper1, oper2: CARDINAL;
BEGIN
  oper1 := params[0]; oper2 := params[1];
  CASE opcode OF
  |01H: JumpEqual   (nbParams, params)
  |02H: JumpLess    (INTEGER(oper1), INTEGER(oper2))
  |03H: JumpGreater (INTEGER(oper1), INTEGER(oper2))
  |04H: DecChk      (oper1, oper2)
  |05H: IncChk      (oper1, oper2)
  |06H: JumpIn      (oper1, oper2)
  |07H: Test        (BITSET(oper1), BITSET(oper2))
  |08H: Or          (BITSET(oper1), BITSET(oper2))
  |09H: And         (BITSET(oper1), BITSET(oper2))
  |0AH: TestAttr    (oper1, oper2)
  |0BH: SetAttr     (oper1, oper2)
  |0CH: ClearAttr   (oper1, oper2)
  |0DH: Put         (oper1, oper2)
  |0EH: InsertObj   (oper1, oper2)
  |0FH: Loadw       (oper1, oper2)
  |10H: Loadb       (oper1, oper2)
  |11H: GetProp     (oper1, oper2)
  |12H: GetPropAddr (oper1, oper2)
  |13H: GetNextProp (oper1, oper2)
  |14H: Add         (oper1, oper2)
  |15H: Sub         (oper1, oper2)
  |16H: Mul         (oper1, oper2)
  |17H: Div         (oper1, oper2)
  |18H: Mod         (oper1, oper2)
(* 19H..1FH inexistent *)
  |20H: Gosub	    (nbParams, params)
  |21H: Savew       (oper1, oper2, params[2])
  |22H: Saveb       (oper1, oper2, params[2])
  |23H: PutProp     (oper1, oper2, params[2])
  |24H: Sread	    (oper1, oper2)
  |25H: PrintChar   (oper1)
  |26H: PrintNum    (oper1)
  |27H: PickRandom  (oper1)
  |28H: Stack.Push  (oper1)
  |29H: PutVar      (oper1, Stack.Pull())
  |2AH: SplitWindow (oper1)
  |2BH: SetWindow   (oper1)
  |33H: (* OutputStream *)
  |34H: (* InputStream *)
  |35H: SoundEffect (oper1, oper2, params[2], nbParams)
  ELSE Error(INVALIDOPCODE, Opcode)
  END;
END Execute;

PROCEDURE ZeroOperand(opcode: CARDINAL);
BEGIN
  CASE opcode MOD 16 OF
  | 0 : (* rtrue      *) Rtn(TRUE)
  | 1 : (* rfalse     *) Rtn(FALSE)
  | 2 : (* print      *) Print
  | 3 : (* print_ret  *) PrintRet
  | 4 : (* nop        *)
  | 5 : (* save       *) Save
  | 6 : (* restore    *) Restore
  | 7 : (* restart    *) Restart
  | 8 : (* ret_popped *) Rtn(Stack.Pull())
  | 9 : (* pop        *) Stack.Drop
  |10 : (* quit       *) Quit
  |11 : (* new_line   *) NewLine
  |12 : (* show_status*) ShowStatus
  |13 : (* verify     *) Verify
  ELSE Error(INVALIDOPCODE, opcode)
  END;
END ZeroOperand;

PROCEDURE OneOperand(opcode: CARDINAL);
VAR operand: CARDINAL;
BEGIN
  operand := LoadOperand(Mode(opcode DIV 16 MOD 4));
  CASE opcode MOD 16 OF
  | 0 : RetValue  (operand = 0)
  | 1 : GetSibling(operand)
  | 2 : GetChild  (operand)
  | 3 : GetParent (operand)
  | 4 : GetPropLen(operand)
  | 5 : Inc       (operand)
  | 6 : Dec       (operand)
  | 7 : PrintAddr (operand)
  | 9 : RemoveObj (operand)
  |10 : PrintObj  (operand)
  |11 : Rtn       (operand)
  |12 : Jump      (operand)
  |13 : PrintPAddr(operand)
  |14 : Store(Load(operand))
  |15 : Not(BITSET(operand))
  ELSE Error(INVALIDOPCODE, opcode)
  END;
END OneOperand;

PROCEDURE TwoOperands(opcode: CARDINAL);
VAR params: ARRAY [0..1] OF CARDINAL;
BEGIN
  params[0] := LoadOperand(Mode(1 - opcode DIV 64 MOD 2));
  params[1] := LoadOperand(Mode(1 - opcode DIV 32 MOD 2));
  Execute(opcode MOD 32, 2, params)
END TwoOperands;

PROCEDURE VariableOperands(opcode: CARDINAL);
VAR params: ARRAY [0..3] OF CARDINAL;
    nbParams, modes : CARDINAL;
    addrMode : Mode;
BEGIN
  nbParams := 0;
  modes := NextByte();
  addrMode := Mode(modes DIV 64);
  WHILE (nbParams < 4) AND (addrMode # NONE) DO
    params[nbParams] := LoadOperand(addrMode);
    INC(nbParams);
    modes := modes MOD 64 * 4; (* shift left remaining bits *)
    addrMode  := Mode(modes DIV 64);
  END;
  Execute(opcode-0C0H, nbParams, params)
END VariableOperands;

PROCEDURE Interpreter;
VAR opcode: CARDINAL;
BEGIN
  WHILE gameState # QUITGAME DO
    opcode := NextByte();
    IF    opcode < 080H THEN TwoOperands(opcode)
    ELSIF opcode < 0B0H THEN OneOperand (opcode)
    ELSIF opcode < 0C0H THEN ZeroOperand(opcode)
    ELSE                     VariableOperands(opcode)
    END;
  END;
END Interpreter;

END Interp.
