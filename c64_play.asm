; ---------------------------------------------------------------------
; DRO AdLib OPL2 player for Commodore 64 equipped with SFX
; Sound Expander cartridge with YM3812 chip (the "normal" chip
; this cartridge was shipped with may work, but since OPL2 features
; do not exist on those, music will be somewhat "odd" to listen to).
; VERSION: 1.2a
; ---------------------------------------------------------------------
; (C)2011 LGB (Gábor Lénárt) lgb@lgb.hu, this program can be used
; according to the GNU/GPL 2 or 3 (or later, if a new one is released) license.
; License: http://www.gnu.org/licenses/gpl-2.0.html
; License: http://www.gnu.org/licenses/gpl-3.0.html
; Personal note: PLEASE drop me a mail if you have ideas to modify
; this program (patches, bugs, features etc) or if you use it in your work,
; as the GPL defines, you should provide the source of your work then
; too as it must be GPL then. Thanks! Of course any feedback is welcome, anyway.
; ---------------------------------------------------------------------
; Needs Sound Expander cartridge equipped with YM3812 chip.
; It plays DOSBOX captured "DRO" files, version2 format is supported only
; (see later in the source at the .DEFINE DRO_FILE statement).
; ---------------------------------------------------------------------
; QUICK INSTALL/TEST HOWTO:
;
; Assembler:
;	Get ca65 from the cc65 suite (www.cc65.org). Yes, it's a C
;	compiler for 6502 in general, but we need only the
;	assembler&linker only, not the compiler itself.
; Preparation:
;	You must get a DRO (v2) file from somewhere (grab one with DOSBOX
;	for example), you must place it into the directory where this
;	asm source is, and you may want to modify the source at the
;	.DEFINE DRO_FILE for incbin'ing the right file. I can't
;	distribute music too much, since I haven't got an own one ...
;	PLEASE CONTACT ME, if you have DRO file which can be distributed
;	- as an example - with the source! IT WOULD BE REALLY NICE!
; Compilation:
;	Command: cl65 -t c64 -o c64_play.prg c64_play.asm
;	Do not forget the "-t c64"!
; Test (with VICE emulator):
;	Command: x64 -sfxse -sfxsetype 3812 -autostart c64_play.prg
;	You can configure the SFX Sound Expander cartridge "by hand"
;	too in the menu of the VICE, of course. About VICE: it did not
;	work for me (version 2.3) on Linux (no sound and/or even crash),
;	also I've heard reports
;	that it has problems with Windows too (I don't have Windows,
;	so I can't tell) sometimes (?) at least. You may want to check
;	VICE's SVN repository out for the development release; it works
;	for me now (2.3.11, SVN revision I've tested with: 24920)!!
;	The best thing is test on the real hardware though!
;	UPDATE:
;	* thanks to Raj for testing it on a real hardware :)
;	* thanks to Soci for suggesting devel version of VICE to test with
; ---------------------------------------------------------------------
; What I could test with VICE (video):
;	http://www.youtube.com/watch?v=umiL62CPObg
; ---------------------------------------------------------------------
; TODO list:
;	* rework the player to use IRQ for playing
;	* get a "safe" (free to distribute) DRO music to include
;	* SID mode: try to mimic the cartridge with SID: will sound
;	  awful (with rapidly changed channels) but it can be used to
;	  test the stuff without a cartridge too
; ---------------------------------------------------------------------

.ZEROPAGE

ZP:	.RES 2 ; general purpose zeropage locations we use (two bytes)
song_p:	.RES 2 ; byte pointer inside the DRO stream (two bytes)

.BSS

screen_reg_addrs: .RES 512

.SEGMENT "ZPSAVE"  ; not used here so much

; BASIC stub: do NOT place anything into the STARTUP segment
; before the stub itself!
.SEGMENT "STARTUP"
.WORD basic_loader
basic_loader:
        .WORD @lastline,-1
        .BYTE $9E ; "SYS" basic token
        .BYTE $30+.LOBYTE(main/10000)
        .BYTE $30+.LOBYTE((main .MOD 10000)/1000)
        .BYTE $30+.LOBYTE((main .MOD 1000)/100)
        .BYTE $30+.LOBYTE((main .MOD 100)/10)
        .BYTE $30+.LOBYTE( main .MOD 10)
        .BYTE 0
@lastline:
        .WORD 0,0
        .BYTE 0
; end of BASIC stub


; Character remapping for screen codes:
; We manipulate screen directly, and I don't want to convert texts
; in the asm file, so let's just leave it for the assembler:
; CA65 can make custom charset conversion configred by .CHARMAP
; constructs: conversion from ASCII (the assembly file's charset)
; to C64 screen codes (can be poked directly into the video RAM).
; Not remapped characters left as-is (by c64 target) hopefully
; most of them at least are OK :)

.REPEAT 26,l
.CHARMAP l+97,l+1 ; lower case
.CHARMAP l+65,l+65 ; upper case
.ENDREP
.CHARMAP 64,0  ; @
.CHARMAP 95,100   ; _

;song_length		= song + 12  ; we don't use length currently, but the label after the included DRO to match against the position counter
cmd_short_delay		= song + 23
cmd_long_delay		= song + 24
codemap_len		= song + 25
codemap			= song + 26

SFX_YM_SELECT_REGISTER	= $DF40
SFX_YM_DATA_REGISTER	= $DF50

SCREEN_ADDRESS		= $0400
COLOR_ADDRESS		= $D800
COLOR_RAM_OFFSET	= COLOR_ADDRESS - SCREEN_ADDRESS
REGDUMP_START_POS	= SCREEN_ADDRESS + 41
SONG_POSITION_POS	= SCREEN_ADDRESS + 24*40
MSG_POS			= SCREEN_ADDRESS + 22*40
SONG_NAME_POS		= SONG_POSITION_POS + 15
DELAY_POS_COLRAM	= MSG_POS + 37 + COLOR_RAM_OFFSET
MSG_COLOR		= 7
HEADER_COLOR		= 13
COMMON_COLOR		= 1
NAME_COLOR		= 14
DELAY_ACTIVE_COLOR	= 1
DELAY_INACTIVE_COLOR	= 11
LINE_COLOR		= 3

; You need a version 2 DRO file here
; DOSBOX 0.74 (maybe 0.73 too, but note: older versions
; produces older formatted DRO files which are NOT supported
; at all!) can produce such a file in OPL2 capture mode
; No check about the file, it must be version 2 DRO, and
; the whole C64 program must fit into the memory of course
; with the DRO included.
; This name is also stored as the song name (and shown in the
; player) however, since we use screen codes, it won't be so
; correct. File name should not be too long because it should
; fit onto the screen. The name is also used to .INCBIN the
; actual file, see later at .INCBIN
;.DEFINE DRO_FILE "dune_title.dro"
.DEFINE DRO_FILE "test.dro"

header: .BYTE " C64 DRO player v1.2a by LGB lgb@lgb.hu "
header_size = * - header

song:
	; Do not put anything extra here: label "song" must be
	; just before the DRO stream, and "song_end" should be
	; after it! Also read note at the .DEFINE line above.
	.INCBIN DRO_FILE
song_end:

dro_file_name: .BYTE DRO_FILE
dro_file_name_size = * - dro_file_name

hextab: .BYTE "0123456789ABCDEF"

msg: .BYTE    "Hold key 'x' to reset C64.     Delay:"
	.BYTE '-'+128
	.BYTE 'S'+128
	.BYTE 'L'+128
msg_size = * - msg


show_reg:
	LDX ZP+1 ; X:=value (since we will reuse it)
	LDY ZP
	LDA screen_reg_addrs,Y
	STA ZP
	LDA screen_reg_addrs+256,Y
	STA ZP+1
	TXA
	LDY #0
show_hex_byte:  ; A=byte, ZP: screen address base, Y = offset (from ZP)
	PHA
	LSR A
	LSR A
	LSR A
	LSR A
	TAX
	LDA hextab,X
	STA (ZP),Y
	PLA
	AND #15
	TAX
	LDA hextab,X
	INY
	STA (ZP),Y
	INY
	RTS



reset_sfx:
	LDA #0
	TAY
:	STY SFX_YM_SELECT_REGISTER ; select YM register
        NOP ; some wait after writing
        NOP
        NOP
        NOP
        STA SFX_YM_DATA_REGISTER ; write to selected YM register now
        LDX #4 ; some more delay we need here ...
:	DEX
        NOP
        BNE :-
        INY
        STY $D020 ; it is really not needed :)
        BNE :--
	RTS




