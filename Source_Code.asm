.include "m16def.inc"

.def temp = r16
.def dots = r17
.def digit = r18
.def copy = r19
.def ones = r20
.def logic = r21
.def compare = r22
.def hrs = r23
.def min = r24
.def scd = r25

.cseg

.org $000
jmp Reset
.org $002
jmp EXT_INT0
.org $004
jmp EXT_INT1
.org $008 
jmp TIM2_OVF
.org $010  
jmp TIM1_OVF
.org $012 
jmp TIM0_OVF

Reset:
ldi temp, high(RAMEND)  ; Stack init
out sph, temp
ldi temp, low(RAMEND)
out spl, temp

ldi temp, 0xFF  ; Ports settings 
out DDRA, temp
out DDRB, temp
out DDRC, temp
out PORTC, temp

ldi temp, 0 ;ALARM SET CHECKING REGISTER - FOR BUTTON DELAYS
mov r15, temp

ldi temp, 0b11110000; ENABLING PORT FOR CONTROLLING INDICATION
out DDRD, temp

ldi temp, 0b00000001  ;No prescaler for timer 1, 2, 0 - NORMAL MODE
out TCCR1B, temp
out TCCR0, temp
out TCCR2, temp

ldi temp, 0b00000101   ; Interrupts for timer 1 and 0 are ON
out TIMSK, temp

ldi temp, 0x7F   ;  Put 32767 to timer 1 so it overfloats every sec accurately
out TCNT1H, temp
ldi temp, 0xFF
out TCNT1L, temp

ldi scd, 0  ; Loading default values for sec min hrs
ldi min, 0
ldi hrs, 0

ldi dots, 0xFF ; for PORTA

ldi logic, 0b00010000 ; For dynamic indication - control which indicator is on
out PORTD, logic

ldi temp, 0b11000000 ; External interrupts INT1 - INT0  ENABLED
out GICR, temp

ldi temp, 0b00001010 ; TYPES OF INTERRUPTS 10 - INT1 - 10 - INT0 --BOTH ON FALLING EDGE
out MCUCR, temp

rcall alrmdwnd

sei
rjmp data
rjmp Proga
;-------------------------------------------------------------------------------------------------
alrmdwnd: ; SUBPROGRAMM FOR LOADING LAST EEPROM ALARM TO X REGISTER
ldi temp, 0x00
out EEARH, temp
out EEARL, temp

sbi EECR, EERE
in XL, EEDR

rcall wait

inc temp
out EEARL, temp
sbi EECR, EERE
in XH, EEDR

rcall wait
ret

data: 
.db 0b11000000, 0b11111001, 0b10100100, 0b10110000,0b10011001, 0b10010010, 0b10000010, 0b11111000,0b10000000, 0b10010000  
ret

;-------------------------------------------------MAIN
Proga:
cpi min, 60
breq mz
cpi hrs, 24 
breq hz

sbis PIND, 0; Alarm setting part
rcall alarm

rjmp Proga

hz:;hours reset
clr hrs
rjmp Proga

mz:;minutes reset
clr min
rjmp Proga
;-WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW O P T I M I S E D 
;------------------------------------------------------------ALARM
alarm:
cli; TO DISABLE INT 0 INT 1 TEMPORARY

ldi temp, 0b00000000 ; External interrupts INT1 - INT0 - INT2  DISABLED
out GICR, temp

ldi temp, 0b01000100   ; Interrupts for timer 1 and 0 are OFF FOR TIMER 2 ARE ON
out TIMSK, temp
;out TIFR, temp

sei
rcall loop
ret

loop:
sbis PIND, 2
rcall inch
sbis PIND, 3
jmp away
sbis PIND, 0
rcall incm

rcall delay
rjmp loop

inch:
inc XL
cpi XL, 24
breq hzero
rcall delay
ret

incm:
inc XH
cpi XH, 60
breq mzero
rcall delay
ret

hzero:
clr XL
ret

mzero:
clr XH
ret

delay:
ldi digit, 0x00
mov r15, digit
ldi digit, 0xff
rcall long_delay

long_delay:
dec digit
cpi digit, 0

breq refresh
sbrc r15, 7
ret
rjmp long_delay

refresh:
mov digit, r15
inc digit
mov r15, digit
ldi digit, 0xff
ret

away:
cli
ldi temp, 0b11000000 ; External interrupts INT1 - INT0 - INT2  ENABLED
out GICR, temp

