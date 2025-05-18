#define __SFR_OFFSET 0x00
#include "avr/io.h"

; Pin definitions
.equ TRIGGER, PD2
.equ ECHO, PD3
.equ LED, PB1

.global main

;------------------------
; Main Program
;------------------------
main:
    RCALL USART_Init
    RCALL HC_SR04_init
    
    ; Test message
    LDI ZL, lo8(message)
    LDI ZH, hi8(message)
    RCALL print_string
    
main_loop:
    RCALL HC_SR04_measure
    RCALL print_distance
    RCALL delay_200us
    RJMP main_loop

message: .asciz "Ultrasonic Sensor Ready\r\n"

print_string:
    LPM R16, Z+
    CPI R16, 0
    BREQ print_done
    RCALL USART_Transmit
    RJMP print_string
print_done:
    RET

;------------------------
; Initialize Ultrasonic Sensor
;------------------------
HC_SR04_init:
    SBI DDRD, TRIGGER     ; Set trigger pin as output
    CBI DDRD, ECHO        ; Set echo pin as input
    SBI PORTD, ECHO 
    LDI R16, 0
    STS TCCR1A, R16       ; Normal mode
    STS TCCR1B, R16       ; Stop timer
    STS TCCR1C, R16
    RET

;------------------------
; Measure Distance with HC-SR04
;------------------------
HC_SR04_measure:
    SBI PORTB, LED ; Saat menghitung LED nyala

    LDI R16, 0
    STS TCNT1H, R16      ; Clear timer
    STS TCNT1L, R16

    ; Send 10us trigger pulse
    SBI PORTD, TRIGGER
    RCALL delay_10us
    CBI PORTD, TRIGGER

    LDI R19, 150
    
  ; Wait for echo to go high

  wait_echo_high:
      SBIS PIND, ECHO
      RJMP check_high_timeout
      RJMP echo_high_detected

  check_high_timeout:
    RCALL delay_200us   ; Butuh delay lebih presisi
    DEC R19
    BRNE wait_echo_high
    RJMP measurement_failed

   echo_high_detected:
    LDI R16, (1<<ICES1)|(1<<CS11)|(1<<ICNC1) ; Rising edge, prescaler=8
    STS TCCR1B, R16

    LDI R19, 150

    wait_echo_low_ext:
    LDI R20, 255

    wait_echo_low:
        SBIC PIND, ECHO
        RJMP check_timeout_low
        RJMP echo_low_detected

    check_timeout_low:
      RCALL delay_200us
      DEC R19
      BRNE wait_echo_low
      RJMP measurement_failed
    
    echo_low_detected: 
      LDS R24, ICR1L
      LDS R25, ICR1H
      CBI PORTB, LED ; Debug: LED OFF saat selesai
    
    ; Calculate distance in cm (time/58)
    ; Approximation: time/58 ≈ time*9/512 ≈ (time*9)>>9
    MOVW R30, R24         ; Copy time to R31:R30
    LSL R30               ; Multiply by 2
    ROL R31
    MOVW R22, R30         ; Save time*2 in R23:R22
    LSL R30               ; Multiply by 4 (total)
    ROL R31
    LSL R30               ; Multiply by 8 (total)
    ROL R31
    ADD R30, R22          ; Add time*2 to get time*10
    ADC R31, R23
    SBIW R30, 1           ; time*10 - 1 (for better rounding)
    
    ; Now divide by 58 (approximated as multiply by 9 then divide by 512)
    LSR R31               ; Divide by 2 (start of divide by 512)
    ROR R30
    LSR R31
    ROR R30
    LSR R31
    ROR R30
    LSR R31
    ROR R30
    LSR R31
    ROR R30
    LSR R31
    ROR R30
    LSR R31
    ROR R30
    LSR R31
    ROR R30
    
    ; R30 now contains distance in cm
    RET
  
  measurement_failed:
    LDI R24, 0       ; Return 0 sebagai error
    LDI R25, 0
    RET
