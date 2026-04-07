IMPLEMENTATION MODULE Table;

(*
	MODULE Table		Version 1.0	(c) 1989 Mark Wickens

	Created: 02-12-89
*)

FROM MyStrings	IMPORT	String, EqualStrings, MakeSubstring, LengthOfString,
			CharInString;
FROM TableTrees	IMPORT	BST, InsertInTree, IsInTree, DeleteFromTree,
			RetrieveFromTree, ElementsInTree, NextInOrderInTree,
			InitialiseATree, IsRoomInTree;

TYPE
  TablePtr	= BST;		(* A TablePtr points to a Binary Search Tree. *)

CONST
  TableSize	= 100;		(* Size of Hash table, excluding Table[0]. *)

VAR
  HashTable		: ARRAY [0..TableSize] OF TablePtr;
  				(* Hash Table is an array of TablePtr's. *)
  CurrentNext	: String;	(* The key of the next String in order, used
  				   when searching through the complete table
				   alphabetically. *)

PROCEDURE Hash(KeyToHash: String): CARDINAL;
(*
	This operation produces locations in a hash table by performing
	a transformation on a key 'KeyToHash'.  The algorithm is based on
	the Division Hashing Algormith as defined in
	
		Knuth, Donald E		'The Art Of Computer Programming'
					- Volume 3 'Sorting and Searching'
		Section 6.4 Hashing, pp 509.

	As quoted from Knuth,
	'Extensive tests on typical files have shown that two major
	types of hash functions work quite well.  One of these is
	based on division, and the other is based on multiplication.'
	Both functions work well as progressions, ie., similar input data are
	mapped onto arithmetic progressions, which reduces the number of
	collisions produced by similar data.  The algorithm is,
	
	h(K) = K mod M where
	
	K is the Key to be Hashed,
	h(K) is the hashed key,
	M is the Size of the Table,
*)

  PROCEDURE HashString(KeyToHash: String): LONGCARD;	
  (*
  	Procedure to produce a HashValue from a key.  In this case,
	all members of the String are multiplied by their position in the
	string and added together.
	It should be noted that the maximum value produced by this procedure
	(for a string of length 30, all 'z's) is under 10,000.
  *)
  VAR
    CharPos, Position, Length	: CARDINAL;
    Char			: CHAR;
    HashValue			: LONGCARD;

  BEGIN
    HashValue := 0;	(* Ready to be multiplied by first value. *)
    Length := LengthOfString(KeyToHash);
    FOR Position := 1 TO Length DO
      CharPos	:= ORD(CharInString(KeyToHash, Position)) * Position;
		(* CharPos := Position of Char in alphabet * Position of Char
		   in the string. *)
      HashValue := HashValue + LONGCARD(CharPos)(* Keeps a running total. *)
    END;
    RETURN HashValue 	(* Total calculated. *)
  END HashString;

BEGIN
  RETURN CARDINAL(HashString(KeyToHash) MOD LONGCARD(TableSize))
	(* Performs the algorithm detailed earlier, and returns result. *)
END Hash;

PROCEDURE InitialiseTable;
(*	Resets the complete table by initalising the structure at each node. *)
VAR
  Current: CARDINAL;

BEGIN
  FOR Current := 0 TO TableSize DO
    InitialiseATree(HashTable[Current])
  END
END InitialiseTable;

PROCEDURE IsRoom(): BOOLEAN;
(*	Checks whether there would be enough room for another node.	*)
BEGIN
  RETURN IsRoomInTree()
END IsRoom;

PROCEDURE IsIn(Key: String): BOOLEAN;
(*	Checks whether there is an entry for surname in the table.	*)
BEGIN
  RETURN IsInTree(HashTable[Hash(Key)], Key)
END IsIn;

PROCEDURE Insert(Entry: TableType);
(*	Inserts a record into the table.				*)
BEGIN
  InsertInTree(HashTable[Hash(Entry.Key)], Entry)	
END Insert;

PROCEDURE Retrieve(Key: String): TableType;
(*	Retrieves a record from the table.				*)
VAR
  TableEntry: TableType;

BEGIN
  RetrieveFromTree(HashTable[Hash(Key)], Key, TableEntry);
  RETURN TableEntry
END Retrieve;

PROCEDURE Delete(Key: String);
(*	Deletes a record from a table.					*)
BEGIN
  DeleteFromTree(HashTable[Hash(Key)], Key)
END Delete;

PROCEDURE Amend(VAR Entry: TableType);
(*	Amends the details of a record in the table.			*)
BEGIN
  DeleteFromTree(HashTable[Hash(Entry.Key)], Entry.Key);
  InsertInTree(HashTable[Hash(Entry.Key)], Entry)
END Amend;

PROCEDURE Greater(Key: String): BOOLEAN;
(*	Checks whether there is an entry in the table which is the next in
	order.								*)
VAR
  Counter: CARDINAL;	(* Counts through the entries in the table.	*)

BEGIN
  MakeSubstring(Key, 1, LengthOfString(Key), CurrentNext);
  					(* CurrentNext := Key *)
  FOR Counter := 0 TO TableSize DO	(* Count through each location in
  					   the table.	*)
    NextInOrderInTree(HashTable[Counter], CurrentNext, Key)
  END;
  RETURN NOT EqualStrings(Key, CurrentNext)
  					(* If Key = CurrentNext, there is
					   not an entry in the table with a
					   greater surname. *)
END Greater;

PROCEDURE NextInOrder(Key: String; VAR Entry: TableType);
(*	Gets the next entry in the table with a greater Key.	*)
BEGIN
  IF IsIn(CurrentNext) THEN		(* If CurrentNext exists in table, *)
    Entry := Retrieve(CurrentNext)	(* retrieve it.			   *)
  END
END NextInOrder;

PROCEDURE SizeOfTable(): CARDINAL;
(*	Returns the number of locations in the hash table.		*)
BEGIN
  RETURN TableSize + 1	(* Add one because the table starts at location 0. *)
END SizeOfTable;

PROCEDURE ElementsAtLocation(Location: CARDINAL): CARDINAL;
(*	Returns the number of entries at a location in the table.	*)
BEGIN
  RETURN ElementsInTree(HashTable[Location])	(* Get number of elements in
  						   the tree at that position. *)
END ElementsAtLocation;

PROCEDURE TableShutdown;
END TableShutdown;

END Table.

