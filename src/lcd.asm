    .include "lcd.inc"
    .include "system.inc"

    .module lcd

INSTR_SET_DDRAM equ $80

INSTR_DISPLAY_CTRL equ %00001000

; ------------------------------------------------------------------------------
; Waits for the LCD's busy flag to go low.
;
; In:   -
; Out:  -
; Destroys: a
; ------------------------------------------------------------------------------
busy_wait:
    in      a, (LCD_CTRL) 
    and     $80
    ret     z
    jr      busy_wait

; ------------------------------------------------------------------------------
; Sends an instruction to the LCD.
;
; In:       a = instruction to send
; Out:      -
; Destroys: -
; ------------------------------------------------------------------------------
send_instr:
    push    af
    call    busy_wait
    pop     af
    out     (LCD_CTRL), a
    ret


; ------------------------------------------------------------------------------
; Resets the LCD's cursor position to the beginning.
;
; In:       -
; Out:      -
; Destroys: a
; ------------------------------------------------------------------------------
reset_cursor:
    ld      a, INSTR_SET_DDRAM | $00
    jp      send_instr

; ------------------------------------------------------------------------------
; Initializes the LCD. Must be called before any other LCD subroutines.
;
; In:       -
; Out:      -
; Destroys: a
; ------------------------------------------------------------------------------
init:
    ld      a, %00111000    ; interface data length & misc
    ;              |||
    ;              ||+--- 5x11/5x8 font = 0 (5x8)
    ;              |+---- 2/1 lines = 1 (1 line)
    ;              +----- 8/4-bit mode = 1 (8-bit)
    call    send_instr

    ld      a, %00000010    ; return home
    call    send_instr

    ld      a, %00000110    ; entry mode set
    ;                 ||
    ;                 |+- shift display = 0
    ;                 +-- inc/dec cursor = 1 (inc)
    call    send_instr


    ld      a, %00001111    ; display on/off control
    ;                |||
    ;                ||+- cursor blinking = 1
    ;                |+-- cursor enable = 1
    ;                +--- display enable = 1
    call    send_instr

    ld      a, %00000001    ; clear display
    call    send_instr

    jp      reset_cursor

; ------------------------------------------------------------------------------
; Prints a character to the LCD.
;
; In:       a = character to print
; Out:      -
; Destroys: -
; ------------------------------------------------------------------------------
print_char:
    push    af
    call    busy_wait
    pop     af
    out     (LCD_DATA), a
    ret

; ------------------------------------------------------------------------------
; Fills the remainder of the LCD's current line with " ".
;
; In:       -
; Out:      -
; Destroys: a, b
; ------------------------------------------------------------------------------
clear_to_eol:
    ld      b, 16
    ld      a, ' '

.loop
    call    print_char
    djnz    .loop

    ret


; ------------------------------------------------------------------------------
; Prints a null-terminated string to the LCD.
;
; In:       hl = pointer to the string to print
; Out:      -
; Destroys: a, hl
; ------------------------------------------------------------------------------
print:
    ld      a, (hl)
    or      a
    ret     z

    call    print_char
    inc     hl
    jr      print

; ------------------------------------------------------------------------------
; Prints a byte in hex format to the LCD.
;
; In:       c = byte to print
; Out:      -
; Destroys: a
; ------------------------------------------------------------------------------
print_hex:
    ld      a, c
    .4      srl     a
    call    @conv.digit_to_hex
    call    print_char

    ld      a, c
    and     $0F
    call    @conv.digit_to_hex
    jp      print_char

; ------------------------------------------------------------------------------
; Prints a byte in binary format to the LCD.
;
; In:       d = byte to print
; Out:      -
; Destroys: a, b
; ------------------------------------------------------------------------------
print_bin:
    ld      b, 8
.loop:
    rlc     d
    ld      a, '0'
    adc     0
    ld      c, a
    call    print_char

    djnz    .loop
    ret


; ------------------------------------------------------------------------------
; Prints a 16-bit unsigned number to the LCD.
;
; In:       hl = number to print
; Out:      -
; Destroys: a, bc, de, hl
; ------------------------------------------------------------------------------
print_num:
    ld      bc, num_str_buf
    call    @conv.num_to_str
    jp      print

    .endmodule
