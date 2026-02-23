ex0int_t1	CODE	1000h
label333	CODE	1DF2h
label397	CODE	0FFFFh
label401	CODE	7A7Ch
label404	CODE	1040h
label405	CODE	111Eh
label407	CODE	1002h
label412	CODE	10FDh
label417	CODE	1189h
label424	CODE	0FC42h
label431	CODE	101Eh
label432	CODE	18Ah
label433	CODE	1201h
label434	CODE	11B7h
label438	CODE	0A012h
label440	CODE	120Fh
label443	CODE	0CA19h
label446	CODE	1272h
label451	CODE	4180h
label453	CODE	12B6h
label459	CODE	12EDh
label461	CODE	1344h
label463	CODE	134Eh
label472	CODE	406h
label473	CODE	3F14h
label475	CODE	13EBh
label476	CODE	1007h
label479	CODE	1411h
label480	CODE	122Eh
label483	CODE	1117h
label484	CODE	0F09h
label488	CODE	1497h
label489	CODE	6A6Ah
label490	CODE	1414h
label497	CODE	19DAh
label499	CODE	14E4h
label501	CODE	0A10h
label503	CODE	416h
label505	CODE	1595h
label506	CODE	38BEh
label507	CODE	14ECh
label510	CODE	152Ah
label511	CODE	152Ch
label512	CODE	31CDh
label513	CODE	15C7h
label515	CODE	15E4h
label516	CODE	0B03h
label517	CODE	605h
label521	CODE	100Dh
label522	CODE	0C100h
label528	CODE	1616h
label530	CODE	16B3h
label536	CODE	171Dh
label539	CODE	17A9h
label541	CODE	17F4h
label546	CODE	180Bh
label547	CODE	181Ah
label548	CODE	184Eh
label551	CODE	1797h
label553	CODE	17A3h
label557	CODE	1C82h
label559	CODE	1419h
label561	CODE	1937h
label563	CODE	196Ah
label564	CODE	1935h
label566	CODE	1923h
label574	CODE	1A0Ch
label578	CODE	1A23h
label579	CODE	1A32h
label580	CODE	1A66h
label583	CODE	19AFh
label585	CODE	19BBh
label590	CODE	1B37h

reset:	ORG	0h
	ljmp	rst_tar
ex0int:	clr	IE1
	ajmp	ex0int_t
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
t0int:	setb	90h
	clr	0Ah
	reti
	mov	R7, A
	mov	R7, A
	mov	R7, A
label450:ex1int:	inc	36h
	jnb	1Ch, ex1int_t
	reti
	mov	R7, A
	mov	R7, A
t1int:	djnz	2Ah, label3
	acall	label4
	ajmp	rst_tar
label4:	reti
serint:	jbc	TI, label5
	mov	R0, SBUF
	clr	TB8
	mov	SBUF, @R0
	clr	RI
label5:	clr	IE0
	reti
label3:	jbc	94h, label6
	setb	94h
	mov	TH1, 41h
	mov	TL1, 40h
	jb	1Ch, label7
	clr	IE0
label7:	reti
label6:	mov	TH1, 45h
	mov	TL1, 44h
	mov	41h, 43h
	mov	40h, 42h
	mov	37h, 36h
	mov	36h, #0h
	setb	17h
	jb	1Ch, label8
	clr	IE0
label8:	reti
ex1int_t:	djnz	2Bh, label9
	djnz	2Dh, ex0int_t0
	lcall	ex0int_t1
ex0int_t0:	anl	IE, #0EAh
	acall	ex0int_t2
	jnb	IE1, $
	inc	36h
	clr	IE1
	djnz	2Dh, ex0int_t3
	lcall	ex0int_t1
ex0int_t3:	jb	10h, ex0int_t4
ex0int_t6:	jb	INT1, ex0int_t5
	jnb	IE1, ex0int_t6
ex0int_t5:	cpl	91h
ex0int_t8:	jb	IE1, ex0int_t7
	ajmp	ex0int_t8
ex0int_t4:	jnb	IE1, $
	cpl	91h
ex0int_t7:	setb	EX1
	ajmp	ex0int_t9
label9:	djnz	2Dh, ex0int_t2
	lcall	ex0int_t1
ex0int_t2:	reti
ex0int_t9:	push	ACC
	push	PSW
	jb	91h, ex1int_t0
	clr	A
	mov	C, 10h
	addc	A, 30h
	rrc	A
	dec	A
	mov	10h, C
	clr	EX1
	add	A, 2Bh
	mov	2Bh, A
	setb	EX1
	clr	IE0
	setb	EX0
	pop	PSW
	pop	ACC
	ret
ex1int_t0:	push	DPH
	push	DPL
	push	B
	mov	DPTR, #1160h
	clr	A
	mov	C, 10h
	addc	A, 33h
	subb	A, 31h
	clr	C
	subb	A, 57h
	clr	C
	subb	A, 2Fh
	rrc	A
	dec	A
	mov	10h, C
	clr	EX1
	add	A, 2Bh
	mov	2Bh, A
	setb	EX1
	mov	A, #3h
	add	A, 35h
	movc	A, @A+DPTR
	clr	EX1
	add	A, 2Dh
	mov	2Dh, A
	setb	EX1
	acall	ex1int_t1
	clr	IE0
	setb	EX0
	mov	PSW, #18h
	ljmp	ex1int_t2
label318:	djnz	34h, ex1int_t3
	mov	R5, #2Dh
	jb	16h, ex1int_t4
	mov	R5, #2Bh
	jb	15h, ex1int_t4
label413:	mov	R5, #29h
	jb	14h, ex1int_t4
	mov	R5, #27h
ex1int_t4:	mov	A, R5
	movc	A, @A+DPTR
	mov	34h, A
	inc	R5
	mov	A, R5
	movc	A, @A+DPTR
	mov	R5, A
	mov	A, 32h
	mov	R6, A
	mov	R7, 31h
	clr	C
	subb	A, R7
	clr	C
	jnb	0E7h, ex1int_t5
	cpl	A
	inc	A
	subb	A, R5
	mov	A, R6
	jc	ex1int_t6
	mov	A, R7
	subb	A, R5
	ajmp	ex1int_t6
ex1int_t5:	subb	A, R5
	mov	A, R6
	jc	ex1int_t6
	mov	A, R7
	add	A, R5
ex1int_t6:	mov	31h, A
ex1int_t3:	mov	A, #1h
	movc	A, @A+DPTR
	inc	35h
	cjne	A, 35h, ex1int_t7
	mov	35h, #0h
	mov	DPTR, #000h
	movx	@DPTR, A
	movx	@DPTR, A
	movx	@DPTR, A
	movx	@DPTR, A
	mov	DPTR, #1160h
	ajmp	ex1int_t8
ex1int_t7:	jb	1Ah, ex1int_t8
	jbc	0Fh, ex1int_t9
	ajmp	label30
ex1int_t9:	mov	B, #40h
	mov	A, 4Ch
	mul	AB
	mov	R6, A
	mov	R7, B
	jnb	0Ah, label31
	clr	TR0
	clr	C
	mov	A, TL0
	subb	A, R6
	mov	TL0, A
	mov	A, TH0
	subb	A, R7
	mov	TH0, A
	ajmp	label32
ex1int_t8:	clr	C
	mov	A, #11h
	movc	A, @A+DPTR
	subb	A, 37h
	orl	C, 1Dh
	jc	label33
	mov	R6, 4Ah
	mov	R7, 4Bh
	ljmp	label34
label376:	jb	1Ah, label31
	jnb	0Dh, label35
	mov	A, 4Dh
	cjne	A, #10h, label36
label36:	jc	label37
	clr	0Dh
	jnb	16h, label38
	clr	16h
	mov	34h, #1h
label38:	ajmp	label35
label37:	mov	DPTR, #1140h
	jb	0Eh, label39
	add	A, #10h
label39:	movc	A, @A+DPTR
	cjne	A, #40h, label40
	jnb	16h, label40
	clr	16h
	mov	34h, #1h
label40:	acall	label41
	mov	A, #2h
	acall	label42
label35:	jnb	0Fh, label31
	clr	0Fh
	mov	B, #40h
	mov	A, 4Ch
	mul	AB
	add	A, R6
	mov	R6, A
	mov	A, B
	addc	A, R7
	mov	R7, A
label31:	ljmp	label43
label357:	mov	A, 54h
	mov	B, #5h
	mul	AB
	clr	TR0
	add	A, R6
	cpl	A
	mov	TL0, A
	mov	A, B
	addc	A, R7
	cpl	A
	mov	TH0, A
label32:	clr	EA
	clr	90h
	setb	0Ah
	setb	TR0
	setb	ET0
	clr	IE0
	setb	EA
label33:	mov	A, 4Dh
	jb	0E7h, label30
	inc	4Dh
label30:	pop	B
	pop	DPL
	pop	DPH
	pop	PSW
	pop	ACC
	ret
ex0int_t:	push	PSW
	mov	C, INT1
	orl	C, IE1
	mov	2Bh, 2Ch
	mov	2Dh, 2Eh
	jc	label44
	mov	C, 11h
	ajmp	label45
label44:	anl	C, /11h
	jc	label45
	inc	2Bh
label45:	mov	10h, C
	djnz	2Bh, label46
	inc	2Bh
	dec	30h
	dec	30h
label46:	mov	35h, #0h
	mov	C, 13h
	mov	91h, C
label398:	pop	PSW
	reti
ex1int_t1:	mov	A, #2h
	movc	A, @A+DPTR
	mov	2Eh, A
	setb	13h
	mov	A, #0h
	movc	A, @A+DPTR
	setb	C
	subb	A, 31h
	clr	C
	subb	A, 57h
	clr	C
	subb	A, 2Fh
	jnc	label47
	clr	C
label48:	clr	13h
	addc	A, 2Fh
label47:	clr	C
	rrc	A
	jz	label48
	mov	2Ch, A
	mov	11h, C
	mov	A, #7h
	add	A, 35h
	movc	A, @A+DPTR
	add	A, 31h
	add	A, 57h
	mov	33h, A
	mov	30h, 2Fh
	ret
rst_tar:mov	IE, #80h
	mov	P1, #0FFh
	mov	P3, #0FFh
	mov	TMOD, #11h
	mov	IP, #2h
	mov	TCON, #5h
	mov	SCON, #90h
	mov	SP, #63h
	mov	DPTR, #1160h
	mov	PSW, #0h
	mov	R0, #64h
	clr	A
	ljmp	label49
label50:	mov	@R0, A
	djnz	R0, label50
	ljmp	label51
label372:	setb	1Ch
	mov	R0, #0h
	mov	R1, #40h
	lcall	label52
	setb	TR1
	setb	ET1
	setb	EX1
	setb	TF1
	jnb	17h, $
	clr	17h
	jnb	17h, $
	setb	1Ah
	lcall	label53
	mov	A, #0Eh
	movc	A, @A+DPTR
	mov	R0, A
label55:	acall	label54
	djnz	R0, label55
	ljmp	label56
	clr	IE0
	mov	P2, #0h
	movx	@R0, A
	movx	@R0, A
	movx	@R0, A
	movx	@R0, A
	mov	A, #0Dh
	movc	A, @A+DPTR
label58:	mov	2Ah, A
	jnb	17h, label57
	clr	17h
	movx	@R0, A
label57:	jnb	IE0, label58
	setb	EX0
	clr	1Ch
	ljmp	label59
label54:	jnb	INT1, $
	jb	INT1, $
	ret
label368:	mov	P2, #0h
	movx	A, @R0
	mov	R2, #32h
	mov	R0, #10h
	mov	R3, #8h
	movx	A, @R0
label60:	djnz	R2, $
	inc	P2
	movx	A, @R0
	mov	@R0, A
	inc	R0
	mov	R2, #32h
	movx	A, @R0
	djnz	R3, label60
	mov	A, 12h
	cpl	A
	mov	R4, A
	mov	R2, #1h
	acall	label61
	mov	12h, A
	mov	A, 13h
	cpl	A
	mov	R4, A
	acall	label61
	mov	13h, A
	mov	R0, #38h
	mov	R1, #3Ch
	mov	R2, #4h
	mov	R3, #33h
label64:	jb	1Ch, label62
	mov	A, @R0
	dec	A
	mov	@R0, A
	jnz	label63
label62:	mov	A, R3
	movc	A, @A+DPTR
	mov	@R0, A
	mov	A, @R1
	jz	label63
	dec	A
	mov	@R1, A
label63:	inc	R0
	inc	R1
	inc	R3
	djnz	R2, label64
label366:	mov	A, #18h
label543:	movc	A, @A+DPTR
	cjne	A, 37h, label65
label65:	jc	label66
	jb	1Ch, label66
	mov	R5, 55h
	mov	A, 37h
	clr	C
	subb	A, R5
	mov	F0, C
	jnc	label67
	cpl	A
	inc	A
label67:	xch	A, B
	mov	A, #15h
	movc	A, @A+DPTR
	mul	AB
	mov	R6, A
	jb	0E7h, label68
	xch	A, B
	jz	label69
label68:	mov	R6, #7Fh
label69:	mov	A, 56h
	jnb	F0, label70
	clr	C
	subb	A, R6
	jnc	label71
	add	A, #80h
	cjne	R5, #0h, label72
	sjmp	label71
label72:	dec	55h
	sjmp	label71
label70:	add	A, R6
	jnc	label71
	add	A, #80h
	cjne	R5, #0FFh, label73
	sjmp	label71
label73:	inc	55h
label71:	mov	56h, A
	mov	A, #19h
	movc	A, @A+DPTR
	cjne	A, 49h, label74
label74:	mov	A, #0h
	jc	label75
	mov	A, 55h
	cjne	A, 37h, label76
	sjmp	label77
label76:	jc	label78
	mov	A, #16h
	movc	A, @A+DPTR
	sjmp	label75
label77:	mov	A, #0h
	sjmp	label75
label78:	mov	A, #17h
	movc	A, @A+DPTR
label75:	mov	57h, A
	sjmp	label79
label66:	mov	55h, 37h
	mov	56h, #80h
	mov	57h, #0h
label79:	jnb	1Ah, label80
	mov	R5, #0h
	mov	A, #12h
	movc	A, @A+DPTR
	mov	49h, A
	mov	B, #19h
	mul	AB
	mov	R6, A
	mov	R7, B
	mov	A, #1h
	movc	A, @A+DPTR
	mov	B, 49h
	mul	AB
	mov	B, #19h
	mul	AB
	mov	46h, B
	mov	47h, A
	mov	48h, #0h
	ajmp	label81