main:
	; Disable interrupts (timing can be "perfect")
	; Note: later, the stuff should be rewritten to be
	; IRQ based player ...
	; The timing is a disaster in the current code:
	; we only count instruction cycles more or less correctly
	; assuming about 1MHz clock (the more accurate value
	; depends on PAL/NTSC, etc). Also, because of other things
	; (fetching byte, writing SFX regs, displaying) needs
	; time and it is not counted, the exact timing is surely bad.
	; This is only a quick TEST, do not except advanced
	; features now.
	SEI
	; Select lower-case character set
	LDA #23
	STA $D018
	; "Nice" black screen, also clear it, with filling the color RAM as well
	LDX #0
	STX $D020
	STX $D021
:
	LDA #' '
	STA SCREEN_ADDRESS,X
	STA SCREEN_ADDRESS+$100,X
	STA SCREEN_ADDRESS+$200,X
	STA SCREEN_ADDRESS+$300,X
	LDA #COMMON_COLOR
	STA COLOR_ADDRESS,X
	STA COLOR_ADDRESS+$100,X
	STA COLOR_ADDRESS+$200,X
	STA COLOR_ADDRESS+$300,X
	INX
	BNE :-
	; Display the top header
:	LDA header,X
	ORA #128 ; in inverse (bit 7 set)
	STA SCREEN_ADDRESS,X
	LDA #HEADER_COLOR 	; with some different color ....
	STA COLOR_ADDRESS,X
	INX
	CPX #header_size
	BNE :-
	; Display the msg
	LDX #0
