;
; Lab2_Morse.asm
;
; Created: 2023-12-02 15:55:38
; Author : alfre
;

; Konstant som bestämmer längden på en tidsenhet.
.equ DELAY_TIME = 28

; Laddar stacken
ldi r16, HIGH(RAMEND)
out SPH, r16
ldi r16, LOW(RAMEND)
out SPL, r16

; Ser till att hoppa över MESSAGE och BTAB 
; för att de inte ska tolkas som instruktioner.
jmp HW_INIT


; Sträng som ska skickas och tabell för uppslag av motsvarande
; morsesekvens för varje bokstav.
MESSAGE: .db "SSAE SSAE ", $00
;MESSAGE: .db "DATORTEKNIK", $00
;MESSAGE: .db "ALF SP", $00
BTAB: .db $60, $88, $A8, $90, $40, $28, $D0, $08, $20, $78, $B0, $48, $E0, $A0, $F0, $68, $D8, $50, $10, $C0, $30, $18, $70, $98, $B8, $C8




; Initiera portar in och ut.
HW_INIT: 
	ldi r16, $01
	out DDRB, r16

; Låter programmet naturligt trilla igenom till MAIN
MAIN:
	call TRANSMIT_MESSAGE
	rjmp MAIN

; Själva huvud funktionen som tar hand om att peka
; ut ny bokstav och sedan kallar på SEND_CHAR
; för att skicka till högtalaren.
TRANSMIT_MESSAGE:
	ldi ZH,HIGH(MESSAGE*2)
	ldi ZL,LOW(MESSAGE*2)
TRANSMIT_MESSAGE2:
	lpm r16, Z+

	; Kollar så att vi inte nått NULL tecknet i strängen,
	; isåfall så hoppar vi till return.
	cpi r16, 0
	breq TRANSMIT_RET

	; Kollar ifall den funna bokstaven är ett "space".
	cpi r16, $20
	breq SPACE

	; Skickar den funna bokstaven till högtalaren
	call SEND_CHAR

	call PAUSE
	call PAUSE


	rjmp TRANSMIT_MESSAGE2
TRANSMIT_RET:
	ret

; Kallar på LOOKUP som hämtar Morsesekvensen från tabellen.
; Sedan skickar den ut bokstaven till högtalaren genom att använda
; Left-shift och carry.
SEND_CHAR:
	call LOOKUP ; Hämta morsesekvens från tabell och lägg i r16
NEXT_BIT:
	
	; Left-shiftar för att knuffa MSB till carry
	lsl r16
	; Ifall r16 = 0 så är vi klara med alla bitar
	breq SEND_CHAR_RET

	; och branchar sedan beroende på om carry är satt
	; hög eller låg.
	
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


; Label för ett "space".
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

; Subrutin för att hitta den motsvarande morsesekvensen till bokstaven.
LOOKUP:
	; Subtraherar 40 från det funna tecknet och 
	; använder r16 som indexering i tabellen.
	subi r16,'@'

	; Pushar Z pekaren som användes för att peka ut bokstaven 
	; för att kunna återanvända för att peka ut morsesekvensen.
	push ZH		
	push ZL


	ldi ZH,HIGH(BTAB*2)
	ldi ZL,LOW(BTAB*2)
	add ZL, r16
	dec ZL
	lpm r16, Z

	; Poppar tillbaka Z pekaren för att senare kunna fortsätta 
	; stega igenom strängen från där vi var.
	pop ZL
	pop ZH
	ret


; Enkel delay från LAB1
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