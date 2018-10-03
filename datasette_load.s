	*= $0801
	!by $0b,$08,10,0,$9e,'2'
	!by '0','6','1',$00,$00,$00

; Minimal C64 Datasette program loader
; by Michael Steil, http://www.pagetable.com/

; length of the three types of pulses
; measured in 8 PAL clock cycles
length_short  = $30
length_medium = $42
length_long   = $56

; to differentiate the types of pulses, we
; take the arithmetic mean as a threshold
threshold_short_medium = (length_short + length_medium) / 2
threshold_medium_long = (length_medium + length_long) / 2

ptr = 2 ; 3
tmp_cntdwn = 4
count = 5
buffer = $033c

; wait for PLAY to be pressed
	lda #$10
m1:	bit $01
	bne m1

	sei
	lda $d011
	and #$ff-$10    ;disable screen
	sta $d011
m2:	lda $d012
	bne m2          ;wait for new screen
	lda $01
	and #$ff-$20    ;motor on
	sta $01

	lda #7          ;divide timer b by 8
	ldx #0
	sta $dd04
	stx $dd05
	lda #%00010001
	sta $dd0e       ;start timer a
	dex ; $ff
	stx $dd06       ;always start timer b
	stx $dd07       ;from $ffff
	; don't start timer b until the first pulse

; get header
	ldx #<buffer
	ldy #>buffer
	jsr get_countdown
	lda #192
	jsr get_block

; get data
	ldx buffer + 1
	ldy buffer + 2
	jsr get_countdown

m3:	lda #0
	jsr get_block
	inc ptr + 1
	bcc m3

	lda $d011
	ora #$10
	sta $d011       ;screen on
	lda 1
	ora #$20        ;motor off
	sta 1
	rts

;****************************************
; get_pulse
;  measures the length of a pulse
;  in:  -
;  out: A: $ff-(length of pulse)
;       C: 1: short pulse
;          0: medium or long pulse
;  destroys X
;****************************************
get_pulse:
	lda #$10
p1:	bit $dc0d       ;wait for start
	bne p1          ;of pulse

	ldx #%01011001  ;value to restart timer b
p2:	bit $dc0d       ;wait for end
	beq p2          ;of pulse

	lda $dd06       ;read timer b
	stx $dd0f       ;restart timer b
	cmp #$ff-threshold_short_medium
	rts             ;c=1: short

;****************************************
; get_byte
;  reads a byte
;  in:  -
;  out: A: byte read
;       C: 1: end of file
;  destroys X
;****************************************
get_byte:
; wait for byte marker
	jsr get_pulse
	cmp #$ff-threshold_medium_long
	bcs get_byte    ;not long
	jsr get_pulse
	bcs b2          ;short = end of data
; get 8 bits
	lda #%01111111  ;canary bit at #7
b1:	pha
	jsr get_pulse   ;ignore first
	jsr get_pulse
	pla
	ror             ;shift in bit
	bcs b1          ;until canary bit
b2:	rts

;****************************************
; get_countdown
;  returns after a countdown is detected
;  in:  X/Y: load address (for later)
;  out: -
;  destroys A, X, Y
;****************************************
get_countdown:
	stx ptr
	sty ptr + 1     ;load address
c0:	jsr get_byte
c1:	ldy #$89
	sty tmp_cntdwn  ;start with $89
	ldy #9
	bne c2
cx:	jsr get_byte
c2:	cmp tmp_cntdwn
	bne c4
	dec tmp_cntdwn
	dey
	bne cx
	rts
c4:	cpy #9           ;first byte wrong?
	beq c0           ;then read new byte
	bne c1           ;compare against $89

;****************************************
; get_block
;  read up to 256 bytes into a buffer
;  in:  A:   number of bytes
;       ptr: buffer
;  out: C:   1: end of file
;  destroys A, X, Y
;****************************************
get_block:
	sta count
	ldy #0
g1:	jsr get_byte
	bcs g2
	sta (ptr),y
	iny
	dec count
	bne g1
g2:	rts
