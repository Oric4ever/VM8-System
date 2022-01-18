MODULE LinkedList;
IMPORT Container;

TYPE Type*  = POINTER TO Node;
     List*  = POINTER TO Node;
     Queue* = POINTER TO Node;
     Stack* = POINTER TO Node;

    (* Node type is hidden *)
     Node = RECORD
              next: Type;
              item: Container.Item;
            END;

PROCEDURE IsEmpty*(list: List): BOOLEAN;
BEGIN RETURN list = NIL
END IsEmpty;

PROCEDURE Prepend*(VAR list: List; item: Container.Item);
VAR newList: List;
BEGIN
  NEW(newList);
  newList.next := list;
  newList.item := item;
  list := newList;
END Prepend;

PROCEDURE First*(list: List; VAR first: Container.Item);
BEGIN
  ASSERT(list # NIL); first := list.item
END First;

PROCEDURE Rest*(list: List; VAR rest: List);
BEGIN
  ASSERT(list # NIL); rest := list.next
END Rest;

PROCEDURE Get*(list: List; position: INTEGER; VAR item: Container.Item);
VAR i: INTEGER;
BEGIN
  ASSERT(position >= 0);
  FOR i := 1 TO position DO ASSERT(list # NIL); list := list.next END;
  ASSERT(list # NIL); item := list.item
END Get;

PROCEDURE Set*(list: List; position: INTEGER; item: Container.Item);
VAR i: INTEGER;
BEGIN
  ASSERT(position >= 0);
  FOR i := 1 TO position DO ASSERT(list # NIL); list := list.next END;
  ASSERT(list # NIL); list.item := item
END Set;

PROCEDURE Insert*(VAR list: List; position: INTEGER; item: Container.Item);
VAR pred : List;
    i : INTEGER;
BEGIN
  ASSERT(position >= 0);
  IF position = 0 THEN Prepend(list, item)
  ELSE
    pred := list;
    FOR i := 2 TO position DO ASSERT(pred # NIL); pred := pred.next END;
    ASSERT(pred # NIL); Prepend(pred.next, item)
  END
END Insert;

PROCEDURE Delete*(VAR list: List; position: INTEGER);
VAR pred : List;
    i : INTEGER;
BEGIN
  ASSERT(position >= 0);
  IF position = 0 THEN
    ASSERT(list # NIL);
    list := list.next
  ELSE
    pred := list;
    FOR i := 2 TO position DO ASSERT(pred # NIL); pred := pred.next END;
    ASSERT(pred # NIL);
    IF pred.next # NIL
    THEN pred.next := pred.next.next
    ELSE pred.next := NIL
    END
  END;
END Delete;

PROCEDURE Add*(VAR list: List; item: Container.Item);
VAR pred : List;
BEGIN
  IF list = NIL THEN Prepend(list, item)
  ELSE
    pred := list;
    WHILE pred.next # NIL DO pred := pred.next END;
    Prepend(pred.next, item)
  END
END Add;

PROCEDURE Map*(list: List; fct: Container.ItemModifier);
BEGIN
  WHILE list # NIL DO fct(list.item); list := list.next END
END Map;

PROCEDURE Find*(list: List; fct: Container.Predicate; VAR item: Container.Item);
BEGIN
  WHILE (list # NIL) & NOT fct(list.item) DO list := list.next END;
  IF list # NIL THEN item := list.item ELSE item := NIL END;
END Find;

END LinkedList.
