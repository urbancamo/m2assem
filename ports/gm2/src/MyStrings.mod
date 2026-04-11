IMPLEMENTATION MODULE MyStrings;

(*
	This module implements the objects exported from the definition
	module.
*)

CONST
  NewLineCh	= CHR(10);
  HT		= CHR(9);


PROCEDURE InitialiseAString(VAR S: String);

BEGIN
  S[1] := EndOfLine
END InitialiseAString;


PROCEDURE ArrayToString(Array: ARRAY OF CHAR; VAR S: String);

VAR
  Counter	: CARDINAL;

BEGIN
  Counter := 0;
  WHILE (Array[Counter] <> EndOfLine) AND (Counter <= LongestString - 1) DO
    S[Counter + 1] := Array[Counter];
    INC(Counter)
  END;
  S[Counter + 1] := EndOfLine
END ArrayToString;


PROCEDURE StringToArray(S: String; VAR Array: ARRAY OF CHAR);

VAR
  Counter	: CARDINAL;

BEGIN
  Counter := 1;
  WHILE S[Counter] <> EndOfLine DO
    Array[Counter - 1] := S[Counter];
    INC(Counter)
  END;
  (* gm2 port: NUL-terminate the destination so the result is usable as a
     C-style string by gm2 library functions like FIO.Exists. *)
  Array[Counter - 1] := EndOfLine
END StringToArray;


PROCEDURE CapitaliseString(VAR S: String);
VAR
  P, Length: CARDINAL;

BEGIN
  Length := LengthOfString(S);
  FOR P := 1 TO Length DO
    S[P] := CAP(S[P])
  END
END CapitaliseString;


PROCEDURE ConcatStrings(VAR S1: String; S2: ARRAY OF CHAR);
VAR
  Length1, P: CARDINAL;

BEGIN
  Length1 := LengthOfString(S1);
  P := 0;
  WHILE (P <= HIGH(S2)) AND (S2[P] <> EndOfLine) AND
        (Length1 + P + 1 <= LongestString) DO
    S1[Length1 + P + 1] := S2[P];
    INC(P)
  END;
  IF Length1 + P + 1 <= LongestString THEN
    S1[Length1 + P + 1] := EndOfLine
  END
END ConcatStrings;


PROCEDURE CharInString(S: String; P: CARDINAL): CHAR;
	
BEGIN
  IF P > LengthOfString(S) THEN
    RETURN EndOfLine
  ELSE
    RETURN S[P]
  END
END CharInString;


PROCEDURE LengthOfString(S: String): CARDINAL;
VAR
  I: CARDINAL;
  Sum: CARDINAL;

BEGIN
  I := 1;
  Sum := 0;
  WHILE S[I] <> EndOfLine DO
    IF S[I] = HT THEN
      REPEAT
        INC(Sum)
      UNTIL (Sum MOD 8) = 0;
      INC(I)
    ELSE
      INC(I);
      INC(Sum)
    END
  END;
  RETURN Sum
END LengthOfString;


PROCEDURE MakeSubstring(S: String; StartPos, Length: CARDINAL;
						VAR Substring: String);
			
VAR
  Dest, Index: CARDINAL;
	
BEGIN
  Dest := 1;
  FOR Index := StartPos TO StartPos + Length - 1 DO
    Substring[Dest] := S[Index];
    Dest := Dest + 1
  END;
  Substring[Dest] := EndOfLine
END MakeSubstring;


PROCEDURE EmptyString(S: String): BOOLEAN;
	
BEGIN
  RETURN S[1] = EndOfLine
END EmptyString;


PROCEDURE ReverseString(VAR S: String);
	
VAR
  T:	CHAR;
  Front, Back:	CARDINAL;
	
BEGIN
  Front := 1;
  Back := LengthOfString(S);
  WHILE Front < Back DO
    T := S[Front];
    S[Front] := S[Back];
    S[Back] := T;
    INC(Front);
    DEC(Back)
  END
END ReverseString;


PROCEDURE AlphabeticallyLess(S1, S2: String): BOOLEAN;
	
VAR
  Index: CARDINAL;
  Comparing, ALess: BOOLEAN;
	
BEGIN
  Index := 1;
  Comparing := TRUE;
  WHILE Comparing DO
    IF (Index > LongestString) OR (S2[Index] = EndOfLine) THEN
      Comparing := FALSE;
      ALess := FALSE
    ELSIF S1[Index] = EndOfLine THEN
      Comparing := FALSE;
      ALess := TRUE
    ELSIF S1[Index] = S2[Index] THEN
      INC(Index)
    ELSE
      Comparing := FALSE;
      ALess := S1[Index] < S2[Index]
    END;
  END;	    RETURN ALess
END AlphabeticallyLess;


PROCEDURE EqualStrings(S1, S2: String): BOOLEAN;
	
VAR
  Index: CARDINAL;
  Comparing, Same:  BOOLEAN;
	
BEGIN
  Index := 1;
  Comparing := TRUE;
  WHILE Comparing DO
    IF (Index > LongestString) OR
		 ((S1[Index] = EndOfLine) AND (S2[Index] = EndOfLine)) THEN
      Comparing := FALSE;
      Same := TRUE
    ELSIF S1[Index] = S2[Index] THEN
      INC(Index)
    ELSE
      Comparing := FALSE;
      Same := FALSE
    END
  END;
  RETURN Same
END EqualStrings;


PROCEDURE StringsShutdown;
END StringsShutdown;


END MyStrings.

