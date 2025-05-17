#define __SFR_OFFSET 0x00
#include "avr/io.h"
#define LCD 0x27

; Kelompok 25

.global main


main:
  rcall I2C_init

loop:
  rcall I2C_start
  ldi r16, (LCD << 1) | 0
  rcall I2C_write
  ldi r16, 0x0
  rcall I2C_write
  rcall I2C_stop
  
  rjmp loop

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