:	LDA msg,X
	STA MSG_POS,X
	LDA #MSG_COLOR
	STA MSG_POS+COLOR_RAM_OFFSET,X
	INX
	CPX #msg_size
	BNE :-
	; Display song name (note: there is no check about the length, do not use too long name to leave the area of the video RAM)
	LDX #0
:	LDA dro_file_name,X
	ORA #128 ; in inverse (bit 7 set)
	STA SONG_NAME_POS,X
	LDA #NAME_COLOR
	STA SONG_NAME_POS+COLOR_RAM_OFFSET,X
	INX
	CPX #dro_file_name_size
	BNE :-
	; Display lines
	LDX #39
:	LDA #100
	STA MSG_POS-40,X
	LDA #99
	STA MSG_POS+40,X
	LDA #LINE_COLOR
	STA MSG_POS+COLOR_RAM_OFFSET-40,X
	STA MSG_POS+COLOR_RAM_OFFSET+40,X
	DEX
	BPL :-

	; Generate our table for displaying YM registers
	; It's the direct C64 addresses in the video RAM for
	; 0...255 values (AdLib registers).
	LDA #.LOBYTE(screen_reg_addrs)
	STA ZP
	LDA #.HIBYTE(screen_reg_addrs)
	STA ZP+1
	LDY #0 ; AdLib register counter
	LDX #13 ; number of bytes to display within a C64 text line
@scraddrtabfillloop: ; we all love self-modifying code, right?
	; write out low byte of the screen address
	@scraddrtablo = * + 1
	LDA #.LOBYTE(REGDUMP_START_POS)
	STA (ZP),Y
	STA @dot
	; write out high byte of the screen address
	INC ZP+1
	@scraddrtabhi = * + 1
	LDA #.HIBYTE(REGDUMP_START_POS)
	STA (ZP),Y
	STA @dot+1
	DEC ZP+1
	; display a dot
	LDA #46
	@dot = * + 1
	STA $FFFF
	; see, if we have to move to next line instead
	LDA #3 ; the increment needed
	DEX
	CLC
	BNE :+
	ADC #1
	LDX #13
:
	ADC @scraddrtablo
	STA @scraddrtablo
	BCC :+
	INC @scraddrtabhi
:
	INY
	BNE @scraddrtabfillloop

	; Program CIA-1 for our simple kbd "scan", we only check a single matrix row/col,
	; so this is the only place where it's needed to setup
	; they key is "x" what we're looking for
	LDA #%11111011
	STA $DC00

@main_player:
	; We must find the (C64 memory) address of the first byte
	; to be "played". DRO's header is not a fix sized in length,
	; we must add the size of "codemap table" after it's starting
	; address to get that.

	; Initialize low byte
	LDA #.LOBYTE(codemap)
	CLC
	ADC codemap_len
	STA song_p
	; Initialize high byte
	LDA #.HIBYTE(codemap)
	ADC #0 ; use carry too!
	STA song_p+1
	; show pos info ...
	LDX #.LOBYTE(SONG_POSITION_POS)
	STX ZP
	LDX #.HIBYTE(SONG_POSITION_POS)
	STX ZP+1
	LDY #0
	JSR show_hex_byte  ; song_p high byte is already in A, print it
	LDA song_p
	JSR show_hex_byte  ; also print the low byte then
	LDA #'/'
	STA (ZP),Y
	INY
	INY
	INY
	INY
	INY
	STA (ZP),Y
	INY
	LDA #.HIBYTE(song_end)
	JSR show_hex_byte
	LDA #.LOBYTE(song_end)
	JSR show_hex_byte

	; Clear SFX registers ...
	JSR reset_sfx
	; Start playing actually ...