label80:	mov	R3, 37h
	mov	A, #32h
	mov	B, R3
	div	AB
	mov	R7, A
	acall	label82
	mov	R6, A
	mov	A, 10h
	mov	B, #20h
	div	AB
	mov	R2, A
	mov	R3, B
	mov	DPTR, #10F4h
	movc	A, @A+DPTR
	acall	label41
	mov	DPTR, #10FCh
	mov	A, R2
	movc	A, @A+DPTR
	acall	label42
	mov	DPTR, #1104h
	mov	A, R3
	movc	A, @A+DPTR
	acall	label41
	mov	DPTR, #1160h
	mov	A, #13h
	acall	label83
	mov	A, #14h
	acall	label84
	mov	A, R6
	mov	R3, A
	mov	A, R7
	mov	R4, A
	mov	R2, #1Bh
	lcall	label61
	mov	R5, A
	mov	R2, 46h
	mov	R1, 47h
	mov	R0, 48h
	lcall	label85
	mov	46h, R2
	mov	47h, R1
	mov	48h, R0
	mov	R7, 46h
	mov	R6, 47h
	mov	A, #0A4h
	acall	label41
	mov	A, #4h
	acall	label42
	mov	49h, R7
	mov	R7, 46h
	mov	R6, 47h
label81:	ljmp	label86
label377:	push	50h
	ljmp	label87
ex0int_t03:	mov	R0, 4Eh
	mov	R1, 4Fh
	acall	label88
	mov	A, 50h
	acall	label42
	pop	50h
	lcall	label89
	mov	R2, #1Ah
	acall	label61
label492:	mov	54h, A
	clr	EA
	mov	4Bh, R7
	mov	4Ah, R6
	clr	IE0
	setb	EA
	lcall	label90
	jnb	1Eh, label91
	mov	R1, #50h
label92:	setb	ES
	djnz	R1, label92
	clr	ES
label91:	ljmp	label93
label83:	setb	F0
label84:	movc	A, @A+DPTR
	mov	B, #19h
	mul	AB
	mov	R3, A
	subb	A, R6
	mov	A, B
	subb	A, R7
	jbc	F0, label94
	cpl	C
label94:	jnc	label95
	mov	A, R3
	mov	R6, A
	mov	A, B
	mov	R7, A
label95:	ret
label88:	mov	A, R0
	mov	B, R6
	mul	AB
	mov	R5, B
	mov	A, R1
	mov	B, R6
	mul	AB
	add	A, R5
	mov	R5, A
	clr	A
	addc	A, B
	mov	R6, A
	mov	A, R0
	mov	B, R7
	mul	AB
	add	A, R5
	mov	R5, A
	mov	A, R6
	addc	A, B
	mov	R6, A
	clr	A
	rlc	A
	xch	A, R7
	mov	B, A
	mov	A, R1
	mul	AB
	add	A, R6
	mov	R6, A
	mov	A, R7
	addc	A, B
	mov	R7, A
	ret
	jb	1Ah, label96
	jb	18h, label96
	clr	C
	mov	A, 10h
	subb	A, 53h
	jc	label96
	mov	3h, A
	mov	A, #37h
	movc	A, @A+DPTR
	clr	C
	subb	A, 37h
	jnc	label97
	mov	B, #0h
	ajmp	label98
label97:	mov	R2, #1Ch
	lcall	label61
	mov	B, A
	lcall	label61
	mul	AB
label98:	jb	0Fh, label99
	mov	4Ch, B
label99:	mov	R2, #1Eh
	lcall	label61
	jz	label96
	mov	B, A
	mov	A, 4Ch
	jz	ex0int_t00
	setb	0Fh
ex0int_t00:	lcall	label61
	mul	AB
	acall	label61
	mul	AB
	mov	A, B
	cjne	A, 3Dh, ex0int_t01
ex0int_t01:	jc	label96
	mov	3Dh, A
label96:	mov	53h, 52h
	mov	52h, 51h
	mov	51h, 10h
	mov	A, 3Dh
	lcall	ex0int_t02
	ajmp	ex0int_t03
label41:	mov	R5, A
	mov	B, R6
	mul	AB
	mov	R6, B
	xch	A, R5
	mov	B, R7
	mul	AB
	add	A, R6
	mov	R6, A
	clr	A
	addc	A, B
	mov	R7, A
	ret
label82:	clr	A
	mov	R4, #8h
	clr	C
ex0int_t06:	rlc	A
	xch	A, B
	rlc	A
	jbc	CY, ex0int_t04
	subb	A, R3
	jnc	ex0int_t05
	add	A, R3
ex0int_t05:	xch	A, B
	djnz	R4, ex0int_t06
	rlc	A
	cpl	A
	ret
ex0int_t04:	subb	A, R3
	clr	C
	xch	A, B
	djnz	R4, ex0int_t06
	rlc	A
	cpl	A
	ret
label42:	jz	ex0int_t07
	xch	A, R7
	jnb	0E7h, ex0int_t08
	xch	A, R7
ex0int_t07:	ret
ex0int_t08:	clr	C
	xch	A, R5
	rlc	A
	xch	A, R5
	xch	A, R6
	rlc	A
	xch	A, R6
	rlc	A
	xch	A, R7
	dec	A
	ajmp	label42
label61:	push	B
	mov	DPTR, #1090h
	mov	A, R2
	inc	R2
	setb	RS0
	movc	A, @A+DPTR
	cjne	A, #0FFh, ex0int_t09
	setb	2Ah
	ajmp	ex0int_t10
ex0int_t09:	clr	2Ah
	mov	C, 0E0h
	clr	0E0h
	mov	DPTR, #11E0h
	mov	R7, A
	inc	R7
	movc	A, @A+DPTR
	xch	A, R7
	movc	A, @A+DPTR
	mov	DPL, A
	mov	DPH, R7
	jc	ex0int_t11
	acall	ex0int_t12
	acall	ex0int_t13
	ajmp	ex0int_t10
ex0int_t11:	acall	ex0int_t12
	mov	B, R1
	mov	A, R0
	mov	R6, A
	mov	A, R3
	mov	R7, A
	acall	ex0int_t12
	mov	A, R2
	mul	AB
	add	A, R1
	mov	R1, A
	mov	A, R7
	jz	ex0int_t14
	acall	ex0int_t13
ex0int_t14:	xch	A, R2
	cpl	A
	inc	A
	add	A, R1
	mov	R1, A
	acall	ex0int_t13
	xch	A, R7
	jnz	ex0int_t15
	xch	A, R7
	ajmp	ex0int_t10
ex0int_t15:	mov	R3, A
	mov	B, R6
	xch	A, R7
	mov	R5, A
	mov	A, R2
	acall	ex0int_t16
ex0int_t10:	clr	RS0
	pop	B
	mov	DPTR, #1160h
	ret
ex0int_t12:	clr	A
	movc	A, @A+DPTR
	mov	R0, A
	inc	DPTR
	clr	A
	movc	A, @A+DPTR
	mov	R2, A
	mov	R1, A
	mov	A, @R0
	mov	R0, A
ex0int_t18:	mov	A, R1
	movc	A, @A+DPTR
	add	A, R0
	mov	R0, A
	jc	ex0int_t17
	djnz	R1, ex0int_t18
	inc	R1
	clr	A
	ajmp	ex0int_t19
ex0int_t17:	mov	A, R1
	xrl	A, R2
	jz	ex0int_t19
	mov	A, R1
	movc	A, @A+DPTR
ex0int_t19:	mov	R3, A
	inc	DPTR
	mov	A, R2
	add	A, DPL
	mov	DPL, A
	clr	A
	addc	A, DPH
	mov	DPH, A
	ret
ex0int_t13:	mov	A, R3
	jnz	ex0int_t20
	mov	A, R1
	dec	A
	movc	A, @A+DPTR
	ret
ex0int_t20:	mov	B, R0
	mov	A, R1
	dec	A
	movc	A, @A+DPTR
	mov	R5, A
	mov	A, R1
	movc	A, @A+DPTR
ex0int_t16:	clr	C
	subb	A, R5
	mov	F0, C
	jnc	ex0int_t21
	cpl	A
	inc	A
ex0int_t21:	mul	AB
	ajmp	ex0int_t22
ex0int_t28:	xch	A, B
	clr	C
	rlc	A
	jc	ex0int_t23
	subb	A, R3
	cpl	C
ex0int_t23:	clr	A
	addc	A, B
	jnb	F0, ex0int_t24
	cpl	A
	inc	A
ex0int_t24:	add	A, R5
	ret
ex0int_t38:	setb	RS0
	acall	ex0int_t12
	dec	R1
	mov	A, R1
	movc	A, @A+DPTR
	mov	DPTR, #1160h
	clr	RS0
	ret
ex0int_t22:	mov	R4, #8h
	clr	C
ex0int_t27:	rlc	A
	xch	A, B
	rlc	A
	jbc	CY, ex0int_t25
	subb	A, R3
	jnc	ex0int_t26
	add	A, R3
ex0int_t26:	xch	A, B
	djnz	R4, ex0int_t27
	rlc	A
	cpl	A
	ajmp	ex0int_t28
ex0int_t25:	subb	A, R3
	clr	C
	xch	A, B
	djnz	R4, ex0int_t27
	rlc	A
	cpl	A
	ajmp	ex0int_t28
label85:	mov	A, R3
	clr	C
	subb	A, R1
	mov	R6, A
	mov	A, R4
	subb	A, R2
	mov	R7, A
	jnz	ex0int_t29
	mov	A, R6
	jnz	ex0int_t29
	mov	R0, A
ex0int_t29:	jc	ex0int_t30
	mov	A, R5
	acall	label41
	clr	C
	mov	A, R5
	add	A, R0
	mov	R0, A
	mov	A, R6
	addc	A, R1
	mov	R1, A
	mov	A, R7
	addc	A, R2
	mov	R2, A
	ljmp	ex0int_t31
ex0int_t30:	clr	C
	mov	A, R6
	cpl	A
	add	A, #1h
	mov	R6, A
	mov	A, R7
	cpl	A
	addc	A, #0h
	mov	R7, A
	mov	A, R5
	acall	label41
	clr	C
	mov	A, R0
	subb	A, R5
	mov	R0, A
	mov	A, R1
	subb	A, R6
	mov	R1, A
	mov	A, R2
	subb	A, R7
	mov	R2, A
ex0int_t31:	ret
ex0int_t53:	clr	A
	mov	C, 96h
	rlc	A
	sjmp	ex0int_t32
ex0int_t48:	clr	A
ex0int_t32:	mov	C, T0
	rlc	A
	add	A, R2
	mov	R2, A
	ret
label358:	acall	ex0int_t33
ex0int_t33:	mov	A, #0Fh
	movc	A, @A+DPTR
	mov	R0, #0h
	mov	R1, A
ex0int_t35:	acall	ex0int_t34
	jnb	INT1, ex0int_t35
ex0int_t36:	acall	ex0int_t34
	jb	INT1, ex0int_t36
	ret
ex0int_t34:	djnz	R0, ex0int_t37
	djnz	R1, ex0int_t37
	ajmp	rst_tar
ex0int_t37:	ret
label361:	mov	DPTR, #1124h
	acall	ex0int_t38
	rrc	A
	mov	19h, C
	rrc	A
	mov	18h, C
	ljmp	ex0int_t39
	mov	A, 15h
	cjne	A, #80h, ex0int_t40
ex0int_t40:	cpl	C
	mov	1Bh, C
	mov	A, 14h
	cjne	A, #80h, ex0int_t41
ex0int_t41:	cpl	C
	mov	2Eh, C
	mov	A, #10h
	movc	A, @A+DPTR
	clr	C
	subb	A, 37h
	jnc	ex0int_t42
	mov	R2, #3h
	acall	label61
	clr	C
	subb	A, 37h
	jc	ex0int_t43
	ret
ex0int_t42:	setb	1Ah
	ret
ex0int_t43:	clr	1Ah
	ret
label362:	mov	R5, #0h
	clr	C
	jnb	1Ah, ex0int_t44
	mov	R2, #4h
	acall	ex0int_t45
	ajmp	ex0int_t46
ex0int_t44:	jnb	18h, ex0int_t47
	mov	R2, #7h
	acall	ex0int_t45
	acall	ex0int_t48
	ajmp	ex0int_t49
ex0int_t47:	jnb	19h, ex0int_t50
	mov	R2, #0Bh
	acall	ex0int_t45
	acall	ex0int_t48
	ajmp	ex0int_t51
ex0int_t50:	mov	R2, #11h
	mov	A, #20h
	movc	A, @A+DPTR
	subb	A, 49h
	jc	ex0int_t52
	acall	ex0int_t45
	acall	ex0int_t53
	ajmp	ex0int_t49
ex0int_t52:	dec	R2
	acall	ex0int_t45
	acall	ex0int_t53
ex0int_t51:	mov	DPTR, #112Eh
	acall	ex0int_t38
	jnb	0E2h, ex0int_t49
	mov	A, #21h
	movc	A, @A+DPTR
	clr	C
	subb	A, 37h
	jnc	ex0int_t49
	mov	A, #22h
	movc	A, @A+DPTR
	add	A, R5
	mov	R5, A
ex0int_t49:	acall	label61
	add	A, R5
	clr	C
	subb	A, #14h
	mov	R5, A
ex0int_t46:	ljmp	ex0int_t54
	mov	R2, #17h
	acall	label61
	add	A, R5
	clr	C
	subb	A, #14h
	mov	R5, A
	mov	R0, A
	mov	C, 0E7h
	mov	A, #23h
	jnc	ex0int_t55
	inc	A
ex0int_t55:	movc	A, @A+DPTR
	mov	R1, A
	jnc	ex0int_t56
	xch	A, R0
ex0int_t56:	clr	C
	subb	A, R0
	jnc	ex0int_t57
	mov	A, R1
	mov	R5, A
ex0int_t57:	mov	A, R5
	mov	C, 0E7h
	rrc	A
	mov	R5, A
	ljmp	ex0int_t58
label321:	jb	1Ah, ex0int_t59
	jnb	18h, ex0int_t60
	mov	R2, #19h
	acall	label61
	clr	C
	subb	A, 37h
	jnc	ex0int_t61
	mov	R3, A
	mov	A, #32h
	jb	0Eh, ex0int_t62
	mov	A, #31h
ex0int_t62:	movc	A, @A+DPTR
	add	A, R3
	jc	ex0int_t59
	setb	15h
	mov	A, R5
	cjne	A, 31h, ex0int_t59
	setb	1Dh
	clr	15h
	mov	32h, A
	mov	31h, A
	ret
ex0int_t60:	clr	0Eh
	clr	15h
	jnb	1Dh, ex0int_t59
	mov	A, #2Fh
	movc	A, @A+DPTR
	ajmp	ex0int_t63
ex0int_t61:	clr	15h
	jnb	1Dh, ex0int_t59
	setb	0Eh
	mov	A, #30h
	movc	A, @A+DPTR
