#define __SFR_OFFSET 0x00
#include "avr/io.h"

#define LCD_ADDR 0x27
#define D7 128
#define D6 64
#define D5 32
#define D4 16
#define BL 8
#define E  4
#define RW 2
#define RS 1

#define TG_PIN 1
#define EC_PIN 0

#define PUMP_PIN 2 

#define UTS_VAL r10
#define ADC_VAL r11
; Kelompok 25

.global main

main:
  sbi DDRB, TG_PIN ; Trigger Output
  cbi DDRB, EC_PIN ; Echo input

  sbi DDRD, PUMP_PIN

  rcall I2C_init
  rcall LCD_init
  rcall ADC_init
  rcall SER_init

loop:
  rcall LCD_home
  
  rcall UTS_read
  mov UTS_VAL, r16
  rcall SER_hexout

  rcall ADC_read
  mov ADC_VAL, r16
  rcall SER_hexout

  cp ADC_VAL, UTS_VAL
  brge stop

  fill:
    sbi PORTD, PUMP_PIN  
    ldi r30, lo8(fill_message)
    ldi r31, hi8(fill_message)
    rcall LCD_print
    ldi r16, 0xC6
    rcall LCD_command
    mov r16, ADC_VAL
    rcall LCD_hexout
    rjmp loop
  stop:
    cbi PORTD, PUMP_PIN  
    ldi r30, lo8(set_message)
    ldi r31, hi8(set_message)
    rcall LCD_print
    ldi r16, 0xC6
    rcall LCD_command
    mov r16, ADC_VAL
    rcall LCD_hexout

  rjmp loop

SER_init:
    CLR   R24
    STS   UCSR0A, R24     ; clear UCSR0A register
    STS   UBRR0H, R24     ; clear UBRR0H register
    LDI   R24, 103        ; & store in UBRR0L 103
    STS   UBRR0L, R24     ; to set baud rate 9600
    LDI   R24, 1<<RXEN0 | 1<<TXEN0
    STS   UCSR0B, R24     ; enable RXB & TXB
    LDI   R24, 1<<UCSZ00 | 1<<UCSZ01
    STS   UCSR0C, R24     ; asynch, no parity, 1 stop, 8 bits
    RET  

SER_hexout:
  push r16
  andi r16, 0xf0
  swap r16
  rcall hex_adjust
  sts UDR0, r16
  pop r16
  andi r16, 0x0f
  rcall hex_adjust
  sts UDR0, r16
  ldi r16, ' '
  l1:
  LDS   R17, UCSR0A
    SBRS  R17, UDRE0                ;test data buffer if data can be sent
    RJMP  l1
  sts UDR0, r16
  ret

LCD_init:
  rcall delay

  ldi r16, 0x33
  rcall LCD_command

  ldi r16, 0x32
  rcall LCD_command

  ; Command Function Set to 4 bits, 2 line, 5x7
  ldi r16, 0x28
  rcall LCD_command  

  ; Command display on, cursor off
  ldi r16, 0x0c
  rcall LCD_command

  rcall LCD_clear

  ; Entrymode left set
  ldi r16, 0x6
  rcall LCD_command
  ret

LCD_clear:
  ldi r16, 0x1
  rcall LCD_command
  ret

LCD_home:
  ldi r16, 0x2
  rcall LCD_command
  ret

; Prints Mem(Z) to LCD until null termination
LCD_print:
  lpm r16, Z+
  cpi r16, 0
  breq print_exit

  rcall LCD_data
  
  rjmp LCD_print
print_exit:
  ret

; Outputs hex r16 to LCD
LCD_hexout:
  push r16
  andi r16, 0xf0
  swap r16
  rcall hex_adjust
  rcall LCD_data
  pop r16
  andi r16, 0x0f
  rcall hex_adjust
  rcall LCD_data
  ret

hex_adjust:
  cpi r16, 10
  brlt hex_adjust_exit
  subi r16, -7
  hex_adjust_exit:
  subi r16, -48
  ret

; Sends 8 bit command from r16
LCD_command:
  push r16
  andi r16, 0xf0
  rcall LCD_write4bits
  pop r16
  swap r16
  andi r16, 0xf0
  rcall LCD_write4bits
  ret

LCD_data:
  push r16
  andi r16, 0xf0
  ori r16, 0x01
  rcall LCD_write4bits
  pop r16
  swap r16
  andi r16, 0xf0
  ori r16, 0x01
  rcall LCD_write4bits
  ret

