    .include "joypad.inc"

    .module joypad

DEVICE_ADDR equ $52
RW_WRITE equ 0
RW_READ equ 1

; ------------------------------------------------------------------------------
; Reads the joypad's current button state.
;
; In:       -
; Out:      d = joypad bits
;           zero flag = 1 if successful
;                       0 if could not read
; Destroys: a, bc, e, hl
; ------------------------------------------------------------------------------
read:
    call    @i2c.start

    ld      c, (DEVICE_ADDR << 1) | RW_WRITE
    call    @i2c.write
    bit     0, d
    ret     nz          ; no ack

    ld      c, 0
    call    @i2c.write
    bit     0, d
    ret     nz          ; no ack

    call    @i2c.stop

    call    @i2c.start

    ld      c, (DEVICE_ADDR << 1) | RW_READ
    call    @i2c.write
    bit     0, d
    ret     nz          ; no ack

    ld      e, $01      ; send ack
    call    @i2c.read
    call    @i2c.read
    call    @i2c.read
    call    @i2c.read
    call    @i2c.read
    ld      l, c
    dec     e           ; send nack now
    call    @i2c.read
    ld      h, c
    call    @i2c.stop

    ld      d, 0

    bit     7, l
    jr      z, .b0_low
    set     0, d
.b0_low:
    bit     1, h
    jr      z, .b1_low
    set     1, d
.b1_low:
    bit     6, l
    jr      z, .b2_low
    set     2, d
.b2_low:
    bit     0, h
    jr      z, .b3_low
    set     3, d
.b3_low:
    bit     2, l
    jr      z, .b4_low
    set     4, d
.b4_low:
    bit     4, l
    jr      z, .b5_low
    set     5, d
.b5_low:
    bit     6, h
    jr      z, .b6_low
    set     6, d
.b6_low:
    bit     4, h
    jr      z, .b7_low
    set     7, d
.b7_low:

    xor     a           ; set zero flag
    ret

    .endmodule