ex0int_t63:	add	A, 31h
	mov	31h, A
	mov	32h, R5
	clr	C
	mov	A, R5
	subb	A, 31h
	jnb	0E7h, ex0int_t64
	mov	34h, #1h
	mov	4Dh, #0h
	setb	0Dh
	clr	1Dh
	ajmp	ex0int_t59
ex0int_t64:	mov	A, #2Dh
	movc	A, @A+DPTR
	mov	34h, A
	setb	16h
	mov	4Dh, #0h
	setb	0Dh
	clr	1Dh
	ret
ex0int_t59:	clr	C
	mov	A, #25h
	movc	A, @A+DPTR
	subb	A, 49h
	jc	ex0int_t65
	mov	A, #26h
	movc	A, @A+DPTR
	subb	A, 37h
	cpl	C
ex0int_t65:	jnb	14h, ex0int_t66
	cpl	C
ex0int_t66:	jnc	ex0int_t67
	cpl	14h
	jb	16h, ex0int_t67
	jb	15h, ex0int_t67
	mov	34h, #1h
ex0int_t67:	mov	A, R5
	jnb	1Ch, ex0int_t68
	mov	31h, A
	mov	34h, #1h
ex0int_t68:	mov	A, R5
	jnb	16h, ex0int_t69
	clr	C
	subb	A, 31h
	jnb	0E7h, ex0int_t69
	clr	16h
	mov	34h, #1h
ex0int_t69:	mov	32h, R5
	ret
ex0int_t45:	acall	label61
	jb	2Ah, ex0int_t70
	add	A, R5
	clr	C
	subb	A, #14h
	mov	R5, A
	ajmp	ex0int_t45
ex0int_t70:	ret
label363:	mov	R2, #18h
	acall	label61
	mov	2Fh, A
	ret
label364:	mov	DPTR, #112Eh
	acall	ex0int_t38
	clr	0E2h
	add	A, #1Bh
	movc	A, @A+DPTR
	mov	B, A
	mov	R2, #21h
	acall	label61
	mul	AB
	mov	R7, B
	mov	R6, A
	mov	50h, #2h
	acall	label61
	lcall	ex0int_t71
	jnb	1Ah, ex0int_t72
	mov	R2, #2Fh
	mov	A, #1Fh
	movc	A, @A+DPTR
	cjne	A, 13h, ex0int_t73
ex0int_t73:	jnc	ex0int_t74
	inc	R2
ex0int_t74:	acall	label61
	mov	3Ch, A
	mov	R2, #31h
	acall	label61
	mov	R4, A
	mov	R3, #5h
	mov	R1, #8h
	jb	0Ch, ex0int_t75
	acall	label61
	clr	C
	subb	A, 37h
	jc	ex0int_t76
	mov	A, #1Ah
	movc	A, @A+DPTR
	subb	A, 4Dh
	jnc	ex0int_t77
ex0int_t76:	setb	0Ch
	mov	4Dh, #0h
ex0int_t75:	mov	R2, #33h
	lcall	label61
	mov	B, A
	lcall	label61
	mul	AB
	mov	A, R4
ex0int_t79:	jb	0E7h, ex0int_t78
	rl	A
	xch	A, R1
	rl	A
	xch	A, R1
	dec	R3
	sjmp	ex0int_t79
ex0int_t78:	mul	AB
	mov	R4, B
	jnb	0E7h, ex0int_t77
	inc	R4
ex0int_t77:	mov	A, R4
	cjne	A, 1h, ex0int_t80
ex0int_t80:	jc	ex0int_t81
	lcall	label41
	mov	A, 50h
	add	A, R3
	lcall	label42
	mov	50h, A
ex0int_t81:	ljmp	ex0int_t82
ex0int_t72:	lcall	ex0int_t48
	lcall	label61
	mov	B, A
	mov	R2, #25h
	jnb	18h, ex0int_t83
	inc	R2
ex0int_t83:	lcall	label61
	mul	AB
	mov	A, B
	lcall	ex0int_t02
	mov	A, 3Ch
	lcall	ex0int_t02
	mov	R2, #27h
	lcall	ex0int_t48
	jb	18h, ex0int_t84
	mov	R2, #29h
	lcall	ex0int_t48
	jb	19h, ex0int_t84
	mov	R2, #2Bh
	lcall	ex0int_t53
ex0int_t84:	lcall	label61
	lcall	ex0int_t71
ex0int_t82:	ljmp	ex0int_t85
	mov	4Eh, R6
	mov	4Fh, R7
	ljmp	ex0int_t86
ex0int_t02:	jz	ex0int_t87
	add	A, #80h
	jnc	ex0int_t71
	rrc	A
	inc	50h
ex0int_t71:	lcall	label41
	mov	A, 50h
	inc	A
	lcall	label42
	mov	50h, A
ex0int_t87:	ret
label386:	ljmp	ex0int_t88
label389:	jnb	1Ch, ex0int_t89
	lcall	ex0int_t90
	mov	20h, #0h
	setb	6h
ex0int_t89:	jbc	1h, ex0int_t91
	setb	1h
	ret
ex0int_t91:	jb	1Ah, ex0int_t92
	jb	1Dh, ex0int_t93
	mov	C, 19h
	anl	C, 18h
	jc	ex0int_t94
	jb	18h, ex0int_t95
	lcall	ex0int_t90
	setb	6h
	clr	0h
	ajmp	ex0int_t96
ex0int_t92:	setb	6h
	setb	0h
	mov	R2, #35h
	lcall	label61
	mov	7Fh, A
	ajmp	ex0int_t97
ex0int_t93:	setb	6h
	clr	0h
	lcall	ex0int_t90
	ajmp	ex0int_t96
ex0int_t94:	mov	A, #3Ch
	movc	A, @A+DPTR
	clr	C
	rrc	A
	mov	R1, A
	mov	R0, #0h
	ajmp	label52
ex0int_t95:	ljmp	ex0int_t98
label390:	jnb	1Bh, ex0int_t99
	mov	R2, #36h
	lcall	label61
	mov	7Fh, A
	sjmp	ex0int_t97
ex0int_t99:	mov	R2, #37h
	lcall	label61
	mov	B, A
	jb	T1, ex1int_t00
	mov	A, #39h
	movc	A, @A+DPTR
	cjne	A, B, ex1int_t01
ex1int_t01:	jc	ex1int_t00
	mov	B, A
ex1int_t00:	jnb	6h, ex1int_t02
	ljmp	ex1int_t03
label391:	jb	0h, ex1int_t04
	mov	7Fh, 37h
ex1int_t04:	mov	7Ch, #1h
	clr	6h
ex1int_t02:	mov	A, B
	cjne	A, 7Fh, ex1int_t05
ex1int_t05:	jnc	ex1int_t06
	djnz	7Ch, ex1int_t07
	dec	7Fh
	mov	A, #3Fh
	mov	C, 0h
	addc	A, #0h
	movc	A, @A+DPTR
	mov	7Ch, A
ex1int_t07:	mov	B, 7Fh
ex1int_t06:	mov	7Fh, B
ex0int_t97:	mov	A, #38h
	movc	A, @A+DPTR
	add	A, 37h
	setb	C
	subb	A, 7Fh
	jnc	ex1int_t08
	mov	A, #80h
	subb	A, 7Eh
	jc	ex1int_t08
	acall	ex0int_t90
ex1int_t08:	ljmp	ex1int_t09
label392:	mov	A, 7Fh
	clr	C
	subb	A, 37h
	mov	2h, C
	jnc	ex1int_t10
	clr	3h
	cpl	A
	inc	A
	sjmp	ex1int_t11
ex1int_t10:	clr	4h
ex1int_t11:	mov	R3, A
	mov	R1, 7Eh
	mov	R0, 7Dh
	jbc	3h, ex1int_t12
	jbc	4h, ex1int_t12
	mov	R2, #38h
	jnb	2h, ex1int_t13
	inc	R2
ex1int_t13:	lcall	label61
	mov	B, A
	mov	A, R3
	lcall	ex1int_t14
	mov	7Dh, R0
	mov	7Eh, R1
ex1int_t12:	jb	2h, ex1int_t15
	mov	R2, #3Ah
	lcall	label61
	mov	B, A
	mov	A, R3
	cjne	A, #3Fh, ex1int_t16
ex1int_t16:	jc	ex1int_t17
	mov	A, 3Fh
ex1int_t17:	rl	A
	rl	A
	lcall	ex1int_t14
ex1int_t15:	ljmp	ex1int_t18
	mov	A, R1
	clr	C
	jnb	0E7h, ex1int_t19
	jb	1Ah, ex1int_t20
	mov	A, #3Dh
	movc	A, @A+DPTR
	rrc	A
	add	A, #80h
	cjne	A, 1h, ex1int_t21
ex1int_t21:	jnc	ex1int_t20
	mov	R1, A
	setb	3h
	sjmp	ex1int_t20
ex1int_t19:	mov	A, #3Eh
	movc	A, @A+DPTR
	rrc	A
	cpl	A
	add	A, #80h
	cjne	A, 1h, ex1int_t22
ex1int_t22:	jc	ex1int_t20
	mov	R1, A
	setb	4h
ex1int_t20:	mov	R2, #3Dh
	lcall	label61
	cjne	A, 49h, ex1int_t23
ex1int_t23:	jc	ex1int_t24
	setb	4h
ex1int_t24:	mov	A, R1
	clr	C
	subb	A, #80h
	mov	5h, C
	mov	R1, A
ex0int_t96:	ljmp	ex1int_t25
label394:	mov	R2, #3Ch
	lcall	label61
	mov	B, A
	jnb	1Dh, ex1int_t26
	mov	R2, #3Bh
	lcall	label61
	acall	ex1int_t27
ex1int_t26:	jnb	1Bh, ex1int_t28
	mov	A, #3Bh
	movc	A, @A+DPTR
	acall	ex1int_t27
ex1int_t28:	jb	T1, ex1int_t29
	mov	A, #3Ah
	movc	A, @A+DPTR
	acall	ex1int_t27
ex1int_t29:	mov	A, #80h
	mul	AB
	ljmp	ex1int_t30
label395:	add	A, R0
	mov	R0, A
	mov	A, B
	addc	A, R1
	mov	R1, A
	jnb	0E7h, label52
	jnb	5h, ex1int_t31
	mov	R1, #0h
	mov	R0, #0h
	sjmp	label52
ex1int_t31:	mov	R1, #7Fh
	mov	R0, #0FFh
label52:	ljmp	ex1int_t32
	mov	R7, 1h
label518:	mov	R6, 0h
	mov	A, #1h
	lcall	label42
	mov	7Bh, R7
	mov	A, #41h
	movc	A, @A+DPTR
	lcall	label41
	mov	A, #42h
	movc	A, @A+DPTR
	add	A, R7
	mov	R7, A
	mov	A, #0Bh
	movc	A, @A+DPTR
	mov	R0, A
	mov	A, #0Ch
	movc	A, @A+DPTR
	mov	R1, A
	lcall	label88
	mov	A, R6
	cpl	A
	mov	R0, A
	mov	A, R7
	cpl	A
	mov	R1, A
	mov	A, #0Bh
	movc	A, @A+DPTR
	mov	R3, A
	mov	A, #0Ch
	movc	A, @A+DPTR
	mov	R4, A
	setb	C
	mov	A, R6
	subb	A, R3
	xch	A, R7
	subb	A, R4
	mov	R3, A
	clr	ET1
	mov	44h, R7
	mov	45h, R3
	mov	42h, R0
	mov	43h, R1
	setb	ET1
	ret
ex0int_t90:	mov	7Eh, #80h
	mov	7Dh, #0h
	mov	R1, #0h
	mov	R0, #0h
	ret
ex1int_t27:	add	A, B
	jnc	ex1int_t33
	mov	A, 0FFh
ex1int_t33:	mov	B, A
	ret
	mov	R2, #3Eh
	jnb	T0, ex1int_t34
	mov	R2, #41h
ex1int_t34:	lcall	label61
	mov	18h, A
	lcall	label61
	mov	19h, A
	lcall	label61
	mov	1Ah, A
	ret
label592:	jnb	1Ch, ex1int_t35
	mov	1Bh, #80h
ex1int_t35:	mov	R0, 1Ch
	mov	R1, 1Bh
	mov	C, 97h
	cpl	C
	mov	2h, C
	jc	ex1int_t36
	jb	26h, ex1int_t37
	lcall	ex1int_t38
	sjmp	ex1int_t39
ex1int_t37:	clr	A
	lcall	ex1int_t40
	sjmp	ex1int_t39
ex1int_t36:	jnb	26h, ex1int_t41
	lcall	ex1int_t38
	sjmp	ex1int_t39
ex1int_t41:	mov	A, 1Ah
	lcall	ex1int_t40
ex1int_t39:	mov	1Ch, R0
	mov	1Bh, R1
	mov	C, 2h
	mov	26h, C
	ljmp	ex1int_t42
	jb	1Ah, ex1int_t43
	jb	19h, ex1int_t43
	jb	1Dh, ex1int_t43
	nop
	nop
	nop
	mov	A, #4Bh
	movc	A, @A+DPTR
	cjne	A, 37h, ex1int_t44
ex1int_t44:	jc	ex1int_t43
	mov	A, #4Ch
	movc	A, @A+DPTR
	cjne	A, 49h, ex1int_t45
ex1int_t45:	jnc	ex1int_t46
	jnb	25h, ex1int_t43
	jb	21h, ex1int_t47
	setb	21h
	clr	22h
	mov	A, #4Dh
	movc	A, @A+DPTR
	mov	3Fh, A
ex1int_t47:	mov	A, 3Fh
	jz	ex1int_t43
	sjmp	ex1int_t48
ex1int_t46:	clr	21h
ex1int_t48:	mov	A, #49h
	jb	18h, ex1int_t49
	mov	A, #48h
ex1int_t49:	movc	A, @A+DPTR
	mov	R2, A
	jb	25h, ex1int_t50
	mov	A, #4Ah
	movc	A, @A+DPTR
	add	A, R2
ex1int_t50:	clr	C
	subb	A, 13h
	mov	25h, C
	lcall	ex1int_t51
	sjmp	ex1int_t52
ex1int_t43:	clr	25h
ex1int_t52:	lcall	ex1int_t53
	jnb	96h, ex1int_t54
	jb	97h, ex1int_t54
	jb	23h, ex1int_t55
	setb	23h
	clr	24h
	mov	A, #43h
	movc	A, @A+DPTR
	mov	3Eh, A
ex1int_t55:	mov	A, 3Eh
	jnz	ex1int_t56
	clr	27h
	sjmp	ex1int_t56
ex1int_t54:	jb	24h, ex1int_t57
	setb	24h
	clr	23h
	clr	22h
	setb	20h
	mov	A, #44h
	movc	A, @A+DPTR
	mov	3Eh, A
ex1int_t57:	mov	A, 3Eh
	jnz	ex1int_t56
	setb	27h
