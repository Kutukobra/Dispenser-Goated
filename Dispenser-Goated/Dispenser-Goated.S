#define __SFR_OFFSET 0x00
#include "avr/io.h"

; Muhammad Nadzhif Fikri
; 2306210102

.global main

main:
  SBI DDRB, 5   ; Set pin 13 as output (BUILTIN_LED)
  SBI PORTD, 5  ; Set pin 5 to pull up

loop:
  SBI PORTB, 5
  SBIC PIND, 5
  CBI PORTB, 5
  RJMP loop        ; Loops
  