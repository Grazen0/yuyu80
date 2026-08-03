    .include "system.inc"
    .include "macros.inc"
    .include "joypad.inc"

    resb    BLINK_DELAY, 1
    resb    FALL_DELAY, 1
    resb    redraw, 1
    resb    joyp_pressed, 1
    resb    joyp_down, 1

    resb    cur_rotate_right, 2

FIELD_HEIGHT            .equ 16
FIELD_WIDTH             .equ 10
FIELD_WIDTH_ALIGNED     .equ 16

FALL_SPEED equ TIMER_FREQ/3
FALL_SPEED_FAST equ TIMER_FREQ/50

    ; bool field[FIELD_WIDTH_ALIGNED][FIELD_HEIGHT]
    ; Contains, for each cell in the field, whether it contains a block or not
    resb    field, FIELD_WIDTH_ALIGNED * FIELD_HEIGHT


    padorg $0000
reset:
    di
    jp      init

    padorg $0008
ctc_int_vec:
    isr_slot isr_ctc_ch0
    isr_slot isr_ctc_ch1
    isr_slot isr_ctc_ch2
    isr_slot isr_ctc_ch3
    .assert (ctc_int_vec & %111) == 0

    org $0010
sio_int_vec:
    isr_slot isr_sio_b_tx_buffer_empty
    isr_slot isr_sio_b_external_status_change
    isr_slot isr_sio_b_rx_char_available
    isr_slot isr_sio_b_rx_special_condition
    isr_slot isr_sio_a_tx_buffer_empty
    isr_slot isr_sio_a_external_status_change
    isr_slot isr_sio_a_rx_char_available
    isr_slot isr_sio_a_rx_special_condition
    .assert (sio_int_vec & %1111) == 0

    padorg $0066
nmi:
    retn

isr_nop:
    ei
    reti

init:
    ld      sp, RAM_END & $FFFF

    call    @i2c.init       ; Init the PIO ASAP to prevent overloads on SDA and SCL
    call    @time.init
    call    @lcd.init
    call    @serial.init

    ; CTC interrupt vector
    ld      a, low(ctc_int_vec)
    out     (CTC_CH0), a

    ; SIO interrupt vector
    ld      a, $02              ; Select WR2
    out     (SIO_CTRL_B), a
    ld      a, low(sio_int_vec) ; Interrupt vector
    out     (SIO_CTRL_B), a

    ; init interrupts
    xor     a
    ld      i, a
    im      2
    ei

    ld      hl, TIMER_FREQ
    call    @time.delay

main:
    call    @serial.ansi.clear
    call    @serial.ansi.hide_cursor

    ld      hl, s_banner
    call    @serial.print

    xor     a
    ld      (BLINK_DELAY), a

.menu_loop:
    ld      a, (BLINK_DELAY)
    inc     a
    ld      (BLINK_DELAY), a

    cp      TIMER_FREQ/3
    jr      z, .show_indicator
    cp      2*TIMER_FREQ/3
    jr      z, .hide_indicator
    jr      .blink_switch_end
.show_indicator:
    ld      c, 10
    ld      e, 10
    call    @serial.ansi.move_cursor
    ld      c, '>'
    call    @serial.print_char
    ld      c, 24
    call    @serial.ansi.move_cursor_horizontal
    ld      c, '<'
    call    @serial.print_char
    jr      .blink_switch_end
.hide_indicator:
    ld      c, 10
    ld      e, 10
    call    @serial.ansi.move_cursor
    ld      c, ' '
    call    @serial.print_char
    ld      c, 24
    call    @serial.ansi.move_cursor_horizontal
    ld      c, ' '
    call    @serial.print_char
    xor     a
    ld      (BLINK_DELAY), a
.blink_switch_end:

    call    @joypad.read
    jr      nz, .no_read

    bit     JOYP_START_BIT, d
    jr      z, .game_init
.no_read:

    call    @time.wait_tick
    jp      .menu_loop

.game_init:
    call    @serial.ansi.clear

    ld      c, FIELD_POS_Y
    ld      e, FIELD_POS_X-2
    call    @serial.ansi.move_cursor

    ; Draw field with rows of "||. . . . . . . . ||"
    ld      b, FIELD_HEIGHT
.draw_field_loop:
    push    bc
    ld      hl, s_field_row
    call    @serial.print
    ld      hl, 2*FIELD_WIDTH + 4
    call    @serial.ansi.move_cursor_left
    pop     bc
    djnz    .draw_field_loop

    ld      hl, s_field_floor
    call    @serial.print

    call    new_piece

    ld      ix, blocks
    ld      iy, s_block
    call    draw_blocks

    ; FALL_DELAY = 0
    xor     a
    ld      (FALL_DELAY), a

    ; field[..] = 0
    .assert field_len <= 256    ; Turns out field_len is exactly 256, phew!
    ld      hl, field
    xor     a
    .if field_len == 256
        ld      b, a
    .else
        ld      b, field_len
    .endif