ex1int_t56:	mov	C, 25h
	anl	C, 27h
	anl	C, 20h
	mov	25h, C
	jc	ex1int_t58
	mov	R0, #0h
	mov	R1, #80h
	mov	1Ch, R0
	mov	1Bh, R1
	clr	22h
ex1int_t58:	ljmp	ex1int_t59
label353:	lcall	label88
	mov	A, #1h
	lcall	label42
	ljmp	ex1int_t60
ex1int_t51:	mov	A, #46h
	movc	A, @A+DPTR
	mov	R3, A
	clr	C
	mov	A, R1
	subb	A, R3
	jc	ex1int_t61
	mov	R0, #0h
	sjmp	ex1int_t62
ex1int_t61:	mov	A, #47h
	movc	A, @A+DPTR
	mov	R3, A
	clr	C
	subb	A, R1
	jc	ex1int_t63
	mov	R0, #0FFh
ex1int_t62:	mov	A, R3
	mov	R1, A
	mov	1Ch, R0
	mov	1Bh, R1
	jb	21h, ex1int_t63
	jb	22h, ex1int_t64
	mov	A, #45h
	movc	A, @A+DPTR
	cjne	A, #0FFh, ex1int_t65
	clr	22h
	setb	20h
	sjmp	ex1int_t63
ex1int_t65:	setb	22h
	mov	3Fh, A
ex1int_t64:	mov	A, 3Fh
	jnz	ex1int_t63
	clr	20h
ex1int_t63:	ret
	mov	R2, #4Eh
	mov	A, R2
	movc	A, @A+DPTR
	cjne	A, 37h, ex1int_t66
ex1int_t66:	jc	ex1int_t67
	xch	A, R2
	inc	A
	movc	A, @A+DPTR
	xch	A, R2
	subb	A, R2
	cjne	A, 37h, ex1int_t68
ex1int_t68:	jnc	ex1int_t69
	sjmp	ex1int_t70
ex1int_t69:	setb	95h
	sjmp	ex1int_t70
ex1int_t67:	clr	95h
ex1int_t70:	jnb	1Fh, ex1int_t71
	mov	A, 1Bh
	mov	C, 0E7h
	nop
	mov	TXD, C
ex1int_t71:	ret
	jnb	25h, ex1int_t72
	clr	95h
	clr	0Bh
	sjmp	ex1int_t70
ex1int_t72:	jb	0Bh, ex1int_t73
	mov	A, #50h
	movc	A, @A+DPTR
	mov	3Fh, A
	setb	95h
	setb	0Bh
ex1int_t73:	mov	A, 3Fh
	jnz	ex1int_t74
	clr	95h
ex1int_t74:	sjmp	ex1int_t70
ex1int_t38:	mov	A, 18h
	mov	B, #1h
	sjmp	ex1int_t14
ex1int_t40:	cpl	A
	inc	A
	add	A, 19h
	mov	B, #10h
	clr	24h
ex1int_t14:	mul	AB
	jnb	0F7h, ex1int_t75
	mov	B, #7Fh
ex1int_t75:	jnb	2h, ex1int_t76
	cpl	C
	cpl	A
	xrl	B, #0FFh
ex1int_t76:	addc	A, R0
	mov	R0, A
	mov	A, B
	addc	A, R1
	mov	R1, A
	clr	A
	jb	2h, ex1int_t77
	cpl	C
	cpl	A
ex1int_t77:	jc	ex1int_t78
	mov	R0, A
	mov	R1, A
ex1int_t78:	ret
label383:	jb	1Ah, ex1int_t79
	mov	R2, #44h
	lcall	label61
	mov	R3, A
	jb	9h, ex1int_t80
	cjne	A, 49h, ex1int_t81
ex1int_t81:	jc	ex1int_t82
	clr	8h
	sjmp	ex1int_t79
ex1int_t82:	mov	A, #52h
	jb	8h, ex1int_t83
	setb	8h
	movc	A, @A+DPTR
	mov	58h, A
	mov	A, #54h
	movc	A, @A+DPTR
	mov	59h, A
ex1int_t83:	mov	A, 58h
	jnz	ex1int_t79
	setb	9h
	mov	A, #53h
	movc	A, @A+DPTR
	mov	58h, A
	mov	A, #55h
	movc	A, @A+DPTR
	mov	59h, A
	setb	1Dh
	mov	32h, R5
	mov	31h, R5
	ret
ex1int_t80:	mov	A, 58h
	jnz	ex1int_t84
	clr	8h
	clr	9h
	sjmp	ex1int_t79
ex1int_t84:	mov	A, #51h
	movc	A, @A+DPTR
	cpl	A
	inc	A
	add	A, R3
	clr	C
	subb	A, 49h
	jnc	ex1int_t79
	setb	1Dh
	mov	32h, R5
	mov	31h, R5
	ret
ex1int_t79:	ljmp	ex1int_t85
label380:	dec	59h
	mov	A, 59h
	jnz	ex1int_t86
	mov	A, #54h
	jnb	9h, ex1int_t87
	inc	A
ex1int_t87:	movc	A, @A+DPTR
	mov	59h, A
	mov	A, 58h
	jz	ex1int_t86
	dec	58h
ex1int_t86:	ljmp	ex1int_t88
	nop
	nop
	nop
	nop
	nop
	setb	95h
	ret
label373:	clr	IE0
	mov	P2, #0h
	movx	@R0, A
	movx	@R0, A
	movx	@R0, A
	movx	@R0, A
	mov	A, #0Dh
	movc	A, @A+DPTR
	mov	B, A
	mov	C, INT1
	mov	0E0h, C
	mov	R5, #0h
	mov	R6, #2h
	mov	R7, #2h
	rlc	A
ex1int_t93:	mov	2Ah, B
	jnb	17h, ex1int_t89
	clr	17h
	movx	@R0, A
ex1int_t89:	djnz	R5, ex1int_t90
	jb	0E0h, ex1int_t91
	mov	R7, #2h
	djnz	R6, ex1int_t90
	ljmp	rst_tar
ex1int_t91:	mov	R6, #2h
	djnz	R7, ex1int_t90
	ljmp	rst_tar
ex1int_t90:	mov	C, INT1
	mov	0E0h, C
	orl	C, 0E1h
	jnc	ex1int_t92
	mov	C, 0E0h
	anl	C, 0E1h
	jc	ex1int_t92
	mov	R5, #0h
	mov	R6, #2h
	mov	R7, #2h
ex1int_t92:	rlc	A
	jnb	IE0, ex1int_t93
	setb	EX0
	clr	1Ch
	ljmp	label59
	jnb	INT1, $
	jb	INT1, $
	ret
	jnb	T0, ex1int_t94
	setb	31h
	setb	30h
	ljmp	ex1int_t95
ex1int_t94:	clr	31h
	setb	30h
ex1int_t95:	ljmp	ex1int_t96
	jb	1Ch, ex1int_t97
	mov	A, 29h
	jz	ex1int_t98
	dec	A
	mov	29h, A
ex1int_t98:	jb	T0, ex1int_t99
	clr	36h
	jnb	31h, label300
	jb	30h, label301
	jb	34h, label302
	setb	32h
	clr	33h
	sjmp	label303
label302:	clr	32h
	setb	33h
label303:	setb	30h
	clr	31h
	sjmp	ex1int_t97
ex1int_t99:	mov	R2, #46h
	jb	31h, label304
	mov	A, #58h
	movc	A, @A+DPTR
	mov	29h, A
	jb	1Dh, label305
	jbc	36h, label306
	mov	C, 34h
	mov	35h, C
	sjmp	label306
label304:	jb	30h, label301
label306:	jb	35h, label307
	inc	R2
label307:	lcall	label61
	clr	C
	subb	A, #14h
	mov	C, 0E7h
	rrc	A
	setb	31h
	clr	30h
	mov	31h, A
label300:	mov	A, 29h
	jnz	ex1int_t97
	setb	30h
label301:	clr	32h
	clr	33h
	sjmp	ex1int_t97
label305:	setb	30h
	clr	31h
	clr	32h
	clr	33h
	jb	36h, ex1int_t97
	mov	C, 34h
	mov	35h, C
	setb	36h
ex1int_t97:	ret
	jb	1Ch, label308
	jnb	30h, label308
	jb	32h, label309
	jb	33h, label309
	ajmp	label308
label309:	djnz	34h, label308
	mov	DPTR, #1160h
	mov	A, #56h
	jb	32h, label310
	mov	A, #57h
label310:	movc	A, @A+DPTR
	mov	34h, A
	mov	R2, #45h
	lcall	label61
	mov	R5, A
	mov	A, 32h
	mov	R6, A
	mov	R7, 31h
	clr	C
	subb	A, R7
	clr	C
	jb	0E7h, label311
	subb	A, R5
	jc	label311
	mov	A, R7
	add	A, R5
	ajmp	label312
label311:	clr	32h
	clr	33h
	mov	34h, #1h
	mov	A, 32h
label312:	mov	31h, A
label308:	ret
	mov	A, 28h
	clr	C
	subb	A, 37h
	jnc	label313
	mov	B, A
	mov	A, #6Dh
	movc	A, @A+DPTR
	add	A, B
	jc	label313
	clr	34h
	sjmp	label314
label313:	setb	34h
label314:	mov	28h, 37h
	ret
	jb	1Ch, label315
	jnb	30h, label316
	jb	16h, label317
	jb	32h, label316
	jb	33h, label316
label315:	ljmp	label318
label317:	clr	32h
	clr	33h
	ljmp	label318
label316:	ljmp	ex1int_t3
	jb	1Ch, label319
	jb	1Dh, label320
	jb	30h, label319
	clr	15h
	clr	16h
	ljmp	ex0int_t69
label320:	clr	32h
	clr	33h
label319:	ljmp	label321
	ljmp	label322
	ajmp	label323
label347:	mov	27h, #0h
	clr	28h
	acall	label324
	mov	A, #5Fh
	movc	A, @A+DPTR
	subb	A, 13h
	cpl	C
	mov	3Ch, C
	mov	C, 25h
	cpl	C
	mov	3Dh, C
	mov	A, #60h
	movc	A, @A+DPTR
	subb	A, 12h
	mov	3Eh, C
	mov	R0, #5Ch
	mov	A, #5Dh
	jnb	39h, label325
label481:	mov	R0, #59h
	inc	A
label325:	movc	A, @A+DPTR
	mov	B, A
	ljmp	label326
	mov	A, 27h
	anl	A, #78h
	jz	label327
	ajmp	label328
label327:	mov	A, #59h
	movc	A, @A+DPTR
	cpl	A
	inc	A
	add	A, 59h
	add	A, 1Bh
	mov	R3, A
	clr	C
	subb	A, @R0
	mov	2h, C
	jnc	label329
	cpl	A
	inc	A
label329:	mul	AB
	mov	R6, B
	mov	R5, A
	inc	R0
	jb	2h, label330
	mov	A, @R0
	add	A, R5
	mov	@R0, A
	inc	R0
	mov	A, @R0
	addc	A, R6
	mov	@R0, A
	jnc	label331
	clr	C
	subb	A, #80h
	mov	@R0, A
	dec	R0
	dec	R0
	mov	A, #5Ah
	movc	A, @A+DPTR
	setb	C
	subb	A, @R0
	jc	label331
	inc	@R0
	sjmp	label332
label330:	clr	C
	mov	A, @R0
	subb	A, R5
	mov	@R0, A
	inc	R0
	mov	A, @R0
	subb	A, R6
	mov	@R0, A
	jnc	label331
	add	A, #80h
	mov	@R0, A
	dec	R0
	dec	R0
	mov	A, #5Bh
	movc	A, @A+DPTR
	clr	C
	subb	A, @R0
	jnc	label331
	dec	@R0
label332:	jnb	39h, label331
	mov	A, @R0
	mov	R0, #6h
	lcall	label333
label331:	clr	C
	mov	A, #59h
	movc	A, @A+DPTR
	subb	A, 59h
	add	A, R3
	mov	1Bh, A
	jb	39h, label328
	ljmp	label334
	djnz	63h, label328
	mov	A, #5Ch
	movc	A, @A+DPTR
	mov	63h, A
	clr	C
	mov	A, 5Ch
	subb	A, 59h
	jnc	label335
	cpl	A
	inc	A
label335:	mov	2h, C
	mov	B, #1h
	jnb	38h, label336
	mov	R1, 5Fh
	mov	R0, 60h
	acall	ex1int_t14
	mov	B, 5Fh
	mov	5Fh, R1
	mov	60h, R0
	sjmp	label337
label336:	mov	R1, 61h
	mov	R0, 62h
	acall	ex1int_t14
	mov	B, 61h
	mov	61h, R1
	mov	62h, R0
label337:	mov	A, R1
	mov	R0, #0Ch
	jb	38h, label338
	mov	R0, #12h
label338:	cjne	A, B, label339
	sjmp	label328
label339:	lcall	label333
label328:	ljmp	label340
	clr	C
	mov	A, 5Fh
	subb	A, #80h
	mov	F0, C
	jnc	label341
	cpl	A
	inc	A
label341:	mov	R1, A
	mov	R3, 37h
	mov	B, 37h
	mov	A, #32h
	div	AB
	mov	R7, A
	lcall	label82
	mov	R6, A
	mov	A, R1
	lcall	label41
	mov	A, R7
	jz	label342
	mov	R6, #0FFh
label342:	mov	A, R6
	clr	C
	rrc	A
	add	A, #80h
	jnb	F0, label343
	cpl	A
	nop
label343:	add	A, 61h
	cpl	C
	mov	F0, C
	jnc	label344
	cpl	A
	nop
label344:	jnz	label345
	clr	F0
label345:	mov	58h, A
	mov	C, F0
	mov	29h, C
	ret
label323:	mov	A, 49h
	mov	B, 37h
	mul	AB
	mov	R7, B
	mov	R6, A
	mov	A, #0A4h
	lcall	label41
	mov	A, #2h
	lcall	label42
	jz	label346
	mov	R7, #0FFh
label346:	mov	A, R7
	mov	R4, A
	ajmp	label347
label324:	ljmp	label348
	clr	C
	mov	A, #63h
	movc	A, @A+DPTR
	subb	A, R4
	jnc	label349
	mov	A, #64h
	movc	A, @A+DPTR
	clr	C
	subb	A, 49h
	mov	39h, C
	sjmp	label350
label349:	mov	A, #62h
	movc	A, @A+DPTR
	subb	A, 37h
	jc	label351
	mov	A, #61h
	movc	A, @A+DPTR
	subb	A, R4
	cpl	C
	mov	38h, C
	sjmp	label350
