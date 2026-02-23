Version 4
SymbolType CELL
LINE Normal -32 48 32 48
LINE Normal -32 -48 32 -48
LINE Normal 32 -48 32 48
LINE Normal -32 -48 -32 48

PIN -64 0 LEFT 8
PINATTR PinName EngineO2Sensor
PINATTR SpiceOrder 1

PIN 0 -80 UP 8
PINATTR PinName 12V
PINATTR SpiceOrder 2

PIN 0 80 DOWN 8
PINATTR PinName 12VRAIL
PINATTR SpiceOrder 3

PIN 32 -16 RIGHT 8
PINATTR PinName DigO2Top
PINATTR SpiceOrder 4

PIN 32 16 RIGHT 8
PINATTR PinName DigO2Bottom
PINATTR SpiceOrder 5

PIN -16 80 DOWN 8
PINATTR PinName GND
PINATTR SpiceOrder 6

TEXT 0 0 Center 0 O2_DualComparator
TEXT -30 -30 Left 0 "Top Comparator"
TEXT -30 20 Left 0 "Bottom Comparator"

