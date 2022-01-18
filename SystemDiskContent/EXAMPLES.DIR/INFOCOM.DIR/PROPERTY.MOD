IMPLEMENTATION MODULE Property;
FROM SYSTEM  IMPORT ADDRESS;
FROM Objects IMPORT PropTableAddr;
FROM Support IMPORT ZtoWord, Store;
IMPORT GameFile;

TYPE Byte     = [0..255];
     Property = POINTER TO ARRAY [0..8] OF Byte;

(* byte 0 contains both property's size and number *)

PROCEDURE PropNum(p: Property): CARDINAL;
BEGIN
  RETURN p^[0] MOD 32
END PropNum;

PROCEDURE PropSize(p: Property): CARDINAL;
BEGIN
  RETURN p^[0] DIV 32 + 1
END PropSize;

PROCEDURE NextAddr(property: Property): Property;
BEGIN
  RETURN ADDRESS(property) + PropSize(property) + 1
END NextAddr;

PROCEDURE SearchProp(p: Property; propNum: CARDINAL): Property;
VAR pNum: CARDINAL;
BEGIN
  (* properties are stored in descending numbers *)
  WHILE propNum < PropNum(p) DO p := NextAddr(p) END;
  RETURN p
END SearchProp;

PROCEDURE  GetProp    (objNum, propNum: CARDINAL);
VAR p       : Property;
    propVal : CARDINAL;
BEGIN
  p := SearchProp(PropTableAddr(objNum), propNum);
  IF propNum # PropNum(p) THEN (* get default value instead *)
    propVal := ZtoWord(GameFile.defaultProps^[propNum]);
  ELSE
    propVal  := p^[1];
    IF PropSize(p) > 1 THEN propVal := propVal * 256 + p^[2] END;
  END;
  Store(propVal)
END GetProp;

PROCEDURE  PutProp    (objNum, propNum, value: CARDINAL);
VAR p : Property;
BEGIN
  p := SearchProp(PropTableAddr(objNum), propNum);
  IF PropSize(p) = 1 THEN
    p^[1] := value
  ELSE
    p^[1] := value DIV 256;
    p^[2] := value MOD 256;
  END;
END PutProp;

PROCEDURE GetNextProp    (objNum, propNum: CARDINAL);
VAR p : Property;
BEGIN
  p := PropTableAddr(objNum);
  IF propNum # 0 THEN p := NextAddr(SearchProp(p, propNum)) END;
  Store(PropNum(p))
END GetNextProp;

(* Get the addr of the property value (just after its size) *)
PROCEDURE  GetPropAddr(objNum, propNum: CARDINAL);
VAR p: Property;
    propAddr : CARDINAL;
BEGIN
  propAddr := 0; (* default address if property does not exist *)
  p := SearchProp(PropTableAddr(objNum), propNum);
  IF PropNum(p) = propNum THEN propAddr := ADDRESS(p) + 1 - GameFile.basePtr END;
  Store(propAddr)
END GetPropAddr;

PROCEDURE  GetPropLen (propAddr: CARDINAL);
VAR p: Property;
BEGIN
  IF propAddr = 0 THEN Store(0)
  ELSE
    p := GameFile.basePtr + propAddr - 1; (* size is stored just before the property data *)
    Store(PropSize(p))
  END;
END GetPropLen;

END Property.