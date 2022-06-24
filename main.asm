;
; Game Project in Assembler
; Authors: Franziska Heil, Marie Benzing, Nico Schroeder
;
; Description:
;	This is a reaction game. 
;	The player has to press the correct button to the corresponding LED.
;	The player will hear an error sound if the player presses the wrong button.
;	The player can check his current score on the console.
;	The game will end if the player makes to many mistakes. 
;	The player can set the following game properties:
;		max_errors	  -> maximum amount of errors
;		points_to_win -> max points to reach to win (1 - 127) 
;
; Game Setup:
;	LED1 in D2
;	LED2 in D3
;	BUTTON for LED1 in D4
;	BUTTON for LED2 in D5

.equ max_errors = 3
.equ points_to_win = 20

.equ fcpu = 16000000
.equ baud = 9600
.equ ubbr = (fcpu/16/baud-1)

.def ascii_shift = r19 ; register for ascii shift (+ 48)
.def points = r20
.def random = r21

; registers to display points in ascii
.def first_digit = r22
.def second_digit = r23
.def third_digit = r24

.def error_counter = r13
.def error_sound_counter = r25

init:
hwTable1: .db "YOUR CURRENT_POINTS: ", 0
sbi DDRD , 2
sbi DDRD , 3
sbi DDRD , 6 ; buzzer output
clr points
clr random
clr first_digit
clr second_digit
clr third_digit
clr error_sound_counter
clr error_counter
clr r16
clr r17
clr r18
ldi ascii_shift, 48
cbi PIND, 4
cbi PIND, 5
cbi PORTD, 2
cbi PORTD, 3


; set UBBR
ldi r17 , LOW ( ubbr )
sts UBRR0L , r17
ldi r17 , HIGH ( ubbr )
sts UBRR0H , r17
ldi r16 , (1 << RXEN0 ) | (1 << TXEN0 ) ; enable tx and rx
sts UCSR0B , r16

start: 
	; print current points on console
	ldi ZH , high (hwTable1<<1)
	ldi ZL , low (hwTable1<<1)
	rcall send_string
	g_l:
	sbrc random, 0 ; skip if bit 0 in random is cleared
	rjmp bit_is_set
	bit_is_not_set:
	sbi PORTD, 2 ; turn LED on
	; loop until user input
	ldi r22, 200
	ldi r23, 200
	ldi r24, 25
	endlosschleife_start0:
		dec random  ; decrease random to generate new "random" number for next round
		sbic PIND, 4 ; skip next instruction if input = 0 on PIND 4
		rjmp ready ; correct button was pressed
		sbic PIND, 5 ; skip next instruction if input = 0 on PIND 5 
		rcall buzzer ; wrong button was pressed -> call buzzer
		dec r22
		brne endlosschleife_start0
		dec r23
		brne endlosschleife_start0
		dec r24
		brne endlosschleife_start0
		cbi PORTD, 2
		rjmp bit_is_set ; no button pressed -> continue

	bit_is_set:
	sbi PORTD, 3 ; turn LED on
	; loop until user input
	ldi r22, 200
	ldi r23, 200
	ldi r24, 25
	endlosschleife_start1:
		dec random ; decrease random to generate new "random" number for next round
		sbic PIND, 5 ; skip next instruction if input = 0 on PIND 5
		rjmp ready ; correct button was pressed
		sbic PIND, 4 ; skip next instruction if input = 0 on PIND 4
		rcall buzzer ; wrong button was pressed -> call buzzer
		dec r22
		brne endlosschleife_start1
		dec r23
		brne endlosschleife_start1
		dec r24
		brne endlosschleife_start1
		cbi PORTD, 3
		rjmp bit_is_not_set

ready:
	inc points ; increase points by 1
	push r19 ; save register r19
	ldi r19, points_to_win
	cp points, r19 ; check if current points are equal to points_to_win
	breq player_wins ; if current points == points_to_win branch player_wins
	pop r19 ; get register r19
	cbi PIND, 4
	cbi PIND, 5
	cbi PORTD, 2
	cbi PORTD, 3
	rcall delay_1
	rjmp start ; start game loop again

game_over:
	; print "YOU LOST.. " on console
	hwTable2: .db "YOU LOST.. ", 0
	ldi ZH , high (hwTable2<<1)
	ldi ZL , low (hwTable2<<1)
	rcall send_string 
	; turn both LEDs off for ca. 2 seconds then start game again
	cbi PORTD, 2
	cbi PORTD, 3
	rcall delay_3
	rcall delay_3
	rjmp init

