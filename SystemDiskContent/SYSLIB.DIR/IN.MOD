IMPLEMENTATION MODULE In;
IMPORT Texts;

VAR termCH: CHAR;

PROCEDURE Char (VAR ch: CHAR);
 (* Done := Not past end of input *)
BEGIN
  Texts.ReadChar(Texts.input, ch);
  Done := NOT Texts.EOT(Texts.input);
  termCH := ch;
END Char;

PROCEDURE String (VAR s: ARRAY OF CHAR);
 (* Reads string as in Texts. Done := the returned string is not empty *)
BEGIN
  Texts.ReadLine  (Texts.input, s);
  Texts.ReadAgain (Texts.input);
  Texts.ReadChar  (Texts.input, termCH);
END String;

PROCEDURE Name (VAR s: ARRAY OF CHAR);
 (* Reads string as in Texts. Done := the returned string is not empty *)
BEGIN
  Texts.ReadString(Texts.input, s);
  Texts.ReadAgain (Texts.input);
  Texts.ReadChar  (Texts.input, termCH);
END Name;

PROCEDURE Int (VAR x: INTEGER);
 (* Reads integer as in Texts. Done := integer was read *)
BEGIN
  Texts.ReadInt  (Texts.input, x);
  Done := Texts.Done(Texts.input);
  Texts.ReadAgain(Texts.input);
  Texts.ReadChar (Texts.input, termCH);
END Int;

PROCEDURE Long (VAR x: LONGINT);
 (* Reads integer as in Texts. Done := integer was read *)
BEGIN
  Texts.ReadLong  (Texts.input, x);
  Done := Texts.Done(Texts.input);
  Texts.ReadAgain(Texts.input);
  Texts.ReadChar (Texts.input, termCH);
END Long;

PROCEDURE Real (VAR x: REAL);
BEGIN
  Texts.ReadReal(Texts.input, x);
  Done := Texts.Done(Texts.input);
  Texts.ReadAgain(Texts.input);
  Texts.ReadChar (Texts.input, termCH);
END Real;

BEGIN
  Done := TRUE
END In.
