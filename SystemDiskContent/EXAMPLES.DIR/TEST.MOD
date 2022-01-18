MODULE TestList;

IMPORT Out, Container, LinkedList;

TYPE IntBox = RECORD(Container.Box)
                value: INTEGER
              END;
     MyItem = POINTER TO IntBox;

VAR list: LinkedList.Type;
    item: MyItem;
    i   : INTEGER;

PROCEDURE IsOdd(item: Container.Item): BOOLEAN;
BEGIN RETURN ODD(item(MyItem).value)
END IsOdd;

PROCEDURE Double(VAR item: Container.Item);
BEGIN
  item(MyItem).value := item(MyItem).value * 2
END Double;

BEGIN
  FOR i := 2 TO 10 DO
    NEW(item); item.value := i;
    LinkedList.Add(list, item)
  END;
  Out.String("Searching...");
  LinkedList.Find(list, IsOdd, item);
  Out.Int(item.value, 1); Out.Ln;
  LinkedList.Map(list, Double);
  WHILE NOT LinkedList.IsEmpty(list) DO
    LinkedList.First(list, item);
    Out.Int(item.value, 3);
    LinkedList.Rest(list, list)
  END;
  Out.Ln
END TestList.