player_wins:
	; print "YOU WON... " on console
	hwTable3: .db "YOU WON... ", 0
	ldi ZH , high (hwTable3<<1)
	ldi ZL , low (hwTable3<<1)
	rcall prevent_pts_print ; prevent printing the points on console
	rcall send_string
	; turn both LEDs on for ca. 2 seconds then turn off and start game again
	sbi PORTD, 2
	sbi PORTD, 3
	rcall delay_3
	rcall delay_3
	cbi PORTD, 2
	cbi PORTD, 3
	rcall delay_3
	rjmp init

	prevent_pts_print: 
	; this prevents the points of being printed on the console
	; by increasing error_counter register until it equals max_errors.
	; whenever the print function gets called it checks whether 
	; error_counter is equal to max_errors. 
	; If that's the case the points don't get printed
	; because that means it's either "game over" or the user won.
		loop:			
			inc error_counter
			mov r19, error_counter 
			cpi r19, max_errors
			brlt loop
		ldi r19, max_errors
		ret


buzzer: ; zählt wie oft der ton erklingt
	ldi r19, 4 
	cpse error_sound_counter, r19 ; compare error_sound_counter with r19 (max: 4)
	rjmp sound_on
	ldi error_sound_counter, 0 ; setzt counter für nächsten Fehler zurück
	inc error_counter
	ldi r19, max_errors
	cp error_counter, r19
	breq game_over 
	ldi r19, 48 ; load 48 in r19 (ascii_shift)
	ret

sound_on : ; speichert 1 sec in register
    ldi  r27, 41
    ldi  r28, 150
    ldi  r29, 128
	rjmp B1

B1: ; zählt 1 sec runter & schaltet Ton an
	dec  r29					
    brne B1
    dec  r28
    brne B1
    dec  r27
    brne B1
	sbi PORTD , 6 ; schaltet Ton an  
	inc error_sound_counter ; erhöht counter
	rjmp sound_off

sound_off : ; speichert 1 sec in register
    ldi  r27, 41
    ldi  r28, 150
    ldi  r29, 128
	rjmp B2

B2: ; zählt 1 sec runter & schaltet Ton aus
	dec  r29
    brne B2
    dec  r28
    brne B2
    dec  r27
    brne B2
	cbi PORTD , 6 ; schaltet Ton aus
	rjmp buzzer


; send something to the console
send_string:
clr first_digit
clr second_digit
clr third_digit

hwLoop:
	lpm r18 , Z+
	tst r18 ; check for zero , set Z flag
	breq endLoop ; if tmp = 0, all chars have been sent
	call transmitChar
	jmp hwLoop

endLoop:
	cp error_counter, r19
	breq game_ends ; don't print points

	push points ; save current points
	rcall convert_to_ascii ; convert current points in ascii by saving each digit to a different register
	rcall wait_until_empty ; wait until USART data register is empty
	sts UDR0, first_digit ; print first digit (100er Stelle) 
	rcall wait_until_empty
	sts UDR0, second_digit ; print second digit (10er Stelle)
	rcall wait_until_empty
	sts UDR0, third_digit ; print second digit (1er Stelle)
	pop points ; get current points from stack
	
	game_ends:
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
	cpi points, 100 ; check if number is greater than 100
	brge div_100 ; "divide" number by 100 (actually just subtract 10 until < 100 and increase counter for every subtration)
	cpi points, 10 ; check if number is greater than 10
	brge div_10 ; "divide" number by 10 (actually just subtract 10 until < 10 and increase counter for every subtration)
	mov third_digit, points
	add first_digit, ascii_shift ; add 48
	add second_digit, ascii_shift  ; add 48
	add third_digit, ascii_shift  ; add 48
	ret
	div_100:
		inc first_digit ; increase first digit
		subi points, 100 ; subtract 10 from points
		rjmp convert_to_ascii ; jump back and repeat until less than 100
	div_10:
		inc second_digit ; increase first digit
		subi points, 10 ; subtract 10 from points
		rjmp convert_to_ascii ; jump back and repeat until less than 10
	
wait_until_empty:
	lds r17 , UCSR0A
	sbrs r17 , UDRE0
	rjmp wait_until_empty
	ret

delay_1:
	push r18
	push r19
	push r20
	ldi r18, 21
	ldi r19, 75
	ldi r20, 191
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

delay_3:
	push r18
	push r19
	push r20
	ldi r18, 82
	ldi r19, 43
	ldi r20, 0
	L3: 
	dec r20
	brne L3
	dec r19
	brne L3
	dec r18
	brne L3
	pop r20
	pop r19
	pop r18
	ret