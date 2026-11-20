// DME firmware dead-code ranges. The testbench warns
//   DME: [WARN] t=.. ms  dme dead code entry at XXXX (range: description) from YYYY
// whenever the DME PC enters one of these. Edit freely: one line per range,
// DEAD_CODE(lo, hi, "description"), addresses inclusive.
// DEAD_CODE_UNLESS_LJMP(lo, hi, "description", j): dead only while the
// ljmp at j doesn't go to lo, for code one ROM uses and another bypasses
// (the 86 ROM's hooks at 1B3C and 105C jump to 0A5E and 0AAC; the 89's go
// to the copies at 1D15 and 1CB7).
`DEAD_CODE(16'h02A1, 16'h02BE, "startup sync loop (live copy at 0C77)")
`DEAD_CODE(16'h047D, 16'h04D8, "acceleration enrichment (live copy at 1F8E)")
`DEAD_CODE(16'h0632, 16'h063E, "helper, only called by dead code")
`DEAD_CODE(16'h0659, 16'h0707, "TPS and timing calculation (live at 1BC1, 1C24)")
`DEAD_CODE(16'h07AA, 16'h07B6, "helper, only called by dead code")
`DEAD_CODE(16'h07BE, 16'h0891, "fuel adjustments (live copy at 1D23)")
`DEAD_CODE(16'h098B, 16'h09C4, "lambda-related (live copy at 1B82)")
`DEAD_CODE(16'h0A08, 16'h0A49, "lambda-related (live copy at 1B40)")
`DEAD_CODE_UNLESS_LJMP(16'h0A5E, 16'h0A64, "map 62/65 select (live copy at 1D15)", 16'h1B3C)
`DEAD_CODE_UNLESS_LJMP(16'h0AAC, 16'h0AFA, "lambda (live copy at 1CB7)", 16'h105C)
`DEAD_CODE(16'h0B8A, 16'h0BA4, "P1.5 output fragment")
`DEAD_CODE(16'h0BB0, 16'h0BCC, "P1.5 output fragment")
`DEAD_CODE(16'h1F21, 16'h1F39, "serial tester trims: 26h to advance, 28h to fuel (hooks at 104A/1050 bypass it)")
`DEAD_CODE(16'h0CCB, 16'h0FFE, "old main loop + disabled features (live main loop at 1F3A), trap at 0FF5")
