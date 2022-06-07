;
; Assembler_GameProject.asm
; Author : Nico Schroeder
; TODO :
; Generate Lose Sound
; Punishment for error:
	; check if punishment sets number of points below zero
	; implement a solution for even AND odd error points
; generate random number between 0 and 3 -> for a game with 4 LEDs
	; just check if last bits of number are 00,01,10,11
; Timer

.equ fcpu = 16000000
.equ baud = 9600
.equ ubbr = ( fcpu /16/ baud -1) ; oder 16000000 / (16 * 9600)) - 1
.equ punishment = 3 ; muss ungerade sein

hwTable: .db "YOUR CURRENT_POINTS: ", 0

.def check_for_error = r19
.def ascii_shift = r20
.def points = r22
.def random = r23

; registers to display points in ascii
.def first_digit = r24
.def second_digit = r25

; init
sbi DDRD , 2
sbi DDRD , 3
clr points
clr random
clr check_for_error
clr first_digit
clr second_digit
ldi ascii_shift, 48

; set UBBR
ldi r17 , LOW ( ubbr )
sts UBRR0L , r17
ldi r17 , HIGH ( ubbr )
sts UBRR0H , r17
ldi r16 , (1 << RXEN0 ) | (1 << TXEN0 ) ; enable tx and rx
sts UCSR0B , r16

start: 
	rcall send_current_points
	sbrc random, 0 ; skip if bit 0 in random is cleared
	rjmp bit_is_set
	sbi PORTD ,2 ; turn LED on
	; Endlosschleife bis user input
	endlosschleife_start0:
		dec random  ; decrease random to generate new "random" number for next round
		sbic PIND, 4 ; skip next instruction if input = 0
		rjmp ready
		sbic PIND, 5 ; wrong button pressed -> buzzer 
		rcall buzzer
		rjmp endlosschleife_start0

	bit_is_set:
	; do that:
	sbi PORTD, 3 ; turn LED on
	; Endlosschleife bis user input
	endlosschleife_start1:
		dec random ; decrease random to generate new "random" number for next round
		sbic PIND, 5 ; skip next instruction if input = 0
		rjmp ready
		sbic PIND, 4 ; wrong button pressed -> buzzer 
		rcall buzzer
		rjmp endlosschleife_start1

ready:
	inc points
	sbrc check_for_error, 0
	rcall decrease_points
	cbi PIND, 4
	cbi PIND, 5
	cbi PORTD, 2
	cbi PORTD, 3
	rcall delay_1
	rjmp start

delay_1:
	push r18
	push r19
	push r20
	ldi r18, 41
	ldi r19, 150
	ldi r20, 128
	L1: 
	dec r20
	brne L1
	dec r19
	brne L1
	dec r18
	brne L1
	pop r20
	pop r19
	pop r18
	ret

delay_2:
	push r18
	push r19
	push r20
	ldi r18, 9
	ldi r19, 30
	ldi r20, 229
	L2: 
	dec r20
	brne L2
	dec r19
	brne L2
	dec r18
	brne L2
	pop r20
	pop r19
	pop r18
	ret

buzzer: 
	sbi PORTD, 6
	rcall delay_2
	cbi PORTD, 6
	sbr check_for_error, punishment ; Funktioniert bisher für jede beliebige ungerade Anzahl an Minuspunkten (Bit 0 wird gecheckt)
	ret

decrease_points:
	sub points, check_for_error
	clr check_for_error
	ret


send_current_points:
	ldi ZH , high (hwTable<<1)
	ldi ZL , low (hwTable<<1)

hwLoop:
	lpm r18 , Z+
	tst r18 ; check for zero , set Z flag
	breq endLoop ; if tmp = 0, all chars have been sent
	call transmitChar
	jmp hwLoop

endLoop:
	push points ; save current points
	rcall convert_to_ascii ; convert current points in ascii by saving each digit to a different register
	rcall wait_until_empty ; wait until USART data register is empty
	sts UDR0, first_digit ; print first digit (10er Stelle) 
	rcall wait_until_empty
	sts UDR0, second_digit ; print second digit (1er Stelle)
	pop points ; get current points from stack
	ldi r18, 13
	call transmitChar
	clr first_digit
	clr second_digit
	ret

handleCRLF:
	ldi r18 , 10

transmitChar:
	rcall wait_until_empty
	sts UDR0 , r18 ; write character to UDR0 for transmission
	cpi r18 , 13 ; in case of cr , addtional lf must be send afterwards
	breq handleCRLF
	ret

convert_to_ascii:
	; TODO: convert for three digit numbers
	cpi points, 10 ; check if number is greater than 10
	brge div_10 ; "divide" number by 10 (actually just subtract 10 until < 10 and increase counter for every subtration)
	mov second_digit, points
	add first_digit, ascii_shift ; add 48
	add second_digit, ascii_shift  ; add 48
	ret
	div_10:
		inc first_digit ; increase first digit
		subi points, 10 ; subtract 10 from points
		rjmp convert_to_ascii ; jump back and reapeat until less than 10
	
wait_until_empty:
	lds r17 , UCSR0A
	sbrs r17 , UDRE0
	rjmp wait_until_empty
	ret