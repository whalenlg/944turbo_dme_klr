; Annotated, best-effort 8051 linear disassembly
; Recognized opcodes: LJMP(02), LCALL(12), SJMP(80), MOV DPTR(90), INC DPTR(A3),
; MOV A,#(74), MOV direct,#(75), NOP(00), RET(22), CLR A(E4), MOVX @DPTR,A(F0)
; Unknown bytes are emitted as DB directives.
    ORG 0000h

loc_0000h: ; referenced target
0000:    LJMP loc_024Eh    ; 02 02 4E
0003:    DB 0C2h, 08Bh, 021h
0006:    MOVX @DPTR, A
0007:    DB 0FFh, 0FFh, 0FFh, 0FFh, 0D2h
000C:    MOV DPTR, #C20Ah   ; 90 C2 0A
000F:    DB 032h, 0FFh, 0FFh, 0FFh, 005h, 036h, 030h, 01Ch, 044h, 032h, 0FFh, 0FFh, 0D5h, 02Ah, 013h, 011h
001F:    RET
0020:    DB 041h, 04Eh, 032h, 010h, 099h, 008h, 0A8h, 099h, 0C2h, 09Bh, 086h, 099h, 0C2h, 098h, 0C2h, 089h
0030:    DB 032h, 010h, 094h, 00Eh, 0D2h, 094h, 085h, 041h, 08Dh, 085h, 040h, 08Bh, 020h, 01Ch
003E:    LJMP C289h    ; 02 C2 89
0041:    DB 032h, 085h, 045h, 08Dh, 085h, 044h, 08Bh, 085h, 043h, 041h, 085h, 042h, 040h, 085h, 036h, 037h
0051:    MOV 36h, #00h   ; 75 36 00
0054:    DB 0D2h, 017h, 020h, 01Ch
0058:    LJMP C289h    ; 02 C2 89
005B:    DB 032h, 0D5h, 02Bh, 031h, 0D5h, 02Dh, 003h
0062:    LCALL loc_1000h   ; 12 10 00
0065:    DB 053h, 0A8h, 0EAh, 011h, 096h, 030h, 08Bh, 0FDh, 005h, 036h, 0C2h, 08Bh, 0D5h, 02Dh, 003h
0074:    LCALL loc_1000h   ; 12 10 00
0077:    DB 020h, 010h, 00Dh, 020h, 0B3h, 003h, 030h, 08Bh, 0FAh, 0B2h, 091h, 020h, 08Bh, 007h, 001h, 082h
0087:    DB 030h, 08Bh, 0FDh, 0B2h, 091h, 0D2h, 0AAh, 001h, 097h, 0D5h, 02Dh, 003h
0093:    LCALL loc_1000h   ; 12 10 00
0096:    DB 032h, 0C0h, 0E0h, 0C0h, 0D0h, 020h, 091h, 01Ah
009E:    CLR A
009F:    DB 0A2h, 010h, 035h, 030h, 013h, 014h, 092h, 010h, 0C2h, 0AAh, 025h, 02Bh, 0F5h, 02Bh, 0D2h, 0AAh
00AF:    DB 0C2h, 089h, 0D2h, 0A8h, 0D0h, 0D0h, 0D0h, 0E0h
00B7:    RET
00B8:    DB 0C0h, 083h, 0C0h, 082h, 0C0h
00BD:    MOVX @DPTR, A
00BE:    MOV DPTR, #1160h   ; 90 11 60
00C1:    CLR A
00C2:    DB 0A2h, 010h, 035h, 033h, 095h, 031h, 0C3h, 095h, 057h, 0C3h, 095h, 02Fh, 013h, 014h, 092h, 010h
00D2:    DB 0C2h, 0AAh, 025h, 02Bh, 0F5h, 02Bh, 0D2h, 0AAh
00DA:    MOV A, #03h    ; 74 03
00DC:    DB 025h, 035h, 093h, 0C2h, 0AAh, 025h, 02Dh, 0F5h, 02Dh, 0D2h, 0AAh, 051h, 01Dh, 0C2h, 089h, 0D2h
00EC:    DB 0A8h
00ED:    MOV D0h, #18h   ; 75 D0 18
00F0:    LJMP loc_1029h    ; 02 10 29
loc_00F3h: ; referenced target
00F3:    DB 0D5h, 034h, 036h, 07Dh, 02Dh, 020h, 016h, 00Ch, 07Dh, 02Bh, 020h, 015h, 007h, 07Dh, 029h, 020h
0103:    DB 014h
0104:    LJMP 7D27h    ; 02 7D 27
0107:    DB 0EDh, 093h, 0F5h, 034h, 00Dh, 0EDh, 093h, 0FDh, 0E5h, 032h, 0FEh, 0AFh, 031h, 0C3h, 09Fh, 0C3h
0117:    DB 030h, 0E7h, 00Ah, 0F4h, 004h, 09Dh, 0EEh, 040h, 00Ah, 0EFh, 09Dh, 021h, 02Ah, 09Dh, 0EEh, 040h
0127:    LJMP EF2Dh    ; 02 EF 2D
012A:    DB 0F5h, 031h
loc_012Ch: ; referenced target
012C:    MOV A, #01h    ; 74 01
012E:    DB 093h, 005h, 035h, 0B5h, 035h, 00Fh
0134:    MOV 35h, #00h   ; 75 35 00
0137:    MOV DPTR, #0000h   ; 90 00 00
013A:    MOVX @DPTR, A
013B:    MOVX @DPTR, A
013C:    MOVX @DPTR, A
013D:    MOVX @DPTR, A
013E:    MOV DPTR, #1160h   ; 90 11 60
0141:    DB 021h, 066h, 020h, 01Ah, 020h, 010h, 00Fh
0148:    LJMP 21E5h    ; 02 21 E5
014B:    MOV F0h, #40h   ; 75 F0 40
014E:    DB 0E5h, 04Ch, 0A4h, 0FEh, 0AFh
0153:    MOVX @DPTR, A
0154:    DB 030h, 00Ah, 064h, 0C2h, 08Ch, 0C3h, 0E5h, 08Ah, 09Eh, 0F5h, 08Ah, 0E5h, 08Ch, 09Fh, 0F5h, 08Ch
0164:    DB 021h, 0D0h, 0C3h
0167:    MOV A, #11h    ; 74 11
0169:    DB 093h, 095h, 037h, 072h, 01Dh, 040h, 06Eh, 0AEh, 04Ah, 0AFh, 04Bh
0174:    LJMP loc_102Ch    ; 02 10 2C
loc_0177h: ; referenced target
0177:    DB 020h, 01Ah, 041h, 030h, 00Dh, 02Dh, 0E5h, 04Dh, 0B4h, 010h
0181:    NOP
0182:    DB 040h, 00Ch, 0C2h, 00Dh, 030h, 016h, 005h, 0C2h, 016h
018B:    MOV 34h, #01h   ; 75 34 01
018E:    DB 021h, 0AAh
0190:    MOV DPTR, #1140h   ; 90 11 40
0193:    DB 020h, 00Eh
0195:    LJMP 2410h    ; 02 24 10
0198:    DB 093h, 0B4h, 040h, 008h, 030h, 016h, 005h, 0C2h, 016h
01A1:    MOV 34h, #01h   ; 75 34 01
01A4:    DB 091h, 0D9h
01A6:    MOV A, #02h    ; 74 02
01A8:    DB 0B1h, 009h, 030h, 00Fh, 00Eh, 0C2h, 00Fh
01AF:    MOV F0h, #40h   ; 75 F0 40
01B2:    DB 0E5h, 04Ch, 0A4h, 02Eh, 0FEh, 0E5h
01B8:    MOVX @DPTR, A
01B9:    DB 03Fh, 0FFh
01BB:    LJMP loc_102Fh    ; 02 10 2F
loc_01BEh: ; referenced target
01BE:    DB 0E5h, 054h
01C0:    MOV F0h, #05h   ; 75 F0 05
01C3:    DB 0A4h, 0C2h, 08Ch, 02Eh, 0F4h, 0F5h, 08Ah, 0E5h
01CB:    MOVX @DPTR, A
01CC:    DB 03Fh, 0F4h, 0F5h, 08Ch, 0C2h, 0AFh, 0C2h
01D3:    MOV DPTR, #D20Ah   ; 90 D2 0A
01D6:    DB 0D2h, 08Ch, 0D2h, 0A9h, 0C2h, 089h, 0D2h, 0AFh, 0E5h, 04Dh, 020h, 0E7h
01E2:    LJMP loc_054Dh    ; 02 05 4D
01E5:    DB 0D0h
01E6:    MOVX @DPTR, A
01E7:    DB 0D0h, 082h, 0D0h, 083h, 0D0h, 0D0h, 0D0h, 0E0h
01EF:    RET
01F0:    DB 0C0h, 0D0h, 0A2h, 0B3h, 072h, 08Bh, 085h, 02Ch, 02Bh, 085h, 02Eh, 02Dh, 040h, 004h, 0A2h, 011h
0200:    DB 041h, 008h, 0B0h, 011h, 040h
0205:    LJMP loc_052Bh    ; 02 05 2B
0208:    DB 092h, 010h, 0D5h, 02Bh, 006h, 005h, 02Bh, 015h, 030h, 015h, 030h
0213:    MOV 35h, #00h   ; 75 35 00
0216:    DB 0A2h, 013h, 092h, 091h, 0D0h, 0D0h, 032h
loc_021Dh: ; referenced target
021D:    MOV A, #02h    ; 74 02
021F:    DB 093h, 0F5h, 02Eh, 0D2h, 013h
0224:    MOV A, #00h    ; 74 00
0226:    DB 093h, 0D3h, 095h, 031h, 0C3h, 095h, 057h, 0C3h, 095h, 02Fh, 050h, 005h, 0C3h, 0C2h, 013h, 035h
0236:    DB 02Fh, 0C3h, 013h, 060h, 0F8h, 0F5h, 02Ch, 092h, 011h
023F:    MOV A, #07h    ; 74 07
0241:    DB 025h, 035h, 093h, 025h, 031h, 025h, 057h, 0F5h, 033h, 085h, 02Fh, 030h
024D:    RET
loc_024Eh: ; referenced target
024E:    MOV A8h, #80h   ; 75 A8 80
0251:    MOV 90h, #FFh   ; 75 90 FF
0254:    MOV B0h, #FFh   ; 75 B0 FF
0257:    MOV 89h, #11h   ; 75 89 11
025A:    MOV B8h, #02h   ; 75 B8 02
025D:    MOV 88h, #05h   ; 75 88 05
0260:    MOV 98h, #90h   ; 75 98 90
0263:    MOV 81h, #63h   ; 75 81 63
0266:    MOV DPTR, #1160h   ; 90 11 60
0269:    MOV D0h, #00h   ; 75 D0 00
026C:    DB 078h, 064h
026E:    CLR A
026F:    LJMP loc_100Bh    ; 02 10 0B
loc_0272h: ; referenced target
0272:    DB 0F6h, 0D8h, 0FDh
0275:    LJMP loc_100Eh    ; 02 10 0E
loc_0278h: ; referenced target
0278:    DB 0D2h, 01Ch, 078h
027B:    NOP
027C:    DB 079h, 040h
027E:    LCALL loc_0A05h   ; 12 0A 05
0281:    DB 0D2h, 08Eh, 0D2h, 0ABh, 0D2h, 0AAh, 0D2h, 08Fh, 030h, 017h, 0FDh, 0C2h, 017h, 030h, 017h, 0FDh
0291:    DB 0D2h, 01Ah
0293:    LCALL loc_1005h   ; 12 10 05
0296:    MOV A, #0Eh    ; 74 0E
0298:    DB 093h, 0F8h, 051h, 0BFh, 0D8h, 0FCh
029E:    LJMP loc_1017h    ; 02 10 17
02A1:    DB 0C2h, 089h
02A3:    MOV A0h, #00h   ; 75 A0 00
02A6:    DB 0F2h, 0F2h, 0F2h, 0F2h
02AA:    MOV A, #0Dh    ; 74 0D
02AC:    DB 093h, 0F5h, 02Ah, 030h, 017h, 003h, 0C2h, 017h, 0F2h, 030h, 089h, 0F5h, 0D2h, 0A8h, 0C2h, 01Ch
02BC:    LJMP loc_1008h    ; 02 10 08
02BF:    DB 030h, 0B3h, 0FDh, 020h, 0B3h, 0FDh
02C5:    RET
loc_02C6h: ; referenced target
02C6:    MOV A0h, #00h   ; 75 A0 00
02C9:    DB 0E2h, 07Ah, 032h, 078h, 010h, 07Bh, 008h, 0E2h, 0DAh, 0FEh, 005h, 0A0h, 0E2h, 0F6h, 008h, 07Ah
02D9:    DB 032h, 0E2h, 0DBh, 0F4h, 0E5h
02DE:    LCALL F4FCh   ; 12 F4 FC
02E1:    DB 07Ah, 001h, 0B1h, 01Dh, 0F5h
02E6:    LCALL E513h   ; 12 E5 13
02E9:    DB 0F4h, 0FCh, 0B1h, 01Dh, 0F5h, 013h, 078h, 038h, 079h, 03Ch, 07Ah, 004h, 07Bh, 033h, 020h, 01Ch
02F9:    DB 005h, 0E6h, 014h, 0F6h, 070h, 008h, 0EBh, 093h, 0F6h, 0E7h, 060h
loc_0304h: ; referenced target
0304:    LJMP loc_14F7h    ; 02 14 F7
0307:    DB 008h, 009h, 00Bh, 0DAh, 0EBh
loc_030Ch: ; referenced target
030C:    MOV A, #18h    ; 74 18
loc_030Eh: ; referenced target
030E:    DB 093h, 0B5h, 037h
0311:    NOP
0312:    DB 040h, 064h, 020h, 01Ch, 061h, 0ADh, 055h, 0E5h, 037h, 0C3h, 09Dh, 092h, 0D5h, 050h
0320:    LJMP F404h    ; 02 F4 04
0323:    DB 0C5h
0324:    MOVX @DPTR, A
0325:    MOV A, #15h    ; 74 15
0327:    DB 093h, 0A4h, 0FEh, 020h, 0E7h, 004h, 0C5h
032E:    MOVX @DPTR, A
032F:    DB 060h
0330:    LJMP 7E7Fh    ; 02 7E 7F
0333:    DB 0E5h, 056h, 030h, 0D5h, 00Fh, 0C3h, 09Eh, 050h, 017h, 024h
033D:    SJMP loc_02FCh    ; relative -67
033F:    NOP
0340:    LJMP 8010h    ; 02 80 10
0343:    DB 015h, 055h
0345:    SJMP loc_0353h    ; relative +12
0347:    DB 02Eh, 050h, 009h, 024h
034B:    SJMP loc_030Ah    ; relative -67
034D:    DB 0FFh
034E:    LJMP 8002h    ; 02 80 02
0351:    DB 005h, 055h, 0F5h, 056h
0355:    MOV A, #19h    ; 74 19
0357:    DB 093h, 0B5h, 049h
035A:    NOP
035B:    MOV A, #00h    ; 74 00
035D:    DB 040h, 015h, 0E5h, 055h, 0B5h, 037h
0363:    LJMP 8007h    ; 02 80 07
0366:    DB 040h, 009h
0368:    MOV A, #16h    ; 74 16
036A:    DB 093h
036B:    SJMP loc_0374h    ; relative +7
036D:    MOV A, #00h    ; 74 00
036F:    SJMP loc_0374h    ; relative +3
0371:    MOV A, #17h    ; 74 17
0373:    DB 093h, 0F5h, 057h
0376:    SJMP loc_0381h    ; relative +9
0378:    DB 085h, 037h, 055h
037B:    MOV 56h, #80h   ; 75 56 80
037E:    MOV 57h, #00h   ; 75 57 00
loc_0381h: ; referenced target
0381:    DB 030h, 01Ah, 023h, 07Dh
0385:    NOP
0386:    MOV A, #12h    ; 74 12
0388:    DB 093h, 0F5h, 049h
038B:    MOV F0h, #19h   ; 75 F0 19
038E:    DB 0A4h, 0FEh, 0AFh
0391:    MOVX @DPTR, A
0392:    MOV A, #01h    ; 74 01
0394:    DB 093h, 085h, 049h
0397:    MOVX @DPTR, A
0398:    DB 0A4h
0399:    MOV F0h, #19h   ; 75 F0 19
039C:    DB 0A4h, 085h
039E:    MOVX @DPTR, A
039F:    DB 046h, 0F5h, 047h
03A2:    MOV 48h, #00h   ; 75 48 00
03A5:    DB 081h, 005h, 0ABh, 037h
03A9:    MOV A, #32h    ; 74 32
03AB:    DB 08Bh
03AC:    MOVX @DPTR, A
03AD:    DB 084h, 0FFh, 091h, 0EAh, 0FEh, 0E5h, 010h
03B4:    MOV F0h, #20h   ; 75 F0 20
03B7:    DB 084h, 0FAh, 0ABh
03BA:    MOVX @DPTR, A
03BB:    MOV DPTR, #10F4h   ; 90 10 F4
03BE:    DB 093h, 091h, 0D9h
03C1:    MOV DPTR, #10FCh   ; 90 10 FC
03C4:    DB 0EAh, 093h, 0B1h, 009h
03C8:    MOV DPTR, #1104h   ; 90 11 04
03CB:    DB 0EBh, 093h, 091h, 0D9h
03CF:    MOV DPTR, #1160h   ; 90 11 60
03D2:    MOV A, #13h    ; 74 13
03D4:    DB 091h, 03Dh
03D6:    MOV A, #14h    ; 74 14
03D8:    DB 091h, 03Fh, 0EEh, 0FBh, 0EFh, 0FCh, 07Ah, 01Bh
03E0:    LCALL loc_051Dh   ; 12 05 1D
03E3:    DB 0FDh, 0AAh, 046h, 0A9h, 047h, 0A8h, 048h
03EA:    LCALL loc_05FAh   ; 12 05 FA
03ED:    DB 08Ah, 046h, 089h, 047h, 088h, 048h, 0AFh, 046h, 0AEh, 047h
03F7:    MOV A, #A4h    ; 74 A4
03F9:    DB 091h, 0D9h
03FB:    MOV A, #04h    ; 74 04
03FD:    DB 0B1h, 009h, 08Fh, 049h, 0AFh, 046h, 0AEh, 047h
0405:    LJMP loc_1032h    ; 02 10 32
loc_0408h: ; referenced target
0408:    DB 0C0h, 050h
040A:    LJMP loc_1035h    ; 02 10 35
loc_040Dh: ; referenced target
040D:    DB 0A8h, 04Eh, 0A9h, 04Fh, 091h, 055h, 0E5h, 050h, 0B1h, 009h, 0D0h, 050h
0419:    LCALL loc_1038h   ; 12 10 38
041C:    DB 07Ah, 01Ah, 0B1h, 01Dh, 0F5h, 054h, 0C2h, 0AFh, 08Fh, 04Bh, 08Eh, 04Ah, 0C2h, 089h, 0D2h, 0AFh
042C:    LCALL loc_103Bh   ; 12 10 3B
042F:    DB 030h, 01Eh, 008h, 079h, 050h, 0D2h, 0ACh, 0D9h, 0FCh, 0C2h, 0ACh
043A:    LJMP loc_103Eh    ; 02 10 3E
043D:    DB 0D2h, 0D5h, 093h
0440:    MOV F0h, #19h   ; 75 F0 19
0443:    DB 0A4h, 0FBh, 09Eh, 0E5h
0447:    MOVX @DPTR, A
0448:    DB 09Fh, 010h, 0D5h, 001h, 0B3h, 050h, 005h, 0EBh, 0FEh, 0E5h
0452:    MOVX @DPTR, A
0453:    DB 0FFh
0454:    RET
loc_0455h: ; referenced target
0455:    DB 0E8h, 08Eh
0457:    MOVX @DPTR, A
0458:    DB 0A4h, 0ADh
045A:    MOVX @DPTR, A
045B:    DB 0E9h, 08Eh
045D:    MOVX @DPTR, A
045E:    DB 0A4h, 02Dh, 0FDh
0461:    CLR A
0462:    DB 035h
0463:    MOVX @DPTR, A
0464:    DB 0FEh, 0E8h, 08Fh
0467:    MOVX @DPTR, A
0468:    DB 0A4h, 02Dh, 0FDh, 0EEh, 035h
046D:    MOVX @DPTR, A
046E:    DB 0FEh
046F:    CLR A
0470:    DB 033h, 0CFh, 0F5h
0473:    MOVX @DPTR, A
0474:    DB 0E9h, 0A4h, 02Eh, 0FEh, 0EFh, 035h
047A:    MOVX @DPTR, A
047B:    DB 0FFh
047C:    RET
047D:    DB 020h, 01Ah, 049h, 020h, 018h, 046h, 0C3h, 0E5h, 010h, 095h, 053h, 040h, 03Fh, 0F5h, 003h
048C:    MOV A, #37h    ; 74 37
048E:    DB 093h, 0C3h, 095h, 037h, 050h, 005h
0494:    MOV F0h, #00h   ; 75 F0 00
0497:    DB 081h, 0A4h, 07Ah, 01Ch
049B:    LCALL loc_051Dh   ; 12 05 1D
049E:    DB 0F5h
049F:    MOVX @DPTR, A
04A0:    LCALL loc_051Dh   ; 12 05 1D
04A3:    DB 0A4h, 020h, 00Fh, 003h, 085h
04A8:    MOVX @DPTR, A
04A9:    DB 04Ch, 07Ah, 01Eh
04AC:    LCALL loc_051Dh   ; 12 05 1D
04AF:    DB 060h, 018h, 0F5h
04B2:    MOVX @DPTR, A
04B3:    DB 0E5h, 04Ch, 060h
04B6:    LJMP D20Fh    ; 02 D2 0F
04B9:    LCALL loc_051Dh   ; 12 05 1D
04BC:    DB 0A4h, 0B1h, 01Dh, 0A4h, 0E5h
04C1:    MOVX @DPTR, A
04C2:    DB 0B5h, 03Dh
04C4:    NOP
04C5:    DB 040h
04C6:    LJMP F53Dh    ; 02 F5 3D
04C9:    DB 085h, 052h, 053h, 085h, 051h, 052h, 085h, 010h, 051h, 0E5h, 03Dh
04D4:    LCALL loc_087Dh   ; 12 08 7D
04D7:    DB 081h, 00Dh, 0FDh, 08Eh
04DB:    MOVX @DPTR, A
04DC:    DB 0A4h, 0AEh
04DE:    MOVX @DPTR, A
04DF:    DB 0CDh, 08Fh
04E1:    MOVX @DPTR, A
04E2:    DB 0A4h, 02Eh, 0FEh
04E5:    CLR A
04E6:    DB 035h
04E7:    MOVX @DPTR, A
04E8:    DB 0FFh
04E9:    RET
loc_04EAh: ; referenced target
04EA:    CLR A
04EB:    DB 07Ch, 008h, 0C3h, 033h, 0C5h
04F0:    MOVX @DPTR, A
04F1:    DB 033h, 010h, 0D7h, 00Bh, 09Bh, 050h, 001h, 02Bh, 0C5h
04FA:    MOVX @DPTR, A
04FB:    DB 0DCh, 0F1h, 033h, 0F4h
04FF:    RET
0500:    DB 09Bh, 0C3h, 0C5h
0503:    MOVX @DPTR, A
0504:    DB 0DCh, 0E8h, 033h, 0F4h
0508:    RET
loc_0509h: ; referenced target
0509:    DB 060h, 005h, 0CFh, 030h, 0E7h
050E:    LJMP CF22h    ; 02 CF 22
0511:    DB 0C3h, 0CDh, 033h, 0CDh, 0CEh, 033h, 0CEh, 033h, 0CFh, 014h, 0A1h, 009h, 0C0h
051E:    MOVX @DPTR, A
051F:    MOV DPTR, #1090h   ; 90 10 90
0522:    DB 0EAh, 00Ah, 0D2h, 0D3h, 093h, 0B4h, 0FFh, 004h, 0D2h, 02Ah, 0A1h, 070h, 0C2h, 02Ah, 0A2h, 0E0h
0532:    DB 0C2h, 0E0h
0534:    MOV DPTR, #11E0h   ; 90 11 E0
0537:    DB 0FFh, 00Fh, 093h, 0CFh, 093h, 0F5h, 082h, 08Fh, 083h, 040h, 006h, 0B1h, 078h, 0B1h, 0A1h, 0A1h
0547:    DB 070h, 0B1h, 078h, 089h
054B:    MOVX @DPTR, A
054C:    DB 0E8h, 0FEh, 0EBh, 0FFh, 0B1h, 078h, 0EAh, 0A4h, 029h, 0F9h, 0EFh, 060h
0558:    LJMP B1A1h    ; 02 B1 A1
055B:    DB 0CAh, 0F4h, 004h, 029h, 0F9h, 0B1h, 0A1h, 0CFh, 070h, 003h, 0CFh, 0A1h, 070h, 0FBh, 08Eh
056A:    MOVX @DPTR, A
056B:    DB 0CFh, 0FDh, 0EAh, 0B1h, 0B0h, 0C2h, 0D3h, 0D0h
0573:    MOVX @DPTR, A
0574:    MOV DPTR, #1160h   ; 90 11 60
0577:    RET
0578:    CLR A
0579:    DB 093h, 0F8h
057B:    INC DPTR
057C:    CLR A
057D:    DB 093h, 0FAh, 0F9h, 0E6h, 0F8h, 0E9h, 093h, 028h, 0F8h, 040h, 006h, 0D9h, 0F8h, 009h
058B:    CLR A
058C:    DB 0A1h, 094h, 0E9h, 06Ah, 060h
0591:    LJMP E993h    ; 02 E9 93
0594:    DB 0FBh
0595:    INC DPTR
0596:    DB 0EAh, 025h, 082h, 0F5h, 082h
059B:    CLR A
059C:    DB 035h, 083h, 0F5h, 083h
05A0:    RET
05A1:    DB 0EBh, 070h, 004h, 0E9h, 014h, 093h
05A7:    RET
05A8:    DB 088h
05A9:    MOVX @DPTR, A
05AA:    DB 0E9h, 014h, 093h, 0FDh, 0E9h, 093h, 0C3h, 09Dh, 092h, 0D5h, 050h
05B5:    LJMP F404h    ; 02 F4 04
05B8:    DB 0A4h, 0A1h, 0DAh, 0C5h
05BC:    MOVX @DPTR, A
05BD:    DB 0C3h, 033h, 040h
05C0:    LJMP 9BB3h    ; 02 9B B3
05C3:    CLR A
05C4:    DB 035h
05C5:    MOVX @DPTR, A
05C6:    DB 030h, 0D5h
05C8:    LJMP F404h    ; 02 F4 04
05CB:    DB 02Dh
05CC:    RET
loc_05CDh: ; referenced target
05CD:    DB 0D2h, 0D3h, 0B1h, 078h, 019h, 0E9h, 093h
05D4:    MOV DPTR, #1160h   ; 90 11 60
05D7:    DB 0C2h, 0D3h
05D9:    RET
05DA:    DB 07Ch, 008h, 0C3h, 033h, 0C5h
05DF:    MOVX @DPTR, A
05E0:    DB 033h, 010h, 0D7h, 00Ch, 09Bh, 050h, 001h, 02Bh, 0C5h
05E9:    MOVX @DPTR, A
05EA:    DB 0DCh, 0F1h, 033h, 0F4h, 0A1h, 0BBh, 09Bh, 0C3h, 0C5h
05F3:    MOVX @DPTR, A
05F4:    DB 0DCh, 0E7h, 033h, 0F4h, 0A1h, 0BBh, 0EBh, 0C3h, 099h, 0FEh, 0ECh, 09Ah, 0FFh, 070h, 004h, 0EEh
0604:    DB 070h, 001h, 0F8h, 040h, 010h, 0EDh, 091h, 0D9h, 0C3h, 0EDh, 028h, 0F8h, 0EEh, 039h, 0F9h, 0EFh
0614:    DB 03Ah, 0FAh
0616:    LJMP loc_0631h    ; 02 06 31
0619:    DB 0C3h, 0EEh, 0F4h, 024h, 001h, 0FEh, 0EFh, 0F4h, 034h
0622:    NOP
0623:    DB 0FFh, 0EDh, 091h, 0D9h, 0C3h, 0E8h, 09Dh, 0F8h, 0E9h, 09Eh, 0F9h, 0EAh, 09Fh, 0FAh
loc_0631h: ; referenced target
0631:    RET
loc_0632h: ; referenced target
0632:    CLR A
0633:    DB 0A2h, 096h, 033h
0636:    SJMP loc_0639h    ; relative +1
loc_0638h: ; referenced target
0638:    CLR A
loc_0639h: ; referenced target
0639:    DB 0A2h, 0B4h, 033h, 02Ah, 0FAh
063E:    RET
loc_063Fh: ; referenced target
063F:    DB 0D1h, 041h
0641:    MOV A, #0Fh    ; 74 0F
0643:    DB 093h, 078h
0645:    NOP
0646:    DB 0F9h, 0D1h, 052h, 030h, 0B3h, 0FBh, 0D1h, 052h, 020h, 0B3h, 0FBh
0651:    RET
0652:    DB 0D8h, 004h, 0D9h
0655:    LJMP 414Eh    ; 02 41 4E
0658:    RET
loc_0659h: ; referenced target
0659:    MOV DPTR, #1124h   ; 90 11 24
065C:    DB 0B1h, 0CDh, 013h, 092h, 019h, 013h, 092h, 018h
0664:    LJMP loc_1047h    ; 02 10 47
0667:    DB 0E5h, 015h, 0B4h
066A:    SJMP loc_066Ch    ; relative +0
loc_066Ch: ; referenced target
066C:    DB 0B3h, 092h, 01Bh, 0E5h, 014h, 0B4h
0672:    SJMP loc_0674h    ; relative +0
loc_0674h: ; referenced target
0674:    DB 0B3h, 092h, 02Eh
0677:    MOV A, #10h    ; 74 10
0679:    DB 093h, 0C3h, 095h, 037h, 050h, 00Ah, 07Ah, 003h, 0B1h, 01Dh, 0C3h, 095h, 037h, 040h, 004h
0688:    RET
0689:    DB 0D2h, 01Ah
068B:    RET
068C:    DB 0C2h, 01Ah
068E:    RET
loc_068Fh: ; referenced target
068F:    DB 07Dh
0690:    NOP
0691:    DB 0C3h, 030h, 01Ah, 006h, 07Ah, 004h, 0F1h, 0AAh, 0C1h, 0E1h, 030h, 018h, 008h, 07Ah, 007h, 0F1h
06A1:    DB 0AAh, 0D1h, 038h, 0C1h, 0DAh, 030h, 019h, 008h, 07Ah, 00Bh, 0F1h, 0AAh, 0D1h, 038h, 0C1h, 0C5h
06B1:    DB 07Ah, 011h
06B3:    MOV A, #20h    ; 74 20
06B5:    DB 093h, 095h, 049h, 040h, 006h, 0F1h, 0AAh, 0D1h, 032h, 0C1h, 0DAh, 01Ah, 0F1h, 0AAh, 0D1h, 032h
06C5:    MOV DPTR, #112Eh   ; 90 11 2E
06C8:    DB 0B1h, 0CDh, 030h, 0E2h, 00Dh
06CD:    MOV A, #21h    ; 74 21
06CF:    DB 093h, 0C3h, 095h, 037h, 050h, 005h
06D5:    MOV A, #22h    ; 74 22
06D7:    DB 093h, 02Dh, 0FDh, 0B1h, 01Dh, 02Dh, 0C3h, 094h, 014h, 0FDh
06E1:    LJMP loc_104Ah    ; 02 10 4A
06E4:    DB 07Ah, 017h, 0B1h, 01Dh, 02Dh, 0C3h, 094h, 014h, 0FDh, 0F8h, 0A2h, 0E7h
06F0:    MOV A, #23h    ; 74 23
06F2:    DB 050h, 001h, 004h, 093h, 0F9h, 050h, 001h, 0C8h, 0C3h, 098h, 050h
06FD:    LJMP E9FDh    ; 02 E9 FD
0700:    DB 0EDh, 0A2h, 0E7h, 013h, 0FDh
0705:    LJMP loc_104Dh    ; 02 10 4D
loc_0708h: ; referenced target
0708:    DB 020h, 01Ah, 065h, 030h, 018h, 024h, 07Ah, 019h, 0B1h, 01Dh, 0C3h, 095h, 037h, 050h, 027h, 0FBh
0718:    MOV A, #32h    ; 74 32
071A:    DB 020h, 00Eh
071C:    LJMP 7431h    ; 02 74 31
071F:    DB 093h, 02Bh, 040h, 04Dh, 0D2h, 015h, 0EDh, 0B5h, 031h, 047h, 0D2h, 01Dh, 0C2h, 015h, 0F5h, 032h
072F:    DB 0F5h, 031h
0731:    RET
0732:    DB 0C2h, 00Eh, 0C2h, 015h, 030h, 01Dh, 037h
0739:    MOV A, #2Fh    ; 74 2F
073B:    DB 093h, 0E1h, 048h, 0C2h, 015h, 030h, 01Dh, 02Dh, 0D2h, 00Eh
0745:    MOV A, #30h    ; 74 30
0747:    DB 093h, 025h, 031h, 0F5h, 031h, 08Dh, 032h, 0C3h, 0EDh, 095h, 031h, 030h, 0E7h, 00Ch
0755:    MOV 34h, #01h   ; 75 34 01
0758:    MOV 4Dh, #00h   ; 75 4D 00
075B:    DB 0D2h, 00Dh, 0C2h, 01Dh, 0E1h, 070h
0761:    MOV A, #2Dh    ; 74 2D
0763:    DB 093h, 0F5h, 034h, 0D2h, 016h
0768:    MOV 4Dh, #00h   ; 75 4D 00
076B:    DB 0D2h, 00Dh, 0C2h, 01Dh
076F:    RET
0770:    DB 0C3h
0771:    MOV A, #25h    ; 74 25
0773:    DB 093h, 095h, 049h, 040h, 006h
0778:    MOV A, #26h    ; 74 26
077A:    DB 093h, 095h, 037h, 0B3h, 030h, 014h, 001h, 0B3h, 050h, 00Bh, 0B2h, 014h, 020h, 016h, 006h, 020h
078A:    DB 015h, 003h
078C:    MOV 34h, #01h   ; 75 34 01
078F:    DB 0EDh, 030h, 01Ch, 005h, 0F5h, 031h
0795:    MOV 34h, #01h   ; 75 34 01
0798:    DB 0EDh, 030h, 016h, 00Bh, 0C3h, 095h, 031h, 030h, 0E7h, 005h, 0C2h, 016h
07A4:    MOV 34h, #01h   ; 75 34 01
loc_07A7h: ; referenced target
07A7:    DB 08Dh, 032h
07A9:    RET
07AA:    DB 0B1h, 01Dh, 020h, 02Ah, 007h, 02Dh, 0C3h, 094h, 014h, 0FDh, 0E1h, 0AAh
07B6:    RET
loc_07B7h: ; referenced target
07B7:    DB 07Ah, 018h, 0B1h, 01Dh, 0F5h, 02Fh
07BD:    RET
loc_07BEh: ; referenced target
07BE:    MOV DPTR, #112Eh   ; 90 11 2E
07C1:    DB 0B1h, 0CDh, 0C2h, 0E2h, 024h, 01Bh, 093h, 0F5h
07C9:    MOVX @DPTR, A
07CA:    DB 07Ah, 021h, 0B1h, 01Dh, 0A4h, 0AFh
07D0:    MOVX @DPTR, A
07D1:    DB 0FEh
07D2:    MOV 50h, #02h   ; 75 50 02
07D5:    DB 0B1h, 01Dh
07D7:    LCALL loc_0886h   ; 12 08 86
07DA:    DB 030h, 01Ah, 05Fh, 07Ah, 02Fh
07DF:    MOV A, #1Fh    ; 74 1F
07E1:    DB 093h, 0B5h, 013h
07E4:    NOP
07E5:    DB 050h, 001h, 00Ah, 0B1h, 01Dh, 0F5h, 03Ch, 07Ah, 031h, 0B1h, 01Dh, 0FCh, 07Bh, 005h, 079h, 008h
07F5:    DB 020h, 00Ch, 013h, 0B1h, 01Dh, 0C3h, 095h, 037h, 040h, 007h
07FF:    MOV A, #1Ah    ; 74 1A
0801:    DB 093h, 095h, 04Dh, 050h
0805:    RET
0806:    DB 0D2h, 00Ch
0808:    MOV 4Dh, #00h   ; 75 4D 00
080B:    DB 07Ah, 033h
080D:    LCALL loc_051Dh   ; 12 05 1D
0810:    DB 0F5h
0811:    MOVX @DPTR, A
0812:    LCALL loc_051Dh   ; 12 05 1D
0815:    DB 0A4h, 0ECh, 020h, 0E7h, 007h, 023h, 0C9h, 023h, 0C9h, 01Bh
081F:    SJMP loc_0817h    ; relative -10
0821:    DB 0A4h, 0ACh
0823:    MOVX @DPTR, A
0824:    DB 030h, 0E7h, 001h, 00Ch, 0ECh, 0B5h, 001h
082B:    NOP
082C:    DB 040h, 00Bh
082E:    LCALL loc_04D9h   ; 12 04 D9
0831:    DB 0E5h, 050h, 02Bh
0834:    LCALL loc_0509h   ; 12 05 09
0837:    DB 0F5h, 050h
0839:    LJMP loc_0873h    ; 02 08 73
083C:    LCALL loc_0638h   ; 12 06 38
083F:    LCALL loc_051Dh   ; 12 05 1D
0842:    DB 0F5h
0843:    MOVX @DPTR, A
0844:    DB 07Ah, 025h, 030h, 018h, 001h, 00Ah
084A:    LCALL loc_051Dh   ; 12 05 1D
084D:    DB 0A4h, 0E5h
084F:    MOVX @DPTR, A
0850:    LCALL loc_087Dh   ; 12 08 7D
0853:    DB 0E5h, 03Ch
0855:    LCALL loc_087Dh   ; 12 08 7D
0858:    DB 07Ah, 027h
085A:    LCALL loc_0638h   ; 12 06 38
085D:    DB 020h, 018h, 00Dh, 07Ah, 029h
0862:    LCALL loc_0638h   ; 12 06 38
0865:    DB 020h, 019h, 005h, 07Ah, 02Bh
086A:    LCALL loc_0632h   ; 12 06 32
086D:    LCALL loc_051Dh   ; 12 05 1D
0870:    LCALL loc_0886h   ; 12 08 86
loc_0873h: ; referenced target
0873:    LJMP loc_1050h    ; 02 10 50
0876:    DB 08Eh, 04Eh, 08Fh, 04Fh
087A:    LJMP loc_1053h    ; 02 10 53
loc_087Dh: ; referenced target
087D:    DB 060h
087E:    LCALL 2480h   ; 12 24 80
0881:    DB 050h, 003h, 013h, 005h, 050h
loc_0886h: ; referenced target
0886:    LCALL loc_04D9h   ; 12 04 D9
0889:    DB 0E5h, 050h, 004h
088C:    LCALL loc_0509h   ; 12 05 09
088F:    DB 0F5h, 050h
0891:    RET
loc_0892h: ; referenced target
0892:    LJMP loc_1068h    ; 02 10 68
loc_0895h: ; referenced target
0895:    DB 030h, 01Ch, 008h
0898:    LCALL loc_0A4Ah   ; 12 0A 4A
089B:    MOV 20h, #00h   ; 75 20 00
089E:    DB 0D2h, 006h, 010h, 001h, 003h, 0D2h, 001h
08A5:    RET
08A6:    DB 020h, 01Ah, 015h, 020h, 01Dh, 01Fh, 0A2h, 019h, 082h, 018h, 040h
08B1:    RET
08B2:    DB 020h, 018h, 029h
08B5:    LCALL loc_0A4Ah   ; 12 0A 4A
08B8:    DB 0D2h, 006h, 0C2h
08BB:    NOP
08BC:    DB 021h, 0C5h, 0D2h, 006h, 0D2h
08C1:    NOP
08C2:    DB 07Ah, 035h
08C4:    LCALL loc_051Dh   ; 12 05 1D
08C7:    DB 0F5h, 07Fh, 021h, 02Dh, 0D2h, 006h, 0C2h
08CE:    NOP
08CF:    LCALL loc_0A4Ah   ; 12 0A 4A
08D2:    DB 021h, 0C5h
08D4:    MOV A, #3Ch    ; 74 3C
08D6:    DB 093h, 0C3h, 013h, 0F9h, 078h
08DB:    NOP
08DC:    DB 041h, 005h
08DE:    LJMP loc_106Bh    ; 02 10 6B
loc_08E1h: ; referenced target
08E1:    DB 030h, 01Bh, 009h, 07Ah, 036h
08E6:    LCALL loc_051Dh   ; 12 05 1D
08E9:    DB 0F5h, 07Fh
08EB:    SJMP loc_092Dh    ; relative +64
08ED:    DB 07Ah, 037h
08EF:    LCALL loc_051Dh   ; 12 05 1D
08F2:    DB 0F5h
08F3:    MOVX @DPTR, A
08F4:    DB 020h, 0B5h, 00Ah
08F7:    MOV A, #39h    ; 74 39
08F9:    DB 093h, 0B5h
08FB:    MOVX @DPTR, A
08FC:    NOP
08FD:    DB 040h
08FE:    LJMP F5F0h    ; 02 F5 F0
0901:    DB 030h, 006h, 00Eh
0904:    LJMP loc_106Eh    ; 02 10 6E
loc_0907h: ; referenced target
0907:    DB 020h
0908:    NOP
0909:    DB 003h, 085h, 037h, 07Fh
090D:    MOV 7Ch, #01h   ; 75 7C 01
0910:    DB 0C2h, 006h, 0E5h
0913:    MOVX @DPTR, A
0914:    DB 0B5h, 07Fh
0916:    NOP
0917:    DB 050h, 011h, 0D5h, 07Ch, 00Bh, 015h, 07Fh
091E:    MOV A, #3Fh    ; 74 3F
0920:    DB 0A2h
0921:    NOP
0922:    DB 034h
0923:    NOP
0924:    DB 093h, 0F5h, 07Ch, 085h, 07Fh
0929:    MOVX @DPTR, A
092A:    DB 085h
092B:    MOVX @DPTR, A
092C:    DB 07Fh
loc_092Dh: ; referenced target
092D:    MOV A, #38h    ; 74 38
092F:    DB 093h, 025h, 037h, 0D3h, 095h, 07Fh, 050h, 008h
0937:    MOV A, #80h    ; 74 80
0939:    DB 095h, 07Eh, 040h
093C:    LJMP 514Ah    ; 02 51 4A
093F:    LJMP loc_1071h    ; 02 10 71
loc_0942h: ; referenced target
0942:    DB 0E5h, 07Fh, 0C3h, 095h, 037h, 092h
0948:    LJMP 5006h    ; 02 50 06
094B:    DB 0C2h, 003h, 0F4h, 004h
loc_094Fh: ; referenced target
094F:    SJMP loc_0953h    ; relative +2
0951:    DB 0C2h, 004h, 0FBh, 0A9h, 07Eh, 0A8h, 07Dh, 010h, 003h, 016h, 010h, 004h, 013h, 07Ah, 038h, 030h
0961:    LJMP loc_010Ah    ; 02 01 0A
0964:    LCALL loc_051Dh   ; 12 05 1D
0967:    DB 0F5h
0968:    MOVX @DPTR, A
0969:    DB 0EBh
096A:    LCALL loc_0BDDh   ; 12 0B DD
096D:    DB 088h, 07Dh, 089h, 07Eh, 020h
0972:    LJMP loc_147Ah    ; 02 14 7A
0975:    DB 03Ah
0976:    LCALL loc_051Dh   ; 12 05 1D
0979:    DB 0F5h
097A:    MOVX @DPTR, A
097B:    DB 0EBh, 0B4h, 03Fh
097E:    NOP
097F:    DB 040h
0980:    LJMP E53Fh    ; 02 E5 3F
0983:    DB 023h, 023h
0985:    LCALL loc_0BDDh   ; 12 0B DD
0988:    LJMP loc_1074h    ; 02 10 74
098B:    DB 0E9h, 0C3h, 030h, 0E7h, 013h, 020h, 01Ah, 01Fh
0993:    MOV A, #3Dh    ; 74 3D
0995:    DB 093h, 013h, 024h
0998:    SJMP loc_094Fh    ; relative -75
099A:    DB 001h
099B:    NOP
099C:    DB 050h, 014h, 0F9h, 0D2h, 003h
09A1:    SJMP loc_09B2h    ; relative +15
09A3:    MOV A, #3Eh    ; 74 3E
09A5:    DB 093h, 013h, 0F4h, 024h
09A9:    SJMP loc_0960h    ; relative -75
09AB:    DB 001h
09AC:    NOP
09AD:    DB 040h, 003h, 0F9h, 0D2h, 004h, 07Ah, 03Dh
09B4:    LCALL loc_051Dh   ; 12 05 1D
09B7:    DB 0B5h, 049h
09B9:    NOP
09BA:    DB 040h
09BB:    LJMP D204h    ; 02 D2 04
09BE:    DB 0E9h, 0C3h, 094h
09C1:    SJMP loc_0955h    ; relative -110
09C3:    DB 005h, 0F9h
09C5:    LJMP loc_1077h    ; 02 10 77
loc_09C8h: ; referenced target
09C8:    DB 07Ah, 03Ch
09CA:    LCALL loc_051Dh   ; 12 05 1D
09CD:    DB 0F5h
09CE:    MOVX @DPTR, A
09CF:    DB 030h, 01Dh, 007h, 07Ah, 03Bh
09D4:    LCALL loc_051Dh   ; 12 05 1D
09D7:    DB 051h, 055h, 030h, 01Bh, 005h
09DC:    MOV A, #3Bh    ; 74 3B
09DE:    DB 093h, 051h, 055h, 020h, 0B5h, 005h
09E4:    MOV A, #3Ah    ; 74 3A
09E6:    DB 093h, 051h, 055h
09E9:    MOV A, #80h    ; 74 80
09EB:    DB 0A4h
09EC:    LJMP loc_107Ah    ; 02 10 7A
loc_09EFh: ; referenced target
09EF:    DB 028h, 0F8h, 0E5h
09F2:    MOVX @DPTR, A
09F3:    DB 039h, 0F9h, 030h, 0E7h, 00Dh, 030h, 005h, 006h, 079h
09FC:    NOP
09FD:    DB 078h
09FE:    NOP
09FF:    SJMP loc_0A05h    ; relative +4
0A01:    DB 079h, 07Fh, 078h, 0FFh
loc_0A05h: ; referenced target
0A05:    LJMP loc_107Dh    ; 02 10 7D
0A08:    DB 0AFh, 001h, 0AEh
0A0B:    NOP
0A0C:    MOV A, #01h    ; 74 01
0A0E:    LCALL loc_0509h   ; 12 05 09
0A11:    DB 08Fh, 07Bh
0A13:    MOV A, #41h    ; 74 41
0A15:    DB 093h
0A16:    LCALL loc_04D9h   ; 12 04 D9
0A19:    MOV A, #42h    ; 74 42
0A1B:    DB 093h, 02Fh, 0FFh
0A1E:    MOV A, #0Bh    ; 74 0B
0A20:    DB 093h, 0F8h
0A22:    MOV A, #0Ch    ; 74 0C
0A24:    DB 093h, 0F9h
0A26:    LCALL loc_0455h   ; 12 04 55
0A29:    DB 0EEh, 0F4h, 0F8h, 0EFh, 0F4h, 0F9h
0A2F:    MOV A, #0Bh    ; 74 0B
0A31:    DB 093h, 0FBh
0A33:    MOV A, #0Ch    ; 74 0C
0A35:    DB 093h, 0FCh, 0D3h, 0EEh, 09Bh, 0CFh, 09Ch, 0FBh, 0C2h, 0ABh, 08Fh, 044h, 08Bh, 045h, 088h, 042h
0A45:    DB 089h, 043h, 0D2h, 0ABh
0A49:    RET
loc_0A4Ah: ; referenced target
0A4A:    MOV 7Eh, #80h   ; 75 7E 80
0A4D:    MOV 7Dh, #00h   ; 75 7D 00
0A50:    DB 079h
0A51:    NOP
0A52:    DB 078h
0A53:    NOP
0A54:    RET
0A55:    DB 025h
0A56:    MOVX @DPTR, A
0A57:    DB 050h
0A58:    LJMP E5FFh    ; 02 E5 FF
0A5B:    DB 0F5h
0A5C:    MOVX @DPTR, A
0A5D:    RET
0A5E:    DB 07Ah, 03Eh, 030h, 0B4h
0A62:    LJMP 7A41h    ; 02 7A 41
loc_0A65h: ; referenced target
0A65:    LCALL loc_051Dh   ; 12 05 1D
0A68:    DB 0F5h, 018h
0A6A:    LCALL loc_051Dh   ; 12 05 1D
0A6D:    DB 0F5h, 019h
0A6F:    LCALL loc_051Dh   ; 12 05 1D
0A72:    DB 0F5h, 01Ah
0A74:    RET
loc_0A75h: ; referenced target
0A75:    DB 030h, 01Ch, 003h
0A78:    MOV 1Bh, #80h   ; 75 1B 80
0A7B:    DB 0A8h, 01Ch, 0A9h, 01Bh, 0A2h, 097h, 0B3h, 092h
0A83:    LJMP 400Eh    ; 02 40 0E
0A86:    DB 020h, 026h, 005h
0A89:    LCALL loc_0BCDh   ; 12 0B CD
0A8C:    SJMP loc_0AA1h    ; relative +19
0A8E:    CLR A
0A8F:    LCALL loc_0BD4h   ; 12 0B D4
0A92:    SJMP loc_0AA1h    ; relative +13
0A94:    DB 030h, 026h, 005h
0A97:    LCALL loc_0BCDh   ; 12 0B CD
0A9A:    SJMP loc_0AA1h    ; relative +5
0A9C:    DB 0E5h, 01Ah
0A9E:    LCALL loc_0BD4h   ; 12 0B D4
loc_0AA1h: ; referenced target
0AA1:    DB 088h, 01Ch, 089h, 01Bh, 0A2h
0AA6:    LJMP 9226h    ; 02 92 26
0AA9:    LJMP loc_105Ch    ; 02 10 5C
0AAC:    DB 020h, 01Ah, 04Ah, 020h, 019h, 047h, 020h, 01Dh, 044h
0AB5:    NOP
0AB6:    NOP
0AB7:    NOP
0AB8:    MOV A, #4Bh    ; 74 4B
0ABA:    DB 093h, 0B5h, 037h
0ABD:    NOP
0ABE:    DB 040h, 039h
0AC0:    MOV A, #4Ch    ; 74 4C
0AC2:    DB 093h, 0B5h, 049h
loc_0AC5h: ; referenced target
0AC5:    NOP
0AC6:    DB 050h, 015h, 030h, 025h, 02Eh, 020h, 021h, 009h, 0D2h, 021h, 0C2h
0AD1:    RET
0AD2:    MOV A, #4Dh    ; 74 4D
0AD4:    DB 093h, 0F5h, 03Fh, 0E5h, 03Fh, 060h, 01Eh
0ADB:    SJMP loc_0ADFh    ; relative +2
0ADD:    DB 0C2h, 021h
loc_0ADFh: ; referenced target
0ADF:    MOV A, #49h    ; 74 49
0AE1:    DB 020h, 018h
0AE3:    LJMP 7448h    ; 02 74 48
0AE6:    DB 093h, 0FAh, 020h, 025h, 004h
0AEB:    MOV A, #4Ah    ; 74 4A
0AED:    DB 093h, 02Ah, 0C3h, 095h, 013h, 092h, 025h
0AF4:    LCALL loc_0B50h   ; 12 0B 50
0AF7:    SJMP loc_0AFBh    ; relative +2
0AF9:    DB 0C2h, 025h
loc_0AFBh: ; referenced target
0AFB:    LCALL loc_105Fh   ; 12 10 5F
0AFE:    DB 030h, 096h, 017h, 020h, 097h, 014h, 020h, 023h, 009h, 0D2h, 023h, 0C2h, 024h
0B0B:    MOV A, #43h    ; 74 43
0B0D:    DB 093h, 0F5h, 03Eh, 0E5h, 03Eh, 070h, 01Ah, 0C2h, 027h
0B16:    SJMP loc_0B2Eh    ; relative +22
0B18:    DB 020h, 024h, 00Dh, 0D2h, 024h, 0C2h, 023h, 0C2h
0B20:    RET
0B21:    DB 0D2h, 020h
0B23:    MOV A, #44h    ; 74 44
0B25:    DB 093h, 0F5h, 03Eh, 0E5h, 03Eh, 070h
0B2B:    LJMP D227h    ; 02 D2 27
loc_0B2Eh: ; referenced target
0B2E:    DB 0A2h, 025h, 082h, 027h, 082h, 020h, 092h, 025h, 040h, 00Ah, 078h
0B39:    NOP
0B3A:    DB 079h
0B3B:    SJMP loc_0AC5h    ; relative -120
0B3D:    DB 01Ch, 089h, 01Bh, 0C2h
0B41:    RET
0B42:    LJMP loc_1062h    ; 02 10 62
loc_0B45h: ; referenced target
0B45:    LCALL loc_0455h   ; 12 04 55
0B48:    MOV A, #01h    ; 74 01
0B4A:    LCALL loc_0509h   ; 12 05 09
0B4D:    LJMP loc_1065h    ; 02 10 65
loc_0B50h: ; referenced target
0B50:    MOV A, #46h    ; 74 46
0B52:    DB 093h, 0FBh, 0C3h, 0E9h, 09Bh, 040h, 004h, 078h
0B5A:    NOP
0B5B:    SJMP loc_0B67h    ; relative +10
0B5D:    MOV A, #47h    ; 74 47
0B5F:    DB 093h, 0FBh, 0C3h, 099h, 040h, 024h, 078h, 0FFh, 0EBh, 0F9h, 088h, 01Ch, 089h, 01Bh, 020h, 021h
0B6F:    DB 019h, 020h
0B71:    RET
0B72:    DB 010h
0B73:    MOV A, #45h    ; 74 45
0B75:    DB 093h, 0B4h, 0FFh, 006h, 0C2h
0B7A:    RET
0B7B:    DB 0D2h, 020h
0B7D:    SJMP loc_0B89h    ; relative +10
0B7F:    DB 0D2h
0B80:    RET
0B81:    DB 0F5h, 03Fh, 0E5h, 03Fh, 070h
0B86:    LJMP C220h    ; 02 C2 20
loc_0B89h: ; referenced target
0B89:    RET
0B8A:    DB 07Ah, 04Eh, 0EAh, 093h, 0B5h, 037h
0B90:    NOP
0B91:    DB 040h, 010h, 0CAh, 004h, 093h, 0CAh, 09Ah, 0B5h, 037h
0B9A:    NOP
0B9B:    DB 050h
0B9C:    LJMP 8006h    ; 02 80 06
0B9F:    DB 0D2h, 095h
0BA1:    SJMP loc_0BA5h    ; relative +2
0BA3:    DB 0C2h, 095h, 030h, 01Fh, 007h, 0E5h, 01Bh, 0A2h, 0E7h
0BAC:    NOP
0BAD:    DB 092h, 0B1h
0BAF:    RET
0BB0:    DB 030h, 025h, 006h, 0C2h, 095h, 0C2h, 00Bh
0BB7:    SJMP loc_0BA5h    ; relative -20
0BB9:    DB 020h, 00Bh, 009h
0BBC:    MOV A, #50h    ; 74 50
0BBE:    DB 093h, 0F5h, 03Fh, 0D2h, 095h, 0D2h, 00Bh, 0E5h, 03Fh, 070h
0BC8:    LJMP C295h    ; 02 C2 95
0BCB:    SJMP loc_0BA5h    ; relative -40
loc_0BCDh: ; referenced target
0BCD:    DB 0E5h, 018h
0BCF:    MOV F0h, #01h   ; 75 F0 01
0BD2:    SJMP loc_0BDDh    ; relative +9
loc_0BD4h: ; referenced target
0BD4:    DB 0F4h, 004h, 025h, 019h
0BD8:    MOV F0h, #10h   ; 75 F0 10
0BDB:    DB 0C2h, 024h, 0A4h, 030h, 0F7h, 003h
0BE1:    MOV F0h, #7Fh   ; 75 F0 7F
0BE4:    DB 030h
0BE5:    LJMP loc_05B3h    ; 02 05 B3
0BE8:    DB 0F4h, 063h
0BEA:    MOVX @DPTR, A
0BEB:    DB 0FFh, 038h, 0F8h, 0E5h
0BEF:    MOVX @DPTR, A
0BF0:    DB 039h, 0F9h
0BF2:    CLR A
0BF3:    DB 020h
0BF4:    LJMP loc_02B3h    ; 02 02 B3
0BF7:    DB 0F4h, 040h
0BF9:    LJMP F8F9h    ; 02 F8 F9
0BFC:    RET
loc_0BFDh: ; referenced target
0BFD:    DB 020h, 01Ah, 054h, 07Ah, 044h
0C02:    LCALL loc_051Dh   ; 12 05 1D
0C05:    DB 0FBh, 020h, 009h, 02Fh, 0B5h, 049h
0C0B:    NOP
0C0C:    DB 040h, 004h, 0C2h, 008h
0C10:    SJMP loc_0C54h    ; relative +66
0C12:    MOV A, #52h    ; 74 52
0C14:    DB 020h, 008h, 00Ah, 0D2h, 008h, 093h, 0F5h, 058h
0C1C:    MOV A, #54h    ; 74 54
0C1E:    DB 093h, 0F5h, 059h, 0E5h, 058h, 070h, 02Fh, 0D2h, 009h
0C27:    MOV A, #53h    ; 74 53
0C29:    DB 093h, 0F5h, 058h
0C2C:    MOV A, #55h    ; 74 55
0C2E:    DB 093h, 0F5h, 059h, 0D2h, 01Dh, 08Dh, 032h, 08Dh, 031h
0C37:    RET
0C38:    DB 0E5h, 058h, 070h, 006h, 0C2h, 008h, 0C2h, 009h
0C40:    SJMP loc_0C54h    ; relative +18
0C42:    MOV A, #51h    ; 74 51
0C44:    DB 093h, 0F4h, 004h, 02Bh, 0C3h, 095h, 049h, 050h, 007h, 0D2h, 01Dh, 08Dh, 032h, 08Dh, 031h
0C53:    RET
loc_0C54h: ; referenced target
0C54:    LJMP loc_1059h    ; 02 10 59
loc_0C57h: ; referenced target
0C57:    DB 015h, 059h, 0E5h, 059h, 070h, 00Fh
0C5D:    MOV A, #54h    ; 74 54
0C5F:    DB 030h, 009h, 001h, 004h, 093h, 0F5h, 059h, 0E5h, 058h, 060h
0C69:    LJMP loc_1558h    ; 02 15 58
0C6C:    LJMP loc_1056h    ; 02 10 56
loc_0C6Fh: ; referenced target
0C6F:    NOP
0C70:    NOP
0C71:    NOP
0C72:    NOP
0C73:    NOP
0C74:    DB 0D2h, 095h
0C76:    RET
loc_0C77h: ; referenced target
0C77:    DB 0C2h, 089h
0C79:    MOV A0h, #00h   ; 75 A0 00
0C7C:    DB 0F2h, 0F2h, 0F2h, 0F2h
0C80:    MOV A, #0Dh    ; 74 0D
0C82:    DB 093h, 0F5h
0C84:    MOVX @DPTR, A
0C85:    DB 0A2h, 0B3h, 092h, 0E0h, 07Dh
0C8A:    NOP
0C8B:    DB 07Eh
0C8C:    LJMP 7F02h    ; 02 7F 02
0C8F:    DB 033h, 085h
0C91:    MOVX @DPTR, A
0C92:    DB 02Ah, 030h, 017h, 003h, 0C2h, 017h, 0F2h, 0DDh, 011h, 020h, 0E0h, 007h, 07Fh
0C9F:    LJMP DE0Ah    ; 02 DE 0A
0CA2:    LJMP loc_024Eh    ; 02 02 4E
0CA5:    DB 07Eh
0CA6:    LJMP DF03h    ; 02 DF 03
0CA9:    LJMP loc_024Eh    ; 02 02 4E
0CAC:    DB 0A2h, 0B3h, 092h, 0E0h, 072h, 0E1h, 050h, 00Ch, 0A2h, 0E0h, 082h, 0E1h, 040h, 006h, 07Dh
0CBB:    NOP
0CBC:    DB 07Eh
0CBD:    LJMP 7F02h    ; 02 7F 02
0CC0:    DB 033h, 030h, 089h, 0CCh, 0D2h, 0A8h, 0C2h, 01Ch
0CC8:    LJMP loc_1008h    ; 02 10 08
0CCB:    DB 030h, 0B3h, 0FDh, 020h, 0B3h, 0FDh
0CD1:    RET
0CD2:    DB 030h, 0B4h, 007h, 0D2h, 031h, 0D2h, 030h
0CD9:    LJMP loc_0CE0h    ; 02 0C E0
0CDC:    DB 0C2h, 031h, 0D2h, 030h
loc_0CE0h: ; referenced target
0CE0:    LJMP loc_0F9Ah    ; 02 0F 9A
0CE3:    DB 020h, 01Ch, 06Eh, 0E5h, 029h, 060h, 003h, 014h, 0F5h, 029h, 020h, 0B4h, 01Bh, 0C2h, 036h, 030h
0CF3:    DB 031h, 042h, 020h, 030h, 045h, 020h, 034h, 006h, 0D2h, 032h, 0C2h, 033h
0CFF:    SJMP loc_0D05h    ; relative +4
0D01:    DB 0C2h, 032h, 0D2h, 033h, 0D2h, 030h, 0C2h, 031h
0D09:    SJMP loc_0D54h    ; relative +73
0D0B:    DB 07Ah, 046h, 020h, 031h, 011h
0D10:    MOV A, #58h    ; 74 58
0D12:    DB 093h, 0F5h, 029h, 020h, 01Dh, 02Bh, 010h, 036h, 009h, 0A2h, 034h, 092h, 035h
0D1F:    SJMP loc_0D24h    ; relative +3
0D21:    DB 020h, 030h, 019h, 020h, 035h, 001h, 00Ah
0D28:    LCALL loc_051Dh   ; 12 05 1D
0D2B:    DB 0C3h, 094h, 014h, 0A2h, 0E7h, 013h, 0D2h, 031h, 0C2h, 030h, 0F5h, 031h, 0E5h, 029h, 070h, 019h
0D3B:    DB 0D2h, 030h, 0C2h, 032h, 0C2h, 033h
0D41:    SJMP loc_0D54h    ; relative +17
0D43:    DB 0D2h, 030h, 0C2h, 031h, 0C2h, 032h, 0C2h, 033h, 020h, 036h, 006h, 0A2h, 034h, 092h, 035h, 0D2h
0D53:    DB 036h
loc_0D54h: ; referenced target
0D54:    RET
0D55:    DB 020h, 01Ch, 03Eh, 030h, 030h, 03Bh, 020h, 032h, 005h, 020h, 033h
0D60:    LJMP A196h    ; 02 A1 96
0D63:    DB 0D5h, 034h, 030h
0D66:    MOV DPTR, #1160h   ; 90 11 60
0D69:    MOV A, #56h    ; 74 56
0D6B:    DB 020h, 032h
0D6D:    LJMP 7457h    ; 02 74 57
0D70:    DB 093h, 0F5h, 034h, 07Ah, 045h
0D75:    LCALL loc_051Dh   ; 12 05 1D
0D78:    DB 0FDh, 0E5h, 032h, 0FEh, 0AFh, 031h, 0C3h, 09Fh, 0C3h, 020h, 0E7h, 007h, 09Dh, 040h, 004h, 0EFh
0D88:    DB 02Dh, 0A1h, 094h, 0C2h, 032h, 0C2h, 033h
0D8F:    MOV 34h, #01h   ; 75 34 01
0D92:    DB 0E5h, 032h, 0F5h, 031h
0D96:    RET
0D97:    DB 0E5h, 028h, 0C3h, 095h, 037h, 050h, 00Dh, 0F5h
0D9F:    MOVX @DPTR, A
0DA0:    MOV A, #6Dh    ; 74 6D
0DA2:    DB 093h, 025h
0DA4:    MOVX @DPTR, A
0DA5:    DB 040h, 004h, 0C2h, 034h
0DA9:    SJMP loc_0DADh    ; relative +2
0DAB:    DB 0D2h, 034h, 085h, 037h, 028h
0DB0:    RET
0DB1:    DB 020h, 01Ch, 00Ch, 030h, 030h, 013h, 020h, 016h, 009h, 020h, 032h, 00Dh, 020h, 033h, 00Ah
0DC0:    LJMP loc_00F3h    ; 02 00 F3
0DC3:    DB 0C2h, 032h, 0C2h, 033h
0DC7:    LJMP loc_00F3h    ; 02 00 F3
0DCA:    LJMP loc_012Ch    ; 02 01 2C
0DCD:    DB 020h, 01Ch, 011h, 020h, 01Dh, 00Ah, 020h, 030h, 00Bh, 0C2h, 015h, 0C2h, 016h
0DDA:    LJMP loc_07A7h    ; 02 07 A7
0DDD:    DB 0C2h, 032h, 0C2h, 033h
0DE1:    LJMP loc_0708h    ; 02 07 08
0DE4:    LJMP loc_1080h    ; 02 10 80
0DE7:    DB 0E1h, 006h
0DE9:    MOV 27h, #00h   ; 75 27 00
0DEC:    DB 0C2h, 028h, 0F1h, 021h
0DF0:    MOV A, #5Fh    ; 74 5F
0DF2:    DB 093h, 095h, 013h, 0B3h, 092h, 03Ch, 0A2h, 025h, 0B3h, 092h, 03Dh
0DFD:    MOV A, #60h    ; 74 60
0DFF:    DB 093h, 095h
0E01:    LCALL 923Eh   ; 12 92 3E
0E04:    DB 078h, 05Ch
0E06:    MOV A, #5Dh    ; 74 5D
0E08:    DB 030h, 039h, 003h, 078h, 059h, 004h, 093h, 0F5h
0E10:    MOVX @DPTR, A
0E11:    LJMP loc_1083h    ; 02 10 83
0E14:    DB 0E5h, 027h, 054h, 078h, 060h
0E19:    LJMP C1C3h    ; 02 C1 C3
0E1C:    MOV A, #59h    ; 74 59
0E1E:    DB 093h, 0F4h, 004h, 025h, 059h, 025h, 01Bh, 0FBh, 0C3h, 096h, 092h
0E29:    LJMP 5002h    ; 02 50 02
0E2C:    DB 0F4h, 004h, 0A4h, 0AEh
0E30:    MOVX @DPTR, A
0E31:    DB 0FDh, 008h, 020h
0E34:    LJMP loc_19E6h    ; 02 19 E6
0E37:    DB 02Dh, 0F6h, 008h, 0E6h, 03Eh, 0F6h, 050h, 030h, 0C3h, 094h
0E41:    SJMP loc_0E39h    ; relative -10
0E43:    DB 018h, 018h
0E45:    MOV A, #5Ah    ; 74 5A
0E47:    DB 093h, 0D3h, 096h, 040h, 023h, 006h
0E4D:    SJMP loc_0E66h    ; relative +23
0E4F:    DB 0C3h, 0E6h, 09Dh, 0F6h, 008h, 0E6h, 09Eh, 0F6h, 050h, 016h, 024h
0E5A:    SJMP loc_0E52h    ; relative -10
0E5C:    DB 018h, 018h
loc_0E5Eh: ; referenced target
0E5E:    MOV A, #5Bh    ; 74 5B
0E60:    DB 093h, 0C3h, 096h, 050h, 00Ah, 016h, 030h, 039h, 006h, 0E6h, 078h, 006h
0E6C:    LCALL loc_1DF2h   ; 12 1D F2
0E6F:    DB 0C3h
0E70:    MOV A, #59h    ; 74 59
0E72:    DB 093h, 095h, 059h, 02Bh, 0F5h, 01Bh, 020h, 039h, 048h
0E7B:    LJMP loc_1086h    ; 02 10 86
0E7E:    DB 0D5h, 063h, 042h
0E81:    MOV A, #5Ch    ; 74 5C
0E83:    DB 093h, 0F5h, 063h, 0C3h, 0E5h, 05Ch, 095h, 059h, 050h
0E8C:    LJMP F404h    ; 02 F4 04
0E8F:    DB 092h
0E90:    LJMP 75F0h    ; 02 75 F0
0E93:    DB 001h, 030h, 038h, 00Fh, 0A9h, 05Fh, 0A8h, 060h, 071h, 0DDh, 085h, 05Fh
0E9F:    MOVX @DPTR, A
0EA0:    DB 089h, 05Fh, 088h, 060h
0EA4:    SJMP loc_0EB3h    ; relative +13
0EA6:    DB 0A9h, 061h, 0A8h, 062h, 071h, 0DDh, 085h, 061h
0EAE:    MOVX @DPTR, A
0EAF:    DB 089h, 061h, 088h, 062h, 0E9h, 078h, 00Ch, 020h, 038h
0EB8:    LJMP 7812h    ; 02 78 12
0EBB:    DB 0B5h
0EBC:    MOVX @DPTR, A
0EBD:    LJMP 8003h    ; 02 80 03
0EC0:    LCALL loc_1DF2h   ; 12 1D F2
0EC3:    LJMP loc_1089h    ; 02 10 89
0EC6:    DB 0C3h, 0E5h, 05Fh, 094h
0ECA:    SJMP loc_0E5Eh    ; relative -110
0ECC:    DB 0D5h, 050h
0ECE:    LJMP F404h    ; 02 F4 04
0ED1:    DB 0F9h, 0ABh, 037h, 085h, 037h
0ED6:    MOVX @DPTR, A
0ED7:    MOV A, #32h    ; 74 32
0ED9:    DB 084h, 0FFh
0EDB:    LCALL loc_04EAh   ; 12 04 EA
0EDE:    DB 0FEh, 0E9h
0EE0:    LCALL loc_04D9h   ; 12 04 D9
0EE3:    DB 0EFh, 060h
0EE5:    LJMP 7EFFh    ; 02 7E FF
0EE8:    DB 0EEh, 0C3h, 013h, 024h
0EEC:    SJMP loc_0F1Eh    ; relative +48
0EEE:    DB 0D5h
0EEF:    LJMP F400h    ; 02 F4 00
0EF2:    DB 025h, 061h, 0B3h, 092h, 0D5h, 050h
0EF8:    LJMP F400h    ; 02 F4 00
0EFB:    DB 070h
0EFC:    LJMP C2D5h    ; 02 C2 D5
0EFF:    DB 0F5h, 058h, 0A2h, 0D5h, 092h, 029h
0F05:    RET
0F06:    DB 0E5h, 049h, 085h, 037h
0F0A:    MOVX @DPTR, A
0F0B:    DB 0A4h, 0AFh
0F0D:    MOVX @DPTR, A
0F0E:    DB 0FEh
0F0F:    MOV A, #A4h    ; 74 A4
0F11:    LCALL loc_04D9h   ; 12 04 D9
0F14:    MOV A, #02h    ; 74 02
0F16:    LCALL loc_0509h   ; 12 05 09
0F19:    DB 060h
0F1A:    LJMP 7FFFh    ; 02 7F FF
0F1D:    DB 0EFh, 0FCh, 0A1h, 0E9h
0F21:    LJMP loc_108Ch    ; 02 10 8C
0F24:    DB 0C3h
0F25:    MOV A, #63h    ; 74 63
0F27:    DB 093h, 09Ch, 050h, 00Ah
0F2B:    MOV A, #64h    ; 74 64
0F2D:    DB 093h, 0C3h, 095h, 049h, 092h, 039h
0F33:    SJMP loc_0F65h    ; relative +48
0F35:    MOV A, #62h    ; 74 62
0F37:    DB 093h, 095h, 037h, 040h, 009h
0F3C:    MOV A, #61h    ; 74 61
0F3E:    DB 093h, 09Ch, 0B3h, 092h, 038h
0F43:    SJMP loc_0F65h    ; relative +32
0F45:    MOV A, #66h    ; 74 66
0F47:    DB 093h, 0C3h, 095h, 037h, 050h, 018h
0F4D:    MOV A, #65h    ; 74 65
0F4F:    DB 093h, 0C3h, 09Ch, 040h, 011h
0F54:    MOV A, #67h    ; 74 67
0F56:    DB 093h, 095h, 049h, 050h, 00Ah
0F5B:    MOV A, #68h    ; 74 68
0F5D:    DB 093h, 0C3h, 095h, 049h, 040h
0F62:    LJMP D23Ah    ; 02 D2 3A
loc_0F65h: ; referenced target
0F65:    DB 0E5h, 027h, 054h, 007h, 070h
0F6A:    LJMP D23Bh    ; 02 D2 3B
0F6D:    RET
0F6E:    MOV A, #59h    ; 74 59
0F70:    DB 093h, 0F4h, 004h, 025h, 059h, 029h, 0F9h, 061h, 045h, 0E5h, 058h
0F7B:    MOV F0h, #04h   ; 75 F0 04
0F7E:    DB 0A4h, 030h, 029h, 005h, 0B3h, 0F4h, 063h
0F85:    MOVX @DPTR, A
0F86:    DB 0FFh, 03Eh, 0FEh, 0E5h
0F8A:    MOVX @DPTR, A
0F8B:    DB 03Fh, 0FFh
0F8D:    CLR A
0F8E:    DB 020h, 029h
0F90:    LJMP B3F4h    ; 02 B3 F4
0F93:    DB 040h
0F94:    LJMP FFFEh    ; 02 FF FE
0F97:    LJMP loc_01BEh    ; 02 01 BE
loc_0F9Ah: ; referenced target
0F9A:    MOV 89h, #11h   ; 75 89 11
0F9D:    MOV B8h, #02h   ; 75 B8 02
0FA0:    DB 043h, 0A8h, 085h, 043h, 088h, 005h
0FA6:    MOV DPTR, #1160h   ; 90 11 60
0FA9:    MOV 81h, #63h   ; 75 81 63
0FAC:    DB 0C2h, 092h
0FAE:    MOV A, #0Dh    ; 74 0D
0FB0:    DB 093h, 0F5h, 02Ah
0FB3:    LCALL loc_063Fh   ; 12 06 3F
0FB6:    LCALL loc_101Ah   ; 12 10 1A
0FB9:    LCALL loc_0FE7h   ; 12 0F E7
0FBC:    LCALL loc_0659h   ; 12 06 59
0FBF:    LCALL loc_0FE7h   ; 12 0F E7
0FC2:    LCALL loc_068Fh   ; 12 06 8F
0FC5:    LCALL loc_101Ah   ; 12 10 1A
0FC8:    LCALL loc_0FE7h   ; 12 0F E7
0FCB:    LCALL loc_07B7h   ; 12 07 B7
0FCE:    LCALL loc_0FE7h   ; 12 0F E7
0FD1:    LCALL loc_101Ah   ; 12 10 1A
0FD4:    LCALL loc_07BEh   ; 12 07 BE
0FD7:    LCALL loc_0FE7h   ; 12 0F E7
0FDA:    LJMP loc_101Dh    ; 02 10 1D
0FDD:    DB 030h, 01Ch, 0BAh
0FE0:    LCALL loc_021Dh   ; 12 02 1D
0FE3:    LCALL loc_030Ch   ; 12 03 0C
0FE6:    RET
loc_0FE7h: ; referenced target
0FE7:    DB 010h, 017h, 001h
0FEA:    RET
0FEB:    LJMP loc_02C6h    ; 02 02 C6
0FEE:    DB 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh
0FFE:    NOP
0FFF:    DB 042h, 0C2h, 095h
1002:    LJMP loc_0C6Fh    ; 02 0C 6F
loc_1005h: ; referenced target
1005:    LJMP loc_1F4Eh    ; 02 1F 4E
loc_1008h: ; referenced target
1008:    LJMP loc_1F3Ah    ; 02 1F 3A
loc_100Bh: ; referenced target
100B:    LJMP loc_0272h    ; 02 02 72
loc_100Eh: ; referenced target
100E:    LCALL loc_1E53h   ; 12 1E 53
1011:    LJMP loc_0278h    ; 02 02 78
1014:    DB 0FFh, 0FFh, 0FFh
loc_1017h: ; referenced target
1017:    LJMP loc_0C77h    ; 02 0C 77
loc_101Ah: ; referenced target
101A:    LJMP loc_1E6Dh    ; 02 1E 6D
loc_101Dh: ; referenced target
101D:    LJMP loc_1F7Dh    ; 02 1F 7D
1020:    DB 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh
loc_1029h: ; referenced target
1029:    LJMP loc_00F3h    ; 02 00 F3
loc_102Ch: ; referenced target
102C:    LJMP loc_0177h    ; 02 01 77
loc_102Fh: ; referenced target
102F:    LJMP loc_01BEh    ; 02 01 BE
loc_1032h: ; referenced target
1032:    LJMP loc_0408h    ; 02 04 08
loc_1035h: ; referenced target
1035:    LJMP loc_1F8Eh    ; 02 1F 8E
loc_1038h: ; referenced target
1038:    LJMP loc_1B30h    ; 02 1B 30
loc_103Bh: ; referenced target
103B:    RET
103C:    DB 0FFh, 0FFh
loc_103Eh: ; referenced target
103E:    LJMP loc_0C57h    ; 02 0C 57
1041:    DB 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh
loc_1047h: ; referenced target
1047:    LJMP loc_1BD0h    ; 02 1B D0
loc_104Ah: ; referenced target
104A:    LJMP loc_1C8Fh    ; 02 1C 8F
loc_104Dh: ; referenced target
104D:    LJMP loc_0BFDh    ; 02 0B FD
loc_1050h: ; referenced target
1050:    LJMP loc_1DE0h    ; 02 1D E0
loc_1053h: ; referenced target
1053:    LJMP loc_1B39h    ; 02 1B 39
loc_1056h: ; referenced target
1056:    LJMP loc_0892h    ; 02 08 92
loc_1059h: ; referenced target
1059:    LJMP loc_0708h    ; 02 07 08
loc_105Ch: ; referenced target
105C:    LJMP loc_1CB7h    ; 02 1C B7
loc_105Fh: ; referenced target
105F:    LJMP loc_1E00h    ; 02 1E 00
loc_1062h: ; referenced target
1062:    LJMP loc_0B45h    ; 02 0B 45
loc_1065h: ; referenced target
1065:    LJMP loc_0BA5h    ; 02 0B A5
loc_1068h: ; referenced target
1068:    LJMP loc_0895h    ; 02 08 95
loc_106Bh: ; referenced target
106B:    LJMP loc_08E1h    ; 02 08 E1
loc_106Eh: ; referenced target
106E:    LJMP loc_0907h    ; 02 09 07
loc_1071h: ; referenced target
1071:    LJMP loc_0942h    ; 02 09 42
loc_1074h: ; referenced target
1074:    LJMP loc_1B82h    ; 02 1B 82
loc_1077h: ; referenced target
1077:    LJMP loc_09C8h    ; 02 09 C8
loc_107Ah: ; referenced target
107A:    LJMP loc_09EFh    ; 02 09 EF
loc_107Dh: ; referenced target
107D:    LJMP loc_1B40h    ; 02 1B 40
loc_1080h: ; referenced target
1080:    LJMP FFFFh    ; 02 FF FF
loc_1083h: ; referenced target
1083:    LJMP FFFFh    ; 02 FF FF
loc_1086h: ; referenced target
1086:    LJMP FFFFh    ; 02 FF FF
loc_1089h: ; referenced target
1089:    LJMP FFFFh    ; 02 FF FF
loc_108Ch: ; referenced target
108C:    LJMP FFFFh    ; 02 FF FF
108F:    DB 0FFh
loc_1090h: ; referenced target
1090:    NOP
1091:    LJMP loc_021Ah    ; 02 02 1A
1094:    DB 010h
1095:    MOV A, #76h    ; 74 76
1097:    DB 078h, 00Eh, 06Eh, 070h, 072h, 00Ch, 00Ah, 008h, 068h, 06Ah, 06Ch
10A2:    LCALL 7A7Ch   ; 12 7A 7C
10A5:    DB 07Eh, 0FFh, 0FFh, 019h, 01Ch, 038h, 03Ah, 044h, 042h, 09Eh, 0A0h, 0A2h, 03Ch, 03Eh, 098h, 09Ah
10B5:    DB 09Ch, 041h, 0FFh, 02Eh, 020h, 01Eh
10BB:    RET
10BC:    SJMP loc_1040h    ; relative -126
10BE:    DB 084h, 025h, 026h, 02Ah, 08Ch, 08Eh
10C4:    MOV DPTR, #4648h   ; 90 46 48
10C7:    DB 04Ah, 04Ch, 04Eh, 050h, 052h, 055h, 0FFh, 059h, 05Bh, 05Dh, 059h, 05Bh, 061h, 05Eh, 0FFh, 0FFh
10D7:    DB 0FFh, 004h, 014h, 016h, 02Ch, 092h, 094h, 096h, 029h, 087h, 089h, 08Bh, 030h, 032h, 034h, 036h
10E7:    DB 056h, 0A4h, 0A6h, 0A8h, 007h, 063h, 065h, 067h, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0AEh, 0A0h, 093h
10F7:    DB 087h, 0F7h, 0E3h, 0D0h, 0BFh, 001h
10FD:    LJMP loc_0304h    ; 02 03 04
1100:    DB 004h, 005h, 006h, 007h, 081h, 084h, 086h, 089h, 08Bh, 08Eh, 091h, 094h, 096h, 099h, 09Ch, 09Fh
1110:    DB 0A2h, 0A5h, 0A9h, 0ACh, 0AFh, 0B2h, 0B6h, 0B9h, 0BDh, 0C1h, 0C4h, 0C8h, 0CCh, 0D0h, 0D4h, 0D8h
1120:    DB 0DCh, 0E0h
1122:    CLR A
1123:    DB 0E9h, 016h, 004h, 089h, 02Fh, 02Fh, 019h, 003h
112B:    LJMP loc_0100h    ; 02 01 00
loc_112Eh: ; referenced target
112E:    DB 017h, 008h, 023h, 026h, 01Dh, 014h, 00Eh, 00Eh, 00Ah, 060h
1138:    NOP
1139:    DB 001h
113A:    LJMP loc_0304h    ; 02 03 04
113D:    DB 005h, 006h, 007h, 05Ah, 033h, 047h, 040h, 040h, 040h, 040h, 040h, 040h, 040h, 040h, 040h, 040h
114D:    DB 040h, 040h, 040h, 03Ah, 03Bh, 03Dh, 03Eh, 03Fh, 03Fh, 03Fh, 03Fh, 03Fh, 040h, 040h, 040h, 040h
115D:    DB 040h, 040h, 040h, 02Ch
1161:    LJMP FC42h    ; 02 FC 42
1164:    DB 042h
1165:    NOP
1166:    NOP
1167:    DB 084h, 084h
1169:    NOP
116A:    NOP
116B:    DB 031h, 016h, 01Eh, 00Ah, 006h, 004h, 0A2h, 01Fh, 0DCh, 011h, 008h, 001h, 0FFh, 040h, 05Ah, 00Ch
117B:    SJMP loc_1101h    ; relative -124
117D:    DB 07Ch, 088h, 0A2h, 050h, 028h, 0FCh, 049h, 0F9h, 03Ch, 014h, 008h, 001h, 001h, 008h, 001h
118C:    LJMP loc_0101h    ; 02 01 01
118F:    DB 0F9h, 0FFh, 009h, 009h, 024h, 005h, 001h, 01Eh, 03Eh, 004h, 015h, 018h
119B:    NOP
119C:    DB 017h, 0C0h, 027h
119F:    LJMP loc_018Ah    ; 02 01 8A
11A2:    DB 042h, 042h, 009h, 0FFh, 093h, 060h, 058h, 058h, 007h, 08Eh, 066h, 006h, 04Bh, 005h, 0FFh, 032h
11B2:    DB 01Ah, 01Dh, 00Ah, 0B4h, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh
11C2:    DB 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 078h, 0FFh, 055h, 08Ch, 055h, 0FFh, 037h
11D2:    DB 031h, 0FFh, 013h
11D5:    LCALL loc_1149h   ; 12 11 49
11D8:    DB 02Fh, 010h, 07Ah, 026h, 028h, 07Ah, 026h, 028h
loc_11E0h: ; referenced target
11E0:    LCALL A012h   ; 12 A0 12
11E3:    DB 0A6h
11E4:    LCALL C012h   ; 12 C0 12
11E7:    DB 0CAh, 013h, 076h, 013h, 098h, 013h, 0A2h, 013h, 0ACh, 013h, 0BCh, 013h, 0C4h, 013h, 0CCh, 013h
11F7:    DB 0D4h, 013h, 0DCh, 014h, 047h, 014h, 04Fh, 014h, 05Bh, 015h, 070h, 014h, 065h, 014h, 073h, 014h
1207:    DB 086h, 014h, 08Ch, 015h, 038h, 015h, 044h, 015h, 066h, 015h, 07Ah, 015h, 084h, 015h, 08Ah, 015h
1217:    MOV DPTR, #1598h   ; 90 15 98
121A:    DB 015h, 09Eh, 015h, 0ACh, 015h, 0B2h, 015h, 0BCh, 015h, 0D3h, 015h, 0DBh, 015h, 0E5h, 015h, 0EFh
122A:    DB 015h, 0F9h, 016h, 001h, 016h, 00Bh, 016h, 015h, 016h, 01Fh, 016h, 029h, 016h, 04Fh, 016h, 059h
123A:    DB 016h, 094h, 016h, 0BAh, 016h, 0E0h, 018h, 0ECh, 016h, 0FAh
1244:    LCALL CA19h   ; 12 CA 19
1247:    LCALL loc_17A6h   ; 12 17 A6
124A:    DB 013h, 076h, 019h, 0BEh, 017h, 0C8h, 013h, 0ACh, 019h, 0E0h, 017h, 0D8h, 01Bh, 004h, 019h
1259:    MOVX @DPTR, A
125A:    DB 017h, 0E0h, 01Bh, 00Ch, 019h, 0F8h, 017h, 0E8h, 01Bh, 014h, 01Ah
1265:    NOP
1266:    DB 017h, 0F6h, 014h, 08Ch, 01Ah, 00Eh, 018h, 0A2h, 015h, 038h, 01Ah, 0BAh, 018h, 0AEh, 015h, 044h
1276:    DB 01Ah, 0C6h, 018h, 0D0h, 015h, 0B2h, 01Ah, 0E8h, 018h, 0DAh, 015h, 0D3h, 01Ah, 0F2h, 018h, 0E2h
1286:    DB 016h, 04Fh, 01Ah, 0FAh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh
loc_1296h: ; referenced target
1296:    DB 014h, 004h, 02Eh, 052h, 048h, 038h, 001h, 003h
129E:    LJMP loc_0013h    ; 02 00 13
12A1:    LJMP 4180h    ; 02 41 80
12A4:    SJMP loc_1226h    ; relative -128
12A6:    DB 004h, 00Ch, 004h, 007h, 008h, 00Fh, 01Ah, 035h, 01Ch, 01Ch, 010h, 007h, 003h, 016h
12B4:    LJMP loc_1325h    ; 02 13 25
12B7:    DB 034h, 048h, 05Fh, 089h, 0A2h, 0C3h, 0E0h, 0F3h, 0FBh, 037h, 004h, 018h, 02Ch, 048h, 067h, 011h
12C7:    DB 014h, 019h, 021h, 037h, 00Ch, 004h, 004h, 008h, 008h, 008h, 008h, 018h, 010h, 010h, 018h, 010h
12D7:    DB 064h, 049h, 00Ch, 005h, 00Bh, 005h, 006h, 005h, 00Ah, 010h, 00Bh, 00Ah, 016h, 014h, 072h, 023h
12E7:    DB 026h, 02Ch, 02Fh, 031h, 031h, 031h, 031h, 031h, 031h, 031h, 031h, 023h, 026h, 02Ch, 02Fh, 031h
12F7:    DB 031h, 031h, 031h, 031h, 031h, 031h, 031h, 023h, 02Ah, 031h, 039h, 040h, 040h, 033h, 031h, 031h
1307:    DB 031h, 031h, 031h, 032h, 039h, 040h, 040h, 040h, 041h, 034h, 031h, 02Dh, 02Dh, 02Dh, 02Dh, 037h
1317:    DB 040h, 040h, 044h, 044h, 03Ch, 039h, 033h, 02Eh, 02Dh, 02Dh, 02Dh, 03Ch, 040h, 040h, 043h, 044h
1327:    DB 041h, 03Bh, 036h, 034h, 02Dh, 029h, 029h, 040h, 047h, 047h, 047h, 047h, 042h, 03Ch, 037h, 034h
1337:    DB 02Dh, 029h, 029h, 046h, 04Bh, 04Fh, 04Fh, 04Fh, 048h, 045h, 040h, 039h, 031h, 02Eh, 02Dh, 046h
1347:    DB 04Bh, 04Fh, 04Fh, 04Fh, 04Fh, 048h, 045h, 040h, 039h, 036h, 034h, 046h, 04Bh, 04Fh, 04Fh, 04Fh
1357:    DB 04Fh, 04Fh, 048h, 042h, 03Dh, 039h, 036h, 046h, 04Bh, 04Fh, 04Fh, 04Fh, 04Fh, 04Fh, 048h, 045h
1367:    DB 03Eh, 03Ah, 036h, 046h, 04Bh, 04Fh, 04Fh, 04Fh, 04Fh, 04Fh, 048h, 045h, 03Eh, 03Ah, 036h, 037h
1377:    DB 010h, 00Ch, 00Dh, 003h, 003h, 007h, 00Ch, 007h, 006h, 00Ch, 00Dh, 00Ch, 00Dh, 007h, 005h, 006h
1387:    DB 064h, 032h, 032h, 02Dh, 027h, 027h, 027h, 02Ah, 02Eh, 02Eh, 030h, 030h, 030h, 030h, 032h, 032h
1397:    DB 032h
1398:    LCALL loc_0406h   ; 12 04 06
139B:    DB 004h
139C:    LJMP 3F14h    ; 02 3F 14
139F:    DB 014h, 014h, 014h, 013h, 004h, 016h, 00Fh, 052h, 04Fh, 014h, 014h, 014h, 014h, 037h, 007h, 004h
13AF:    DB 003h, 00Eh, 008h, 010h, 018h, 0ACh, 03Fh, 01Bh, 01Bh, 01Ch, 02Ah, 02Ah, 047h, 013h, 003h, 04Eh
13BF:    DB 059h, 04Fh, 026h, 00Dh, 014h, 013h, 003h, 00Eh, 04Ah, 05Eh, 014h, 006h, 014h, 037h, 003h, 007h
13CF:    DB 00Dh, 0E9h, 01Ch, 032h, 032h, 013h, 003h, 04Eh, 055h, 04Fh, 01Bh, 014h, 00Dh, 037h, 00Ch, 003h
13DF:    DB 004h, 004h, 004h, 004h, 010h, 010h, 005h, 027h, 023h, 01Fh, 05Eh, 011h, 007h, 01Dh, 01Eh, 01Dh
13EF:    DB 01Eh, 01Dh, 007h, 00Eh, 019h, 01Ah, 017h, 010h, 00Ch, 00Ah, 007h, 049h, 02Ah, 017h, 010h, 00Ch
13FF:    DB 00Ah, 007h, 049h, 02Ah, 017h, 010h, 00Ch, 00Ah, 007h, 051h, 02Eh, 019h
140B:    LCALL loc_0E0Bh   ; 12 0E 0B
140E:    DB 007h, 05Dh, 035h, 01Dh, 014h, 010h, 00Dh, 008h, 06Ah, 03Dh, 021h, 017h
141A:    LCALL loc_0F09h   ; 12 0F 09
141D:    DB 06Ah, 061h, 035h, 025h, 01Ch, 018h, 00Eh, 06Ah, 061h, 03Ah, 02Ah, 021h, 01Bh, 010h, 06Ah, 06Ah
142D:    DB 03Fh, 02Eh, 024h, 01Eh
1431:    LCALL 6A6Ah   ; 12 6A 6A
1434:    DB 06Ah, 04Eh, 03Dh, 033h, 01Eh, 06Ah, 06Ah, 06Ah, 06Ah, 053h, 045h, 02Ah, 06Ah, 06Ah, 06Ah, 06Ah
1444:    DB 067h, 056h, 033h, 013h, 003h, 038h, 042h, 07Ch
144C:    LCALL loc_1414h   ; 12 14 14
144F:    DB 013h, 005h, 06Ch, 019h, 01Eh, 01Eh, 031h, 064h, 064h, 01Eh, 01Eh, 01Eh
145B:    LCALL loc_0420h   ; 12 04 20
145E:    DB 02Eh, 03Bh, 06Dh
1461:    MOV DPTR, #8A80h   ; 90 8A 80
1464:    SJMP loc_1479h    ; relative +19
1466:    DB 006h, 020h, 010h, 016h, 008h, 050h, 058h, 0A6h, 05Ah, 043h, 02Dh, 00Fh
1472:    NOP
1473:    DB 037h, 003h, 032h, 032h, 083h, 049h, 003h, 028h, 03Ch
147C:    MOV A, #FFh    ; 74 FF
147E:    DB 0FFh, 0FFh, 0FFh, 0FFh, 0C0h, 0FFh, 0B3h
1485:    SJMP loc_14BEh    ; relative +55
1487:    LJMP loc_19DAh    ; 02 19 DA
148A:    DB 0FFh, 0FFh, 037h, 00Ch, 004h, 004h, 008h, 008h, 008h, 008h, 018h, 010h, 010h, 018h, 010h, 064h
149A:    DB 049h, 00Ch, 005h, 00Bh, 005h, 006h, 005h, 00Ah, 010h, 00Bh, 00Ah, 016h, 014h, 072h, 085h, 085h
14AA:    DB 085h, 085h, 085h, 085h, 084h, 083h, 083h, 083h, 083h, 083h, 085h, 085h, 085h, 084h, 084h, 084h
14BA:    DB 084h, 084h, 084h, 084h, 084h, 084h, 085h, 085h, 085h, 084h, 084h, 084h, 084h, 084h, 084h, 084h
14CA:    DB 084h, 084h, 085h, 086h, 086h, 086h, 086h, 086h, 088h, 088h, 089h, 089h, 089h, 089h, 085h, 086h
14DA:    DB 086h, 087h, 088h, 088h, 088h, 088h, 089h, 08Fh, 08Fh, 08Fh, 085h, 086h, 087h, 088h, 088h, 089h
14EA:    DB 089h, 089h, 089h, 08Ah, 095h, 095h, 085h, 086h, 088h, 088h, 088h, 089h, 089h, 089h, 08Ah, 08Ch
14FA:    DB 094h, 094h, 085h, 087h, 088h, 088h, 08Ah, 08Ah, 08Ah, 08Ah, 08Bh, 08Ch, 08Dh, 096h, 085h, 087h
150A:    DB 088h, 088h, 08Ah, 08Ah, 08Ah, 08Bh, 08Bh, 08Ch, 08Dh, 093h, 085h, 087h, 089h, 089h, 08Bh, 08Bh
151A:    DB 08Bh, 08Bh, 08Bh, 08Bh, 08Bh, 08Fh, 085h, 087h, 088h, 088h, 088h, 089h, 089h, 089h, 089h, 089h
loc_152Ah: ; referenced target
152A:    DB 089h, 08Ah, 088h, 088h, 08Ah, 08Ah, 08Ah, 089h, 088h, 088h, 088h, 088h, 088h, 088h, 037h, 005h
153A:    LJMP loc_020Ah    ; 02 02 0A
153D:    DB 010h, 0D0h
153F:    SJMP loc_14C4h    ; relative -125
1541:    DB 083h, 084h, 084h, 037h, 010h, 00Ch, 00Dh, 003h, 003h, 007h, 00Ch, 007h, 006h, 00Ch, 00Dh, 00Ch
1551:    DB 00Dh, 007h, 005h, 006h, 064h, 08Ah, 08Fh, 095h, 097h, 09Ah, 09Dh, 09Dh, 09Fh, 09Fh, 09Dh, 09Dh
1561:    DB 09Bh, 09Bh, 09Bh, 09Bh, 09Bh, 013h, 004h, 02Eh, 01Dh, 01Eh, 06Dh, 05Ah, 02Dh, 033h
156F:    NOP
1570:    LCALL loc_0416h   ; 12 04 16
1573:    DB 00Fh, 00Fh, 04Fh
1576:    NOP
1577:    DB 027h, 027h, 027h, 013h, 004h, 04Ah, 01Eh, 021h, 069h, 0B6h, 01Ch
1582:    LCALL loc_0C13h   ; 12 0C 13
1585:    LJMP 38BEh    ; 02 38 BE
1588:    DB 00Fh, 00Fh, 04Dh
158B:    LJMP loc_14ECh    ; 02 14 EC
158E:    DB 0FBh, 053h, 037h, 003h, 003h, 004h, 0F1h, 0F8h, 0CBh, 093h, 011h
1599:    LJMP 7515h    ; 02 75 15
159C:    DB 05Dh, 01Dh, 037h, 006h, 003h, 00Dh, 00Eh, 032h, 032h, 06Ah, 040h, 040h
15A8:    SJMP loc_152Ah    ; relative -128
15AA:    SJMP loc_152Ch    ; relative -128
15AC:    DB 003h
15AD:    LJMP 31CDh    ; 02 31 CD
15B0:    NOP
15B1:    DB 0FFh, 013h, 004h, 01Eh, 01Dh, 01Eh, 06Dh, 026h, 026h, 013h
15BB:    NOP
15BC:    DB 037h, 003h, 019h, 019h, 0B5h, 049h, 004h, 01Eh, 01Eh, 01Eh, 07Eh, 0FFh, 0FFh, 0FFh, 0CDh, 0FFh
15CC:    DB 0FFh, 0FFh, 0CDh, 0FFh, 0FFh, 0CDh, 0B3h, 013h, 003h, 028h, 02Dh, 083h, 03Bh, 02Ch
15DA:    NOP
15DB:    DB 003h, 004h, 00Dh, 010h, 010h, 0D0h
15E1:    NOP
15E2:    NOP
15E3:    DB 040h, 0FFh, 013h, 004h, 00Fh, 06Fh, 016h, 05Eh, 028h, 019h, 017h, 014h, 013h, 004h, 04Bh, 01Dh
15F3:    DB 036h, 04Dh, 014h, 014h, 014h, 014h, 013h, 003h, 06Dh, 027h, 04Dh, 019h, 017h, 015h, 003h, 004h
1603:    LJMP loc_0B03h    ; 02 0B 03
1606:    MOVX @DPTR, A
1607:    LJMP loc_0A10h    ; 02 0A 10
160A:    DB 001h, 003h, 004h
160D:    LJMP loc_0605h    ; 02 06 05
1610:    DB 0F3h
1611:    LJMP loc_0A0Ah    ; 02 0A 0A
1614:    DB 010h, 003h, 004h, 001h, 008h, 006h
161A:    MOVX @DPTR, A
161B:    NOP
161C:    DB 01Eh, 050h, 050h, 037h, 004h, 001h, 00Dh
1623:    LCALL C100h   ; 12 C1 00
1626:    DB 01Ah, 01Ah, 01Ah, 037h, 006h, 005h, 005h, 009h, 00Bh, 032h, 09Ch, 013h, 004h, 030h, 016h, 063h
1636:    DB 04Dh, 0FFh, 060h, 059h, 017h, 0FFh, 060h, 059h, 017h, 0FFh, 060h, 059h, 017h, 0FFh, 06Eh, 05Ah
1646:    DB 01Ah, 0FFh, 099h, 089h, 033h, 0FFh, 0C8h, 0BAh
164E:    SJMP loc_1663h    ; relative +19
1650:    DB 004h, 04Dh, 01Dh, 02Ah, 05Eh, 028h, 01Bh, 016h, 014h, 037h, 007h, 00Ah, 00Ah, 00Ah, 00Ah, 014h
1660:    DB 019h, 09Ch, 049h, 006h, 00Ah, 00Ah, 00Ah, 014h, 014h, 09Ch, 004h, 007h, 00Ah, 00Ah, 00Eh, 00Eh
1670:    DB 008h, 00Fh
1672:    LCALL loc_1616h   ; 12 16 16
1675:    DB 016h, 00Ch, 013h, 018h, 01Dh, 023h, 023h, 014h, 020h, 023h, 027h, 02Dh, 02Dh, 01Eh, 020h, 027h
1685:    DB 02Dh, 02Dh, 02Dh, 028h, 028h, 02Dh, 02Dh, 02Dh, 02Dh, 028h, 028h, 02Dh, 02Dh, 02Dh, 02Dh, 037h
1695:    DB 004h, 00Ah, 00Ah, 00Ah, 0C9h, 049h, 006h, 00Ah, 00Ah, 00Ah, 014h, 014h, 09Ch, 028h, 03Ch, 046h
16A5:    DB 050h, 05Ah, 05Ah, 028h, 041h, 050h, 05Fh, 05Fh, 05Fh, 034h, 04Dh, 064h, 064h, 064h, 064h, 04Bh
16B5:    DB 064h, 064h, 064h, 064h, 064h, 037h, 004h, 00Ah, 00Ah, 00Ah, 0C9h, 049h, 006h, 00Ah, 00Ah, 00Ah
16C5:    DB 014h, 014h, 09Ch, 005h, 005h, 005h, 005h, 005h, 005h, 005h, 005h, 005h, 005h, 005h, 005h, 009h
16D5:    DB 009h, 009h, 009h, 00Ch, 00Ch, 005h, 008h, 00Ah, 00Ch, 010h, 010h, 037h, 00Ch, 00Dh, 006h, 006h
16E5:    DB 00Dh, 019h, 00Ch, 00Dh, 00Ch, 007h, 006h, 006h, 064h, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh
16F5:    DB 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 037h, 00Ch, 004h, 004h, 008h, 008h, 008h, 008h, 018h, 010h, 010h
1705:    DB 018h, 010h, 064h, 049h, 00Ch, 005h, 00Bh, 005h, 006h, 005h, 00Ah, 010h, 00Bh, 00Ah, 016h, 014h
1715:    DB 072h, 023h, 026h, 02Ch, 02Fh, 031h, 031h, 031h, 031h, 031h, 031h, 031h, 031h, 023h, 026h, 02Ch
1725:    DB 02Fh, 031h, 031h, 031h, 031h, 031h, 031h, 031h, 031h, 023h, 02Ah, 031h, 039h, 040h, 040h, 037h
1735:    DB 031h, 031h, 031h, 031h, 031h, 032h, 039h, 044h, 045h, 048h, 042h, 037h, 031h, 031h, 031h, 031h
1745:    DB 031h, 037h, 040h, 04Ah, 04Fh, 04Fh, 045h, 03Ch, 037h, 031h, 031h, 031h, 031h, 03Ch, 043h, 04Ah
1755:    DB 04Fh, 04Fh, 048h, 042h, 03Bh, 035h, 031h, 02Dh, 02Dh, 040h, 049h, 04Fh, 04Fh, 04Fh, 048h, 042h
1765:    DB 03Ch, 034h, 02Dh, 029h, 029h, 046h, 04Bh, 04Fh, 04Fh, 04Fh, 048h, 045h, 042h, 039h, 032h, 02Eh
1775:    DB 02Dh, 046h, 04Bh, 04Fh, 04Fh, 04Fh, 04Fh, 048h, 045h, 040h, 039h, 036h, 034h, 046h, 04Bh, 04Fh
1785:    DB 04Fh, 04Fh, 04Fh, 04Fh, 048h, 042h, 03Dh, 039h, 036h, 046h, 04Bh, 04Fh, 04Fh, 04Fh, 04Fh, 04Fh
1795:    DB 048h, 045h, 03Eh, 03Ah, 036h, 046h, 04Bh, 04Fh, 04Fh, 04Fh, 04Fh, 04Fh, 048h, 045h, 03Eh, 03Ah
17A5:    DB 036h, 037h, 010h, 00Ch, 00Dh, 003h, 003h, 007h, 00Ch, 007h, 006h, 00Ch, 00Dh, 00Ch, 00Dh, 007h
17B5:    DB 005h, 006h, 064h, 032h, 032h, 02Dh, 027h, 027h, 027h, 02Ah, 02Eh, 02Eh, 030h, 030h, 030h, 030h
17C5:    DB 032h, 032h, 032h, 037h, 007h
17CA:    LJMP loc_030Eh    ; 02 03 0E
17CD:    DB 008h, 010h, 018h, 0ACh, 040h, 01Bh, 01Bh, 01Ch, 02Ah, 02Ah, 047h, 013h, 003h, 04Eh, 059h, 04Fh
17DD:    DB 026h, 014h, 014h, 013h, 003h, 073h, 025h, 05Eh, 014h, 014h, 014h, 013h, 006h, 020h, 010h, 01Eh
17ED:    DB 01Dh, 035h, 056h, 0A6h, 05Ah, 043h, 021h, 013h
17F5:    NOP
17F6:    DB 037h, 00Ch, 004h, 004h, 008h, 008h, 008h, 008h, 018h, 010h, 010h, 018h, 010h, 064h, 049h, 00Ch
1806:    DB 005h, 00Bh, 005h, 006h, 005h, 00Ah, 010h, 00Bh, 00Ah, 016h, 014h, 072h
1812:    SJMP loc_1794h    ; relative -128
1814:    SJMP loc_1796h    ; relative -128
1816:    SJMP loc_1896h    ; relative +126
1818:    DB 07Ch, 07Ch, 07Eh, 07Eh, 07Eh, 07Eh
181E:    SJMP loc_17A0h    ; relative -128
1820:    SJMP loc_17A2h    ; relative -128
1822:    SJMP loc_18A2h    ; relative +126
1824:    DB 07Ch, 07Ch, 07Eh, 07Eh, 07Eh, 07Eh, 07Ch, 07Ch, 07Eh, 07Eh, 07Eh, 07Eh, 07Dh, 07Dh, 07Eh, 07Eh
1834:    DB 07Eh, 07Eh, 07Ch, 07Eh, 07Fh
1839:    SJMP loc_18BAh    ; relative +127
183B:    DB 07Fh
183C:    SJMP loc_17BEh    ; relative -128
183E:    SJMP loc_17C9h    ; relative -119
1840:    DB 08Ch, 08Ch, 07Ch, 07Eh
1844:    SJMP loc_17C6h    ; relative -128
1846:    DB 082h, 082h, 082h, 082h, 083h, 08Bh, 08Fh, 08Fh, 07Ch, 07Eh
1850:    SJMP loc_17D4h    ; relative -126
1852:    DB 082h, 082h, 082h, 082h, 083h, 083h, 095h, 095h, 07Ch, 07Eh, 081h, 082h, 082h, 082h, 082h, 082h
1862:    DB 083h, 085h, 08Dh, 095h, 07Fh
1867:    SJMP loc_17EBh    ; relative -126
1869:    DB 083h, 084h, 083h, 083h, 083h, 083h, 087h, 08Dh, 095h, 081h, 082h, 083h, 084h, 084h, 083h, 083h
1879:    DB 083h, 084h, 087h, 08Dh, 093h, 083h, 084h, 084h, 084h, 084h, 084h, 083h, 084h, 084h, 087h, 08Dh
1889:    DB 08Dh, 085h, 085h, 085h, 085h, 085h, 085h, 084h, 084h, 084h, 086h, 089h, 08Ch, 088h, 088h, 088h
1899:    DB 088h, 088h, 086h, 086h, 086h, 086h, 086h, 086h, 087h, 037h, 005h
18A4:    LJMP loc_020Ah    ; 02 02 0A
18A7:    DB 010h, 0D0h
18A9:    SJMP loc_182Eh    ; relative -125
18AB:    DB 083h, 084h, 084h, 037h, 010h, 00Ch, 00Dh, 003h, 003h, 007h, 00Ch, 007h, 006h, 00Ch, 00Dh, 00Ch
18BB:    DB 00Dh, 007h, 005h, 006h, 064h, 08Ah, 08Fh, 095h, 097h, 09Ah, 09Dh, 09Dh, 09Fh, 09Fh, 09Dh, 09Dh
18CB:    DB 098h, 08Dh, 08Ah, 08Ah, 08Ah, 013h, 004h, 01Eh, 01Dh, 01Eh, 06Dh, 026h, 026h, 013h, 013h, 013h
18DB:    DB 003h, 02Dh, 04Bh, 05Eh, 03Bh, 02Ch
18E1:    NOP
18E2:    DB 013h, 004h, 04Dh, 01Dh, 02Ah, 05Eh, 028h, 01Bh, 016h, 014h, 037h, 004h, 00Ah, 00Ah, 00Ah, 0C9h
18F2:    DB 049h, 006h, 00Ah, 00Ah, 00Ah, 014h, 014h, 09Ch, 00Ah, 00Ah, 00Ah, 00Ch, 00Fh, 00Fh, 00Ah, 00Ah
1902:    LCALL loc_1419h   ; 12 14 19
1905:    DB 019h, 00Fh, 016h, 019h, 01Dh, 01Dh, 01Dh, 00Fh, 019h, 01Eh, 021h, 021h, 021h, 037h, 00Ch, 004h
1915:    DB 004h, 008h, 008h, 008h, 008h, 018h, 010h, 010h, 018h, 010h, 064h, 049h, 00Ch, 005h, 00Bh, 005h
1925:    DB 006h, 005h, 00Ah, 010h, 00Bh, 00Ah, 016h, 014h, 072h, 023h, 026h, 02Ch, 02Fh, 031h, 031h, 031h
1935:    DB 031h, 031h, 031h, 031h, 031h, 023h, 026h, 02Bh, 02Bh, 02Bh, 02Bh, 02Bh, 02Bh, 02Bh, 031h, 031h
1945:    DB 031h, 023h, 02Ah, 02Bh, 02Ch, 02Ch, 02Ch, 029h, 029h, 029h, 031h, 031h, 031h, 032h, 032h, 031h
1955:    DB 02Fh, 02Ch, 02Ch, 029h, 029h, 029h, 031h, 031h, 031h, 036h, 032h, 031h, 02Fh, 02Eh, 02Ch, 029h
1965:    DB 029h, 029h, 031h, 031h, 031h, 038h, 035h, 031h, 031h, 02Fh, 02Dh, 02Ah, 02Ah, 029h, 02Dh, 02Dh
1975:    DB 02Dh, 03Dh, 036h, 031h, 031h, 02Fh, 02Fh, 02Eh, 02Dh, 029h, 029h, 029h, 029h, 040h, 040h, 040h
1985:    DB 040h, 040h, 041h, 039h, 039h, 039h, 032h, 02Eh, 02Dh, 046h, 04Bh, 04Fh, 04Fh, 04Fh, 04Fh, 048h
1995:    DB 045h, 040h, 039h, 036h, 034h, 046h, 04Bh, 04Fh, 04Fh, 04Fh, 04Fh, 04Fh, 048h, 042h, 03Dh, 039h
19A5:    DB 036h, 046h, 04Bh, 04Fh, 04Fh, 04Fh, 04Fh, 04Fh, 048h, 045h, 03Eh, 03Ah, 036h, 046h, 04Bh, 04Fh
19B5:    DB 04Fh, 04Fh, 04Fh, 04Fh, 048h, 045h, 03Eh, 03Ah, 036h, 037h, 010h, 00Ch, 00Dh, 003h, 003h, 007h
19C5:    DB 00Ch, 007h, 006h, 00Ch, 00Dh, 00Ch, 00Dh, 007h, 005h, 006h, 064h, 032h, 032h, 02Dh, 027h, 027h
19D5:    DB 027h, 02Ah, 02Eh, 02Eh, 030h, 030h, 030h, 030h, 032h, 032h, 032h, 037h, 007h
19E2:    LJMP loc_030Eh    ; 02 03 0E
19E5:    DB 008h, 010h, 018h, 0ACh, 040h, 01Bh, 01Bh, 01Ch, 02Ah, 02Ah, 047h, 013h, 003h, 04Eh, 059h, 04Fh
19F5:    DB 026h, 014h, 014h, 013h, 003h, 073h, 025h, 05Eh, 014h, 014h, 014h, 013h, 006h, 020h, 010h, 01Eh
1A05:    DB 01Dh, 035h, 056h, 0A6h, 05Ah, 043h, 021h, 013h
1A0D:    NOP
1A0E:    DB 037h, 00Ch, 004h, 004h, 008h, 008h, 008h, 008h, 018h, 010h, 010h, 018h, 010h, 064h, 049h, 00Ch
1A1E:    DB 005h, 00Bh, 005h, 006h, 005h, 00Ah, 010h, 00Bh, 00Ah, 016h, 014h, 072h
1A2A:    SJMP loc_19ACh    ; relative -128
1A2C:    SJMP loc_19AEh    ; relative -128
1A2E:    SJMP loc_1AAEh    ; relative +126
1A30:    DB 07Ch, 07Ch, 07Eh, 07Eh, 07Eh, 07Eh
1A36:    SJMP loc_19B8h    ; relative -128
1A38:    SJMP loc_19BAh    ; relative -128
1A3A:    SJMP loc_1ABAh    ; relative +126
1A3C:    DB 07Ch, 07Ch, 07Eh, 07Eh, 07Eh, 07Eh, 07Ch, 07Ch, 07Eh, 07Eh, 07Eh, 07Eh, 07Dh, 07Dh, 07Eh, 07Eh
1A4C:    DB 07Eh, 07Eh, 07Ch, 07Eh, 07Fh
1A51:    SJMP loc_1AD2h    ; relative +127
1A53:    DB 07Fh
1A54:    SJMP loc_19D6h    ; relative -128
1A56:    SJMP loc_19E1h    ; relative -119
1A58:    DB 08Ch, 08Ch, 07Ch, 07Eh
1A5C:    SJMP loc_19DEh    ; relative -128
1A5E:    DB 082h, 082h, 082h, 082h, 083h, 08Bh, 08Fh, 08Fh, 07Ch, 07Eh
1A68:    SJMP loc_19ECh    ; relative -126
1A6A:    DB 082h, 082h, 082h, 082h, 083h, 083h, 095h, 095h, 07Ch, 07Eh, 081h, 082h, 082h, 082h, 082h, 082h
1A7A:    DB 083h, 085h, 08Dh, 095h, 07Fh
1A7F:    SJMP loc_1A03h    ; relative -126
1A81:    DB 083h, 084h, 083h, 083h, 083h, 083h, 087h, 08Dh, 095h, 081h, 082h, 083h, 084h, 084h, 083h, 083h
1A91:    DB 083h, 084h, 087h, 08Dh, 093h, 083h, 084h, 084h, 084h, 084h, 084h, 083h, 084h, 084h, 087h, 08Dh
1AA1:    DB 08Dh, 085h, 085h, 085h, 085h, 085h, 085h, 084h, 084h, 084h, 086h, 089h, 08Ch, 088h, 088h, 088h
1AB1:    DB 088h, 088h, 086h, 086h, 086h, 086h, 086h, 086h, 087h, 037h, 005h
1ABC:    LJMP loc_020Ah    ; 02 02 0A
1ABF:    DB 010h, 0D0h
1AC1:    SJMP loc_1A46h    ; relative -125
1AC3:    DB 083h, 084h, 084h, 037h, 010h, 00Ch, 00Dh, 003h, 003h, 007h, 00Ch, 007h, 006h, 00Ch, 00Dh, 00Ch
1AD3:    DB 00Dh, 007h, 005h, 006h, 064h, 08Ah, 08Fh, 095h, 097h, 09Ah, 09Dh, 09Dh, 09Fh, 09Fh, 09Dh, 09Dh
1AE3:    DB 098h, 08Dh, 08Ah, 08Ah, 08Ah, 013h, 004h, 01Eh, 01Dh, 01Eh, 06Dh, 026h, 026h, 013h, 013h, 013h
1AF3:    DB 003h, 02Dh, 04Bh, 05Eh, 03Bh, 02Ch
1AF9:    NOP
1AFA:    DB 013h, 004h, 04Dh, 01Dh, 02Ah, 05Eh, 028h, 01Bh, 016h, 014h, 013h, 003h, 04Eh, 059h, 04Fh, 026h
1B0A:    DB 00Dh, 014h, 013h, 003h, 073h, 025h, 05Eh, 014h, 014h, 014h, 013h, 006h, 020h, 010h, 01Eh, 01Dh
1B1A:    DB 035h, 056h, 0A6h, 05Ah, 043h, 025h, 016h
1B21:    NOP
1B22:    DB 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 030h, 007h
1B32:    DB 003h
1B33:    LJMP loc_0A75h    ; 02 0A 75
1B36:    LJMP loc_105Fh    ; 02 10 5F
loc_1B39h: ; referenced target
1B39:    DB 030h, 007h, 003h
1B3C:    LJMP loc_1D15h    ; 02 1D 15
1B3F:    RET
loc_1B40h: ; referenced target
1B40:    DB 0AFh, 001h, 0AEh
1B43:    NOP
1B44:    MOV A, #01h    ; 74 01
loc_1B46h: ; referenced target
1B46:    LCALL loc_0509h   ; 12 05 09
1B49:    DB 08Fh, 07Bh
1B4B:    MOV A, #41h    ; 74 41
1B4D:    DB 093h
loc_1B4Eh: ; referenced target
1B4E:    LCALL loc_04D9h   ; 12 04 D9
1B51:    MOV A, #42h    ; 74 42
1B53:    DB 093h, 02Fh, 0FFh
1B56:    MOV A, #0Bh    ; 74 0B
1B58:    DB 093h, 0F8h
1B5A:    MOV A, #0Ch    ; 74 0C
1B5C:    DB 093h, 0F9h
1B5E:    LCALL loc_0455h   ; 12 04 55
1B61:    DB 0EEh, 0F4h, 0F8h, 0EFh, 0F4h, 0F9h
1B67:    MOV A, #0Bh    ; 74 0B
1B69:    DB 093h, 0FBh
1B6B:    MOV A, #0Ch    ; 74 0C
1B6D:    DB 093h, 0FCh, 0D3h, 0EEh, 09Bh, 0CFh, 09Ch, 0FBh, 0C2h, 0AFh, 08Fh, 044h, 08Bh, 045h, 088h, 042h
1B7D:    DB 089h, 043h, 0D2h, 0AFh
1B81:    RET
loc_1B82h: ; referenced target
1B82:    DB 0E9h, 0C3h, 030h, 0E7h, 013h, 020h, 01Ah, 01Fh
1B8A:    MOV A, #3Dh    ; 74 3D
1B8C:    DB 093h, 013h, 024h
1B8F:    SJMP loc_1B46h    ; relative -75
1B91:    DB 001h
1B92:    NOP
1B93:    DB 050h, 014h, 0F9h, 0D2h, 003h
1B98:    SJMP loc_1BA9h    ; relative +15
1B9A:    MOV A, #3Eh    ; 74 3E
1B9C:    DB 093h, 013h, 0F4h, 024h
1BA0:    SJMP loc_1B57h    ; relative -75
1BA2:    DB 001h
1BA3:    NOP
1BA4:    DB 040h, 003h, 0F9h, 0D2h, 004h, 07Ah, 057h, 0F1h, 0F2h
1BAD:    LCALL loc_051Dh   ; 12 05 1D
1BB0:    DB 0B5h, 049h
1BB2:    NOP
1BB3:    DB 040h
1BB4:    LJMP D204h    ; 02 D2 04
1BB7:    DB 0E9h, 0C3h, 094h
1BBA:    SJMP loc_1B4Eh    ; relative -110
1BBC:    DB 005h, 0F9h
1BBE:    LJMP loc_1077h    ; 02 10 77
loc_1BC1h: ; referenced target
1BC1:    MOV DPTR, #1124h   ; 90 11 24
1BC4:    LCALL loc_05CDh   ; 12 05 CD
1BC7:    DB 013h, 092h, 019h, 013h, 092h, 018h
1BCD:    LJMP loc_1047h    ; 02 10 47
loc_1BD0h: ; referenced target
1BD0:    DB 0E5h, 015h, 0B4h
1BD3:    SJMP loc_1BD5h    ; relative +0
loc_1BD5h: ; referenced target
1BD5:    DB 0B3h, 092h, 01Bh
1BD8:    MOV DPTR, #1296h   ; 90 12 96
1BDB:    LCALL loc_05CDh   ; 12 05 CD
1BDE:    DB 013h, 092h, 02Fh, 013h, 092h, 02Eh
1BE4:    NOP
1BE5:    NOP
1BE6:    NOP
1BE7:    DB 030h, 02Eh, 004h, 0C2h, 007h, 061h
1BED:    MOVX @DPTR, A
1BEE:    DB 0D2h, 007h
1BF0:    MOV A, #10h    ; 74 10
1BF2:    DB 093h, 0C3h, 095h, 037h, 050h, 00Bh, 07Ah, 003h
1BFA:    LCALL loc_051Dh   ; 12 05 1D
1BFD:    DB 0C3h, 095h, 037h, 040h, 01Fh
1C02:    RET
1C03:    DB 0D2h, 01Ah, 030h, 007h, 014h
1C08:    MOV A, #6Fh    ; 74 6F
1C0A:    DB 093h, 0B5h, 013h
1C0D:    NOP
1C0E:    DB 0B3h, 092h, 02Dh
1C11:    MOV A, #6Dh    ; 74 6D
1C13:    DB 093h, 0B5h, 013h
1C16:    NOP
1C17:    DB 0B3h, 092h, 02Ch, 081h, 020h, 0C2h, 02Ch, 0C2h, 02Dh
1C20:    RET
1C21:    DB 0C2h, 01Ah
1C23:    RET
loc_1C24h: ; referenced target
1C24:    DB 07Dh
1C25:    NOP
1C26:    DB 0C3h, 030h, 01Ah, 008h, 07Ah, 049h, 091h, 0AEh, 091h, 0AEh, 081h, 08Ch, 030h, 018h
1C34:    LCALL 7A04h   ; 12 7A 04
1C37:    DB 020h, 02Ch, 004h, 0F1h, 0F2h, 081h, 041h
1C3E:    LCALL loc_1D10h   ; 12 1D 10
1C41:    DB 091h, 0AEh, 07Ah, 008h, 081h, 088h, 030h, 019h, 006h, 07Ah, 00Ch, 091h, 0AEh, 081h, 069h, 07Ah
1C51:    LCALL 202Ch   ; 12 20 2C
1C54:    DB 004h, 0F1h, 0F2h, 081h, 05Ch
1C59:    LCALL loc_1D10h   ; 12 1D 10
1C5C:    DB 091h, 0AEh
1C5E:    MOV A, #20h    ; 74 20
1C60:    DB 093h, 095h, 049h, 040h, 004h, 07Ah, 05Bh, 081h, 088h, 07Ah, 00Dh, 091h, 0AEh, 020h, 019h
1C6F:    LJMP 7A5Bh    ; 02 7A 5B
1C72:    MOV DPTR, #112Eh   ; 90 11 2E
1C75:    LCALL loc_05CDh   ; 12 05 CD
1C78:    DB 030h, 0E2h, 00Dh
1C7B:    MOV A, #21h    ; 74 21
1C7D:    DB 093h, 0C3h, 095h, 037h, 050h, 005h
1C83:    MOV A, #22h    ; 74 22
1C85:    DB 093h, 02Dh, 0FDh, 0F1h, 0F2h, 091h, 0AEh
1C8C:    LJMP loc_104Ah    ; 02 10 4A
loc_1C8Fh: ; referenced target
1C8F:    DB 07Ah, 048h, 091h, 0AEh, 0F8h, 0A2h, 0E7h
1C96:    MOV A, #23h    ; 74 23
1C98:    DB 050h, 001h, 004h, 093h, 0F9h, 050h, 001h, 0C8h, 0C3h, 098h, 050h
1CA3:    LJMP E9FDh    ; 02 E9 FD
1CA6:    DB 0EDh, 0A2h, 0E7h, 013h, 0FDh
1CAB:    LJMP loc_104Dh    ; 02 10 4D
1CAE:    LCALL loc_051Dh   ; 12 05 1D
1CB1:    DB 02Dh, 0C3h, 094h, 014h, 0FDh
1CB6:    RET
loc_1CB7h: ; referenced target
1CB7:    DB 020h, 01Ah, 051h, 020h, 019h, 04Eh, 020h, 01Dh, 04Bh
1CC0:    NOP
1CC1:    NOP
1CC2:    NOP
1CC3:    MOV A, #4Bh    ; 74 4B
1CC5:    DB 093h, 0B5h, 037h
1CC8:    NOP
1CC9:    DB 040h, 040h
1CCB:    MOV A, #4Ch    ; 74 4C
1CCD:    DB 093h, 0B5h, 049h
1CD0:    NOP
1CD1:    DB 050h, 015h, 030h, 025h, 035h, 020h, 021h, 009h, 0D2h, 021h, 0C2h
1CDC:    RET
1CDD:    MOV A, #4Dh    ; 74 4D
1CDF:    DB 093h, 0F5h, 03Fh, 0E5h, 03Fh, 060h, 025h
1CE6:    SJMP loc_1CEAh    ; relative +2
1CE8:    DB 0C2h, 021h, 030h, 02Ch, 004h
1CED:    MOV A, #6Eh    ; 74 6E
1CEF:    SJMP loc_1CF8h    ; relative +7
1CF1:    MOV A, #49h    ; 74 49
1CF3:    DB 020h, 018h
1CF5:    LJMP 7448h    ; 02 74 48
loc_1CF8h: ; referenced target
1CF8:    DB 093h, 0FAh, 020h, 025h, 004h
1CFD:    MOV A, #4Ah    ; 74 4A
1CFF:    DB 093h, 02Ah, 0C3h, 095h, 013h, 092h, 025h
1D06:    LCALL loc_0B50h   ; 12 0B 50
1D09:    SJMP loc_1D0Dh    ; relative +2
1D0B:    DB 0C2h, 025h
loc_1D0Dh: ; referenced target
1D0D:    LJMP loc_0AFBh    ; 02 0A FB
loc_1D10h: ; referenced target
1D10:    MOV A, #02h    ; 74 02
1D12:    DB 02Ah, 0FAh
1D14:    RET
loc_1D15h: ; referenced target
1D15:    DB 07Ah, 03Eh, 020h, 02Eh, 005h, 030h, 0B4h
1D1C:    LJMP 7A41h    ; 02 7A 41
1D1F:    LJMP loc_0A65h    ; 02 0A 65
1D22:    DB 0FFh
loc_1D23h: ; referenced target
1D23:    MOV DPTR, #112Eh   ; 90 11 2E
1D26:    LCALL loc_05CDh   ; 12 05 CD
1D29:    DB 0C2h, 0E2h, 024h, 01Bh, 093h, 0F5h
1D2F:    MOVX @DPTR, A
1D30:    DB 07Ah, 02Ah
1D32:    LCALL loc_051Dh   ; 12 05 1D
1D35:    DB 0A4h, 0AFh
1D37:    MOVX @DPTR, A
1D38:    DB 0FEh
1D39:    MOV 50h, #02h   ; 75 50 02
1D3C:    DB 030h, 02Fh, 005h
1D3F:    MOV A, #6Bh    ; 74 6B
1D41:    DB 093h, 0B1h
1D43:    MOVX @DPTR, A
1D44:    DB 030h, 01Ah, 062h, 07Ah, 028h
1D49:    MOV A, #1Fh    ; 74 1F
1D4B:    DB 093h, 0B5h, 013h
1D4E:    NOP
1D4F:    DB 050h, 001h, 00Ah
1D52:    LCALL loc_051Dh   ; 12 05 1D
1D55:    DB 0F5h, 03Ch, 07Ah, 053h
1D59:    LCALL loc_051Dh   ; 12 05 1D
1D5C:    DB 0FCh, 07Bh, 005h, 079h, 008h, 020h, 00Ch, 014h
1D64:    LCALL loc_051Dh   ; 12 05 1D
1D67:    DB 0C3h, 095h, 037h, 040h, 007h
1D6C:    MOV A, #1Ah    ; 74 1A
1D6E:    DB 093h, 095h, 04Dh, 050h
1D72:    RET
1D73:    DB 0D2h, 00Ch
1D75:    MOV 4Dh, #00h   ; 75 4D 00
1D78:    DB 07Ah, 055h
1D7A:    LCALL loc_051Dh   ; 12 05 1D
1D7D:    DB 0F5h
1D7E:    MOVX @DPTR, A
1D7F:    LCALL loc_051Dh   ; 12 05 1D
1D82:    DB 0A4h, 0ECh, 020h, 0E7h, 007h, 023h, 0C9h, 023h, 0C9h, 01Bh
1D8C:    SJMP loc_1D84h    ; relative -10
1D8E:    DB 0A4h, 0ACh
1D90:    MOVX @DPTR, A
1D91:    DB 030h, 0E7h, 001h, 00Ch, 0ECh, 0B5h, 001h
1D98:    NOP
1D99:    DB 040h, 00Bh
1D9B:    LCALL loc_04D9h   ; 12 04 D9
1D9E:    DB 0E5h, 050h, 02Bh
1DA1:    LCALL loc_0509h   ; 12 05 09
1DA4:    DB 0F5h, 050h
1DA6:    LJMP loc_1DDDh    ; 02 1D DD
1DA9:    DB 020h, 02Dh, 004h, 0F1h, 0F2h, 0A1h, 0B3h
1DB0:    LCALL loc_1D10h   ; 12 1D 10
1DB3:    LCALL loc_051Dh   ; 12 05 1D
1DB6:    DB 0F5h
1DB7:    MOVX @DPTR, A
1DB8:    DB 07Ah, 02Fh, 030h, 018h, 001h, 00Ah
1DBE:    LCALL loc_051Dh   ; 12 05 1D
1DC1:    DB 0A4h, 0E5h
1DC3:    MOVX @DPTR, A
1DC4:    DB 0B1h, 0E7h, 0E5h, 03Ch, 0B1h, 0E7h, 07Ah, 031h, 020h, 018h, 007h, 07Ah, 04Bh, 020h, 019h
1DD3:    LJMP 7A4Fh    ; 02 7A 4F
1DD6:    DB 0F1h, 0F2h
1DD8:    LCALL loc_051Dh   ; 12 05 1D
1DDB:    DB 0B1h
1DDC:    MOVX @DPTR, A
loc_1DDDh: ; referenced target
1DDD:    LJMP loc_1050h    ; 02 10 50
loc_1DE0h: ; referenced target
1DE0:    DB 08Eh, 04Eh, 08Fh, 04Fh
1DE4:    LJMP loc_1053h    ; 02 10 53
loc_1DE7h: ; referenced target
1DE7:    DB 060h
1DE8:    LCALL 2480h   ; 12 24 80
1DEB:    DB 050h, 003h, 013h, 005h, 050h
1DF0:    LCALL loc_04D9h   ; 12 04 D9
1DF3:    DB 0E5h, 050h, 004h
1DF6:    LCALL loc_0509h   ; 12 05 09
1DF9:    DB 0F5h, 050h
1DFB:    RET
1DFC:    DB 0FFh, 0FFh, 0FFh, 0FFh, 088h
1E01:    MOVX @DPTR, A
1E02:    MOV A0h, #19h   ; 75 A0 19
1E05:    DB 078h, 01Bh, 0B8h, 01Bh, 004h, 0D2h, 0D5h
1E0C:    SJMP loc_1E3Bh    ; relative +45
1E0E:    DB 0E6h, 0F2h
1E10:    MOV A0h, #1Bh   ; 75 A0 1B
1E13:    DB 078h, 031h, 0B8h, 031h, 006h, 0E6h, 024h, 00Ah, 023h
1E1C:    SJMP loc_1E1Fh    ; relative +1
1E1E:    DB 0E6h, 0F2h, 005h, 0A0h, 0E5h, 037h, 0F2h, 005h, 0A0h, 0E5h, 049h, 0F2h, 005h, 0A0h, 0E5h, 010h
1E2E:    DB 0F2h, 005h, 0A0h, 0E5h, 013h, 0F2h
1E34:    SJMP loc_1E50h    ; relative +26
1E36:    MOV A0h, #98h   ; 75 A0 98
1E39:    DB 0C2h, 0D5h
loc_1E3Bh: ; referenced target
1E3B:    MOV A, #60h    ; 74 60
1E3D:    DB 0F4h, 004h, 025h, 01Bh, 023h, 023h, 0F8h, 0E5h, 01Ch, 033h, 033h, 033h, 054h, 003h, 038h, 0F2h
1E4D:    DB 010h, 0D5h, 0C0h, 0A8h
1E51:    MOVX @DPTR, A
1E52:    RET
loc_1E53h: ; referenced target
1E53:    MOV 28h, #80h   ; 75 28 80
1E56:    MOV 26h, #00h   ; 75 26 00
1E59:    MOV 29h, #FFh   ; 75 29 FF
1E5C:    DB 0D2h, 02Bh, 0D2h, 09Bh, 0C2h, 099h
1E62:    MOV 99h, #FFh   ; 75 99 FF
1E65:    DB 030h, 099h, 0FDh, 0C2h, 09Bh, 0C2h, 098h
1E6C:    RET
loc_1E6Dh: ; referenced target
1E6D:    DB 030h, 01Fh, 001h
1E70:    RET
1E71:    DB 030h, 01Eh, 001h
1E74:    RET
1E75:    DB 030h, 02Bh, 025h, 0C2h, 02Bh, 020h, 098h, 003h, 0D2h, 01Fh
1E7F:    RET
1E80:    DB 0E5h, 099h, 0B4h, 0EEh, 00Eh, 0D2h, 01Eh, 0C2h, 099h
1E89:    MOV 99h, #FFh   ; 75 99 FF
1E8C:    DB 030h, 099h, 0FDh
1E8F:    MOV 98h, #B0h   ; 75 98 B0
1E92:    RET
1E93:    DB 0E5h, 099h, 0C3h, 094h, 0FFh, 060h, 016h, 0D2h, 01Fh
1E9C:    RET
1E9D:    DB 030h, 098h, 010h, 0E5h, 029h, 0C3h, 094h, 0FFh, 060h, 009h
1EA7:    MOV DPTR, #11DAh   ; 90 11 DA
1EAA:    DB 0E5h, 029h, 093h, 0F9h, 0A7h, 099h
1EB0:    MOV DPTR, #11D1h   ; 90 11 D1
1EB3:    CLR A
1EB4:    DB 093h
1EB5:    LCALL loc_1EF9h   ; 12 1E F9
1EB8:    INC DPTR
1EB9:    CLR A
1EBA:    DB 093h
1EBB:    LCALL loc_1EF9h   ; 12 1E F9
1EBE:    INC DPTR
1EBF:    CLR A
1EC0:    DB 093h
1EC1:    LCALL loc_1EF9h   ; 12 1E F9
1EC4:    DB 0A9h, 07Ah, 0C2h, 099h, 0E7h, 0F5h, 099h, 030h, 099h, 0FDh, 0D2h, 09Bh, 005h, 029h, 0E5h, 029h
1ED4:    DB 0B4h, 006h, 008h
1ED7:    MOV 29h, #FFh   ; 75 29 FF
1EDA:    MOV A, #FFh    ; 74 FF
1EDC:    LJMP loc_1EEAh    ; 02 1E EA
1EDF:    MOV DPTR, #11D4h   ; 90 11 D4
1EE2:    DB 093h, 0F9h, 0E7h, 0B4h, 0FFh
1EE7:    LJMP 74FEh    ; 02 74 FE
loc_1EEAh: ; referenced target
1EEA:    DB 0C2h, 099h, 0F5h, 099h, 030h, 099h, 0FDh, 0C2h, 09Bh, 0C2h, 098h
1EF5:    MOV DPTR, #1160h   ; 90 11 60
1EF8:    RET
loc_1EF9h: ; referenced target
1EF9:    DB 0B4h, 0FFh, 01Bh, 030h, 01Dh, 004h
1EFF:    CLR A
1F00:    LJMP loc_1F19h    ; 02 1F 19
1F03:    DB 0E5h, 04Bh, 0A2h
1F06:    CLR A
1F07:    DB 054h, 00Fh, 0C4h, 0F5h
1F0B:    MOVX @DPTR, A
1F0C:    DB 0E5h, 04Ah, 054h
1F0F:    MOVX @DPTR, A
1F10:    DB 0C4h, 045h
1F12:    MOVX @DPTR, A
1F13:    DB 013h
1F14:    LJMP loc_1F19h    ; 02 1F 19
1F17:    DB 0F9h, 0E7h, 0C2h, 099h, 0F5h, 099h, 030h, 099h, 0FDh
1F20:    RET
1F21:    DB 020h, 01Fh, 007h, 020h, 01Eh, 004h, 0E5h, 026h, 02Dh, 0FDh, 081h, 08Fh, 020h, 01Fh, 007h, 020h
1F31:    DB 01Eh, 004h, 0E5h, 028h, 0B1h
1F36:    MOVX @DPTR, A
1F37:    LJMP loc_1DE0h    ; 02 1D E0
loc_1F3Ah: ; referenced target
1F3A:    MOV 89h, #11h   ; 75 89 11
1F3D:    MOV B8h, #02h   ; 75 B8 02
1F40:    DB 043h, 0A8h, 085h, 043h, 088h, 005h
1F46:    MOV DPTR, #1160h   ; 90 11 60
1F49:    MOV 81h, #63h   ; 75 81 63
1F4C:    DB 0C2h, 092h
loc_1F4Eh: ; referenced target
1F4E:    MOV A, #0Dh    ; 74 0D
1F50:    DB 093h, 0F5h, 02Ah
1F53:    LCALL loc_063Fh   ; 12 06 3F
1F56:    LCALL loc_101Ah   ; 12 10 1A
1F59:    LCALL loc_1F87h   ; 12 1F 87
1F5C:    LCALL loc_1BC1h   ; 12 1B C1
1F5F:    LCALL loc_1F87h   ; 12 1F 87
1F62:    LCALL loc_1C24h   ; 12 1C 24
1F65:    LCALL loc_101Ah   ; 12 10 1A
1F68:    LCALL loc_1F87h   ; 12 1F 87
1F6B:    LCALL loc_07B7h   ; 12 07 B7
1F6E:    LCALL loc_1F87h   ; 12 1F 87
1F71:    LCALL loc_101Ah   ; 12 10 1A
1F74:    LCALL loc_1D23h   ; 12 1D 23
1F77:    LCALL loc_1F87h   ; 12 1F 87
1F7A:    LJMP loc_101Dh    ; 02 10 1D
loc_1F7Dh: ; referenced target
1F7D:    DB 030h, 01Ch, 0BAh
1F80:    LCALL loc_021Dh   ; 12 02 1D
1F83:    LCALL loc_030Ch   ; 12 03 0C
1F86:    RET
loc_1F87h: ; referenced target
1F87:    DB 010h, 017h, 001h
1F8A:    RET
1F8B:    LJMP loc_02C6h    ; 02 02 C6
loc_1F8Eh: ; referenced target
1F8E:    DB 020h, 01Ah, 050h, 020h, 018h, 04Dh, 0C3h, 0E5h, 010h, 095h, 053h, 040h, 046h, 0F5h, 003h
1F9D:    MOV A, #37h    ; 74 37
1F9F:    DB 093h, 0C3h, 095h, 037h, 050h, 005h
1FA5:    MOV F0h, #00h   ; 75 F0 00
1FA8:    DB 0E1h, 0B7h, 07Ah, 01Ch
1FAC:    LCALL loc_051Dh   ; 12 05 1D
1FAF:    DB 0F5h
1FB0:    MOVX @DPTR, A
1FB1:    DB 0F1h, 0F2h
1FB3:    LCALL loc_051Dh   ; 12 05 1D
1FB6:    DB 0A4h, 020h, 00Fh, 003h, 085h
1FBB:    MOVX @DPTR, A
1FBC:    DB 04Ch, 07Ah, 021h
1FBF:    LCALL loc_051Dh   ; 12 05 1D
1FC2:    DB 060h, 01Dh, 0F5h
1FC5:    MOVX @DPTR, A
1FC6:    DB 0E5h, 04Ch, 060h
1FC9:    LJMP D20Fh    ; 02 D2 0F
1FCC:    DB 0F1h, 0F2h
1FCE:    LCALL loc_051Dh   ; 12 05 1D
1FD1:    DB 0A4h, 07Ah, 026h
1FD4:    LCALL loc_051Dh   ; 12 05 1D
1FD7:    DB 0A4h, 0E5h
1FD9:    MOVX @DPTR, A
1FDA:    DB 0B5h, 03Dh
1FDC:    NOP
1FDD:    DB 040h
1FDE:    LJMP F53Dh    ; 02 F5 3D
1FE1:    DB 085h, 052h, 053h, 085h, 051h, 052h, 085h, 010h, 051h, 0E5h, 03Dh
1FEC:    LCALL loc_1DE7h   ; 12 1D E7
1FEF:    LJMP loc_040Dh    ; 02 04 0D
1FF2:    CLR A
1FF3:    DB 0A2h, 0B4h, 033h, 0A2h, 02Eh, 050h, 003h, 033h, 02Ah, 0FAh
1FFD:    RET
1FFE:    DB 001h, 0EDh