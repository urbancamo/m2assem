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
  END
END StringToArray;


PROCEDURE CapitaliseString(VAR S: String);
VAR
  Position, Length: CARDINAL;

BEGIN
  Length := LengthOfString(S);
  FOR Position := 1 TO Length DO
    S[Position] := CAP(S[Position])
  END
END CapitaliseString;


PROCEDURE ConcatStrings(VAR S1: String; S2: String);
VAR
  Position, Length1, Length2: CARDINAL;

BEGIN
  Length1 := LengthOfString(S1);
  Length2 := LengthOfString(S2);
  IF Length1 + Length2 < LongestString THEN
    FOR Position := Length1 + 1 TO Length1 + 1 + Length2 DO
      S1[Position] := S2[Position - Length1]
    END
  ELSE
    FOR Position := Length1 + 1 TO LongestString DO
      S1[Position] := S2[Position - Length1]
    END
  END
END ConcatStrings;


PROCEDURE CharInString(S: String; Position: CARDINAL): CHAR;
	
BEGIN
  IF Position > LengthOfString(S) THEN
    RETURN EndOfLine
  ELSE
    RETURN S[Position]
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

