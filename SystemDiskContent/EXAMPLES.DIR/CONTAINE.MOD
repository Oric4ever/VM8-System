MODULE Container;

(*
   Module Container defines Box, an empty tagged record that is used in the
   collections modules:
     LinkedList
     BinaryTree

   Genericity in the collections modules is replaced by type extension :
   all the dynamic structures handle Items, i.e pointers to Box.
   where Box is an empty tagged record that has to be extended by the user.

   Example: in order define lists of GameState, the user has to define a
   GameState type as an extension of the Container.Box type:

   TYPE GameState = RECORD(Container.Box)
                      ... (* fields of the GameState *)
                    END;

   then, the LinkedList module's procedures can be used :

   VAR myItem : POINTER TO GameState;
       myList : LinkedList.Type;
   BEGIN
     NEW(myItem);
     LinkedList.Prepend(myList, myItem);
*)

TYPE
    Box*    = TAGGED RECORD END;
    Item*   = POINTER TO Box;

    Modifier*  = PROCEDURE(VAR box: Box);
    Predicate* = PROCEDURE(box: Box): BOOLEAN;

    Compare*   = PROCEDURE(box1, box2: Box): INTEGER; (* sign of result reflects comparison *)

(*
    ItemModifier* = PROCEDURE(VAR item: Item);
    Predicate*    = PROCEDURE(item: Item): BOOLEAN;

    ItemCompare*  = PROCEDURE(item1, item2: Item): INTEGER; (* sign of result reflects comparison *)
*)
END Container.