.clear_field_loop:
    ld      (hl), a
    inc     hl
    djnz    .clear_field_loop

    ; joyp_pressed = joyp_down = $FF
    dec     a
    ld      (joyp_pressed), a
    ld      (joyp_down), a

    ; init rng
    ld      hl, (timer)
    scf                     ; Ensure non-zero h
    rl      h
    scf                     ; Ensure non-zero l
    rl      l
    ld      (r_seed), hl

.game_loop:
    ; Copy blocks to blocks_new
    ld      bc, BLOCKS_COUNT*pos_t
    ld      hl, blocks
    ld      de, blocks_new
    ldir

    xor     a
    ld      (redraw), a

    ; c = ~joyp_prev | joyp
    call    @joypad.read
    jp      z, .read_ok
    ld      d, $FF          ; if read unsuccessful, default to have no buttons pressed
.read_ok:
    ld      hl, joyp_down
    ld      a, (hl)         ; a = joyp_down(old)
    ld      (hl), d

    ; a = joyp_down(old)
    ; d = joyp_down(new)
    ; joyp_pressed = ~joyp_down(old) | joyp_down(new)
    cpl
    or      d
    ld      (joyp_pressed), a

    and     JOYP_DOWN
    jr      nz, .skip_fast_fall
    ld      a, $FE
    ld      (FALL_DELAY), a
.skip_fast_fall:

    ld      a, (joyp_pressed)
    and     JOYP_A
    jr      nz, .rotate_right_end

    ; Rotate piece to the right
    ld      ix, blocks_new
    ld      hl, (cur_rotate_right)
    call    jp_hl
    call    check_piece
    jr      c, .rotate_right_end
    ld      a, 1
    ld      (redraw), a
.rotate_right_end:

    ld      a, (joyp_pressed)
    and     JOYP_B
    jr      nz, .rotate_left_end

    ; Rotate piece to the left (rotate right 3 times)
    ; TODO: actually implement left rotation
    ld      b, 3
.rotate_left_loop:
    push    bc
    ld      ix, blocks_new
    ld      hl, (cur_rotate_right)
    call    jp_hl
    pop     bc
    djnz    .rotate_left_loop

    call    check_piece
    jr      c, .rotate_left_end
    ld      a, 1
    ld      (redraw), a
.rotate_left_end:

    ld      a, (joyp_pressed)
    and     JOYP_SELECT
    call    z, debug_print_field

    ld      a, (joyp_pressed)
    and     JOYP_LEFT
    call    z, move_left
    ld      a, (joyp_pressed)
    and     JOYP_RIGHT
    call    z, move_right
    ld      a, (joyp_pressed)
    and     JOYP_DOWN
    jr      z, .fall


    ld      hl, FALL_DELAY
    inc     (hl)

    ld      a, (joyp_down)
    bit     JOYP_DOWN_BIT, a
    ld      a, (hl)
    jr      z, .time_fall_fast

    cp      FALL_SPEED
    jr      .time_fall_end
.time_fall_fast:
    cp      FALL_SPEED_FAST
.time_fall_end:
    jr      c, .fall_end

.fall:
    xor     a
    ld      (FALL_DELAY), a
    call    fall_block
.fall_end:

    ld      a, (redraw)
    or      a
    jr      z, .redraw_end

    ; Remove blocks
    ld      ix, blocks
    ld      iy, s_dot
    call    draw_blocks

    ; Copy blocks_new to blocks
    ld      bc, BLOCKS_COUNT*pos_t
    ld      hl, blocks_new
    ld      de, blocks
    ldir

    ; Draw new blocks
    ld      ix, blocks
    ld      iy, s_block
    call    draw_blocks
.redraw_end:

    call    @time.wait_tick
    jp      .game_loop

debug_print_field:
    debug_begin

    ld      b, FIELD_HEIGHT
.loop:
    push    bc

    ld      a, b
    dec     a
    .4  add     a
    ld      h, 0
    ld      l, a
    ld      de, field
    add     hl, de

    push    hl
    ld      c, b
    ld      e, FIELD_POS_X+2*FIELD_WIDTH+10
    call    @serial.ansi.move_cursor
    pop     hl

    xor     a
    ld      c, FIELD_WIDTH