label351:	mov	A, #66h
	movc	A, @A+DPTR
	clr	C
	subb	A, 37h
	jnc	label350
	mov	A, #65h
	movc	A, @A+DPTR
	clr	C
	subb	A, R4
	jc	label350
	mov	A, #67h
	movc	A, @A+DPTR
	subb	A, 49h
	jnc	label350
	mov	A, #68h
	movc	A, @A+DPTR
	clr	C
	subb	A, 49h
	jc	label350
	setb	3Ah
label350:	mov	A, 27h
	anl	A, #7h
	jnz	label352
	setb	3Bh
label352:	ret
	mov	A, #59h
	movc	A, @A+DPTR
	cpl	A
	inc	A
	add	A, 59h
	add	A, R1
	mov	R1, A
	ajmp	label353
	mov	A, 58h
	mov	B, #4h
	mul	AB
	jnb	29h, label354
	cpl	C
	cpl	A
	xrl	B, #0FFh
label354:	addc	A, R6
	mov	R6, A
	mov	A, B
	addc	A, R7
	mov	R7, A
	clr	A
	jb	29h, label355
	cpl	C
	cpl	A
label355:	jc	label356
	mov	R7, A
	mov	R6, A
label356:	ljmp	label357
ex1int_t96:	mov	TMOD, #11h
	mov	IP, #2h
	orl	IE, #85h
	orl	TCON, #5h
	mov	DPTR, #1160h
	mov	SP, #63h
	clr	92h
	mov	A, #0Dh
	movc	A, @A+DPTR
	mov	2Ah, A
	lcall	label358
	lcall	label359
	lcall	label360
	lcall	label361
	lcall	label360
	lcall	label362
	lcall	label359
	lcall	label360
	lcall	label363
	lcall	label360
	lcall	label359
	lcall	label364
	lcall	label360
	ljmp	label365
	jnb	1Ch, ex1int_t96
	lcall	ex1int_t1
	lcall	label366
	ret
label360:	jbc	17h, label367
	ret
label367:	ljmp	label368
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	nop
	orl	0C2h, A
label430:	subb	A, 2h
label449:	inc	R4
	xrl	A, R7
label53:	ljmp	label369
label59:	ljmp	label370
label49:	ljmp	label50
label51:	lcall	label371
	ljmp	label372
label455:	mov	R7, A
	mov	R7, A
label441:	mov	R7, A
label56:	ljmp	label373
label359:	ljmp	label374
label365:	ljmp	label375
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
ex1int_t2:	ljmp	label318
label34:	ljmp	label376
label43:	ljmp	label357
label86:	ljmp	label377
label87:	ljmp	label378
label89:	ljmp	label379
label90:	ret
	mov	R7, A
	mov	R7, A
label93:	ljmp	label380
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
ex0int_t39:	ljmp	label381
ex0int_t54:	ljmp	label382
ex0int_t58:	ljmp	label383
ex0int_t85:	ljmp	label384
ex0int_t86:	ljmp	label385
ex1int_t88:	ljmp	label386
ex1int_t85:	ljmp	label321
ex1int_t42:	ljmp	label387
ex1int_t53:	ljmp	label388
ex1int_t59:	ljmp	label353
ex1int_t60:	ljmp	ex1int_t70
ex0int_t88:	ljmp	label389
ex0int_t98:	ljmp	label390
ex1int_t03:	ljmp	label391
ex1int_t09:	ljmp	label392
ex1int_t18:	ljmp	label393
ex1int_t25:	ljmp	label394
ex1int_t30:	ljmp	label395
ex1int_t32:	ljmp	label396
label322:	ljmp	label397
label326:	ljmp	label397
label334:	ljmp	label397
label340:	ljmp	label397
label348:	ljmp	label397
	mov	R7, A
	nop
	ljmp	label398
	jbc	74h, label399
	mov	R0, #0Eh
	xrl	A, R6
	jnz	label400
	inc	R4
	inc	R2
	inc	R0
	xrl	A, R0
	xrl	A, R2
	xrl	A, R4
	lcall	label401
	mov	R6, #0FFh
	mov	R7, A
	dec	R1
	dec	R4
	addc	A, R0
	addc	A, R2
	orl	A, #42h
	subb	A, R6
	orl	C, /0A2h
	addc	A, R4
	addc	A, R6
	subb	A, R0
	subb	A, R2
	subb	A, R4
	ajmp	label402
	add	A, R6
	jb	1Eh, label403
	sjmp	label404
	div	AB
	add	A, 26h
	add	A, R2
	mov	AUXR, R4
	mov	DPTR, #4648h
	orl	A, R2
	orl	A, R4
	orl	A, R6
	jnc	label405
	anl	A, 0FFh
	anl	A, R1
	anl	A, R3
	anl	A, R5
	anl	A, R1
	anl	A, R3
	ajmp	label406
	mov	R7, A
label410:	mov	R7, A
	mov	R7, A
	inc	A
	dec	A
	dec	@R0
	add	A, R4
	mov	94h, C
label403:	subb	A, @R0
	add	A, R1
	mov	TMOD, @R1
	mov	30h, R3
	reti
	addc	A, #36h
	anl	A, @R0
	mul	AB
	mov	@R0, IE
	inc	@R1
	xrl	65h, #67h
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R6, P2
	movc	A, @A+DPTR
	mov	0F7h, @R1
	movx	A, @R1
	pop	0BFh
	ajmp	label407
	rr	A
label427:	inc	A
	inc	A
label429:	inc	6h
	inc	@R1
	ajmp	label408
	mov	TMOD, @R0
	mov	AUXR, R3
	acall	label409
	subb	A, @R0
label399:	subb	A, R1
label400:	subb	A, R4
	subb	A, R7
	mov	C, 0A5h
	mov	R1, 0ACh
	mov	R7, IPL1
label425:	cjne	@R0, #0B9h, label410
	ajmp	label411
label487:	xch	A, R0
	xch	A, R4
	pop	P1M1
	djnz	R0, label412
	movx	A, @DPTR
	clr	A
	mov	A, R1
	dec	@R0
	inc	A
	mov	2Fh, R1
	add	A, R7
	dec	R1
	rr	A
	ljmp	label413
label468:	dec	@R1
	inc	R0
	rl	A
label460:	add	A, @R0
label462:	dec	R5
	dec	A
	inc	R6
	inc	R6
	inc	R2
label456:	jz	label414
label414:	ajmp	label407
	rr	A
	inc	A
	inc	6h
	inc	@R1
	anl	A, R2
	rlc	A
	orl	A, @R1
	jc	label415
	jc	label416
	jc	label417
label436:	jc	label418
	jc	label419
	jc	label420
	jc	label418
	addc	A, R3
	addc	A, R5
	addc	A, R6
	addc	A, R7
	addc	A, R7
	addc	A, R7
	addc	A, R7
	addc	A, R7
	jc	label421
	jc	label422
	jc	label423
	jc	label419
	ljmp	label424
label491:	orl	0h, A
	nop
	div	AB
	div	AB
label504:	nop
	nop
	acall	label425
	dec	R6
	inc	R2
	inc	@R0
	inc	A
	mov	C, 1Fh
	djnz	R4, label426
	inc	R0
	ajmp	label427
	jc	label428
	inc	R4
	sjmp	label429
	mov	R4, #88h
	mov	C, 50h
	add	A, R0
	mov	R4, A
	orl	A, R1
	mov	R1, A
label415:	addc	A, R4
label426:	dec	A
label416:	inc	R0
	ajmp	label430
	inc	R0
label418:	ajmp	label407
label419:	ajmp	label430
label420:	mov	R1, A
	mov	R7, A
	inc	R1
	inc	R1
	add	A, #5h
	ajmp	label431
	addc	A, R6
	inc	A
	dec	18h
label421:	nop
	dec	@R1
label422:	push	27h
label423:	ljmp	label432
	orl	42h, A
	inc	R1
	mov	R7, A
	movc	A, @A+DPTR
	jz	label433
	anl	A, R0
	inc	@R1
	mov	66h, R6
	inc	@R0
	orl	A, R3
	inc	0FFh
	reti
	dec	R2
	dec	R5
	inc	R2
	cjne	A, #0FFh, label434
label439:	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R0, #0FFh
	anl	A, TH0
	anl	A, 0FFh
	addc	A, @R1
	acall	label435
label428:	rrc	A
	lcall	label436
	add	A, R7
	jbc	7Ah, label437
	add	A, R0
	mov	R2, #26h
	add	A, R0
	lcall	label438
	mov	@R0, 12h
	push	12h
	xch	A, R2
	rrc	A
	mov	@R0, #13h
	subb	A, R0
	rrc	A
	mov	C, 13h
	mov	R4, 13h
	cjne	R4, #13h, label439
	rrc	A
	xch	A, R4
	rrc	A
	da	A
	rrc	A
	djnz	R4, label440
	orl	A, @R1
	dec	A
	orl	A, R7
	dec	A
label435:	anl	A, R3
	dec	70h
label437:	dec	A
	xrl	A, 14h
	jmp	@A+DPTR
	dec	A
	mov	14h, @R0
	mov	15h, R4
	addc	A, R0
	dec	44h
	dec	66h
	dec	7Ah
	dec	DP1L
	dec	TL0
	dec	P1
label445:	dec	SCON
	dec	KBF
	dec	0ACh
	dec	IPL1
label442:	dec	0BCh
label447:	dec	0D3h
	dec	CCAPM1
label452:	dec	0E5h
	dec	0EFh
	dec	CH
	dec	@R0
	ajmp	label441
	inc	R3
	dec	@R0
	dec	16h
	dec	R7
	dec	@R0
	add	A, R1
	dec	@R0
	orl	A, R7
	dec	@R0
	anl	A, R1
	dec	@R0
	subb	A, #16h
	cjne	R2, #16h, label442
	dec	R0
	mov	A, R4
	dec	@R0
	mov	R2, A
	lcall	label443
	lcall	label444
	rrc	A
	mov	@R0, #19h
	cjne	R6, #17h, label445
label532:	rrc	A
	mov	R4, 19h
	movx	A, @DPTR
	dec	@R1
	djnz	R0, label446
	inc	A
	dec	R1
	movx	@DPTR, A
	dec	@R1
	movx	A, @DPTR
	dec	R3
	inc	R4
	dec	R1
	mov	R0, A
	dec	@R1
	mov	A, R0
	dec	R3
	dec	A
	dec	R2
	nop
	dec	@R1
	mov	@R0, A
	dec	A
	mov	1Ah, R4
	inc	R6
	dec	R0
	mov	C, 15h
	addc	A, R0
	dec	R2
	cjne	R2, #18h, label447
	dec	44h
	dec	R2
	xch	A, @R0
	dec	R0
	pop	15h
	cpl	1Ah
	mov	A, R0
	dec	R0
	djnz	R2, label448
	setb	C
	dec	R2
	movx	@R0, A
	dec	R0
	movx	A, @R0
	dec	@R0
	orl	A, R7
	dec	R2
	mov	R2, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
label448:	dec	A
	inc	A
	add	A, R6
	anl	48h, A
	addc	A, R0
	ajmp	label449
	ljmp	label450
	ljmp	label451
	sjmp	label452
	inc	A
	inc	R4
	inc	A
	inc	@R1
	inc	R0
	inc	R7
	dec	R2
	addc	A, 1Ch
	dec	R4
	jbc	7h, label453
	dec	@R0
	ljmp	label454
	addc	A, #48h
	anl	A, R7
	mov	AUXR1, R1
	clr	C
	movx	A, @DPTR
	movx	@R1, A
	mov	R3, A
	addc	A, @R1
	inc	A
	dec	R0
	add	A, R4
	orl	A, R0
	xrl	A, @R1
	acall	label455
	dec	R1
	ajmp	label456
	inc	R4
	inc	A
	inc	A
	inc	R0
	inc	R0
	inc	R0
	inc	R0
	dec	R0
	jbc	10h, label457
	jbc	64h, label458
	inc	R4
	inc	0Bh
	inc	6h
	inc	0Ah
	jbc	0Bh, label459
	dec	@R0
	dec	A
	orl	C, 23h
	add	A, @R0
	add	A, R4
	add	A, R7
	acall	label460
	acall	label460
label457:	acall	label460
	acall	label460
	rl	A
	add	A, @R0
	add	A, R4
	add	A, R7
	acall	label460
	acall	label460
	acall	label460
	acall	label460
	rl	A
label402:	add	A, R2
	acall	label414
	jc	label461
	rlc	A
	acall	label460
	acall	label460
	acall	label462
	addc	A, R1
	jc	label463
	jc	label464
	addc	A, #31h
	add	A, R5
	add	A, R5
	add	A, R5
	add	A, R5
	addc	A, @R1
	jc	label465
	orl	A, #44h
	addc	A, R4
	addc	A, R1
	rlc	A
	add	A, R6
	add	A, R5
	add	A, R5
	add	A, R5
label458:	addc	A, R4
	jc	label466
label454:	orl	44h, #41h
	addc	A, R3
	addc	A, @R0
	addc	A, #2Dh
	add	A, R1
	add	A, R1
	jc	label467
	orl	A, @R1
	orl	A, @R1
	orl	A, @R1
	orl	3Ch, A
label485:	addc	A, @R1
	addc	A, #2Dh
	add	A, R1
	add	A, R1
label486:	orl	A, @R0
	orl	A, R3
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R0
	orl	A, 40h
	addc	A, R1
	acall	label468
	add	A, R5
	orl	A, @R0
	orl	A, R3
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R0
	orl	A, 40h
	addc	A, R1
	addc	A, @R0
label464:	addc	A, #46h
	orl	A, R3
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R7
label465:	orl	A, R0
	orl	3Dh, A
	addc	A, R1
	addc	A, @R0
label406:	orl	A, @R0
	orl	A, R3
	orl	A, R7
label474:	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R7
label466:	orl	A, R0
	orl	A, 3Eh
	addc	A, R2
	addc	A, @R0
	orl	A, @R0
	orl	A, R3
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R0
	orl	A, 3Eh
	addc	A, R2
	addc	A, @R0
	addc	A, @R1
label467:	jbc	0Ch, label469
	rr	A
	rr	A
	inc	@R1
	inc	R4
	inc	@R1
	inc	@R0
	inc	R4
	inc	R5
	inc	R4
	inc	R5
	inc	@R1
	inc	6h
label469:	xrl	A, #32h
	reti
	add	A, R5
	add	A, @R1
	add	A, @R1
	add	A, @R1
	add	A, R2
	add	A, R6
	add	A, R6
	jnb	30h, label470
	jnb	32h, label471
	reti
	lcall	label472
	inc	A
	ljmp	label473
	dec	A
	dec	A
	dec	A
	rrc	A
	inc	A
	dec	@R0
	inc	R7
	anl	4Fh, A
	dec	A
	dec	A
	dec	A
	dec	A
	addc	A, @R1
	inc	@R1
	inc	A
	rr	A
	inc	R6
	inc	R0
	jbc	18h, label474
	addc	A, R7
	dec	R3
	dec	R3
	dec	R4
	add	A, R2
	add	A, R2
	orl	A, @R1
	rrc	A
	rr	A
	orl	A, R6
	anl	A, R1
	orl	A, R7
	add	A, @R0
	inc	R5
	dec	A
