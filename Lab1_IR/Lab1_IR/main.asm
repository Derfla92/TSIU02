;
; Lab1_IR.asm
;
; Created: 2023-11-15 12:35:44
; Author : AlfredSpjutMolin
;



; Replace with your application code

.equ OUTER_DELAY = 10
.equ INNER_DELAY = $1F

ldi r16, HIGH(RAMEND)
out SPH,r16
ldi r16,LOW(RAMEND)
out SPL,r16


ldi r16, $FF
out DDRB, r16

idle:	
	sbis PINA,0
	rjmp idle

	call halfdelay
	sbis PINA,0
	rjmp idle
process:
	clr r20
	call readBits
	out PORTB, r20
	rjmp idle

readBits:
	ldi r18,4 ; loopcounter
readBitsInner:
	call fulldelay
	call readBit
	dec r18
	breq readBitsDone
	lsl r20
	rjmp readBitsInner
readBitsDone:
	ret

readBit:
	in r19,PINA
	or r20,r19
	ret


fulldelay:
	sbi PORTB,7
	ldi r16,OUTER_DELAY ; Decimal bas
fulldelayYttreLoop:
	ldi r17,INNER_DELAY
fulldelayInreLoop:
	dec r17
	brne fulldelayInreLoop
	dec r16
	brne fulldelayYttreLoop
	cbi PORTB,7
	ret

halfdelay:
	sbi PORTB,7
	ldi r16,OUTER_DELAY/2 ; Decimal bas
halfdelayYttreLoop:
	ldi r17,INNER_DELAY
halfdelayInreLoop:
	dec r17
	brne halfdelayInreLoop
	dec r16
	brne halfdelayYttreLoop
	cbi PORTB,7
	ret