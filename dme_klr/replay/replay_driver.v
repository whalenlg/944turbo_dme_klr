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
//             +trace=<file>  (default: the stim path with .stim.csv
//                             replaced by .trace.csv; skipped if absent)
//
//  The column order is fixed to xlsx_to_stim.py's STIM_COLS (and
//  TRACE_COLS for the trace file); the header lines are checked.
//
//  Waveform: the signals below are added to the testbench's VCD/FST, all
//  changing at each row's time, so the log sits beside the model:
//    row_idx, log_t_ms, log_segment   which log row is playing
//    pin_*    the raw bytes driven into the model (the stim file)
//    log_*    the log's input columns in its own units (psi, V, degF)
//    exp_*    the log's outputs, i.e. what the model should produce
//  log_tps_status is 0 Idle, 1 Off Idle, 2 Full Load.
// ============================================================

`include "timescale.v"

module replay_driver;

    localparam HEADER = "t_ms,rpm,afm,boost,coolant,airtemp,battery,altitude,fuel_qual,dme_tps,klr_tps,o2,knock";
    localparam TRACE_HEADER = {"t_ms,segment,rpm,afm_v,map_psi,ect_f,iat_v,batt_v,alt_v,tps_v,nbo2_v,",
                               "tps_status,fqs,ign_adv,klr_retard,inj_ms,dwell_ms,icv_pct,knocking,knock_cnt"};

    integer   fd, n, idx, warmup_ms;
    real      t_ms, t0_ms, offset_ns, target_ns;
    integer   rpm, afm, boost, coolant, airtemp, battery, altitude, fuel_qual, dme_tps, klr_tps, o2, knock;
    reg [8*256-1:0] stim_file;
    reg [8*256-1:0] line;
    reg [8*256-1:0] trace_file;
    integer   tfd;
    real      tr_t_ms;

    // ── Waveform signals (see the header) ──
    integer   row_idx = -1;
    real      log_t_ms = 0;
    integer   log_segment = 0;
    reg [15:0] pin_rpm;
    reg [7:0] pin_afm, pin_boost, pin_coolant, pin_airtemp, pin_battery, pin_altitude,
              pin_fuel_qual, pin_dme_tps, pin_klr_tps;
    reg [1:0] pin_o2;
    reg       pin_knock;
    real      log_rpm, log_afm_v, log_map_psi, log_ect_f, log_iat_v, log_batt_v, log_alt_v,
              log_tps_v, log_nbo2_v, log_fqs;
    integer   log_tps_status;
    real      exp_ign_adv, exp_klr_retard, exp_inj_ms, exp_dwell_ms, exp_icv_pct,
              exp_knock_cnt;
    reg       exp_knocking, exp_full_load;
    // the tr_* staging copies are read ahead; show_row moves them to log_*/exp_*
    integer   tr_segment, tr_tps_status, tr_knocking;
    real      tr_rpm, tr_afm_v, tr_map_psi, tr_ect_f, tr_iat_v, tr_batt_v, tr_alt_v, tr_tps_v,
              tr_nbo2_v, tr_fqs, tr_ign_adv, tr_klr_retard, tr_inj_ms, tr_dwell_ms,
              tr_icv_pct, tr_knock_cnt;

    initial begin
        #0;   // after vcd.v / klr_vcd.v open the dump file, also at t=0
        $dumpvars(1, row_idx, log_t_ms, log_segment);
        $dumpvars(1, pin_rpm, pin_afm, pin_boost, pin_coolant, pin_airtemp, pin_battery,
                  pin_altitude, pin_fuel_qual, pin_dme_tps, pin_klr_tps, pin_o2, pin_knock);
        $dumpvars(1, log_rpm, log_afm_v, log_map_psi, log_ect_f, log_iat_v, log_batt_v,
                  log_alt_v, log_tps_v, log_nbo2_v, log_tps_status, log_fqs);
        $dumpvars(1, exp_ign_adv, exp_klr_retard, exp_inj_ms, exp_dwell_ms,
                  exp_icv_pct, exp_full_load, exp_knocking, exp_knock_cnt);
    end

    function integer read_trace;
        input integer f;
        begin
            read_trace = $fscanf(f, "%f,%d,%f,%f,%f,%f,%f,%f,%f,%f,%f,%d,%f,%f,%f,%f,%f,%f,%d,%f\n",
                                 tr_t_ms, tr_segment, tr_rpm, tr_afm_v, tr_map_psi, tr_ect_f,
                                 tr_iat_v, tr_batt_v, tr_alt_v, tr_tps_v, tr_nbo2_v,
                                 tr_tps_status, tr_fqs, tr_ign_adv, tr_klr_retard,
                                 tr_inj_ms, tr_dwell_ms, tr_icv_pct, tr_knocking, tr_knock_cnt);
        end
    endfunction

    // Puts the current row on the waveform signals (log_*/exp_* from the
    // trace row matching the stim row just applied; apply sets pin_*).
    task show_row;
        begin
            row_idx   = idx;
            log_t_ms  = t_ms;
            if (tfd != 0) begin
                if (read_trace(tfd) != 20 || tr_t_ms != t_ms) begin
                    $display("replay: %0s doesn't line up with the stimulus at row %0d; trace signals stop here",
                             trace_file, idx);
                    $fclose(tfd);
                    tfd = 0;
                end else begin
                    log_segment = tr_segment;
                    log_rpm = tr_rpm;  log_afm_v = tr_afm_v;  log_map_psi = tr_map_psi;
                    log_ect_f = tr_ect_f;  log_iat_v = tr_iat_v;  log_batt_v = tr_batt_v;
                    log_alt_v = tr_alt_v;  log_tps_v = tr_tps_v;  log_nbo2_v = tr_nbo2_v;
                    log_tps_status = tr_tps_status;  log_fqs = tr_fqs;
                    exp_ign_adv = tr_ign_adv;
                    exp_klr_retard = tr_klr_retard;  exp_inj_ms = tr_inj_ms;
                    exp_dwell_ms = tr_dwell_ms;  exp_icv_pct = tr_icv_pct;
                    exp_full_load = (tr_tps_status == 2);  exp_knocking = tr_knocking;
                    exp_knock_cnt = tr_knock_cnt;
                end
            end
        end
    endtask

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
            dme_klr_dashboard_tb.live_knock     = knock;
            pin_rpm = rpm;  pin_afm = afm;  pin_boost = boost;  pin_coolant = coolant;
            pin_airtemp = airtemp;  pin_battery = battery;  pin_altitude = altitude;
            pin_fuel_qual = fuel_qual;  pin_dme_tps = dme_tps;  pin_klr_tps = klr_tps;
            pin_o2 = o2;  pin_knock = knock;
        end
    endtask

    function integer read_row;
        input integer f;
        begin
            read_row = $fscanf(f, "%f,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n",
                               t_ms, rpm, afm, boost, coolant, airtemp, battery,
                               altitude, fuel_qual, dme_tps, klr_tps, o2, knock);
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

        // trace file: +trace=, else <stim minus .stim.csv>.trace.csv
        tfd = 0;
        if (!$value$plusargs("trace=%s", trace_file)) begin
            trace_file = 0;
            if (stim_file[71:0] == ".stim.csv")
                trace_file = ((stim_file >> 72) << 80) | ".trace.csv";
        end
        if (trace_file != 0) tfd = $fopen(trace_file, "r");
        if (tfd != 0) begin
            n = $fgets(line, tfd);
            while (line[7:0] == 8'h0A || line[7:0] == 8'h0D) line = line >> 8;
            if (line != TRACE_HEADER) begin
                $display("replay: unexpected header in %0s; no log_*/exp_* signals", trace_file);
                $fclose(tfd);
                tfd = 0;
            end
        end
        if (tfd == 0) $display("replay: no trace file; the waveform gets pin_* only");

        if (read_row(fd) != 13) begin
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
            show_row;
            idx = idx + 1;
            if (idx % 100 == 0) $fflush;
            if (read_row(fd) != 13) begin
                wait (dme_klr_dashboard_tb.live_snap_ack == dme_klr_dashboard_tb.live_snap_req);
                #1000;
                $display("SIM: [REPLAY] done t_ns=%0d rows_played=%0d", $time, idx);
                $fclose(fd);
                $finish;
            end
        end
    end

endmodule
