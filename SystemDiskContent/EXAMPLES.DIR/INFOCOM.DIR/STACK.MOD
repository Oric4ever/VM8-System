IMPLEMENTATION MODULE Stack;
FROM SYSTEM IMPORT ADDRESS;

VAR stack: ARRAY [0..255] OF WORD;
    index: CARDINAL; (* index of stack top *)
    frameIndex: CARDINAL; (* index of current frame *)

PROCEDURE Drop;               BEGIN DEC(index)                    END Drop;
PROCEDURE GetTop(): CARDINAL; BEGIN RETURN CARDINAL(stack[index]) END GetTop;
PROCEDURE SetTop(w: WORD);    BEGIN stack[index] := w             END SetTop;

PROCEDURE Push(w: WORD);
BEGIN 
  INC(index); stack[index] := w 
END Push;

PROCEDURE Pull(): CARDINAL;
VAR w: CARDINAL;
BEGIN
  w := CARDINAL(stack[index]);  DEC(index);  RETURN w
END Pull;

PROCEDURE BuildFrame(nbVars: CARDINAL);
BEGIN
  Push(frameIndex);  frameIndex := index;  INC(index, nbVars);
END BuildFrame;

PROCEDURE DeleteFrame;
BEGIN
  index := frameIndex;  frameIndex := Pull();
END DeleteFrame;

PROCEDURE GetLocal(varIndex: CARDINAL): CARDINAL;
BEGIN
  RETURN CARDINAL( stack[frameIndex + varIndex] )
END GetLocal;

PROCEDURE SetLocal(varIndex: CARDINAL; value: WORD);
BEGIN
  stack[frameIndex + varIndex] := value
END SetLocal;

END Stack.