.loop_inner:
    push    bc
    ld      d, (hl)
    call    @serial.print_hex
    inc     hl
    pop     bc
    dec     c
    jr      nz, .loop_inner

    pop     bc
    djnz    .loop

    debug_end
    ret

move_left:
    ; Move every block in blocks_new 1 column left
    ld      b, BLOCKS_COUNT
    ld      hl, blocks_new+pos_t.x
.loop:
    dec     (hl)
    .(pos_t)    inc     hl
    djnz    .loop

    call    check_piece
    ret     c
    ld      a, 1
    ld      (redraw), a
    ret

; same as move_left, but dec (hl) instead of inc (hl)
move_right:
    ; Move every block in blocks_new 1 column left
    ld      b, BLOCKS_COUNT
    ld      hl, blocks_new+pos_t.x
.loop:
    inc     (hl)
    .(pos_t)    inc     hl
    djnz    .loop

    call    check_piece
    ret     c
    ld      a, 1
    ld      (redraw), a
    ret

fall_block:
    ; Move every block in blocks_new 1 row down
    ld      b, BLOCKS_COUNT
    ld      hl, blocks_new+pos_t.y
.fall_loop:
    inc     (hl)
    .(pos_t)    inc     hl
    djnz    .fall_loop

    call    check_piece
    jr      nc, .no_collision

    ; Collision detected. Place the piece and make a new one.
    call    place_piece
    jp      new_piece

.no_collision:
    ld      a, 1
    ld      (redraw), a
    ret

load_pos_as_field_addr:
    ; This code works under these assumptions
    .assert FIELD_HEIGHT <= 16
    .assert FIELD_WIDTH <= 16
    .assert field_len <= 256

    ; a = 16*y + x
    ld      a, (ix+pos_t.y)
    ; TODO: calculate number of shifts depending on field alignment
    .4  add     a
    add     a, (ix+pos_t.x)

    ; hl = &field[16*y + x]
    ld      hl, field
    ld      d, 0
    ld      e, a
    add     hl, de
    ret

place_piece:
    ; Place piece into field
    ld      b, BLOCKS_COUNT
    ld      ix, blocks
.place_loop:
    push    bc

    call    load_pos_as_field_addr
    ld      (hl), 1

    call    load_pos_as_screen_pos
    call    @serial.ansi.move_cursor
    ld      hl, s_block
    call    @serial.print

    .(pos_t)    inc     ix
    pop     bc
    djnz    .place_loop

    ; Scan from bottom to top for full lines
    ld      ix, clear_lines
    ld      iy, clear_lines_count
    ld      (iy), 0
    ld      b, FIELD_HEIGHT
.scan_loop:
    ; hl = &field[16*(b-1)]
    ld      a, b
    dec     a
    .4 add     a ; TODO: do this with FIELD_WIDTH_ALIGNED instead of hardcoding 4
    ld      d, 0
    ld      e, a
    ld      hl, field
    add     hl, de
    push    hl

    ld      c, FIELD_WIDTH
.scan_loop_inner:
    ld      a, (hl)
    or      a
    jr      z, .line_not_full
    inc     hl
    dec     c
    jr      nz, .scan_loop_inner

    ; Line is full. Add it to clear_lines
    ld      (ix), b
    inc     ix
    inc     (iy)

    ; Now clear it (in field)
    xor     a
    ex      (sp), hl

    ld      c, FIELD_WIDTH
.clear_line_loop:
    ld      (hl), a
    inc     hl
    dec     c
    jr      nz, .clear_line_loop

    ; Now clear it (visually)
    push    bc
    ld      c, b
    ld      e, FIELD_POS_X
    call    @serial.ansi.move_cursor
    ld      hl, s_field_row_inner
    call    @serial.print
    pop     bc

    call    @time.wait_tick
    call    @time.wait_tick

.line_not_full:
    pop     hl
    djnz    .scan_loop

    call    @lcd.move_cursor_line_1
    ld      hl, s_empty
    call    @lcd.print
    call    @lcd.move_cursor_line_1

    ; Scan upwards and shift down onto empty lines
    ld      ix, clear_lines
    ld      b, FIELD_HEIGHT ; b = dest line
    ld      c, b            ; c = source line
.shift_loop:

; while source line is clear, use next line as source (dec c)
.while_loop:
    ld      a, (iy)             ; of course, check that at least..
    or      a                   ; ..
    jr      z, .dec_source_end  ; ..a clear line still remains
    ld      a, c
    cp      (ix)
    jr      nz, .dec_source_end

    dec     c
    dec     (iy)
    inc     ix
    jr      .while_loop
