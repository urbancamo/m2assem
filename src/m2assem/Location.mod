IMPLEMENTATION MODULE Location;

(*
	MODULE: Location	Version 1.0	(c) 1989 Mark Wickens
	
	Created: 28-11-89
	
	Handles the location of the location counter relative to the start
	of the source file.
*)

FROM ADM	IMPORT	MEMLOW, MEMHIGH;
FROM Exceptions	IMPORT	Raise, ExceptionType, ExceptionLevel;

CONST
  LocationError	= "Location of current instruction is out of bounds";

VAR
  LocationCounter: LONGCARD;


PROCEDURE ResetLocation;
BEGIN
  LocationCounter := MEMLOW
END ResetLocation;


PROCEDURE SetLocation(NewLocation: LONGCARD);
BEGIN
  IF (NewLocation >= MEMLOW) AND (NewLocation <= MEMHIGH) THEN
    LocationCounter := NewLocation
  ELSE
    Raise(Code, Fatal, LocationError)
  END
END SetLocation;


PROCEDURE CurrentLocation(): LONGCARD;
BEGIN
  RETURN LocationCounter
END CurrentLocation;


PROCEDURE INCLocation(Increment: CARDINAL);
BEGIN
  IF LocationCounter + LONGCARD(Increment) < MEMHIGH THEN
    INC(LocationCounter, LONGCARD(Increment))
  ELSE
    Raise(Code, Fatal, LocationError)
  END
END INCLocation;


PROCEDURE LocationShutdown;
BEGIN
  LocationCounter := MEMLOW
END LocationShutdown;


END Location.