label470:	rrc	A
	rr	A
	inc	R6
	orl	A, R2
	anl	A, R6
label471:	dec	A
	inc	@R0
	dec	A
	addc	A, @R1
	rr	A
	inc	@R1
	inc	R5
	mov	A, R1
	dec	R4
	reti
	reti
	rrc	A
	rr	A
	orl	A, R6
	anl	A, 4Fh
	dec	R3
	dec	A
	inc	R5
	addc	A, @R1
	inc	R4
	rr	A
	inc	A
	inc	A
	inc	A
	inc	A
	jbc	10h, label475
	add	A, @R1
	rl	A
	dec	R7
	anl	A, R6
	acall	label476
	dec	R5
	dec	R6
	dec	R5
	dec	R6
	dec	R5
	inc	@R1
	inc	R6
	dec	R1
	dec	R2
	dec	@R1
	jbc	0Ch, label477
	inc	@R1
	orl	A, R1
	add	A, R2
	dec	@R1
	jbc	0Ch, label478
	inc	@R1
	orl	A, R1
	add	A, R2
label477:	dec	@R1
	jbc	0Ch, label479
	inc	@R1
	acall	label480
label478:	dec	R1
	lcall	label481
	inc	@R1
	anl	A, R5
	addc	A, 1Dh
	dec	A
	jbc	0Dh, label482
	xrl	A, R2
	addc	A, R5
	ajmp	label483
	lcall	label484
	xrl	A, R2
label482:	ajmp	label485
	add	A, 1Ch
	dec	R0
	inc	R6
	xrl	A, R2
	ajmp	label486
	add	A, R2
	ajmp	label487
	jbc	6Ah, label488
	addc	A, R7
	add	A, R6
	add	A, #1Eh
	lcall	label489
	xrl	A, R2
	orl	A, R6
	addc	A, R5
	rlc	A
	dec	R6
	xrl	A, R2
	xrl	A, R2
	xrl	A, R2
	xrl	A, R2
	anl	45h, #2Ah
	xrl	A, R2
	xrl	A, R2
	xrl	A, R2
	xrl	A, R2
	xrl	A, @R1
	anl	A, @R0
	rlc	A
	rrc	A
	rr	A
	addc	A, R0
	orl	7Ch, A
	lcall	label490
	rrc	A
	inc	6Ch
	dec	R1
	dec	R6
	dec	R6
	acall	label491
	xrl	A, #1Eh
	dec	R6
	dec	R6
	lcall	label492
	add	A, R6
	addc	A, R3
	xrl	A, R5
	mov	DPTR, #8A80h
	sjmp	label493
	inc	@R0
	jb	10h, label494
	inc	R0
	jnc	label495
	mov	@R0, 5Ah
	orl	2Dh, #0Fh
	nop
	addc	A, @R1
	rr	A
	reti
	reti
	movc	A, @A+PC
	orl	A, R1
label493:	rr	A
	add	A, R0
	addc	A, R4
	mov	A, #0FFh
	mov	R7, A
	mov	R7, A
label494:	mov	R7, A
	mov	R7, A
	push	0FFh
label408:	cpl	C
	sjmp	label496
	ljmp	label497
	mov	R7, A
	mov	R7, A
	addc	A, @R1
	inc	R4
	inc	A
	inc	A
	inc	R0
	inc	R0
	inc	R0
	inc	R0
label409:	dec	R0
	jbc	10h, label498
	jbc	64h, label499
	inc	R4
	inc	0Bh
	inc	6h
	inc	0Ah
	jbc	0Bh, label500
	dec	@R0
	dec	A
	orl	C, 85h
	mov	DP1H, DP1H
	mov	DP1L, DP1H
label500:	movc	A, @A+PC
label498:	movc	A, @A+PC
	movc	A, @A+PC
	movc	A, @A+PC
	movc	A, @A+PC
	mov	DP1H, DP1H
	div	AB
	div	AB
	div	AB
	div	AB
	div	AB
	div	AB
	div	AB
label496:	div	AB
	div	AB
	mov	DP1H, DP1H
	div	AB
	div	AB
label495:	div	AB
	div	AB
	div	AB
	div	AB
	div	AB
	div	AB
	div	AB
	mov	SPDR, SPDR
	mov	SPDR, @R0
	mov	TCON, @R0
	mov	TMOD, R0
	mov	TMOD, R1
	mov	DP1H, R1
	mov	SPDR, @R0
	mov	TCON, @R1
	mov	TCON, R0
	mov	TMOD, R0
	mov	CLKREG, R7
	mov	DP1H, R7
	mov	PCON, @R0
	mov	TCON, R0
	mov	TMOD, R1
	mov	TMOD, R1
	mov	95h, R2
	subb	A, DP1H
	mov	TCON, @R0
	mov	TCON, R0
	mov	TMOD, R1
	mov	TL0, R1
	mov	94h, R4
	subb	A, #85h
	mov	TCON, @R1
	mov	TL0, R0
	mov	TL0, R2
	mov	TL1, R2
	mov	TH1, R4
	subb	A, @R0
	mov	TCON, PCON
	mov	TL0, R0
	mov	TL0, R2
	mov	TL1, R3
	mov	TH1, R4
	movc	A, @A+DPTR
	mov	TMOD, PCON
	mov	TL1, R1
	mov	TL1, R3
	mov	TL1, R3
	mov	TL1, R3
	mov	DP1H, R7
	mov	TCON, @R1
	mov	TCON, R0
	mov	TMOD, R1
	mov	TMOD, R1
	mov	TMOD, R1
	mov	TCON, R2
	mov	TL0, R0
	mov	TL0, R2
	mov	TCON, R1
	mov	TCON, R0
	mov	TCON, R0
	mov	37h, R0
	inc	2h
	ljmp	label501
	pop	P0
	movc	A, @A+PC
	movc	A, @A+PC
	div	AB
	div	AB
	addc	A, @R1
	jbc	0Ch, label502
	rr	A
	rr	A
	inc	@R1
	inc	R4
	inc	@R1
	inc	@R0
	inc	R4
	inc	R5
	inc	R4
	inc	R5
	inc	@R1
	inc	6h
label502:	xrl	A, #8Ah
	mov	95h, R7
	subb	A, @R1
	subb	A, R2
	subb	A, R5
	subb	A, R5
	subb	A, R7
	subb	A, R7
	subb	A, R5
	subb	A, R5
	subb	A, R3
	subb	A, R3
	subb	A, R3
	subb	A, R3
	subb	A, R3
	rrc	A
	inc	A
	add	A, R6
	dec	R5
	dec	R6
	xrl	A, R5
	anl	A, R2
	add	A, R5
	rlc	A
	nop
	lcall	label503
	inc	R7
	inc	R7
	orl	A, R7
	nop
	add	A, @R1
	add	A, @R1
	add	A, @R1
	rrc	A
	inc	A
	orl	A, R2
	dec	R6
	ajmp	label504
	cjne	@R0, #1Ch, label505
	inc	R4
	rrc	A
	ljmp	label506
	inc	R7
	inc	R7
	orl	A, R5
	ljmp	label507
	mov	R3, A
	anl	37h, #3h
	rr	A
	inc	A
	acall	label508
	xch	A, R3
	movc	A, @A+DPTR
	acall	label407
	mov	15h, #5Dh
	dec	R5
	addc	A, @R1
	inc	@R0
	rr	A
	inc	R5
	inc	R6
	reti
	reti
	xrl	A, R2
	jc	label509
	sjmp	label510
	sjmp	label511
	rr	A
	ljmp	label512
	nop
label514:	mov	R7, A
	rrc	A
	inc	A
	dec	R6
	dec	R5
	dec	R6
	xrl	A, R5
	add	A, @R0
	add	A, @R0
	rrc	A
	nop
	addc	A, @R1
	rr	A
	dec	R1
	dec	R1
	cjne	A, 49h, label513
	dec	R6
	dec	R6
	dec	R6
	mov	R6, #0FFh
	mov	R7, A
	mov	R7, A
	xch	A, R5
	mov	R7, A
	mov	R7, A
	mov	R7, A
	xch	A, R5
	mov	R7, A
	mov	R7, A
	xch	A, R5
	cpl	C
	rrc	A
	rr	A
	add	A, R0
	add	A, R5
	movc	A, @A+PC
	addc	A, R3
	add	A, R4
	nop
	rr	A
	inc	A
	inc	R5
	jbc	10h, label514
	nop
	nop
	jc	label515
	rrc	A
	inc	A
	inc	R7
label509:	xrl	A, R7
	dec	@R0
	anl	A, R6
	add	A, R0
	dec	R1
	dec	@R1
	dec	A
	rrc	A
	inc	A
	orl	A, R3
	dec	R5
	addc	A, @R0
	orl	A, R5
	dec	A
	dec	A
	dec	A
	dec	A
	rrc	A
	rr	A
	xrl	A, R5
	add	A, @R1
	orl	A, R5
	dec	R1
	dec	@R1
	dec	3h
	inc	A
	ljmp	label516
	movx	@DPTR, A
	ljmp	label501
	ajmp	label449
	inc	A
	ljmp	label517
	movx	@R1, A
	ljmp	label518
	jbc	3h, label519
	ajmp	label59
	inc	@R0
	movx	@DPTR, A
label519:	nop
	dec	R6
	jnc	label520
	addc	A, @R1
	inc	A
	ajmp	label521
	lcall	label522
	dec	R2
	dec	R2
	dec	R2
	addc	A, @R1
	inc	@R0
	inc	5h
	inc	R1
	inc	R3
	reti
	subb	A, R4
	rrc	A
	inc	A
	jnb	16h, label523
	orl	A, R5
	mov	R7, A
	jz	label524
	dec	@R1
	mov	R7, A
	jz	label525
	dec	@R1
	mov	R7, A
	jz	label526
	dec	@R1
	mov	R7, A
	xrl	A, R6
	anl	A, R2
	dec	R2
	mov	R7, A
	subb	A, R1
	mov	33h, R1
	mov	R7, A
	xch	A, R0
	cjne	R2, #80h, label527
	inc	A
	orl	A, R5
	dec	R5
	add	A, R2
	anl	A, R6
	add	A, R0
	dec	R3
	dec	@R0
	dec	A
	addc	A, @R1
	inc	@R1
	inc	R2
	inc	R2
	inc	R2
	inc	R2
	dec	A
	dec	R1
	subb	A, R4
	orl	A, R1
label527:	inc	@R0
	inc	R2
	inc	R2
	inc	R2
	dec	A
	dec	A
	subb	A, R4
	inc	A
	inc	@R1
	inc	R2
	inc	R2
	inc	R6
label520:	inc	R6
	inc	R0
	inc	R7
	lcall	label528
	dec	@R0
	inc	R4
	rrc	A
	dec	R0
	dec	R5
	rl	A
	rl	A
	dec	A
	jb	23h, label529
	add	A, R5
	add	A, R5
	dec	R6
	jb	27h, label530
	add	A, R5
	add	A, R5
	add	A, R0
	add	A, R0
	add	A, R5
	add	A, R5
	add	A, R5
	add	A, R5
	add	A, R0
	add	A, R0
	add	A, R5
	add	A, R5
	add	A, R5
label524:	add	A, R5
	addc	A, @R1
	inc	A
	inc	R2
label525:	inc	R2
	inc	R2
label523:	xch	A, R1
	orl	A, R1
label526:	inc	@R0
	inc	R2
	inc	R2
	inc	R2
	dec	A
	dec	A
	subb	A, R4
	add	A, R0
	addc	A, R4
	orl	A, @R0
	jnc	label531
label529:	anl	A, R2
	add	A, R0
	ajmp	label532
	anl	A, R7
	anl	A, R7
	anl	A, R7
	addc	A, #4Dh
	xrl	A, #64h
	xrl	A, #64h
	orl	A, R3
	xrl	A, #64h
	xrl	A, #64h
	xrl	A, #37h
	inc	A
	inc	R2
	inc	R2
	inc	R2
	xch	A, R1
	orl	A, R1
	inc	@R0
	inc	R2
	inc	R2
label411:	inc	R2
	dec	A
	dec	A
	subb	A, R4
	inc	5h
	inc	5h
	inc	5h
	inc	5h
	inc	5h
	inc	5h
	inc	R1
	inc	R1
	inc	R1
	inc	R1
	inc	R4
	inc	R4
	inc	8h
	inc	R2
	inc	R4
	jbc	10h, label533
	inc	R4
	inc	R5
	inc	@R0
	inc	@R0
	inc	R5
	dec	R1
	inc	R4
	inc	R5
	inc	R4
	inc	@R1
	inc	@R0
	inc	@R0
	xrl	A, #0FFh
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	addc	A, @R1
	inc	R4
	inc	A
	inc	A
	inc	R0
	inc	R0
	inc	R0
label531:	inc	R0
	dec	R0
	jbc	10h, label534
	jbc	64h, label535
	inc	R4
	inc	0Bh
	inc	6h
	inc	0Ah
	jbc	0Bh, label536
	dec	@R0
	dec	A
	orl	C, 23h
	add	A, @R0
label533:	add	A, R4
	add	A, R7
	acall	label460
	acall	label460
label534:	acall	label460
	acall	label460
	rl	A
	add	A, @R0
	add	A, R4
	add	A, R7
	acall	label460
	acall	label460
	acall	label460
	acall	label460
	rl	A
	add	A, R2
	acall	label414
	jc	label537
	addc	A, @R1
	acall	label460
	acall	label460
	acall	label462
	addc	A, R1
	orl	A, #45h
	orl	A, R0
	orl	37h, A
	acall	label460
	acall	label460
	acall	label456
	jc	label538
	orl	A, R7
	orl	A, R7
	orl	A, 3Ch
	addc	A, @R1
	acall	label460
	acall	label460
label535:	addc	A, R4
	orl	4Ah, #4Fh
	orl	A, R7
	orl	A, R0
	orl	3Bh, A
	addc	A, 31h
	add	A, R5
	add	A, R5
	jc	label539
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R0
	orl	3Ch, A
	addc	A, #2Dh
	add	A, R1
	add	A, R1
	orl	A, @R0
	orl	A, R3
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R0
	orl	A, 42h
	addc	A, R1
	reti
label537:	add	A, R6
	add	A, R5
	orl	A, @R0
	orl	A, R3
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R0
label544:	orl	A, 40h
	addc	A, R1
	addc	A, @R0
	addc	A, #46h
	orl	A, R3
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R0
	orl	3Dh, A
	addc	A, R1
	addc	A, @R0
	orl	A, @R0
	orl	A, R3
	orl	A, R7
	orl	A, R7
	orl	A, R7