.dec_source_end:

    ; if source = dest, we don't need to move anything
    ld      a, c
    cp      b
    jr      z, .skip_move

    ; copy line from source to dest
    push    bc

    ; hl = &field[16*(b-1)]   <- dest
    ld      a, b
    dec     a
    .4 add     a
    ld      h, 0
    ld      l, a
    ld      de, field
    add     hl, de
    push    hl          ; push dest

    ; hl = &field[16*(c-1)]   <- source
    ld      a, c
    dec     a
    jp      p, .move_from_source

    ; dest has already left the field
    ; just fill with 0s
    xor     a
    ld      b, FIELD_WIDTH
.move_from_0_loop:
    ld      (hl), a
    inc     hl
    djnz    .move_from_0_loop
    jr      .move_end
.move_from_source:
    .4 add     a
    ld      h, 0
    ld      l, a
    ld      de, field
    add     hl, de          ; hl = source

    pop     de              ; de = dest
    push    de              ; also re-save it for redrawing the line
    ld      bc, FIELD_WIDTH
    ldir
.move_end:

    pop     de  ; de = dest
    pop     bc
    push    bc
    push    de

    ld      c, b
    ld      e, FIELD_POS_X
    call    @serial.ansi.move_cursor
    pop     de

    ld      b, FIELD_WIDTH
.print_loop:
    ld      a, (de)
    or      a
    jr      nz, .one
    ld      hl, s_dot
    jr      .select_end
.one:
    ld      hl, s_block
.select_end:
    call    @serial.print
    inc     de
    djnz    .print_loop

    pop     bc

.skip_move:
    dec     c   ; source--
    djnz    .shift_loop

    ret

    resb    clear_lines, FIELD_HEIGHT
    resb    clear_lines_count, 1

; ------------------------------------------------------------------------------
; Checks if `blocks_new` collides with something. If so, changes it
; back to `blocks`.
;
; In:       -
; Out:      carry flag = 0 did not collide, no fix needed fix
;                        1 collided, had to fix
; Destroys: a, bc, de, hl, ix
; ------------------------------------------------------------------------------
check_piece:
    ld      b, BLOCKS_COUNT
    ld      ix, blocks_new
.loop:
    ; Fix if pos.x >= FIELD_WIDTH
    ld      a, (ix+pos_t.x)
    cp      FIELD_WIDTH
    jr      nc, .fix

    ; Fix if pos.y >= FIELD_HEIGHT
    ld      a, (ix+pos_t.y)
    cp      FIELD_HEIGHT
    jr      nc, .fix

    ; Fix if intersects with a block in field
    call    load_pos_as_field_addr
    bit     0, (hl)
    jr      nz, .fix

    .(pos_t)    inc     ix
    djnz    .loop
    ret
.fix:
    ; Re-copy blocks to blocks_new
    ld      bc, BLOCKS_COUNT*pos_t
    ld      hl, blocks
    ld      de, blocks_new
    ldir
    scf
    ret

new_piece:
    call    @random.rand_7

    ; hl = rotate_right_table + 2*a
    ld      h, 0
    ld      l, a
    add     hl, hl

    ld      de, rotate_right_table
    add     hl, de

    ld      e, (hl)
    inc     hl
    ld      d, (hl)
    ld      (cur_rotate_right), de

    ; hl = pieces + 2*a
    ld      h, 0
    ld      l, a
    .assert piece_t == 8
    .3  add     hl, hl
    ld      de, pieces
    add     hl, de

    ld      de, blocks
.loop:
    ld      a, (hl)
    ld      (de), a
    inc     de
    inc     hl

    ld      a, (hl)
    add     a, 3    ; Add 3 to every x coordinate to center the piece
    ld      (de), a
    inc     de
    inc     hl

    djnz    .loop
    ret

; ix = address of pos_t to load
load_pos_as_screen_pos:
    ; c = FIELD_POS_Y + y
    ld      a, (ix+pos_t.y)
    add     FIELD_POS_Y
    ld      c, a

    ; e = FIELD_POS_X + 2*x
    ld      a, (ix+pos_t.x)
    sla     a
    add     FIELD_POS_X
    ld      e, a

    ret

draw_blocks:
    ld      b, BLOCKS_COUNT
.draw_loop:
    call    load_pos_as_screen_pos
    push    bc
    call    @serial.ansi.move_cursor
    push    iy
    pop     hl
    call    @serial.print
    pop     bc

    .(pos_t)    inc     ix
    djnz    .draw_loop
    ret


    .include "math.asm"
    .include "conv.asm"
    .include "lcd.asm"
    .include "time.asm"
    .include "serial/serial.asm"
    .include "i2c.asm"
    .include "joypad.asm"
    .include "random.asm"