ldi temp, 0b00001010 ; TYPES OF INTERRUPTS 10 - INT1 - 10 - INT0 --BOTH ON FALLING EDGE
out MCUCR, temp

ldi temp, 0b00000101   ; Interrupts for timer 1 and 0 are ON
out TIMSK, temp
;-----------------------------EEPROM ALARM WRITING 
out EEDR, XL
ldi XL, 0x00
out EEARH, XL
ldi XL, 0x00
out EEARL, XL

sbi EECR, EEMWE
sbi EECR, EEWE

rcall wait

out EEDR, XH
ldi XH, 0x00
out EEARH, XH
ldi XH, 0x01
out EEARL, XH

sbi EECR, EEMWE
sbi EECR, EEWE

rcall wait
rcall alrmdwnd
sei
ret

wait:
sbic EECR, EEWE
rjmp wait
ret

alarmcheck:
cp min, XH
breq sndstep
ret

sndstep:
cp hrs, XL
breq dispalarm
ret

dispalarm:
ldi temp, 0xff
out PORTB, temp
ret
;---------------------------------------------------------------------------------
TIM1_OVF: 
cli
out PORTA, dots
ldi temp, 0xff
eor dots, temp
inc scd
ldi compare, 60
cp scd, compare
breq minutes

Vix: ; After register is cleared put 32767 there again to work normally
ldi temp, 0x7F
out TCNT1H, temp
ldi temp, 0xFF
out TCNT1L, temp
sei
ret

minutes:
ldi temp, 0x00
out PORTB, temp
clr scd
inc min
rcall alarmcheck
cp min, compare
breq hours
rjmp Vix

hours:
clr min
inc hrs
ldi compare, 24
cp hrs, compare
breq zeroing
rjmp Vix

zeroing:
clr hrs

;------------------------------------------------------------------------------------------
TIM0_OVF:
cli
lsl logic
cpi logic, 0b00010000
breq led1
cpi logic, 0b00100000
breq led2
cpi logic, 0b01000000
breq led3
cpi logic, 0b10000000
breq led4
cpi logic, 0b00000000
breq led1
out PORTC, temp
sei
reti

Zix:
out PORTD, logic
lpm
out PORTC, r0
sei 
ret

led1:
ldi logic, 0b00010000
mov copy, hrs
mov r29, copy
rcall split_func
ldi ZH, high(data*2)
ldi ZL, low(data*2)
add ZL, ones
rjmp Zix

led2:
mov copy, hrs
mov r29, copy
rcall split_func
ldi ZH, high(data*2)
ldi ZL, low(data*2)
add ZL, r29
rjmp Zix

led3:
mov copy, min
mov r29, copy
rcall split_func
ldi ZH, high(data*2)
ldi ZL, low(data*2)
add ZL, ones
rjmp Zix

led4:
mov copy, min
mov r29, copy
rcall split_func
ldi ZH, high(data*2)
ldi ZL, low(data*2)
add ZL, r29
rjmp Zix
;----------------------------------------DISCHARGES
split_func:
ldi ones, 0
rcall div
ret

div:
subi copy, 10
brcs result
inc ones
rjmp div

result:
ldi r28, 10
mul ones, r28
sub r29, r0
ret
;-------------------------------------------------------------------
TIM2_OVF:
cli
lsl logic
cpi logic, 0b00010000
breq aled1
cpi logic, 0b00100000
breq aled2
cpi logic, 0b01000000
breq aled3
cpi logic, 0b10000000
breq aled4
cpi logic, 0b00000000
breq aled1
out PORTC, temp
reti
sei
reti

aled1:
ldi logic, 0b00010000
mov copy, XL
mov r29, copy
rcall split_func
ldi ZH, high(data*2)
ldi ZL, low(data*2)
add ZL, ones
rjmp Zix

aled2:
mov copy, XL
mov r29, copy
rcall split_func
ldi ZH, high(data*2)
ldi ZL, low(data*2)
add ZL, r29
rjmp Zix

aled3:
mov copy, XH
mov r29, copy
rcall split_func
ldi ZH, high(data*2)
ldi ZL, low(data*2)
add ZL, ones
rjmp Zix

aled4:
mov copy, XH
mov r29, copy
rcall split_func
ldi ZH, high(data*2)
ldi ZL, low(data*2)
add ZL, r29
rjmp Zix
reti
;----------------------------------------BUTTONS
EXT_INT0:
cli 
inc hrs
ldi scd, 0
sei
reti

EXT_INT1:
cli 
inc min
ldi scd, 0
sei
reti