; Sends r16 high nibble
LCD_write4bits:
  rcall LCD_expanderWrite
  rcall LCD_pulseEnable
  ret

; Sends r16 to LCD via I2C
LCD_expanderWrite:
  push r16
  mov r17, r16
  rcall I2C_start
  ldi r16, (LCD_ADDR << 1) | 0
  rcall I2C_write
  mov r16, r17
  ori r16, BL
  rcall I2C_write
  rcall I2C_stop
  pop r16
  ret

; Pulse EN and r16 high nibble
LCD_pulseEnable:  
  push r16
  ori r16, 0x4 ; Set E
  rcall LCD_expanderWrite
  rcall delay
  andi r16, 0xfb ; Clr E
  rcall LCD_expanderWrite
  rcall delay
  pop r16
  ret


I2C_init:
  ; Prescaler = 1
  clr r16
  sts TWSR, r16
  ; Bitrate = 100KHZ, TWBR = 72
  ldi r16, 72
  sts TWBR, r16
  ; Enable
  ldi r16, (1 << TWEN)
  sts TWCR, r16
  ret

I2C_start:
  ; Clear int flag, start, enable 
  ldi r16, (1 << TWINT) | (1 << TWSTA) | (1 << TWEN)
  sts TWCR, r16
  rcall I2C_wait
  ret

I2C_stop:
  ; Clear int flag, stop, enable
  ldi r16, (1 << TWINT) | (1 << TWSTO) | (1 << TWEN)
  sts TWCR, r16
  ret

; Write r16 to I2C
I2C_write:
  sts TWDR, r16
  ; Clear TWINT, Enable
  ldi r16, (1 << TWINT) | (1 << TWEN)
  sts TWCR, r16
  rcall I2C_wait
  ret

I2C_wait:
  lds r16, TWCR
  sbrs r16, TWINT
  rjmp I2C_wait
  ret

ADC_init:
  ldi r20, 0x20 ; Aref, Left, A0
  sts ADMUX, r20
  ldi r20, 0x87 ; ADEN, ADSC, CLK/64
  sts ADCSRA, r20
  ret

; Returns ADC A0 to R21:R20 
ADC_read:
  ldi r20, 0xC7
  sts ADCSRA, r20
  ADC_read_wait:
    lds r21, ADCSRA
    sbrs r21, 4
    rjmp ADC_read_wait
  ldi r21, 0xD7
  sts ADCSRA, r21
  lds r16, ADCH
  lsr r16
  lsr r16
  ret

; Reads time for trig and echo to r16
UTS_read:
  sbi PORTB, TG_PIN
  rcall delay_T0
  cbi PORTB, TG_PIN ; Trigger trigger pin
  clr r20
  sts TCCR1A, r20
  ldi r20, 0b11000101 ; Rising edge, CLK/1024, noise cancellation
  sts TCCR1B, r20
  UTS_echo_high_wait:
    in r21, TIFR1
    sbrs r21, ICF1
    rjmp UTS_echo_high_wait 
  lds r17, ICR1L  ; Capture begin time
  out TIFR1, r21
  ldi r20, 0b10000101 ; Falling edge
  sts TCCR1B, r20
  UTS_echo_low_wait:
    in r21, TIFR1
    sbrs r21, ICF1
    rjmp UTS_echo_low_wait
  lds r16, ICR1L  ; Capture end time
  out TIFR1, r21  ; Refresh  
  sub r16, r17
  ret

; Timer delay
delay_T0:
  clr r20
  out TCNT0, r20
  ldi r20, 20
  out OCR0A, r20
  ldi r20, 0b00001010 ; CTC, CLK/8
  out TCCR0B, r20
  delay_T0_loop:
    in r20, TIFR0
    sbrs r20, OCF0A ; Tunggu interrupt
    rjmp delay_T0_loop
  clr r20
  out TCCR0B, R20 ; Timer0 stop
  ldi r20, (1 << OCF0A) ; Clear interrupt
  out TIFR0, r20
  ret

; Loop delay
delay:
    ldi r19, 50
  .dl2:
      ldi r20, 255
    .dl3:
        nop
        dec r20
        brne .dl3
        dec r19
        brne .dl2
        ret

fill_message:
  .ascii "-== FILLING! ==-" 
  .byte 0

set_message:
  .ascii "-= Target Set =-" 
  .byte 0