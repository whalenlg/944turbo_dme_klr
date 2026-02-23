Version 4
SymbolType CELL
LINE Normal -48 -80 48 -80
LINE Normal 48 -80 48 80
LINE Normal 48 80 -48 80
LINE Normal -48 80 -48 -80

WINDOW 0 0 0 Left 0
WINDOW 3 0 0 Left 0

SYMATTR Prefix X
SYMATTR Value O2_DUAL
SYMATTR Description "O2 dual comparator (component-level)"

PIN -96 0 LEFT 8
PINATTR PinName SENSOR
PINATTR SpiceOrder 1

PIN -16 -80 UP 8
PINATTR PinName VLOGIC
PINATTR SpiceOrder 2

PIN -16 -40 UP 8
PINATTR PinName V12
PINATTR SpiceOrder 3

PIN -16 40 DOWN 8
PINATTR PinName GND
PINATTR SpiceOrder 4

PIN 96 -24 RIGHT 8
PINATTR PinName OUT_TOP
PINATTR SpiceOrder 5

PIN 96 24 RIGHT 8
PINATTR PinName OUT_BOT
PINATTR SpiceOrder 6

TEXT -40 -56 Left 0 "O2 dual comparator (comp-level)"
