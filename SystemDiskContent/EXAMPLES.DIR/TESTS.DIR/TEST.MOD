MODULE HELLO;
FROM SYSTEM   IMPORT BIOS;
FROM STORAGE  IMPORT FREEMEM;
FROM Terminal IMPORT WriteChar, WriteString, WriteLn;

EXCEPTION E1,E2;

PROCEDURE TEST;
BEGIN
  WriteString('ok');
EXCEPTION 
| E1 : WriteString('Exc E1')
| E2 : WriteString('Exc E2')
END TEST;

PROCEDURE WriteCard(val: CARDINAL);
BEGIN
  IF val >= 10 THEN WriteCard(val DIV 10) END;
  WriteChar(CHR(val MOD 10 + ORD('0')))
END WriteCard;

BEGIN
  WriteCard(FREEMEM()); WriteString(' bytes free.'); WriteLn;
  BIOS(0,0)
END HELLO.                               
