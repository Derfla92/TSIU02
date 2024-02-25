	
	; --- lab4spel.asm

	.equ	VMEM_SZ     = 5		; #rows on display
	.equ	AD_CHAN_X   = 0		; ADC0=PA0, PORTA bit 0 X-led
	.equ	AD_CHAN_Y   = 1		; ADC1=PA1, PORTA bit 1 Y-led
	.equ	GAME_SPEED  = 70	; inter-run delay (millisecs)
	.equ	PRESCALE    = 7		; AD-prescaler value
	.equ	BEEP_PITCH  = 128	; Victory beep pitch
	.equ	BEEP_LENGTH = 100	; Victory beep length
	.equ	DELAY_TIME = 18	; Delay length

	.equ	X_CUTOFF_HIGH_H = 0x02
	.equ	X_CUTOFF_HIGH_L = 0xA0
	.equ	X_CUTOFF_LOW_H = 0x01
	.equ	X_CUTOFF_LOW_L = 0x00
	.equ	Y_CUTOFF_HIGH_H = 0x03
	.equ	Y_CUTOFF_HIGH_L = 0x64
	.equ	Y_CUTOFF_LOW_H = 0x01
	.equ	Y_CUTOFF_LOW_L = 0x00

	
	; ---------------------------------------
	; --- Memory layout in SRAM
	.dseg
	.org	SRAM_START
POSX:	.byte	1	; Own position
POSY:	.byte 	1
TPOSX:	.byte	1	; Target position
TPOSY:	.byte	1
LINE:	.byte	1	; Current line	
VMEM:	.byte	VMEM_SZ ; Video MEMory
SEED:	.byte	1	; Seed for Random

	; ---------------------------------------
	; --- Macros for inc/dec-rementing
	; --- a byte in SRAM
	.macro INCSRAM	; inc byte in SRAM
		lds	r16,@0
		inc	r16
		sts	@0,r16
	.endmacro

	.macro DECSRAM	; dec byte in SRAM
		lds	r16,@0
		dec	r16
		sts	@0,r16
	.endmacro

	; ---------------------------------------
	; --- Code
	.cseg
	.org 	$0
	jmp	START
	.org	INT0addr
	jmp	MUX


START:
	; sätt stackpekaren
	ldi r16, HIGH(RAMEND)
	out SPH, r16
	ldi r16, LOW(RAMEND)
	out SPL, r16

	call	HW_INIT	
	call	WARM
RUN:
/*	call BEEP
	rjmp RUN*/
	call	JOYSTICK
	call	ERASE_VMEM
	call	UPDATE

	; Vänta en stund så inte spelet går för fort 
	ldi r16, GAME_SPEED
RUN_DELAY:
	call DELAY
	dec r16
	brne RUN_DELAY
	
	
	; Avgör om träff
	; Kolla om X-led stämmer överens
	ldi XH, HIGH(POSX)
	ldi XL, LOW(POSX)
	ld r16, X
	adiw X, 2
	ld r17, X
	cp r16, r17
	brne NO_HIT

	; Kolla om Y-led stämmer överens (POSX + 1 = Y-axis)
	ldi XH, HIGH(POSX)
	ldi XL, LOW(POSX)
	inc XL

	ld r16, X
	adiw X, 2
	ld r17, X
	cp r16, r17

	brne	NO_HIT	
	ldi	r16,BEEP_LENGTH
	call	BEEP
	call	WARM
NO_HIT:
	jmp	RUN

	; ---------------------------------------
	; --- Multiplex display
MUX:	

	; skriv rutin som handhar multiplexningen och ***
	; utskriften till diodmatrisen. Öka SEED.		***
	push r16
	in r16, SREG
	push r16
	push XH
	push XL
	
	clr r16
	out PORTB, r16
	ldi XH, HIGH(VMEM)
	ldi XL, LOW(VMEM)
	lds r16, LINE
	; Lägg till LINE på X-pekaren för att peka ut vilka dioder som ska lysa
	add XL, r16
	;  Skriv ut Line till PORTD
	swap r16
	lsl r16
	out PORTD, r16

	ld r16, X
	; Skriv ut VMEM till PORTB
	out PORTB, r16

	; Öka line nummer
	lds r16, LINE
	inc r16
	cpi r16, VMEM_SZ
	brne STORE_LINE
	ldi r16, 0
STORE_LINE:
	sts LINE,r16

	; Öka seed
	lds r16, SEED
	inc r16
	sts SEED, r16

	pop XL
	pop XH
	pop r16
	out SREG,r16
	pop r16
	reti
		
	; ---------------------------------------
	; --- JOYSTICK Sense stick and update POSX, POSY
	; --- Uses r16
JOYSTICK:	

	; skriv kod som ökar eller minskar POSX beroende 	***
	; på insignalen från A/D-omvandlaren i X-led...	***
	; Väljer PINA0 

