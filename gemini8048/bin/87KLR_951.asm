	;; reset
                strt t
                jmp  $0077

	;; ext int routine
                sel  rb0
                dis  i
                jmp  $030E

	;; timer int routine
                sel  rb0
                mov  @r0,a
                mov  a,r7
                mov  t,a
                djnz r6,$0010
                inc  r6
                inc  r6
                stop tcnt
                jnt1 $001A
                en   i
                djnz r3,$001A
                inc  r3
                anl  p2,#$BF
                orl  p2,#$80
                djnz r2,$0036
                mov  r0,#$26
                mov  a,@r0
                inc  a
                mov  r2,a
                mov  a,r7
                rrc  a
                xch  a,r2
                rlc  a
                xch  a,r2
                rrc  a
                jnc  $0023
                djnz r2,$0029
                orl  p2,#$40
                anl  p2,#$7F
                djnz r5,$0032
                inc  r5
                mov  r0,#$38
                jmp  $005E
                djnz r5,$0063
                mov  r0,#$40
                mov  a,r7
                inc  @r0
                jb1  $003F
                inc  @r0
                mov  a,@r0
                inc  r0
                jb2  $004E
                mov  a,@r0
                jz   $004A
                anl  p1,#$EF
                jmp  $0054
                dec  r0
                mov  @r0,#$FF
                inc  r0
                mov  a,@r0
                cpl  a
                add  a,#$C1
                orl  p1,#$10
                mov  r5,a
                dec  r0
                mov  a,@r0
                swap a
                xchd a,@r0
                anl  a,#$77
                mov  @r0,a
                mov  r0,#$38
                djnz r4,$0061
                inc  r4
                mov  a,@r0
                retr
                djnz r4,$0061
                orl  p1,#$80
                mov  r0,#$2C
                mov  a,@r0
                inc  @r0
                mov  r4,#$2
                call $040B
                mov  r0,#$38
                mov  a,@r0
                retr
	;; END of timer int routine
	

	;; Reset/Trigger routine
                anl  p2,#$47
                jmp  $007B
                jnt1 $0073
                anl  p2,#$87
                mov  r0,#$25
                mov  r1,#$21
                mov  a,@r1
                mov  @r0,a
                inc  r0
                dec  r1
                mov  a,@r1
                mov  @r0,a
                mov  r0,#$28
                mov  a,@r0
                mov  @r1,a
                inc  r0
                inc  r1
                mov  a,@r0
                mov  @r1,a
                mov  r0,#$38
                mov  a,#$FC
                mov  t,a
                mov  r2,a
                inc  r5
                mov  r1,#$40
                mov  a,@r1
                djnz r5,$009C
                inc  r5
                swap a
                xchd a,@r1
                jb2  $00A0
                anl  p1,#$EF
                call $0325
                en   tcnti
                mov  r1,#$3C
                movx a,@r1
                xch  a,@r1
                inc  r1
                mov  @r1,a
                mov  r1,#$3E
                mov  a,@r1
                cpl  a
                mov  r1,#$3A
                add  a,@r1
                jc   $00B4
                anl  p1,#$DF		;11011111
                mov  r1,#$24
                clr  a
                xch  a,r6
                cpl  a
                mov  @r1,a
                mov  a,@r1
                add  a,#$1A
                jnc  $00CF
                mov  a,r7
                clr  c
                rlc  a
                mov  r7,a
                inc  r1
                mov  a,@r1
                clr  c
                rrc  a
                mov  @r1,a
                dec  r1
                mov  a,r1
                cpl  a
                jb4  $00C4
                call $0325
                mov  r1,#$24
                mov  a,@r1
                add  a,#$92
                cpl  f1
                jc   $00EF
                add  a,#$41
                jc   $00DC
                cpl  f1
                mov  a,r7
                jb1  $00EF
                clr  c
                cpl  c
                rrc  a
                mov  r7,a
                inc  r1
                mov  a,@r1
                clr  c
                rlc  a
                mov  @r1,a
                dec  r1
                mov  a,r1
                cpl  a
                jb4  $00E4
                call $0325
                mov  r1,#$31
                inc  @r1
                jmp  $0102
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                movp a,@a
                ret
                nop
                inc  @r1
                mov  r1,#$2C
                mov  a,@r1
                anl  a,#$7
                jnz  $0101
                mov  r1,#$33
                mov  a,@r1
                jz   $0137
                mov  a,r7
                jb1  $0135
                mov  r1,#$2C
                mov  a,@r1
                jb7  $0137
                mov  r1,#$32
                jnz  $0127
                mov  a,@r1
                jnz  $0125
                inc  r1
                mov  a,@r1
                dec  r1
                add  a,#$A8
                swap a
                add  a,#$19
                dec  a
                mov  @r1,a
                mov  a,@r1
                anl  a,#$F
                jnz  $0131
                mov  a,@r1
                swap a
                jb3  $0123
                mov  @r1,a
                add  a,#$FD
                jnc  $0137
                orl  p2,#$10
                mov  r1,#$27
                mov  a,r1
                xch  a,@r1
                add  a,#$D9
                jnz  $0146
                mov  a,r7
                clr  c
                rlc  a
                jc   $0140
                jz   $0148
                mov  r7,#$F0
                sel  rb1
                mov  r1,#$24
                mov  a,@r1
                mov  r6,a
                sel  rb0
                mov  a,r7
                jb2  $01B1
                jb3  $016A
                orl  p2,#$10
                mov  r1,#$7F
                mov  @r1,#$2F
                dec  r1
                mov  @r1,#$46
                dec  r1
                mov  @r1,#$31
                dec  r1
                mov  @r1,#$34
                dec  r1
                mov  @r1,#$0
                mov  a,r1
                xrl  a,#$28
                jnz  $0162
                mov  a,#$FF
                orl  p1,#$10
                mov  r1,#$2E
                mov  @r1,a
                mov  r1,#$30
                mov  @r1,a
                mov  r1,#$34
                mov  @r1,#$6
                inc  r1
                mov  @r1,a
                inc  r1
                mov  @r1,a
                mov  r1,#$39		;TPS power
                mov  @r1,#$C8		;39h <- 200
                mov  a,#$77		;119
                mov  r1,#$3B
                mov  @r1,a		;3B <- 119
                mov  r1,#$3C
                mov  @r1,a		;3C <- 119
                inc  r1
                mov  @r1,a		;3D <- 119
                inc  r1
                mov  @r1,a
                mov  r1,#$2C
                mov  @r1,#$0
                mov  r1,#$2A
                mov  @r1,#$3F
                inc  r1
                mov  @r1,#$1B
                mov  r1,#$22
                mov  @r1,#$A
                inc  r1
                mov  @r1,#$2
                clr  a
                mov  r2,a
                mov  r3,a
                dis  i
                sel  rb1
                call $0336
                orl  p2,#$40
                anl  p2,#$7F
                jnt1 $01A5
                anl  p2,#$BF
                orl  p2,#$80
                jmp  $01A9
	;; END of trigger/reset routine

	;; timing delay calculation
                sel  rb1
                mov  r1,#$73
                mov  a,@r1
                mov  r1,#$3F
                add  a,@r1
                mov  r3,a
                call $0300
                clr  c
                rrc  a
                mov  r1,#$29
                mov  @r1,a
                mov  a,r3
                rrc  a
                swap a
                anl  a,#$F
                dec  r1
                mov  @r1,a
                jmp  $0200
	;; END of timing delay calculation
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                movp a,@a
                ret

	;; Blink code calculation
                mov  r1,#$33
                mov  a,@r1
                add  a,#$EE
                jnc  $0215
                add  a,#$EC
                jc   $0215
                mov  r0,#$73
                mov  @r0,#$2D
                mov  r0,#$31
                mov  @r0,#$2
                jmp  $0243
                mov  r0,#$44
                mov  a,#$E4
                add  a,@r0
                jc   $022F
                mov  r0,#$2F
                mov  a,#$89
                add  a,@r0
                mov  r2,#$22
                jc   $022A
                dec  r2
                mov  a,#$FA
                add  a,@r0
                cpl  c
                inc  r0
                call $032A
                jmp  $0243
                mov  r0,#$43
                mov  a,@r0
                cpl  a
                add  a,#$18
                jc   $0243
                mov  r0,#$52
                mov  a,@r0		;load current MAP sensor pressure into a
                add  a,#$BF		;add 191
                cpl  c			;c=1 means an error, 0 means no error (checked in 0x32a/0x32c). So it's an error if the add did not carry, iow the MAP pressure value was <=64, that is ~54kpa or -7.8psi (that is 45kpa or 6.5psi before 10 was added in the ADC routine)
                mov  r2,#$33		;this appears to be setting the BCD for a bad MAP sensor
                mov  r0,#$30		;is this the event count for "bad MAP sensor"?
                call $032A
                mov  r0,#$2E
                mov  a,@r0
                add  a,#$72
                jc   $024C
                mov  @r1,#$12
                mov  a,@r0
                add  a,#$6B
                jnc  $025A
                mov  a,@r1
                xrl  a,#$12
                jnz  $025A
                mov  @r1,a
                mov  r0,#$3A
                mov  @r0,a
                mov  r0,#$41
                mov  a,@r0
                clr  c
                jnz  $0262
                call $02B1 		;reset the boost error event counter 35h to the value 64h (100)
                mov  r0,#$60		;load boost error location 60h into r0
                mov  a,@r0		;load actual boost error into a
                mov  r2,#$32		;BCD value for "boost too high"
                jb7  $027B		;boost error is 1's comp. so bit7=overboost
                mov  r0,#$44		;44h contains rpm axis
                mov  a,@r0		;load rpm axis value into a
                add  a,#$DB		;add 219
                jnc  $0272		;c=0 if rpm is > ~2800
                call $02B1		;this resets 35h to the value 64h (100), so no event count for underboost at low rpm
                mov  r0,#$60		;r0 now points to boost error location again
                mov  a,@r0		;load boost error into a
                dec  r2			; r2 now=31h, BCD value for "boost too low"
                cpl  a
                add  a,#$20		;add 32 (i.e. subtract 32 because we just cpl'd)
                jc   $027D		;c=1 means the boost error was < 32
                add  a,#$20		;jmp to here if overboost (from 0x267), with a=boost error from 60h. We also get here if the previous -32 operation didn't carry, i.e. the underboost error was >=32.
                cpl  c			;for underboost, c=1 if the error was < 64. For overboost, c=1 if the error was > 32  
                mov  r0,#$6C		;set in ADC MAP read; used to rate limit updates to 52h (current measured boost), and rate limits error checking to 1/4 on rising boost
                mov  a,@r0
                jnz  $0289		;skip to the next test if boost error checking is being rate limited by 6Ch
                mov  r0,#$35		;here, r0 is an input parameter to a generic event counter routine
                mov  a,#$64
                call $032C		;error counter routine. c=0 no error. c=1, we have an error
                mov  r0,#$3C		;next test, throttle position
                mov  a,#$F4
                add  a,@r0
                cpl  c
                mov  r2,#$41		;BCD code for TPS power
                jc   $0298
                mov  a,#$24
                add  a,@r0
                inc  r2			;BCD code for TPS signal
                mov  a,@r0
                mov  @r0,a
                mov  r0,#$36
                call $032A
                sel  mb1
                call $0500
                sel  mb0
                call $0336
	;; END of blink code calculation

	;; stack manipulation for housekeeping functions
	;; See page 2-5 of the MCS-48 pdf. Locations 16h and 17h are the top
	;; of the stack (2-byte value).
	;; We got here from the reset purely by jumping, no calls.
	;; Thus the ret statement at 0x2B0 will use whatever we put on the stack 	;; in this routine below. 
                mov  r1,#$17
                mov  @r1,#$8		;17h <- 8 (locations will be 8xxh)
                dec  r1
                clr  a
                xch  a,@r1		;a <- 16h
                jb0  $02AF		;call the first function 0x800?
                dec  a
                dec  a
                xchd a,@r1
                sel  mb1
                ret
                mov  r0,#$35
                mov  @r0,#$64
                ret
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                movp a,@a
                ret

	;; 8-bit multiply function (r3 x r6), 16-bit result in a:r3?
                mov  r5,#$9
                clr  c
                clr  a
                rrc  a
                xch  a,r3
                rrc  a
                xch  a,r3
                jnc  $030B
                add  a,r6
                djnz r5,$0304
                ret
	;; END of 8-bit multiply function

	;; main body of ext int routine
                mov  @r0,a
                mov  r0,#$25
                mov  a,@r0
                inc  a
                mov  r2,a
                mov  r0,#$21
                mov  a,@r0
                inc  a
                mov  r3,a
                mov  a,r7
                swap a
                cpl  a
                add  a,#$A
                mov  r0,a
                djnz r0,$031F
                mov  r0,#$38
                mov  a,@r0
                retr
	;; END ext int routine

	;; initialize r4 with 22h
                mov  r1,#$22
                mov  a,@r1
                mov  r4,a
                ret
	;; END initialize r4 with 22h

	;; Count errors and set 33h blink code
                mov  a,#$3C
                xch  a,@r0
                jnc  $0331
                dec  a
                mov  @r0,a		;count is dec'd and stored back if c (error)
                jnz  $0335		;just return if the error counter isn't 0 yet
                mov  a,r2			;r2 should contain the BCD value for the error
                mov  @r1,a		;now the address in r1 (33h) has the error BCD
                ret
	;; END count errors

	;; diagnostic function (unused?)
                mov  r0,#$80
                mov  r2,#$8
                movx a,@r0
                jb5  $0353
                mov  r2,#$4
                dec  r0
                xch  a,@r0
                swap a
                xch  a,@r0
                xchd a,@r0
                djnz r2,$033F
                jb6  $0352
                jb7  $0352
                inc  r0
                mov  @r0,#$0
                inc  r0
                mov  a,@r0
                anl  a,#$F
                mov  @r0,a
                ret
                clr  f0
                jb7  $0357
                cpl  f0
                mov  r3,#$7F
                jb6  $0368
                jb7  $0381
                mov  r1,#$2C
                mov  a,@r1
                dec  a
                rl   a
                swap a
                anl  a,#$3
                add  a,r3
                mov  r3,a
                clr  f0
                dec  r0
                mov  a,r0
                jb2  $037E
                add  a,#$82
                movp a,@a
                mov  r3,#$7F
                mov  r1,a
                jf0  $0375
                mov  a,@r1
                mov  r4,a
                mov  a,r3
                add  a,r2
                mov  r1,a
                mov  a,r4
                movx @r1,a
                djnz r2,$0368
                ret
                mov  a,@r0
                jmp  $0371
                mov  r1,#$7D
                mov  a,@r1
                jnz  $039D
                clr  f0
                cpl  f0
                call $0368
                call $0390
                mov  r0,#$7C
                mov  @r0,a
                ret
                call $0392
                mov  r0,#$7E
                mov  r1,#$D
                mov  a,@r0
                xchd a,@r1
                inc  r0
                dec  r1
                mov  a,@r0
                mov  @r1,#$FE
                ret
	;; END diagnostic function
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                anl  a,#$60
                add  a,r0
                orl  a,@r1
                movp a,@a

	;; ADC routine function table (starts at 0x400)
                jmp  $040E
                movd p4,a
                movd p4,a
                movd p4,a
                clr  a
                orl  a,r4
                orld p4,a
                anl  bus,#$99
                orld p7,a
	;; END function table
	
                nop

	;; ADC routine jump
                anl  a,#$7
                jmpp @a
	;; END ADC routine jmp

	;; ADC function #1 (address select)
                anl  p1,#$F7
                mov  a,@r0
                dec  a
                jz   $041C
                anl  p1,#$F3
                jb4  $041A
                anl  p1,#$F5
                jb3  $041E
                anl  p1,#$F6
                orl  p2,#$20
                orl  p1,#$8
                anl  p1,#$F5
                orl  p1,#$5
                ret
	;; END ADC function #1

	;; ADC function #3 (knock self-test)
                mov  r0,#$23
                mov  a,@r0
                mov  r4,a
                mov  r0,#$2F
                mov  a,@r0
                add  a,#$C0
                mov  r0,#$31
                jc   $0446
                mov  a,@r0
                jb2  $0438
                ret
                anl  a,#$7
                mov  @r0,a
                ret
	;; END ADC function #3

	;; ADC function #2 (knock self-test)
                add  a,#$7
                movp a,@a
                mov  r0,#$2F
                add  a,@r0
                jc   $044B
                mov  r0,#$31
                mov  a,@r0
                jnz  $044B
                anl  p1,#$7F
                ret
	;; END ADC function #2

	;; ADC function #4 (read ADC ch. 0 - 3)
                movx a,@r0
                orl  p1,#$8
                anl  p1,#$F4		;11110100
                xch  a,@r0
                jb4  $0480
                jb3  $047B
                xch  a,@r0
                mov  r1,a
                mov  a,@r0
                xrl  a,#$6
                mov  r0,#$2F		;knock sensor noise
                jz   $0476
                mov  a,#$C0
                add  a,r1
                jnc  $0478
                mov  a,r1
                mov  @r0,a
                mov  r1,#$34
                mov  a,@r1
                add  a,#$FA
                jz   $0475
                cpl  a
                jz   $0472
                mov  a,#$FC
                add  a,#$69
                mov  @r0,a
                ret
                mov  r0,#$2D
                mov  a,r1
                mov  @r0,a
                ret
                xch  a,@r0
                mov  r0,#$2E		;battery voltage
                mov  @r0,a
                ret
                jb3  $0487
                xch  a,@r0
                mov  r0,#$6F
                nop
                ret
                xch  a,@r0
                mov  r0,#$39		;TPS v+ ?
                mov  @r0,a
                ret
	;; END ADC function #4

	;; ADC function #5 (read ch. 5 knock sensor)
                movx a,@r0
                orl  p1,#$8
                anl  p1,#$F7
                orl  p1,#$7
                mov  r0,#$46
                cpl  a
                mov  @r0,a
                ret
	;; END ADC function #5

	;; ADC function #6 (MAP sensor?) Summary: read the ADC value, add 10 and compare it to the previous value to determine if boost is increasing or not. If it is increasing, then only update 52h and run boost error correction every 4th time. Otherwise, we keep the old value in 52h and run error checking every time. So boost has to be increasing for 4 cycles in a row to count as an increased value. 
                mov  r0,#$52
                movx a,@r0
                add  a,#$A		;add 10 to the value from 52h
                mov  r4,a			;r4 <- value from 52h + 10
                cpl  a
                add  a,@r0
                mov  r0,#$6C		;used in blink code checking - we only trigger boost codes if this is 0 
                orl  p1,#$8		;latch or unlatch ALE?
                anl  p1,#$F7		;select 11110111 (iow address ch.7, TPS angle for the nead read cycle)
                jnc  $04B1		;c=0 if boost is increasing
                mov  @r0,#$0		;here 6Ch is set to 0 which enables boost error code checking
                mov  r0,#$52
                mov  a,r4
                mov  @r0,a		;store the value from r4 into 52h
                mov  r4,#$FF		;r4 <- 255
                ret
                inc  @r0			;inc the value in 6Ch
                mov  a,@r0
                jb2  $04A8		;looks like we only enable error code checking every 4th read?
                mov  r4,#$FF
                ret
	;; END ADC function #6
	
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                movp a,@a
                ret
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                movp a,@a
                ret
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                movp a,@a
                ret
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                movp a,@a
                ret

	;; housekeeping function list (add 0x800h to calls)
                call $020F		;call throttle angle calculation? (A0E or A0F)
                call $028D
                call $0257
                call $0282
                nop
                nop
                call $029E		;calculate ADC angles (A9E)
                call $0100		;read maps (900)
                nop
                nop
                call $0012
                jmp  $0012
	;; END housekeeping function list
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                movp a,@a
                ret
	;; read maps (rpm and PID gain)
                mov  r1,#$44
                mov  a,@r1
                rl   a
                swap a
                anl  a,#$7
                inc  a
                mov  r5,a
                mov  r2,#$25
                mov  a,r2
                movp a,@a
                jz   $0919
                mov  r1,a
                mov  a,r2
                add  a,#$9
                xch  a,r2
                add  a,r5
                movp a,@a
                mov  @r1,a
                jmp  $010B
                mov  r1,#$43
                mov  a,@r1
                anl  a,#$18
                add  a,r2
                add  a,r5
                movp a,@a
                mov  r1,#$6B
                mov  @r1,a
                ret
	;; END read maps

	;; RPM maps
                xch  a,r2
                .db   0x9b
                .db   0x9b
                cpl  f0
                jb4  $0991
                orl  p2,#$83
                addc a,r7
                xch  a,r3
                movd p5,a
                xchd a,@r1
                xchd a,@r0
                xchd a,@r0
                xchd a,@r0
                xchd a,@r0
                xchd a,@r0
                cpl  a
                swap a
                jmp  $0244
                strt t
                .db   0x66
                .db   0x66
                .db   0x66
                .db   0x66
                .db   0x66
                orl  a,r2
                jmp  $0350
                movd p6,a
                jb1  $0924
                inc  r4
                call $000C
                anl  a,@r0
                en   tcnti
                inc  r7
                inc  r4
                inc  r1
                dis  i
                jb0  $090F
                movd a,p4
                orl  a,r6
                addc a,r5
                jmp  $0351
                jmp  $0238
                xch  a,r3
                inc  r7
                inc  r1
                orl  a,r3
                jb0  $0912
                jb0  $0912
                jb0  $0912
                jb0  $0912
                orl  a,r0
                xch  a,@r0
                xch  a,@r0
                xch  a,@r0
                inc  r3
                inc  r3
                inc  r3
                inc  r1
                inc  @r0
                orl  a,r4
                movx a,@r0
                movx a,@r0
                movx a,@r0
                movx a,@r0
                movx a,@r0
                movx a,@r0
                movx a,@r0
                movx a,@r0
                movd p6,a
                mov  a,t
                mov  a,t
                mov  a,t
                mov  a,t
                mov  a,t
                mov  a,t
                mov  a,t
                mov  a,t
                strt cnt
                in   a,p2
                in   a,p2
                in   a,p2
                in   a,p2
                in   a,p2
                in   a,p2
                in   a,p2
                in   a,p2
                add  a,r1
                jmp  $0004
                jmp  $0004
                jmp  $0004
                jmp  $0004
                nop
	;; END rpm maps

	;; PID gain 8x4 map (rpm/throttle)
                djnz r1,$09E9
                jnc  $09E6
                djnz r2,$09E7
                movp3 a,@a
                movp3 a,@a
                dec  r1
                mov  r1,a
                .db   0xa6
                jni  $098A
                cpl  c
                .db   0xc3
                movp3 a,@a
                mov  r1,a
                orl  p1,#$86
                .db   0x66
                add  a,r2
                rrc  a
                ret
                movp3 a,@a
                dec  r1
                mov  r1,a
                jni  $0966
                add  a,r2
                rrc  a
                movp a,@a
                movp3 a,@a
	;; PID gain 8x4 map
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                movp a,@a
                ret

	;; RPM axis map
                .db   0x01
                .db   0x01
                outl bus,a
                .db   0x01
                .db   0x01
                outl bus,a
                outl bus,a
                outl bus,a
                outl bus,a
                outl bus,a
                add  a,#$3
                add  a,#$4
                jmp  $00B9		;added manually by me, see note below!
	;; END RPM axis map

	;; read throttle angle calculation.
	;; This was disassembled incorrectly.
	;; Location 0A0E = 04, this should be part of the map above
	;; location 0A0F = B9 = 1011 1001 = mov r1, XX
	;; location 0A10 = 3C, so we have "mov r1, 3C".
	;; location 0A11 = F1 = 1111 0001 = mov a, @r1

	;;0xa0e jmp  $00B9
	;;0xa10 movd p4,a	

                mov  r1,#$3C		;added manually by me, see note above
                mov  a,@r1
                cpl  a
                inc  r1
                add  a,@r1
                mov  r1,#$3F
                jc   $0A1F		;c=1 if 3C > 3D (throttle increasing?)
                add  a,#$6		
                jc   $0A1F		;c=1 if 3C > 3D-6
                mov  @r1,#$B		;3F <- 11=0000 01011
                mov  a,@r1
                jz   $0A23
                dec  a
                anl  a,#$F
                mov  @r1,a
                mov  r1,#$3C
                mov  a,@r1
                mov  r6,a
                dec  r1
                mov  a,@r1
                mov  r3,a
                sel  mb0
                call $0300		;8x8=16 multiply, so r3:a = 3Ch x 3Bh. 3B is initialized to 119 in the trigger routine. 
                sel  mb1
                dec  r1			;r1 <- 3A
                mov  @r1,a		;3A <- high byte of the multiply
                add  a,#$CB		;203
                jc   $0A38
                clr  a
                mov  r1,#$43		
                mov  @r1,a		;43h <- 3Ah + 203, or zero if 3Ah+203 < 255
                mov  a,#$E3		;227
                add  a,@r1
                jnc  $0A42
                mov  @r1,#$1C		;43h <- 28 if 43h is > 
                mov  r1,#$39
                mov  a,@r1
                mov  r6,a
                mov  r1,#$3B
                mov  a,@r1
                mov  r3,a
                sel  mb0
                call $0300		;r3:a = 39h x 3Bh (high byte)
                sel  mb1
                add  a,#$A3		;163
                jz   $0A56
                cpl  a
                inc  a
                add  a,@r1
                mov  @r1,a
                ret
	;; END throttle angle calculation

	;; read rpm axis function
                mov  r1,#$44
                mov  r0,#$24
                mov  r6,#$0
                mov  a,@r0
                cpl  a
                mov  r4,a
                sel  rb0
                mov  a,r7
                sel  rb1
                cpl  a
                jb1  $0A7C
                cpl  a
                add  a,#$38
                add  a,r4
                mov  r4,a
                jc   $0A77
                inc  r6
                mov  a,r6
                rrc  a
                clr  c
                rrc  a
                movp a,@a
                add  a,r4
                mov  r4,a
                jnc  $0A6D
                mov  a,#$C4
                add  a,r6
                jnc  $0A7F
                mov  r6,#$3C
                clr  a
                xch  a,r6
                mov  @r1,a
                ret
	;; END read rpm axis function

	;; read CV feedforward map
                mov  r0,#$43
                mov  r1,#$44
                clr  f1
                call $0480
                mov  r1,#$68
                mov  @r1,a
                ret
	;; END read CV feedforward map

	;; read target boost map
                mov  r0,#$43
                mov  r1,#$44
                clr  f1
                cpl  f1
                call $0480
                cpl  a
                mov  r1,#$57
                add  a,@r1
                cpl  a
                mov  r1,#$51
                mov  @r1,a
                ret
	;; END read target boost map

	;; calculate ADC angles 1 & 2
                mov  r0,#$2A
                mov  r1,#$22
                call $0380
                mov  @r1,a
                mov  r0,#$2B
                inc  r1
                call $0380
                add  a,#$F8
                mov  @r1,a
                ret
	;; END calculate ADC angles
	
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                movp a,@a
                ret

	;; CV feedforward aka open-loop map (rpm/throttle)
                jnt0 $0B26
                jnt0 $0B26
                jnt0 $0B26
                jnt0 $0B26
                jnt0 $0B26
                jnt0 $0B26
                jnt0 $0B26
                jnt0 $0B26
                xchd a,@r0
                xchd a,@r0
                xchd a,@r0
                jt0  $0B36
                outl p1,a
                outl p1,a
                outl p1,a
                outl p1,a
                outl p1,a
                outl p1,a
                outl p1,a
                outl p1,a
                outl p1,a
                outl p1,a
                outl p1,a
                outl p2,a
                outl p2,a
                movd p5,a
                orl  a,#$45
                orl  a,r1
                orl  a,r1
                orl  a,r4
                orl  a,r4
                orl  a,r4
                orl  a,r4
                orl  a,r4
                orl  a,r4
                orl  a,r4
                orl  a,r4
                orl  a,r4
                anl  a,@r1
                anl  a,@r1
                anl  a,@r1
                call $025A
                add  a,@r0
                jmp  $0368
                add  a,r2
                add  a,r4
                add  a,r5
                .db   0x73
                .db   0x73
                .db   0x73
                .db   0x73
                .db   0x73
                .db   0x73
                .db   0x73
                .db   0x73
                rr   a
                addc a,r3
                addc a,r7
                ret
                jni  $0B8A
                orld p6,a
                jb4  $0B9A
                anl  p2,#$9A
                anl  p2,#$9A
                jnz  $0B92
                orld p6,a
                jb4  $0B96
                anld p5,a
                mov  @r1,a
                clr  f1
                mov  r1,a
                mov  r5,a
                jf0  $0BBF
                mov  r7,#$BF
                mov  r7,#$BF
                jnz  $0B92
                orld p6,a
                jb4  $0B96
                anld p5,a
                mov  @r1,a
                clr  f1
                mov  r1,a
                mov  r5,a
                jf0  $0BBF
                mov  r7,#$BF
                mov  r7,#$BF
                jnz  $0B92
                orld p6,a
                jb4  $0B96
                anld p5,a
                mov  @r1,a
                clr  f1
                mov  r1,a
                mov  r5,a
                jf0  $0BBF
                mov  r7,#$BF
                mov  r7,#$BF
	;; END CV feedforward map

	;; multiply @r0 by RPM value
                mov  a,@r0
                mov  r3,a
                mov  r0,#$24
                mov  a,@r0
                mov  r6,a
                sel  mb0
                call $0300
                sel  mb1
                ret
                jmp  $04FE
	;; END multiply @r0 by RPM
	
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                jf1  $0B8B
                movp a,@a
                ret

	;; target boost map (rpm/throttle)
                anl  bus,#$98
                anl  bus,#$96
                jnz  $0C96
                call $0494
                call $0492
                jb4  $0C91
                movx @r1,a
                movx @r0,a
                orld p5,a
                orl  p1,#$9E
                anld p6,a
                anld p6,a
                anld p6,a
                anld p6,a
                anld p6,a
                anld p6,a
                anld p6,a
                anld p6,a
                anld p5,a
                anld p5,a
                anl  p2,#$97
                movx @r1,a
                orld p5,a
                .db   0x8b
                clr  f1
                clr  f1
                clr  f1
                .db   0xa6
                cpl  c
                cpl  c
                cpl  c
                mov  r2,a
                mov  r2,a
                cpl  c
                cpl  c
                jmp  $059D
                call $048D
                .db   0x8b
                mov  r3,a
                mov  r3,a
                mov  r3,a
                mov  r6,a
                mov  r7,a
                mov  @r0,#$B1
                call $05B4
                call $05B4
                mov  @r1,#$AA
                anld p7,a
                orld p6,a
                orld p5,a
                call $05B4
                jf0  $0CB8
                mov  r2,#$BC
                mov  r7,#$C1
                .db   0xc1
                .db   0xc1
                .db   0xc1
                .db   0xc1
                mov  r6,#$AB
                movx @r1,a
                orld p7,a
                mov  r1,#$B9
                mov  r4,#$C1
                jz   $0CCA
                dec  r6
                dec  r7
                dec  r7
                xrl  a,@r0
                xrl  a,@r1
                xrl  a,@r0
                dec  r6
                call $0598
                movx @r1,a
                mov  r1,#$B9
                mov  r4,#$C1
                jz   $0CCA
                dec  r6
                dec  r7
                dec  r7
                xrl  a,@r0
                xrl  a,@r1
                xrl  a,@r0
                dec  r6
                call $0598
                movx @r1,a
                mov  r1,#$B9
                mov  r4,#$C1
                jz   $0CCA
                dec  r6
                dec  r7
                dec  r7
                xrl  a,@r0
                xrl  a,@r1
                xrl  a,@r0
                dec  r6
                call $0598
                movx @r1,a
	;; 0xc80 mov  a,@r1		
	;; END target boost map

	;; This must be incorrectly disassemlbed because 480 (C80) is called
	;; as the routine
	;; In any case this is where we call to from A82
	;; r0 = 43h
	;; r1 = 44h
	;; read boost/cv feedforward map
                mov  a,@r1		;added my me to fix the above mistake
                rrc  a
                rrc  a			;divide 43h by 4 to get 0-7 range
                anl  a,#$F
                mov  r2,a
                mov  a,@r0
                rlc  a
                rlc  a
                anl  a,#$F0
                add  a,r2
                mov  r2,a
                mov  a,@r0
                anl  a,#$3
                inc  a
                dec  r0
                mov  @r0,a
                clr  a
                mov  r5,a
                mov  r7,a
                mov  r4,#$4
                mov  a,r4
                cpl  a
                add  a,@r0
                mov  a,r2
                jnc  $0CA0
                add  a,#$10
                mov  r3,a
                call $03FC
                add  a,r5
                mov  r5,a
                jnc  $0CA8
                inc  r7
                mov  a,@r1
                rrc  a
                mov  a,r3
                jnc  $0CAE
                inc  a
                call $03FC
                add  a,r5
                mov  r5,a
                jnc  $0CB5
                inc  r7
                mov  a,@r1
                inc  r3
                jb1  $0CBA
                dec  r3
                mov  a,r3
                call $03FC
                add  a,r5
                mov  r5,a
                jnc  $0CC2
                inc  r7
                mov  a,r3
                call $03FC
                add  a,r5
                mov  r5,a
                jnc  $0CCA
                inc  r7
                djnz r4,$0C98
                mov  a,r7
                anl  a,#$F
                xch  a,r5
                mov  r0,#$1D
                xchd a,@r0
                swap a
                ret
	;; END read boost/cv feedforward map
	
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                movp a,@a
                ret

	;; Detect knock
                mov  r0,#$7A
                mov  r1,#$45
                mov  a,@r1
                cpl  a
                add  a,@r0
                jc   $0D0B
                mov  a,@r1
                mov  @r0,a
                mov  r1,#$47
                mov  r2,#$0
	;; The upper nibble of 47h represents 0-4 in steps of 0.25. The value in 7Ah is multipled by this; the values depend on rpm:
	;; low-medium: 66  (x1), medium-high: 55 (x0.75), high: 44 (x0.5). The final value is the threshold; the current reading must be *lower* than the threshold to count as knock; therefore this coefficient makes knock detection *less* sensitive at high rpm. 	
                mov  a,@r0
                mov  r0,a
                mov  r4,a
                rlc  a
                call $07C1		;0xFC1
                call $07C1
                call $07BD		;0xFDB
                call $07BD
                mov  a,@r1
                swap a
                xchd a,@r1
                dec  r1
                mov  a,@r1
                cpl  a
                add  a,r4
                jc   $0D29
                mov  r2,#$9
                mov  a,@r1
                rrc  a
                mov  @r1,a

                mov  r0,#$73
                mov  r1,#$49
                mov  r3,#$4
                clr  f0
                cpl  f0
                call $0798
                mov  r0,#$6F
                mov  r3,#$4
                inc  r0
                xch  a,@r0
                djnz r3,$0D37
                mov  r1,#$3A
                mov  a,@r1
                mov  r5,a
                add  a,#$F0
                jc   $0D4B
                mov  r1,#$33
                mov  a,@r1
                add  a,#$EF
                jnz  $0D4B
                mov  @r1,a
                mov  r1,#$48
                mov  a,@r1
                cpl  a
                add  a,r5
                mov  r1,#$31
                mov  a,@r1
                mov  r7,a
                djnz r7,$0D74
                mov  @r1,#$2
                inc  r2
                mov  a,#$6
                mov  r0,#$34
                xch  a,@r0
                djnz r2,$0D62
                dec  a
                mov  @r0,a
                jnz  $0D68
                mov  r1,#$33
                mov  @r1,#$23
                mov  r0,#$7B
                mov  a,@r0
                mov  r3,a
                dec  r0
                mov  a,@r0
                mov  r6,#$74
                call $07AB
                jmp  $0589
                clr  a
                jnc  $0D7E
                mov  a,r2
                jz   $0D7C
                anl  p1,#$BF
                mov  a,@r0
                add  a,r2
                mov  @r0,a
                mov  r0,#$7A
                mov  r1,#$46
                mov  r6,#$74
                mov  r7,#$4
                call $07A9
                mov  r0,#$5E
                mov  r1,#$73
                mov  r6,#$58
                mov  r7,#$4
                call $07A9
                mov  r0,#$57
                mov  r1,#$2C
                mov  a,@r1
                anl  a,#$38
                mov  r4,a
                jnz  $0DA5
                mov  r1,#$4F
                mov  r3,#$1
                cpl  f0
                call $0798
                mov  @r0,a
                mov  r1,#$4C
                mov  a,@r1
                swap a
                cpl  a
                mov  r2,a
                orl  a,#$F0
                inc  a
                mov  r1,#$58
                add  a,@r1
                jnc  $0DBA
                jnz  $0DBA
                inc  r1
                mov  a,r2
                orl  a,#$F
                add  a,@r1
                mov  r1,#$4D
                mov  a,@r1
                jf0  $0DC0
                inc  @r1
                jnz  $0DCE
                mov  @r1,a
                jnc  $0DCE
                mov  a,@r0
                add  a,#$5
                mov  @r0,a
                inc  r1
                mov  a,@r1
                cpl  a
                dec  r1
                mov  @r1,a
                mov  r2,#$4D
                mov  a,@r0
                cpl  a
                add  a,r2
                jc   $0DD7
                mov  a,r2
                mov  @r0,a
                mov  r0,#$6B
                mov  a,r4
                clr  f0
                cpl  f0
                jmp  $0600
	;; END detect knock

	;; filter target boost
                mov  a,@r0
                anl  a,#$3
                add  a,#$1
                mov  r6,a
                mov  r7,a
                mov  r0,#$53
                mov  r1,#$55
                call $05F1
                mov  a,r6
                mov  r7,a
                mov  r0,#$55
                mov  r1,#$51
                call $0608
                mov  @r0,a
                inc  r0
                xch  a,r3
                mov  @r0,a
                ret
	;; END filter target boost
	
                nop
                nop
                nop
                nop
                nop
                nop
                movp a,@a
                ret

	;; select PID function
                jb4  $0E82
                jb3  $0E30
                nop
                nop
                jmp  $05DE
	;; END select PID function

	;; exponential smoothing function
                mov  a,r7
                mov  r4,a
                mov  a,@r0
                mov  r2,a
                inc  r0
                mov  a,@r0
                mov  r3,a
                call $07CB
                mov  a,r4
                mov  r7,a
                mov  a,r3
                cpl  a
                add  a,#$1
                mov  r5,a
                mov  a,r2
                cpl  a
                addc a,#$0
                mov  r4,a
                mov  a,@r1
                mov  r2,a
                mov  r3,#$0
                call $07CB
                mov  a,@r0
                add  a,r5
                mov  r5,a
                dec  r0
                mov  a,@r0
                addc a,r4
                mov  r4,a
                mov  a,r5
                add  a,r3
                mov  r3,a
                mov  a,r4
                addc a,r2
                ret
	;; END exponential smoothing function

	;; PID derivative function. Location 52h contains actual boost and 51h contains target boost (from the map read routine). Here they are compared for the error value. At 0xe38, carry is set if actual boost was higher than target, i.e. overboost. 
                mov  r1,#$52
                mov  a,@r1
                cpl  a
                dec  r1
                add  a,@r1 
                mov  r1,#$64
                jnc  $0E56
                mov  r2,a
                cpl  a
                add  a,@r1
                mov  a,@r1
                jnz  $0E47
                inc  r1
                mov  a,@r1
                dec  r1
                jnz  $0E4B
                mov  a,r2
                mov  @r1,a
                mov  a,r2
                jc   $0E4B
                mov  @r1,a
                clr  c
                rlc  a
                jc   $0E58
                rlc  a
                jc   $0E58
                cpl  a
                add  a,@r1
                jnc  $0E58
                mov  @r1,#$0
                mov  a,@r1
                jz   $0E73
                mov  r0,#$6B
                mov  a,@r0
                rr   a
                rr   a
                anl  a,#$3
                add  a,#$1
                mov  r7,a
                mov  r0,#$65
                mov  a,@r0
                cpl  a
                inc  a
                add  a,@r1
                clr  c
                rrc  a
                clr  c
                rlc  a
                jb7  $0E7E
                djnz r7,$0E6E
                add  a,#$80
                mov  r0,#$62
                mov  @r0,a
                mov  r7,#$6
                mov  r0,#$65
                jmp  $05F1
                mov  a,#$7F
                jmp  $0673
	;; END PID derivative function

	;; PID proportional/integral function
                jb3  $0EF6
                mov  r1,#$52
                mov  a,@r1
                cpl  a
                inc  r1
                add  a,@r1
                mov  r4,a
                jc   $0E8F
                cpl  f0
                cpl  a
                add  a,#$FC
                mov  r1,#$6A
                mov  r0,#$61
                jc   $0E9B
                mov  a,@r1
                inc  @r1
                jnz  $0ED0
                dec  r1
                mov  a,@r1
                cpl  a
                inc  r1
                mov  @r1,a
                inc  @r0
                jf0  $0EA7
                mov  a,@r0
                add  a,#$FE
                mov  @r0,a
                mov  r1,#$62
                mov  a,@r1
                add  a,#$60
                jnc  $0EB0
                mov  @r0,#$80
                mov  a,#$BB
                mov  r3,a
                cpl  a
                add  a,@r0
                jc   $0EBE
                mov  a,#$44
                mov  r3,a
                cpl  a
                add  a,@r0
                jc   $0ED0
                mov  r1,#$67
                mov  a,@r1
                jnz  $0EC5
                clr  c
                cpl  c
                cpl  a
                jz   $0EC9
                inc  @r1
                jc   $0ECE
                cpl  a
                dec  a
                mov  @r1,a
                mov  a,r3
                mov  @r0,a
                mov  r1,#$6B
                mov  a,@r1
                jb4  $0ED9
                mov  a,r4
                clr  c
                rrc  a
                mov  r4,a
                mov  a,r4
                clr  c
                rlc  a
                mov  r4,a
                jb7  $0EE5
                add  a,#$C0
                jnc  $0EE5
                mov  r4,#$40
                mov  a,r4
                mov  r1,#$60
                mov  @r1,a
                add  a,@r0
                inc  r0
                add  a,@r0
                inc  r0
                jnc  $0EF1
                jb7  $0EF3
                mov  @r0,a
                ret
                mov  @r0,#$7F
                ret
                jmp  $0700
	;; END PID proportional/integral function
	
                nop
                nop
                nop
                nop
                nop
                nop
                movp a,@a
                ret

	;; final CV output calculation
                mov  r1,#$63
                mov  a,@r1
                mov  r6,a
                cpl  a
                jb7  $0F0A
                inc  a
                mov  r6,a
                cpl  f0
                mov  a,@r0
                orl  a,#$1F
                mov  r3,a
                sel  mb0
                call $0300
                sel  mb1
                mov  r3,#$B1
                jf0  $0F19
                cpl  a
                mov  r3,#$0
                mov  r4,a
                mov  r1,#$67
                mov  a,@r1
                clr  c
                rlc  a
                mov  r1,#$68
                add  a,@r1
                mov  r1,#$6F
                mov  @r1,a
                add  a,r4
                mov  r4,a
                jf0  $0F2A
                cpl  c
                jc   $0F33
                cpl  a
                add  a,r3
                jf0  $0F31
                cpl  c
                jc   $0F3F
                mov  a,r3
                mov  r4,a
                mov  r1,#$67
                mov  a,@r1
                dec  a
                dec  a
                jb7  $0F3E
                add  a,#$4
                mov  @r1,a
                mov  r2,#$22
                call $07D5
                mov  r1,#$43
                mov  a,@r1
                jz   $0F81
                add  a,#$FF
                jc   $0F4F
                mov  a,@r0
                jz   $0F81
                inc  r1
                mov  a,@r1
                add  a,#$C4
                jc   $0F81
                add  a,#$0
                jnc  $0F5C
                mov  a,@r0
                jz   $0F81
                mov  r1,#$4B
                mov  a,@r1
                mov  r2,a
                mov  r1,#$33		;33h is current blink code
                mov  a,@r1
                jz   $0F69
                add  a,#$EF		;EFh+11h=0
                jnz  $0F81
                mov  a,r4
                mov  @r0,a
                mov  r0,#$6F
                mov  r4,#$4
                inc  r0
                mov  a,@r0
                cpl  a
                add  a,r2
                jc   $0F7E
                mov  a,r2
                mov  @r0,a
                mov  r1,#$33
                mov  a,@r1
                jnz  $0F7E
                mov  @r1,#$11		;33h <- 11 (blink code 1-1)
                djnz r4,$0F6F
                ret
	;; END cv final output calculation

	;; limp mode function
                clr  a
                mov  r3,#$10
                mov  r1,#$57
                mov  @r1,a
                inc  r1
                djnz r3,$0F86
                mov  @r1,#$80
                mov  r1,#$61
                mov  @r1,#$80
                mov  r1,#$52
                mov  a,@r1
                inc  r1
                mov  @r1,a
                clr  a
                jmp  $076A
	;; END limp mode function

	;; count cycles for cylinders
                inc  @r1
                mov  a,@r1
                jnz  $0FA1
                inc  r1
                mov  a,@r1
                cpl  a
                dec  r1
                mov  @r1,a
                add  a,r3
                mov  a,@r0
                jnc  $0FA8
                jz   $0FA8
                dec  a
                ret
	;; end count cycles

	;; call exp. smoothing and rotate 16-bit values
                call $0608
                call $07B0
                call $07B0
                ret
                xch  a,r6
                mov  r0,a
                xch  a,r6
                xch  a,r3
                mov  r7,#$4
                xch  a,@r0
                inc  r0
                xch  a,@r0
                inc  r0
                djnz r7,$0FB6
                ret

                mov  a,r0
                clr  c
                rrc  a
                mov  r0,a
                xch  a,@r1
                rlc  a
                xch  a,@r1
                jnc  $0FC9
                add  a,r4
                xch  a,r4
                ret
                mov  a,r0
                ret
                mov  a,r2
                clr  c
                rrc  a
                mov  r2,a
                mov  a,r3
                rrc  a
                mov  r3,a
                djnz r7,$0FCB
                ret
	;; end call exp. smoothing/rotate values

	;; prep CV output
                mov  r0,#$41
                mov  a,r4
                add  a,#$40
                jnc  $0FDE
                mov  r4,#$BF
                ret
	;; end prep CV output
	
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                jb1  $0F32
                jb1  $0F43
                orl  a,#$43
                jb1  $0F32
                jb1  $0F20
                dis  i
