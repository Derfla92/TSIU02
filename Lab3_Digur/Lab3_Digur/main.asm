;
; Lab3_Digur.asm
;
; Created: 2023-12-07 11:35:09
; Author : alfre
;




; Ser till att hoppa över MESSAGE och BTAB 
; för att de inte ska tolkas som instruktioner.
jmp HW_INIT

; Avbrottsvektorer
.org INT0addr
jmp BCD

.org INT1addr
jmp MUX

.org INT_VECTORS_SIZE

; Tabeller och konstanter

.dseg

TIME: .byte 4
SEG: .byte 1


.cseg

SEGTABLE: .db  $FC, $60, $DA, $F2, $66, $B6, $BE, $E0, $FE, $E6
; Initiera portar in och ut.
; Laddar även stacken.
HW_INIT: 
	ldi r16, $FF
	out DDRB, r16
	ldi r16, $03
	out DDRA, r16
	
	; Laddar stacken
	ldi r16, HIGH(RAMEND)
	out SPH, r16
	ldi r16, LOW(RAMEND)
	out SPL, r16

	; Återställ minnet
	ldi XH, HIGH(TIME)
	ldi XL, LOW(TIME)
	clr r16
	st X+, r16
	st X+, r16
	st X+, r16
	st X+, r16

	; Ställa in resande flank på ext_INT0 och ext_INT1
	ldi r16,(1 << ISC00) | (1 << ISC01) | (1 << ISC10) | (1 << ISC11) 
	out MCUCR, r16

	; Aktivera ext_INT0 och ext_INT1
	ldi r16,(1<<INT0) | (1<<INT1)
	out GICR, r16

	; Aktivera avbrott globalt
	sei

MAIN:

	rjmp MAIN


BCD:
	push r16
	in r16, SREG
	push r16
	push r17
	push r18

	push XH
	push XL
	
	ldi r17, 0
NEXT_TIME:
	cpi r17, 4
	breq BCD_RET
	ldi XH,HIGH(TIME)
	ldi XL,LOW(TIME)
	add XL, r17
	ld r16, X

	ldi r18, 1
	and r18,r17
	brne EVEN
ODD:
	cpi r16, 9
	rjmp CONTINUE
EVEN: 
	cpi r16, 5

CONTINUE:
	breq RESET_TIME
	inc r16
	st X, r16
	rjmp BCD_RET
RESET_TIME:
	;Ifall time = 9 så reset till 0 och öka X och försök igen
	ldi r16, 0
	st X, r16
	inc r17
	rjmp NEXT_TIME
	
BCD_RET:
	pop XL
	pop XH

	pop r18
	pop r17
	pop r16
	out SREG, r16
	pop r16
	reti

MUX:
	push r16
	in r16, SREG
	push r16
	push r19

	push XH
	push XL

	push ZH
	push ZL

	lds r19, SEG ; Hämtar nuvarande hanterad SEG
	ldi XH, HIGH(TIME)
	ldi XL, LOW(TIME)
	; Hämtar tiden för rätt seg
	andi r19, 3
	add XL, r19
	ld r16, X
	
	ldi ZH, HIGH(SEGTABLE*2)
	ldi ZL, LOW(SEGTABLE*2)
	add ZL, r16

	lpm r16, Z


	out PORTB, r16
	out PORTA, r19
	inc r19
/*	cpi r19, 4
	brne MUX_RET
	ldi r19, 0*/
MUX_RET:
	sts SEG, r19

	pop ZL
	pop ZH
	pop XL
	pop XH

	pop r19
	pop r16
	out SREG, r16
	pop r16
	reti