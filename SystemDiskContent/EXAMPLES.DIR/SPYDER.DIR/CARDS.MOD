IMPLEMENTATION MODULE Cards;
IMPORT XTerm;
FROM Terminal IMPORT WriteChar, ClearScreen;
FROM Unicode IMPORT WritePlan1;
(*
TYPE Color = (PIQUE, CARREAU, TREFLE, COEUR);
     Value = (AS, DEUX, TROIS, QUATRE, CINQ, SIX, SEPT, HUIT, NEUF, DIX, VALET, DAME, ROI);
     Card  = RECORD
               color: Color;
               value: Value;
             END;
     Deck  = ARRAY [1..4*13] OF Card;
*)

PROCEDURE IsSameColor(card1, card2: Card): BOOLEAN;
BEGIN
  RETURN card1.color = card2.color;
END IsSameColor;

PROCEDURE Follows(card1, card2: Card): BOOLEAN;
BEGIN
  RETURN ORD(card1.value) = ORD(card2.value) + 1;
END Follows;

PROCEDURE DisplayCardBack;
BEGIN
  XTerm.Foreground(XTerm.BLUE);
  WritePlan1( 0F0A0H ); (* in plan 1, so actually 1F0A0H *)
  WriteChar(' ');
END DisplayCardBack;

PROCEDURE Display(card: Card);
CONST unicodeCards = 0F0A0H; (* in plan 1, so actually 1F0A0H *)
BEGIN
  IF (card.color=CARREAU) OR (card.color=COEUR)
  THEN XTerm.Foreground(XTerm.RED)
  ELSE XTerm.Foreground(XTerm.BLACK)
  END;
  WritePlan1( unicodeCards + 1 + ORD(card.color)*16 + ORD(card.value) );
  WriteChar(' ');
END Display;

PROCEDURE NewDeck(VAR deck: Deck);
VAR card : Card;
    i: CARDINAL;
BEGIN
  FOR i:=0 TO HIGH(deck) DO
    card.color := Color(i MOD 4);
    card.value := Value(i DIV 4);
    deck[i] := card
  END
END NewDeck;


PROCEDURE Shuffle(VAR cards: ARRAY OF Card);
VAR i, j, n: CARDINAL;
    tmp: Card;
BEGIN
  i := 0; j := 0;
  FOR n:=1 TO 1000 DO
    INC(j, 23); WHILE j>HIGH(cards) DO DEC(j,HIGH(cards)) END;
    tmp := cards[i]; cards[i] := cards[j]; cards[j] := tmp;
    INC(i, 37); WHILE i>HIGH(cards) DO DEC(i,HIGH(cards)) END;
  END;
END Shuffle;

VAR deck: Deck;
    i: CARDINAL;
BEGIN
  NewDeck(deck);
  Shuffle(deck);
  DisplayCardBack;
  FOR i:= 0 TO HIGH(deck) DO Display(deck[i]) END
END Cards.                  