label538:	orl	A, R7
	orl	A, R7
label550:	orl	A, R0
	orl	A, 3Eh
	addc	A, R2
	addc	A, @R0
	orl	A, @R0
	orl	A, R3
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R7
label552:	orl	A, R0
	orl	A, 3Eh
	addc	A, R2
	addc	A, @R0
label444:	addc	A, @R1
	jbc	0Ch, label540
	rr	A
	rr	A
	inc	@R1
	inc	R4
	inc	@R1
	inc	@R0
	inc	R4
	inc	R5
	inc	R4
	inc	R5
	inc	@R1
	inc	6h
label540:	xrl	A, #32h
	reti
	add	A, R5
	add	A, @R1
	add	A, @R1
	add	A, @R1
	add	A, R2
label555:	add	A, R6
	add	A, R6
	jnb	30h, label541
	jnb	32h, label542
	reti
	addc	A, @R1
label556:	inc	@R1
	ljmp	label543
	inc	R0
	jbc	18h, label544
	jc	label545
	dec	R3
	dec	R4
	add	A, R2
	add	A, R2
	orl	A, @R1
	rrc	A
	rr	A
	orl	A, R6
	anl	A, R1
	orl	A, R7
	add	A, @R0
	dec	A
	dec	A
	rrc	A
	rr	A
	jmp	@A+DPTR
	add	A, 5Eh
	dec	A
	dec	A
	dec	A
	rrc	A
	inc	@R0
	jb	10h, label546
	dec	R5
label545:	addc	A, 56h
	mov	@R0, 5Ah
	orl	21h, #13h
	nop
	addc	A, @R1
	inc	R4
label508:	inc	A
label542:	inc	A
	inc	R0
	inc	R0
	inc	R0
	inc	R0
	dec	R0
	jbc	10h, label547
	jbc	64h, label548
	inc	R4
	inc	0Bh
	inc	6h
	inc	0Ah
	jbc	0Bh, label549
	dec	@R0
	dec	A
	orl	C, 80h
	sjmp	label550
	sjmp	label551
	mov	R6, #7Ch
label549:	mov	R4, #7Eh
	mov	R6, #7Eh
	mov	R6, #80h
	sjmp	label552
	sjmp	label553
	mov	R6, #7Ch
	mov	R4, #7Eh
	mov	R6, #7Eh
	mov	R6, #7Ch
	mov	R4, #7Eh
	mov	R6, #7Eh
	mov	R6, #7Dh
	mov	R5, #7Eh
	mov	R6, #7Eh
	mov	R6, #7Ch
	mov	R6, #7Fh
	sjmp	label554
	mov	R7, #80h
	sjmp	label555
	mov	TH0, R1
	mov	7Ch, R4
	mov	R6, #80h
	sjmp	label556
	anl	C, 82h
	anl	C, 83h
	mov	CLKREG, R3
	mov	7Ch, R7
	mov	R6, #80h
	anl	C, 82h
	anl	C, 82h
	anl	C, 83h
	movc	A, @A+PC
	subb	A, 95h
	mov	R4, #7Eh
	ajmp	label557
	anl	C, 82h
	anl	C, 82h
	movc	A, @A+PC
	mov	95h, TH1
	mov	R7, #80h
	anl	C, 83h
	div	AB
	movc	A, @A+PC
	movc	A, @A+PC
	movc	A, @A+PC
	movc	A, @A+PC
	mov	TH1, @R1
	subb	A, SP
	anl	C, 83h
	div	AB
	div	AB
	movc	A, @A+PC
	movc	A, @A+PC
	movc	A, @A+PC
	div	AB
	mov	TH1, @R1
	movc	A, @A+DPTR
	movc	A, @A+PC
	div	AB
	div	AB
	div	AB
	div	AB
	div	AB
	movc	A, @A+PC
	div	AB
	div	AB
	mov	TH1, @R1
	mov	DP1H, R5
	mov	DP1H, DP1H
	mov	DP1L, DP1H
	div	AB
	div	AB
	mov	TMOD, @R0
	mov	TCON, R4
	mov	TCON, R0
	mov	TCON, R0
	mov	SPDR, @R0
	mov	SPDR, @R0
	mov	SPDR, @R0
	mov	37h, @R1
	inc	2h
	ljmp	label501
	pop	P0
	movc	A, @A+PC
	movc	A, @A+PC
	div	AB
	div	AB
	addc	A, @R1
	jbc	0Ch, label558
	rr	A
	rr	A
	inc	@R1
	inc	R4
	inc	@R1
	inc	@R0
	inc	R4
	inc	R5
label554:	inc	R4
	inc	R5
	inc	@R1
	inc	6h
label558:	xrl	A, #8Ah
	mov	95h, R7
	subb	A, @R1
	subb	A, R2
	subb	A, R5
	subb	A, R5
	subb	A, R7
	subb	A, R7
	subb	A, R5
	subb	A, R5
	subb	A, R0
	mov	TL0, R5
	mov	TL0, R2
	rrc	A
	inc	A
	dec	R6
	dec	R5
	dec	R6
	xrl	A, R5
	add	A, @R0
	add	A, @R0
	rrc	A
	rrc	A
	rrc	A
	rr	A
	add	A, R5
	orl	A, R3
	anl	A, R6
	addc	A, R3
	add	A, R4
	nop
	rrc	A
	inc	A
	orl	A, R5
	dec	R5
	add	A, R2
	anl	A, R6
	add	A, R0
	dec	R3
	dec	@R0
	dec	A
	addc	A, @R1
label689:	inc	A
	inc	R2
	inc	R2
	inc	R2
	xch	A, R1
	orl	A, R1
	inc	@R0
	inc	R2
	inc	R2
	inc	R2
	dec	A
	dec	A
	subb	A, R4
	inc	R2
	inc	R2
	inc	R2
	inc	R4
	inc	R7
	inc	R7
	inc	R2
	inc	R2
	lcall	label559
	dec	R1
	inc	R7
	dec	@R0
	dec	R1
	dec	R5
	dec	R5
	dec	R5
	inc	R7
	dec	R1
	dec	R6
	ajmp	label560
	ajmp	label561
	inc	R4
	inc	A
	inc	A
	inc	R0
	inc	R0
	inc	R0
	inc	R0
	dec	R0
	jbc	10h, label562
	jbc	64h, label563
label560:	inc	R4
	inc	0Bh
	inc	6h
	inc	0Ah
	jbc	0Bh, label564
	dec	@R0
	dec	A
	orl	C, 23h
label568:	add	A, @R0
	add	A, R4
label565:	add	A, R7
label567:	acall	label565
	acall	label565
label562:	acall	label565
label569:	acall	label565
	rl	A
	add	A, @R0
	add	A, R3
	add	A, R3
	add	A, R3
	add	A, R3
	add	A, R3
	add	A, R3
	add	A, R3
	acall	label565
	acall	label566
	add	A, R2
	add	A, R3
	add	A, R4
	add	A, R4
	add	A, R4
	add	A, R1
	add	A, R1
	add	A, R1
	acall	label565
	acall	label567
	reti
	acall	label568
	add	A, R4
	add	A, R4
	add	A, R1
	add	A, R1
	add	A, R1
	acall	label565
	acall	label562
	reti
	acall	label568
	add	A, R6
	add	A, R4
	add	A, R1
	add	A, R1
	add	A, R1
	acall	label565
	acall	label569
	addc	A, 31h
	acall	label568
	add	A, R5
	add	A, R2
	add	A, R2
	add	A, R1
	add	A, R5
	add	A, R5
	add	A, R5
	addc	A, R5
	addc	A, @R0
	acall	label565
	add	A, R7
	add	A, R7
	add	A, R6
	add	A, R5
	add	A, R1
	add	A, R1
	add	A, R1
	add	A, R1
	jc	label570
	jc	label571
	jc	label572
	addc	A, R1
	addc	A, R1
	addc	A, R1
	reti
	add	A, R6
	add	A, R5
	orl	A, @R0
	orl	A, R3
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R0
label576:	orl	A, 40h
	addc	A, R1
	addc	A, @R0
	addc	A, #46h
	orl	A, R3
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R0
	orl	3Dh, A
	addc	A, R1
	addc	A, @R0
	orl	A, @R0
	orl	A, R3
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R7
label582:	orl	A, R0
	orl	A, 3Eh
	addc	A, R2
	addc	A, @R0
	orl	A, @R0
	orl	A, R3
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R7
	orl	A, R7
label584:	orl	A, R0
	orl	A, 3Eh
	addc	A, R2
	addc	A, @R0
	addc	A, @R1
	jbc	0Ch, label573
	rr	A
	rr	A
label570:	inc	@R1
	inc	R4
label571:	inc	@R1
	inc	@R0
	inc	R4
label572:	inc	R5
	inc	R4
	inc	R5
	inc	@R1
	inc	6h
label573:	xrl	A, #32h
	reti
	add	A, R5
	add	A, @R1
	add	A, @R1
	add	A, @R1
	add	A, R2
label587:	add	A, R6
	add	A, R6
	jnb	30h, label574
	jnb	32h, label575
	reti
	addc	A, @R1
label588:	inc	@R1
	ljmp	label543
	inc	R0
	jbc	18h, label576
	jc	label577
	dec	R3
	dec	R4
	add	A, R2
	add	A, R2
	orl	A, @R1
	rrc	A
	rr	A
	orl	A, R6
	anl	A, R1
	orl	A, R7
	add	A, @R0
	dec	A
	dec	A
	rrc	A
	rr	A
	jmp	@A+DPTR
	add	A, 5Eh
	dec	A
	dec	A
	dec	A
	rrc	A
	inc	@R0
	jb	10h, label578
	dec	R5
label577:	addc	A, 56h
	mov	@R0, 5Ah
	orl	21h, #13h
	nop
	addc	A, @R1
	inc	R4
	inc	A
label575:	inc	A
	inc	R0
	inc	R0
	inc	R0
	inc	R0
	dec	R0
	jbc	10h, label579
	jbc	64h, label580
	inc	R4
	inc	0Bh
	inc	6h
	inc	0Ah
	jbc	0Bh, label581
	dec	@R0
	dec	A
	orl	C, 80h
	sjmp	label582
	sjmp	label583
	mov	R6, #7Ch
label581:	mov	R4, #7Eh
	mov	R6, #7Eh
	mov	R6, #80h
	sjmp	label584
	sjmp	label585
	mov	R6, #7Ch
	mov	R4, #7Eh
	mov	R6, #7Eh
	mov	R6, #7Ch
	mov	R4, #7Eh
	mov	R6, #7Eh
	mov	R6, #7Dh
	mov	R5, #7Eh
	mov	R6, #7Eh
	mov	R6, #7Ch
	mov	R6, #7Fh
	sjmp	label586
	mov	R7, #80h
	sjmp	label587
	mov	TH0, R1
	mov	7Ch, R4
	mov	R6, #80h
	sjmp	label588
	anl	C, 82h
	anl	C, 83h
	mov	CLKREG, R3
	mov	7Ch, R7
	mov	R6, #80h
	anl	C, 82h
	anl	C, 82h
	anl	C, 83h
	movc	A, @A+PC
	subb	A, 95h
	mov	R4, #7Eh
	ajmp	label557
	anl	C, 82h
	anl	C, 82h
	movc	A, @A+PC
	mov	95h, TH1
	mov	R7, #80h
	anl	C, 83h
	div	AB
	movc	A, @A+PC
	movc	A, @A+PC
	movc	A, @A+PC
	movc	A, @A+PC
	mov	TH1, @R1
	subb	A, SP
	anl	C, 83h
	div	AB
	div	AB
	movc	A, @A+PC
	movc	A, @A+PC
	movc	A, @A+PC
	div	AB
	mov	TH1, @R1
	movc	A, @A+DPTR
	movc	A, @A+PC
	div	AB
	div	AB
	div	AB
	div	AB
	div	AB
	movc	A, @A+PC
	div	AB
	div	AB
	mov	TH1, @R1
	mov	DP1H, R5
	mov	DP1H, DP1H
	mov	DP1L, DP1H
	div	AB
	div	AB
	mov	TMOD, @R0
	mov	TCON, R4
	mov	TCON, R0
	mov	TCON, R0
	mov	SPDR, @R0
	mov	SPDR, @R0
	mov	SPDR, @R0
	mov	37h, @R1
	inc	2h
	ljmp	label501
	pop	P0
	movc	A, @A+PC
	movc	A, @A+PC
	div	AB
	div	AB
	addc	A, @R1
	jbc	0Ch, label589
	rr	A
	rr	A
	inc	@R1
	inc	R4
	inc	@R1
	inc	@R0
	inc	R4
	inc	R5
label586:	inc	R4
	inc	R5
	inc	@R1
	inc	6h
label589:	xrl	A, #8Ah
	mov	95h, R7
	subb	A, @R1
	subb	A, R2
	subb	A, R5
	subb	A, R5
	subb	A, R7
	subb	A, R7
	subb	A, R5
	subb	A, R5
	subb	A, R0
	mov	TL0, R5
	mov	TL0, R2
	rrc	A
	inc	A
	dec	R6
	dec	R5
	dec	R6
	xrl	A, R5
	add	A, @R0
	add	A, @R0
	rrc	A
	rrc	A
	rrc	A
	rr	A
	add	A, R5
	orl	A, R3
	anl	A, R6
	addc	A, R3
	add	A, R4
	nop
	rrc	A
	inc	A
	orl	A, R5
	dec	R5
	add	A, R2
	anl	A, R6
	add	A, R0
	dec	R3
	dec	@R0
	dec	A
	rrc	A
	rr	A
	orl	A, R6
	anl	A, R1
	orl	A, R7
	add	A, @R0
	inc	R5
	dec	A
	rrc	A
	rr	A
	jmp	@A+DPTR
	add	A, 5Eh
	dec	A
	dec	A
	dec	A
	rrc	A
	inc	@R0
	jb	10h, label590
	dec	R5
	addc	A, 56h
	mov	@R0, 5Ah
	orl	25h, #16h
	nop
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
label379:	jnb	7h, label591
	ljmp	label592
label591:	ljmp	ex1int_t53
label385:	jnb	7h, label593
	ljmp	label594
label593:	ret
label396:	mov	R7, 1h
	mov	R6, 0h
	mov	A, #1h
	lcall	label42
	mov	7Bh, R7
	mov	A, #41h
	movc	A, @A+DPTR
	lcall	label41
	mov	A, #42h
	movc	A, @A+DPTR
	add	A, R7
	mov	R7, A
	mov	A, #0Bh
	movc	A, @A+DPTR
	mov	R0, A
	mov	A, #0Ch
	movc	A, @A+DPTR
	mov	R1, A
	lcall	label88
	mov	A, R6
	cpl	A
	mov	R0, A
	mov	A, R7
	cpl	A
	mov	R1, A
	mov	A, #0Bh
	movc	A, @A+DPTR
	mov	R3, A
	mov	A, #0Ch
	movc	A, @A+DPTR
	mov	R4, A
	setb	C
	mov	A, R6
	subb	A, R3
	xch	A, R7
	subb	A, R4
	mov	R3, A
	clr	EA
	mov	44h, R7
	mov	45h, R3
	mov	42h, R0
	mov	43h, R1
	setb	EA
	ret