JOYSTICK_LOAD_X:
	ldi r16, AD_CHAN_X
	rjmp JOYSTICK_START_ADC
JOYSTICK_LOAD_Y:
	ldi r16, AD_CHAN_Y
JOYSTICK_START_ADC:
	out ADMUX, r16

	sbi ADCSRA, ADSC
JOYSTICK_WAIT:
	sbic ADCSRA, ADSC
	rjmp JOYSTICK_WAIT
	in r16, ADCL
	in r17, ADCH
	
	
	; Check if joystick has left center position on X-Axis
	; if ADMUX is 0
	sbis ADMUX, 0
	call JOYSTICK_CHECK_X

	; Check if joystick has left center position on Y-Axis
	; if ADMUX is 1
	sbic ADMUX, 0
	call JOYSTICK_CHECK_Y

	; Swap to check Y-axis if ADMUX is 0
	sbis ADMUX, 0
	rjmp JOYSTICK_LOAD_Y
	
JOY_LIM:
	call	LIMITS		; don't fall off world!
	ret

	; Check if joystick has left middle position X
	; X_CUTOFF_HIGH_H
	; X_CUTOFF_HIGH_L
	; X_CUTOFF_LOW_H
	; X_CUTOFF_LOW_L
JOYSTICK_CHECK_X:
	cpi r17, X_CUTOFF_HIGH_H
	brlo JOYSTICK_CHECK_X_LOW
	cpi r16, X_CUTOFF_HIGH_L
	brlo JOYSTICK_CHECK_X_LOW
	lds r18, POSX
	inc r18
	sts POSX, r18
	rjmp JOYSTICK_CHECK_X_RET

JOYSTICK_CHECK_X_LOW:
	cpi r17, X_CUTOFF_LOW_H
	brsh JOYSTICK_CHECK_X_RET
/*	cpi r16, X_CUTOFF_LOW_L
	brsh JOYSTICK_CHECK_X_RET*/
	lds r18, POSX
	dec r18
	sts POSX, r18
	
JOYSTICK_CHECK_X_RET:
	ret

	; Check if joystick has left middle position Y
	; Y_CUTOFF_HIGH_H
	; Y_CUTOFF_HIGH_L
	; Y_CUTOFF_LOW_H
	; Y_CUTOFF_LOW_L

JOYSTICK_CHECK_Y:
	cpi r17, Y_CUTOFF_HIGH_H
	brlo JOYSTICK_CHECK_Y_LOW
	cpi r16, Y_CUTOFF_HIGH_L
	brlo JOYSTICK_CHECK_Y_LOW
	lds r18, POSY
	inc r18
	sts POSY, r18
	rjmp JOYSTICK_CHECK_Y_RET

JOYSTICK_CHECK_Y_LOW:
	cpi r17, Y_CUTOFF_LOW_H
	brsh JOYSTICK_CHECK_Y_RET
/*	cpi r16, X_CUTOFF_LOW_L
	brsh JOYSTICK_CHECK_X_RET*/
	lds r18, POSY
	dec r18
	sts POSY, r18
	
JOYSTICK_CHECK_Y_RET:
	ret



	; ---------------------------------------
	; --- LIMITS Limit POSX,POSY coordinates	
	; --- Uses r16,r17
LIMITS:
	lds	r16,POSX	; variable
	ldi	r17,7		; upper limit+1
	call	POS_LIM		; actual work
	sts	POSX,r16
	lds	r16,POSY	; variable
	ldi	r17,5		; upper limit+1
	call	POS_LIM		; actual work
	sts	POSY,r16
	ret

POS_LIM:
	ori	r16,0		; negative?
	brmi	POS_LESS	; POSX neg => add 1
	cp	r16,r17		; past edge
	brne	POS_OK
	subi	r16,2
POS_LESS:
	inc	r16	
POS_OK:
	ret

	; ---------------------------------------
	; --- UPDATE VMEM
	; --- with POSX/Y, TPOSX/Y
	; --- Uses r16, r17
UPDATE:	
	clr	ZH 
	ldi	ZL,LOW(POSX)
	call 	SETPOS
	clr	ZH
	ldi	ZL,LOW(TPOSX)
	call	SETPOS
	ret

	; --- SETPOS Set bit pattern of r16 into *Z
	; --- Uses r16, r17
	; --- 1st call Z points to POSX at entry and POSY at exit
	; --- 2nd call Z points to TPOSX at entry and TPOSY at exit
SETPOS:
	ld	r17,Z+  	; r17=POSX
	call	SETBIT		; r16=bitpattern for VMEM+POSY
	ld	r17,Z		; r17=POSY Z to POSY
	ldi	ZL,LOW(VMEM)
	add	ZL,r17		; *(VMEM+T/POSY) ZL=VMEM+0..4
	ld	r17,Z		; current line in VMEM
	or	r17,r16		; OR on place
	st	Z,r17		; put back into VMEM
	ret
	
	; --- SETBIT Set bit r17 on r16
	; --- Uses r16, r17
