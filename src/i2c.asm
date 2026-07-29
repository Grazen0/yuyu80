    .include "i2c.inc"

    .module i2c

SDA_BIT equ 0
SCL_BIT equ 1
SDA equ 1 << SDA_BIT
SCL equ 1 << SCL_BIT

START_STOP_WAIT equ 16

; ------------------------------------------------------------------------------
; Initializes I2C. Must be called before any other I2C subroutines.
;
; In:       -
; Out:      -
; Destroys: a
; ------------------------------------------------------------------------------
init:
    ; Init PIO port A
    ld      a, %11001111        ; Control mode
    out     (PIO_CTRL_A), a
    ld      (i2c_pio_mode), a

    ld      a, SCL | SDA        ; Set SCL and SDA as inputs
    out     (PIO_CTRL_A), a
    ld      (i2c_pio_io_conf), a

    ; SCL and SDA, when outputs, will always be 0.
    ; They are controlled only by changing their I/O direction. (See {scl,sda}_{drive_low,release})
    ld      a, ~(SCL | SDA)
    out     (PIO_DATA_A), a

    ret

; ------------------------------------------------------------------------------
; Drives the SCL line low (0).
;
; In:       -
; Out:      -
; Destroys: a
; ------------------------------------------------------------------------------
scl_drive_low:
    ld      a, (i2c_pio_mode)
    out     (PIO_CTRL_A), a
    ld      a, (i2c_pio_io_conf)
    and     ~SCL
    out     (PIO_CTRL_A), a
    ld      (i2c_pio_io_conf), a
    ret

; ------------------------------------------------------------------------------
; Releases the SCL line.
;
; In:       -
; Out:      -
; Destroys: a
; ------------------------------------------------------------------------------
scl_release:
    ld      a, (i2c_pio_mode)
    out     (PIO_CTRL_A), a
    ld      a, (i2c_pio_io_conf)
    or      SCL
    out     (PIO_CTRL_A), a
    ld      (i2c_pio_io_conf), a
    ret

; ------------------------------------------------------------------------------
; Drives the SDA line low (0).
;
; In:       -
; Out:      -
; Destroys: a
; ------------------------------------------------------------------------------
sda_drive_low:
    ld      a, (i2c_pio_mode)
    out     (PIO_CTRL_A), a
    ld      a, (i2c_pio_io_conf)
    and     ~SDA
    out     (PIO_CTRL_A), a
    ld      (i2c_pio_io_conf), a
    ret

; ------------------------------------------------------------------------------
; Releases the SDA line.
;
; In:       -
; Out:      -
; Destroys: a
; ------------------------------------------------------------------------------
sda_release:
    ld      a, (i2c_pio_mode)
    out     (PIO_CTRL_A), a
    ld      a, (i2c_pio_io_conf)
    or      SDA
    out     (PIO_CTRL_A), a
    ld      (i2c_pio_io_conf), a
    ret

; ------------------------------------------------------------------------------
; Runs a serial clock I2C cycle:
;     1 -> SCL
;   SDA ->   d
;     0 -> SCL
;
; In:       -
; Out:      d = bit read during the clock cycle
; Destroys: a
; ------------------------------------------------------------------------------
scl_cycle:
    call    scl_release
    .8      nop             ; wait for a bit

    in      a, (PIO_DATA_A)
    and     SDA
    ld      d, a

    jp      scl_drive_low

; ------------------------------------------------------------------------------
; Executes the I2C start sequence.
;
; In:       -
; Out:      -
; Destroys: a, b
; ------------------------------------------------------------------------------
start:
    call    sda_release
    call    scl_release
    call    sda_drive_low
    call    scl_drive_low

    ld      b, START_STOP_WAIT
.wait_loop:
    djnz    .wait_loop
    ret

; ------------------------------------------------------------------------------
; Executes the I2C stop sequence.
;
; In:       -
; Out:      -
; Destroys: a
; ------------------------------------------------------------------------------
stop:
    call    sda_drive_low
    call    scl_release
    call    sda_release

    ld      b, START_STOP_WAIT
.wait_loop:
    djnz    .wait_loop
    ret

; ------------------------------------------------------------------------------
; Writes a byte via I2C.
;
; In:       a = byte to write
; Out:      d = 0 if received ack, 1 otherwise
; Destroys: a, bc, de, hl
; ------------------------------------------------------------------------------
write:
    ld      b, 8
    ld      c, a
.loop:
    rlc     c
    jr      nc, .bit_low

    call    sda_release
    jr      .bit_low_end
.bit_low:
    call    sda_drive_low
.bit_low_end:

    call    scl_cycle
    djnz    .loop

    ; read ack
    call    sda_release
    jp      scl_cycle

; ------------------------------------------------------------------------------
; Reads a byte from I2C.
;
; In:       e = send ack (1) or nack (0)
; Out:      c = byte read
; Destroys: a, b, d
; ------------------------------------------------------------------------------
read:
    ld      c, 0
    ld      b, 8
.loop:
    call    scl_cycle
    srl     d
    rl      c
    djnz    .loop

    bit     0, e
    call    nz, sda_drive_low

    call    scl_cycle
    call    sda_release

    ret

s_no_ack:
    .byte "No ACK", 0

    .endmodule
