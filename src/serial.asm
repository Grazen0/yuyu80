    .include "serial.inc"

    .module serial

rts_off:
    ld      a, $05          ; Select WR5
    out     (SIO_CTRL_A), a
    ld      a, %11101000
    ;           ||||||||
    ;           |||||||+- tx crc enable = 0
    ;           ||||||+-- rts = 0
    ;           |||||+--- tx sdlc/crc-16 = 0
    ;           ||||+---- tx enable = 1
    ;           |||+----- send break = 0
    ;           |++------ bits per char = 11 (8)
    ;           +-------- dtr = 1
    out     (SIO_CTRL_A), a
    ret

rts_on:
    ld      a, $05          ; Select WR5
    out     (SIO_CTRL_A), a
    ld      a, %11101010
    ;           ||||||||
    ;           |||||||+- tx crc enable = 0
    ;           ||||||+-- rts = 1
    ;           |||||+--- tx sdlc/crc-16 = 0
    ;           ||||+---- tx enable = 1
    ;           |||+----- send break = 0
    ;           |++------ bits per char = 11 (8)
    ;           +-------- dtr = 1
    out     (SIO_CTRL_A), a
    ret

; ------------------------------------------------------------------------------
; Initializes the serial module. Must be called before any other serial
; subroutines.
;
; In:       -
; Out:      -
; Destroys: a
; ------------------------------------------------------------------------------
init:
    ; CTC channel 1 produces the clock for the SIO
    ld      a, %00000111
    ;           ||||||||
    ;           |||||||+- is control word = 1
    ;           ||||||+-- reset = 1
    ;           |||||+--- time constant follows = 1
    ;           ||||+---- automatic timer trigger
    ;           |||+----- clk/trg edge = 1 (falling edge)
    ;           ||+------ prescaler value = 1 (x16)
    ;           |+------- timer mode = 0
    ;           +-------- enable interrupts = 0
    out     (CTC_CH1), a
    ld      a, SIO_TIME_CONST
    out     (CTC_CH1), a

    ; SIO channel A
    ld      a, $30              ; select WR0, error reset
    out     (SIO_CTRL_A), a
    ld      a, %00011000        ; channel reset
    out     (SIO_CTRL_A), a

    ld      a, $04              ; select WR4
    out     (SIO_CTRL_A), a
    ld      a, %01000100
    ;           |||||| |
    ;           |||||| +- no parity
    ;           ||||++--- 1-bit stop
    ;           ||++----- 8-bit sync character
    ;           ++------- x16 clock mode
    out     (SIO_CTRL_A), a

    ld      a, $05              ; select WR5
    out     (SIO_CTRL_A), a
    ld      a, %11101000
    ;           ||||||||
    ;           |||||||+- tx crc disable
    ;           ||||||+-- rts inactive
    ;           |||||+--- tx sdlc/crc-16 disable
    ;           ||||+---- tx enable
    ;           |||+----- no break
    ;           |++------ 8 bits per char
    ;           +-------- dtr inactive
    out     (SIO_CTRL_A), a

    ; SIO channel B (inactive)
    ld      a, $01              ; select WR1
    out     (SIO_CTRL_B), a
    ld      a, %00000100
    ;           ||||||||
    ;           |||||||+- ext int disable
    ;           ||||||+-- tx int disable
    ;           |||||+--- status affects vector
    ;           |||++---- rx int disable
    ;           ||+------ no wait/ready on r/t
    ;           |+------- no wait/ready function
    ;           +-------- wait/ready disable
    out     (SIO_CTRL_B), a

    ld      a, $01              ; select WR1
    out     (SIO_CTRL_A), a
    ld      a, %00011000
    ;           ||||||||
    ;           |||||||+- ext int disable
    ;           ||||||+-- tx int disable
    ;           |||||+--- status affects vector
    ;           |||++---- int on all rx characters
    ;           ||+------ no wait/ready on r/t
    ;           |+------- no wait/ready function
    ;           +-------- wait/ready disable
    out     (SIO_CTRL_A), a

    ld      a, $03              ; select WR3
    out     (SIO_CTRL_A), a
    ld      a, %11000001
    ;           ||||||||
    ;           |||||||+- rx enable
    ;           ||||||+-- no sync char load inhibit
    ;           |||||+--- no sdlc (?)
    ;           ||||+---- rx crc disable
    ;           |||+----- no hunt phase
    ;           ||+------ no auto enables
    ;           ++------- rx 8 bits per char
    out     (SIO_CTRL_A), a

    ; init rx buffer
    xor     a
    ld      (serial_rx_tail), a
    ld      (serial_rx_head), a

    ret

; ------------------------------------------------------------------------------
; Returns the number of available bytes to read from the serial input buffer.
;
; In:       -
; Out:      a = # of available bytes to read
; Destroys: b
; ------------------------------------------------------------------------------
available:
    ld      a, (serial_rx_head)
    ld      b, a
    ld      a, (serial_rx_tail)
    sub     b
    and     serial_rx_buffer_len-1
    ret

; ------------------------------------------------------------------------------
; Reads a byte from the serial input buffer.
;
; In:       -
; Out:      a = byte read.
; Destroys: hl
; ------------------------------------------------------------------------------
read:
    ld      hl, serial_rx_buffer
    ld      a, (serial_rx_head)
    add     l
    ld      l, a

    sub     low(serial_rx_buffer)-1 ; -1 increments head
    and     serial_rx_buffer_len-1
    ld      (serial_rx_head), a

    ld      a, (hl)
    ret

; ------------------------------------------------------------------------------
; Waits for the transmit buffer to be empty.
;
; In:       -
; Out:      -
; Destroys: a
; ------------------------------------------------------------------------------
wait_tx_empty:
    in      a, (SIO_CTRL_A)     ; Read RR0
    and     $04
    jr      z, wait_tx_empty
    ret

; ------------------------------------------------------------------------------
; Prints a character via serial.
;
; In:       c = character to print
; Out:      -
; Destroys: a
; ------------------------------------------------------------------------------
print_char:
    call    wait_tx_empty
    ld      a, c
    out     (SIO_DATA_A), a
    ret

; ------------------------------------------------------------------------------
; Prints a null-terminated string via serial.
;
; In:       hl = pointer to the string to print
; Out:      -
; Destroys: a, c, hl
; ------------------------------------------------------------------------------
print:
    ld      a, (hl)
    or      a
    ret     z

    ld      c, a
    call    print_char
    inc     hl
    jr      print

@isr_sio_a_rx_char_available:
    push    bc
    push    hl
    push    af

.rx_loop:
    in      a, (SIO_DATA_A)
    ld      c, a

    ld      hl, serial_rx_buffer
    ld      a, (serial_rx_tail)
    add     l
    ld      l, a

    sub     low(serial_rx_buffer)-1 ; -1 increments tail
    and     serial_rx_buffer_len-1
    ld      (serial_rx_tail), a

    ld      (hl), c

    in      a, (SIO_CTRL_A) ; Read RR0
    and     $01             ; bit 0 -> rx char available
    jr      nz, .rx_loop

    pop     af
    pop     hl
    pop     bc
    ei
    reti

@isr_sio_a_rx_special_condition:
    push    bc
    push    de
    push    hl
    push    af

    call    @lcd.reset_cursor
    ld      hl, s_special_condition
    call    @lcd.print

    pop     af
    pop     hl
    pop     de
    pop     bc
    ei
    reti

s_special_condition: .byte "Special!", 0
s_char_available: .byte "Char available!", 0

    .endmodule

