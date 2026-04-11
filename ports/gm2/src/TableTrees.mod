IMPLEMENTATION MODULE TableTrees;

(*
	MODULE TableTrees	Version 1.0	(c) 1989 Mark Wickens
	
	Created:	02-12-89
	
	This library module implements a binary search tree.
	Each node of the tree data of type TableType, and the tree does not
	contain duplications.  It can handle any number of trees, the type of
	which is exported opaquely to user programs.
*)

FROM TableExt	IMPORT	TableType;
FROM Storage	IMPORT	ALLOCATE, DEALLOCATE, Available;
FROM MyStrings	IMPORT	AlphabeticallyLess, EqualStrings;

TYPE
  BST	= POINTER TO Node;
  Node	= RECORD
  	    Data	: TableType;
	    Left,
	    Right	: BST
	  END;


PROCEDURE InitialiseATree(VAR Tree: BST);
BEGIN
  Tree := NIL;
END InitialiseATree;


PROCEDURE IsRoomInTree(): BOOLEAN;
BEGIN
  RETURN Available(SIZE(Node))
END IsRoomInTree;


PROCEDURE InsertInTree(VAR Tree: BST; DataItem: TableType);
BEGIN
  IF Tree <> NIL THEN
    IF AlphabeticallyLess(DataItem.Key, Tree^.Data.Key) THEN
      InsertInTree(Tree^.Left, DataItem)
    ELSIF AlphabeticallyLess(Tree^.Data.Key, DataItem.Key) THEN
      InsertInTree(Tree^.Right, DataItem)
    END
  ELSE
    NEW(Tree);
    WITH Tree^ DO
      Data	:= DataItem;
      Left	:= NIL;
      Right	:= NIL
    END
  END
END InsertInTree;


PROCEDURE IsInTree(Tree: BST; Key: String): BOOLEAN;
BEGIN
  IF Tree <> NIL THEN
    IF AlphabeticallyLess(Key, Tree^.Data.Key) THEN
      RETURN IsInTree(Tree^.Left, Key)
    ELSIF AlphabeticallyLess(Tree^.Data.Key, Key) THEN
      RETURN IsInTree(Tree^.Right, Key)
    ELSE
      RETURN TRUE
    END
  ELSE
    RETURN FALSE
  END
END IsInTree;


PROCEDURE DeleteFromTree(VAR Tree: BST; Key: String);
  PROCEDURE DeleteSmallest(VAR P: BST; VAR Key: String);
  VAR
    Temp: BST;

  BEGIN
    IF P^.Left = NIL THEN
      Temp := P;
      Key := P^.Data.Key;
      P := P^.Right;
      DISPOSE(Temp)
    ELSE
      DeleteSmallest(P^.Left, Key)
    END
  END DeleteSmallest;

VAR
  TempData: TableType;
  Temp: BST;

BEGIN
  IF AlphabeticallyLess(Key, Tree^.Data.Key) THEN
    DeleteFromTree(Tree^.Left, Key)
  ELSIF AlphabeticallyLess(Tree^.Data.Key, Key) THEN
    DeleteFromTree(Tree^.Right, Key)
  ELSE
    IF (Tree^.Left = NIL) AND (Tree^.Right = NIL) THEN
      Temp := Tree;
      DISPOSE(Temp);
      Tree := NIL
    ELSIF Tree^.Right = NIL THEN
      Temp := Tree;
      Tree := Tree^.Left;
      DISPOSE(Tree)
    ELSIF Tree^.Left = NIL THEN
      Temp := Tree;
      Tree := Tree^.Right;
      DISPOSE(Tree)
    ELSE
      DeleteSmallest(Tree^.Right, TempData.Key);
      Tree^.Data := TempData
    END
  END
END DeleteFromTree;


PROCEDURE ElementsInTree(Tree: BST): CARDINAL;
VAR
  Counter: CARDINAL;

  PROCEDURE TraverseTreeCount(Tree: BST);
  BEGIN
    IF Tree <> NIL THEN
      TraverseTreeCount(Tree^.Left);
      TraverseTreeCount(Tree^.Right);
      INC(Counter)
    END
  END TraverseTreeCount;

BEGIN
  Counter := 0;
  TraverseTreeCount(Tree);
  RETURN Counter
END ElementsInTree;


PROCEDURE RetrieveFromTree(Tree: BST; Key: String;
						VAR DataItem: TableType);
BEGIN
  IF Tree <> NIL THEN
    IF AlphabeticallyLess(Key, Tree^.Data.Key) THEN
      RetrieveFromTree(Tree^.Left, Key, DataItem)
    ELSIF AlphabeticallyLess(Tree^.Data.Key, Key) THEN
      RetrieveFromTree(Tree^.Right, Key, DataItem)
    ELSE
      DataItem	:= Tree^.Data
    END
  END
END RetrieveFromTree;


PROCEDURE NextInOrderInTree(Tree: BST; VAR CurrentNext: String;
						Key: String);
  PROCEDURE SearchTree(Tree: BST);
  BEGIN
    IF Tree <> NIL THEN
      IF AlphabeticallyLess(Tree^.Data.Key, Key) THEN
        SearchTree(Tree^.Right)
      ELSIF (EqualStrings(CurrentNext, Key) AND
	     AlphabeticallyLess(Key, Tree^.Data.Key)) OR
	     (AlphabeticallyLess(Tree^.Data.Key, CurrentNext) AND
	      NOT EqualStrings(Tree^.Data.Key, Key)) THEN
	CurrentNext := Tree^.Data.Key;
	SearchTree(Tree^.Left)
      ELSE
        SearchTree(Tree^.Left)
      END
    END
  END SearchTree;

BEGIN
  SearchTree(Tree)
END NextInOrderInTree;


PROCEDURE TableTreesShutdown;
END TableTreesShutdown;


END TableTrees.


