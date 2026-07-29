    .include "system.inc"
    .include "macros.inc"

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

    call    @i2c.init
    call    @time.init
    call    @lcd.init
    call    @serial.init

    ; CTC interrupt vector
    ld      a, low(ctc_int_vec)
    out     (CTC_CH0), a

    ; SIO interrupt vector
    ld      a, $02              ; select WR2
    out     (SIO_CTRL_B), a
    ld      a, low(sio_int_vec) ; interrupt vector
    out     (SIO_CTRL_B), a

    ; init interrupts
    xor     a
    ld      i, a
    im      2
    ei

    ld      hl, s_banner
    call    @serial.print

.loop:
    call    @serial.available
    or      a
    jr      z, .skip_read_loop
    ld      b, a
.read_loop:
    call    @serial.read
    call    @serial.print_char
    djnz    .read_loop
.skip_read_loop:

    call    @lcd.reset_cursor
    call    @joypad.read
    bit     0, d
    jr      nz, .no_ack

    ld      d, a
    call    @lcd.print_bin
    jr      .read_end
.no_ack:
    ld      hl, s_no_ack
    call    @lcd.print
.read_end:

    jr      .loop

    .include "math.asm"
    .include "conv.asm"
    .include "lcd.asm"
    .include "time.asm"
    .include "serial.asm"
    .include "i2c.asm"
    .include "joypad.asm"

s_banner:
    .byte " _   _      _ _                             _     _ _ \r\n"
    .byte "| | | | ___| | | ___    __      _____  _ __| | __| | |\r\n"
    .byte "| |_| |/ _ \\ | |/ _ \\   \\ \\ /\\ / / _ \\| '__| |/ _` | |\r\n"
    .byte "|  _  |  __/ | | (_) |   \\ V  V / (_) | |  | | (_| |_|\r\n"
    .byte "|_| |_|\\___|_|_|\\___( )   \\_/\\_/ \\___/|_|  |_|\\__,_(_)\r\n"
    .byte "                    |/                                \r\n"
    .byte "Type something to see it back.\r\n", 0

s_no_ack: .byte "No ACK", 0
s_hello: .byte "Hello, world!", 0
s_available: .byte "Available: ", 0
