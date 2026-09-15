iverilog -o knock_gen_tb.vvp -s knock_gen_tb timescale.v klr_defs.v knock_gen.v knock_gen_tb.v
vvp knock_gen_tb.vvp

