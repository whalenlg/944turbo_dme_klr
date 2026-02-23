Addr    Opcode Instruction                              Cycles

------- ------ ----------------------------------       ------
0x0000: 02 02 4e   ljmp 0x024e                              ?
0x0003: c2 8b      clr 0x88.3 [0x8b]                        ?
0x0005: 21 f0      ajmp 0x01f0                              ?
0x0007: ff         mov R7, A                                ?
0x0008: ff         mov R7, A                                ?
0x0009: ff         mov R7, A                                ?
0x000a: ff         mov R7, A                                ?
0x000b: d2 90      setb 0x90.0 [0x90]                       ?
0x000d: c2 0a      clr 0x21.2 [0x0a]                        ?
0x000f: 32         reti                                     ?
0x0010: ff         mov R7, A                                ?
0x0011: ff         mov R7, A                                ?
0x0012: ff         mov R7, A                                ?
0x0013: 05 36      inc 0x36                                 ?
0x0015: 30 1c 44   jnb 0x23.4 [0x1c], 0x005c                ?
0x0018: 32         reti                                     ?
0x0019: ff         mov R7, A                                ?
0x001a: ff         mov R7, A                                ?
0x001b: d5 2a 13   djnz 0x2a, 0x0031                        ?
0x001e: 11 22      acall 0x0022                             ?
0x0020: 41 4e      ajmp 0x024e                              ?
0x0022: 32         reti                                     ?
0x0023: 10 99 08   jbc 0x98.1 [0x99], 0x002e                ?
0x0026: a8 99      mov R0, 0x99                             ?
0x0028: c2 9b      clr 0x98.3 [0x9b]                        ?
0x002a: 86 99      mov 0x99, @R0                            ?
0x002c: c2 98      clr 0x98.0 [0x98]                        ?
0x002e: c2 89      clr 0x88.1 [0x89]                        ?
0x0030: 32         reti                                     ?
0x0031: 10 94 0e   jbc 0x90.4 [0x94], 0x0042                ?
0x0034: d2 94      setb 0x90.4 [0x94]                       ?
0x0036: 85 41 8d   mov 0x41, 0x8d                           ?
0x0039: 85 40 8b   mov 0x40, 0x8b                           ?
0x003c: 20 1c 02   jb 0x23.4 [0x1c], 0x0041                 ?
0x003f: c2 89      clr 0x88.1 [0x89]                        ?
0x0041: 32         reti                                     ?
0x0042: 85 45 8d   mov 0x45, 0x8d                           ?
0x0045: 85 44 8b   mov 0x44, 0x8b                           ?
0x0048: 85 43 41   mov 0x43, 0x41                           ?
0x004b: 85 42 40   mov 0x42, 0x40                           ?
0x004e: 85 36 37   mov 0x36, 0x37                           ?
0x0051: 75 36 00   mov 0x36, #0x00                          ?
0x0054: d2 17      setb 0x22.7 [0x17]                       ?
0x0056: 20 1c 02   jb 0x23.4 [0x1c], 0x005b                 ?
0x0059: c2 89      clr 0x88.1 [0x89]                        ?
0x005b: 32         reti                                     ?
0x005c: d5 2b 31   djnz 0x2b, 0x0090                        ?
0x005f: d5 2d 03   djnz 0x2d, 0x0065                        ?
0x0062: 12 10 00   lcall 0x1000                             ?
0x0065: 53 a8 ea   anl 0xa8, #0xea                          ?
0x0068: 11 96      acall 0x0096                             ?
0x006a: 30 8b fd   jnb 0x88.3 [0x8b], 0x006a                ?
0x006d: 05 36      inc 0x36                                 ?
0x006f: c2 8b      clr 0x88.3 [0x8b]                        ?
0x0071: d5 2d 03   djnz 0x2d, 0x0077                        ?
0x0074: 12 10 00   lcall 0x1000                             ?
0x0077: 20 10 0d   jb 0x22.0 [0x10], 0x0087                 ?
0x007a: 20 b3 03   jb 0xb0.3 [0xb3], 0x0080                 ?
0x007d: 30 8b fa   jnb 0x88.3 [0x8b], 0x007a                ?
0x0080: b2 91      cpl 0x90.1 [0x91]                        ?
0x0082: 20 8b 07   jb 0x88.3 [0x8b], 0x008c                 ?
0x0085: 01 82      ajmp 0x0082                              ?
0x0087: 30 8b fd   jnb 0x88.3 [0x8b], 0x0087                ?
0x008a: b2 91      cpl 0x90.1 [0x91]                        ?
0x008c: d2 aa      setb 0xa8.2 [0xaa]                       ?
0x008e: 01 97      ajmp 0x0097                              ?
0x0090: d5 2d 03   djnz 0x2d, 0x0096                        ?
0x0093: 12 10 00   lcall 0x1000                             ?
0x0096: 32         reti                                     ?
0x0097: c0 e0      push 0xe0                                ?
0x0099: c0 d0      push 0xd0                                ?
0x009b: 20 91 1a   jb 0x90.1 [0x91], 0x00b8                 ?
0x009e: e4         clr A                                    ?
0x009f: a2 10      mov C, 0x22.0 [0x10]                     ?
0x00a1: 35 30      addc A, 0x30                             ?
0x00a3: 13         rrc A                                    ?
0x00a4: 14         dec A                                    ?
0x00a5: 92 10      mov 0x22.0 [0x10], C                     ?
0x00a7: c2 aa      clr 0xa8.2 [0xaa]                        ?
0x00a9: 25 2b      add A, 0x2b                              ?
0x00ab: f5 2b      mov 0x2b, A                              ?
0x00ad: d2 aa      setb 0xa8.2 [0xaa]                       ?
0x00af: c2 89      clr 0x88.1 [0x89]                        ?
0x00b1: d2 a8      setb 0xa8.0 [0xa8]                       ?
0x00b3: d0 d0      pop 0xd0                                 ?
0x00b5: d0 e0      pop 0xe0                                 ?
0x00b7: 22         ret                                      ?
0x00b8: c0 83      push 0x83                                ?
0x00ba: c0 82      push 0x82                                ?
0x00bc: c0 f0      push 0xf0                                ?
0x00be: 90 11 60   mov DPTR, #0x1160                        ?
0x00c1: e4         clr A                                    ?
0x00c2: a2 10      mov C, 0x22.0 [0x10]                     ?
0x00c4: 35 33      addc A, 0x33                             ?
0x00c6: 95 31      subb A, 0x31                             ?
0x00c8: c3         clr C                                    ?
0x00c9: 95 57      subb A, 0x57                             ?
0x00cb: c3         clr C                                    ?
0x00cc: 95 2f      subb A, 0x2f                             ?
0x00ce: 13         rrc A                                    ?
0x00cf: 14         dec A                                    ?
0x00d0: 92 10      mov 0x22.0 [0x10], C                     ?
0x00d2: c2 aa      clr 0xa8.2 [0xaa]                        ?
0x00d4: 25 2b      add A, 0x2b                              ?
0x00d6: f5 2b      mov 0x2b, A                              ?
0x00d8: d2 aa      setb 0xa8.2 [0xaa]                       ?
0x00da: 74 03      mov A, #0x03                             ?
0x00dc: 25 35      add A, 0x35                              ?
0x00de: 93         movc A, @A+DPTR                          ?
0x00df: c2 aa      clr 0xa8.2 [0xaa]                        ?
0x00e1: 25 2d      add A, 0x2d                              ?
0x00e3: f5 2d      mov 0x2d, A                              ?
0x00e5: d2 aa      setb 0xa8.2 [0xaa]                       ?
0x00e7: 51 1d      acall 0x021d                             ?
0x00e9: c2 89      clr 0x88.1 [0x89]                        ?
0x00eb: d2 a8      setb 0xa8.0 [0xa8]                       ?
0x00ed: 75 d0 18   mov 0xd0, #0x18                          ?
0x00f0: 02 10 29   ljmp 0x1029                              ?
0x00f3: d5 34 36   djnz 0x34, 0x012c                        ?
0x00f6: 7d 2d      mov R5, #0x2d                            ?
0x00f8: 20 16 0c   jb 0x22.6 [0x16], 0x0107                 ?
0x00fb: 7d 2b      mov R5, #0x2b                            ?
0x00fd: 20 15 07   jb 0x22.5 [0x15], 0x0107                 ?
0x0100: 7d 29      mov R5, #0x29                            ?
0x0102: 20 14 02   jb 0x22.4 [0x14], 0x0107                 ?
0x0105: 7d 27      mov R5, #0x27                            ?
0x0107: ed         mov A, R5                                ?
0x0108: 93         movc A, @A+DPTR                          ?
0x0109: f5 34      mov 0x34, A                              ?
0x010b: 0d         inc R5                                   ?
0x010c: ed         mov A, R5                                ?
0x010d: 93         movc A, @A+DPTR                          ?
0x010e: fd         mov R5, A                                ?
0x010f: e5 32      mov A, 0x32                              ?
0x0111: fe         mov R6, A                                ?
0x0112: af 31      mov R7, 0x31                             ?
0x0114: c3         clr C                                    ?
0x0115: 9f         subb A, R7                               ?
0x0116: c3         clr C                                    ?
0x0117: 30 e7 0a   jnb 0xe0.7 [0xe7], 0x0124                ?
0x011a: f4         cpl A                                    ?
0x011b: 04         inc A                                    ?
0x011c: 9d         subb A, R5                               ?
0x011d: ee         mov A, R6                                ?
0x011e: 40 0a      jc 0x012a                                ?
0x0120: ef         mov A, R7                                ?
0x0121: 9d         subb A, R5                               ?
0x0122: 21 2a      ajmp 0x012a                              ?
0x0124: 9d         subb A, R5                               ?
0x0125: ee         mov A, R6                                ?
0x0126: 40 02      jc 0x012a                                ?
0x0128: ef         mov A, R7                                ?
0x0129: 2d         add A, R5                                ?
0x012a: f5 31      mov 0x31, A                              ?
0x012c: 74 01      mov A, #0x01                             ?
0x012e: 93         movc A, @A+DPTR                          ?
0x012f: 05 35      inc 0x35                                 ?
0x0131: b5 35 0f   cjne A, 0x35, 0x0143                     ?
0x0134: 75 35 00   mov 0x35, #0x00                          ?
0x0137: 90 00 00   mov DPTR, #0x0000                        ?
0x013a: f0         movx @DPTR, A                            ?
0x013b: f0         movx @DPTR, A                            ?
0x013c: f0         movx @DPTR, A                            ?
0x013d: f0         movx @DPTR, A                            ?
0x013e: 90 11 60   mov DPTR, #0x1160                        ?
0x0141: 21 66      ajmp 0x0166                              ?
0x0143: 20 1a 20   jb 0x23.2 [0x1a], 0x0166                 ?
0x0146: 10 0f 02   jbc 0x21.7 [0x0f], 0x014b                ?
0x0149: 21 e5      ajmp 0x01e5                              ?
0x014b: 75 f0 40   mov 0xf0, #0x40                          ?
0x014e: e5 4c      mov A, 0x4c                              ?
0x0150: a4         mul AB                                   ?
0x0151: fe         mov R6, A                                ?
0x0152: af f0      mov R7, 0xf0                             ?
0x0154: 30 0a 64   jnb 0x21.2 [0x0a], 0x01bb                ?
0x0157: c2 8c      clr 0x88.4 [0x8c]                        ?
0x0159: c3         clr C                                    ?
0x015a: e5 8a      mov A, 0x8a                              ?
0x015c: 9e         subb A, R6                               ?
0x015d: f5 8a      mov 0x8a, A                              ?
0x015f: e5 8c      mov A, 0x8c                              ?
0x0161: 9f         subb A, R7                               ?
0x0162: f5 8c      mov 0x8c, A                              ?
0x0164: 21 d0      ajmp 0x01d0                              ?
0x0166: c3         clr C                                    ?
0x0167: 74 11      mov A, #0x11                             ?
0x0169: 93         movc A, @A+DPTR                          ?
0x016a: 95 37      subb A, 0x37                             ?
0x016c: 72 1d      orl C, 0x23.5 [0x1d]                     ?
0x016e: 40 6e      jc 0x01de                                ?
0x0170: ae 4a      mov R6, 0x4a                             ?
0x0172: af 4b      mov R7, 0x4b                             ?
0x0174: 02 10 2c   ljmp 0x102c                              ?
0x0177: 20 1a 41   jb 0x23.2 [0x1a], 0x01bb                 ?
0x017a: 30 0d 2d   jnb 0x21.5 [0x0d], 0x01aa                ?
0x017d: e5 4d      mov A, 0x4d                              ?
0x017f: b4 10 00   cjne A, #0x10, 0x0182                    ?
0x0182: 40 0c      jc 0x0190                                ?
0x0184: c2 0d      clr 0x21.5 [0x0d]                        ?
0x0186: 30 16 05   jnb 0x22.6 [0x16], 0x018e                ?
0x0189: c2 16      clr 0x22.6 [0x16]                        ?
0x018b: 75 34 01   mov 0x34, #0x01                          ?
0x018e: 21 aa      ajmp 0x01aa                              ?
0x0190: 90 11 40   mov DPTR, #0x1140                        ?
0x0193: 20 0e 02   jb 0x21.6 [0x0e], 0x0198                 ?
0x0196: 24 10      add A, #0x10                             ?
0x0198: 93         movc A, @A+DPTR                          ?
0x0199: b4 40 08   cjne A, #0x40, 0x01a4                    ?
0x019c: 30 16 05   jnb 0x22.6 [0x16], 0x01a4                ?
0x019f: c2 16      clr 0x22.6 [0x16]                        ?
0x01a1: 75 34 01   mov 0x34, #0x01                          ?
0x01a4: 91 d9      acall 0x04d9                             ?
0x01a6: 74 02      mov A, #0x02                             ?
0x01a8: b1 09      acall 0x0509                             ?
0x01aa: 30 0f 0e   jnb 0x21.7 [0x0f], 0x01bb                ?
0x01ad: c2 0f      clr 0x21.7 [0x0f]                        ?
0x01af: 75 f0 40   mov 0xf0, #0x40                          ?
0x01b2: e5 4c      mov A, 0x4c                              ?
0x01b4: a4         mul AB                                   ?
0x01b5: 2e         add A, R6                                ?
0x01b6: fe         mov R6, A                                ?
0x01b7: e5 f0      mov A, 0xf0                              ?
0x01b9: 3f         addc A, R7                               ?
0x01ba: ff         mov R7, A                                ?
0x01bb: 02 10 2f   ljmp 0x102f                              ?
0x01be: e5 54      mov A, 0x54                              ?
0x01c0: 75 f0 05   mov 0xf0, #0x05                          ?
0x01c3: a4         mul AB                                   ?
0x01c4: c2 8c      clr 0x88.4 [0x8c]                        ?
0x01c6: 2e         add A, R6                                ?
0x01c7: f4         cpl A                                    ?
0x01c8: f5 8a      mov 0x8a, A                              ?
0x01ca: e5 f0      mov A, 0xf0                              ?
0x01cc: 3f         addc A, R7                               ?
0x01cd: f4         cpl A                                    ?
0x01ce: f5 8c      mov 0x8c, A                              ?
0x01d0: c2 af      clr 0xa8.7 [0xaf]                        ?
0x01d2: c2 90      clr 0x90.0 [0x90]                        ?
0x01d4: d2 0a      setb 0x21.2 [0x0a]                       ?
0x01d6: d2 8c      setb 0x88.4 [0x8c]                       ?
0x01d8: d2 a9      setb 0xa8.1 [0xa9]                       ?
0x01da: c2 89      clr 0x88.1 [0x89]                        ?
0x01dc: d2 af      setb 0xa8.7 [0xaf]                       ?
0x01de: e5 4d      mov A, 0x4d                              ?
0x01e0: 20 e7 02   jb 0xe0.7 [0xe7], 0x01e5                 ?
0x01e3: 05 4d      inc 0x4d                                 ?
0x01e5: d0 f0      pop 0xf0                                 ?
0x01e7: d0 82      pop 0x82                                 ?
0x01e9: d0 83      pop 0x83                                 ?
0x01eb: d0 d0      pop 0xd0                                 ?
0x01ed: d0 e0      pop 0xe0                                 ?
0x01ef: 22         ret                                      ?
0x01f0: c0 d0      push 0xd0                                ?
0x01f2: a2 b3      mov C, 0xb0.3 [0xb3]                     ?
0x01f4: 72 8b      orl C, 0x88.3 [0x8b]                     ?
0x01f6: 85 2c 2b   mov 0x2c, 0x2b                           ?
0x01f9: 85 2e 2d   mov 0x2e, 0x2d                           ?
0x01fc: 40 04      jc 0x0202                                ?
0x01fe: a2 11      mov C, 0x22.1 [0x11]                     ?
0x0200: 41 08      ajmp 0x0208                              ?
0x0202: b0 11      anl C, /0x22.1 [0x11]                    ?
0x0204: 40 02      jc 0x0208                                ?
0x0206: 05 2b      inc 0x2b                                 ?
0x0208: 92 10      mov 0x22.0 [0x10], C                     ?
0x020a: d5 2b 06   djnz 0x2b, 0x0213                        ?
0x020d: 05 2b      inc 0x2b                                 ?
0x020f: 15 30      dec 0x30                                 ?
0x0211: 15 30      dec 0x30                                 ?
0x0213: 75 35 00   mov 0x35, #0x00                          ?
0x0216: a2 13      mov C, 0x22.3 [0x13]                     ?
0x0218: 92 91      mov 0x90.1 [0x91], C                     ?
0x021a: d0 d0      pop 0xd0                                 ?
0x021c: 32         reti                                     ?
0x021d: 74 02      mov A, #0x02                             ?
0x021f: 93         movc A, @A+DPTR                          ?
0x0220: f5 2e      mov 0x2e, A                              ?
0x0222: d2 13      setb 0x22.3 [0x13]                       ?
0x0224: 74 00      mov A, #0x00                             ?
0x0226: 93         movc A, @A+DPTR                          ?
0x0227: d3         setb C                                   ?
0x0228: 95 31      subb A, 0x31                             ?
0x022a: c3         clr C                                    ?
0x022b: 95 57      subb A, 0x57                             ?
0x022d: c3         clr C                                    ?
0x022e: 95 2f      subb A, 0x2f                             ?
0x0230: 50 05      jnc 0x0237                               ?
0x0232: c3         clr C                                    ?
0x0233: c2 13      clr 0x22.3 [0x13]                        ?
0x0235: 35 2f      addc A, 0x2f                             ?
0x0237: c3         clr C                                    ?
0x0238: 13         rrc A                                    ?
0x0239: 60 f8      jz 0x0233                                ?
0x023b: f5 2c      mov 0x2c, A                              ?
0x023d: 92 11      mov 0x22.1 [0x11], C                     ?
0x023f: 74 07      mov A, #0x07                             ?
0x0241: 25 35      add A, 0x35                              ?
0x0243: 93         movc A, @A+DPTR                          ?
0x0244: 25 31      add A, 0x31                              ?
0x0246: 25 57      add A, 0x57                              ?
0x0248: f5 33      mov 0x33, A                              ?
0x024a: 85 2f 30   mov 0x2f, 0x30                           ?
0x024d: 22         ret                                      ?
0x024e: 75 a8 80   mov 0xa8, #0x80                          ?
0x0251: 75 90 ff   mov 0x90, #0xff                          ?
0x0254: 75 b0 ff   mov 0xb0, #0xff                          ?
0x0257: 75 89 11   mov 0x89, #0x11                          ?
0x025a: 75 b8 02   mov 0xb8, #0x02                          ?
0x025d: 75 88 05   mov 0x88, #0x05                          ?
0x0260: 75 98 90   mov 0x98, #0x90                          ?
0x0263: 75 81 63   mov 0x81, #0x63                          ?
0x0266: 90 11 60   mov DPTR, #0x1160                        ?
0x0269: 75 d0 00   mov 0xd0, #0x00                          ?
0x026c: 78 64      mov R0, #0x64                            ?
0x026e: e4         clr A                                    ?
0x026f: 02 10 0b   ljmp 0x100b                              ?
0x0272: f6         mov @R0, A                               ?
0x0273: d8 fd      djnz R0, 0x0272                          ?
0x0275: 02 10 0e   ljmp 0x100e                              ?
0x0278: d2 1c      setb 0x23.4 [0x1c]                       ?
0x027a: 78 00      mov R0, #0x00                            ?
0x027c: 79 40      mov R1, #0x40                            ?
0x027e: 12 0a 05   lcall 0x0a05                             ?
0x0281: d2 8e      setb 0x88.6 [0x8e]                       ?
0x0283: d2 ab      setb 0xa8.3 [0xab]                       ?
0x0285: d2 aa      setb 0xa8.2 [0xaa]                       ?
0x0287: d2 8f      setb 0x88.7 [0x8f]                       ?
0x0289: 30 17 fd   jnb 0x22.7 [0x17], 0x0289                ?
0x028c: c2 17      clr 0x22.7 [0x17]                        ?
0x028e: 30 17 fd   jnb 0x22.7 [0x17], 0x028e                ?
0x0291: d2 1a      setb 0x23.2 [0x1a]                       ?
0x0293: 12 10 05   lcall 0x1005                             ?
0x0296: 74 0e      mov A, #0x0e                             ?
0x0298: 93         movc A, @A+DPTR                          ?
0x0299: f8         mov R0, A                                ?
0x029a: 51 bf      acall 0x02bf                             ?
0x029c: d8 fc      djnz R0, 0x029a                          ?
0x029e: 02 10 17   ljmp 0x1017                              ?
0x02a1: c2 89      clr 0x88.1 [0x89]                        ?
0x02a3: 75 a0 00   mov 0xa0, #0x00                          ?
0x02a6: f2         movx @R0, A                              ?
0x02a7: f2         movx @R0, A                              ?
0x02a8: f2         movx @R0, A                              ?
0x02a9: f2         movx @R0, A                              ?
0x02aa: 74 0d      mov A, #0x0d                             ?
0x02ac: 93         movc A, @A+DPTR                          ?
0x02ad: f5 2a      mov 0x2a, A                              ?
0x02af: 30 17 03   jnb 0x22.7 [0x17], 0x02b5                ?
0x02b2: c2 17      clr 0x22.7 [0x17]                        ?
0x02b4: f2         movx @R0, A                              ?
0x02b5: 30 89 f5   jnb 0x88.1 [0x89], 0x02ad                ?
0x02b8: d2 a8      setb 0xa8.0 [0xa8]                       ?
0x02ba: c2 1c      clr 0x23.4 [0x1c]                        ?
0x02bc: 02 10 08   ljmp 0x1008                              ?
0x02bf: 30 b3 fd   jnb 0xb0.3 [0xb3], 0x02bf                ?
0x02c2: 20 b3 fd   jb 0xb0.3 [0xb3], 0x02c2                 ?
0x02c5: 22         ret                                      ?
0x02c6: 75 a0 00   mov 0xa0, #0x00                          ?
0x02c9: e2         movx A, @R0                              ?
0x02ca: 7a 32      mov R2, #0x32                            ?
0x02cc: 78 10      mov R0, #0x10                            ?
0x02ce: 7b 08      mov R3, #0x08                            ?
0x02d0: e2         movx A, @R0                              ?
0x02d1: da fe      djnz R2, 0x02d1                          ?
0x02d3: 05 a0      inc 0xa0                                 ?
0x02d5: e2         movx A, @R0                              ?
0x02d6: f6         mov @R0, A                               ?
0x02d7: 08         inc R0                                   ?
0x02d8: 7a 32      mov R2, #0x32                            ?
0x02da: e2         movx A, @R0                              ?
0x02db: db f4      djnz R3, 0x02d1                          ?
0x02dd: e5 12      mov A, 0x12                              ?
0x02df: f4         cpl A                                    ?
0x02e0: fc         mov R4, A                                ?
0x02e1: 7a 01      mov R2, #0x01                            ?
0x02e3: b1 1d      acall 0x051d                             ?
0x02e5: f5 12      mov 0x12, A                              ?
0x02e7: e5 13      mov A, 0x13                              ?
0x02e9: f4         cpl A                                    ?
0x02ea: fc         mov R4, A                                ?
0x02eb: b1 1d      acall 0x051d                             ?
0x02ed: f5 13      mov 0x13, A                              ?
0x02ef: 78 38      mov R0, #0x38                            ?
0x02f1: 79 3c      mov R1, #0x3c                            ?
0x02f3: 7a 04      mov R2, #0x04                            ?
0x02f5: 7b 33      mov R3, #0x33                            ?
0x02f7: 20 1c 05   jb 0x23.4 [0x1c], 0x02ff                 ?
0x02fa: e6         mov A, @R0                               ?
0x02fb: 14         dec A                                    ?
0x02fc: f6         mov @R0, A                               ?
0x02fd: 70 08      jnz 0x0307                               ?
0x02ff: eb         mov A, R3                                ?
0x0300: 93         movc A, @A+DPTR                          ?
0x0301: f6         mov @R0, A                               ?
0x0302: e7         mov A, @R1                               ?
0x0303: 60 02      jz 0x0307                                ?
0x0305: 14         dec A                                    ?
0x0306: f7         mov @R1, A                               ?
0x0307: 08         inc R0                                   ?
0x0308: 09         inc R1                                   ?
0x0309: 0b         inc R3                                   ?
0x030a: da eb      djnz R2, 0x02f7                          ?
0x030c: 74 18      mov A, #0x18                             ?
0x030e: 93         movc A, @A+DPTR                          ?
0x030f: b5 37 00   cjne A, 0x37, 0x0312                     ?
0x0312: 40 64      jc 0x0378                                ?
0x0314: 20 1c 61   jb 0x23.4 [0x1c], 0x0378                 ?
0x0317: ad 55      mov R5, 0x55                             ?
0x0319: e5 37      mov A, 0x37                              ?
0x031b: c3         clr C                                    ?
0x031c: 9d         subb A, R5                               ?
0x031d: 92 d5      mov 0xd0.5 [0xd5], C                     ?
0x031f: 50 02      jnc 0x0323                               ?
0x0321: f4         cpl A                                    ?
0x0322: 04         inc A                                    ?
0x0323: c5 f0      xch A, 0xf0                              ?
0x0325: 74 15      mov A, #0x15                             ?
0x0327: 93         movc A, @A+DPTR                          ?
0x0328: a4         mul AB                                   ?
0x0329: fe         mov R6, A                                ?
0x032a: 20 e7 04   jb 0xe0.7 [0xe7], 0x0331                 ?
0x032d: c5 f0      xch A, 0xf0                              ?
0x032f: 60 02      jz 0x0333                                ?
0x0331: 7e 7f      mov R6, #0x7f                            ?
0x0333: e5 56      mov A, 0x56                              ?
0x0335: 30 d5 0f   jnb 0xd0.5 [0xd5], 0x0347                ?
0x0338: c3         clr C                                    ?
0x0339: 9e         subb A, R6                               ?
0x033a: 50 17      jnc 0x0353                               ?
0x033c: 24 80      add A, #0x80                             ?
0x033e: bd 00 02   cjne R5, #0x00, 0x0343                   ?
0x0341: 80 10      sjmp 0x0353                              ?
0x0343: 15 55      dec 0x55                                 ?
0x0345: 80 0c      sjmp 0x0353                              ?
0x0347: 2e         add A, R6                                ?
0x0348: 50 09      jnc 0x0353                               ?
0x034a: 24 80      add A, #0x80                             ?
0x034c: bd ff 02   cjne R5, #0xff, 0x0351                   ?
0x034f: 80 02      sjmp 0x0353                              ?
0x0351: 05 55      inc 0x55                                 ?
0x0353: f5 56      mov 0x56, A                              ?
0x0355: 74 19      mov A, #0x19                             ?
0x0357: 93         movc A, @A+DPTR                          ?
0x0358: b5 49 00   cjne A, 0x49, 0x035b                     ?
0x035b: 74 00      mov A, #0x00                             ?
0x035d: 40 15      jc 0x0374                                ?
0x035f: e5 55      mov A, 0x55                              ?
0x0361: b5 37 02   cjne A, 0x37, 0x0366                     ?
0x0364: 80 07      sjmp 0x036d                              ?
0x0366: 40 09      jc 0x0371                                ?
0x0368: 74 16      mov A, #0x16                             ?
0x036a: 93         movc A, @A+DPTR                          ?
0x036b: 80 07      sjmp 0x0374                              ?
0x036d: 74 00      mov A, #0x00                             ?
0x036f: 80 03      sjmp 0x0374                              ?
0x0371: 74 17      mov A, #0x17                             ?
0x0373: 93         movc A, @A+DPTR                          ?
0x0374: f5 57      mov 0x57, A                              ?
0x0376: 80 09      sjmp 0x0381                              ?
0x0378: 85 37 55   mov 0x37, 0x55                           ?
0x037b: 75 56 80   mov 0x56, #0x80                          ?
0x037e: 75 57 00   mov 0x57, #0x00                          ?
0x0381: 30 1a 23   jnb 0x23.2 [0x1a], 0x03a7                ?
0x0384: 7d 00      mov R5, #0x00                            ?
0x0386: 74 12      mov A, #0x12                             ?
0x0388: 93         movc A, @A+DPTR                          ?
0x0389: f5 49      mov 0x49, A                              ?
0x038b: 75 f0 19   mov 0xf0, #0x19                          ?
0x038e: a4         mul AB                                   ?
0x038f: fe         mov R6, A                                ?
0x0390: af f0      mov R7, 0xf0                             ?
0x0392: 74 01      mov A, #0x01                             ?
0x0394: 93         movc A, @A+DPTR                          ?
0x0395: 85 49 f0   mov 0x49, 0xf0                           ?
0x0398: a4         mul AB                                   ?
0x0399: 75 f0 19   mov 0xf0, #0x19                          ?
0x039c: a4         mul AB                                   ?
0x039d: 85 f0 46   mov 0xf0, 0x46                           ?
0x03a0: f5 47      mov 0x47, A                              ?
0x03a2: 75 48 00   mov 0x48, #0x00                          ?
0x03a5: 81 05      ajmp 0x0405                              ?
0x03a7: ab 37      mov R3, 0x37                             ?
0x03a9: 74 32      mov A, #0x32                             ?
0x03ab: 8b f0      mov 0xf0, R3                             ?
0x03ad: 84         div AB                                   ?
0x03ae: ff         mov R7, A                                ?
0x03af: 91 ea      acall 0x04ea                             ?
0x03b1: fe         mov R6, A                                ?
0x03b2: e5 10      mov A, 0x10                              ?
0x03b4: 75 f0 20   mov 0xf0, #0x20                          ?
0x03b7: 84         div AB                                   ?
0x03b8: fa         mov R2, A                                ?
0x03b9: ab f0      mov R3, 0xf0                             ?
0x03bb: 90 10 f4   mov DPTR, #0x10f4                        ?
0x03be: 93         movc A, @A+DPTR                          ?
0x03bf: 91 d9      acall 0x04d9                             ?
0x03c1: 90 10 fc   mov DPTR, #0x10fc                        ?
0x03c4: ea         mov A, R2                                ?
0x03c5: 93         movc A, @A+DPTR                          ?
0x03c6: b1 09      acall 0x0509                             ?
0x03c8: 90 11 04   mov DPTR, #0x1104                        ?
0x03cb: eb         mov A, R3                                ?
0x03cc: 93         movc A, @A+DPTR                          ?
0x03cd: 91 d9      acall 0x04d9                             ?
0x03cf: 90 11 60   mov DPTR, #0x1160                        ?
0x03d2: 74 13      mov A, #0x13                             ?
0x03d4: 91 3d      acall 0x043d                             ?
0x03d6: 74 14      mov A, #0x14                             ?
0x03d8: 91 3f      acall 0x043f                             ?
0x03da: ee         mov A, R6                                ?
0x03db: fb         mov R3, A                                ?
0x03dc: ef         mov A, R7                                ?
0x03dd: fc         mov R4, A                                ?
0x03de: 7a 1b      mov R2, #0x1b                            ?
0x03e0: 12 05 1d   lcall 0x051d                             ?
0x03e3: fd         mov R5, A                                ?
0x03e4: aa 46      mov R2, 0x46                             ?
0x03e6: a9 47      mov R1, 0x47                             ?
0x03e8: a8 48      mov R0, 0x48                             ?
0x03ea: 12 05 fa   lcall 0x05fa                             ?
0x03ed: 8a 46      mov 0x46, R2                             ?
0x03ef: 89 47      mov 0x47, R1                             ?
0x03f1: 88 48      mov 0x48, R0                             ?
0x03f3: af 46      mov R7, 0x46                             ?
0x03f5: ae 47      mov R6, 0x47                             ?
0x03f7: 74 a4      mov A, #0xa4                             ?
0x03f9: 91 d9      acall 0x04d9                             ?
0x03fb: 74 04      mov A, #0x04                             ?
0x03fd: b1 09      acall 0x0509                             ?
0x03ff: 8f 49      mov 0x49, R7                             ?
0x0401: af 46      mov R7, 0x46                             ?
0x0403: ae 47      mov R6, 0x47                             ?
0x0405: 02 10 32   ljmp 0x1032                              ?
0x0408: c0 50      push 0x50                                ?
0x040a: 02 10 35   ljmp 0x1035                              ?
0x040d: a8 4e      mov R0, 0x4e                             ?
0x040f: a9 4f      mov R1, 0x4f                             ?
0x0411: 91 55      acall 0x0455                             ?
0x0413: e5 50      mov A, 0x50                              ?
0x0415: b1 09      acall 0x0509                             ?
0x0417: d0 50      pop 0x50                                 ?
0x0419: 12 10 38   lcall 0x1038                             ?
0x041c: 7a 1a      mov R2, #0x1a                            ?
0x041e: b1 1d      acall 0x051d                             ?
0x0420: f5 54      mov 0x54, A                              ?
0x0422: c2 af      clr 0xa8.7 [0xaf]                        ?
0x0424: 8f 4b      mov 0x4b, R7                             ?
0x0426: 8e 4a      mov 0x4a, R6                             ?
0x0428: c2 89      clr 0x88.1 [0x89]                        ?
0x042a: d2 af      setb 0xa8.7 [0xaf]                       ?
0x042c: 12 10 3b   lcall 0x103b                             ?
0x042f: 30 1e 08   jnb 0x23.6 [0x1e], 0x043a                ?
0x0432: 79 50      mov R1, #0x50                            ?
0x0434: d2 ac      setb 0xa8.4 [0xac]                       ?
0x0436: d9 fc      djnz R1, 0x0434                          ?
0x0438: c2 ac      clr 0xa8.4 [0xac]                        ?
0x043a: 02 10 3e   ljmp 0x103e                              ?
0x043d: d2 d5      setb 0xd0.5 [0xd5]                       ?
0x043f: 93         movc A, @A+DPTR                          ?
0x0440: 75 f0 19   mov 0xf0, #0x19                          ?
0x0443: a4         mul AB                                   ?
0x0444: fb         mov R3, A                                ?
0x0445: 9e         subb A, R6                               ?
0x0446: e5 f0      mov A, 0xf0                              ?
0x0448: 9f         subb A, R7                               ?
0x0449: 10 d5 01   jbc 0xd0.5 [0xd5], 0x044d                ?
0x044c: b3         cpl C                                    ?
0x044d: 50 05      jnc 0x0454                               ?
0x044f: eb         mov A, R3                                ?
0x0450: fe         mov R6, A                                ?
0x0451: e5 f0      mov A, 0xf0                              ?
0x0453: ff         mov R7, A                                ?
0x0454: 22         ret                                      ?
0x0455: e8         mov A, R0                                ?
0x0456: 8e f0      mov 0xf0, R6                             ?
0x0458: a4         mul AB                                   ?
0x0459: ad f0      mov R5, 0xf0                             ?
0x045b: e9         mov A, R1                                ?
0x045c: 8e f0      mov 0xf0, R6                             ?
0x045e: a4         mul AB                                   ?
0x045f: 2d         add A, R5                                ?
0x0460: fd         mov R5, A                                ?
0x0461: e4         clr A                                    ?
0x0462: 35 f0      addc A, 0xf0                             ?
0x0464: fe         mov R6, A                                ?
0x0465: e8         mov A, R0                                ?
0x0466: 8f f0      mov 0xf0, R7                             ?
0x0468: a4         mul AB                                   ?
0x0469: 2d         add A, R5                                ?
0x046a: fd         mov R5, A                                ?
0x046b: ee         mov A, R6                                ?
0x046c: 35 f0      addc A, 0xf0                             ?
0x046e: fe         mov R6, A                                ?
0x046f: e4         clr A                                    ?
0x0470: 33         rlc A                                    ?
0x0471: cf         xch A, R7                                ?
0x0472: f5 f0      mov 0xf0, A                              ?
0x0474: e9         mov A, R1                                ?
0x0475: a4         mul AB                                   ?
0x0476: 2e         add A, R6                                ?
0x0477: fe         mov R6, A                                ?
0x0478: ef         mov A, R7                                ?
0x0479: 35 f0      addc A, 0xf0                             ?
0x047b: ff         mov R7, A                                ?
0x047c: 22         ret                                      ?
0x047d: 20 1a 49   jb 0x23.2 [0x1a], 0x04c9                 ?
0x0480: 20 18 46   jb 0x23.0 [0x18], 0x04c9                 ?
0x0483: c3         clr C                                    ?
0x0484: e5 10      mov A, 0x10                              ?
0x0486: 95 53      subb A, 0x53                             ?
0x0488: 40 3f      jc 0x04c9                                ?
0x048a: f5 03      mov 0x03, A                              ?
0x048c: 74 37      mov A, #0x37                             ?
0x048e: 93         movc A, @A+DPTR                          ?
0x048f: c3         clr C                                    ?
0x0490: 95 37      subb A, 0x37                             ?
0x0492: 50 05      jnc 0x0499                               ?
0x0494: 75 f0 00   mov 0xf0, #0x00                          ?
0x0497: 81 a4      ajmp 0x04a4                              ?
0x0499: 7a 1c      mov R2, #0x1c                            ?
0x049b: 12 05 1d   lcall 0x051d                             ?
0x049e: f5 f0      mov 0xf0, A                              ?
0x04a0: 12 05 1d   lcall 0x051d                             ?
0x04a3: a4         mul AB                                   ?
0x04a4: 20 0f 03   jb 0x21.7 [0x0f], 0x04aa                 ?
0x04a7: 85 f0 4c   mov 0xf0, 0x4c                           ?
0x04aa: 7a 1e      mov R2, #0x1e                            ?
0x04ac: 12 05 1d   lcall 0x051d                             ?
0x04af: 60 18      jz 0x04c9                                ?
0x04b1: f5 f0      mov 0xf0, A                              ?
0x04b3: e5 4c      mov A, 0x4c                              ?
0x04b5: 60 02      jz 0x04b9                                ?
0x04b7: d2 0f      setb 0x21.7 [0x0f]                       ?
0x04b9: 12 05 1d   lcall 0x051d                             ?
0x04bc: a4         mul AB                                   ?
0x04bd: b1 1d      acall 0x051d                             ?
0x04bf: a4         mul AB                                   ?
0x04c0: e5 f0      mov A, 0xf0                              ?
0x04c2: b5 3d 00   cjne A, 0x3d, 0x04c5                     ?
0x04c5: 40 02      jc 0x04c9                                ?
0x04c7: f5 3d      mov 0x3d, A                              ?
0x04c9: 85 52 53   mov 0x52, 0x53                           ?
0x04cc: 85 51 52   mov 0x51, 0x52                           ?
0x04cf: 85 10 51   mov 0x10, 0x51                           ?
0x04d2: e5 3d      mov A, 0x3d                              ?
0x04d4: 12 08 7d   lcall 0x087d                             ?
0x04d7: 81 0d      ajmp 0x040d                              ?
0x04d9: fd         mov R5, A                                ?
0x04da: 8e f0      mov 0xf0, R6                             ?
0x04dc: a4         mul AB                                   ?
0x04dd: ae f0      mov R6, 0xf0                             ?
0x04df: cd         xch A, R5                                ?
0x04e0: 8f f0      mov 0xf0, R7                             ?
0x04e2: a4         mul AB                                   ?
0x04e3: 2e         add A, R6                                ?
0x04e4: fe         mov R6, A                                ?
0x04e5: e4         clr A                                    ?
0x04e6: 35 f0      addc A, 0xf0                             ?
0x04e8: ff         mov R7, A                                ?
0x04e9: 22         ret                                      ?
0x04ea: e4         clr A                                    ?
0x04eb: 7c 08      mov R4, #0x08                            ?
0x04ed: c3         clr C                                    ?
0x04ee: 33         rlc A                                    ?
0x04ef: c5 f0      xch A, 0xf0                              ?
0x04f1: 33         rlc A                                    ?
0x04f2: 10 d7 0b   jbc 0xd0.7 [0xd7], 0x0500                ?
0x04f5: 9b         subb A, R3                               ?
0x04f6: 50 01      jnc 0x04f9                               ?
0x04f8: 2b         add A, R3                                ?
0x04f9: c5 f0      xch A, 0xf0                              ?
0x04fb: dc f1      djnz R4, 0x04ee                          ?
0x04fd: 33         rlc A                                    ?
0x04fe: f4         cpl A                                    ?
0x04ff: 22         ret                                      ?
0x0500: 9b         subb A, R3                               ?
0x0501: c3         clr C                                    ?
0x0502: c5 f0      xch A, 0xf0                              ?
0x0504: dc e8      djnz R4, 0x04ee                          ?
0x0506: 33         rlc A                                    ?
0x0507: f4         cpl A                                    ?
0x0508: 22         ret                                      ?
0x0509: 60 05      jz 0x0510                                ?
0x050b: cf         xch A, R7                                ?
0x050c: 30 e7 02   jnb 0xe0.7 [0xe7], 0x0511                ?
0x050f: cf         xch A, R7                                ?
0x0510: 22         ret                                      ?
0x0511: c3         clr C                                    ?
0x0512: cd         xch A, R5                                ?
0x0513: 33         rlc A                                    ?
0x0514: cd         xch A, R5                                ?
0x0515: ce         xch A, R6                                ?
0x0516: 33         rlc A                                    ?
0x0517: ce         xch A, R6                                ?
0x0518: 33         rlc A                                    ?
0x0519: cf         xch A, R7                                ?
0x051a: 14         dec A                                    ?
0x051b: a1 09      ajmp 0x0509                              ?
0x051d: c0 f0      push 0xf0                                ?
0x051f: 90 10 90   mov DPTR, #0x1090                        ?
0x0522: ea         mov A, R2                                ?
0x0523: 0a         inc R2                                   ?
0x0524: d2 d3      setb 0xd0.3 [0xd3]                       ?
0x0526: 93         movc A, @A+DPTR                          ?
0x0527: b4 ff 04   cjne A, #0xff, 0x052e                    ?
0x052a: d2 2a      setb 0x25.2 [0x2a]                       ?
0x052c: a1 70      ajmp 0x0570                              ?
0x052e: c2 2a      clr 0x25.2 [0x2a]                        ?
0x0530: a2 e0      mov C, 0xe0.0 [0xe0]                     ?
0x0532: c2 e0      clr 0xe0.0 [0xe0]                        ?
0x0534: 90 11 e0   mov DPTR, #0x11e0                        ?
0x0537: ff         mov R7, A                                ?
0x0538: 0f         inc R7                                   ?
0x0539: 93         movc A, @A+DPTR                          ?
0x053a: cf         xch A, R7                                ?
0x053b: 93         movc A, @A+DPTR                          ?
0x053c: f5 82      mov 0x82, A                              ?
0x053e: 8f 83      mov 0x83, R7                             ?
0x0540: 40 06      jc 0x0548                                ?
0x0542: b1 78      acall 0x0578                             ?
0x0544: b1 a1      acall 0x05a1                             ?
0x0546: a1 70      ajmp 0x0570                              ?
0x0548: b1 78      acall 0x0578                             ?
0x054a: 89 f0      mov 0xf0, R1                             ?
0x054c: e8         mov A, R0                                ?
0x054d: fe         mov R6, A                                ?
0x054e: eb         mov A, R3                                ?
0x054f: ff         mov R7, A                                ?
0x0550: b1 78      acall 0x0578                             ?
0x0552: ea         mov A, R2                                ?
0x0553: a4         mul AB                                   ?
0x0554: 29         add A, R1                                ?
0x0555: f9         mov R1, A                                ?
0x0556: ef         mov A, R7                                ?
0x0557: 60 02      jz 0x055b                                ?
0x0559: b1 a1      acall 0x05a1                             ?
0x055b: ca         xch A, R2                                ?
0x055c: f4         cpl A                                    ?
0x055d: 04         inc A                                    ?
0x055e: 29         add A, R1                                ?
0x055f: f9         mov R1, A                                ?
0x0560: b1 a1      acall 0x05a1                             ?
0x0562: cf         xch A, R7                                ?
0x0563: 70 03      jnz 0x0568                               ?
0x0565: cf         xch A, R7                                ?
0x0566: a1 70      ajmp 0x0570                              ?
0x0568: fb         mov R3, A                                ?
0x0569: 8e f0      mov 0xf0, R6                             ?
0x056b: cf         xch A, R7                                ?
0x056c: fd         mov R5, A                                ?
0x056d: ea         mov A, R2                                ?
0x056e: b1 b0      acall 0x05b0                             ?
0x0570: c2 d3      clr 0xd0.3 [0xd3]                        ?
0x0572: d0 f0      pop 0xf0                                 ?
0x0574: 90 11 60   mov DPTR, #0x1160                        ?
0x0577: 22         ret                                      ?
0x0578: e4         clr A                                    ?
0x0579: 93         movc A, @A+DPTR                          ?
0x057a: f8         mov R0, A                                ?
0x057b: a3         inc DPTR                                 ?
0x057c: e4         clr A                                    ?
0x057d: 93         movc A, @A+DPTR                          ?
0x057e: fa         mov R2, A                                ?
0x057f: f9         mov R1, A                                ?
0x0580: e6         mov A, @R0                               ?
0x0581: f8         mov R0, A                                ?
0x0582: e9         mov A, R1                                ?
0x0583: 93         movc A, @A+DPTR                          ?
0x0584: 28         add A, R0                                ?
0x0585: f8         mov R0, A                                ?
0x0586: 40 06      jc 0x058e                                ?
0x0588: d9 f8      djnz R1, 0x0582                          ?
0x058a: 09         inc R1                                   ?
0x058b: e4         clr A                                    ?
0x058c: a1 94      ajmp 0x0594                              ?
0x058e: e9         mov A, R1                                ?
0x058f: 6a         xrl A, R2                                ?
0x0590: 60 02      jz 0x0594                                ?
0x0592: e9         mov A, R1                                ?
0x0593: 93         movc A, @A+DPTR                          ?
0x0594: fb         mov R3, A                                ?
0x0595: a3         inc DPTR                                 ?
0x0596: ea         mov A, R2                                ?
0x0597: 25 82      add A, 0x82                              ?
0x0599: f5 82      mov 0x82, A                              ?
0x059b: e4         clr A                                    ?
0x059c: 35 83      addc A, 0x83                             ?
0x059e: f5 83      mov 0x83, A                              ?
0x05a0: 22         ret                                      ?
0x05a1: eb         mov A, R3                                ?
0x05a2: 70 04      jnz 0x05a8                               ?
0x05a4: e9         mov A, R1                                ?
0x05a5: 14         dec A                                    ?
0x05a6: 93         movc A, @A+DPTR                          ?
0x05a7: 22         ret                                      ?
0x05a8: 88 f0      mov 0xf0, R0                             ?
0x05aa: e9         mov A, R1                                ?
0x05ab: 14         dec A                                    ?
0x05ac: 93         movc A, @A+DPTR                          ?
0x05ad: fd         mov R5, A                                ?
0x05ae: e9         mov A, R1                                ?
0x05af: 93         movc A, @A+DPTR                          ?
0x05b0: c3         clr C                                    ?
0x05b1: 9d         subb A, R5                               ?
0x05b2: 92 d5      mov 0xd0.5 [0xd5], C                     ?
0x05b4: 50 02      jnc 0x05b8                               ?
0x05b6: f4         cpl A                                    ?
0x05b7: 04         inc A                                    ?
0x05b8: a4         mul AB                                   ?
0x05b9: a1 da      ajmp 0x05da                              ?
0x05bb: c5 f0      xch A, 0xf0                              ?
0x05bd: c3         clr C                                    ?
0x05be: 33         rlc A                                    ?
0x05bf: 40 02      jc 0x05c3                                ?
0x05c1: 9b         subb A, R3                               ?
0x05c2: b3         cpl C                                    ?
0x05c3: e4         clr A                                    ?
0x05c4: 35 f0      addc A, 0xf0                             ?
0x05c6: 30 d5 02   jnb 0xd0.5 [0xd5], 0x05cb                ?
0x05c9: f4         cpl A                                    ?
0x05ca: 04         inc A                                    ?
0x05cb: 2d         add A, R5                                ?
0x05cc: 22         ret                                      ?
0x05cd: d2 d3      setb 0xd0.3 [0xd3]                       ?
0x05cf: b1 78      acall 0x0578                             ?
0x05d1: 19         dec R1                                   ?
0x05d2: e9         mov A, R1                                ?
0x05d3: 93         movc A, @A+DPTR                          ?
0x05d4: 90 11 60   mov DPTR, #0x1160                        ?
0x05d7: c2 d3      clr 0xd0.3 [0xd3]                        ?
0x05d9: 22         ret                                      ?
0x05da: 7c 08      mov R4, #0x08                            ?
0x05dc: c3         clr C                                    ?
0x05dd: 33         rlc A                                    ?
0x05de: c5 f0      xch A, 0xf0                              ?
0x05e0: 33         rlc A                                    ?
0x05e1: 10 d7 0c   jbc 0xd0.7 [0xd7], 0x05f0                ?
0x05e4: 9b         subb A, R3                               ?
0x05e5: 50 01      jnc 0x05e8                               ?
0x05e7: 2b         add A, R3                                ?
0x05e8: c5 f0      xch A, 0xf0                              ?
0x05ea: dc f1      djnz R4, 0x05dd                          ?
0x05ec: 33         rlc A                                    ?
0x05ed: f4         cpl A                                    ?
0x05ee: a1 bb      ajmp 0x05bb                              ?
0x05f0: 9b         subb A, R3                               ?
0x05f1: c3         clr C                                    ?
0x05f2: c5 f0      xch A, 0xf0                              ?
0x05f4: dc e7      djnz R4, 0x05dd                          ?
0x05f6: 33         rlc A                                    ?
0x05f7: f4         cpl A                                    ?
0x05f8: a1 bb      ajmp 0x05bb                              ?
0x05fa: eb         mov A, R3                                ?
0x05fb: c3         clr C                                    ?
0x05fc: 99         subb A, R1                               ?
0x05fd: fe         mov R6, A                                ?
0x05fe: ec         mov A, R4                                ?
0x05ff: 9a         subb A, R2                               ?
0x0600: ff         mov R7, A                                ?
0x0601: 70 04      jnz 0x0607                               ?
0x0603: ee         mov A, R6                                ?
0x0604: 70 01      jnz 0x0607                               ?
0x0606: f8         mov R0, A                                ?
0x0607: 40 10      jc 0x0619                                ?
0x0609: ed         mov A, R5                                ?
0x060a: 91 d9      acall 0x04d9                             ?
0x060c: c3         clr C                                    ?
0x060d: ed         mov A, R5                                ?
0x060e: 28         add A, R0                                ?
0x060f: f8         mov R0, A                                ?
0x0610: ee         mov A, R6                                ?
0x0611: 39         addc A, R1                               ?
0x0612: f9         mov R1, A                                ?
0x0613: ef         mov A, R7                                ?
0x0614: 3a         addc A, R2                               ?
0x0615: fa         mov R2, A                                ?
0x0616: 02 06 31   ljmp 0x0631                              ?
0x0619: c3         clr C                                    ?
0x061a: ee         mov A, R6                                ?
0x061b: f4         cpl A                                    ?
0x061c: 24 01      add A, #0x01                             ?
0x061e: fe         mov R6, A                                ?
0x061f: ef         mov A, R7                                ?
0x0620: f4         cpl A                                    ?
0x0621: 34 00      addc A, #0x00                            ?
0x0623: ff         mov R7, A                                ?
0x0624: ed         mov A, R5                                ?
0x0625: 91 d9      acall 0x04d9                             ?
0x0627: c3         clr C                                    ?
0x0628: e8         mov A, R0                                ?
0x0629: 9d         subb A, R5                               ?
0x062a: f8         mov R0, A                                ?
0x062b: e9         mov A, R1                                ?
0x062c: 9e         subb A, R6                               ?
0x062d: f9         mov R1, A                                ?
0x062e: ea         mov A, R2                                ?
0x062f: 9f         subb A, R7                               ?
0x0630: fa         mov R2, A                                ?
0x0631: 22         ret                                      ?
0x0632: e4         clr A                                    ?
0x0633: a2 96      mov C, 0x90.6 [0x96]                     ?
0x0635: 33         rlc A                                    ?
0x0636: 80 01      sjmp 0x0639                              ?
0x0638: e4         clr A                                    ?
0x0639: a2 b4      mov C, 0xb0.4 [0xb4]                     ?
0x063b: 33         rlc A                                    ?
0x063c: 2a         add A, R2                                ?
0x063d: fa         mov R2, A                                ?
0x063e: 22         ret                                      ?
0x063f: d1 41      acall 0x0641                             ?
0x0641: 74 0f      mov A, #0x0f                             ?
0x0643: 93         movc A, @A+DPTR                          ?
0x0644: 78 00      mov R0, #0x00                            ?
0x0646: f9         mov R1, A                                ?
0x0647: d1 52      acall 0x0652                             ?
0x0649: 30 b3 fb   jnb 0xb0.3 [0xb3], 0x0647                ?
0x064c: d1 52      acall 0x0652                             ?
0x064e: 20 b3 fb   jb 0xb0.3 [0xb3], 0x064c                 ?
0x0651: 22         ret                                      ?
0x0652: d8 04      djnz R0, 0x0658                          ?
0x0654: d9 02      djnz R1, 0x0658                          ?
0x0656: 41 4e      ajmp 0x024e                              ?
0x0658: 22         ret                                      ?
0x0659: 90 11 24   mov DPTR, #0x1124                        ?
0x065c: b1 cd      acall 0x05cd                             ?
0x065e: 13         rrc A                                    ?
0x065f: 92 19      mov 0x23.1 [0x19], C                     ?
0x0661: 13         rrc A                                    ?
0x0662: 92 18      mov 0x23.0 [0x18], C                     ?
0x0664: 02 10 47   ljmp 0x1047                              ?
0x0667: e5 15      mov A, 0x15                              ?
0x0669: b4 80 00   cjne A, #0x80, 0x066c                    ?
0x066c: b3         cpl C                                    ?
0x066d: 92 1b      mov 0x23.3 [0x1b], C                     ?
0x066f: e5 14      mov A, 0x14                              ?
0x0671: b4 80 00   cjne A, #0x80, 0x0674                    ?
0x0674: b3         cpl C                                    ?
0x0675: 92 2e      mov 0x25.6 [0x2e], C                     ?
0x0677: 74 10      mov A, #0x10                             ?
0x0679: 93         movc A, @A+DPTR                          ?
0x067a: c3         clr C                                    ?
0x067b: 95 37      subb A, 0x37                             ?
0x067d: 50 0a      jnc 0x0689                               ?
0x067f: 7a 03      mov R2, #0x03                            ?
0x0681: b1 1d      acall 0x051d                             ?
0x0683: c3         clr C                                    ?
0x0684: 95 37      subb A, 0x37                             ?
0x0686: 40 04      jc 0x068c                                ?
0x0688: 22         ret                                      ?
0x0689: d2 1a      setb 0x23.2 [0x1a]                       ?
0x068b: 22         ret                                      ?
0x068c: c2 1a      clr 0x23.2 [0x1a]                        ?
0x068e: 22         ret                                      ?
0x068f: 7d 00      mov R5, #0x00                            ?
0x0691: c3         clr C                                    ?
0x0692: 30 1a 06   jnb 0x23.2 [0x1a], 0x069b                ?
0x0695: 7a 04      mov R2, #0x04                            ?
0x0697: f1 aa      acall 0x07aa                             ?
0x0699: c1 e1      ajmp 0x06e1                              ?
0x069b: 30 18 08   jnb 0x23.0 [0x18], 0x06a6                ?
0x069e: 7a 07      mov R2, #0x07                            ?
0x06a0: f1 aa      acall 0x07aa                             ?
0x06a2: d1 38      acall 0x0638                             ?
0x06a4: c1 da      ajmp 0x06da                              ?
0x06a6: 30 19 08   jnb 0x23.1 [0x19], 0x06b1                ?
0x06a9: 7a 0b      mov R2, #0x0b                            ?
0x06ab: f1 aa      acall 0x07aa                             ?
0x06ad: d1 38      acall 0x0638                             ?
0x06af: c1 c5      ajmp 0x06c5                              ?
0x06b1: 7a 11      mov R2, #0x11                            ?
0x06b3: 74 20      mov A, #0x20                             ?
0x06b5: 93         movc A, @A+DPTR                          ?
0x06b6: 95 49      subb A, 0x49                             ?
0x06b8: 40 06      jc 0x06c0                                ?
0x06ba: f1 aa      acall 0x07aa                             ?
0x06bc: d1 32      acall 0x0632                             ?
0x06be: c1 da      ajmp 0x06da                              ?
0x06c0: 1a         dec R2                                   ?
0x06c1: f1 aa      acall 0x07aa                             ?
0x06c3: d1 32      acall 0x0632                             ?
0x06c5: 90 11 2e   mov DPTR, #0x112e                        ?
0x06c8: b1 cd      acall 0x05cd                             ?
0x06ca: 30 e2 0d   jnb 0xe0.2 [0xe2], 0x06da                ?
0x06cd: 74 21      mov A, #0x21                             ?
0x06cf: 93         movc A, @A+DPTR                          ?
0x06d0: c3         clr C                                    ?
0x06d1: 95 37      subb A, 0x37                             ?
0x06d3: 50 05      jnc 0x06da                               ?
0x06d5: 74 22      mov A, #0x22                             ?
0x06d7: 93         movc A, @A+DPTR                          ?
0x06d8: 2d         add A, R5                                ?
0x06d9: fd         mov R5, A                                ?
0x06da: b1 1d      acall 0x051d                             ?
0x06dc: 2d         add A, R5                                ?
0x06dd: c3         clr C                                    ?
0x06de: 94 14      subb A, #0x14                            ?
0x06e0: fd         mov R5, A                                ?
0x06e1: 02 10 4a   ljmp 0x104a                              ?
0x06e4: 7a 17      mov R2, #0x17                            ?
0x06e6: b1 1d      acall 0x051d                             ?
0x06e8: 2d         add A, R5                                ?
0x06e9: c3         clr C                                    ?
0x06ea: 94 14      subb A, #0x14                            ?
0x06ec: fd         mov R5, A                                ?
0x06ed: f8         mov R0, A                                ?
0x06ee: a2 e7      mov C, 0xe0.7 [0xe7]                     ?
0x06f0: 74 23      mov A, #0x23                             ?
0x06f2: 50 01      jnc 0x06f5                               ?
0x06f4: 04         inc A                                    ?
0x06f5: 93         movc A, @A+DPTR                          ?
0x06f6: f9         mov R1, A                                ?
0x06f7: 50 01      jnc 0x06fa                               ?
0x06f9: c8         xch A, R0                                ?
0x06fa: c3         clr C                                    ?
0x06fb: 98         subb A, R0                               ?
0x06fc: 50 02      jnc 0x0700                               ?
0x06fe: e9         mov A, R1                                ?
0x06ff: fd         mov R5, A                                ?
0x0700: ed         mov A, R5                                ?
0x0701: a2 e7      mov C, 0xe0.7 [0xe7]                     ?
0x0703: 13         rrc A                                    ?
0x0704: fd         mov R5, A                                ?
0x0705: 02 10 4d   ljmp 0x104d                              ?
0x0708: 20 1a 65   jb 0x23.2 [0x1a], 0x0770                 ?
0x070b: 30 18 24   jnb 0x23.0 [0x18], 0x0732                ?
0x070e: 7a 19      mov R2, #0x19                            ?
0x0710: b1 1d      acall 0x051d                             ?
0x0712: c3         clr C                                    ?
0x0713: 95 37      subb A, 0x37                             ?
0x0715: 50 27      jnc 0x073e                               ?
0x0717: fb         mov R3, A                                ?
0x0718: 74 32      mov A, #0x32                             ?
0x071a: 20 0e 02   jb 0x21.6 [0x0e], 0x071f                 ?
0x071d: 74 31      mov A, #0x31                             ?
0x071f: 93         movc A, @A+DPTR                          ?
0x0720: 2b         add A, R3                                ?
0x0721: 40 4d      jc 0x0770                                ?
0x0723: d2 15      setb 0x22.5 [0x15]                       ?
0x0725: ed         mov A, R5                                ?
0x0726: b5 31 47   cjne A, 0x31, 0x0770                     ?
0x0729: d2 1d      setb 0x23.5 [0x1d]                       ?
0x072b: c2 15      clr 0x22.5 [0x15]                        ?
0x072d: f5 32      mov 0x32, A                              ?
0x072f: f5 31      mov 0x31, A                              ?
0x0731: 22         ret                                      ?
0x0732: c2 0e      clr 0x21.6 [0x0e]                        ?
0x0734: c2 15      clr 0x22.5 [0x15]                        ?
0x0736: 30 1d 37   jnb 0x23.5 [0x1d], 0x0770                ?
0x0739: 74 2f      mov A, #0x2f                             ?
0x073b: 93         movc A, @A+DPTR                          ?
0x073c: e1 48      ajmp 0x0748                              ?
0x073e: c2 15      clr 0x22.5 [0x15]                        ?
0x0740: 30 1d 2d   jnb 0x23.5 [0x1d], 0x0770                ?
0x0743: d2 0e      setb 0x21.6 [0x0e]                       ?
0x0745: 74 30      mov A, #0x30                             ?
0x0747: 93         movc A, @A+DPTR                          ?
0x0748: 25 31      add A, 0x31                              ?
0x074a: f5 31      mov 0x31, A                              ?
0x074c: 8d 32      mov 0x32, R5                             ?
0x074e: c3         clr C                                    ?
0x074f: ed         mov A, R5                                ?
0x0750: 95 31      subb A, 0x31                             ?
0x0752: 30 e7 0c   jnb 0xe0.7 [0xe7], 0x0761                ?
0x0755: 75 34 01   mov 0x34, #0x01                          ?
0x0758: 75 4d 00   mov 0x4d, #0x00                          ?
0x075b: d2 0d      setb 0x21.5 [0x0d]                       ?
0x075d: c2 1d      clr 0x23.5 [0x1d]                        ?
0x075f: e1 70      ajmp 0x0770                              ?
0x0761: 74 2d      mov A, #0x2d                             ?
0x0763: 93         movc A, @A+DPTR                          ?
0x0764: f5 34      mov 0x34, A                              ?
0x0766: d2 16      setb 0x22.6 [0x16]                       ?
0x0768: 75 4d 00   mov 0x4d, #0x00                          ?
0x076b: d2 0d      setb 0x21.5 [0x0d]                       ?
0x076d: c2 1d      clr 0x23.5 [0x1d]                        ?
0x076f: 22         ret                                      ?
0x0770: c3         clr C                                    ?
0x0771: 74 25      mov A, #0x25                             ?
0x0773: 93         movc A, @A+DPTR                          ?
0x0774: 95 49      subb A, 0x49                             ?
0x0776: 40 06      jc 0x077e                                ?
0x0778: 74 26      mov A, #0x26                             ?
0x077a: 93         movc A, @A+DPTR                          ?
0x077b: 95 37      subb A, 0x37                             ?
0x077d: b3         cpl C                                    ?
0x077e: 30 14 01   jnb 0x22.4 [0x14], 0x0782                ?
0x0781: b3         cpl C                                    ?
0x0782: 50 0b      jnc 0x078f                               ?
0x0784: b2 14      cpl 0x22.4 [0x14]                        ?
0x0786: 20 16 06   jb 0x22.6 [0x16], 0x078f                 ?
0x0789: 20 15 03   jb 0x22.5 [0x15], 0x078f                 ?
0x078c: 75 34 01   mov 0x34, #0x01                          ?
0x078f: ed         mov A, R5                                ?
0x0790: 30 1c 05   jnb 0x23.4 [0x1c], 0x0798                ?
0x0793: f5 31      mov 0x31, A                              ?
0x0795: 75 34 01   mov 0x34, #0x01                          ?
0x0798: ed         mov A, R5                                ?
0x0799: 30 16 0b   jnb 0x22.6 [0x16], 0x07a7                ?
0x079c: c3         clr C                                    ?
0x079d: 95 31      subb A, 0x31                             ?
0x079f: 30 e7 05   jnb 0xe0.7 [0xe7], 0x07a7                ?
0x07a2: c2 16      clr 0x22.6 [0x16]                        ?
0x07a4: 75 34 01   mov 0x34, #0x01                          ?
0x07a7: 8d 32      mov 0x32, R5                             ?
0x07a9: 22         ret                                      ?
0x07aa: b1 1d      acall 0x051d                             ?
0x07ac: 20 2a 07   jb 0x25.2 [0x2a], 0x07b6                 ?
0x07af: 2d         add A, R5                                ?
0x07b0: c3         clr C                                    ?
0x07b1: 94 14      subb A, #0x14                            ?
0x07b3: fd         mov R5, A                                ?
0x07b4: e1 aa      ajmp 0x07aa                              ?
0x07b6: 22         ret                                      ?
0x07b7: 7a 18      mov R2, #0x18                            ?
0x07b9: b1 1d      acall 0x051d                             ?
0x07bb: f5 2f      mov 0x2f, A                              ?
0x07bd: 22         ret                                      ?
0x07be: 90 11 2e   mov DPTR, #0x112e                        ?
0x07c1: b1 cd      acall 0x05cd                             ?
0x07c3: c2 e2      clr 0xe0.2 [0xe2]                        ?
0x07c5: 24 1b      add A, #0x1b                             ?
0x07c7: 93         movc A, @A+DPTR                          ?
0x07c8: f5 f0      mov 0xf0, A                              ?
0x07ca: 7a 21      mov R2, #0x21                            ?
0x07cc: b1 1d      acall 0x051d                             ?
0x07ce: a4         mul AB                                   ?
0x07cf: af f0      mov R7, 0xf0                             ?
0x07d1: fe         mov R6, A                                ?
0x07d2: 75 50 02   mov 0x50, #0x02                          ?
0x07d5: b1 1d      acall 0x051d                             ?
0x07d7: 12 08 86   lcall 0x0886                             ?
0x07da: 30 1a 5f   jnb 0x23.2 [0x1a], 0x083c                ?
0x07dd: 7a 2f      mov R2, #0x2f                            ?
0x07df: 74 1f      mov A, #0x1f                             ?
0x07e1: 93         movc A, @A+DPTR                          ?
0x07e2: b5 13 00   cjne A, 0x13, 0x07e5                     ?
0x07e5: 50 01      jnc 0x07e8                               ?
0x07e7: 0a         inc R2                                   ?
0x07e8: b1 1d      acall 0x051d                             ?
0x07ea: f5 3c      mov 0x3c, A                              ?
0x07ec: 7a 31      mov R2, #0x31                            ?
0x07ee: b1 1d      acall 0x051d                             ?
0x07f0: fc         mov R4, A                                ?
0x07f1: 7b 05      mov R3, #0x05                            ?
0x07f3: 79 08      mov R1, #0x08                            ?
0x07f5: 20 0c 13   jb 0x21.4 [0x0c], 0x080b                 ?
0x07f8: b1 1d      acall 0x051d                             ?
0x07fa: c3         clr C                                    ?
0x07fb: 95 37      subb A, 0x37                             ?
0x07fd: 40 07      jc 0x0806                                ?
0x07ff: 74 1a      mov A, #0x1a                             ?
0x0801: 93         movc A, @A+DPTR                          ?
0x0802: 95 4d      subb A, 0x4d                             ?
0x0804: 50 22      jnc 0x0828                               ?
0x0806: d2 0c      setb 0x21.4 [0x0c]                       ?
0x0808: 75 4d 00   mov 0x4d, #0x00                          ?
0x080b: 7a 33      mov R2, #0x33                            ?
0x080d: 12 05 1d   lcall 0x051d                             ?
0x0810: f5 f0      mov 0xf0, A                              ?
0x0812: 12 05 1d   lcall 0x051d                             ?
0x0815: a4         mul AB                                   ?
0x0816: ec         mov A, R4                                ?
0x0817: 20 e7 07   jb 0xe0.7 [0xe7], 0x0821                 ?
0x081a: 23         rl A                                     ?
0x081b: c9         xch A, R1                                ?
0x081c: 23         rl A                                     ?
0x081d: c9         xch A, R1                                ?
0x081e: 1b         dec R3                                   ?
0x081f: 80 f6      sjmp 0x0817                              ?
0x0821: a4         mul AB                                   ?
0x0822: ac f0      mov R4, 0xf0                             ?
0x0824: 30 e7 01   jnb 0xe0.7 [0xe7], 0x0828                ?
0x0827: 0c         inc R4                                   ?
0x0828: ec         mov A, R4                                ?
0x0829: b5 01 00   cjne A, 0x01, 0x082c                     ?
0x082c: 40 0b      jc 0x0839                                ?
0x082e: 12 04 d9   lcall 0x04d9                             ?
0x0831: e5 50      mov A, 0x50                              ?
0x0833: 2b         add A, R3                                ?
0x0834: 12 05 09   lcall 0x0509                             ?
0x0837: f5 50      mov 0x50, A                              ?
0x0839: 02 08 73   ljmp 0x0873                              ?
0x083c: 12 06 38   lcall 0x0638                             ?
0x083f: 12 05 1d   lcall 0x051d                             ?
0x0842: f5 f0      mov 0xf0, A                              ?
0x0844: 7a 25      mov R2, #0x25                            ?
0x0846: 30 18 01   jnb 0x23.0 [0x18], 0x084a                ?
0x0849: 0a         inc R2                                   ?
0x084a: 12 05 1d   lcall 0x051d                             ?
0x084d: a4         mul AB                                   ?
0x084e: e5 f0      mov A, 0xf0                              ?
0x0850: 12 08 7d   lcall 0x087d                             ?
0x0853: e5 3c      mov A, 0x3c                              ?
0x0855: 12 08 7d   lcall 0x087d                             ?
0x0858: 7a 27      mov R2, #0x27                            ?
0x085a: 12 06 38   lcall 0x0638                             ?
0x085d: 20 18 0d   jb 0x23.0 [0x18], 0x086d                 ?
0x0860: 7a 29      mov R2, #0x29                            ?
0x0862: 12 06 38   lcall 0x0638                             ?
0x0865: 20 19 05   jb 0x23.1 [0x19], 0x086d                 ?
0x0868: 7a 2b      mov R2, #0x2b                            ?
0x086a: 12 06 32   lcall 0x0632                             ?
0x086d: 12 05 1d   lcall 0x051d                             ?
0x0870: 12 08 86   lcall 0x0886                             ?
0x0873: 02 10 50   ljmp 0x1050                              ?
0x0876: 8e 4e      mov 0x4e, R6                             ?
0x0878: 8f 4f      mov 0x4f, R7                             ?
0x087a: 02 10 53   ljmp 0x1053                              ?
0x087d: 60 12      jz 0x0891                                ?
0x087f: 24 80      add A, #0x80                             ?
0x0881: 50 03      jnc 0x0886                               ?
0x0883: 13         rrc A                                    ?
0x0884: 05 50      inc 0x50                                 ?
0x0886: 12 04 d9   lcall 0x04d9                             ?
0x0889: e5 50      mov A, 0x50                              ?
0x088b: 04         inc A                                    ?
0x088c: 12 05 09   lcall 0x0509                             ?
0x088f: f5 50      mov 0x50, A                              ?
0x0891: 22         ret                                      ?
0x0892: 02 10 68   ljmp 0x1068                              ?
0x0895: 30 1c 08   jnb 0x23.4 [0x1c], 0x08a0                ?
0x0898: 12 0a 4a   lcall 0x0a4a                             ?
0x089b: 75 20 00   mov 0x20, #0x00                          ?
0x089e: d2 06      setb 0x20.6 [0x06]                       ?
0x08a0: 10 01 03   jbc 0x20.1 [0x01], 0x08a6                ?
0x08a3: d2 01      setb 0x20.1 [0x01]                       ?
0x08a5: 22         ret                                      ?
0x08a6: 20 1a 15   jb 0x23.2 [0x1a], 0x08be                 ?
0x08a9: 20 1d 1f   jb 0x23.5 [0x1d], 0x08cb                 ?
0x08ac: a2 19      mov C, 0x23.1 [0x19]                     ?
0x08ae: 82 18      anl C, 0x23.0 [0x18]                     ?
0x08b0: 40 22      jc 0x08d4                                ?
0x08b2: 20 18 29   jb 0x23.0 [0x18], 0x08de                 ?
0x08b5: 12 0a 4a   lcall 0x0a4a                             ?
0x08b8: d2 06      setb 0x20.6 [0x06]                       ?
0x08ba: c2 00      clr 0x20.0 [0x00]                        ?
0x08bc: 21 c5      ajmp 0x09c5                              ?
0x08be: d2 06      setb 0x20.6 [0x06]                       ?
0x08c0: d2 00      setb 0x20.0 [0x00]                       ?
0x08c2: 7a 35      mov R2, #0x35                            ?
0x08c4: 12 05 1d   lcall 0x051d                             ?
0x08c7: f5 7f      mov 0x7f, A                              ?
0x08c9: 21 2d      ajmp 0x092d                              ?
0x08cb: d2 06      setb 0x20.6 [0x06]                       ?
0x08cd: c2 00      clr 0x20.0 [0x00]                        ?
0x08cf: 12 0a 4a   lcall 0x0a4a                             ?
0x08d2: 21 c5      ajmp 0x09c5                              ?
0x08d4: 74 3c      mov A, #0x3c                             ?
0x08d6: 93         movc A, @A+DPTR                          ?
0x08d7: c3         clr C                                    ?
0x08d8: 13         rrc A                                    ?
0x08d9: f9         mov R1, A                                ?
0x08da: 78 00      mov R0, #0x00                            ?
0x08dc: 41 05      ajmp 0x0a05                              ?
0x08de: 02 10 6b   ljmp 0x106b                              ?
0x08e1: 30 1b 09   jnb 0x23.3 [0x1b], 0x08ed                ?
0x08e4: 7a 36      mov R2, #0x36                            ?
0x08e6: 12 05 1d   lcall 0x051d                             ?
0x08e9: f5 7f      mov 0x7f, A                              ?
0x08eb: 80 40      sjmp 0x092d                              ?
0x08ed: 7a 37      mov R2, #0x37                            ?
0x08ef: 12 05 1d   lcall 0x051d                             ?
0x08f2: f5 f0      mov 0xf0, A                              ?
0x08f4: 20 b5 0a   jb 0xb0.5 [0xb5], 0x0901                 ?
0x08f7: 74 39      mov A, #0x39                             ?
0x08f9: 93         movc A, @A+DPTR                          ?
0x08fa: b5 f0 00   cjne A, 0xf0, 0x08fd                     ?
0x08fd: 40 02      jc 0x0901                                ?
0x08ff: f5 f0      mov 0xf0, A                              ?
0x0901: 30 06 0e   jnb 0x20.6 [0x06], 0x0912                ?
0x0904: 02 10 6e   ljmp 0x106e                              ?
0x0907: 20 00 03   jb 0x20.0 [0x00], 0x090d                 ?
0x090a: 85 37 7f   mov 0x37, 0x7f                           ?
0x090d: 75 7c 01   mov 0x7c, #0x01                          ?
0x0910: c2 06      clr 0x20.6 [0x06]                        ?
0x0912: e5 f0      mov A, 0xf0                              ?
0x0914: b5 7f 00   cjne A, 0x7f, 0x0917                     ?
0x0917: 50 11      jnc 0x092a                               ?
0x0919: d5 7c 0b   djnz 0x7c, 0x0927                        ?
0x091c: 15 7f      dec 0x7f                                 ?
0x091e: 74 3f      mov A, #0x3f                             ?
0x0920: a2 00      mov C, 0x20.0 [0x00]                     ?
0x0922: 34 00      addc A, #0x00                            ?
0x0924: 93         movc A, @A+DPTR                          ?
0x0925: f5 7c      mov 0x7c, A                              ?
0x0927: 85 7f f0   mov 0x7f, 0xf0                           ?
0x092a: 85 f0 7f   mov 0xf0, 0x7f                           ?
0x092d: 74 38      mov A, #0x38                             ?
0x092f: 93         movc A, @A+DPTR                          ?
0x0930: 25 37      add A, 0x37                              ?
0x0932: d3         setb C                                   ?
0x0933: 95 7f      subb A, 0x7f                             ?
0x0935: 50 08      jnc 0x093f                               ?
0x0937: 74 80      mov A, #0x80                             ?
0x0939: 95 7e      subb A, 0x7e                             ?
0x093b: 40 02      jc 0x093f                                ?
0x093d: 51 4a      acall 0x0a4a                             ?
0x093f: 02 10 71   ljmp 0x1071                              ?
0x0942: e5 7f      mov A, 0x7f                              ?
0x0944: c3         clr C                                    ?
0x0945: 95 37      subb A, 0x37                             ?
0x0947: 92 02      mov 0x20.2 [0x02], C                     ?
0x0949: 50 06      jnc 0x0951                               ?
0x094b: c2 03      clr 0x20.3 [0x03]                        ?
0x094d: f4         cpl A                                    ?
0x094e: 04         inc A                                    ?
0x094f: 80 02      sjmp 0x0953                              ?
0x0951: c2 04      clr 0x20.4 [0x04]                        ?
0x0953: fb         mov R3, A                                ?
0x0954: a9 7e      mov R1, 0x7e                             ?
0x0956: a8 7d      mov R0, 0x7d                             ?
0x0958: 10 03 16   jbc 0x20.3 [0x03], 0x0971                ?
0x095b: 10 04 13   jbc 0x20.4 [0x04], 0x0971                ?
0x095e: 7a 38      mov R2, #0x38                            ?
0x0960: 30 02 01   jnb 0x20.2 [0x02], 0x0964                ?
0x0963: 0a         inc R2                                   ?
0x0964: 12 05 1d   lcall 0x051d                             ?
0x0967: f5 f0      mov 0xf0, A                              ?
0x0969: eb         mov A, R3                                ?
0x096a: 12 0b dd   lcall 0x0bdd                             ?
0x096d: 88 7d      mov 0x7d, R0                             ?
0x096f: 89 7e      mov 0x7e, R1                             ?
0x0971: 20 02 14   jb 0x20.2 [0x02], 0x0988                 ?
0x0974: 7a 3a      mov R2, #0x3a                            ?
0x0976: 12 05 1d   lcall 0x051d                             ?
0x0979: f5 f0      mov 0xf0, A                              ?
0x097b: eb         mov A, R3                                ?
0x097c: b4 3f 00   cjne A, #0x3f, 0x097f                    ?
0x097f: 40 02      jc 0x0983                                ?
0x0981: e5 3f      mov A, 0x3f                              ?
0x0983: 23         rl A                                     ?
0x0984: 23         rl A                                     ?
0x0985: 12 0b dd   lcall 0x0bdd                             ?
0x0988: 02 10 74   ljmp 0x1074                              ?
0x098b: e9         mov A, R1                                ?
0x098c: c3         clr C                                    ?
0x098d: 30 e7 13   jnb 0xe0.7 [0xe7], 0x09a3                ?
0x0990: 20 1a 1f   jb 0x23.2 [0x1a], 0x09b2                 ?
0x0993: 74 3d      mov A, #0x3d                             ?
0x0995: 93         movc A, @A+DPTR                          ?
0x0996: 13         rrc A                                    ?
0x0997: 24 80      add A, #0x80                             ?
0x0999: b5 01 00   cjne A, 0x01, 0x099c                     ?
0x099c: 50 14      jnc 0x09b2                               ?
0x099e: f9         mov R1, A                                ?
0x099f: d2 03      setb 0x20.3 [0x03]                       ?
0x09a1: 80 0f      sjmp 0x09b2                              ?
0x09a3: 74 3e      mov A, #0x3e                             ?
0x09a5: 93         movc A, @A+DPTR                          ?
0x09a6: 13         rrc A                                    ?
0x09a7: f4         cpl A                                    ?
0x09a8: 24 80      add A, #0x80                             ?
0x09aa: b5 01 00   cjne A, 0x01, 0x09ad                     ?
0x09ad: 40 03      jc 0x09b2                                ?
0x09af: f9         mov R1, A                                ?
0x09b0: d2 04      setb 0x20.4 [0x04]                       ?
0x09b2: 7a 3d      mov R2, #0x3d                            ?
0x09b4: 12 05 1d   lcall 0x051d                             ?
0x09b7: b5 49 00   cjne A, 0x49, 0x09ba                     ?
0x09ba: 40 02      jc 0x09be                                ?
0x09bc: d2 04      setb 0x20.4 [0x04]                       ?
0x09be: e9         mov A, R1                                ?
0x09bf: c3         clr C                                    ?
0x09c0: 94 80      subb A, #0x80                            ?
0x09c2: 92 05      mov 0x20.5 [0x05], C                     ?
0x09c4: f9         mov R1, A                                ?
0x09c5: 02 10 77   ljmp 0x1077                              ?
0x09c8: 7a 3c      mov R2, #0x3c                            ?
0x09ca: 12 05 1d   lcall 0x051d                             ?
0x09cd: f5 f0      mov 0xf0, A                              ?
0x09cf: 30 1d 07   jnb 0x23.5 [0x1d], 0x09d9                ?
0x09d2: 7a 3b      mov R2, #0x3b                            ?
0x09d4: 12 05 1d   lcall 0x051d                             ?
0x09d7: 51 55      acall 0x0a55                             ?
0x09d9: 30 1b 05   jnb 0x23.3 [0x1b], 0x09e1                ?
0x09dc: 74 3b      mov A, #0x3b                             ?
0x09de: 93         movc A, @A+DPTR                          ?
0x09df: 51 55      acall 0x0a55                             ?
0x09e1: 20 b5 05   jb 0xb0.5 [0xb5], 0x09e9                 ?
0x09e4: 74 3a      mov A, #0x3a                             ?
0x09e6: 93         movc A, @A+DPTR                          ?
0x09e7: 51 55      acall 0x0a55                             ?
0x09e9: 74 80      mov A, #0x80                             ?
0x09eb: a4         mul AB                                   ?
0x09ec: 02 10 7a   ljmp 0x107a                              ?
0x09ef: 28         add A, R0                                ?
0x09f0: f8         mov R0, A                                ?
0x09f1: e5 f0      mov A, 0xf0                              ?
0x09f3: 39         addc A, R1                               ?
0x09f4: f9         mov R1, A                                ?
0x09f5: 30 e7 0d   jnb 0xe0.7 [0xe7], 0x0a05                ?
0x09f8: 30 05 06   jnb 0x20.5 [0x05], 0x0a01                ?
0x09fb: 79 00      mov R1, #0x00                            ?
0x09fd: 78 00      mov R0, #0x00                            ?
0x09ff: 80 04      sjmp 0x0a05                              ?
0x0a01: 79 7f      mov R1, #0x7f                            ?
0x0a03: 78 ff      mov R0, #0xff                            ?
0x0a05: 02 10 7d   ljmp 0x107d                              ?
0x0a08: af 01      mov R7, 0x01                             ?
0x0a0a: ae 00      mov R6, 0x00                             ?
0x0a0c: 74 01      mov A, #0x01                             ?
0x0a0e: 12 05 09   lcall 0x0509                             ?
0x0a11: 8f 7b      mov 0x7b, R7                             ?
0x0a13: 74 41      mov A, #0x41                             ?
0x0a15: 93         movc A, @A+DPTR                          ?
0x0a16: 12 04 d9   lcall 0x04d9                             ?
0x0a19: 74 42      mov A, #0x42                             ?
0x0a1b: 93         movc A, @A+DPTR                          ?
0x0a1c: 2f         add A, R7                                ?
0x0a1d: ff         mov R7, A                                ?
0x0a1e: 74 0b      mov A, #0x0b                             ?
0x0a20: 93         movc A, @A+DPTR                          ?
0x0a21: f8         mov R0, A                                ?
0x0a22: 74 0c      mov A, #0x0c                             ?
0x0a24: 93         movc A, @A+DPTR                          ?
0x0a25: f9         mov R1, A                                ?
0x0a26: 12 04 55   lcall 0x0455                             ?
0x0a29: ee         mov A, R6                                ?
0x0a2a: f4         cpl A                                    ?
0x0a2b: f8         mov R0, A                                ?
0x0a2c: ef         mov A, R7                                ?
0x0a2d: f4         cpl A                                    ?
0x0a2e: f9         mov R1, A                                ?
0x0a2f: 74 0b      mov A, #0x0b                             ?
0x0a31: 93         movc A, @A+DPTR                          ?
0x0a32: fb         mov R3, A                                ?
0x0a33: 74 0c      mov A, #0x0c                             ?
0x0a35: 93         movc A, @A+DPTR                          ?
0x0a36: fc         mov R4, A                                ?
0x0a37: d3         setb C                                   ?
0x0a38: ee         mov A, R6                                ?
0x0a39: 9b         subb A, R3                               ?
0x0a3a: cf         xch A, R7                                ?
0x0a3b: 9c         subb A, R4                               ?
0x0a3c: fb         mov R3, A                                ?
0x0a3d: c2 ab      clr 0xa8.3 [0xab]                        ?
0x0a3f: 8f 44      mov 0x44, R7                             ?
0x0a41: 8b 45      mov 0x45, R3                             ?
0x0a43: 88 42      mov 0x42, R0                             ?
0x0a45: 89 43      mov 0x43, R1                             ?
0x0a47: d2 ab      setb 0xa8.3 [0xab]                       ?
0x0a49: 22         ret                                      ?
0x0a4a: 75 7e 80   mov 0x7e, #0x80                          ?
0x0a4d: 75 7d 00   mov 0x7d, #0x00                          ?
0x0a50: 79 00      mov R1, #0x00                            ?
0x0a52: 78 00      mov R0, #0x00                            ?
0x0a54: 22         ret                                      ?
0x0a55: 25 f0      add A, 0xf0                              ?
0x0a57: 50 02      jnc 0x0a5b                               ?
0x0a59: e5 ff      mov A, 0xff                              ?
0x0a5b: f5 f0      mov 0xf0, A                              ?
0x0a5d: 22         ret                                      ?
0x0a5e: 7a 3e      mov R2, #0x3e                            ?
0x0a60: 30 b4 02   jnb 0xb0.4 [0xb4], 0x0a65                ?
0x0a63: 7a 41      mov R2, #0x41                            ?
0x0a65: 12 05 1d   lcall 0x051d                             ?
0x0a68: f5 18      mov 0x18, A                              ?
0x0a6a: 12 05 1d   lcall 0x051d                             ?
0x0a6d: f5 19      mov 0x19, A                              ?
0x0a6f: 12 05 1d   lcall 0x051d                             ?
0x0a72: f5 1a      mov 0x1a, A                              ?
0x0a74: 22         ret                                      ?
0x0a75: 30 1c 03   jnb 0x23.4 [0x1c], 0x0a7b                ?
0x0a78: 75 1b 80   mov 0x1b, #0x80                          ?
0x0a7b: a8 1c      mov R0, 0x1c                             ?
0x0a7d: a9 1b      mov R1, 0x1b                             ?
0x0a7f: a2 97      mov C, 0x90.7 [0x97]                     ?
0x0a81: b3         cpl C                                    ?
0x0a82: 92 02      mov 0x20.2 [0x02], C                     ?
0x0a84: 40 0e      jc 0x0a94                                ?
0x0a86: 20 26 05   jb 0x24.6 [0x26], 0x0a8e                 ?
0x0a89: 12 0b cd   lcall 0x0bcd                             ?
0x0a8c: 80 13      sjmp 0x0aa1                              ?
0x0a8e: e4         clr A                                    ?
0x0a8f: 12 0b d4   lcall 0x0bd4                             ?
0x0a92: 80 0d      sjmp 0x0aa1                              ?
0x0a94: 30 26 05   jnb 0x24.6 [0x26], 0x0a9c                ?
0x0a97: 12 0b cd   lcall 0x0bcd                             ?
0x0a9a: 80 05      sjmp 0x0aa1                              ?
0x0a9c: e5 1a      mov A, 0x1a                              ?
0x0a9e: 12 0b d4   lcall 0x0bd4                             ?
0x0aa1: 88 1c      mov 0x1c, R0                             ?
0x0aa3: 89 1b      mov 0x1b, R1                             ?
0x0aa5: a2 02      mov C, 0x20.2 [0x02]                     ?
0x0aa7: 92 26      mov 0x24.6 [0x26], C                     ?
0x0aa9: 02 10 5c   ljmp 0x105c                              ?
0x0aac: 20 1a 4a   jb 0x23.2 [0x1a], 0x0af9                 ?
0x0aaf: 20 19 47   jb 0x23.1 [0x19], 0x0af9                 ?
0x0ab2: 20 1d 44   jb 0x23.5 [0x1d], 0x0af9                 ?
0x0ab5: 00         nop                                      ?
0x0ab6: 00         nop                                      ?
0x0ab7: 00         nop                                      ?
0x0ab8: 74 4b      mov A, #0x4b                             ?
0x0aba: 93         movc A, @A+DPTR                          ?
0x0abb: b5 37 00   cjne A, 0x37, 0x0abe                     ?
0x0abe: 40 39      jc 0x0af9                                ?
0x0ac0: 74 4c      mov A, #0x4c                             ?
0x0ac2: 93         movc A, @A+DPTR                          ?
0x0ac3: b5 49 00   cjne A, 0x49, 0x0ac6                     ?
0x0ac6: 50 15      jnc 0x0add                               ?
0x0ac8: 30 25 2e   jnb 0x24.5 [0x25], 0x0af9                ?
0x0acb: 20 21 09   jb 0x24.1 [0x21], 0x0ad7                 ?
0x0ace: d2 21      setb 0x24.1 [0x21]                       ?
0x0ad0: c2 22      clr 0x24.2 [0x22]                        ?
0x0ad2: 74 4d      mov A, #0x4d                             ?
0x0ad4: 93         movc A, @A+DPTR                          ?
0x0ad5: f5 3f      mov 0x3f, A                              ?
0x0ad7: e5 3f      mov A, 0x3f                              ?
0x0ad9: 60 1e      jz 0x0af9                                ?
0x0adb: 80 02      sjmp 0x0adf                              ?
0x0add: c2 21      clr 0x24.1 [0x21]                        ?
0x0adf: 74 49      mov A, #0x49                             ?
0x0ae1: 20 18 02   jb 0x23.0 [0x18], 0x0ae6                 ?
0x0ae4: 74 48      mov A, #0x48                             ?
0x0ae6: 93         movc A, @A+DPTR                          ?
0x0ae7: fa         mov R2, A                                ?
0x0ae8: 20 25 04   jb 0x24.5 [0x25], 0x0aef                 ?
0x0aeb: 74 4a      mov A, #0x4a                             ?
0x0aed: 93         movc A, @A+DPTR                          ?
0x0aee: 2a         add A, R2                                ?
0x0aef: c3         clr C                                    ?
0x0af0: 95 13      subb A, 0x13                             ?
0x0af2: 92 25      mov 0x24.5 [0x25], C                     ?
0x0af4: 12 0b 50   lcall 0x0b50                             ?
0x0af7: 80 02      sjmp 0x0afb                              ?
0x0af9: c2 25      clr 0x24.5 [0x25]                        ?
0x0afb: 12 10 5f   lcall 0x105f                             ?
0x0afe: 30 96 17   jnb 0x90.6 [0x96], 0x0b18                ?
0x0b01: 20 97 14   jb 0x90.7 [0x97], 0x0b18                 ?
0x0b04: 20 23 09   jb 0x24.3 [0x23], 0x0b10                 ?
0x0b07: d2 23      setb 0x24.3 [0x23]                       ?
0x0b09: c2 24      clr 0x24.4 [0x24]                        ?
0x0b0b: 74 43      mov A, #0x43                             ?
0x0b0d: 93         movc A, @A+DPTR                          ?
0x0b0e: f5 3e      mov 0x3e, A                              ?
0x0b10: e5 3e      mov A, 0x3e                              ?
0x0b12: 70 1a      jnz 0x0b2e                               ?
0x0b14: c2 27      clr 0x24.7 [0x27]                        ?
0x0b16: 80 16      sjmp 0x0b2e                              ?
0x0b18: 20 24 0d   jb 0x24.4 [0x24], 0x0b28                 ?
0x0b1b: d2 24      setb 0x24.4 [0x24]                       ?
0x0b1d: c2 23      clr 0x24.3 [0x23]                        ?
0x0b1f: c2 22      clr 0x24.2 [0x22]                        ?
0x0b21: d2 20      setb 0x24.0 [0x20]                       ?
0x0b23: 74 44      mov A, #0x44                             ?
0x0b25: 93         movc A, @A+DPTR                          ?
0x0b26: f5 3e      mov 0x3e, A                              ?
0x0b28: e5 3e      mov A, 0x3e                              ?
0x0b2a: 70 02      jnz 0x0b2e                               ?
0x0b2c: d2 27      setb 0x24.7 [0x27]                       ?
0x0b2e: a2 25      mov C, 0x24.5 [0x25]                     ?
0x0b30: 82 27      anl C, 0x24.7 [0x27]                     ?
0x0b32: 82 20      anl C, 0x24.0 [0x20]                     ?
0x0b34: 92 25      mov 0x24.5 [0x25], C                     ?
0x0b36: 40 0a      jc 0x0b42                                ?
0x0b38: 78 00      mov R0, #0x00                            ?
0x0b3a: 79 80      mov R1, #0x80                            ?
0x0b3c: 88 1c      mov 0x1c, R0                             ?
0x0b3e: 89 1b      mov 0x1b, R1                             ?
0x0b40: c2 22      clr 0x24.2 [0x22]                        ?
0x0b42: 02 10 62   ljmp 0x1062                              ?
0x0b45: 12 04 55   lcall 0x0455                             ?
0x0b48: 74 01      mov A, #0x01                             ?
0x0b4a: 12 05 09   lcall 0x0509                             ?
0x0b4d: 02 10 65   ljmp 0x1065                              ?
0x0b50: 74 46      mov A, #0x46                             ?
0x0b52: 93         movc A, @A+DPTR                          ?
0x0b53: fb         mov R3, A                                ?
0x0b54: c3         clr C                                    ?
0x0b55: e9         mov A, R1                                ?
0x0b56: 9b         subb A, R3                               ?
0x0b57: 40 04      jc 0x0b5d                                ?
0x0b59: 78 00      mov R0, #0x00                            ?
0x0b5b: 80 0a      sjmp 0x0b67                              ?
0x0b5d: 74 47      mov A, #0x47                             ?
0x0b5f: 93         movc A, @A+DPTR                          ?
0x0b60: fb         mov R3, A                                ?
0x0b61: c3         clr C                                    ?
0x0b62: 99         subb A, R1                               ?
0x0b63: 40 24      jc 0x0b89                                ?
0x0b65: 78 ff      mov R0, #0xff                            ?
0x0b67: eb         mov A, R3                                ?
0x0b68: f9         mov R1, A                                ?
0x0b69: 88 1c      mov 0x1c, R0                             ?
0x0b6b: 89 1b      mov 0x1b, R1                             ?
0x0b6d: 20 21 19   jb 0x24.1 [0x21], 0x0b89                 ?
0x0b70: 20 22 10   jb 0x24.2 [0x22], 0x0b83                 ?
0x0b73: 74 45      mov A, #0x45                             ?
0x0b75: 93         movc A, @A+DPTR                          ?
0x0b76: b4 ff 06   cjne A, #0xff, 0x0b7f                    ?
0x0b79: c2 22      clr 0x24.2 [0x22]                        ?
0x0b7b: d2 20      setb 0x24.0 [0x20]                       ?
0x0b7d: 80 0a      sjmp 0x0b89                              ?
0x0b7f: d2 22      setb 0x24.2 [0x22]                       ?
0x0b81: f5 3f      mov 0x3f, A                              ?
0x0b83: e5 3f      mov A, 0x3f                              ?
0x0b85: 70 02      jnz 0x0b89                               ?
0x0b87: c2 20      clr 0x24.0 [0x20]                        ?
0x0b89: 22         ret                                      ?
0x0b8a: 7a 4e      mov R2, #0x4e                            ?
0x0b8c: ea         mov A, R2                                ?
0x0b8d: 93         movc A, @A+DPTR                          ?
0x0b8e: b5 37 00   cjne A, 0x37, 0x0b91                     ?
0x0b91: 40 10      jc 0x0ba3                                ?
0x0b93: ca         xch A, R2                                ?
0x0b94: 04         inc A                                    ?
0x0b95: 93         movc A, @A+DPTR                          ?
0x0b96: ca         xch A, R2                                ?
0x0b97: 9a         subb A, R2                               ?
0x0b98: b5 37 00   cjne A, 0x37, 0x0b9b                     ?
0x0b9b: 50 02      jnc 0x0b9f                               ?
0x0b9d: 80 06      sjmp 0x0ba5                              ?
0x0b9f: d2 95      setb 0x90.5 [0x95]                       ?
0x0ba1: 80 02      sjmp 0x0ba5                              ?
0x0ba3: c2 95      clr 0x90.5 [0x95]                        ?
0x0ba5: 30 1f 07   jnb 0x23.7 [0x1f], 0x0baf                ?
0x0ba8: e5 1b      mov A, 0x1b                              ?
0x0baa: a2 e7      mov C, 0xe0.7 [0xe7]                     ?
0x0bac: 00         nop                                      ?
0x0bad: 92 b1      mov 0xb0.1 [0xb1], C                     ?
0x0baf: 22         ret                                      ?
0x0bb0: 30 25 06   jnb 0x24.5 [0x25], 0x0bb9                ?
0x0bb3: c2 95      clr 0x90.5 [0x95]                        ?
0x0bb5: c2 0b      clr 0x21.3 [0x0b]                        ?
0x0bb7: 80 ec      sjmp 0x0ba5                              ?
0x0bb9: 20 0b 09   jb 0x21.3 [0x0b], 0x0bc5                 ?
0x0bbc: 74 50      mov A, #0x50                             ?
0x0bbe: 93         movc A, @A+DPTR                          ?
0x0bbf: f5 3f      mov 0x3f, A                              ?
0x0bc1: d2 95      setb 0x90.5 [0x95]                       ?
0x0bc3: d2 0b      setb 0x21.3 [0x0b]                       ?
0x0bc5: e5 3f      mov A, 0x3f                              ?
0x0bc7: 70 02      jnz 0x0bcb                               ?
0x0bc9: c2 95      clr 0x90.5 [0x95]                        ?
0x0bcb: 80 d8      sjmp 0x0ba5                              ?
0x0bcd: e5 18      mov A, 0x18                              ?
0x0bcf: 75 f0 01   mov 0xf0, #0x01                          ?
0x0bd2: 80 09      sjmp 0x0bdd                              ?
0x0bd4: f4         cpl A                                    ?
0x0bd5: 04         inc A                                    ?
0x0bd6: 25 19      add A, 0x19                              ?
0x0bd8: 75 f0 10   mov 0xf0, #0x10                          ?
0x0bdb: c2 24      clr 0x24.4 [0x24]                        ?
0x0bdd: a4         mul AB                                   ?
0x0bde: 30 f7 03   jnb 0xf0.7 [0xf7], 0x0be4                ?
0x0be1: 75 f0 7f   mov 0xf0, #0x7f                          ?
0x0be4: 30 02 05   jnb 0x20.2 [0x02], 0x0bec                ?
0x0be7: b3         cpl C                                    ?
0x0be8: f4         cpl A                                    ?
0x0be9: 63 f0 ff   xrl 0xf0, #0xff                          ?
0x0bec: 38         addc A, R0                               ?
0x0bed: f8         mov R0, A                                ?
0x0bee: e5 f0      mov A, 0xf0                              ?
0x0bf0: 39         addc A, R1                               ?
0x0bf1: f9         mov R1, A                                ?
0x0bf2: e4         clr A                                    ?
0x0bf3: 20 02 02   jb 0x20.2 [0x02], 0x0bf8                 ?
0x0bf6: b3         cpl C                                    ?
0x0bf7: f4         cpl A                                    ?
0x0bf8: 40 02      jc 0x0bfc                                ?
0x0bfa: f8         mov R0, A                                ?
0x0bfb: f9         mov R1, A                                ?
0x0bfc: 22         ret                                      ?
0x0bfd: 20 1a 54   jb 0x23.2 [0x1a], 0x0c54                 ?
0x0c00: 7a 44      mov R2, #0x44                            ?
0x0c02: 12 05 1d   lcall 0x051d                             ?
0x0c05: fb         mov R3, A                                ?
0x0c06: 20 09 2f   jb 0x21.1 [0x09], 0x0c38                 ?
0x0c09: b5 49 00   cjne A, 0x49, 0x0c0c                     ?
0x0c0c: 40 04      jc 0x0c12                                ?
0x0c0e: c2 08      clr 0x21.0 [0x08]                        ?
0x0c10: 80 42      sjmp 0x0c54                              ?
0x0c12: 74 52      mov A, #0x52                             ?
0x0c14: 20 08 0a   jb 0x21.0 [0x08], 0x0c21                 ?
0x0c17: d2 08      setb 0x21.0 [0x08]                       ?
0x0c19: 93         movc A, @A+DPTR                          ?
0x0c1a: f5 58      mov 0x58, A                              ?
0x0c1c: 74 54      mov A, #0x54                             ?
0x0c1e: 93         movc A, @A+DPTR                          ?
0x0c1f: f5 59      mov 0x59, A                              ?
0x0c21: e5 58      mov A, 0x58                              ?
0x0c23: 70 2f      jnz 0x0c54                               ?
0x0c25: d2 09      setb 0x21.1 [0x09]                       ?
0x0c27: 74 53      mov A, #0x53                             ?
0x0c29: 93         movc A, @A+DPTR                          ?
0x0c2a: f5 58      mov 0x58, A                              ?
0x0c2c: 74 55      mov A, #0x55                             ?
0x0c2e: 93         movc A, @A+DPTR                          ?
0x0c2f: f5 59      mov 0x59, A                              ?
0x0c31: d2 1d      setb 0x23.5 [0x1d]                       ?
0x0c33: 8d 32      mov 0x32, R5                             ?
0x0c35: 8d 31      mov 0x31, R5                             ?
0x0c37: 22         ret                                      ?
0x0c38: e5 58      mov A, 0x58                              ?
0x0c3a: 70 06      jnz 0x0c42                               ?
0x0c3c: c2 08      clr 0x21.0 [0x08]                        ?
0x0c3e: c2 09      clr 0x21.1 [0x09]                        ?
0x0c40: 80 12      sjmp 0x0c54                              ?
0x0c42: 74 51      mov A, #0x51                             ?
0x0c44: 93         movc A, @A+DPTR                          ?
0x0c45: f4         cpl A                                    ?
0x0c46: 04         inc A                                    ?
0x0c47: 2b         add A, R3                                ?
0x0c48: c3         clr C                                    ?
0x0c49: 95 49      subb A, 0x49                             ?
0x0c4b: 50 07      jnc 0x0c54                               ?
0x0c4d: d2 1d      setb 0x23.5 [0x1d]                       ?
0x0c4f: 8d 32      mov 0x32, R5                             ?
0x0c51: 8d 31      mov 0x31, R5                             ?
0x0c53: 22         ret                                      ?
0x0c54: 02 10 59   ljmp 0x1059                              ?
0x0c57: 15 59      dec 0x59                                 ?
0x0c59: e5 59      mov A, 0x59                              ?
0x0c5b: 70 0f      jnz 0x0c6c                               ?
0x0c5d: 74 54      mov A, #0x54                             ?
0x0c5f: 30 09 01   jnb 0x21.1 [0x09], 0x0c63                ?
0x0c62: 04         inc A                                    ?
0x0c63: 93         movc A, @A+DPTR                          ?
0x0c64: f5 59      mov 0x59, A                              ?
0x0c66: e5 58      mov A, 0x58                              ?
0x0c68: 60 02      jz 0x0c6c                                ?
0x0c6a: 15 58      dec 0x58                                 ?
0x0c6c: 02 10 56   ljmp 0x1056                              ?
0x0c6f: 00         nop                                      ?
0x0c70: 00         nop                                      ?
0x0c71: 00         nop                                      ?
0x0c72: 00         nop                                      ?
0x0c73: 00         nop                                      ?
0x0c74: d2 95      setb 0x90.5 [0x95]                       ?
0x0c76: 22         ret                                      ?
0x0c77: c2 89      clr 0x88.1 [0x89]                        ?
0x0c79: 75 a0 00   mov 0xa0, #0x00                          ?
0x0c7c: f2         movx @R0, A                              ?
0x0c7d: f2         movx @R0, A                              ?
0x0c7e: f2         movx @R0, A                              ?
0x0c7f: f2         movx @R0, A                              ?
0x0c80: 74 0d      mov A, #0x0d                             ?
0x0c82: 93         movc A, @A+DPTR                          ?
0x0c83: f5 f0      mov 0xf0, A                              ?
0x0c85: a2 b3      mov C, 0xb0.3 [0xb3]                     ?
0x0c87: 92 e0      mov 0xe0.0 [0xe0], C                     ?
0x0c89: 7d 00      mov R5, #0x00                            ?
0x0c8b: 7e 02      mov R6, #0x02                            ?
0x0c8d: 7f 02      mov R7, #0x02                            ?
0x0c8f: 33         rlc A                                    ?
0x0c90: 85 f0 2a   mov 0xf0, 0x2a                           ?
0x0c93: 30 17 03   jnb 0x22.7 [0x17], 0x0c99                ?
0x0c96: c2 17      clr 0x22.7 [0x17]                        ?
0x0c98: f2         movx @R0, A                              ?
0x0c99: dd 11      djnz R5, 0x0cac                          ?
0x0c9b: 20 e0 07   jb 0xe0.0 [0xe0], 0x0ca5                 ?
0x0c9e: 7f 02      mov R7, #0x02                            ?
0x0ca0: de 0a      djnz R6, 0x0cac                          ?
0x0ca2: 02 02 4e   ljmp 0x024e                              ?
0x0ca5: 7e 02      mov R6, #0x02                            ?
0x0ca7: df 03      djnz R7, 0x0cac                          ?
0x0ca9: 02 02 4e   ljmp 0x024e                              ?
0x0cac: a2 b3      mov C, 0xb0.3 [0xb3]                     ?
0x0cae: 92 e0      mov 0xe0.0 [0xe0], C                     ?
0x0cb0: 72 e1      orl C, 0xe0.1 [0xe1]                     ?
0x0cb2: 50 0c      jnc 0x0cc0                               ?
0x0cb4: a2 e0      mov C, 0xe0.0 [0xe0]                     ?
0x0cb6: 82 e1      anl C, 0xe0.1 [0xe1]                     ?
0x0cb8: 40 06      jc 0x0cc0                                ?
0x0cba: 7d 00      mov R5, #0x00                            ?
0x0cbc: 7e 02      mov R6, #0x02                            ?
0x0cbe: 7f 02      mov R7, #0x02                            ?
0x0cc0: 33         rlc A                                    ?
0x0cc1: 30 89 cc   jnb 0x88.1 [0x89], 0x0c90                ?
0x0cc4: d2 a8      setb 0xa8.0 [0xa8]                       ?
0x0cc6: c2 1c      clr 0x23.4 [0x1c]                        ?
0x0cc8: 02 10 08   ljmp 0x1008                              ?
0x0ccb: 30 b3 fd   jnb 0xb0.3 [0xb3], 0x0ccb                ?
0x0cce: 20 b3 fd   jb 0xb0.3 [0xb3], 0x0cce                 ?
0x0cd1: 22         ret                                      ?
0x0cd2: 30 b4 07   jnb 0xb0.4 [0xb4], 0x0cdc                ?
0x0cd5: d2 31      setb 0x26.1 [0x31]                       ?
0x0cd7: d2 30      setb 0x26.0 [0x30]                       ?
0x0cd9: 02 0c e0   ljmp 0x0ce0                              ?
0x0cdc: c2 31      clr 0x26.1 [0x31]                        ?
0x0cde: d2 30      setb 0x26.0 [0x30]                       ?
0x0ce0: 02 0f 9a   ljmp 0x0f9a                              ?
0x0ce3: 20 1c 6e   jb 0x23.4 [0x1c], 0x0d54                 ?
0x0ce6: e5 29      mov A, 0x29                              ?
0x0ce8: 60 03      jz 0x0ced                                ?
0x0cea: 14         dec A                                    ?
0x0ceb: f5 29      mov 0x29, A                              ?
0x0ced: 20 b4 1b   jb 0xb0.4 [0xb4], 0x0d0b                 ?
0x0cf0: c2 36      clr 0x26.6 [0x36]                        ?
0x0cf2: 30 31 42   jnb 0x26.1 [0x31], 0x0d37                ?
0x0cf5: 20 30 45   jb 0x26.0 [0x30], 0x0d3d                 ?
0x0cf8: 20 34 06   jb 0x26.4 [0x34], 0x0d01                 ?
0x0cfb: d2 32      setb 0x26.2 [0x32]                       ?
0x0cfd: c2 33      clr 0x26.3 [0x33]                        ?
0x0cff: 80 04      sjmp 0x0d05                              ?
0x0d01: c2 32      clr 0x26.2 [0x32]                        ?
0x0d03: d2 33      setb 0x26.3 [0x33]                       ?
0x0d05: d2 30      setb 0x26.0 [0x30]                       ?
0x0d07: c2 31      clr 0x26.1 [0x31]                        ?
0x0d09: 80 49      sjmp 0x0d54                              ?
0x0d0b: 7a 46      mov R2, #0x46                            ?
0x0d0d: 20 31 11   jb 0x26.1 [0x31], 0x0d21                 ?
0x0d10: 74 58      mov A, #0x58                             ?
0x0d12: 93         movc A, @A+DPTR                          ?
0x0d13: f5 29      mov 0x29, A                              ?
0x0d15: 20 1d 2b   jb 0x23.5 [0x1d], 0x0d43                 ?
0x0d18: 10 36 09   jbc 0x26.6 [0x36], 0x0d24                ?
0x0d1b: a2 34      mov C, 0x26.4 [0x34]                     ?
0x0d1d: 92 35      mov 0x26.5 [0x35], C                     ?
0x0d1f: 80 03      sjmp 0x0d24                              ?
0x0d21: 20 30 19   jb 0x26.0 [0x30], 0x0d3d                 ?
0x0d24: 20 35 01   jb 0x26.5 [0x35], 0x0d28                 ?
0x0d27: 0a         inc R2                                   ?
0x0d28: 12 05 1d   lcall 0x051d                             ?
0x0d2b: c3         clr C                                    ?
0x0d2c: 94 14      subb A, #0x14                            ?
0x0d2e: a2 e7      mov C, 0xe0.7 [0xe7]                     ?
0x0d30: 13         rrc A                                    ?
0x0d31: d2 31      setb 0x26.1 [0x31]                       ?
0x0d33: c2 30      clr 0x26.0 [0x30]                        ?
0x0d35: f5 31      mov 0x31, A                              ?
0x0d37: e5 29      mov A, 0x29                              ?
0x0d39: 70 19      jnz 0x0d54                               ?
0x0d3b: d2 30      setb 0x26.0 [0x30]                       ?
0x0d3d: c2 32      clr 0x26.2 [0x32]                        ?
0x0d3f: c2 33      clr 0x26.3 [0x33]                        ?
0x0d41: 80 11      sjmp 0x0d54                              ?
0x0d43: d2 30      setb 0x26.0 [0x30]                       ?
0x0d45: c2 31      clr 0x26.1 [0x31]                        ?
0x0d47: c2 32      clr 0x26.2 [0x32]                        ?
0x0d49: c2 33      clr 0x26.3 [0x33]                        ?
0x0d4b: 20 36 06   jb 0x26.6 [0x36], 0x0d54                 ?
0x0d4e: a2 34      mov C, 0x26.4 [0x34]                     ?
0x0d50: 92 35      mov 0x26.5 [0x35], C                     ?
0x0d52: d2 36      setb 0x26.6 [0x36]                       ?
0x0d54: 22         ret                                      ?
0x0d55: 20 1c 3e   jb 0x23.4 [0x1c], 0x0d96                 ?
0x0d58: 30 30 3b   jnb 0x26.0 [0x30], 0x0d96                ?
0x0d5b: 20 32 05   jb 0x26.2 [0x32], 0x0d63                 ?
0x0d5e: 20 33 02   jb 0x26.3 [0x33], 0x0d63                 ?
0x0d61: a1 96      ajmp 0x0d96                              ?
0x0d63: d5 34 30   djnz 0x34, 0x0d96                        ?
0x0d66: 90 11 60   mov DPTR, #0x1160                        ?
0x0d69: 74 56      mov A, #0x56                             ?
0x0d6b: 20 32 02   jb 0x26.2 [0x32], 0x0d70                 ?
0x0d6e: 74 57      mov A, #0x57                             ?
0x0d70: 93         movc A, @A+DPTR                          ?
0x0d71: f5 34      mov 0x34, A                              ?
0x0d73: 7a 45      mov R2, #0x45                            ?
0x0d75: 12 05 1d   lcall 0x051d                             ?
0x0d78: fd         mov R5, A                                ?
0x0d79: e5 32      mov A, 0x32                              ?
0x0d7b: fe         mov R6, A                                ?
0x0d7c: af 31      mov R7, 0x31                             ?
0x0d7e: c3         clr C                                    ?
0x0d7f: 9f         subb A, R7                               ?
0x0d80: c3         clr C                                    ?
0x0d81: 20 e7 07   jb 0xe0.7 [0xe7], 0x0d8b                 ?
0x0d84: 9d         subb A, R5                               ?
0x0d85: 40 04      jc 0x0d8b                                ?
0x0d87: ef         mov A, R7                                ?
0x0d88: 2d         add A, R5                                ?
0x0d89: a1 94      ajmp 0x0d94                              ?
0x0d8b: c2 32      clr 0x26.2 [0x32]                        ?
0x0d8d: c2 33      clr 0x26.3 [0x33]                        ?
0x0d8f: 75 34 01   mov 0x34, #0x01                          ?
0x0d92: e5 32      mov A, 0x32                              ?
0x0d94: f5 31      mov 0x31, A                              ?
0x0d96: 22         ret                                      ?
0x0d97: e5 28      mov A, 0x28                              ?
0x0d99: c3         clr C                                    ?
0x0d9a: 95 37      subb A, 0x37                             ?
0x0d9c: 50 0d      jnc 0x0dab                               ?
0x0d9e: f5 f0      mov 0xf0, A                              ?
0x0da0: 74 6d      mov A, #0x6d                             ?
0x0da2: 93         movc A, @A+DPTR                          ?
0x0da3: 25 f0      add A, 0xf0                              ?
0x0da5: 40 04      jc 0x0dab                                ?
0x0da7: c2 34      clr 0x26.4 [0x34]                        ?
0x0da9: 80 02      sjmp 0x0dad                              ?
0x0dab: d2 34      setb 0x26.4 [0x34]                       ?
0x0dad: 85 37 28   mov 0x37, 0x28                           ?
0x0db0: 22         ret                                      ?
0x0db1: 20 1c 0c   jb 0x23.4 [0x1c], 0x0dc0                 ?
0x0db4: 30 30 13   jnb 0x26.0 [0x30], 0x0dca                ?
0x0db7: 20 16 09   jb 0x22.6 [0x16], 0x0dc3                 ?
0x0dba: 20 32 0d   jb 0x26.2 [0x32], 0x0dca                 ?
0x0dbd: 20 33 0a   jb 0x26.3 [0x33], 0x0dca                 ?
0x0dc0: 02 00 f3   ljmp 0x00f3                              ?
0x0dc3: c2 32      clr 0x26.2 [0x32]                        ?
0x0dc5: c2 33      clr 0x26.3 [0x33]                        ?
0x0dc7: 02 00 f3   ljmp 0x00f3                              ?
0x0dca: 02 01 2c   ljmp 0x012c                              ?
0x0dcd: 20 1c 11   jb 0x23.4 [0x1c], 0x0de1                 ?
0x0dd0: 20 1d 0a   jb 0x23.5 [0x1d], 0x0ddd                 ?
0x0dd3: 20 30 0b   jb 0x26.0 [0x30], 0x0de1                 ?
0x0dd6: c2 15      clr 0x22.5 [0x15]                        ?
0x0dd8: c2 16      clr 0x22.6 [0x16]                        ?
0x0dda: 02 07 a7   ljmp 0x07a7                              ?
0x0ddd: c2 32      clr 0x26.2 [0x32]                        ?
0x0ddf: c2 33      clr 0x26.3 [0x33]                        ?
0x0de1: 02 07 08   ljmp 0x0708                              ?
0x0de4: 02 10 80   ljmp 0x1080                              ?
0x0de7: e1 06      ajmp 0x0f06                              ?
0x0de9: 75 27 00   mov 0x27, #0x00                          ?
0x0dec: c2 28      clr 0x25.0 [0x28]                        ?
0x0dee: f1 21      acall 0x0f21                             ?
0x0df0: 74 5f      mov A, #0x5f                             ?
0x0df2: 93         movc A, @A+DPTR                          ?
0x0df3: 95 13      subb A, 0x13                             ?
0x0df5: b3         cpl C                                    ?
0x0df6: 92 3c      mov 0x27.4 [0x3c], C                     ?
0x0df8: a2 25      mov C, 0x24.5 [0x25]                     ?
0x0dfa: b3         cpl C                                    ?
0x0dfb: 92 3d      mov 0x27.5 [0x3d], C                     ?
0x0dfd: 74 60      mov A, #0x60                             ?
0x0dff: 93         movc A, @A+DPTR                          ?
0x0e00: 95 12      subb A, 0x12                             ?
0x0e02: 92 3e      mov 0x27.6 [0x3e], C                     ?
0x0e04: 78 5c      mov R0, #0x5c                            ?
0x0e06: 74 5d      mov A, #0x5d                             ?
0x0e08: 30 39 03   jnb 0x27.1 [0x39], 0x0e0e                ?
0x0e0b: 78 59      mov R0, #0x59                            ?
0x0e0d: 04         inc A                                    ?
0x0e0e: 93         movc A, @A+DPTR                          ?
0x0e0f: f5 f0      mov 0xf0, A                              ?
0x0e11: 02 10 83   ljmp 0x1083                              ?
0x0e14: e5 27      mov A, 0x27                              ?
0x0e16: 54 78      anl A, #0x78                             ?
0x0e18: 60 02      jz 0x0e1c                                ?
0x0e1a: c1 c3      ajmp 0x0ec3                              ?
0x0e1c: 74 59      mov A, #0x59                             ?
0x0e1e: 93         movc A, @A+DPTR                          ?
0x0e1f: f4         cpl A                                    ?
0x0e20: 04         inc A                                    ?
0x0e21: 25 59      add A, 0x59                              ?
0x0e23: 25 1b      add A, 0x1b                              ?
0x0e25: fb         mov R3, A                                ?
0x0e26: c3         clr C                                    ?
0x0e27: 96         subb A, @R0                              ?
0x0e28: 92 02      mov 0x20.2 [0x02], C                     ?
0x0e2a: 50 02      jnc 0x0e2e                               ?
0x0e2c: f4         cpl A                                    ?
0x0e2d: 04         inc A                                    ?
0x0e2e: a4         mul AB                                   ?
0x0e2f: ae f0      mov R6, 0xf0                             ?
0x0e31: fd         mov R5, A                                ?
0x0e32: 08         inc R0                                   ?
0x0e33: 20 02 19   jb 0x20.2 [0x02], 0x0e4f                 ?
0x0e36: e6         mov A, @R0                               ?
0x0e37: 2d         add A, R5                                ?
0x0e38: f6         mov @R0, A                               ?
0x0e39: 08         inc R0                                   ?
0x0e3a: e6         mov A, @R0                               ?
0x0e3b: 3e         addc A, R6                               ?
0x0e3c: f6         mov @R0, A                               ?
0x0e3d: 50 30      jnc 0x0e6f                               ?
0x0e3f: c3         clr C                                    ?
0x0e40: 94 80      subb A, #0x80                            ?
0x0e42: f6         mov @R0, A                               ?
0x0e43: 18         dec R0                                   ?
0x0e44: 18         dec R0                                   ?
0x0e45: 74 5a      mov A, #0x5a                             ?
0x0e47: 93         movc A, @A+DPTR                          ?
0x0e48: d3         setb C                                   ?
0x0e49: 96         subb A, @R0                              ?
0x0e4a: 40 23      jc 0x0e6f                                ?
0x0e4c: 06         inc @R0                                  ?
0x0e4d: 80 17      sjmp 0x0e66                              ?
0x0e4f: c3         clr C                                    ?
0x0e50: e6         mov A, @R0                               ?
0x0e51: 9d         subb A, R5                               ?
0x0e52: f6         mov @R0, A                               ?
0x0e53: 08         inc R0                                   ?
0x0e54: e6         mov A, @R0                               ?
0x0e55: 9e         subb A, R6                               ?
0x0e56: f6         mov @R0, A                               ?
0x0e57: 50 16      jnc 0x0e6f                               ?
0x0e59: 24 80      add A, #0x80                             ?
0x0e5b: f6         mov @R0, A                               ?
0x0e5c: 18         dec R0                                   ?
0x0e5d: 18         dec R0                                   ?
0x0e5e: 74 5b      mov A, #0x5b                             ?
0x0e60: 93         movc A, @A+DPTR                          ?
0x0e61: c3         clr C                                    ?
0x0e62: 96         subb A, @R0                              ?
0x0e63: 50 0a      jnc 0x0e6f                               ?
0x0e65: 16         dec @R0                                  ?
0x0e66: 30 39 06   jnb 0x27.1 [0x39], 0x0e6f                ?
0x0e69: e6         mov A, @R0                               ?
0x0e6a: 78 06      mov R0, #0x06                            ?
0x0e6c: 12 1d f2   lcall 0x1df2                             ?
0x0e6f: c3         clr C                                    ?
0x0e70: 74 59      mov A, #0x59                             ?
0x0e72: 93         movc A, @A+DPTR                          ?
0x0e73: 95 59      subb A, 0x59                             ?
0x0e75: 2b         add A, R3                                ?
0x0e76: f5 1b      mov 0x1b, A                              ?
0x0e78: 20 39 48   jb 0x27.1 [0x39], 0x0ec3                 ?
0x0e7b: 02 10 86   ljmp 0x1086                              ?
0x0e7e: d5 63 42   djnz 0x63, 0x0ec3                        ?
0x0e81: 74 5c      mov A, #0x5c                             ?
0x0e83: 93         movc A, @A+DPTR                          ?
0x0e84: f5 63      mov 0x63, A                              ?
0x0e86: c3         clr C                                    ?
0x0e87: e5 5c      mov A, 0x5c                              ?
0x0e89: 95 59      subb A, 0x59                             ?
0x0e8b: 50 02      jnc 0x0e8f                               ?
0x0e8d: f4         cpl A                                    ?
0x0e8e: 04         inc A                                    ?
0x0e8f: 92 02      mov 0x20.2 [0x02], C                     ?
0x0e91: 75 f0 01   mov 0xf0, #0x01                          ?
0x0e94: 30 38 0f   jnb 0x27.0 [0x38], 0x0ea6                ?
0x0e97: a9 5f      mov R1, 0x5f                             ?
0x0e99: a8 60      mov R0, 0x60                             ?
0x0e9b: 71 dd      acall 0x0bdd                             ?
0x0e9d: 85 5f f0   mov 0x5f, 0xf0                           ?
0x0ea0: 89 5f      mov 0x5f, R1                             ?
0x0ea2: 88 60      mov 0x60, R0                             ?
0x0ea4: 80 0d      sjmp 0x0eb3                              ?
0x0ea6: a9 61      mov R1, 0x61                             ?
0x0ea8: a8 62      mov R0, 0x62                             ?
0x0eaa: 71 dd      acall 0x0bdd                             ?
0x0eac: 85 61 f0   mov 0x61, 0xf0                           ?
0x0eaf: 89 61      mov 0x61, R1                             ?
0x0eb1: 88 62      mov 0x62, R0                             ?
0x0eb3: e9         mov A, R1                                ?
0x0eb4: 78 0c      mov R0, #0x0c                            ?
0x0eb6: 20 38 02   jb 0x27.0 [0x38], 0x0ebb                 ?
0x0eb9: 78 12      mov R0, #0x12                            ?
0x0ebb: b5 f0 02   cjne A, 0xf0, 0x0ec0                     ?
0x0ebe: 80 03      sjmp 0x0ec3                              ?
0x0ec0: 12 1d f2   lcall 0x1df2                             ?
0x0ec3: 02 10 89   ljmp 0x1089                              ?
0x0ec6: c3         clr C                                    ?
0x0ec7: e5 5f      mov A, 0x5f                              ?
0x0ec9: 94 80      subb A, #0x80                            ?
0x0ecb: 92 d5      mov 0xd0.5 [0xd5], C                     ?
0x0ecd: 50 02      jnc 0x0ed1                               ?
0x0ecf: f4         cpl A                                    ?
0x0ed0: 04         inc A                                    ?
0x0ed1: f9         mov R1, A                                ?
0x0ed2: ab 37      mov R3, 0x37                             ?
0x0ed4: 85 37 f0   mov 0x37, 0xf0                           ?
0x0ed7: 74 32      mov A, #0x32                             ?
0x0ed9: 84         div AB                                   ?
0x0eda: ff         mov R7, A                                ?
0x0edb: 12 04 ea   lcall 0x04ea                             ?
0x0ede: fe         mov R6, A                                ?
0x0edf: e9         mov A, R1                                ?
0x0ee0: 12 04 d9   lcall 0x04d9                             ?
0x0ee3: ef         mov A, R7                                ?
0x0ee4: 60 02      jz 0x0ee8                                ?
0x0ee6: 7e ff      mov R6, #0xff                            ?
0x0ee8: ee         mov A, R6                                ?
0x0ee9: c3         clr C                                    ?
0x0eea: 13         rrc A                                    ?
0x0eeb: 24 80      add A, #0x80                             ?
0x0eed: 30 d5 02   jnb 0xd0.5 [0xd5], 0x0ef2                ?
0x0ef0: f4         cpl A                                    ?
0x0ef1: 00         nop                                      ?
0x0ef2: 25 61      add A, 0x61                              ?
0x0ef4: b3         cpl C                                    ?
0x0ef5: 92 d5      mov 0xd0.5 [0xd5], C                     ?
0x0ef7: 50 02      jnc 0x0efb                               ?
0x0ef9: f4         cpl A                                    ?
0x0efa: 00         nop                                      ?
0x0efb: 70 02      jnz 0x0eff                               ?
0x0efd: c2 d5      clr 0xd0.5 [0xd5]                        ?
0x0eff: f5 58      mov 0x58, A                              ?
0x0f01: a2 d5      mov C, 0xd0.5 [0xd5]                     ?
0x0f03: 92 29      mov 0x25.1 [0x29], C                     ?
0x0f05: 22         ret                                      ?
0x0f06: e5 49      mov A, 0x49                              ?
0x0f08: 85 37 f0   mov 0x37, 0xf0                           ?
0x0f0b: a4         mul AB                                   ?
0x0f0c: af f0      mov R7, 0xf0                             ?
0x0f0e: fe         mov R6, A                                ?
0x0f0f: 74 a4      mov A, #0xa4                             ?
0x0f11: 12 04 d9   lcall 0x04d9                             ?
0x0f14: 74 02      mov A, #0x02                             ?
0x0f16: 12 05 09   lcall 0x0509                             ?
0x0f19: 60 02      jz 0x0f1d                                ?
0x0f1b: 7f ff      mov R7, #0xff                            ?
0x0f1d: ef         mov A, R7                                ?
0x0f1e: fc         mov R4, A                                ?
0x0f1f: a1 e9      ajmp 0x0de9                              ?
0x0f21: 02 10 8c   ljmp 0x108c                              ?
0x0f24: c3         clr C                                    ?
0x0f25: 74 63      mov A, #0x63                             ?
0x0f27: 93         movc A, @A+DPTR                          ?
0x0f28: 9c         subb A, R4                               ?
0x0f29: 50 0a      jnc 0x0f35                               ?
0x0f2b: 74 64      mov A, #0x64                             ?
0x0f2d: 93         movc A, @A+DPTR                          ?
0x0f2e: c3         clr C                                    ?
0x0f2f: 95 49      subb A, 0x49                             ?
0x0f31: 92 39      mov 0x27.1 [0x39], C                     ?
0x0f33: 80 30      sjmp 0x0f65                              ?
0x0f35: 74 62      mov A, #0x62                             ?
0x0f37: 93         movc A, @A+DPTR                          ?
0x0f38: 95 37      subb A, 0x37                             ?
0x0f3a: 40 09      jc 0x0f45                                ?
0x0f3c: 74 61      mov A, #0x61                             ?
0x0f3e: 93         movc A, @A+DPTR                          ?
0x0f3f: 9c         subb A, R4                               ?
0x0f40: b3         cpl C                                    ?
0x0f41: 92 38      mov 0x27.0 [0x38], C                     ?
0x0f43: 80 20      sjmp 0x0f65                              ?
0x0f45: 74 66      mov A, #0x66                             ?
0x0f47: 93         movc A, @A+DPTR                          ?
0x0f48: c3         clr C                                    ?
0x0f49: 95 37      subb A, 0x37                             ?
0x0f4b: 50 18      jnc 0x0f65                               ?
0x0f4d: 74 65      mov A, #0x65                             ?
0x0f4f: 93         movc A, @A+DPTR                          ?
0x0f50: c3         clr C                                    ?
0x0f51: 9c         subb A, R4                               ?
0x0f52: 40 11      jc 0x0f65                                ?
0x0f54: 74 67      mov A, #0x67                             ?
0x0f56: 93         movc A, @A+DPTR                          ?
0x0f57: 95 49      subb A, 0x49                             ?
0x0f59: 50 0a      jnc 0x0f65                               ?
0x0f5b: 74 68      mov A, #0x68                             ?
0x0f5d: 93         movc A, @A+DPTR                          ?
0x0f5e: c3         clr C                                    ?
0x0f5f: 95 49      subb A, 0x49                             ?
0x0f61: 40 02      jc 0x0f65                                ?
0x0f63: d2 3a      setb 0x27.2 [0x3a]                       ?
0x0f65: e5 27      mov A, 0x27                              ?
0x0f67: 54 07      anl A, #0x07                             ?
0x0f69: 70 02      jnz 0x0f6d                               ?
0x0f6b: d2 3b      setb 0x27.3 [0x3b]                       ?
0x0f6d: 22         ret                                      ?
0x0f6e: 74 59      mov A, #0x59                             ?
0x0f70: 93         movc A, @A+DPTR                          ?
0x0f71: f4         cpl A                                    ?
0x0f72: 04         inc A                                    ?
0x0f73: 25 59      add A, 0x59                              ?
0x0f75: 29         add A, R1                                ?
0x0f76: f9         mov R1, A                                ?
0x0f77: 61 45      ajmp 0x0b45                              ?
0x0f79: e5 58      mov A, 0x58                              ?
0x0f7b: 75 f0 04   mov 0xf0, #0x04                          ?
0x0f7e: a4         mul AB                                   ?
0x0f7f: 30 29 05   jnb 0x25.1 [0x29], 0x0f87                ?
0x0f82: b3         cpl C                                    ?
0x0f83: f4         cpl A                                    ?
0x0f84: 63 f0 ff   xrl 0xf0, #0xff                          ?
0x0f87: 3e         addc A, R6                               ?
0x0f88: fe         mov R6, A                                ?
0x0f89: e5 f0      mov A, 0xf0                              ?
0x0f8b: 3f         addc A, R7                               ?
0x0f8c: ff         mov R7, A                                ?
0x0f8d: e4         clr A                                    ?
0x0f8e: 20 29 02   jb 0x25.1 [0x29], 0x0f93                 ?
0x0f91: b3         cpl C                                    ?
0x0f92: f4         cpl A                                    ?
0x0f93: 40 02      jc 0x0f97                                ?
0x0f95: ff         mov R7, A                                ?
0x0f96: fe         mov R6, A                                ?
0x0f97: 02 01 be   ljmp 0x01be                              ?
0x0f9a: 75 89 11   mov 0x89, #0x11                          ?
0x0f9d: 75 b8 02   mov 0xb8, #0x02                          ?
0x0fa0: 43 a8 85   orl 0xa8, #0x85                          ?
0x0fa3: 43 88 05   orl 0x88, #0x05                          ?
0x0fa6: 90 11 60   mov DPTR, #0x1160                        ?
0x0fa9: 75 81 63   mov 0x81, #0x63                          ?
0x0fac: c2 92      clr 0x90.2 [0x92]                        ?
0x0fae: 74 0d      mov A, #0x0d                             ?
0x0fb0: 93         movc A, @A+DPTR                          ?
0x0fb1: f5 2a      mov 0x2a, A                              ?
0x0fb3: 12 06 3f   lcall 0x063f                             ?
0x0fb6: 12 10 1a   lcall 0x101a                             ?
0x0fb9: 12 0f e7   lcall 0x0fe7                             ?
0x0fbc: 12 06 59   lcall 0x0659                             ?
0x0fbf: 12 0f e7   lcall 0x0fe7                             ?
0x0fc2: 12 06 8f   lcall 0x068f                             ?
0x0fc5: 12 10 1a   lcall 0x101a                             ?
0x0fc8: 12 0f e7   lcall 0x0fe7                             ?
0x0fcb: 12 07 b7   lcall 0x07b7                             ?
0x0fce: 12 0f e7   lcall 0x0fe7                             ?
0x0fd1: 12 10 1a   lcall 0x101a                             ?
0x0fd4: 12 07 be   lcall 0x07be                             ?
0x0fd7: 12 0f e7   lcall 0x0fe7                             ?
0x0fda: 02 10 1d   ljmp 0x101d                              ?
0x0fdd: 30 1c ba   jnb 0x23.4 [0x1c], 0x0f9a                ?
0x0fe0: 12 02 1d   lcall 0x021d                             ?
0x0fe3: 12 03 0c   lcall 0x030c                             ?
0x0fe6: 22         ret                                      ?
0x0fe7: 10 17 01   jbc 0x22.7 [0x17], 0x0feb                ?
0x0fea: 22         ret                                      ?
0x0feb: 02 02 c6   ljmp 0x02c6                              ?
0x0fee: ff         mov R7, A                                ?
0x0fef: ff         mov R7, A                                ?
0x0ff0: ff         mov R7, A                                ?
0x0ff1: ff         mov R7, A                                ?
0x0ff2: ff         mov R7, A                                ?
0x0ff3: ff         mov R7, A                                ?
0x0ff4: ff         mov R7, A                                ?
0x0ff5: ff         mov R7, A                                ?
0x0ff6: ff         mov R7, A                                ?
0x0ff7: ff         mov R7, A                                ?
0x0ff8: ff         mov R7, A                                ?
0x0ff9: ff         mov R7, A                                ?
0x0ffa: ff         mov R7, A                                ?
0x0ffb: ff         mov R7, A                                ?
0x0ffc: ff         mov R7, A                                ?
0x0ffd: ff         mov R7, A                                ?
0x0ffe: 00         nop                                      ?
0x0fff: 42 c2      orl 0xc2, A                              ?
0x1001: 95 02      subb A, 0x02                             ?
0x1003: 0c         inc R4                                   ?
0x1004: 6f         xrl A, R7                                ?
0x1005: 02 1f 4e   ljmp 0x1f4e                              ?
0x1008: 02 1f 3a   ljmp 0x1f3a                              ?
0x100b: 02 02 72   ljmp 0x0272                              ?
0x100e: 12 1e 53   lcall 0x1e53                             ?
0x1011: 02 02 78   ljmp 0x0278                              ?
0x1014: ff         mov R7, A                                ?
0x1015: ff         mov R7, A                                ?
0x1016: ff         mov R7, A                                ?
0x1017: 02 0c 77   ljmp 0x0c77                              ?
0x101a: 02 1e 6d   ljmp 0x1e6d                              ?
0x101d: 02 1f 7d   ljmp 0x1f7d                              ?
0x1020: ff         mov R7, A                                ?
0x1021: ff         mov R7, A                                ?
0x1022: ff         mov R7, A                                ?
0x1023: ff         mov R7, A                                ?
0x1024: ff         mov R7, A                                ?
0x1025: ff         mov R7, A                                ?
0x1026: ff         mov R7, A                                ?
0x1027: ff         mov R7, A                                ?
0x1028: ff         mov R7, A                                ?
0x1029: 02 00 f3   ljmp 0x00f3                              ?
0x102c: 02 01 77   ljmp 0x0177                              ?
0x102f: 02 01 be   ljmp 0x01be                              ?
0x1032: 02 04 08   ljmp 0x0408                              ?
0x1035: 02 1f 8e   ljmp 0x1f8e                              ?
0x1038: 02 1b 30   ljmp 0x1b30                              ?
0x103b: 22         ret                                      ?
0x103c: ff         mov R7, A                                ?
0x103d: ff         mov R7, A                                ?
0x103e: 02 0c 57   ljmp 0x0c57                              ?
0x1041: ff         mov R7, A                                ?
0x1042: ff         mov R7, A                                ?
0x1043: ff         mov R7, A                                ?
0x1044: ff         mov R7, A                                ?
0x1045: ff         mov R7, A                                ?
0x1046: ff         mov R7, A                                ?
0x1047: 02 1b d0   ljmp 0x1bd0                              ?
0x104a: 02 1c 8f   ljmp 0x1c8f                              ?
0x104d: 02 0b fd   ljmp 0x0bfd                              ?
0x1050: 02 1d e0   ljmp 0x1de0                              ?
0x1053: 02 1b 39   ljmp 0x1b39                              ?
0x1056: 02 08 92   ljmp 0x0892                              ?
0x1059: 02 07 08   ljmp 0x0708                              ?
0x105c: 02 1c b7   ljmp 0x1cb7                              ?
0x105f: 02 1e 00   ljmp 0x1e00                              ?
0x1062: 02 0b 45   ljmp 0x0b45                              ?
0x1065: 02 0b a5   ljmp 0x0ba5                              ?
0x1068: 02 08 95   ljmp 0x0895                              ?
0x106b: 02 08 e1   ljmp 0x08e1                              ?
0x106e: 02 09 07   ljmp 0x0907                              ?
0x1071: 02 09 42   ljmp 0x0942                              ?
0x1074: 02 1b 82   ljmp 0x1b82                              ?
0x1077: 02 09 c8   ljmp 0x09c8                              ?
0x107a: 02 09 ef   ljmp 0x09ef                              ?
0x107d: 02 1b 40   ljmp 0x1b40                              ?
0x1080: 02 ff ff   ljmp 0xffff                              ?
0x1083: 02 ff ff   ljmp 0xffff                              ?
0x1086: 02 ff ff   ljmp 0xffff                              ?
0x1089: 02 ff ff   ljmp 0xffff                              ?
0x108c: 02 ff ff   ljmp 0xffff                              ?
0x108f: ff         mov R7, A                                ?
0x1090: 00         nop                                      ?
0x1091: 02 02 1a   ljmp 0x021a                              ?
0x1094: 10 74 76   jbc 0x2e.4 [0x74], 0x110d                ?
0x1097: 78 0e      mov R0, #0x0e                            ?
0x1099: 6e         xrl A, R6                                ?
0x109a: 70 72      jnz 0x110e                               ?
0x109c: 0c         inc R4                                   ?
0x109d: 0a         inc R2                                   ?
0x109e: 08         inc R0                                   ?
0x109f: 68         xrl A, R0                                ?
0x10a0: 6a         xrl A, R2                                ?
0x10a1: 6c         xrl A, R4                                ?
0x10a2: 12 7a 7c   lcall 0x7a7c                             ?
0x10a5: 7e ff      mov R6, #0xff                            ?
0x10a7: ff         mov R7, A                                ?
0x10a8: 19         dec R1                                   ?
0x10a9: 1c         dec R4                                   ?
0x10aa: 38         addc A, R0                               ?
0x10ab: 3a         addc A, R2                               ?
0x10ac: 44 42      orl A, #0x42                             ?
0x10ae: 9e         subb A, R6                               ?
0x10af: a0 a2      orl C, /0xa0.2 [0xa2]                    ?
0x10b1: 3c         addc A, R4                               ?
0x10b2: 3e         addc A, R6                               ?
0x10b3: 98         subb A, R0                               ?
0x10b4: 9a         subb A, R2                               ?
0x10b5: 9c         subb A, R4                               ?
0x10b6: 41 ff      ajmp 0x12ff                              ?
0x10b8: 2e         add A, R6                                ?
0x10b9: 20 1e 22   jb 0x23.6 [0x1e], 0x10de                 ?
0x10bc: 80 82      sjmp 0x1040                              ?
0x10be: 84         div AB                                   ?
0x10bf: 25 26      add A, 0x26                              ?
0x10c1: 2a         add A, R2                                ?
0x10c2: 8c 8e      mov 0x8e, R4                             ?
0x10c4: 90 46 48   mov DPTR, #0x4648                        ?
0x10c7: 4a         orl A, R2                                ?
0x10c8: 4c         orl A, R4                                ?
0x10c9: 4e         orl A, R6                                ?
0x10ca: 50 52      jnc 0x111e                               ?
0x10cc: 55 ff      anl A, 0xff                              ?
0x10ce: 59         anl A, R1                                ?
0x10cf: 5b         anl A, R3                                ?
0x10d0: 5d         anl A, R5                                ?
0x10d1: 59         anl A, R1                                ?
0x10d2: 5b         anl A, R3                                ?
0x10d3: 61 5e      ajmp 0x135e                              ?
0x10d5: ff         mov R7, A                                ?
0x10d6: ff         mov R7, A                                ?
0x10d7: ff         mov R7, A                                ?
0x10d8: 04         inc A                                    ?
0x10d9: 14         dec A                                    ?
0x10da: 16         dec @R0                                  ?
0x10db: 2c         add A, R4                                ?
0x10dc: 92 94      mov 0x90.4 [0x94], C                     ?
0x10de: 96         subb A, @R0                              ?
0x10df: 29         add A, R1                                ?
0x10e0: 87 89      mov 0x89, @R1                            ?
0x10e2: 8b 30      mov 0x30, R3                             ?
0x10e4: 32         reti                                     ?
0x10e5: 34 36      addc A, #0x36                            ?
0x10e7: 56         anl A, @R0                               ?
0x10e8: a4         mul AB                                   ?
0x10e9: a6 a8      mov @R0, 0xa8                            ?
0x10eb: 07         inc @R1                                  ?
0x10ec: 63 65 67   xrl 0x65, #0x67                          ?
0x10ef: ff         mov R7, A                                ?
0x10f0: ff         mov R7, A                                ?
0x10f1: ff         mov R7, A                                ?
0x10f2: ff         mov R7, A                                ?
0x10f3: ff         mov R7, A                                ?
0x10f4: ae a0      mov R6, 0xa0                             ?
0x10f6: 93         movc A, @A+DPTR                          ?
0x10f7: 87 f7      mov 0xf7, @R1                            ?
0x10f9: e3         movx A, @R1                              ?
0x10fa: d0 bf      pop 0xbf                                 ?
0x10fc: 01 02      ajmp 0x1002                              ?
0x10fe: 03         rr A                                     ?
0x10ff: 04         inc A                                    ?
0x1100: 04         inc A                                    ?
0x1101: 05 06      inc 0x06                                 ?
0x1103: 07         inc @R1                                  ?
0x1104: 81 84      ajmp 0x1484                              ?
0x1106: 86 89      mov 0x89, @R0                            ?
0x1108: 8b 8e      mov 0x8e, R3                             ?
0x110a: 91 94      acall 0x1494                             ?
0x110c: 96         subb A, @R0                              ?
0x110d: 99         subb A, R1                               ?
0x110e: 9c         subb A, R4                               ?
0x110f: 9f         subb A, R7                               ?
0x1110: a2 a5      mov C, 0xa0.5 [0xa5]                     ?
0x1112: a9 ac      mov R1, 0xac                             ?
0x1114: af b2      mov R7, 0xb2                             ?
0x1116: b6 b9 bd   cjne @R0, #0xb9, 0x10d6                  ?
0x1119: c1 c4      ajmp 0x16c4                              ?
0x111b: c8         xch A, R0                                ?
0x111c: cc         xch A, R4                                ?
0x111d: d0 d4      pop 0xd4                                 ?
0x111f: d8 dc      djnz R0, 0x10fd                          ?
0x1121: e0         movx A, @DPTR                            ?
0x1122: e4         clr A                                    ?
0x1123: e9         mov A, R1                                ?
0x1124: 16         dec @R0                                  ?
0x1125: 04         inc A                                    ?
0x1126: 89 2f      mov 0x2f, R1                             ?
0x1128: 2f         add A, R7                                ?
0x1129: 19         dec R1                                   ?
0x112a: 03         rr A                                     ?
0x112b: 02 01 00   ljmp 0x0100                              ?
0x112e: 17         dec @R1                                  ?
0x112f: 08         inc R0                                   ?
0x1130: 23         rl A                                     ?
0x1131: 26         add A, @R0                               ?
0x1132: 1d         dec R5                                   ?
0x1133: 14         dec A                                    ?
0x1134: 0e         inc R6                                   ?
0x1135: 0e         inc R6                                   ?
0x1136: 0a         inc R2                                   ?
0x1137: 60 00      jz 0x1139                                ?
0x1139: 01 02      ajmp 0x1002                              ?
0x113b: 03         rr A                                     ?
0x113c: 04         inc A                                    ?
0x113d: 05 06      inc 0x06                                 ?
0x113f: 07         inc @R1                                  ?
0x1140: 5a         anl A, R2                                ?
0x1141: 33         rlc A                                    ?
0x1142: 47         orl A, @R1                               ?
0x1143: 40 40      jc 0x1185                                ?
0x1145: 40 40      jc 0x1187                                ?
0x1147: 40 40      jc 0x1189                                ?
0x1149: 40 40      jc 0x118b                                ?
0x114b: 40 40      jc 0x118d                                ?
0x114d: 40 40      jc 0x118f                                ?
0x114f: 40 3a      jc 0x118b                                ?
0x1151: 3b         addc A, R3                               ?
0x1152: 3d         addc A, R5                               ?
0x1153: 3e         addc A, R6                               ?
0x1154: 3f         addc A, R7                               ?
0x1155: 3f         addc A, R7                               ?
0x1156: 3f         addc A, R7                               ?
0x1157: 3f         addc A, R7                               ?
0x1158: 3f         addc A, R7                               ?
0x1159: 40 40      jc 0x119b                                ?
0x115b: 40 40      jc 0x119d                                ?
0x115d: 40 40      jc 0x119f                                ?
0x115f: 40 2c      jc 0x118d                                ?
0x1161: 02 fc 42   ljmp 0xfc42                              ?
0x1164: 42 00      orl 0x00, A                              ?
0x1166: 00         nop                                      ?
0x1167: 84         div AB                                   ?
0x1168: 84         div AB                                   ?
0x1169: 00         nop                                      ?
0x116a: 00         nop                                      ?
0x116b: 31 16      acall 0x1116                             ?
0x116d: 1e         dec R6                                   ?
0x116e: 0a         inc R2                                   ?
0x116f: 06         inc @R0                                  ?
0x1170: 04         inc A                                    ?
0x1171: a2 1f      mov C, 0x23.7 [0x1f]                     ?
0x1173: dc 11      djnz R4, 0x1186                          ?
0x1175: 08         inc R0                                   ?
0x1176: 01 ff      ajmp 0x10ff                              ?
0x1178: 40 5a      jc 0x11d4                                ?
0x117a: 0c         inc R4                                   ?
0x117b: 80 84      sjmp 0x1101                              ?
0x117d: 7c 88      mov R4, #0x88                            ?
0x117f: a2 50      mov C, 0x2a.0 [0x50]                     ?
0x1181: 28         add A, R0                                ?
0x1182: fc         mov R4, A                                ?
0x1183: 49         orl A, R1                                ?
0x1184: f9         mov R1, A                                ?
0x1185: 3c         addc A, R4                               ?
0x1186: 14         dec A                                    ?
0x1187: 08         inc R0                                   ?
0x1188: 01 01      ajmp 0x1001                              ?
0x118a: 08         inc R0                                   ?
0x118b: 01 02      ajmp 0x1002                              ?
0x118d: 01 01      ajmp 0x1001                              ?
0x118f: f9         mov R1, A                                ?
0x1190: ff         mov R7, A                                ?
0x1191: 09         inc R1                                   ?
0x1192: 09         inc R1                                   ?
0x1193: 24 05      add A, #0x05                             ?
0x1195: 01 1e      ajmp 0x101e                              ?
0x1197: 3e         addc A, R6                               ?
0x1198: 04         inc A                                    ?
0x1199: 15 18      dec 0x18                                 ?
0x119b: 00         nop                                      ?
0x119c: 17         dec @R1                                  ?
0x119d: c0 27      push 0x27                                ?
0x119f: 02 01 8a   ljmp 0x018a                              ?
0x11a2: 42 42      orl 0x42, A                              ?
0x11a4: 09         inc R1                                   ?
0x11a5: ff         mov R7, A                                ?
0x11a6: 93         movc A, @A+DPTR                          ?
0x11a7: 60 58      jz 0x1201                                ?
0x11a9: 58         anl A, R0                                ?
0x11aa: 07         inc @R1                                  ?
0x11ab: 8e 66      mov 0x66, R6                             ?
0x11ad: 06         inc @R0                                  ?
0x11ae: 4b         orl A, R3                                ?
0x11af: 05 ff      inc 0xff                                 ?
0x11b1: 32         reti                                     ?
0x11b2: 1a         dec R2                                   ?
0x11b3: 1d         dec R5                                   ?
0x11b4: 0a         inc R2                                   ?
0x11b5: b4 ff ff   cjne A, #0xff, 0x11b7                    ?
0x11b8: ff         mov R7, A                                ?
0x11b9: ff         mov R7, A                                ?
0x11ba: ff         mov R7, A                                ?
0x11bb: ff         mov R7, A                                ?
0x11bc: ff         mov R7, A                                ?
0x11bd: ff         mov R7, A                                ?
0x11be: ff         mov R7, A                                ?
0x11bf: ff         mov R7, A                                ?
0x11c0: ff         mov R7, A                                ?
0x11c1: ff         mov R7, A                                ?
0x11c2: ff         mov R7, A                                ?
0x11c3: ff         mov R7, A                                ?
0x11c4: ff         mov R7, A                                ?
0x11c5: ff         mov R7, A                                ?
0x11c6: ff         mov R7, A                                ?
0x11c7: ff         mov R7, A                                ?
0x11c8: ff         mov R7, A                                ?
0x11c9: ff         mov R7, A                                ?
0x11ca: ff         mov R7, A                                ?
0x11cb: 78 ff      mov R0, #0xff                            ?
0x11cd: 55 8c      anl A, 0x8c                              ?
0x11cf: 55 ff      anl A, 0xff                              ?
0x11d1: 37         addc A, @R1                              ?
0x11d2: 31 ff      acall 0x11ff                             ?
0x11d4: 13         rrc A                                    ?
0x11d5: 12 11 49   lcall 0x1149                             ?
0x11d8: 2f         add A, R7                                ?
0x11d9: 10 7a 26   jbc 0x2f.2 [0x7a], 0x1202                ?
0x11dc: 28         add A, R0                                ?
0x11dd: 7a 26      mov R2, #0x26                            ?
0x11df: 28         add A, R0                                ?
0x11e0: 12 a0 12   lcall 0xa012                             ?
0x11e3: a6 12      mov @R0, 0x12                            ?
0x11e5: c0 12      push 0x12                                ?
0x11e7: ca         xch A, R2                                ?
0x11e8: 13         rrc A                                    ?
0x11e9: 76 13      mov @R0, #0x13                           ?
0x11eb: 98         subb A, R0                               ?
0x11ec: 13         rrc A                                    ?
0x11ed: a2 13      mov C, 0x22.3 [0x13]                     ?
0x11ef: ac 13      mov R4, 0x13                             ?
0x11f1: bc 13 c4   cjne R4, #0x13, 0x11b8                   ?
0x11f4: 13         rrc A                                    ?
0x11f5: cc         xch A, R4                                ?
0x11f6: 13         rrc A                                    ?
0x11f7: d4         da A                                     ?
0x11f8: 13         rrc A                                    ?
0x11f9: dc 14      djnz R4, 0x120f                          ?
0x11fb: 47         orl A, @R1                               ?
0x11fc: 14         dec A                                    ?
0x11fd: 4f         orl A, R7                                ?
0x11fe: 14         dec A                                    ?
0x11ff: 5b         anl A, R3                                ?
0x1200: 15 70      dec 0x70                                 ?
0x1202: 14         dec A                                    ?
0x1203: 65 14      xrl A, 0x14                              ?
0x1205: 73         jmp @A+DPTR                              ?
0x1206: 14         dec A                                    ?
0x1207: 86 14      mov 0x14, @R0                            ?
0x1209: 8c 15      mov 0x15, R4                             ?
0x120b: 38         addc A, R0                               ?
0x120c: 15 44      dec 0x44                                 ?
0x120e: 15 66      dec 0x66                                 ?
0x1210: 15 7a      dec 0x7a                                 ?
0x1212: 15 84      dec 0x84                                 ?
0x1214: 15 8a      dec 0x8a                                 ?
0x1216: 15 90      dec 0x90                                 ?
0x1218: 15 98      dec 0x98                                 ?
0x121a: 15 9e      dec 0x9e                                 ?
0x121c: 15 ac      dec 0xac                                 ?
0x121e: 15 b2      dec 0xb2                                 ?
0x1220: 15 bc      dec 0xbc                                 ?
0x1222: 15 d3      dec 0xd3                                 ?
0x1224: 15 db      dec 0xdb                                 ?
0x1226: 15 e5      dec 0xe5                                 ?
0x1228: 15 ef      dec 0xef                                 ?
0x122a: 15 f9      dec 0xf9                                 ?
0x122c: 16         dec @R0                                  ?
0x122d: 01 16      ajmp 0x1016                              ?
0x122f: 0b         inc R3                                   ?
0x1230: 16         dec @R0                                  ?
0x1231: 15 16      dec 0x16                                 ?
0x1233: 1f         dec R7                                   ?
0x1234: 16         dec @R0                                  ?
0x1235: 29         add A, R1                                ?
0x1236: 16         dec @R0                                  ?
0x1237: 4f         orl A, R7                                ?
0x1238: 16         dec @R0                                  ?
0x1239: 59         anl A, R1                                ?
0x123a: 16         dec @R0                                  ?
0x123b: 94 16      subb A, #0x16                            ?
0x123d: ba 16 e0   cjne R2, #0x16, 0x1220                   ?
0x1240: 18         dec R0                                   ?
0x1241: ec         mov A, R4                                ?
0x1242: 16         dec @R0                                  ?
0x1243: fa         mov R2, A                                ?
0x1244: 12 ca 19   lcall 0xca19                             ?
0x1247: 12 17 a6   lcall 0x17a6                             ?
0x124a: 13         rrc A                                    ?
0x124b: 76 19      mov @R0, #0x19                           ?
0x124d: be 17 c8   cjne R6, #0x17, 0x1218                   ?
0x1250: 13         rrc A                                    ?
0x1251: ac 19      mov R4, 0x19                             ?
0x1253: e0         movx A, @DPTR                            ?
0x1254: 17         dec @R1                                  ?
0x1255: d8 1b      djnz R0, 0x1272                          ?
0x1257: 04         inc A                                    ?
0x1258: 19         dec R1                                   ?
0x1259: f0         movx @DPTR, A                            ?
0x125a: 17         dec @R1                                  ?
0x125b: e0         movx A, @DPTR                            ?
0x125c: 1b         dec R3                                   ?
0x125d: 0c         inc R4                                   ?
0x125e: 19         dec R1                                   ?
0x125f: f8         mov R0, A                                ?
0x1260: 17         dec @R1                                  ?
0x1261: e8         mov A, R0                                ?
0x1262: 1b         dec R3                                   ?
0x1263: 14         dec A                                    ?
0x1264: 1a         dec R2                                   ?
0x1265: 00         nop                                      ?
0x1266: 17         dec @R1                                  ?
0x1267: f6         mov @R0, A                               ?
0x1268: 14         dec A                                    ?
0x1269: 8c 1a      mov 0x1a, R4                             ?
0x126b: 0e         inc R6                                   ?
0x126c: 18         dec R0                                   ?
0x126d: a2 15      mov C, 0x22.5 [0x15]                     ?
0x126f: 38         addc A, R0                               ?
0x1270: 1a         dec R2                                   ?
0x1271: ba 18 ae   cjne R2, #0x18, 0x1222                   ?
0x1274: 15 44      dec 0x44                                 ?
0x1276: 1a         dec R2                                   ?
0x1277: c6         xch A, @R0                               ?
0x1278: 18         dec R0                                   ?
0x1279: d0 15      pop 0x15                                 ?
0x127b: b2 1a      cpl 0x23.2 [0x1a]                        ?
0x127d: e8         mov A, R0                                ?
0x127e: 18         dec R0                                   ?
0x127f: da 15      djnz R2, 0x1296                          ?
0x1281: d3         setb C                                   ?
0x1282: 1a         dec R2                                   ?
0x1283: f2         movx @R0, A                              ?
0x1284: 18         dec R0                                   ?
0x1285: e2         movx A, @R0                              ?
0x1286: 16         dec @R0                                  ?
0x1287: 4f         orl A, R7                                ?
0x1288: 1a         dec R2                                   ?
0x1289: fa         mov R2, A                                ?
0x128a: ff         mov R7, A                                ?
0x128b: ff         mov R7, A                                ?
0x128c: ff         mov R7, A                                ?
0x128d: ff         mov R7, A                                ?
0x128e: ff         mov R7, A                                ?
0x128f: ff         mov R7, A                                ?
0x1290: ff         mov R7, A                                ?
0x1291: ff         mov R7, A                                ?
0x1292: ff         mov R7, A                                ?
0x1293: ff         mov R7, A                                ?
0x1294: ff         mov R7, A                                ?
0x1295: ff         mov R7, A                                ?
0x1296: 14         dec A                                    ?
0x1297: 04         inc A                                    ?
0x1298: 2e         add A, R6                                ?
0x1299: 52 48      anl 0x48, A                              ?
0x129b: 38         addc A, R0                               ?
0x129c: 01 03      ajmp 0x1003                              ?
0x129e: 02 00 13   ljmp 0x0013                              ?
0x12a1: 02 41 80   ljmp 0x4180                              ?
0x12a4: 80 80      sjmp 0x1226                              ?
0x12a6: 04         inc A                                    ?
0x12a7: 0c         inc R4                                   ?
0x12a8: 04         inc A                                    ?
0x12a9: 07         inc @R1                                  ?
0x12aa: 08         inc R0                                   ?
0x12ab: 0f         inc R7                                   ?
0x12ac: 1a         dec R2                                   ?
0x12ad: 35 1c      addc A, 0x1c                             ?
0x12af: 1c         dec R4                                   ?
0x12b0: 10 07 03   jbc 0x20.7 [0x07], 0x12b6                ?
0x12b3: 16         dec @R0                                  ?
0x12b4: 02 13 25   ljmp 0x1325                              ?
0x12b7: 34 48      addc A, #0x48                            ?
0x12b9: 5f         anl A, R7                                ?
0x12ba: 89 a2      mov 0xa2, R1                             ?
0x12bc: c3         clr C                                    ?
0x12bd: e0         movx A, @DPTR                            ?
0x12be: f3         movx @R1, A                              ?
0x12bf: fb         mov R3, A                                ?
0x12c0: 37         addc A, @R1                              ?
0x12c1: 04         inc A                                    ?
0x12c2: 18         dec R0                                   ?
0x12c3: 2c         add A, R4                                ?
0x12c4: 48         orl A, R0                                ?
0x12c5: 67         xrl A, @R1                               ?
0x12c6: 11 14      acall 0x1014                             ?
0x12c8: 19         dec R1                                   ?
0x12c9: 21 37      ajmp 0x1137                              ?
0x12cb: 0c         inc R4                                   ?
0x12cc: 04         inc A                                    ?
0x12cd: 04         inc A                                    ?
0x12ce: 08         inc R0                                   ?
0x12cf: 08         inc R0                                   ?
0x12d0: 08         inc R0                                   ?
0x12d1: 08         inc R0                                   ?
0x12d2: 18         dec R0                                   ?
0x12d3: 10 10 18   jbc 0x22.0 [0x10], 0x12ee                ?
0x12d6: 10 64 49   jbc 0x2c.4 [0x64], 0x1322                ?
0x12d9: 0c         inc R4                                   ?
0x12da: 05 0b      inc 0x0b                                 ?
0x12dc: 05 06      inc 0x06                                 ?
0x12de: 05 0a      inc 0x0a                                 ?
0x12e0: 10 0b 0a   jbc 0x21.3 [0x0b], 0x12ed                ?
0x12e3: 16         dec @R0                                  ?
0x12e4: 14         dec A                                    ?
0x12e5: 72 23      orl C, 0x24.3 [0x23]                     ?
0x12e7: 26         add A, @R0                               ?
0x12e8: 2c         add A, R4                                ?
0x12e9: 2f         add A, R7                                ?
0x12ea: 31 31      acall 0x1131                             ?
0x12ec: 31 31      acall 0x1131                             ?
0x12ee: 31 31      acall 0x1131                             ?
0x12f0: 31 31      acall 0x1131                             ?
0x12f2: 23         rl A                                     ?
0x12f3: 26         add A, @R0                               ?
0x12f4: 2c         add A, R4                                ?
0x12f5: 2f         add A, R7                                ?
0x12f6: 31 31      acall 0x1131                             ?
0x12f8: 31 31      acall 0x1131                             ?
0x12fa: 31 31      acall 0x1131                             ?
0x12fc: 31 31      acall 0x1131                             ?
0x12fe: 23         rl A                                     ?
0x12ff: 2a         add A, R2                                ?
0x1300: 31 39      acall 0x1139                             ?
0x1302: 40 40      jc 0x1344                                ?
0x1304: 33         rlc A                                    ?
0x1305: 31 31      acall 0x1131                             ?
0x1307: 31 31      acall 0x1131                             ?
0x1309: 31 32      acall 0x1132                             ?
0x130b: 39         addc A, R1                               ?
0x130c: 40 40      jc 0x134e                                ?
0x130e: 40 41      jc 0x1351                                ?
0x1310: 34 31      addc A, #0x31                            ?
0x1312: 2d         add A, R5                                ?
0x1313: 2d         add A, R5                                ?
0x1314: 2d         add A, R5                                ?
0x1315: 2d         add A, R5                                ?
0x1316: 37         addc A, @R1                              ?
0x1317: 40 40      jc 0x1359                                ?
0x1319: 44 44      orl A, #0x44                             ?
0x131b: 3c         addc A, R4                               ?
0x131c: 39         addc A, R1                               ?
0x131d: 33         rlc A                                    ?
0x131e: 2e         add A, R6                                ?
0x131f: 2d         add A, R5                                ?
0x1320: 2d         add A, R5                                ?
0x1321: 2d         add A, R5                                ?
0x1322: 3c         addc A, R4                               ?
0x1323: 40 40      jc 0x1365                                ?
0x1325: 43 44 41   orl 0x44, #0x41                          ?
0x1328: 3b         addc A, R3                               ?
0x1329: 36         addc A, @R0                              ?
0x132a: 34 2d      addc A, #0x2d                            ?
0x132c: 29         add A, R1                                ?
0x132d: 29         add A, R1                                ?
0x132e: 40 47      jc 0x1377                                ?
0x1330: 47         orl A, @R1                               ?
0x1331: 47         orl A, @R1                               ?
0x1332: 47         orl A, @R1                               ?
0x1333: 42 3c      orl 0x3c, A                              ?
0x1335: 37         addc A, @R1                              ?
0x1336: 34 2d      addc A, #0x2d                            ?
0x1338: 29         add A, R1                                ?
0x1339: 29         add A, R1                                ?
0x133a: 46         orl A, @R0                               ?
0x133b: 4b         orl A, R3                                ?
0x133c: 4f         orl A, R7                                ?
0x133d: 4f         orl A, R7                                ?
0x133e: 4f         orl A, R7                                ?
0x133f: 48         orl A, R0                                ?
0x1340: 45 40      orl A, 0x40                              ?
0x1342: 39         addc A, R1                               ?
0x1343: 31 2e      acall 0x112e                             ?
0x1345: 2d         add A, R5                                ?
0x1346: 46         orl A, @R0                               ?
0x1347: 4b         orl A, R3                                ?
0x1348: 4f         orl A, R7                                ?
0x1349: 4f         orl A, R7                                ?
0x134a: 4f         orl A, R7                                ?
0x134b: 4f         orl A, R7                                ?
0x134c: 48         orl A, R0                                ?
0x134d: 45 40      orl A, 0x40                              ?
0x134f: 39         addc A, R1                               ?
0x1350: 36         addc A, @R0                              ?
0x1351: 34 46      addc A, #0x46                            ?
0x1353: 4b         orl A, R3                                ?
0x1354: 4f         orl A, R7                                ?
0x1355: 4f         orl A, R7                                ?
0x1356: 4f         orl A, R7                                ?
0x1357: 4f         orl A, R7                                ?
0x1358: 4f         orl A, R7                                ?
0x1359: 48         orl A, R0                                ?
0x135a: 42 3d      orl 0x3d, A                              ?
0x135c: 39         addc A, R1                               ?
0x135d: 36         addc A, @R0                              ?
0x135e: 46         orl A, @R0                               ?
0x135f: 4b         orl A, R3                                ?
0x1360: 4f         orl A, R7                                ?
0x1361: 4f         orl A, R7                                ?
0x1362: 4f         orl A, R7                                ?
0x1363: 4f         orl A, R7                                ?
0x1364: 4f         orl A, R7                                ?
0x1365: 48         orl A, R0                                ?
0x1366: 45 3e      orl A, 0x3e                              ?
0x1368: 3a         addc A, R2                               ?
0x1369: 36         addc A, @R0                              ?
0x136a: 46         orl A, @R0                               ?
0x136b: 4b         orl A, R3                                ?
0x136c: 4f         orl A, R7                                ?
0x136d: 4f         orl A, R7                                ?
0x136e: 4f         orl A, R7                                ?
0x136f: 4f         orl A, R7                                ?
0x1370: 4f         orl A, R7                                ?
0x1371: 48         orl A, R0                                ?
0x1372: 45 3e      orl A, 0x3e                              ?
0x1374: 3a         addc A, R2                               ?
0x1375: 36         addc A, @R0                              ?
0x1376: 37         addc A, @R1                              ?
0x1377: 10 0c 0d   jbc 0x21.4 [0x0c], 0x1387                ?
0x137a: 03         rr A                                     ?
0x137b: 03         rr A                                     ?
0x137c: 07         inc @R1                                  ?
0x137d: 0c         inc R4                                   ?
0x137e: 07         inc @R1                                  ?
0x137f: 06         inc @R0                                  ?
0x1380: 0c         inc R4                                   ?
0x1381: 0d         inc R5                                   ?
0x1382: 0c         inc R4                                   ?
0x1383: 0d         inc R5                                   ?
0x1384: 07         inc @R1                                  ?
0x1385: 05 06      inc 0x06                                 ?
0x1387: 64 32      xrl A, #0x32                             ?
0x1389: 32         reti                                     ?
0x138a: 2d         add A, R5                                ?
0x138b: 27         add A, @R1                               ?
0x138c: 27         add A, @R1                               ?
0x138d: 27         add A, @R1                               ?
0x138e: 2a         add A, R2                                ?
0x138f: 2e         add A, R6                                ?
0x1390: 2e         add A, R6                                ?
0x1391: 30 30 30   jnb 0x26.0 [0x30], 0x13c4                ?
0x1394: 30 32 32   jnb 0x26.2 [0x32], 0x13c9                ?
0x1397: 32         reti                                     ?
0x1398: 12 04 06   lcall 0x0406                             ?
0x139b: 04         inc A                                    ?
0x139c: 02 3f 14   ljmp 0x3f14                              ?
0x139f: 14         dec A                                    ?
0x13a0: 14         dec A                                    ?
0x13a1: 14         dec A                                    ?
0x13a2: 13         rrc A                                    ?
0x13a3: 04         inc A                                    ?
0x13a4: 16         dec @R0                                  ?
0x13a5: 0f         inc R7                                   ?
0x13a6: 52 4f      anl 0x4f, A                              ?
0x13a8: 14         dec A                                    ?
0x13a9: 14         dec A                                    ?
0x13aa: 14         dec A                                    ?
0x13ab: 14         dec A                                    ?
0x13ac: 37         addc A, @R1                              ?
0x13ad: 07         inc @R1                                  ?
0x13ae: 04         inc A                                    ?
0x13af: 03         rr A                                     ?
0x13b0: 0e         inc R6                                   ?
0x13b1: 08         inc R0                                   ?
0x13b2: 10 18 ac   jbc 0x23.0 [0x18], 0x1361                ?
0x13b5: 3f         addc A, R7                               ?
0x13b6: 1b         dec R3                                   ?
0x13b7: 1b         dec R3                                   ?
0x13b8: 1c         dec R4                                   ?
0x13b9: 2a         add A, R2                                ?
0x13ba: 2a         add A, R2                                ?
0x13bb: 47         orl A, @R1                               ?
0x13bc: 13         rrc A                                    ?
0x13bd: 03         rr A                                     ?
0x13be: 4e         orl A, R6                                ?
0x13bf: 59         anl A, R1                                ?
0x13c0: 4f         orl A, R7                                ?
0x13c1: 26         add A, @R0                               ?
0x13c2: 0d         inc R5                                   ?
0x13c3: 14         dec A                                    ?
0x13c4: 13         rrc A                                    ?
0x13c5: 03         rr A                                     ?
0x13c6: 0e         inc R6                                   ?
0x13c7: 4a         orl A, R2                                ?
0x13c8: 5e         anl A, R6                                ?
0x13c9: 14         dec A                                    ?
0x13ca: 06         inc @R0                                  ?
0x13cb: 14         dec A                                    ?
0x13cc: 37         addc A, @R1                              ?
0x13cd: 03         rr A                                     ?
0x13ce: 07         inc @R1                                  ?
0x13cf: 0d         inc R5                                   ?
0x13d0: e9         mov A, R1                                ?
0x13d1: 1c         dec R4                                   ?
0x13d2: 32         reti                                     ?
0x13d3: 32         reti                                     ?
0x13d4: 13         rrc A                                    ?
0x13d5: 03         rr A                                     ?
0x13d6: 4e         orl A, R6                                ?
0x13d7: 55 4f      anl A, 0x4f                              ?
0x13d9: 1b         dec R3                                   ?
0x13da: 14         dec A                                    ?
0x13db: 0d         inc R5                                   ?
0x13dc: 37         addc A, @R1                              ?
0x13dd: 0c         inc R4                                   ?
0x13de: 03         rr A                                     ?
0x13df: 04         inc A                                    ?
0x13e0: 04         inc A                                    ?
0x13e1: 04         inc A                                    ?
0x13e2: 04         inc A                                    ?
0x13e3: 10 10 05   jbc 0x22.0 [0x10], 0x13eb                ?
0x13e6: 27         add A, @R1                               ?
0x13e7: 23         rl A                                     ?
0x13e8: 1f         dec R7                                   ?
0x13e9: 5e         anl A, R6                                ?
0x13ea: 11 07      acall 0x1007                             ?
0x13ec: 1d         dec R5                                   ?
0x13ed: 1e         dec R6                                   ?
0x13ee: 1d         dec R5                                   ?
0x13ef: 1e         dec R6                                   ?
0x13f0: 1d         dec R5                                   ?
0x13f1: 07         inc @R1                                  ?
0x13f2: 0e         inc R6                                   ?
0x13f3: 19         dec R1                                   ?
0x13f4: 1a         dec R2                                   ?
0x13f5: 17         dec @R1                                  ?
0x13f6: 10 0c 0a   jbc 0x21.4 [0x0c], 0x1403                ?
0x13f9: 07         inc @R1                                  ?
0x13fa: 49         orl A, R1                                ?
0x13fb: 2a         add A, R2                                ?
0x13fc: 17         dec @R1                                  ?
0x13fd: 10 0c 0a   jbc 0x21.4 [0x0c], 0x140a                ?
0x1400: 07         inc @R1                                  ?
0x1401: 49         orl A, R1                                ?
0x1402: 2a         add A, R2                                ?
0x1403: 17         dec @R1                                  ?
0x1404: 10 0c 0a   jbc 0x21.4 [0x0c], 0x1411                ?
0x1407: 07         inc @R1                                  ?
0x1408: 51 2e      acall 0x122e                             ?
0x140a: 19         dec R1                                   ?
0x140b: 12 0e 0b   lcall 0x0e0b                             ?
0x140e: 07         inc @R1                                  ?
0x140f: 5d         anl A, R5                                ?
0x1410: 35 1d      addc A, 0x1d                             ?
0x1412: 14         dec A                                    ?
0x1413: 10 0d 08   jbc 0x21.5 [0x0d], 0x141e                ?
0x1416: 6a         xrl A, R2                                ?
0x1417: 3d         addc A, R5                               ?
0x1418: 21 17      ajmp 0x1117                              ?
0x141a: 12 0f 09   lcall 0x0f09                             ?
0x141d: 6a         xrl A, R2                                ?
0x141e: 61 35      ajmp 0x1335                              ?
0x1420: 25 1c      add A, 0x1c                              ?
0x1422: 18         dec R0                                   ?
0x1423: 0e         inc R6                                   ?
0x1424: 6a         xrl A, R2                                ?
0x1425: 61 3a      ajmp 0x133a                              ?
0x1427: 2a         add A, R2                                ?
0x1428: 21 1b      ajmp 0x111b                              ?
0x142a: 10 6a 6a   jbc 0x2d.2 [0x6a], 0x1497                ?
0x142d: 3f         addc A, R7                               ?
0x142e: 2e         add A, R6                                ?
0x142f: 24 1e      add A, #0x1e                             ?
0x1431: 12 6a 6a   lcall 0x6a6a                             ?
0x1434: 6a         xrl A, R2                                ?
0x1435: 4e         orl A, R6                                ?
0x1436: 3d         addc A, R5                               ?
0x1437: 33         rlc A                                    ?
0x1438: 1e         dec R6                                   ?
0x1439: 6a         xrl A, R2                                ?
0x143a: 6a         xrl A, R2                                ?
0x143b: 6a         xrl A, R2                                ?
0x143c: 6a         xrl A, R2                                ?
0x143d: 53 45 2a   anl 0x45, #0x2a                          ?
0x1440: 6a         xrl A, R2                                ?
0x1441: 6a         xrl A, R2                                ?
0x1442: 6a         xrl A, R2                                ?
0x1443: 6a         xrl A, R2                                ?
0x1444: 67         xrl A, @R1                               ?
0x1445: 56         anl A, @R0                               ?
0x1446: 33         rlc A                                    ?
0x1447: 13         rrc A                                    ?
0x1448: 03         rr A                                     ?
0x1449: 38         addc A, R0                               ?
0x144a: 42 7c      orl 0x7c, A                              ?
0x144c: 12 14 14   lcall 0x1414                             ?
0x144f: 13         rrc A                                    ?
0x1450: 05 6c      inc 0x6c                                 ?
0x1452: 19         dec R1                                   ?
0x1453: 1e         dec R6                                   ?
0x1454: 1e         dec R6                                   ?
0x1455: 31 64      acall 0x1164                             ?
0x1457: 64 1e      xrl A, #0x1e                             ?
0x1459: 1e         dec R6                                   ?
0x145a: 1e         dec R6                                   ?
0x145b: 12 04 20   lcall 0x0420                             ?
0x145e: 2e         add A, R6                                ?
0x145f: 3b         addc A, R3                               ?
0x1460: 6d         xrl A, R5                                ?
0x1461: 90 8a 80   mov DPTR, #0x8a80                        ?
0x1464: 80 13      sjmp 0x1479                              ?
0x1466: 06         inc @R0                                  ?
0x1467: 20 10 16   jb 0x22.0 [0x10], 0x1480                 ?
0x146a: 08         inc R0                                   ?
0x146b: 50 58      jnc 0x14c5                               ?
0x146d: a6 5a      mov @R0, 0x5a                            ?
0x146f: 43 2d 0f   orl 0x2d, #0x0f                          ?
0x1472: 00         nop                                      ?
0x1473: 37         addc A, @R1                              ?
0x1474: 03         rr A                                     ?
0x1475: 32         reti                                     ?
0x1476: 32         reti                                     ?
0x1477: 83         movc A, @A+PC                            ?
0x1478: 49         orl A, R1                                ?
0x1479: 03         rr A                                     ?
0x147a: 28         add A, R0                                ?
0x147b: 3c         addc A, R4                               ?
0x147c: 74 ff      mov A, #0xff                             ?
0x147e: ff         mov R7, A                                ?
0x147f: ff         mov R7, A                                ?
0x1480: ff         mov R7, A                                ?
0x1481: ff         mov R7, A                                ?
0x1482: c0 ff      push 0xff                                ?
0x1484: b3         cpl C                                    ?
0x1485: 80 37      sjmp 0x14be                              ?
0x1487: 02 19 da   ljmp 0x19da                              ?
0x148a: ff         mov R7, A                                ?
0x148b: ff         mov R7, A                                ?
0x148c: 37         addc A, @R1                              ?
0x148d: 0c         inc R4                                   ?
0x148e: 04         inc A                                    ?
0x148f: 04         inc A                                    ?
0x1490: 08         inc R0                                   ?
0x1491: 08         inc R0                                   ?
0x1492: 08         inc R0                                   ?
0x1493: 08         inc R0                                   ?
0x1494: 18         dec R0                                   ?
0x1495: 10 10 18   jbc 0x22.0 [0x10], 0x14b0                ?
0x1498: 10 64 49   jbc 0x2c.4 [0x64], 0x14e4                ?
0x149b: 0c         inc R4                                   ?
0x149c: 05 0b      inc 0x0b                                 ?
0x149e: 05 06      inc 0x06                                 ?
0x14a0: 05 0a      inc 0x0a                                 ?
0x14a2: 10 0b 0a   jbc 0x21.3 [0x0b], 0x14af                ?
0x14a5: 16         dec @R0                                  ?
0x14a6: 14         dec A                                    ?
0x14a7: 72 85      orl C, 0x80.5 [0x85]                     ?
0x14a9: 85 85 85   mov 0x85, 0x85                           ?
0x14ac: 85 85 84   mov 0x85, 0x84                           ?
0x14af: 83         movc A, @A+PC                            ?
0x14b0: 83         movc A, @A+PC                            ?
0x14b1: 83         movc A, @A+PC                            ?
0x14b2: 83         movc A, @A+PC                            ?
0x14b3: 83         movc A, @A+PC                            ?
0x14b4: 85 85 85   mov 0x85, 0x85                           ?
0x14b7: 84         div AB                                   ?
0x14b8: 84         div AB                                   ?
0x14b9: 84         div AB                                   ?
0x14ba: 84         div AB                                   ?
0x14bb: 84         div AB                                   ?
0x14bc: 84         div AB                                   ?
0x14bd: 84         div AB                                   ?
0x14be: 84         div AB                                   ?
0x14bf: 84         div AB                                   ?
0x14c0: 85 85 85   mov 0x85, 0x85                           ?
0x14c3: 84         div AB                                   ?
0x14c4: 84         div AB                                   ?
0x14c5: 84         div AB                                   ?
0x14c6: 84         div AB                                   ?
0x14c7: 84         div AB                                   ?
0x14c8: 84         div AB                                   ?
0x14c9: 84         div AB                                   ?
0x14ca: 84         div AB                                   ?
0x14cb: 84         div AB                                   ?
0x14cc: 85 86 86   mov 0x86, 0x86                           ?
0x14cf: 86 86      mov 0x86, @R0                            ?
0x14d1: 86 88      mov 0x88, @R0                            ?
0x14d3: 88 89      mov 0x89, R0                             ?
0x14d5: 89 89      mov 0x89, R1                             ?
0x14d7: 89 85      mov 0x85, R1                             ?
0x14d9: 86 86      mov 0x86, @R0                            ?
0x14db: 87 88      mov 0x88, @R1                            ?
0x14dd: 88 88      mov 0x88, R0                             ?
0x14df: 88 89      mov 0x89, R0                             ?
0x14e1: 8f 8f      mov 0x8f, R7                             ?
0x14e3: 8f 85      mov 0x85, R7                             ?
0x14e5: 86 87      mov 0x87, @R0                            ?
0x14e7: 88 88      mov 0x88, R0                             ?
0x14e9: 89 89      mov 0x89, R1                             ?
0x14eb: 89 89      mov 0x89, R1                             ?
0x14ed: 8a 95      mov 0x95, R2                             ?
0x14ef: 95 85      subb A, 0x85                             ?
0x14f1: 86 88      mov 0x88, @R0                            ?
0x14f3: 88 88      mov 0x88, R0                             ?
0x14f5: 89 89      mov 0x89, R1                             ?
0x14f7: 89 8a      mov 0x8a, R1                             ?
0x14f9: 8c 94      mov 0x94, R4                             ?
0x14fb: 94 85      subb A, #0x85                            ?
0x14fd: 87 88      mov 0x88, @R1                            ?
0x14ff: 88 8a      mov 0x8a, R0                             ?
0x1501: 8a 8a      mov 0x8a, R2                             ?
0x1503: 8a 8b      mov 0x8b, R2                             ?
0x1505: 8c 8d      mov 0x8d, R4                             ?
0x1507: 96         subb A, @R0                              ?
0x1508: 85 87 88   mov 0x87, 0x88                           ?
0x150b: 88 8a      mov 0x8a, R0                             ?
0x150d: 8a 8a      mov 0x8a, R2                             ?
0x150f: 8b 8b      mov 0x8b, R3                             ?
0x1511: 8c 8d      mov 0x8d, R4                             ?
0x1513: 93         movc A, @A+DPTR                          ?
0x1514: 85 87 89   mov 0x87, 0x89                           ?
0x1517: 89 8b      mov 0x8b, R1                             ?
0x1519: 8b 8b      mov 0x8b, R3                             ?
0x151b: 8b 8b      mov 0x8b, R3                             ?
0x151d: 8b 8b      mov 0x8b, R3                             ?
0x151f: 8f 85      mov 0x85, R7                             ?
0x1521: 87 88      mov 0x88, @R1                            ?
0x1523: 88 88      mov 0x88, R0                             ?
0x1525: 89 89      mov 0x89, R1                             ?
0x1527: 89 89      mov 0x89, R1                             ?
0x1529: 89 89      mov 0x89, R1                             ?
0x152b: 8a 88      mov 0x88, R2                             ?
0x152d: 88 8a      mov 0x8a, R0                             ?
0x152f: 8a 8a      mov 0x8a, R2                             ?
0x1531: 89 88      mov 0x88, R1                             ?
0x1533: 88 88      mov 0x88, R0                             ?
0x1535: 88 88      mov 0x88, R0                             ?
0x1537: 88 37      mov 0x37, R0                             ?
0x1539: 05 02      inc 0x02                                 ?
0x153b: 02 0a 10   ljmp 0x0a10                              ?
0x153e: d0 80      pop 0x80                                 ?
0x1540: 83         movc A, @A+PC                            ?
0x1541: 83         movc A, @A+PC                            ?
0x1542: 84         div AB                                   ?
0x1543: 84         div AB                                   ?
0x1544: 37         addc A, @R1                              ?
0x1545: 10 0c 0d   jbc 0x21.4 [0x0c], 0x1555                ?
0x1548: 03         rr A                                     ?
0x1549: 03         rr A                                     ?
0x154a: 07         inc @R1                                  ?
0x154b: 0c         inc R4                                   ?
0x154c: 07         inc @R1                                  ?
0x154d: 06         inc @R0                                  ?
0x154e: 0c         inc R4                                   ?
0x154f: 0d         inc R5                                   ?
0x1550: 0c         inc R4                                   ?
0x1551: 0d         inc R5                                   ?
0x1552: 07         inc @R1                                  ?
0x1553: 05 06      inc 0x06                                 ?
0x1555: 64 8a      xrl A, #0x8a                             ?
0x1557: 8f 95      mov 0x95, R7                             ?
0x1559: 97         subb A, @R1                              ?
0x155a: 9a         subb A, R2                               ?
0x155b: 9d         subb A, R5                               ?
0x155c: 9d         subb A, R5                               ?
0x155d: 9f         subb A, R7                               ?
0x155e: 9f         subb A, R7                               ?
0x155f: 9d         subb A, R5                               ?
0x1560: 9d         subb A, R5                               ?
0x1561: 9b         subb A, R3                               ?
0x1562: 9b         subb A, R3                               ?
0x1563: 9b         subb A, R3                               ?
0x1564: 9b         subb A, R3                               ?
0x1565: 9b         subb A, R3                               ?
0x1566: 13         rrc A                                    ?
0x1567: 04         inc A                                    ?
0x1568: 2e         add A, R6                                ?
0x1569: 1d         dec R5                                   ?
0x156a: 1e         dec R6                                   ?
0x156b: 6d         xrl A, R5                                ?
0x156c: 5a         anl A, R2                                ?
0x156d: 2d         add A, R5                                ?
0x156e: 33         rlc A                                    ?
0x156f: 00         nop                                      ?
0x1570: 12 04 16   lcall 0x0416                             ?
0x1573: 0f         inc R7                                   ?
0x1574: 0f         inc R7                                   ?
0x1575: 4f         orl A, R7                                ?
0x1576: 00         nop                                      ?
0x1577: 27         add A, @R1                               ?
0x1578: 27         add A, @R1                               ?
0x1579: 27         add A, @R1                               ?
0x157a: 13         rrc A                                    ?
0x157b: 04         inc A                                    ?
0x157c: 4a         orl A, R2                                ?
0x157d: 1e         dec R6                                   ?
0x157e: 21 69      ajmp 0x1169                              ?
0x1580: b6 1c 12   cjne @R0, #0x1c, 0x1595                  ?
0x1583: 0c         inc R4                                   ?
0x1584: 13         rrc A                                    ?
0x1585: 02 38 be   ljmp 0x38be                              ?
0x1588: 0f         inc R7                                   ?
0x1589: 0f         inc R7                                   ?
0x158a: 4d         orl A, R5                                ?
0x158b: 02 14 ec   ljmp 0x14ec                              ?
0x158e: fb         mov R3, A                                ?
0x158f: 53 37 03   anl 0x37, #0x03                          ?
0x1592: 03         rr A                                     ?
0x1593: 04         inc A                                    ?
0x1594: f1 f8      acall 0x17f8                             ?
0x1596: cb         xch A, R3                                ?
0x1597: 93         movc A, @A+DPTR                          ?
0x1598: 11 02      acall 0x1002                             ?
0x159a: 75 15 5d   mov 0x15, #0x5d                          ?
0x159d: 1d         dec R5                                   ?
0x159e: 37         addc A, @R1                              ?
0x159f: 06         inc @R0                                  ?
0x15a0: 03         rr A                                     ?
0x15a1: 0d         inc R5                                   ?
0x15a2: 0e         inc R6                                   ?
0x15a3: 32         reti                                     ?
0x15a4: 32         reti                                     ?
0x15a5: 6a         xrl A, R2                                ?
0x15a6: 40 40      jc 0x15e8                                ?
0x15a8: 80 80      sjmp 0x152a                              ?
0x15aa: 80 80      sjmp 0x152c                              ?
0x15ac: 03         rr A                                     ?
0x15ad: 02 31 cd   ljmp 0x31cd                              ?
0x15b0: 00         nop                                      ?
0x15b1: ff         mov R7, A                                ?
0x15b2: 13         rrc A                                    ?
0x15b3: 04         inc A                                    ?
0x15b4: 1e         dec R6                                   ?
0x15b5: 1d         dec R5                                   ?
0x15b6: 1e         dec R6                                   ?
0x15b7: 6d         xrl A, R5                                ?
0x15b8: 26         add A, @R0                               ?
0x15b9: 26         add A, @R0                               ?
0x15ba: 13         rrc A                                    ?
0x15bb: 00         nop                                      ?
0x15bc: 37         addc A, @R1                              ?
0x15bd: 03         rr A                                     ?
0x15be: 19         dec R1                                   ?
0x15bf: 19         dec R1                                   ?
0x15c0: b5 49 04   cjne A, 0x49, 0x15c7                     ?
0x15c3: 1e         dec R6                                   ?
0x15c4: 1e         dec R6                                   ?
0x15c5: 1e         dec R6                                   ?
0x15c6: 7e ff      mov R6, #0xff                            ?
0x15c8: ff         mov R7, A                                ?
0x15c9: ff         mov R7, A                                ?
0x15ca: cd         xch A, R5                                ?
0x15cb: ff         mov R7, A                                ?
0x15cc: ff         mov R7, A                                ?
0x15cd: ff         mov R7, A                                ?
0x15ce: cd         xch A, R5                                ?
0x15cf: ff         mov R7, A                                ?
0x15d0: ff         mov R7, A                                ?
0x15d1: cd         xch A, R5                                ?
0x15d2: b3         cpl C                                    ?
0x15d3: 13         rrc A                                    ?
0x15d4: 03         rr A                                     ?
0x15d5: 28         add A, R0                                ?
0x15d6: 2d         add A, R5                                ?
0x15d7: 83         movc A, @A+PC                            ?
0x15d8: 3b         addc A, R3                               ?
0x15d9: 2c         add A, R4                                ?
0x15da: 00         nop                                      ?
0x15db: 03         rr A                                     ?
0x15dc: 04         inc A                                    ?
0x15dd: 0d         inc R5                                   ?
0x15de: 10 10 d0   jbc 0x22.0 [0x10], 0x15b1                ?
0x15e1: 00         nop                                      ?
0x15e2: 00         nop                                      ?
0x15e3: 40 ff      jc 0x15e4                                ?
0x15e5: 13         rrc A                                    ?
0x15e6: 04         inc A                                    ?
0x15e7: 0f         inc R7                                   ?
0x15e8: 6f         xrl A, R7                                ?
0x15e9: 16         dec @R0                                  ?
0x15ea: 5e         anl A, R6                                ?
0x15eb: 28         add A, R0                                ?
0x15ec: 19         dec R1                                   ?
0x15ed: 17         dec @R1                                  ?
0x15ee: 14         dec A                                    ?
0x15ef: 13         rrc A                                    ?
0x15f0: 04         inc A                                    ?
0x15f1: 4b         orl A, R3                                ?
0x15f2: 1d         dec R5                                   ?
0x15f3: 36         addc A, @R0                              ?
0x15f4: 4d         orl A, R5                                ?
0x15f5: 14         dec A                                    ?
0x15f6: 14         dec A                                    ?
0x15f7: 14         dec A                                    ?
0x15f8: 14         dec A                                    ?
0x15f9: 13         rrc A                                    ?
0x15fa: 03         rr A                                     ?
0x15fb: 6d         xrl A, R5                                ?
0x15fc: 27         add A, @R1                               ?
0x15fd: 4d         orl A, R5                                ?
0x15fe: 19         dec R1                                   ?
0x15ff: 17         dec @R1                                  ?
0x1600: 15 03      dec 0x03                                 ?
0x1602: 04         inc A                                    ?
0x1603: 02 0b 03   ljmp 0x0b03                              ?
0x1606: f0         movx @DPTR, A                            ?
0x1607: 02 0a 10   ljmp 0x0a10                              ?
0x160a: 01 03      ajmp 0x1003                              ?
0x160c: 04         inc A                                    ?
0x160d: 02 06 05   ljmp 0x0605                              ?
0x1610: f3         movx @R1, A                              ?
0x1611: 02 0a 0a   ljmp 0x0a0a                              ?
0x1614: 10 03 04   jbc 0x20.3 [0x03], 0x161b                ?
0x1617: 01 08      ajmp 0x1008                              ?
0x1619: 06         inc @R0                                  ?
0x161a: f0         movx @DPTR, A                            ?
0x161b: 00         nop                                      ?
0x161c: 1e         dec R6                                   ?
0x161d: 50 50      jnc 0x166f                               ?
0x161f: 37         addc A, @R1                              ?
0x1620: 04         inc A                                    ?
0x1621: 01 0d      ajmp 0x100d                              ?
0x1623: 12 c1 00   lcall 0xc100                             ?
0x1626: 1a         dec R2                                   ?
0x1627: 1a         dec R2                                   ?
0x1628: 1a         dec R2                                   ?
0x1629: 37         addc A, @R1                              ?
0x162a: 06         inc @R0                                  ?
0x162b: 05 05      inc 0x05                                 ?
0x162d: 09         inc R1                                   ?
0x162e: 0b         inc R3                                   ?
0x162f: 32         reti                                     ?
0x1630: 9c         subb A, R4                               ?
0x1631: 13         rrc A                                    ?
0x1632: 04         inc A                                    ?
0x1633: 30 16 63   jnb 0x22.6 [0x16], 0x1699                ?
0x1636: 4d         orl A, R5                                ?
0x1637: ff         mov R7, A                                ?
0x1638: 60 59      jz 0x1693                                ?
0x163a: 17         dec @R1                                  ?
0x163b: ff         mov R7, A                                ?
0x163c: 60 59      jz 0x1697                                ?
0x163e: 17         dec @R1                                  ?
0x163f: ff         mov R7, A                                ?
0x1640: 60 59      jz 0x169b                                ?
0x1642: 17         dec @R1                                  ?
0x1643: ff         mov R7, A                                ?
0x1644: 6e         xrl A, R6                                ?
0x1645: 5a         anl A, R2                                ?
0x1646: 1a         dec R2                                   ?
0x1647: ff         mov R7, A                                ?
0x1648: 99         subb A, R1                               ?
0x1649: 89 33      mov 0x33, R1                             ?
0x164b: ff         mov R7, A                                ?
0x164c: c8         xch A, R0                                ?
0x164d: ba 80 13   cjne R2, #0x80, 0x1663                   ?
0x1650: 04         inc A                                    ?
0x1651: 4d         orl A, R5                                ?
0x1652: 1d         dec R5                                   ?
0x1653: 2a         add A, R2                                ?
0x1654: 5e         anl A, R6                                ?
0x1655: 28         add A, R0                                ?
0x1656: 1b         dec R3                                   ?
0x1657: 16         dec @R0                                  ?
0x1658: 14         dec A                                    ?
0x1659: 37         addc A, @R1                              ?
0x165a: 07         inc @R1                                  ?
0x165b: 0a         inc R2                                   ?
0x165c: 0a         inc R2                                   ?
0x165d: 0a         inc R2                                   ?
0x165e: 0a         inc R2                                   ?
0x165f: 14         dec A                                    ?
0x1660: 19         dec R1                                   ?
0x1661: 9c         subb A, R4                               ?
0x1662: 49         orl A, R1                                ?
0x1663: 06         inc @R0                                  ?
0x1664: 0a         inc R2                                   ?
0x1665: 0a         inc R2                                   ?
0x1666: 0a         inc R2                                   ?
0x1667: 14         dec A                                    ?
0x1668: 14         dec A                                    ?
0x1669: 9c         subb A, R4                               ?
0x166a: 04         inc A                                    ?
0x166b: 07         inc @R1                                  ?
0x166c: 0a         inc R2                                   ?
0x166d: 0a         inc R2                                   ?
0x166e: 0e         inc R6                                   ?
0x166f: 0e         inc R6                                   ?
0x1670: 08         inc R0                                   ?
0x1671: 0f         inc R7                                   ?
0x1672: 12 16 16   lcall 0x1616                             ?
0x1675: 16         dec @R0                                  ?
0x1676: 0c         inc R4                                   ?
0x1677: 13         rrc A                                    ?
0x1678: 18         dec R0                                   ?
0x1679: 1d         dec R5                                   ?
0x167a: 23         rl A                                     ?
0x167b: 23         rl A                                     ?
0x167c: 14         dec A                                    ?
0x167d: 20 23 27   jb 0x24.3 [0x23], 0x16a7                 ?
0x1680: 2d         add A, R5                                ?
0x1681: 2d         add A, R5                                ?
0x1682: 1e         dec R6                                   ?
0x1683: 20 27 2d   jb 0x24.7 [0x27], 0x16b3                 ?
0x1686: 2d         add A, R5                                ?
0x1687: 2d         add A, R5                                ?
0x1688: 28         add A, R0                                ?
0x1689: 28         add A, R0                                ?
0x168a: 2d         add A, R5                                ?
0x168b: 2d         add A, R5                                ?
0x168c: 2d         add A, R5                                ?
0x168d: 2d         add A, R5                                ?
0x168e: 28         add A, R0                                ?
0x168f: 28         add A, R0                                ?
0x1690: 2d         add A, R5                                ?
0x1691: 2d         add A, R5                                ?
0x1692: 2d         add A, R5                                ?
0x1693: 2d         add A, R5                                ?
0x1694: 37         addc A, @R1                              ?
0x1695: 04         inc A                                    ?
0x1696: 0a         inc R2                                   ?
0x1697: 0a         inc R2                                   ?
0x1698: 0a         inc R2                                   ?
0x1699: c9         xch A, R1                                ?
0x169a: 49         orl A, R1                                ?
0x169b: 06         inc @R0                                  ?
0x169c: 0a         inc R2                                   ?
0x169d: 0a         inc R2                                   ?
0x169e: 0a         inc R2                                   ?
0x169f: 14         dec A                                    ?
0x16a0: 14         dec A                                    ?
0x16a1: 9c         subb A, R4                               ?
0x16a2: 28         add A, R0                                ?
0x16a3: 3c         addc A, R4                               ?
0x16a4: 46         orl A, @R0                               ?
0x16a5: 50 5a      jnc 0x1701                               ?
0x16a7: 5a         anl A, R2                                ?
0x16a8: 28         add A, R0                                ?
0x16a9: 41 50      ajmp 0x1250                              ?
0x16ab: 5f         anl A, R7                                ?
0x16ac: 5f         anl A, R7                                ?
0x16ad: 5f         anl A, R7                                ?
0x16ae: 34 4d      addc A, #0x4d                            ?
0x16b0: 64 64      xrl A, #0x64                             ?
0x16b2: 64 64      xrl A, #0x64                             ?
0x16b4: 4b         orl A, R3                                ?
0x16b5: 64 64      xrl A, #0x64                             ?
0x16b7: 64 64      xrl A, #0x64                             ?
0x16b9: 64 37      xrl A, #0x37                             ?
0x16bb: 04         inc A                                    ?
0x16bc: 0a         inc R2                                   ?
0x16bd: 0a         inc R2                                   ?
0x16be: 0a         inc R2                                   ?
0x16bf: c9         xch A, R1                                ?
0x16c0: 49         orl A, R1                                ?
0x16c1: 06         inc @R0                                  ?
0x16c2: 0a         inc R2                                   ?
0x16c3: 0a         inc R2                                   ?
0x16c4: 0a         inc R2                                   ?
0x16c5: 14         dec A                                    ?
0x16c6: 14         dec A                                    ?
0x16c7: 9c         subb A, R4                               ?
0x16c8: 05 05      inc 0x05                                 ?
0x16ca: 05 05      inc 0x05                                 ?
0x16cc: 05 05      inc 0x05                                 ?
0x16ce: 05 05      inc 0x05                                 ?
0x16d0: 05 05      inc 0x05                                 ?
0x16d2: 05 05      inc 0x05                                 ?
0x16d4: 09         inc R1                                   ?
0x16d5: 09         inc R1                                   ?
0x16d6: 09         inc R1                                   ?
0x16d7: 09         inc R1                                   ?
0x16d8: 0c         inc R4                                   ?
0x16d9: 0c         inc R4                                   ?
0x16da: 05 08      inc 0x08                                 ?
0x16dc: 0a         inc R2                                   ?
0x16dd: 0c         inc R4                                   ?
0x16de: 10 10 37   jbc 0x22.0 [0x10], 0x1718                ?
0x16e1: 0c         inc R4                                   ?
0x16e2: 0d         inc R5                                   ?
0x16e3: 06         inc @R0                                  ?
0x16e4: 06         inc @R0                                  ?
0x16e5: 0d         inc R5                                   ?
0x16e6: 19         dec R1                                   ?
0x16e7: 0c         inc R4                                   ?
0x16e8: 0d         inc R5                                   ?
0x16e9: 0c         inc R4                                   ?
0x16ea: 07         inc @R1                                  ?
0x16eb: 06         inc @R0                                  ?
0x16ec: 06         inc @R0                                  ?
0x16ed: 64 ff      xrl A, #0xff                             ?
0x16ef: ff         mov R7, A                                ?
0x16f0: ff         mov R7, A                                ?
0x16f1: ff         mov R7, A                                ?
0x16f2: ff         mov R7, A                                ?
0x16f3: ff         mov R7, A                                ?
0x16f4: ff         mov R7, A                                ?
0x16f5: ff         mov R7, A                                ?
0x16f6: ff         mov R7, A                                ?
0x16f7: ff         mov R7, A                                ?
0x16f8: ff         mov R7, A                                ?
0x16f9: ff         mov R7, A                                ?
0x16fa: 37         addc A, @R1                              ?
0x16fb: 0c         inc R4                                   ?
0x16fc: 04         inc A                                    ?
0x16fd: 04         inc A                                    ?
0x16fe: 08         inc R0                                   ?
0x16ff: 08         inc R0                                   ?
0x1700: 08         inc R0                                   ?
0x1701: 08         inc R0                                   ?
0x1702: 18         dec R0                                   ?
0x1703: 10 10 18   jbc 0x22.0 [0x10], 0x171e                ?
0x1706: 10 64 49   jbc 0x2c.4 [0x64], 0x1752                ?
0x1709: 0c         inc R4                                   ?
0x170a: 05 0b      inc 0x0b                                 ?
0x170c: 05 06      inc 0x06                                 ?
0x170e: 05 0a      inc 0x0a                                 ?
0x1710: 10 0b 0a   jbc 0x21.3 [0x0b], 0x171d                ?
0x1713: 16         dec @R0                                  ?
0x1714: 14         dec A                                    ?
0x1715: 72 23      orl C, 0x24.3 [0x23]                     ?
0x1717: 26         add A, @R0                               ?
0x1718: 2c         add A, R4                                ?
0x1719: 2f         add A, R7                                ?
0x171a: 31 31      acall 0x1131                             ?
0x171c: 31 31      acall 0x1131                             ?
0x171e: 31 31      acall 0x1131                             ?
0x1720: 31 31      acall 0x1131                             ?
0x1722: 23         rl A                                     ?
0x1723: 26         add A, @R0                               ?
0x1724: 2c         add A, R4                                ?
0x1725: 2f         add A, R7                                ?
0x1726: 31 31      acall 0x1131                             ?
0x1728: 31 31      acall 0x1131                             ?
0x172a: 31 31      acall 0x1131                             ?
0x172c: 31 31      acall 0x1131                             ?
0x172e: 23         rl A                                     ?
0x172f: 2a         add A, R2                                ?
0x1730: 31 39      acall 0x1139                             ?
0x1732: 40 40      jc 0x1774                                ?
0x1734: 37         addc A, @R1                              ?
0x1735: 31 31      acall 0x1131                             ?
0x1737: 31 31      acall 0x1131                             ?
0x1739: 31 32      acall 0x1132                             ?
0x173b: 39         addc A, R1                               ?
0x173c: 44 45      orl A, #0x45                             ?
0x173e: 48         orl A, R0                                ?
0x173f: 42 37      orl 0x37, A                              ?
0x1741: 31 31      acall 0x1131                             ?
0x1743: 31 31      acall 0x1131                             ?
0x1745: 31 37      acall 0x1137                             ?
0x1747: 40 4a      jc 0x1793                                ?
0x1749: 4f         orl A, R7                                ?
0x174a: 4f         orl A, R7                                ?
0x174b: 45 3c      orl A, 0x3c                              ?
0x174d: 37         addc A, @R1                              ?
0x174e: 31 31      acall 0x1131                             ?
0x1750: 31 31      acall 0x1131                             ?
0x1752: 3c         addc A, R4                               ?
0x1753: 43 4a 4f   orl 0x4a, #0x4f                          ?
0x1756: 4f         orl A, R7                                ?
0x1757: 48         orl A, R0                                ?
0x1758: 42 3b      orl 0x3b, A                              ?
0x175a: 35 31      addc A, 0x31                             ?
0x175c: 2d         add A, R5                                ?
0x175d: 2d         add A, R5                                ?
0x175e: 40 49      jc 0x17a9                                ?
0x1760: 4f         orl A, R7                                ?
0x1761: 4f         orl A, R7                                ?
0x1762: 4f         orl A, R7                                ?
0x1763: 48         orl A, R0                                ?
0x1764: 42 3c      orl 0x3c, A                              ?
0x1766: 34 2d      addc A, #0x2d                            ?
0x1768: 29         add A, R1                                ?
0x1769: 29         add A, R1                                ?
0x176a: 46         orl A, @R0                               ?
0x176b: 4b         orl A, R3                                ?
0x176c: 4f         orl A, R7                                ?
0x176d: 4f         orl A, R7                                ?
0x176e: 4f         orl A, R7                                ?
0x176f: 48         orl A, R0                                ?
0x1770: 45 42      orl A, 0x42                              ?
0x1772: 39         addc A, R1                               ?
0x1773: 32         reti                                     ?
0x1774: 2e         add A, R6                                ?
0x1775: 2d         add A, R5                                ?
0x1776: 46         orl A, @R0                               ?
0x1777: 4b         orl A, R3                                ?
0x1778: 4f         orl A, R7                                ?
0x1779: 4f         orl A, R7                                ?
0x177a: 4f         orl A, R7                                ?
0x177b: 4f         orl A, R7                                ?
0x177c: 48         orl A, R0                                ?
0x177d: 45 40      orl A, 0x40                              ?
0x177f: 39         addc A, R1                               ?
0x1780: 36         addc A, @R0                              ?
0x1781: 34 46      addc A, #0x46                            ?
0x1783: 4b         orl A, R3                                ?
0x1784: 4f         orl A, R7                                ?
0x1785: 4f         orl A, R7                                ?
0x1786: 4f         orl A, R7                                ?
0x1787: 4f         orl A, R7                                ?
0x1788: 4f         orl A, R7                                ?
0x1789: 48         orl A, R0                                ?
0x178a: 42 3d      orl 0x3d, A                              ?
0x178c: 39         addc A, R1                               ?
0x178d: 36         addc A, @R0                              ?
0x178e: 46         orl A, @R0                               ?
0x178f: 4b         orl A, R3                                ?
0x1790: 4f         orl A, R7                                ?
0x1791: 4f         orl A, R7                                ?
0x1792: 4f         orl A, R7                                ?
0x1793: 4f         orl A, R7                                ?
0x1794: 4f         orl A, R7                                ?
0x1795: 48         orl A, R0                                ?
0x1796: 45 3e      orl A, 0x3e                              ?
0x1798: 3a         addc A, R2                               ?
0x1799: 36         addc A, @R0                              ?
0x179a: 46         orl A, @R0                               ?
0x179b: 4b         orl A, R3                                ?
0x179c: 4f         orl A, R7                                ?
0x179d: 4f         orl A, R7                                ?
0x179e: 4f         orl A, R7                                ?
0x179f: 4f         orl A, R7                                ?
0x17a0: 4f         orl A, R7                                ?
0x17a1: 48         orl A, R0                                ?
0x17a2: 45 3e      orl A, 0x3e                              ?
0x17a4: 3a         addc A, R2                               ?
0x17a5: 36         addc A, @R0                              ?
0x17a6: 37         addc A, @R1                              ?
0x17a7: 10 0c 0d   jbc 0x21.4 [0x0c], 0x17b7                ?
0x17aa: 03         rr A                                     ?
0x17ab: 03         rr A                                     ?
0x17ac: 07         inc @R1                                  ?
0x17ad: 0c         inc R4                                   ?
0x17ae: 07         inc @R1                                  ?
0x17af: 06         inc @R0                                  ?
0x17b0: 0c         inc R4                                   ?
0x17b1: 0d         inc R5                                   ?
0x17b2: 0c         inc R4                                   ?
0x17b3: 0d         inc R5                                   ?
0x17b4: 07         inc @R1                                  ?
0x17b5: 05 06      inc 0x06                                 ?
0x17b7: 64 32      xrl A, #0x32                             ?
0x17b9: 32         reti                                     ?
0x17ba: 2d         add A, R5                                ?
0x17bb: 27         add A, @R1                               ?
0x17bc: 27         add A, @R1                               ?
0x17bd: 27         add A, @R1                               ?
0x17be: 2a         add A, R2                                ?
0x17bf: 2e         add A, R6                                ?
0x17c0: 2e         add A, R6                                ?
0x17c1: 30 30 30   jnb 0x26.0 [0x30], 0x17f4                ?
0x17c4: 30 32 32   jnb 0x26.2 [0x32], 0x17f9                ?
0x17c7: 32         reti                                     ?
0x17c8: 37         addc A, @R1                              ?
0x17c9: 07         inc @R1                                  ?
0x17ca: 02 03 0e   ljmp 0x030e                              ?
0x17cd: 08         inc R0                                   ?
0x17ce: 10 18 ac   jbc 0x23.0 [0x18], 0x177d                ?
0x17d1: 40 1b      jc 0x17ee                                ?
0x17d3: 1b         dec R3                                   ?
0x17d4: 1c         dec R4                                   ?
0x17d5: 2a         add A, R2                                ?
0x17d6: 2a         add A, R2                                ?
0x17d7: 47         orl A, @R1                               ?
0x17d8: 13         rrc A                                    ?
0x17d9: 03         rr A                                     ?
0x17da: 4e         orl A, R6                                ?
0x17db: 59         anl A, R1                                ?
0x17dc: 4f         orl A, R7                                ?
0x17dd: 26         add A, @R0                               ?
0x17de: 14         dec A                                    ?
0x17df: 14         dec A                                    ?
0x17e0: 13         rrc A                                    ?
0x17e1: 03         rr A                                     ?
0x17e2: 73         jmp @A+DPTR                              ?
0x17e3: 25 5e      add A, 0x5e                              ?
0x17e5: 14         dec A                                    ?
0x17e6: 14         dec A                                    ?
0x17e7: 14         dec A                                    ?
0x17e8: 13         rrc A                                    ?
0x17e9: 06         inc @R0                                  ?
0x17ea: 20 10 1e   jb 0x22.0 [0x10], 0x180b                 ?
0x17ed: 1d         dec R5                                   ?
0x17ee: 35 56      addc A, 0x56                             ?
0x17f0: a6 5a      mov @R0, 0x5a                            ?
0x17f2: 43 21 13   orl 0x21, #0x13                          ?
0x17f5: 00         nop                                      ?
0x17f6: 37         addc A, @R1                              ?
0x17f7: 0c         inc R4                                   ?
0x17f8: 04         inc A                                    ?
0x17f9: 04         inc A                                    ?
0x17fa: 08         inc R0                                   ?
0x17fb: 08         inc R0                                   ?
0x17fc: 08         inc R0                                   ?
0x17fd: 08         inc R0                                   ?
0x17fe: 18         dec R0                                   ?
0x17ff: 10 10 18   jbc 0x22.0 [0x10], 0x181a                ?
0x1802: 10 64 49   jbc 0x2c.4 [0x64], 0x184e                ?
0x1805: 0c         inc R4                                   ?
0x1806: 05 0b      inc 0x0b                                 ?
0x1808: 05 06      inc 0x06                                 ?
0x180a: 05 0a      inc 0x0a                                 ?
0x180c: 10 0b 0a   jbc 0x21.3 [0x0b], 0x1819                ?
0x180f: 16         dec @R0                                  ?
0x1810: 14         dec A                                    ?
0x1811: 72 80      orl C, 0x80.0 [0x80]                     ?
0x1813: 80 80      sjmp 0x1795                              ?
0x1815: 80 80      sjmp 0x1797                              ?
0x1817: 7e 7c      mov R6, #0x7c                            ?
0x1819: 7c 7e      mov R4, #0x7e                            ?
0x181b: 7e 7e      mov R6, #0x7e                            ?
0x181d: 7e 80      mov R6, #0x80                            ?
0x181f: 80 80      sjmp 0x17a1                              ?
0x1821: 80 80      sjmp 0x17a3                              ?
0x1823: 7e 7c      mov R6, #0x7c                            ?
0x1825: 7c 7e      mov R4, #0x7e                            ?
0x1827: 7e 7e      mov R6, #0x7e                            ?
0x1829: 7e 7c      mov R6, #0x7c                            ?
0x182b: 7c 7e      mov R4, #0x7e                            ?
0x182d: 7e 7e      mov R6, #0x7e                            ?
0x182f: 7e 7d      mov R6, #0x7d                            ?
0x1831: 7d 7e      mov R5, #0x7e                            ?
0x1833: 7e 7e      mov R6, #0x7e                            ?
0x1835: 7e 7c      mov R6, #0x7c                            ?
0x1837: 7e 7f      mov R6, #0x7f                            ?
0x1839: 80 7f      sjmp 0x18ba                              ?
0x183b: 7f 80      mov R7, #0x80                            ?
0x183d: 80 80      sjmp 0x17bf                              ?
0x183f: 89 8c      mov 0x8c, R1                             ?
0x1841: 8c 7c      mov 0x7c, R4                             ?
0x1843: 7e 80      mov R6, #0x80                            ?
0x1845: 80 82      sjmp 0x17c9                              ?
0x1847: 82 82      anl C, 0x80.2 [0x82]                     ?
0x1849: 82 83      anl C, 0x80.3 [0x83]                     ?
0x184b: 8b 8f      mov 0x8f, R3                             ?
0x184d: 8f 7c      mov 0x7c, R7                             ?
0x184f: 7e 80      mov R6, #0x80                            ?
0x1851: 82 82      anl C, 0x80.2 [0x82]                     ?
0x1853: 82 82      anl C, 0x80.2 [0x82]                     ?
0x1855: 82 83      anl C, 0x80.3 [0x83]                     ?
0x1857: 83         movc A, @A+PC                            ?
0x1858: 95 95      subb A, 0x95                             ?
0x185a: 7c 7e      mov R4, #0x7e                            ?
0x185c: 81 82      ajmp 0x1c82                              ?
0x185e: 82 82      anl C, 0x80.2 [0x82]                     ?
0x1860: 82 82      anl C, 0x80.2 [0x82]                     ?
0x1862: 83         movc A, @A+PC                            ?
0x1863: 85 8d 95   mov 0x8d, 0x95                           ?
0x1866: 7f 80      mov R7, #0x80                            ?
0x1868: 82 83      anl C, 0x80.3 [0x83]                     ?
0x186a: 84         div AB                                   ?
0x186b: 83         movc A, @A+PC                            ?
0x186c: 83         movc A, @A+PC                            ?
0x186d: 83         movc A, @A+PC                            ?
0x186e: 83         movc A, @A+PC                            ?
0x186f: 87 8d      mov 0x8d, @R1                            ?
0x1871: 95 81      subb A, 0x81                             ?
0x1873: 82 83      anl C, 0x80.3 [0x83]                     ?
0x1875: 84         div AB                                   ?
0x1876: 84         div AB                                   ?
0x1877: 83         movc A, @A+PC                            ?
0x1878: 83         movc A, @A+PC                            ?
0x1879: 83         movc A, @A+PC                            ?
0x187a: 84         div AB                                   ?
0x187b: 87 8d      mov 0x8d, @R1                            ?
0x187d: 93         movc A, @A+DPTR                          ?
0x187e: 83         movc A, @A+PC                            ?
0x187f: 84         div AB                                   ?
0x1880: 84         div AB                                   ?
0x1881: 84         div AB                                   ?
0x1882: 84         div AB                                   ?
0x1883: 84         div AB                                   ?
0x1884: 83         movc A, @A+PC                            ?
0x1885: 84         div AB                                   ?
0x1886: 84         div AB                                   ?
0x1887: 87 8d      mov 0x8d, @R1                            ?
0x1889: 8d 85      mov 0x85, R5                             ?
0x188b: 85 85 85   mov 0x85, 0x85                           ?
0x188e: 85 85 84   mov 0x85, 0x84                           ?
0x1891: 84         div AB                                   ?
0x1892: 84         div AB                                   ?
0x1893: 86 89      mov 0x89, @R0                            ?
0x1895: 8c 88      mov 0x88, R4                             ?
0x1897: 88 88      mov 0x88, R0                             ?
0x1899: 88 88      mov 0x88, R0                             ?
0x189b: 86 86      mov 0x86, @R0                            ?
0x189d: 86 86      mov 0x86, @R0                            ?
0x189f: 86 86      mov 0x86, @R0                            ?
0x18a1: 87 37      mov 0x37, @R1                            ?
0x18a3: 05 02      inc 0x02                                 ?
0x18a5: 02 0a 10   ljmp 0x0a10                              ?
0x18a8: d0 80      pop 0x80                                 ?
0x18aa: 83         movc A, @A+PC                            ?
0x18ab: 83         movc A, @A+PC                            ?
0x18ac: 84         div AB                                   ?
0x18ad: 84         div AB                                   ?
0x18ae: 37         addc A, @R1                              ?
0x18af: 10 0c 0d   jbc 0x21.4 [0x0c], 0x18bf                ?
0x18b2: 03         rr A                                     ?
0x18b3: 03         rr A                                     ?
0x18b4: 07         inc @R1                                  ?
0x18b5: 0c         inc R4                                   ?
0x18b6: 07         inc @R1                                  ?
0x18b7: 06         inc @R0                                  ?
0x18b8: 0c         inc R4                                   ?
0x18b9: 0d         inc R5                                   ?
0x18ba: 0c         inc R4                                   ?
0x18bb: 0d         inc R5                                   ?
0x18bc: 07         inc @R1                                  ?
0x18bd: 05 06      inc 0x06                                 ?
0x18bf: 64 8a      xrl A, #0x8a                             ?
0x18c1: 8f 95      mov 0x95, R7                             ?
0x18c3: 97         subb A, @R1                              ?
0x18c4: 9a         subb A, R2                               ?
0x18c5: 9d         subb A, R5                               ?
0x18c6: 9d         subb A, R5                               ?
0x18c7: 9f         subb A, R7                               ?
0x18c8: 9f         subb A, R7                               ?
0x18c9: 9d         subb A, R5                               ?
0x18ca: 9d         subb A, R5                               ?
0x18cb: 98         subb A, R0                               ?
0x18cc: 8d 8a      mov 0x8a, R5                             ?
0x18ce: 8a 8a      mov 0x8a, R2                             ?
0x18d0: 13         rrc A                                    ?
0x18d1: 04         inc A                                    ?
0x18d2: 1e         dec R6                                   ?
0x18d3: 1d         dec R5                                   ?
0x18d4: 1e         dec R6                                   ?
0x18d5: 6d         xrl A, R5                                ?
0x18d6: 26         add A, @R0                               ?
0x18d7: 26         add A, @R0                               ?
0x18d8: 13         rrc A                                    ?
0x18d9: 13         rrc A                                    ?
0x18da: 13         rrc A                                    ?
0x18db: 03         rr A                                     ?
0x18dc: 2d         add A, R5                                ?
0x18dd: 4b         orl A, R3                                ?
0x18de: 5e         anl A, R6                                ?
0x18df: 3b         addc A, R3                               ?
0x18e0: 2c         add A, R4                                ?
0x18e1: 00         nop                                      ?
0x18e2: 13         rrc A                                    ?
0x18e3: 04         inc A                                    ?
0x18e4: 4d         orl A, R5                                ?
0x18e5: 1d         dec R5                                   ?
0x18e6: 2a         add A, R2                                ?
0x18e7: 5e         anl A, R6                                ?
0x18e8: 28         add A, R0                                ?
0x18e9: 1b         dec R3                                   ?
0x18ea: 16         dec @R0                                  ?
0x18eb: 14         dec A                                    ?
0x18ec: 37         addc A, @R1                              ?
0x18ed: 04         inc A                                    ?
0x18ee: 0a         inc R2                                   ?
0x18ef: 0a         inc R2                                   ?
0x18f0: 0a         inc R2                                   ?
0x18f1: c9         xch A, R1                                ?
0x18f2: 49         orl A, R1                                ?
0x18f3: 06         inc @R0                                  ?
0x18f4: 0a         inc R2                                   ?
0x18f5: 0a         inc R2                                   ?
0x18f6: 0a         inc R2                                   ?
0x18f7: 14         dec A                                    ?
0x18f8: 14         dec A                                    ?
0x18f9: 9c         subb A, R4                               ?
0x18fa: 0a         inc R2                                   ?
0x18fb: 0a         inc R2                                   ?
0x18fc: 0a         inc R2                                   ?
0x18fd: 0c         inc R4                                   ?
0x18fe: 0f         inc R7                                   ?
0x18ff: 0f         inc R7                                   ?
0x1900: 0a         inc R2                                   ?
0x1901: 0a         inc R2                                   ?
0x1902: 12 14 19   lcall 0x1419                             ?
0x1905: 19         dec R1                                   ?
0x1906: 0f         inc R7                                   ?
0x1907: 16         dec @R0                                  ?
0x1908: 19         dec R1                                   ?
0x1909: 1d         dec R5                                   ?
0x190a: 1d         dec R5                                   ?
0x190b: 1d         dec R5                                   ?
0x190c: 0f         inc R7                                   ?
0x190d: 19         dec R1                                   ?
0x190e: 1e         dec R6                                   ?
0x190f: 21 21      ajmp 0x1921                              ?
0x1911: 21 37      ajmp 0x1937                              ?
0x1913: 0c         inc R4                                   ?
0x1914: 04         inc A                                    ?
0x1915: 04         inc A                                    ?
0x1916: 08         inc R0                                   ?
0x1917: 08         inc R0                                   ?
0x1918: 08         inc R0                                   ?
0x1919: 08         inc R0                                   ?
0x191a: 18         dec R0                                   ?
0x191b: 10 10 18   jbc 0x22.0 [0x10], 0x1936                ?
0x191e: 10 64 49   jbc 0x2c.4 [0x64], 0x196a                ?
0x1921: 0c         inc R4                                   ?
0x1922: 05 0b      inc 0x0b                                 ?
0x1924: 05 06      inc 0x06                                 ?
0x1926: 05 0a      inc 0x0a                                 ?
0x1928: 10 0b 0a   jbc 0x21.3 [0x0b], 0x1935                ?
0x192b: 16         dec @R0                                  ?
0x192c: 14         dec A                                    ?
0x192d: 72 23      orl C, 0x24.3 [0x23]                     ?
0x192f: 26         add A, @R0                               ?
0x1930: 2c         add A, R4                                ?
0x1931: 2f         add A, R7                                ?
0x1932: 31 31      acall 0x1931                             ?
0x1934: 31 31      acall 0x1931                             ?
0x1936: 31 31      acall 0x1931                             ?
0x1938: 31 31      acall 0x1931                             ?
0x193a: 23         rl A                                     ?
0x193b: 26         add A, @R0                               ?
0x193c: 2b         add A, R3                                ?
0x193d: 2b         add A, R3                                ?
0x193e: 2b         add A, R3                                ?
0x193f: 2b         add A, R3                                ?
0x1940: 2b         add A, R3                                ?
0x1941: 2b         add A, R3                                ?
0x1942: 2b         add A, R3                                ?
0x1943: 31 31      acall 0x1931                             ?
0x1945: 31 23      acall 0x1923                             ?
0x1947: 2a         add A, R2                                ?
0x1948: 2b         add A, R3                                ?
0x1949: 2c         add A, R4                                ?
0x194a: 2c         add A, R4                                ?
0x194b: 2c         add A, R4                                ?
0x194c: 29         add A, R1                                ?
0x194d: 29         add A, R1                                ?
0x194e: 29         add A, R1                                ?
0x194f: 31 31      acall 0x1931                             ?
0x1951: 31 32      acall 0x1932                             ?
0x1953: 32         reti                                     ?
0x1954: 31 2f      acall 0x192f                             ?
0x1956: 2c         add A, R4                                ?
0x1957: 2c         add A, R4                                ?
0x1958: 29         add A, R1                                ?
0x1959: 29         add A, R1                                ?
0x195a: 29         add A, R1                                ?
0x195b: 31 31      acall 0x1931                             ?
0x195d: 31 36      acall 0x1936                             ?
0x195f: 32         reti                                     ?
0x1960: 31 2f      acall 0x192f                             ?
0x1962: 2e         add A, R6                                ?
0x1963: 2c         add A, R4                                ?
0x1964: 29         add A, R1                                ?
0x1965: 29         add A, R1                                ?
0x1966: 29         add A, R1                                ?
0x1967: 31 31      acall 0x1931                             ?
0x1969: 31 38      acall 0x1938                             ?
0x196b: 35 31      addc A, 0x31                             ?
0x196d: 31 2f      acall 0x192f                             ?
0x196f: 2d         add A, R5                                ?
0x1970: 2a         add A, R2                                ?
0x1971: 2a         add A, R2                                ?
0x1972: 29         add A, R1                                ?
0x1973: 2d         add A, R5                                ?
0x1974: 2d         add A, R5                                ?
0x1975: 2d         add A, R5                                ?
0x1976: 3d         addc A, R5                               ?
0x1977: 36         addc A, @R0                              ?
0x1978: 31 31      acall 0x1931                             ?
0x197a: 2f         add A, R7                                ?
0x197b: 2f         add A, R7                                ?
0x197c: 2e         add A, R6                                ?
0x197d: 2d         add A, R5                                ?
0x197e: 29         add A, R1                                ?
0x197f: 29         add A, R1                                ?
0x1980: 29         add A, R1                                ?
0x1981: 29         add A, R1                                ?
0x1982: 40 40      jc 0x19c4                                ?
0x1984: 40 40      jc 0x19c6                                ?
0x1986: 40 41      jc 0x19c9                                ?
0x1988: 39         addc A, R1                               ?
0x1989: 39         addc A, R1                               ?
0x198a: 39         addc A, R1                               ?
0x198b: 32         reti                                     ?
0x198c: 2e         add A, R6                                ?
0x198d: 2d         add A, R5                                ?
0x198e: 46         orl A, @R0                               ?
0x198f: 4b         orl A, R3                                ?
0x1990: 4f         orl A, R7                                ?
0x1991: 4f         orl A, R7                                ?
0x1992: 4f         orl A, R7                                ?
0x1993: 4f         orl A, R7                                ?
0x1994: 48         orl A, R0                                ?
0x1995: 45 40      orl A, 0x40                              ?
0x1997: 39         addc A, R1                               ?
0x1998: 36         addc A, @R0                              ?
0x1999: 34 46      addc A, #0x46                            ?
0x199b: 4b         orl A, R3                                ?
0x199c: 4f         orl A, R7                                ?
0x199d: 4f         orl A, R7                                ?
0x199e: 4f         orl A, R7                                ?
0x199f: 4f         orl A, R7                                ?
0x19a0: 4f         orl A, R7                                ?
0x19a1: 48         orl A, R0                                ?
0x19a2: 42 3d      orl 0x3d, A                              ?
0x19a4: 39         addc A, R1                               ?
0x19a5: 36         addc A, @R0                              ?
0x19a6: 46         orl A, @R0                               ?
0x19a7: 4b         orl A, R3                                ?
0x19a8: 4f         orl A, R7                                ?
0x19a9: 4f         orl A, R7                                ?
0x19aa: 4f         orl A, R7                                ?
0x19ab: 4f         orl A, R7                                ?
0x19ac: 4f         orl A, R7                                ?
0x19ad: 48         orl A, R0                                ?
0x19ae: 45 3e      orl A, 0x3e                              ?
0x19b0: 3a         addc A, R2                               ?
0x19b1: 36         addc A, @R0                              ?
0x19b2: 46         orl A, @R0                               ?
0x19b3: 4b         orl A, R3                                ?
0x19b4: 4f         orl A, R7                                ?
0x19b5: 4f         orl A, R7                                ?
0x19b6: 4f         orl A, R7                                ?
0x19b7: 4f         orl A, R7                                ?
0x19b8: 4f         orl A, R7                                ?
0x19b9: 48         orl A, R0                                ?
0x19ba: 45 3e      orl A, 0x3e                              ?
0x19bc: 3a         addc A, R2                               ?
0x19bd: 36         addc A, @R0                              ?
0x19be: 37         addc A, @R1                              ?
0x19bf: 10 0c 0d   jbc 0x21.4 [0x0c], 0x19cf                ?
0x19c2: 03         rr A                                     ?
0x19c3: 03         rr A                                     ?
0x19c4: 07         inc @R1                                  ?
0x19c5: 0c         inc R4                                   ?
0x19c6: 07         inc @R1                                  ?
0x19c7: 06         inc @R0                                  ?
0x19c8: 0c         inc R4                                   ?
0x19c9: 0d         inc R5                                   ?
0x19ca: 0c         inc R4                                   ?
0x19cb: 0d         inc R5                                   ?
0x19cc: 07         inc @R1                                  ?
0x19cd: 05 06      inc 0x06                                 ?
0x19cf: 64 32      xrl A, #0x32                             ?
0x19d1: 32         reti                                     ?
0x19d2: 2d         add A, R5                                ?
0x19d3: 27         add A, @R1                               ?
0x19d4: 27         add A, @R1                               ?
0x19d5: 27         add A, @R1                               ?
0x19d6: 2a         add A, R2                                ?
0x19d7: 2e         add A, R6                                ?
0x19d8: 2e         add A, R6                                ?
0x19d9: 30 30 30   jnb 0x26.0 [0x30], 0x1a0c                ?
0x19dc: 30 32 32   jnb 0x26.2 [0x32], 0x1a11                ?
0x19df: 32         reti                                     ?
0x19e0: 37         addc A, @R1                              ?
0x19e1: 07         inc @R1                                  ?
0x19e2: 02 03 0e   ljmp 0x030e                              ?
0x19e5: 08         inc R0                                   ?
0x19e6: 10 18 ac   jbc 0x23.0 [0x18], 0x1995                ?
0x19e9: 40 1b      jc 0x1a06                                ?
0x19eb: 1b         dec R3                                   ?
0x19ec: 1c         dec R4                                   ?
0x19ed: 2a         add A, R2                                ?
0x19ee: 2a         add A, R2                                ?
0x19ef: 47         orl A, @R1                               ?
0x19f0: 13         rrc A                                    ?
0x19f1: 03         rr A                                     ?
0x19f2: 4e         orl A, R6                                ?
0x19f3: 59         anl A, R1                                ?
0x19f4: 4f         orl A, R7                                ?
0x19f5: 26         add A, @R0                               ?
0x19f6: 14         dec A                                    ?
0x19f7: 14         dec A                                    ?
0x19f8: 13         rrc A                                    ?
0x19f9: 03         rr A                                     ?
0x19fa: 73         jmp @A+DPTR                              ?
0x19fb: 25 5e      add A, 0x5e                              ?
0x19fd: 14         dec A                                    ?
0x19fe: 14         dec A                                    ?
0x19ff: 14         dec A                                    ?
0x1a00: 13         rrc A                                    ?
0x1a01: 06         inc @R0                                  ?
0x1a02: 20 10 1e   jb 0x22.0 [0x10], 0x1a23                 ?
0x1a05: 1d         dec R5                                   ?
0x1a06: 35 56      addc A, 0x56                             ?
0x1a08: a6 5a      mov @R0, 0x5a                            ?
0x1a0a: 43 21 13   orl 0x21, #0x13                          ?
0x1a0d: 00         nop                                      ?
0x1a0e: 37         addc A, @R1                              ?
0x1a0f: 0c         inc R4                                   ?
0x1a10: 04         inc A                                    ?
0x1a11: 04         inc A                                    ?
0x1a12: 08         inc R0                                   ?
0x1a13: 08         inc R0                                   ?
0x1a14: 08         inc R0                                   ?
0x1a15: 08         inc R0                                   ?
0x1a16: 18         dec R0                                   ?
0x1a17: 10 10 18   jbc 0x22.0 [0x10], 0x1a32                ?
0x1a1a: 10 64 49   jbc 0x2c.4 [0x64], 0x1a66                ?
0x1a1d: 0c         inc R4                                   ?
0x1a1e: 05 0b      inc 0x0b                                 ?
0x1a20: 05 06      inc 0x06                                 ?
0x1a22: 05 0a      inc 0x0a                                 ?
0x1a24: 10 0b 0a   jbc 0x21.3 [0x0b], 0x1a31                ?
0x1a27: 16         dec @R0                                  ?
0x1a28: 14         dec A                                    ?
0x1a29: 72 80      orl C, 0x80.0 [0x80]                     ?
0x1a2b: 80 80      sjmp 0x19ad                              ?
0x1a2d: 80 80      sjmp 0x19af                              ?
0x1a2f: 7e 7c      mov R6, #0x7c                            ?
0x1a31: 7c 7e      mov R4, #0x7e                            ?
0x1a33: 7e 7e      mov R6, #0x7e                            ?
0x1a35: 7e 80      mov R6, #0x80                            ?
0x1a37: 80 80      sjmp 0x19b9                              ?
0x1a39: 80 80      sjmp 0x19bb                              ?
0x1a3b: 7e 7c      mov R6, #0x7c                            ?
0x1a3d: 7c 7e      mov R4, #0x7e                            ?
0x1a3f: 7e 7e      mov R6, #0x7e                            ?
0x1a41: 7e 7c      mov R6, #0x7c                            ?
0x1a43: 7c 7e      mov R4, #0x7e                            ?
0x1a45: 7e 7e      mov R6, #0x7e                            ?
0x1a47: 7e 7d      mov R6, #0x7d                            ?
0x1a49: 7d 7e      mov R5, #0x7e                            ?
0x1a4b: 7e 7e      mov R6, #0x7e                            ?
0x1a4d: 7e 7c      mov R6, #0x7c                            ?
0x1a4f: 7e 7f      mov R6, #0x7f                            ?
0x1a51: 80 7f      sjmp 0x1ad2                              ?
0x1a53: 7f 80      mov R7, #0x80                            ?
0x1a55: 80 80      sjmp 0x19d7                              ?
0x1a57: 89 8c      mov 0x8c, R1                             ?
0x1a59: 8c 7c      mov 0x7c, R4                             ?
0x1a5b: 7e 80      mov R6, #0x80                            ?
0x1a5d: 80 82      sjmp 0x19e1                              ?
0x1a5f: 82 82      anl C, 0x80.2 [0x82]                     ?
0x1a61: 82 83      anl C, 0x80.3 [0x83]                     ?
0x1a63: 8b 8f      mov 0x8f, R3                             ?
0x1a65: 8f 7c      mov 0x7c, R7                             ?
0x1a67: 7e 80      mov R6, #0x80                            ?
0x1a69: 82 82      anl C, 0x80.2 [0x82]                     ?
0x1a6b: 82 82      anl C, 0x80.2 [0x82]                     ?
0x1a6d: 82 83      anl C, 0x80.3 [0x83]                     ?
0x1a6f: 83         movc A, @A+PC                            ?
0x1a70: 95 95      subb A, 0x95                             ?
0x1a72: 7c 7e      mov R4, #0x7e                            ?
0x1a74: 81 82      ajmp 0x1c82                              ?
0x1a76: 82 82      anl C, 0x80.2 [0x82]                     ?
0x1a78: 82 82      anl C, 0x80.2 [0x82]                     ?
0x1a7a: 83         movc A, @A+PC                            ?
0x1a7b: 85 8d 95   mov 0x8d, 0x95                           ?
0x1a7e: 7f 80      mov R7, #0x80                            ?
0x1a80: 82 83      anl C, 0x80.3 [0x83]                     ?
0x1a82: 84         div AB                                   ?
0x1a83: 83         movc A, @A+PC                            ?
0x1a84: 83         movc A, @A+PC                            ?
0x1a85: 83         movc A, @A+PC                            ?
0x1a86: 83         movc A, @A+PC                            ?
0x1a87: 87 8d      mov 0x8d, @R1                            ?
0x1a89: 95 81      subb A, 0x81                             ?
0x1a8b: 82 83      anl C, 0x80.3 [0x83]                     ?
0x1a8d: 84         div AB                                   ?
0x1a8e: 84         div AB                                   ?
0x1a8f: 83         movc A, @A+PC                            ?
0x1a90: 83         movc A, @A+PC                            ?
0x1a91: 83         movc A, @A+PC                            ?
0x1a92: 84         div AB                                   ?
0x1a93: 87 8d      mov 0x8d, @R1                            ?
0x1a95: 93         movc A, @A+DPTR                          ?
0x1a96: 83         movc A, @A+PC                            ?
0x1a97: 84         div AB                                   ?
0x1a98: 84         div AB                                   ?
0x1a99: 84         div AB                                   ?
0x1a9a: 84         div AB                                   ?
0x1a9b: 84         div AB                                   ?
0x1a9c: 83         movc A, @A+PC                            ?
0x1a9d: 84         div AB                                   ?
0x1a9e: 84         div AB                                   ?
0x1a9f: 87 8d      mov 0x8d, @R1                            ?
0x1aa1: 8d 85      mov 0x85, R5                             ?
0x1aa3: 85 85 85   mov 0x85, 0x85                           ?
0x1aa6: 85 85 84   mov 0x85, 0x84                           ?
0x1aa9: 84         div AB                                   ?
0x1aaa: 84         div AB                                   ?
0x1aab: 86 89      mov 0x89, @R0                            ?
0x1aad: 8c 88      mov 0x88, R4                             ?
0x1aaf: 88 88      mov 0x88, R0                             ?
0x1ab1: 88 88      mov 0x88, R0                             ?
0x1ab3: 86 86      mov 0x86, @R0                            ?
0x1ab5: 86 86      mov 0x86, @R0                            ?
0x1ab7: 86 86      mov 0x86, @R0                            ?
0x1ab9: 87 37      mov 0x37, @R1                            ?
0x1abb: 05 02      inc 0x02                                 ?
0x1abd: 02 0a 10   ljmp 0x0a10                              ?
0x1ac0: d0 80      pop 0x80                                 ?
0x1ac2: 83         movc A, @A+PC                            ?
0x1ac3: 83         movc A, @A+PC                            ?
0x1ac4: 84         div AB                                   ?
0x1ac5: 84         div AB                                   ?
0x1ac6: 37         addc A, @R1                              ?
0x1ac7: 10 0c 0d   jbc 0x21.4 [0x0c], 0x1ad7                ?
0x1aca: 03         rr A                                     ?
0x1acb: 03         rr A                                     ?
0x1acc: 07         inc @R1                                  ?
0x1acd: 0c         inc R4                                   ?
0x1ace: 07         inc @R1                                  ?
0x1acf: 06         inc @R0                                  ?
0x1ad0: 0c         inc R4                                   ?
0x1ad1: 0d         inc R5                                   ?
0x1ad2: 0c         inc R4                                   ?
0x1ad3: 0d         inc R5                                   ?
0x1ad4: 07         inc @R1                                  ?
0x1ad5: 05 06      inc 0x06                                 ?
0x1ad7: 64 8a      xrl A, #0x8a                             ?
0x1ad9: 8f 95      mov 0x95, R7                             ?
0x1adb: 97         subb A, @R1                              ?
0x1adc: 9a         subb A, R2                               ?
0x1add: 9d         subb A, R5                               ?
0x1ade: 9d         subb A, R5                               ?
0x1adf: 9f         subb A, R7                               ?
0x1ae0: 9f         subb A, R7                               ?
0x1ae1: 9d         subb A, R5                               ?
0x1ae2: 9d         subb A, R5                               ?
0x1ae3: 98         subb A, R0                               ?
0x1ae4: 8d 8a      mov 0x8a, R5                             ?
0x1ae6: 8a 8a      mov 0x8a, R2                             ?
0x1ae8: 13         rrc A                                    ?
0x1ae9: 04         inc A                                    ?
0x1aea: 1e         dec R6                                   ?
0x1aeb: 1d         dec R5                                   ?
0x1aec: 1e         dec R6                                   ?
0x1aed: 6d         xrl A, R5                                ?
0x1aee: 26         add A, @R0                               ?
0x1aef: 26         add A, @R0                               ?
0x1af0: 13         rrc A                                    ?
0x1af1: 13         rrc A                                    ?
0x1af2: 13         rrc A                                    ?
0x1af3: 03         rr A                                     ?
0x1af4: 2d         add A, R5                                ?
0x1af5: 4b         orl A, R3                                ?
0x1af6: 5e         anl A, R6                                ?
0x1af7: 3b         addc A, R3                               ?
0x1af8: 2c         add A, R4                                ?
0x1af9: 00         nop                                      ?
0x1afa: 13         rrc A                                    ?
0x1afb: 04         inc A                                    ?
0x1afc: 4d         orl A, R5                                ?
0x1afd: 1d         dec R5                                   ?
0x1afe: 2a         add A, R2                                ?
0x1aff: 5e         anl A, R6                                ?
0x1b00: 28         add A, R0                                ?
0x1b01: 1b         dec R3                                   ?
0x1b02: 16         dec @R0                                  ?
0x1b03: 14         dec A                                    ?
0x1b04: 13         rrc A                                    ?
0x1b05: 03         rr A                                     ?
0x1b06: 4e         orl A, R6                                ?
0x1b07: 59         anl A, R1                                ?
0x1b08: 4f         orl A, R7                                ?
0x1b09: 26         add A, @R0                               ?
0x1b0a: 0d         inc R5                                   ?
0x1b0b: 14         dec A                                    ?
0x1b0c: 13         rrc A                                    ?
0x1b0d: 03         rr A                                     ?
0x1b0e: 73         jmp @A+DPTR                              ?
0x1b0f: 25 5e      add A, 0x5e                              ?
0x1b11: 14         dec A                                    ?
0x1b12: 14         dec A                                    ?
0x1b13: 14         dec A                                    ?
0x1b14: 13         rrc A                                    ?
0x1b15: 06         inc @R0                                  ?
0x1b16: 20 10 1e   jb 0x22.0 [0x10], 0x1b37                 ?
0x1b19: 1d         dec R5                                   ?
0x1b1a: 35 56      addc A, 0x56                             ?
0x1b1c: a6 5a      mov @R0, 0x5a                            ?
0x1b1e: 43 25 16   orl 0x25, #0x16                          ?
0x1b21: 00         nop                                      ?
0x1b22: ff         mov R7, A                                ?
0x1b23: ff         mov R7, A                                ?
0x1b24: ff         mov R7, A                                ?
0x1b25: ff         mov R7, A                                ?
0x1b26: ff         mov R7, A                                ?
0x1b27: ff         mov R7, A                                ?
0x1b28: ff         mov R7, A                                ?
0x1b29: ff         mov R7, A                                ?
0x1b2a: ff         mov R7, A                                ?
0x1b2b: ff         mov R7, A                                ?
0x1b2c: ff         mov R7, A                                ?
0x1b2d: ff         mov R7, A                                ?
0x1b2e: ff         mov R7, A                                ?
0x1b2f: ff         mov R7, A                                ?
0x1b30: 30 07 03   jnb 0x20.7 [0x07], 0x1b36                ?
0x1b33: 02 0a 75   ljmp 0x0a75                              ?
0x1b36: 02 10 5f   ljmp 0x105f                              ?
0x1b39: 30 07 03   jnb 0x20.7 [0x07], 0x1b3f                ?
0x1b3c: 02 1d 15   ljmp 0x1d15                              ?
0x1b3f: 22         ret                                      ?
0x1b40: af 01      mov R7, 0x01                             ?
0x1b42: ae 00      mov R6, 0x00                             ?
0x1b44: 74 01      mov A, #0x01                             ?
0x1b46: 12 05 09   lcall 0x0509                             ?
0x1b49: 8f 7b      mov 0x7b, R7                             ?
0x1b4b: 74 41      mov A, #0x41                             ?
0x1b4d: 93         movc A, @A+DPTR                          ?
0x1b4e: 12 04 d9   lcall 0x04d9                             ?
0x1b51: 74 42      mov A, #0x42                             ?
0x1b53: 93         movc A, @A+DPTR                          ?
0x1b54: 2f         add A, R7                                ?
0x1b55: ff         mov R7, A                                ?
0x1b56: 74 0b      mov A, #0x0b                             ?
0x1b58: 93         movc A, @A+DPTR                          ?
0x1b59: f8         mov R0, A                                ?
0x1b5a: 74 0c      mov A, #0x0c                             ?
0x1b5c: 93         movc A, @A+DPTR                          ?
0x1b5d: f9         mov R1, A                                ?
0x1b5e: 12 04 55   lcall 0x0455                             ?
0x1b61: ee         mov A, R6                                ?
0x1b62: f4         cpl A                                    ?
0x1b63: f8         mov R0, A                                ?
0x1b64: ef         mov A, R7                                ?
0x1b65: f4         cpl A                                    ?
0x1b66: f9         mov R1, A                                ?
0x1b67: 74 0b      mov A, #0x0b                             ?
0x1b69: 93         movc A, @A+DPTR                          ?
0x1b6a: fb         mov R3, A                                ?
0x1b6b: 74 0c      mov A, #0x0c                             ?
0x1b6d: 93         movc A, @A+DPTR                          ?
0x1b6e: fc         mov R4, A                                ?
0x1b6f: d3         setb C                                   ?
0x1b70: ee         mov A, R6                                ?
0x1b71: 9b         subb A, R3                               ?
0x1b72: cf         xch A, R7                                ?
0x1b73: 9c         subb A, R4                               ?
0x1b74: fb         mov R3, A                                ?
0x1b75: c2 af      clr 0xa8.7 [0xaf]                        ?
0x1b77: 8f 44      mov 0x44, R7                             ?
0x1b79: 8b 45      mov 0x45, R3                             ?
0x1b7b: 88 42      mov 0x42, R0                             ?
0x1b7d: 89 43      mov 0x43, R1                             ?
0x1b7f: d2 af      setb 0xa8.7 [0xaf]                       ?
0x1b81: 22         ret                                      ?
0x1b82: e9         mov A, R1                                ?
0x1b83: c3         clr C                                    ?
0x1b84: 30 e7 13   jnb 0xe0.7 [0xe7], 0x1b9a                ?
0x1b87: 20 1a 1f   jb 0x23.2 [0x1a], 0x1ba9                 ?
0x1b8a: 74 3d      mov A, #0x3d                             ?
0x1b8c: 93         movc A, @A+DPTR                          ?
0x1b8d: 13         rrc A                                    ?
0x1b8e: 24 80      add A, #0x80                             ?
0x1b90: b5 01 00   cjne A, 0x01, 0x1b93                     ?
0x1b93: 50 14      jnc 0x1ba9                               ?
0x1b95: f9         mov R1, A                                ?
0x1b96: d2 03      setb 0x20.3 [0x03]                       ?
0x1b98: 80 0f      sjmp 0x1ba9                              ?
0x1b9a: 74 3e      mov A, #0x3e                             ?
0x1b9c: 93         movc A, @A+DPTR                          ?
0x1b9d: 13         rrc A                                    ?
0x1b9e: f4         cpl A                                    ?
0x1b9f: 24 80      add A, #0x80                             ?
0x1ba1: b5 01 00   cjne A, 0x01, 0x1ba4                     ?
0x1ba4: 40 03      jc 0x1ba9                                ?
0x1ba6: f9         mov R1, A                                ?
0x1ba7: d2 04      setb 0x20.4 [0x04]                       ?
0x1ba9: 7a 57      mov R2, #0x57                            ?
0x1bab: f1 f2      acall 0x1ff2                             ?
0x1bad: 12 05 1d   lcall 0x051d                             ?
0x1bb0: b5 49 00   cjne A, 0x49, 0x1bb3                     ?
0x1bb3: 40 02      jc 0x1bb7                                ?
0x1bb5: d2 04      setb 0x20.4 [0x04]                       ?
0x1bb7: e9         mov A, R1                                ?
0x1bb8: c3         clr C                                    ?
0x1bb9: 94 80      subb A, #0x80                            ?
0x1bbb: 92 05      mov 0x20.5 [0x05], C                     ?
0x1bbd: f9         mov R1, A                                ?
0x1bbe: 02 10 77   ljmp 0x1077                              ?
0x1bc1: 90 11 24   mov DPTR, #0x1124                        ?
0x1bc4: 12 05 cd   lcall 0x05cd                             ?
0x1bc7: 13         rrc A                                    ?
0x1bc8: 92 19      mov 0x23.1 [0x19], C                     ?
0x1bca: 13         rrc A                                    ?
0x1bcb: 92 18      mov 0x23.0 [0x18], C                     ?
0x1bcd: 02 10 47   ljmp 0x1047                              ?
0x1bd0: e5 15      mov A, 0x15                              ?
0x1bd2: b4 80 00   cjne A, #0x80, 0x1bd5                    ?
0x1bd5: b3         cpl C                                    ?
0x1bd6: 92 1b      mov 0x23.3 [0x1b], C                     ?
0x1bd8: 90 12 96   mov DPTR, #0x1296                        ?
0x1bdb: 12 05 cd   lcall 0x05cd                             ?
0x1bde: 13         rrc A                                    ?
0x1bdf: 92 2f      mov 0x25.7 [0x2f], C                     ?
0x1be1: 13         rrc A                                    ?
0x1be2: 92 2e      mov 0x25.6 [0x2e], C                     ?
0x1be4: 00         nop                                      ?
0x1be5: 00         nop                                      ?
0x1be6: 00         nop                                      ?
0x1be7: 30 2e 04   jnb 0x25.6 [0x2e], 0x1bee                ?
0x1bea: c2 07      clr 0x20.7 [0x07]                        ?
0x1bec: 61 f0      ajmp 0x1bf0                              ?
0x1bee: d2 07      setb 0x20.7 [0x07]                       ?
0x1bf0: 74 10      mov A, #0x10                             ?
0x1bf2: 93         movc A, @A+DPTR                          ?
0x1bf3: c3         clr C                                    ?
0x1bf4: 95 37      subb A, 0x37                             ?
0x1bf6: 50 0b      jnc 0x1c03                               ?
0x1bf8: 7a 03      mov R2, #0x03                            ?
0x1bfa: 12 05 1d   lcall 0x051d                             ?
0x1bfd: c3         clr C                                    ?
0x1bfe: 95 37      subb A, 0x37                             ?
0x1c00: 40 1f      jc 0x1c21                                ?
0x1c02: 22         ret                                      ?
0x1c03: d2 1a      setb 0x23.2 [0x1a]                       ?
0x1c05: 30 07 14   jnb 0x20.7 [0x07], 0x1c1c                ?
0x1c08: 74 6f      mov A, #0x6f                             ?
0x1c0a: 93         movc A, @A+DPTR                          ?
0x1c0b: b5 13 00   cjne A, 0x13, 0x1c0e                     ?
0x1c0e: b3         cpl C                                    ?
0x1c0f: 92 2d      mov 0x25.5 [0x2d], C                     ?
0x1c11: 74 6d      mov A, #0x6d                             ?
0x1c13: 93         movc A, @A+DPTR                          ?
0x1c14: b5 13 00   cjne A, 0x13, 0x1c17                     ?
0x1c17: b3         cpl C                                    ?
0x1c18: 92 2c      mov 0x25.4 [0x2c], C                     ?
0x1c1a: 81 20      ajmp 0x1c20                              ?
0x1c1c: c2 2c      clr 0x25.4 [0x2c]                        ?
0x1c1e: c2 2d      clr 0x25.5 [0x2d]                        ?
0x1c20: 22         ret                                      ?
0x1c21: c2 1a      clr 0x23.2 [0x1a]                        ?
0x1c23: 22         ret                                      ?
0x1c24: 7d 00      mov R5, #0x00                            ?
0x1c26: c3         clr C                                    ?
0x1c27: 30 1a 08   jnb 0x23.2 [0x1a], 0x1c32                ?
0x1c2a: 7a 49      mov R2, #0x49                            ?
0x1c2c: 91 ae      acall 0x1cae                             ?
0x1c2e: 91 ae      acall 0x1cae                             ?
0x1c30: 81 8c      ajmp 0x1c8c                              ?
0x1c32: 30 18 12   jnb 0x23.0 [0x18], 0x1c47                ?
0x1c35: 7a 04      mov R2, #0x04                            ?
0x1c37: 20 2c 04   jb 0x25.4 [0x2c], 0x1c3e                 ?
0x1c3a: f1 f2      acall 0x1ff2                             ?
0x1c3c: 81 41      ajmp 0x1c41                              ?
0x1c3e: 12 1d 10   lcall 0x1d10                             ?
0x1c41: 91 ae      acall 0x1cae                             ?
0x1c43: 7a 08      mov R2, #0x08                            ?
0x1c45: 81 88      ajmp 0x1c88                              ?
0x1c47: 30 19 06   jnb 0x23.1 [0x19], 0x1c50                ?
0x1c4a: 7a 0c      mov R2, #0x0c                            ?
0x1c4c: 91 ae      acall 0x1cae                             ?
0x1c4e: 81 69      ajmp 0x1c69                              ?
0x1c50: 7a 12      mov R2, #0x12                            ?
0x1c52: 20 2c 04   jb 0x25.4 [0x2c], 0x1c59                 ?
0x1c55: f1 f2      acall 0x1ff2                             ?
0x1c57: 81 5c      ajmp 0x1c5c                              ?
0x1c59: 12 1d 10   lcall 0x1d10                             ?
0x1c5c: 91 ae      acall 0x1cae                             ?
0x1c5e: 74 20      mov A, #0x20                             ?
0x1c60: 93         movc A, @A+DPTR                          ?
0x1c61: 95 49      subb A, 0x49                             ?
0x1c63: 40 04      jc 0x1c69                                ?
0x1c65: 7a 5b      mov R2, #0x5b                            ?
0x1c67: 81 88      ajmp 0x1c88                              ?
0x1c69: 7a 0d      mov R2, #0x0d                            ?
0x1c6b: 91 ae      acall 0x1cae                             ?
0x1c6d: 20 19 02   jb 0x23.1 [0x19], 0x1c72                 ?
0x1c70: 7a 5b      mov R2, #0x5b                            ?
0x1c72: 90 11 2e   mov DPTR, #0x112e                        ?
0x1c75: 12 05 cd   lcall 0x05cd                             ?
0x1c78: 30 e2 0d   jnb 0xe0.2 [0xe2], 0x1c88                ?
0x1c7b: 74 21      mov A, #0x21                             ?
0x1c7d: 93         movc A, @A+DPTR                          ?
0x1c7e: c3         clr C                                    ?
0x1c7f: 95 37      subb A, 0x37                             ?
0x1c81: 50 05      jnc 0x1c88                               ?
0x1c83: 74 22      mov A, #0x22                             ?
0x1c85: 93         movc A, @A+DPTR                          ?
0x1c86: 2d         add A, R5                                ?
0x1c87: fd         mov R5, A                                ?
0x1c88: f1 f2      acall 0x1ff2                             ?
0x1c8a: 91 ae      acall 0x1cae                             ?
0x1c8c: 02 10 4a   ljmp 0x104a                              ?
0x1c8f: 7a 48      mov R2, #0x48                            ?
0x1c91: 91 ae      acall 0x1cae                             ?
0x1c93: f8         mov R0, A                                ?
0x1c94: a2 e7      mov C, 0xe0.7 [0xe7]                     ?
0x1c96: 74 23      mov A, #0x23                             ?
0x1c98: 50 01      jnc 0x1c9b                               ?
0x1c9a: 04         inc A                                    ?
0x1c9b: 93         movc A, @A+DPTR                          ?
0x1c9c: f9         mov R1, A                                ?
0x1c9d: 50 01      jnc 0x1ca0                               ?
0x1c9f: c8         xch A, R0                                ?
0x1ca0: c3         clr C                                    ?
0x1ca1: 98         subb A, R0                               ?
0x1ca2: 50 02      jnc 0x1ca6                               ?
0x1ca4: e9         mov A, R1                                ?
0x1ca5: fd         mov R5, A                                ?
0x1ca6: ed         mov A, R5                                ?
0x1ca7: a2 e7      mov C, 0xe0.7 [0xe7]                     ?
0x1ca9: 13         rrc A                                    ?
0x1caa: fd         mov R5, A                                ?
0x1cab: 02 10 4d   ljmp 0x104d                              ?
0x1cae: 12 05 1d   lcall 0x051d                             ?
0x1cb1: 2d         add A, R5                                ?
0x1cb2: c3         clr C                                    ?
0x1cb3: 94 14      subb A, #0x14                            ?
0x1cb5: fd         mov R5, A                                ?
0x1cb6: 22         ret                                      ?
0x1cb7: 20 1a 51   jb 0x23.2 [0x1a], 0x1d0b                 ?
0x1cba: 20 19 4e   jb 0x23.1 [0x19], 0x1d0b                 ?
0x1cbd: 20 1d 4b   jb 0x23.5 [0x1d], 0x1d0b                 ?
0x1cc0: 00         nop                                      ?
0x1cc1: 00         nop                                      ?
0x1cc2: 00         nop                                      ?
0x1cc3: 74 4b      mov A, #0x4b                             ?
0x1cc5: 93         movc A, @A+DPTR                          ?
0x1cc6: b5 37 00   cjne A, 0x37, 0x1cc9                     ?
0x1cc9: 40 40      jc 0x1d0b                                ?
0x1ccb: 74 4c      mov A, #0x4c                             ?
0x1ccd: 93         movc A, @A+DPTR                          ?
0x1cce: b5 49 00   cjne A, 0x49, 0x1cd1                     ?
0x1cd1: 50 15      jnc 0x1ce8                               ?
0x1cd3: 30 25 35   jnb 0x24.5 [0x25], 0x1d0b                ?
0x1cd6: 20 21 09   jb 0x24.1 [0x21], 0x1ce2                 ?
0x1cd9: d2 21      setb 0x24.1 [0x21]                       ?
0x1cdb: c2 22      clr 0x24.2 [0x22]                        ?
0x1cdd: 74 4d      mov A, #0x4d                             ?
0x1cdf: 93         movc A, @A+DPTR                          ?
0x1ce0: f5 3f      mov 0x3f, A                              ?
0x1ce2: e5 3f      mov A, 0x3f                              ?
0x1ce4: 60 25      jz 0x1d0b                                ?
0x1ce6: 80 02      sjmp 0x1cea                              ?
0x1ce8: c2 21      clr 0x24.1 [0x21]                        ?
0x1cea: 30 2c 04   jnb 0x25.4 [0x2c], 0x1cf1                ?
0x1ced: 74 6e      mov A, #0x6e                             ?
0x1cef: 80 07      sjmp 0x1cf8                              ?
0x1cf1: 74 49      mov A, #0x49                             ?
0x1cf3: 20 18 02   jb 0x23.0 [0x18], 0x1cf8                 ?
0x1cf6: 74 48      mov A, #0x48                             ?
0x1cf8: 93         movc A, @A+DPTR                          ?
0x1cf9: fa         mov R2, A                                ?
0x1cfa: 20 25 04   jb 0x24.5 [0x25], 0x1d01                 ?
0x1cfd: 74 4a      mov A, #0x4a                             ?
0x1cff: 93         movc A, @A+DPTR                          ?
0x1d00: 2a         add A, R2                                ?
0x1d01: c3         clr C                                    ?
0x1d02: 95 13      subb A, 0x13                             ?
0x1d04: 92 25      mov 0x24.5 [0x25], C                     ?
0x1d06: 12 0b 50   lcall 0x0b50                             ?
0x1d09: 80 02      sjmp 0x1d0d                              ?
0x1d0b: c2 25      clr 0x24.5 [0x25]                        ?
0x1d0d: 02 0a fb   ljmp 0x0afb                              ?
0x1d10: 74 02      mov A, #0x02                             ?
0x1d12: 2a         add A, R2                                ?
0x1d13: fa         mov R2, A                                ?
0x1d14: 22         ret                                      ?
0x1d15: 7a 3e      mov R2, #0x3e                            ?
0x1d17: 20 2e 05   jb 0x25.6 [0x2e], 0x1d1f                 ?
0x1d1a: 30 b4 02   jnb 0xb0.4 [0xb4], 0x1d1f                ?
0x1d1d: 7a 41      mov R2, #0x41                            ?
0x1d1f: 02 0a 65   ljmp 0x0a65                              ?
0x1d22: ff         mov R7, A                                ?
0x1d23: 90 11 2e   mov DPTR, #0x112e                        ?
0x1d26: 12 05 cd   lcall 0x05cd                             ?
0x1d29: c2 e2      clr 0xe0.2 [0xe2]                        ?
0x1d2b: 24 1b      add A, #0x1b                             ?
0x1d2d: 93         movc A, @A+DPTR                          ?
0x1d2e: f5 f0      mov 0xf0, A                              ?
0x1d30: 7a 2a      mov R2, #0x2a                            ?
0x1d32: 12 05 1d   lcall 0x051d                             ?
0x1d35: a4         mul AB                                   ?
0x1d36: af f0      mov R7, 0xf0                             ?
0x1d38: fe         mov R6, A                                ?
0x1d39: 75 50 02   mov 0x50, #0x02                          ?
0x1d3c: 30 2f 05   jnb 0x25.7 [0x2f], 0x1d44                ?
0x1d3f: 74 6b      mov A, #0x6b                             ?
0x1d41: 93         movc A, @A+DPTR                          ?
0x1d42: b1 f0      acall 0x1df0                             ?
0x1d44: 30 1a 62   jnb 0x23.2 [0x1a], 0x1da9                ?
0x1d47: 7a 28      mov R2, #0x28                            ?
0x1d49: 74 1f      mov A, #0x1f                             ?
0x1d4b: 93         movc A, @A+DPTR                          ?
0x1d4c: b5 13 00   cjne A, 0x13, 0x1d4f                     ?
0x1d4f: 50 01      jnc 0x1d52                               ?
0x1d51: 0a         inc R2                                   ?
0x1d52: 12 05 1d   lcall 0x051d                             ?
0x1d55: f5 3c      mov 0x3c, A                              ?
0x1d57: 7a 53      mov R2, #0x53                            ?
0x1d59: 12 05 1d   lcall 0x051d                             ?
0x1d5c: fc         mov R4, A                                ?
0x1d5d: 7b 05      mov R3, #0x05                            ?
0x1d5f: 79 08      mov R1, #0x08                            ?
0x1d61: 20 0c 14   jb 0x21.4 [0x0c], 0x1d78                 ?
0x1d64: 12 05 1d   lcall 0x051d                             ?
0x1d67: c3         clr C                                    ?
0x1d68: 95 37      subb A, 0x37                             ?
0x1d6a: 40 07      jc 0x1d73                                ?
0x1d6c: 74 1a      mov A, #0x1a                             ?
0x1d6e: 93         movc A, @A+DPTR                          ?
0x1d6f: 95 4d      subb A, 0x4d                             ?
0x1d71: 50 22      jnc 0x1d95                               ?
0x1d73: d2 0c      setb 0x21.4 [0x0c]                       ?
0x1d75: 75 4d 00   mov 0x4d, #0x00                          ?
0x1d78: 7a 55      mov R2, #0x55                            ?
0x1d7a: 12 05 1d   lcall 0x051d                             ?
0x1d7d: f5 f0      mov 0xf0, A                              ?
0x1d7f: 12 05 1d   lcall 0x051d                             ?
0x1d82: a4         mul AB                                   ?
0x1d83: ec         mov A, R4                                ?
0x1d84: 20 e7 07   jb 0xe0.7 [0xe7], 0x1d8e                 ?
0x1d87: 23         rl A                                     ?
0x1d88: c9         xch A, R1                                ?
0x1d89: 23         rl A                                     ?
0x1d8a: c9         xch A, R1                                ?
0x1d8b: 1b         dec R3                                   ?
0x1d8c: 80 f6      sjmp 0x1d84                              ?
0x1d8e: a4         mul AB                                   ?
0x1d8f: ac f0      mov R4, 0xf0                             ?
0x1d91: 30 e7 01   jnb 0xe0.7 [0xe7], 0x1d95                ?
0x1d94: 0c         inc R4                                   ?
0x1d95: ec         mov A, R4                                ?
0x1d96: b5 01 00   cjne A, 0x01, 0x1d99                     ?
0x1d99: 40 0b      jc 0x1da6                                ?
0x1d9b: 12 04 d9   lcall 0x04d9                             ?
0x1d9e: e5 50      mov A, 0x50                              ?
0x1da0: 2b         add A, R3                                ?
0x1da1: 12 05 09   lcall 0x0509                             ?
0x1da4: f5 50      mov 0x50, A                              ?
0x1da6: 02 1d dd   ljmp 0x1ddd                              ?
0x1da9: 20 2d 04   jb 0x25.5 [0x2d], 0x1db0                 ?
0x1dac: f1 f2      acall 0x1ff2                             ?
0x1dae: a1 b3      ajmp 0x1db3                              ?
0x1db0: 12 1d 10   lcall 0x1d10                             ?
0x1db3: 12 05 1d   lcall 0x051d                             ?
0x1db6: f5 f0      mov 0xf0, A                              ?
0x1db8: 7a 2f      mov R2, #0x2f                            ?
0x1dba: 30 18 01   jnb 0x23.0 [0x18], 0x1dbe                ?
0x1dbd: 0a         inc R2                                   ?
0x1dbe: 12 05 1d   lcall 0x051d                             ?
0x1dc1: a4         mul AB                                   ?
0x1dc2: e5 f0      mov A, 0xf0                              ?
0x1dc4: b1 e7      acall 0x1de7                             ?
0x1dc6: e5 3c      mov A, 0x3c                              ?
0x1dc8: b1 e7      acall 0x1de7                             ?
0x1dca: 7a 31      mov R2, #0x31                            ?
0x1dcc: 20 18 07   jb 0x23.0 [0x18], 0x1dd6                 ?
0x1dcf: 7a 4b      mov R2, #0x4b                            ?
0x1dd1: 20 19 02   jb 0x23.1 [0x19], 0x1dd6                 ?
0x1dd4: 7a 4f      mov R2, #0x4f                            ?
0x1dd6: f1 f2      acall 0x1ff2                             ?
0x1dd8: 12 05 1d   lcall 0x051d                             ?
0x1ddb: b1 f0      acall 0x1df0                             ?
0x1ddd: 02 10 50   ljmp 0x1050                              ?
0x1de0: 8e 4e      mov 0x4e, R6                             ?
0x1de2: 8f 4f      mov 0x4f, R7                             ?
0x1de4: 02 10 53   ljmp 0x1053                              ?
0x1de7: 60 12      jz 0x1dfb                                ?
0x1de9: 24 80      add A, #0x80                             ?
0x1deb: 50 03      jnc 0x1df0                               ?
0x1ded: 13         rrc A                                    ?
0x1dee: 05 50      inc 0x50                                 ?
0x1df0: 12 04 d9   lcall 0x04d9                             ?
0x1df3: e5 50      mov A, 0x50                              ?
0x1df5: 04         inc A                                    ?
0x1df6: 12 05 09   lcall 0x0509                             ?
0x1df9: f5 50      mov 0x50, A                              ?
0x1dfb: 22         ret                                      ?
0x1dfc: ff         mov R7, A                                ?
0x1dfd: ff         mov R7, A                                ?
0x1dfe: ff         mov R7, A                                ?
0x1dff: ff         mov R7, A                                ?
0x1e00: 88 f0      mov 0xf0, R0                             ?
0x1e02: 75 a0 19   mov 0xa0, #0x19                          ?
0x1e05: 78 1b      mov R0, #0x1b                            ?
0x1e07: b8 1b 04   cjne R0, #0x1b, 0x1e0e                   ?
0x1e0a: d2 d5      setb 0xd0.5 [0xd5]                       ?
0x1e0c: 80 2d      sjmp 0x1e3b                              ?
0x1e0e: e6         mov A, @R0                               ?
0x1e0f: f2         movx @R0, A                              ?
0x1e10: 75 a0 1b   mov 0xa0, #0x1b                          ?
0x1e13: 78 31      mov R0, #0x31                            ?
0x1e15: b8 31 06   cjne R0, #0x31, 0x1e1e                   ?
0x1e18: e6         mov A, @R0                               ?
0x1e19: 24 0a      add A, #0x0a                             ?
0x1e1b: 23         rl A                                     ?
0x1e1c: 80 01      sjmp 0x1e1f                              ?
0x1e1e: e6         mov A, @R0                               ?
0x1e1f: f2         movx @R0, A                              ?
0x1e20: 05 a0      inc 0xa0                                 ?
0x1e22: e5 37      mov A, 0x37                              ?
0x1e24: f2         movx @R0, A                              ?
0x1e25: 05 a0      inc 0xa0                                 ?
0x1e27: e5 49      mov A, 0x49                              ?
0x1e29: f2         movx @R0, A                              ?
0x1e2a: 05 a0      inc 0xa0                                 ?
0x1e2c: e5 10      mov A, 0x10                              ?
0x1e2e: f2         movx @R0, A                              ?
0x1e2f: 05 a0      inc 0xa0                                 ?
0x1e31: e5 13      mov A, 0x13                              ?
0x1e33: f2         movx @R0, A                              ?
0x1e34: 80 1a      sjmp 0x1e50                              ?
0x1e36: 75 a0 98   mov 0xa0, #0x98                          ?
0x1e39: c2 d5      clr 0xd0.5 [0xd5]                        ?
0x1e3b: 74 60      mov A, #0x60                             ?
0x1e3d: f4         cpl A                                    ?
0x1e3e: 04         inc A                                    ?
0x1e3f: 25 1b      add A, 0x1b                              ?
0x1e41: 23         rl A                                     ?
0x1e42: 23         rl A                                     ?
0x1e43: f8         mov R0, A                                ?
0x1e44: e5 1c      mov A, 0x1c                              ?
0x1e46: 33         rlc A                                    ?
0x1e47: 33         rlc A                                    ?
0x1e48: 33         rlc A                                    ?
0x1e49: 54 03      anl A, #0x03                             ?
0x1e4b: 38         addc A, R0                               ?
0x1e4c: f2         movx @R0, A                              ?
0x1e4d: 10 d5 c0   jbc 0xd0.5 [0xd5], 0x1e10                ?
0x1e50: a8 f0      mov R0, 0xf0                             ?
0x1e52: 22         ret                                      ?
0x1e53: 75 28 80   mov 0x28, #0x80                          ?
0x1e56: 75 26 00   mov 0x26, #0x00                          ?
0x1e59: 75 29 ff   mov 0x29, #0xff                          ?
0x1e5c: d2 2b      setb 0x25.3 [0x2b]                       ?
0x1e5e: d2 9b      setb 0x98.3 [0x9b]                       ?
0x1e60: c2 99      clr 0x98.1 [0x99]                        ?
0x1e62: 75 99 ff   mov 0x99, #0xff                          ?
0x1e65: 30 99 fd   jnb 0x98.1 [0x99], 0x1e65                ?
0x1e68: c2 9b      clr 0x98.3 [0x9b]                        ?
0x1e6a: c2 98      clr 0x98.0 [0x98]                        ?
0x1e6c: 22         ret                                      ?
0x1e6d: 30 1f 01   jnb 0x23.7 [0x1f], 0x1e71                ?
0x1e70: 22         ret                                      ?
0x1e71: 30 1e 01   jnb 0x23.6 [0x1e], 0x1e75                ?
0x1e74: 22         ret                                      ?
0x1e75: 30 2b 25   jnb 0x25.3 [0x2b], 0x1e9d                ?
0x1e78: c2 2b      clr 0x25.3 [0x2b]                        ?
0x1e7a: 20 98 03   jb 0x98.0 [0x98], 0x1e80                 ?
0x1e7d: d2 1f      setb 0x23.7 [0x1f]                       ?
0x1e7f: 22         ret                                      ?
0x1e80: e5 99      mov A, 0x99                              ?
0x1e82: b4 ee 0e   cjne A, #0xee, 0x1e93                    ?
0x1e85: d2 1e      setb 0x23.6 [0x1e]                       ?
0x1e87: c2 99      clr 0x98.1 [0x99]                        ?
0x1e89: 75 99 ff   mov 0x99, #0xff                          ?
0x1e8c: 30 99 fd   jnb 0x98.1 [0x99], 0x1e8c                ?
0x1e8f: 75 98 b0   mov 0x98, #0xb0                          ?
0x1e92: 22         ret                                      ?
0x1e93: e5 99      mov A, 0x99                              ?
0x1e95: c3         clr C                                    ?
0x1e96: 94 ff      subb A, #0xff                            ?
0x1e98: 60 16      jz 0x1eb0                                ?
0x1e9a: d2 1f      setb 0x23.7 [0x1f]                       ?
0x1e9c: 22         ret                                      ?
0x1e9d: 30 98 10   jnb 0x98.0 [0x98], 0x1eb0                ?
0x1ea0: e5 29      mov A, 0x29                              ?
0x1ea2: c3         clr C                                    ?
0x1ea3: 94 ff      subb A, #0xff                            ?
0x1ea5: 60 09      jz 0x1eb0                                ?
0x1ea7: 90 11 da   mov DPTR, #0x11da                        ?
0x1eaa: e5 29      mov A, 0x29                              ?
0x1eac: 93         movc A, @A+DPTR                          ?
0x1ead: f9         mov R1, A                                ?
0x1eae: a7 99      mov @R1, 0x99                            ?
0x1eb0: 90 11 d1   mov DPTR, #0x11d1                        ?
0x1eb3: e4         clr A                                    ?
0x1eb4: 93         movc A, @A+DPTR                          ?
0x1eb5: 12 1e f9   lcall 0x1ef9                             ?
0x1eb8: a3         inc DPTR                                 ?
0x1eb9: e4         clr A                                    ?
0x1eba: 93         movc A, @A+DPTR                          ?
0x1ebb: 12 1e f9   lcall 0x1ef9                             ?
0x1ebe: a3         inc DPTR                                 ?
0x1ebf: e4         clr A                                    ?
0x1ec0: 93         movc A, @A+DPTR                          ?
0x1ec1: 12 1e f9   lcall 0x1ef9                             ?
0x1ec4: a9 7a      mov R1, 0x7a                             ?
0x1ec6: c2 99      clr 0x98.1 [0x99]                        ?
0x1ec8: e7         mov A, @R1                               ?
0x1ec9: f5 99      mov 0x99, A                              ?
0x1ecb: 30 99 fd   jnb 0x98.1 [0x99], 0x1ecb                ?
0x1ece: d2 9b      setb 0x98.3 [0x9b]                       ?
0x1ed0: 05 29      inc 0x29                                 ?
0x1ed2: e5 29      mov A, 0x29                              ?
0x1ed4: b4 06 08   cjne A, #0x06, 0x1edf                    ?
0x1ed7: 75 29 ff   mov 0x29, #0xff                          ?
0x1eda: 74 ff      mov A, #0xff                             ?
0x1edc: 02 1e ea   ljmp 0x1eea                              ?
0x1edf: 90 11 d4   mov DPTR, #0x11d4                        ?
0x1ee2: 93         movc A, @A+DPTR                          ?
0x1ee3: f9         mov R1, A                                ?
0x1ee4: e7         mov A, @R1                               ?
0x1ee5: b4 ff 02   cjne A, #0xff, 0x1eea                    ?
0x1ee8: 74 fe      mov A, #0xfe                             ?
0x1eea: c2 99      clr 0x98.1 [0x99]                        ?
0x1eec: f5 99      mov 0x99, A                              ?
0x1eee: 30 99 fd   jnb 0x98.1 [0x99], 0x1eee                ?
0x1ef1: c2 9b      clr 0x98.3 [0x9b]                        ?
0x1ef3: c2 98      clr 0x98.0 [0x98]                        ?
0x1ef5: 90 11 60   mov DPTR, #0x1160                        ?
0x1ef8: 22         ret                                      ?
0x1ef9: b4 ff 1b   cjne A, #0xff, 0x1f17                    ?
0x1efc: 30 1d 04   jnb 0x23.5 [0x1d], 0x1f03                ?
0x1eff: e4         clr A                                    ?
0x1f00: 02 1f 19   ljmp 0x1f19                              ?
0x1f03: e5 4b      mov A, 0x4b                              ?
0x1f05: a2 e4      mov C, 0xe0.4 [0xe4]                     ?
0x1f07: 54 0f      anl A, #0x0f                             ?
0x1f09: c4         swap A                                   ?
0x1f0a: f5 f0      mov 0xf0, A                              ?
0x1f0c: e5 4a      mov A, 0x4a                              ?
0x1f0e: 54 f0      anl A, #0xf0                             ?
0x1f10: c4         swap A                                   ?
0x1f11: 45 f0      orl A, 0xf0                              ?
0x1f13: 13         rrc A                                    ?
0x1f14: 02 1f 19   ljmp 0x1f19                              ?
0x1f17: f9         mov R1, A                                ?
0x1f18: e7         mov A, @R1                               ?
0x1f19: c2 99      clr 0x98.1 [0x99]                        ?
0x1f1b: f5 99      mov 0x99, A                              ?
0x1f1d: 30 99 fd   jnb 0x98.1 [0x99], 0x1f1d                ?
0x1f20: 22         ret                                      ?
0x1f21: 20 1f 07   jb 0x23.7 [0x1f], 0x1f2b                 ?
0x1f24: 20 1e 04   jb 0x23.6 [0x1e], 0x1f2b                 ?
0x1f27: e5 26      mov A, 0x26                              ?
0x1f29: 2d         add A, R5                                ?
0x1f2a: fd         mov R5, A                                ?
0x1f2b: 81 8f      ajmp 0x1c8f                              ?
0x1f2d: 20 1f 07   jb 0x23.7 [0x1f], 0x1f37                 ?
0x1f30: 20 1e 04   jb 0x23.6 [0x1e], 0x1f37                 ?
0x1f33: e5 28      mov A, 0x28                              ?
0x1f35: b1 f0      acall 0x1df0                             ?
0x1f37: 02 1d e0   ljmp 0x1de0                              ?
0x1f3a: 75 89 11   mov 0x89, #0x11                          ?
0x1f3d: 75 b8 02   mov 0xb8, #0x02                          ?
0x1f40: 43 a8 85   orl 0xa8, #0x85                          ?
0x1f43: 43 88 05   orl 0x88, #0x05                          ?
0x1f46: 90 11 60   mov DPTR, #0x1160                        ?
0x1f49: 75 81 63   mov 0x81, #0x63                          ?
0x1f4c: c2 92      clr 0x90.2 [0x92]                        ?
0x1f4e: 74 0d      mov A, #0x0d                             ?
0x1f50: 93         movc A, @A+DPTR                          ?
0x1f51: f5 2a      mov 0x2a, A                              ?
0x1f53: 12 06 3f   lcall 0x063f                             ?
0x1f56: 12 10 1a   lcall 0x101a                             ?
0x1f59: 12 1f 87   lcall 0x1f87                             ?
0x1f5c: 12 1b c1   lcall 0x1bc1                             ?
0x1f5f: 12 1f 87   lcall 0x1f87                             ?
0x1f62: 12 1c 24   lcall 0x1c24                             ?
0x1f65: 12 10 1a   lcall 0x101a                             ?
0x1f68: 12 1f 87   lcall 0x1f87                             ?
0x1f6b: 12 07 b7   lcall 0x07b7                             ?
0x1f6e: 12 1f 87   lcall 0x1f87                             ?
0x1f71: 12 10 1a   lcall 0x101a                             ?
0x1f74: 12 1d 23   lcall 0x1d23                             ?
0x1f77: 12 1f 87   lcall 0x1f87                             ?
0x1f7a: 02 10 1d   ljmp 0x101d                              ?
0x1f7d: 30 1c ba   jnb 0x23.4 [0x1c], 0x1f3a                ?
0x1f80: 12 02 1d   lcall 0x021d                             ?
0x1f83: 12 03 0c   lcall 0x030c                             ?
0x1f86: 22         ret                                      ?
0x1f87: 10 17 01   jbc 0x22.7 [0x17], 0x1f8b                ?
0x1f8a: 22         ret                                      ?
0x1f8b: 02 02 c6   ljmp 0x02c6                              ?
0x1f8e: 20 1a 50   jb 0x23.2 [0x1a], 0x1fe1                 ?
0x1f91: 20 18 4d   jb 0x23.0 [0x18], 0x1fe1                 ?
0x1f94: c3         clr C                                    ?
0x1f95: e5 10      mov A, 0x10                              ?
0x1f97: 95 53      subb A, 0x53                             ?
0x1f99: 40 46      jc 0x1fe1                                ?
0x1f9b: f5 03      mov 0x03, A                              ?
0x1f9d: 74 37      mov A, #0x37                             ?
0x1f9f: 93         movc A, @A+DPTR                          ?
0x1fa0: c3         clr C                                    ?
0x1fa1: 95 37      subb A, 0x37                             ?
0x1fa3: 50 05      jnc 0x1faa                               ?
0x1fa5: 75 f0 00   mov 0xf0, #0x00                          ?
0x1fa8: e1 b7      ajmp 0x1fb7                              ?
0x1faa: 7a 1c      mov R2, #0x1c                            ?
0x1fac: 12 05 1d   lcall 0x051d                             ?
0x1faf: f5 f0      mov 0xf0, A                              ?
0x1fb1: f1 f2      acall 0x1ff2                             ?
0x1fb3: 12 05 1d   lcall 0x051d                             ?
0x1fb6: a4         mul AB                                   ?
0x1fb7: 20 0f 03   jb 0x21.7 [0x0f], 0x1fbd                 ?
0x1fba: 85 f0 4c   mov 0xf0, 0x4c                           ?
0x1fbd: 7a 21      mov R2, #0x21                            ?
0x1fbf: 12 05 1d   lcall 0x051d                             ?
0x1fc2: 60 1d      jz 0x1fe1                                ?
0x1fc4: f5 f0      mov 0xf0, A                              ?
0x1fc6: e5 4c      mov A, 0x4c                              ?
0x1fc8: 60 02      jz 0x1fcc                                ?
0x1fca: d2 0f      setb 0x21.7 [0x0f]                       ?
0x1fcc: f1 f2      acall 0x1ff2                             ?
0x1fce: 12 05 1d   lcall 0x051d                             ?
0x1fd1: a4         mul AB                                   ?
0x1fd2: 7a 26      mov R2, #0x26                            ?
0x1fd4: 12 05 1d   lcall 0x051d                             ?
0x1fd7: a4         mul AB                                   ?
0x1fd8: e5 f0      mov A, 0xf0                              ?
0x1fda: b5 3d 00   cjne A, 0x3d, 0x1fdd                     ?
0x1fdd: 40 02      jc 0x1fe1                                ?
0x1fdf: f5 3d      mov 0x3d, A                              ?
0x1fe1: 85 52 53   mov 0x52, 0x53                           ?
0x1fe4: 85 51 52   mov 0x51, 0x52                           ?
0x1fe7: 85 10 51   mov 0x10, 0x51                           ?
0x1fea: e5 3d      mov A, 0x3d                              ?
0x1fec: 12 1d e7   lcall 0x1de7                             ?
0x1fef: 02 04 0d   ljmp 0x040d                              ?
0x1ff2: e4         clr A                                    ?
0x1ff3: a2 b4      mov C, 0xb0.4 [0xb4]                     ?
0x1ff5: 33         rlc A                                    ?
0x1ff6: a2 2e      mov C, 0x25.6 [0x2e]                     ?
0x1ff8: 50 03      jnc 0x1ffd                               ?
0x1ffa: 33         rlc A                                    ?
0x1ffb: 2a         add A, R2                                ?
0x1ffc: fa         mov R2, A                                ?
0x1ffd: 22         ret                                      ?
0x1ffe: 01 ed      ajmp 0x18ed                              ?
