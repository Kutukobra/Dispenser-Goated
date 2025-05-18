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
; Kelompok 25

.global main

main:
  rcall I2C_init
  rcall LCD_init
  ; Set pin sensor
  ldi r16, (1 << PD2)
  out DDRD, r16

loop:
  rcall read_ultrasonic 
  rcall LCD_clear
  rcall print_number_to_lcd 
  rcall delay
  rjmp loop

LCD_init:
  rcall delay

  ldi r16, 0x33
  rcall LCD_command

  ldi r16, 0x32
  rcall LCD_command

  ; Command Function Set to 4 bits, 2 line, 5x7
  ldi r16, 0x28
  rcall LCD_command  

  ; Command display on, cursor blink
  ldi r16, 0x0e
  rcall LCD_command

  rcall LCD_clear

  ; Entrymode left set
  ldi r16, 0x6
  rcall LCD_command
  ret

LCD_clear:
  ldi r16, 0x1
  rcall LCD_command
  rcall delay
  ret

LCD_home:
  ldi r16, 0x2
  rcall LCD_command
  rcall delay
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

delay:
    ldi r19, 255
.dl2:
    ldi r20, 255
.dl3:
    nop
    dec r20
    brne .dl3
    dec r19
    brne .dl2
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

; Untuk menghasilkan jarak dalam cm (di r24)
read_ultrasonic:
  sbi PORTD, PD2
  rcall short_delay
  cbi PORTD, PD2

; Tunggu sampai echo jadi high
wait_echo_high:
  sbis PIND, PD3
  rjmp wait_echo_high
  clr r24
  clr r25

measure_echo:
  sbic PIND, PD3
  rjmp still_high

  rjmp end_measure

still_high:
  adiw r24, 1
  cpi r24, 255
  brne measure_echo
  inc r25
  rjmp measure_echo

; Pakai perhitungan Polling Based
end_measure:
  ; Hitungan r24-r25 akan proporsional terhadap waktu => hitung jarak
  ; Jadi jarak (cm) = waktu / 58
  ; Biar hemat, pakai pembagian kasar: jarak = count / 58

  ; Pakai r24 untuk simplifikasi (jika <255)
  ldi r18, 58
  clr r19
  mov r20, r24
  clr r21

divloop:
  cp r20, r18
  brlo divdone
  sub r20, r18
  inc r21
  rjmp divloop

divdone:
  mov r24, r21 ; hasil jarak dalam cm
  ret

short_delay:
  ; ~10us delay
  ldi r18, 30
s_delay:
  dec r18
  brne s_delay
  ret

; Menampilkan isi ke LCD dengan desimal
; Input: r24 (angka 0-255)
; Output: Tampilkan sebagai string ke LCD
print_number_to_lcd:
  ldi r22, 100
  clr r25

digit_loop:
  cp r24, r22
  brlo next_digit
  sub r24, r22
  inc r25
  rjmp digit_loop

next_digit:
  mov r16, r25
  ldi r17, 48
  add r16, r17
  rcall LCD_data

  ; Lanjut dengan puluhan dan satuan
  ldi r22, 10
  clr r25

digit_loop2:
  cp r24, r22
  brlo next_digit2
  sub r24, r22
  inc r25
  rjmp digit_loop2

next_digit2:
  mov r16, r25
  ldi r17, 48
  add r16, r17
  add r16, r17
  rcall LCD_data

  ; Satuan
  mov r16, r24
  ldi r17, 48
  add r16, r17
  add r16, r17
  rcall LCD_data
  ret