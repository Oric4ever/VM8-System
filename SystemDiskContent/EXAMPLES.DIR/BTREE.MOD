MODULE BTree;
IMPORT Container;

TYPE
    Type* = POINTER TO Node;
    Tree* = POINTER TO Node;

    Node  = TAGGED RECORD
              left, right: Tree;
              item: Container.Item
            END;

PROCEDURE Insert*(VAR root: Tree; x: Container.Item; cmp: Container.ItemCompare);
VAR sign: INTEGER;
BEGIN
  IF root = NIL THEN NEW(root); root.item := x
  ELSE
    sign := cmp(x, root.item);
    IF sign < 0 THEN Insert(root.left,  x, cmp) END;
    IF sign > 0 THEN Insert(root.right, x, cmp) END;
  END
END Insert;

PROCEDURE Contains*(tree: Tree; x: Container.Item; cmp: Container.ItemCompare): BOOLEAN;
VAR sign: INTEGER;
    found: BOOLEAN;
BEGIN
  IF tree = NIL THEN found := FALSE
  ELSE
    sign  := cmp(x, tree.item);
    found := (sign = 0) OR
             (sign < 0) & Contains(tree.left,  x, cmp) OR
             (sign > 0) & Contains(tree.right, x, cmp)
  END;
  RETURN found
END Contains;

END BTree.