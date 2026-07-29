    .module joypad

DEVICE_ADDR equ $52
RW_WRITE equ 0
RW_READ equ 1

read:
    call    @i2c.start

    ld      a, (DEVICE_ADDR << 1) | RW_WRITE
    call    @i2c.write
    bit     0, d
    ret     nz          ; no ack

    xor     a
    call    @i2c.write
    bit     0, d
    ret     nz          ; no ack

    call    @i2c.stop

    call    @i2c.start

    ld      a, (DEVICE_ADDR << 1) | RW_READ
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

    xor     a
    ld      d, a

    bit     7, l
    jr      z, .b0_low
    set     0, a
.b0_low:
    bit     1, h
    jr      z, .b1_low
    set     1, a
.b1_low:
    bit     6, l
    jr      z, .b2_low
    set     2, a
.b2_low:
    bit     0, h
    jr      z, .b3_low
    set     3, a
.b3_low:
    bit     2, l
    jr      z, .b4_low
    set     4, a
.b4_low:
    bit     4, l
    jr      z, .b5_low
    set     5, a
.b5_low:
    bit     6, h
    jr      z, .b6_low
    set     6, a
.b6_low:
    bit     4, h
    jr      z, .b7_low
    set     7, a
.b7_low:
    ret

    .endmodule