@play_loop:
	; show current position of playback (C64 memory address)
	LDA #.LOBYTE(SONG_POSITION_POS+5)
	STA ZP
	LDA #.HIBYTE(SONG_POSITION_POS+5)
	STA ZP+1
	LDY #0
	LDA song_p+1
	JSR show_hex_byte
	LDA song_p
	JSR show_hex_byte
	; check keyboard
	JSR @chk_kbd
	; fetch two bytes from the DRO stream, store those in zeropage vars ZP and ZP+1
	; we can't increment pointer in "once" (with Y being 0 then 1, then
	; the pointer increment) as we don't know the
	; stream is algined two 2 bytes boundary (depends on the codemap table
	; size, specific to a given DRO file - even if the start of the file is aligned!)
	LDY #0
	LDA (song_p),Y
	STA ZP
	INC song_p
	BNE :+
	INC song_p+1
:	LDA (song_p),Y
	STA ZP+1
	INC song_p
	BNE :+
	INC song_p+1
:
	; Ok, check the fetched byte now
	LDA ZP ; now we must examine the 1st byte: can be command or codemap position
	CMP cmd_short_delay ; is it a short delay command?
	BEQ @short_delay
	CMP cmd_long_delay  ; is it a long delay command?
	BEQ @long_delay
	; no delay commands: the byte is a codemap position
	TAX ; move to X
	; clear delay info, no delay
	LDA #DELAY_INACTIVE_COLOR
	STA DELAY_POS_COLRAM+1
	STA DELAY_POS_COLRAM+2
	LDA #DELAY_ACTIVE_COLOR
	STA DELAY_POS_COLRAM
	; Convert into register number
	LDA codemap,X
	; Note: we should use delays after writing registers (see: reset_sfx)
	; However, at this point we have enough instructions between writes,
	; so I simply don't need any additional delay (I hope so, at least)
	STA SFX_YM_SELECT_REGISTER
	STA ZP ; store YM register number in ZP
	NOP ; anyway, it seems some delay needed at least HERE (before data write)
	NOP
	LDA ZP+1
	STA SFX_YM_DATA_REGISTER
	; show it!
	JSR show_reg
	; check looping
	LDA song_p+1
	CMP #.HIBYTE(song_end)
	BCC @play_loop
	LDA song_p
	CMP #.LOBYTE(song_end)
	BCC @play_loop
	JMP @main_player ; end of the song: start it again!
; In delay codes we check keyboard to see if we want to exit.
; That also used as a part of the delay.
@short_delay: ; "short delay" in DRO files means waiting X+1 miliseconds
	LDA #DELAY_INACTIVE_COLOR
	STA DELAY_POS_COLRAM
	STA DELAY_POS_COLRAM+2
	LDA #DELAY_ACTIVE_COLOR
	STA DELAY_POS_COLRAM+1
	LDX ZP+1 ; after this, we should wait X+1 msecs
	INX
:	LDY #40  ;25*40=1000 cycles [25=20 - see below - plus 5], about one msec.
:	JSR @chk_kbd ; 6 cycles for JSR, 14 for the subrutine: 20 cycles
	DEY   ; 2 cycles
	BNE :-  ; 3 cycles
	DEX
	BNE :--
	JMP @play_loop
@long_delay: ; "long delay" in DRO files means waiting (X+1)*256 miliseconds
	LDA #DELAY_INACTIVE_COLOR
	STA DELAY_POS_COLRAM
	STA DELAY_POS_COLRAM+1
	LDA #DELAY_ACTIVE_COLOR
	STA DELAY_POS_COLRAM+2
	LDX ZP+1  ; after this, we should wait (X+1)*256 msecs
	INX
:	TXA
	PHA
	LDX #0
:	LDY #40
:	JSR @chk_kbd
	DEY
	BNE :-
	DEX
	BNE :--
	PLA
	TAX
	DEX
	BNE :---
	JMP @play_loop
@chk_kbd:  ; if I am correct, it's about 14 cycles normally
	LDA $DC01	; 4 cycles
	AND #%10000000	; 2 cycles
	BEQ @reset	; 2 cycles (branch is not taken)
	RTS		; 6 cycles
@reset: ; It's now safe to turn off your computer. :)
	LDA #%00001011
	STA $D011
	JSR reset_sfx
	JMP 64738