; A rotate subroutine must assume ix to be the base of the blocks array to rotate
; TODO: document that info better
rotate_right_table:
    .word rotate_right_i            ; i
    .word rotate_right_around_0     ; j
    .word rotate_right_around_0     ; l
    .word rotate_right_o            ; o
    .word rotate_right_around_0     ; s
    .word rotate_right_around_0     ; t
    .word rotate_right_around_0     ; z

rotate_right_around_0:
    ld      h, (ix+pos_t.y) ; h = src.y
    ld      l, (ix+pos_t.x) ; l = src.x
    ld      b, BLOCKS_COUNT-1
.loop:
    .(pos_t)    inc     ix

    ; (x0', y0') = (-y0, x0)

    ; c = x0 = x - src.x
    ld      a, (ix+pos_t.x)
    sub     l
    ld      c, a

    ; a = y0 = y - src.y
    ld      a, (ix+pos_t.y)
    sub     h

    ; Calculate x' first
    neg
    add     l
    ld      (ix+pos_t.x), a

    ; Now calculate y'
    ld      a, c
    add     h
    ld      (ix+pos_t.y), a

    djnz    .loop
    ret

rotate_right_i:
    ; d = blocks[0].y - blocks[1].y
    ld      a, (ix+pos_t.y)
    sub     (ix+pos_t+pos_t.y) 
    ld      d, a

    ; e = blocks[0].x - blocks[1].x
    ld      a, (ix+pos_t.x)
    sub     (ix+pos_t+pos_t.x)
    ld      e, a

    call    rotate_right_around_0

    ; The I piece should "push" each block perpendicular
    ; to its new direction.
    ; TODO: add ascii art for this piece (and all of the rest too)
    ld      hl, blocks_new
.adjust_loop:
    ld      a, (hl)
    add     d
    ld      (hl), a
    inc     hl

    ld      a, (hl)
    add     e
    ld      (hl), a
    inc     hl

    djnz    .adjust_loop
    ret

rotate_right_o:
    ret

jp_hl:
    jp      (hl)

s_field_row: .byte "||. . . . . . . . . . ||\n"Z
s_field_row_inner: .byte ". . . . . . . . . . "Z
s_field_floor:  .byte "||====================||"Z

s_block:        .byte "[]"Z
s_dot:          .byte ". "Z

s_banner:
    .byte "\r\n"
    .byte '     _____    _        _',      "\r\n"
    .byte '    |__  /___| |_ _ __(_)___',  "\r\n"
    .byte "      / // _ \\ __| '__| / __|", "\r\n"
    .byte '     / /|  __/ |_| |  | \__ \', "\r\n"
    .byte '    /____\___|\__|_|  |_|___/', "\r\n"
    .byte                                  "\r\n"
    .byte "        (Tetris on a Z80)",     "\r\n"
    .byte                                  "\r\n"
    .byte "           Press start",        "\r\n"Z
    .struct pos_t
y:      byte
x:      byte
    .ends

BLOCKS_COUNT = 4

    ; pos_t blocks[BLOCKS_COUNT]
    ; Contains the positions of the currently falling piece.
    resb    blocks, BLOCKS_COUNT*pos_t
    resb    blocks_new, BLOCKS_COUNT*pos_t

    .struct piece_t
b1:     pos_t
b2:     pos_t
b3:     pos_t
b4:     pos_t
    .ends

PIECES_COUNT = 7
pieces:
i_piece:    piece_t {{0, 1}, {0, 0}, {0, 2}, {0, 3}}
j_piece:    piece_t {{1, 1}, {0, 0}, {1, 0}, {1, 2}}
l_piece:    piece_t {{1, 1}, {0, 2}, {1, 0}, {1, 2}}
o_piece:    piece_t {{0, 1}, {0, 2}, {1, 1}, {1, 2}}
s_piece:    piece_t {{1, 1}, {0, 1}, {0, 2}, {1, 0}}
t_piece:    piece_t {{1, 1}, {1, 0}, {0, 1}, {1, 2}}
z_piece:    piece_t {{1, 1}, {0, 0}, {0, 1}, {1, 2}}
pieces_end:

    .assert (pieces_end - pieces) / piece_t == PIECES_COUNT

; 1-indexed, like terminal rows/columns
FIELD_POS_Y     .equ 1
FIELD_POS_X     .equ 9

s_no_ack:   .byte "No ACK"Z
s_error:    .byte "ERROR"Z
s_empty:    .byte "                "Z

    .assert FIELD_POS_Y == 1 ; for now
