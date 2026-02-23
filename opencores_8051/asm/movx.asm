reset:		ljmp	rst_tar
		org 100h
rst_tar:	mov	R0, #64h	
		clr	A
zero_ram_loop:	mov	@R0, A
		djnz	R0, zero_ram_loop
		mov	R2, #32h	
		mov	R0, #10h	
		mov	R3, #8h	
		movx	A, @R0	
read:		djnz	R2, $
		inc	P2
		movx	A, @R0
		mov	@R0, A
		inc	R0
		mov	R2, #32h
		movx	A, @R0
		djnz	R3,read
		mov	A, 12h
		END