;------------------------
; USART Initialization (9600 baud at 16MHz)
;------------------------
USART_Init:
    ; Set baud rate (9600 with 16MHz clock)
    LDI R16, 103
    STS UBRR0L, R16
    LDI R16, 0
    STS UBRR0H, R16
    
    ; Enable transmitter
    LDI R16, (1<<TXEN0)
    STS UCSR0B, R16
    
    ; Set frame format: 8 data bits, 1 stop bit, no parity
    LDI R16, (1<<UCSZ01)|(1<<UCSZ00)
    STS UCSR0C, R16
    RET

;------------------------
; USART Transmit
;------------------------
USART_Transmit:
    ; Wait for empty transmit buffer
    LDS R17, UCSR0A
    SBRS R17, UDRE0
    RJMP USART_Transmit
    
    ; Put data into buffer, sends the data
    STS UDR0, R16
    RET

;------------------------
; Print Distance to Serial Monitor
;------------------------
print_distance:
    ; Save distance value
    MOV R18, R30
    MOV R16, R25
    RCALL print_hex
    MOV R16, R24
    RCALL print_hex
    CPI R30, 0
    BRNE valid_distance

    LDI ZL, lo8(error_msg)
    LDI ZH, hi8(error_msg)
    RCALL print_string
    RET

    valid_distance:    
      ; Convert to ASCII digits
      CLR R19        ; Hundreds digit counter
      CLR R20        ; Tens digit counter
      
      ; Calculate hundreds digit
      hundreds_loop:
          CPI R18, 100
          BRLO end_hundreds
          INC R19
          SUBI R18, 100
          RJMP hundreds_loop
      end_hundreds:
      
      ; Calculate tens digit
      tens_loop:
          CPI R18, 10
          BRLO end_tens
          INC R20
          SUBI R18, 10
          RJMP tens_loop
      end_tens:
      
      ; Now R19=hundreds, R20=tens, R18=units
      
      ; Print hundreds digit if not zero
      CPI R19, 0
      BREQ skip_hundreds
      MOV R16, R19
      SUBI R16, -'0'  ; Convert to ASCII
      RCALL USART_Transmit
      
      skip_hundreds:
      ; Print tens digit
      MOV R16, R20
      SUBI R16, -'0'  ; Convert to ASCII
      RCALL USART_Transmit
      
      ; Print units digit
      MOV R16, R18
      SUBI R16, -'0'  ; Convert to ASCII
      RCALL USART_Transmit
      
      ; Print " cm" and newline
      LDI R16, ' '
      RCALL USART_Transmit
      LDI R16, 'c'
      RCALL USART_Transmit
      LDI R16, 'm'
      RCALL USART_Transmit
      LDI R16, 0x0D   ; CR
      RCALL USART_Transmit
      LDI R16, 0x0A   ; LF
      RCALL USART_Transmit
      
      RET
  error_msg: .asciz "Error\r\n"
;------------------------
; Delay Subroutines
;------------------------
delay_10us:
    ; 16 cycles = 10us at 16MHz
    LDI R16, 53
    delay_10us_loop:
        DEC R16
        BRNE delay_10us_loop
    RET

delay_200us:
    ; Approximate 200ms delay
    LDI R16, 255
    delay_outer:
        LDI R17, 255
        delay_middle:
            LDI R18, 40
            delay_inner:
                DEC R18
                BRNE delay_inner
            DEC R17
            BRNE delay_middle
        DEC R16
        BRNE delay_outer
    RET

;------------------------
; Debug Tambahan
;------------------------
print_hex:
    ; Konversi nibble tinggi
    MOV R17, R16
    SWAP R17
    ANDI R17, 0x0F
    RCALL nibble_to_ascii
    RCALL USART_Transmit
    ; Konversi nibble rendah
    MOV R17, R16
    ANDI R17, 0x0F
    RCALL nibble_to_ascii
    RCALL USART_Transmit
    RET

nibble_to_ascii:
    CPI R17, 10
    BRLO is_decimal
    SUBI R17, -('A'-10)
    RET
is_decimal:
    SUBI R17, -'0'
    RET