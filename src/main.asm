    .include "system.inc"
    .include "macros.inc"

    resb    counter, 2

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

    ; CTC interrupt vector
    ld      a, low ctc_int_vec
    out     (CTC_CH0), a

    ; SIO interrupt vector
    ld      a, $02              ; select WR2
    out     (SIO_CTRL_B), a
    ld      a, low sio_int_vec  ; interrupt vector
    out     (SIO_CTRL_B), a

    call    @time.init
    call    @lcd.init
    call    @serial.init

    ; init pio
    ld      a, %00001111        ; Output mode
    out     (PIO_CTRL_A), a

    ld      a, %01011100
    out     (PIO_DATA_A), a

    ; init data
    ld      hl, $0000
    ld      (counter), hl

    ; init interrupts
    xor     a
    ld      i, a
    im      2
    ei

.loop:
    ; send something via SIO
    ld      a, '*'
    out     (SIO_DATA_A), a

    call    print_counter

    ld      hl, (counter)
    inc     hl
    ld      (counter), hl

    in      a, (PIO_DATA_A)
    cpl                         ; a = ~a
    out     (PIO_DATA_A), a

    ld      hl, 1000
    call    @time.delay

    jr      .loop

print_counter:
    call    @lcd.reset_cursor

    ld      hl, s_count
    call    @lcd.print

    ld      hl, (counter)
    call    @lcd.print_num

    jp      @lcd.clear_to_eol

    .include "math.asm"
    .include "conv.asm"
    .include "lcd.asm"
    .include "time.asm"
    .include "serial.asm"

s_count: .byte "Count: ", 0
