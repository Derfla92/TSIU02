;
; Lab2_Morse.asm
;
; Created: 2023-12-02 15:55:38
; Author : alfre
;

; Konstant som best�mmer l�ngden p� en tidsenhet.
.equ DELAY_TIME = 28

; Laddar stacken
ldi r16, HIGH(RAMEND)
out SPH, r16
ldi r16, LOW(RAMEND)
out SPL, r16

; Ser till att hoppa �ver MESSAGE och BTAB 
; f�r att de inte ska tolkas som instruktioner.
jmp HW_INIT


; Str�ng som ska skickas och tabell f�r uppslag av motsvarande
; morsesekvens f�r varje bokstav.
MESSAGE: .db "SSAE SSAE ", $00
;MESSAGE: .db "DATORTEKNIK", $00
;MESSAGE: .db "ALF SP", $00
BTAB: .db $60, $88, $A8, $90, $40, $28, $D0, $08, $20, $78, $B0, $48, $E0, $A0, $F0, $68, $D8, $50, $10, $C0, $30, $18, $70, $98, $B8, $C8




; Initiera portar in och ut.
HW_INIT: 
	ldi r16, $01
	out DDRB, r16

; L�ter programmet naturligt trilla igenom till MAIN
MAIN:
	call TRANSMIT_MESSAGE
	rjmp MAIN

; Sj�lva huvud funktionen som tar hand om att peka
; ut ny bokstav och sedan kallar p� SEND_CHAR
; f�r att skicka till h�gtalaren.
TRANSMIT_MESSAGE:
	ldi ZH,HIGH(MESSAGE*2)
	ldi ZL,LOW(MESSAGE*2)
TRANSMIT_MESSAGE2:
	lpm r16, Z+

	; Kollar s� att vi inte n�tt NULL tecknet i str�ngen,
	; is�fall s� hoppar vi till return.
	cpi r16, 0
	breq TRANSMIT_RET

	; Kollar ifall den funna bokstaven �r ett "space".
	cpi r16, $20
	breq SPACE

	; Skickar den funna bokstaven till h�gtalaren
	call SEND_CHAR

	call PAUSE
	call PAUSE


	rjmp TRANSMIT_MESSAGE2
TRANSMIT_RET:
	ret

; Kallar p� LOOKUP som h�mtar Morsesekvensen fr�n tabellen.
; Sedan skickar den ut bokstaven till h�gtalaren genom att anv�nda
; Left-shift och carry.
SEND_CHAR:
	call LOOKUP ; H�mta morsesekvens fr�n tabell och l�gg i r16
NEXT_BIT:
	
	; Left-shiftar f�r att knuffa MSB till carry
	lsl r16
	; Ifall r16 = 0 s� �r vi klara med alla bitar
	breq SEND_CHAR_RET

	; och branchar sedan beroende p� om carry �r satt
	; h�g eller l�g.
	
	brcs DASH
	ldi r17, 10
	rjmp BEEP_LOOP
DASH:
	ldi r17, 30
BEEP_LOOP:
	call WAVE
	dec r17
	brne BEEP_LOOP
	call PAUSE
	rjmp NEXT_BIT

SEND_CHAR_RET:
	ret

WAVE:
	sbi PORTB, 0
	call DELAY
	cbi PORTB, 0
	call DELAY
	ret


; Label f�r ett "space".
SPACE:
	call PAUSE
	call PAUSE
	call PAUSE
	call PAUSE
	rjmp TRANSMIT_MESSAGE2

PAUSE:
	ldi r17, DELAY_TIME
PAUSE_LOOP:
	call DELAY
	dec r17
	brne PAUSE_LOOP
	ret

; Subrutin f�r att hitta den motsvarande morsesekvensen till bokstaven.
LOOKUP:
	; Subtraherar 40 fr�n det funna tecknet och 
	; anv�nder r16 som indexering i tabellen.
	subi r16,'@'

	; Pushar Z pekaren som anv�ndes f�r att peka ut bokstaven 
	; f�r att kunna �teranv�nda f�r att peka ut morsesekvensen.
	push ZH		
	push ZL


	ldi ZH,HIGH(BTAB*2)
	ldi ZL,LOW(BTAB*2)
	add ZL, r16
	dec ZL
	lpm r16, Z

	; Poppar tillbaka Z pekaren f�r att senare kunna forts�tta 
	; stega igenom str�ngen fr�n d�r vi var.
	pop ZL
	pop ZH
	ret


; Enkel delay fr�n LAB1
DELAY:
	push r18
	push r17
	ldi r18,DELAY_TIME ; Decimal bas
DELAY_YTTRE_LOOP:
	ldi r17,DELAY_TIME
DELAY_INRE_LOOP:
	dec r17
	brne DELAY_INRE_LOOP
	dec r18
	brne DELAY_YTTRE_LOOP
	pop r17
	pop r18
	ret