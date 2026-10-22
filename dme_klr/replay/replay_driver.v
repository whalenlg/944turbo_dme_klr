// ============================================================
//  replay_driver.v — open-loop log replay driver, Verilog edition
//
//  The iverilog counterpart of replay_main.cpp: a second top-level
//  module, compiled next to dme_klr_dashboard_tb (-DLIVE) and elaborated
//  with  -s dme_klr_dashboard_tb -s replay_driver.  It reads the same
//  <name>.stim.csv that xlsx_to_stim.py writes, pins the model's live_*
//  inputs row by row, and prints the same SIM: [ROW] markers, so
//  check_replay.py reads its output unchanged.
//
//  Plusargs:  +stim=<file>  (required)   +warmup_ms=<ms>  (default 3000)
//
//  The column order is fixed to xlsx_to_stim.py's STIM_COLS; the header
//  line is checked against it.
// ============================================================

`include "timescale.v"

module replay_driver;

    localparam HEADER = "t_ms,rpm,afm,boost,coolant,airtemp,battery,altitude,fuel_qual,dme_tps,klr_tps,o2";

    integer   fd, n, idx, warmup_ms;
    real      t_ms, t0_ms, offset_ns, target_ns;
    integer   rpm, afm, boost, coolant, airtemp, battery, altitude, fuel_qual, dme_tps, klr_tps, o2;
    reg [8*256-1:0] stim_file;
    reg [8*256-1:0] line;

    task apply;
        begin
            dme_klr_dashboard_tb.live_rpm       = rpm;
            dme_klr_dashboard_tb.live_afm       = afm;
            dme_klr_dashboard_tb.live_boost     = boost;
            dme_klr_dashboard_tb.live_coolant   = coolant;
            dme_klr_dashboard_tb.live_airtemp   = airtemp;
            dme_klr_dashboard_tb.live_battery   = battery;
            dme_klr_dashboard_tb.live_altitude  = altitude;
            dme_klr_dashboard_tb.live_fuel_qual = fuel_qual;
            dme_klr_dashboard_tb.live_dme_tps   = dme_tps;
            dme_klr_dashboard_tb.live_klr_tps   = klr_tps;
            dme_klr_dashboard_tb.live_o2        = o2;
        end
    endtask

    function integer read_row;
        input integer f;
        begin
            read_row = $fscanf(f, "%f,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n",
                               t_ms, rpm, afm, boost, coolant, airtemp, battery,
                               altitude, fuel_qual, dme_tps, klr_tps, o2);
        end
    endfunction

    initial begin
        if (!$value$plusargs("stim=%s", stim_file)) begin
            $display("replay: +stim=<file> is required");
            $finish;
        end
        if (!$value$plusargs("warmup_ms=%d", warmup_ms)) warmup_ms = 3000;
        fd = $fopen(stim_file, "r");
        if (fd == 0) begin
            $display("replay: cannot open %0s", stim_file);
            $finish;
        end
        n = $fgets(line, fd);
        while (line[7:0] == 8'h0A || line[7:0] == 8'h0D) line = line >> 8;   // drop CR/LF
        if (line != HEADER) begin
            $display("replay: unexpected header; regenerate the stimulus with xlsx_to_stim.py");
            $finish;
        end

        if (read_row(fd) != 12) begin
            $display("replay: no stimulus rows");
            $finish;
        end
        #1;                       // after the testbench's own live_* initialisers
        apply;
        t0_ms     = t_ms;
        offset_ns = warmup_ms * 1.0e6 - t0_ms * 1.0e6;
        $display("SIM: [REPLAY] warmup_ms=%0d log_ms=%.3f.. (iverilog)", warmup_ms, t0_ms);

        idx = 0;
        forever begin             // one pass per row; ends at the last row below
            target_ns = t_ms * 1.0e6 + offset_ns;
            if (target_ns > $realtime) #(target_ns - $realtime);
            $display("SIM: [ROW] idx=%0d log_ms=%.3f t_ns=%0d", idx, t_ms, $time);
            dme_klr_dashboard_tb.live_snap_req = dme_klr_dashboard_tb.live_snap_req + 1;
            if (idx > 0) apply;   // row 0 was applied at t=0
            idx = idx + 1;
            if (idx % 100 == 0) $fflush;
            if (read_row(fd) != 12) begin
                wait (dme_klr_dashboard_tb.live_snap_ack == dme_klr_dashboard_tb.live_snap_req);
                #1000;
                $display("SIM: [REPLAY] done t_ns=%0d rows_played=%0d", $time, idx);
                $fclose(fd);
                $finish;
            end
        end
    end

endmodule