label393:	mov	A, R1
	clr	C
	jnb	0E7h, label595
	jb	1Ah, label596
	mov	A, #3Dh
	movc	A, @A+DPTR
	rrc	A
	add	A, #80h
	cjne	A, 1h, label597
label597:	jnc	label596
	mov	R1, A
	setb	3h
	sjmp	label596
label595:	mov	A, #3Eh
	movc	A, @A+DPTR
	rrc	A
	cpl	A
	add	A, #80h
	cjne	A, 1h, label598
label598:	jc	label596
	mov	R1, A
	setb	4h
label596:	mov	R2, #57h
	acall	label599
	lcall	label61
	cjne	A, 49h, label600
label600:	jc	label601
	setb	4h
label601:	mov	A, R1
	clr	C
	subb	A, #80h
	mov	5h, C
	mov	R1, A
	ljmp	ex1int_t25
label678:	mov	DPTR, #1124h
	lcall	ex0int_t38
	rrc	A
	mov	19h, C
	rrc	A
	mov	18h, C
	ljmp	ex0int_t39
label381:	mov	A, 15h
	cjne	A, #80h, label602
label602:	cpl	C
	mov	1Bh, C
	mov	DPTR, #1296h
	lcall	ex0int_t38
	rrc	A
	mov	2Fh, C
	rrc	A
	mov	2Eh, C
	nop
	nop
	nop
	jnb	2Eh, label603
	clr	7h
	ajmp	label604
label603:	setb	7h
label604:	mov	A, #10h
	movc	A, @A+DPTR
	clr	C
	subb	A, 37h
	jnc	label605
	mov	R2, #3h
	lcall	label61
	clr	C
	subb	A, 37h
	jc	label606
	ret
label605:	setb	1Ah
	jnb	7h, label607
	mov	A, #6Fh
	movc	A, @A+DPTR
	cjne	A, 13h, label608
label608:	cpl	C
	mov	2Dh, C
	mov	A, #6Dh
	movc	A, @A+DPTR
	cjne	A, 13h, label609
label609:	cpl	C
	mov	2Ch, C
	ajmp	label610
label607:	clr	2Ch
	clr	2Dh
label610:	ret
label606:	clr	1Ah
	ret
label679:	mov	R5, #0h
	clr	C
	jnb	1Ah, label611
	mov	R2, #49h
	acall	label612
	acall	label612
	ajmp	label613
label611:	jnb	18h, label614
	mov	R2, #4h
	jb	2Ch, label615
	acall	label599
	ajmp	label616
label615:	lcall	label617
label616:	acall	label612
	mov	R2, #8h
	ajmp	label618
label614:	jnb	19h, label619
	mov	R2, #0Ch
	acall	label612
	ajmp	label620
label619:	mov	R2, #12h
	jb	2Ch, label621
	acall	label599
	ajmp	label622
label621:	lcall	label617
label622:	acall	label612
	mov	A, #20h
	movc	A, @A+DPTR
	subb	A, 49h
	jc	label620
	mov	R2, #5Bh
	ajmp	label618
label620:	mov	R2, #0Dh
	acall	label612
	jb	19h, label623
	mov	R2, #5Bh
label623:	mov	DPTR, #112Eh
	lcall	ex0int_t38
	jnb	0E2h, label618
	mov	A, #21h
	movc	A, @A+DPTR
	clr	C
	subb	A, 37h
	jnc	label618
	mov	A, #22h
	movc	A, @A+DPTR
	add	A, R5
	mov	R5, A
label618:	acall	label599
	acall	label612
label613:	ljmp	ex0int_t54
label382:	mov	R2, #48h
	acall	label612
	mov	R0, A
	mov	C, 0E7h
	mov	A, #23h
	jnc	label624
	inc	A
label624:	movc	A, @A+DPTR
	mov	R1, A
	jnc	label625
	xch	A, R0
label625:	clr	C
	subb	A, R0
	jnc	label626
	mov	A, R1
	mov	R5, A
label626:	mov	A, R5
	mov	C, 0E7h
	rrc	A
	mov	R5, A
	ljmp	ex0int_t58
label612:	lcall	label61
	add	A, R5
	clr	C
	subb	A, #14h
	mov	R5, A
	ret
label387:	jb	1Ah, label627
	jb	19h, label627
	jb	1Dh, label627
	nop
	nop
	nop
	mov	A, #4Bh
	movc	A, @A+DPTR
	cjne	A, 37h, label628
label628:	jc	label627
	mov	A, #4Ch
	movc	A, @A+DPTR
	cjne	A, 49h, label629
label629:	jnc	label630
	jnb	25h, label627
	jb	21h, label631
	setb	21h
	clr	22h
	mov	A, #4Dh
	movc	A, @A+DPTR
	mov	3Fh, A
label631:	mov	A, 3Fh
	jz	label627
	sjmp	label632
label630:	clr	21h
label632:	jnb	2Ch, label633
	mov	A, #6Eh
	sjmp	label634
label633:	mov	A, #49h
	jb	18h, label634
	mov	A, #48h
label634:	movc	A, @A+DPTR
	mov	R2, A
	jb	25h, label635
	mov	A, #4Ah
	movc	A, @A+DPTR
	add	A, R2
label635:	clr	C
	subb	A, 13h
	mov	25h, C
	lcall	ex1int_t51
	sjmp	label636
label627:	clr	25h
label636:	ljmp	ex1int_t52
label617:	mov	A, #2h
	add	A, R2
	mov	R2, A
	ret
label594:	mov	R2, #3Eh
	jb	2Eh, label637
	jnb	T0, label637
	mov	R2, #41h
label637:	ljmp	ex1int_t34
	mov	R7, A
label680:	mov	DPTR, #112Eh
	lcall	ex0int_t38
	clr	0E2h
	add	A, #1Bh
	movc	A, @A+DPTR
	mov	B, A
	mov	R2, #2Ah
	lcall	label61
	mul	AB
	mov	R7, B
	mov	R6, A
	mov	50h, #2h
	jnb	2Fh, label638
	mov	A, #6Bh
	movc	A, @A+DPTR
	acall	label639
label638:	jnb	1Ah, label640
	mov	R2, #28h
	mov	A, #1Fh
	movc	A, @A+DPTR
	cjne	A, 13h, label641
label641:	jnc	label642
	inc	R2
label642:	lcall	label61
	mov	3Ch, A
	mov	R2, #53h
	lcall	label61
	mov	R4, A
	mov	R3, #5h
	mov	R1, #8h
	jb	0Ch, label643
	lcall	label61
	clr	C
	subb	A, 37h
	jc	label644
	mov	A, #1Ah
	movc	A, @A+DPTR
	subb	A, 4Dh
	jnc	label645
label644:	setb	0Ch
	mov	4Dh, #0h
label643:	mov	R2, #55h
	lcall	label61
	mov	B, A
	lcall	label61
	mul	AB
	mov	A, R4
label647:	jb	0E7h, label646
	rl	A
	xch	A, R1
	rl	A
	xch	A, R1
	dec	R3
	sjmp	label647
label646:	mul	AB
	mov	R4, B
	jnb	0E7h, label645
	inc	R4
label645:	mov	A, R4
	cjne	A, 1h, label648
label648:	jc	label649
	lcall	label41
	mov	A, 50h
	add	A, R3
	lcall	label42
	mov	50h, A
label649:	ljmp	label650
label640:	jb	2Dh, label651
	acall	label599
	ajmp	label652
label651:	lcall	label617
label652:	lcall	label61
	mov	B, A
	mov	R2, #2Fh
	jnb	18h, label653
	inc	R2
label653:	lcall	label61
	mul	AB
	mov	A, B
	acall	label654
	mov	A, 3Ch
	acall	label654
	mov	R2, #31h
	jb	18h, label655
	mov	R2, #4Bh
	jb	19h, label655
	mov	R2, #4Fh
label655:	acall	label599
	lcall	label61
	acall	label639
label650:	ljmp	ex0int_t85
label384:	mov	4Eh, R6
	mov	4Fh, R7
	ljmp	ex0int_t86
label654:	jz	label656
	add	A, #80h
	jnc	label639
	rrc	A
	inc	50h
label639:	lcall	label41
	mov	A, 50h
	inc	A
	lcall	label42
	mov	50h, A
label656:	ret
	mov	R7, A
	mov	R7, A
	mov	R7, A
	mov	R7, A
label388:	mov	B, R0
	mov	P2, #19h
	mov	R0, #1Bh
	cjne	R0, #1Bh, label657
	setb	F0
	sjmp	label658
label657:	mov	A, @R0
	movx	@R0, A
label662:	mov	P2, #1Bh
	mov	R0, #31h
	cjne	R0, #31h, label659
	mov	A, @R0
	add	A, #0Ah
	rl	A
	sjmp	label660
label659:	mov	A, @R0
label660:	movx	@R0, A
	inc	P2
	mov	A, 37h
	movx	@R0, A
	inc	P2
	mov	A, 49h
	movx	@R0, A
	inc	P2
	mov	A, 10h
	movx	@R0, A
	inc	P2
	mov	A, 13h
	movx	@R0, A
	sjmp	label661
	mov	P2, #98h
	clr	F0
label658:	mov	A, #60h
	cpl	A
	inc	A
	add	A, 1Bh
	rl	A
	rl	A
	mov	R0, A
	mov	A, 1Ch
	rlc	A
	rlc	A
	rlc	A
	anl	A, #3h
	addc	A, R0
	movx	@R0, A
	jbc	F0, label662
label661:	mov	R0, B
	ret
label371:	mov	28h, #80h
	mov	26h, #0h
	mov	29h, #0FFh
	setb	2Bh
	setb	TB8
	clr	TI
	mov	SBUF, #0FFh
	jnb	TI, $
	clr	TB8
	clr	RI
	ret
label374:	jnb	1Fh, label663
	ret
label663:	jnb	1Eh, label664
	ret
label664:	jnb	2Bh, label665
	clr	2Bh
	jb	RI, label666
	setb	1Fh
	ret
label666:	mov	A, SBUF
	cjne	A, #0EEh, label667
	setb	1Eh
	clr	TI
	mov	SBUF, #0FFh
	jnb	TI, $
	mov	SCON, #0B0h
	ret
label667:	mov	A, SBUF
	clr	C
	subb	A, #0FFh
	jz	label668
	setb	1Fh
	ret
label665:	jnb	RI, label668
	mov	A, 29h
	clr	C
	subb	A, #0FFh
	jz	label668
	mov	DPTR, #11DAh
	mov	A, 29h
	movc	A, @A+DPTR
	mov	R1, A
	mov	@R1, SBUF
label668:	mov	DPTR, #11D1h
	clr	A
	movc	A, @A+DPTR
	lcall	label669
	inc	DPTR
	clr	A
	movc	A, @A+DPTR
	lcall	label669
	inc	DPTR
	clr	A
	movc	A, @A+DPTR
	lcall	label669
	mov	R1, 7Ah
	clr	TI
	mov	A, @R1
	mov	SBUF, A
	jnb	TI, $
	setb	TB8
	inc	29h
	mov	A, 29h
	cjne	A, #6h, label670
	mov	29h, #0FFh
	mov	A, #0FFh
	ljmp	label671
label670:	mov	DPTR, #11D4h
	movc	A, @A+DPTR
	mov	R1, A
	mov	A, @R1
	cjne	A, #0FFh, label671
	mov	A, #0FEh
label671:	clr	TI
	mov	SBUF, A
	jnb	TI, $
	clr	TB8
	clr	RI
	mov	DPTR, #1160h
	ret
label669:	cjne	A, #0FFh, label672
	jnb	1Dh, label673
	clr	A
	ljmp	label674
label673:	mov	A, 4Bh
	mov	C, 0E4h
	anl	A, #0Fh
	swap	A
	mov	B, A
	mov	A, 4Ah
	anl	A, #0F0h
	swap	A
	orl	A, B
	rrc	A
	ljmp	label674
label672:	mov	R1, A
	mov	A, @R1
label674:	clr	TI
	mov	SBUF, A
	jnb	TI, $
	ret
	jb	1Fh, label675
	jb	1Eh, label675
	mov	A, 26h
	add	A, R5
	mov	R5, A
label675:	ajmp	label382
	jb	1Fh, label676
	jb	1Eh, label676
	mov	A, 28h
	acall	label639
label676:	ljmp	label384
label370:	mov	TMOD, #11h
	mov	IP, #2h
	orl	IE, #85h
	orl	TCON, #5h
	mov	DPTR, #1160h
	mov	SP, #63h
	clr	92h
label369:	mov	A, #0Dh
	movc	A, @A+DPTR
	mov	2Ah, A
	lcall	label358
	lcall	label359
	lcall	label677
	lcall	label678
	lcall	label677
	lcall	label679
	lcall	label359
	lcall	label677
	lcall	label363
	lcall	label677
	lcall	label359
	lcall	label680
	lcall	label677
	ljmp	label365
label375:	jnb	1Ch, label370
	lcall	ex1int_t1
	lcall	label366
	ret
label677:	jbc	17h, label681
	ret
label681:	ljmp	label368
label378:	jb	1Ah, label682
	jb	18h, label682
	clr	C
	mov	A, 10h
	subb	A, 53h
	jc	label682
	mov	3h, A
	mov	A, #37h
	movc	A, @A+DPTR
	clr	C
	subb	A, 37h
	jnc	label683
	mov	B, #0h
	ajmp	label684
label683:	mov	R2, #1Ch
	lcall	label61
	mov	B, A
	acall	label599
	lcall	label61
	mul	AB
label684:	jb	0Fh, label685
	mov	4Ch, B
label685:	mov	R2, #21h
	lcall	label61
	jz	label682
	mov	B, A
	mov	A, 4Ch
	jz	label686
	setb	0Fh
label686:	acall	label599
	lcall	label61
	mul	AB
	mov	R2, #26h
	lcall	label61
	mul	AB
	mov	A, B
	cjne	A, 3Dh, label687
label687:	jc	label682
	mov	3Dh, A
label682:	mov	53h, 52h
	mov	52h, 51h
	mov	51h, 10h
	mov	A, 3Dh
	lcall	label654
	ljmp	ex0int_t03
label599:	clr	A
	mov	C, T0
	rlc	A
	mov	C, 2Eh
	jnc	label688
	rlc	A
	add	A, R2
	mov	R2, A
label688:	ret
	END
