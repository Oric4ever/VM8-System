MODULE CardStak;
FROM Cards IMPORT Card, Shuffle, NewDeck, Follows;

TYPE Stack = RECORD
               nbCards : CARDINAL;
               cards   : ARRAY [0 .. 50] OF Card;
             END;

PROCEDURE IsEmpty(stack: Stack): BOOLEAN;
BEGIN
  RETURN stack.nbCards = 0
END IsEmpty;

PROCEDURE Top(stack: Stack; VAR card: Card);
BEGIN
  card := stack.cards[stack.nbCards - 1]
END Top;

PROCEDURE Push(card: Card; stack: Stack);
BEGIN
  stack.cards[stack.nbCards] := card;
  INC(stack.nbCards)
END Push;

PROCEDURE IsStackable(card: Card; stack: Stack): BOOLEAN;
BEGIN
  IF Follows(Top(stack)


VAR deck : ARRAY [1 .. 8 * 52] OF Card;
   
PROCEDURE InitDeck;
VAR deck52: ARRAY [1 .. 52] OF Card;
    n, i: CARDINAL;
BEGIN
  FOR n:=0 TO 7 DO
    NewDeck(deck52); Shuffle(deck52);
    FOR i:=1 TO 52 DO deck[n*52 + i] := deck52[i] END;
  END;
  Shuffle(deck);
END InitDeck;

END CardStak.                                                                                                  