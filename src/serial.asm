    .module serial

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
    ;           |||||||+- is control word
    ;           ||||||+-- reset
    ;           |||||+--- time constant follows
    ;           ||||+---- automatic timer trigger
    ;           |||+----- clk/trg reacts to falling edge
    ;           ||+------ prescaler value 16
    ;           |+------- timer mode
    ;           +-------- disable interrupts
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
    ret


@isr_sio_a_rx_char_available:
    push    bc
    push    de
    push    hl
    push    af

    call    @lcd.reset_cursor
    ld      hl, s_char_available
    call    @lcd.print

    pop     af
    pop     hl
    pop     de
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