SETBIT:
	ldi	r16,$01		; bit to shift
SETBIT_LOOP:
	dec 	r17			
	brmi 	SETBIT_END	; til done
	lsl 	r16		; shift
	jmp 	SETBIT_LOOP
SETBIT_END:
	ret

	; ---------------------------------------
	; --- Hardware init
	; --- Uses r16
HW_INIT:

	; 	Konfigurera hårdvara och MUX-avbrott enligt ***
	;	ditt elektriska schema. Konfigurera 		***
	;	flanktriggat avbrott på INT0 (PD2).			***

	ldi r16, $FF
	out DDRB, r16
	ldi r16, $F0 
	out DDRD, r16

	ldi r16, (0 << ADPS2) | (1 << ADPS1) | (1 << ADPS0) | (1 << ADEN)
	out ADCSRA, r16

	ldi r16, (1 << ISC01) | (1 << ISC00)
	out MCUCR, r16

	ldi r16, (1 << INT0)
	out GICR, r16

	sei			; display on
	
	ret

	; ---------------------------------------
	; --- WARM start. Set up a new game
WARM:

	; Sätt startposition (POSX,POSY)=(0,2)		***
	
	ldi r16, 0
	sts POSX, r16
	ldi r16, 2
	sts POSY, r16

	push	r0		
	push	r0		
	call	RANDOM		; RANDOM returns x,y on stack

	; Sätt startposition (TPOSX,TPOSY)				***
	pop r16
	sts TPOSX, r16
	pop r16
	sts TPOSY, r16
	call	ERASE_VMEM
	ret

	; ---------------------------------------
	; --- RANDOM generate TPOSX, TPOSY
	; --- in variables passed on stack.
	; --- Usage as:
	; ---	push r0 
	; ---	push r0 
	; ---	call RANDOM
	; ---	pop TPOSX 
	; ---	pop TPOSY
	; --- Uses r16
RANDOM:
	in	r16,SPH
	mov	ZH,r16
	in	r16,SPL
	mov	ZL,r16
	lds	r16,SEED
	
	; Använd SEED för att beräkna TPOSX		***
	andi r16, $07
	; Kolla om r16 är större än eller lika med 2
	; Om inte, så lägg på 2
	; Detta betyder reellt sett att 2 och 3 har dubbelt
	; så stor chans att inträffa än de andra talen.
	cpi r16, 2
	brsh BIG_ENOUGH_X
	inc r16
	inc r16

BIG_ENOUGH_X:
	; Kolla om r16 är mindre än 7
	; Om inte, ta bort 4
	; Detta betyder reellt sett att 3 har
	; dubbelt så stor chans att inträffa än de andra talen.
	cpi r16, 7
	brlo SMALL_ENOUGH_X
	subi r16, 4
SMALL_ENOUGH_X:
	; store TPOSX	2..6
	std Z+3, r16
	
	lds	r16,SEED
	; Använd SEED för att beräkna TPOSY		***
	andi r16, $07
	cpi r16, 5
	brlo SMALL_ENOUGH_Y
	subi r16, 4
SMALL_ENOUGH_Y:
	; store TPOSY   0..4
	std Z+4, r16
	ret


	; ---------------------------------------
	; --- Erase Videomemory bytes
	; --- Clears VMEM..VMEM+4
	
ERASE_VMEM:

	; Radera videominnet						***
	ldi XH, HIGH(VMEM)
	ldi XL, LOW(VMEM)
	ldi r17, VMEM_SZ
	add r17, XL
	ldi r16, $00
ERASE_VMEM_LOOP:
	st X+, r16

	cp XL, r17
	brne ERASE_VMEM_LOOP
	ret

	; ---------------------------------------
	; --- BEEP(r16) r16 half cycles of BEEP-PITCH
BEEP:	

	; skriv kod för ett ljud som ska markera träff 	***
	ldi r16, BEEP_LENGTH
BEEP_OUTER_LOOP:
	sbi PORTD, 4
	
	ldi r17, BEEP_PITCH
BEEP_INNER_LOOP1:
	dec r17
	brne BEEP_INNER_LOOP1
	

	cbi PORTD, 4

	ldi r17, BEEP_PITCH
BEEP_INNER_LOOP2:
	dec r17
	brne BEEP_INNER_LOOP2
	
	dec r16
	brne beep_outer_loop

	ret



DELAY:
	push r16
	push r17
	ldi r16, DELAY_TIME
DELAY_OUTER:
	ldi r17, DELAY_TIME
DELAY_INNER:
	dec r17
	brne DELAY_INNER
	dec r16
	brne DELAY_OUTER
	pop r17
	pop r16
	ret

			