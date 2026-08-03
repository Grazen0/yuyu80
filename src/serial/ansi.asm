    .module ansi

; ------------------------------------------------------------------------------
; Clears the screen and moves the cursor to 1,1.
;
; In:       -
; Out:      -
; Destroys: a, c, hl
; ------------------------------------------------------------------------------
clear:
    ld      hl, s_clear
    jp      @serial.print

; ------------------------------------------------------------------------------
; Hides the cursor.
;
; In:       -
; Out:      -
; Destroys: a, c, hl
; ------------------------------------------------------------------------------
hide_cursor:
    ld      hl, s_hide_cursor
    jp      @serial.print

; ------------------------------------------------------------------------------
; Shows the cursor.
;
; In:       -
; Out:      -
; Destroys: a, c, hl
; ------------------------------------------------------------------------------
show_cursor:
    ld      hl, s_show_cursor
    jp      @serial.print

; ------------------------------------------------------------------------------
; Moves the cursor to position c,e.
;
; In:       c = column to move to.
;           e = row to move to.
; Out:      -
; Destroys: a, bc, de, hl
; ------------------------------------------------------------------------------
move_cursor:
    push    de
    push    bc

    ld      c, "\E"
    call    @serial.print_char
    ld      c, '['
    call    @serial.print_char

    pop     hl
    ld      h, 0
    call    @serial.print_num

    ld      c, ';'
    call    @serial.print_char

    pop     hl
    ld      h, 0
    call    @serial.print_num

    ld      c, 'H'
    jp      @serial.print_char

; ------------------------------------------------------------------------------
; Moves the cursor horizontally to column c.
;
; In:       c = column to move to
; Out:      -
; Destroys: a, bc, de, hl
; ------------------------------------------------------------------------------
move_cursor_horizontal:
    push    bc
    ld      c, "\E"
    call    @serial.print_char
    ld      c, '['
    call    @serial.print_char
    pop     hl
    ld      h, 0
    call    @serial.print_num
    ld      c, 'G'
    jp      @serial.print_char

; ------------------------------------------------------------------------------
; Moves the cursor to the left by a certain amount.
;
; In:       hl = amount of columns to move
; Out:      -
; Destroys: a, bc, de, hl
; ------------------------------------------------------------------------------
move_cursor_left:
    ld      c, "\E"
    call    @serial.print_char
    ld      c, '['
    call    @serial.print_char
    call    @serial.print_num
    ld      c, 'D'
    jp      @serial.print_char

s_clear:        .byte "\E[1;1H\E[2J"Z
s_hide_cursor:  .byte "\E[?25l"Z
s_show_cursor:  .byte "\E[?25h"Z

    .endmodule
