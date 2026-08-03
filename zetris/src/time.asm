    .include "macros.inc"
    .include "time.inc"

    .module time

; ------------------------------------------------------------------------------
; Initializes the time module. Must be called before any other time subroutines.
;
; In:       -
; Out:      -
; Destroys: a
; ------------------------------------------------------------------------------
init:
    ; Channel 3 is set to trigger an interrupt @ ~100Hz
    ld      a, %10100111
    ;           ||||||||
    ;           |||||||+- is control word
    ;           ||||||+-- reset
    ;           |||||+--- time constant follows
    ;           ||||+---- automatic timer trigger
    ;           |||+----- clk/trg reacts to falling edge
    ;           ||+------ prescaler value 256
    ;           |+------- timer mode
    ;           +-------- enable interrupts
    out     (CTC_CH3), a
    ld      a, TIMER_TIME_CONST
    out     (CTC_CH3), a

    ; hl' will always be `timer` so that we can use it
    ; immediately in the isr
    exx
    ld      hl, timer
    exx

    ; also, we don't care what value `timer` is initialized to

    ret

@isr_ctc_ch3:
    ex      af, af'
    exx
    inc     (hl)
    exx
    ex      af, af'
    ei
    reti

; ------------------------------------------------------------------------------
; Waits for the next time tick.
;
; In:       -
; Out:      -
; Destroys: a, hl
; ------------------------------------------------------------------------------
wait_tick:
    ld      hl, timer
    ld      a, (hl)
.loop:
    halt
    cp      (hl)
    jr      z, .loop
    ret


; ------------------------------------------------------------------------------
; Waits for the given time (in ticks).
;
; In:       hl = time in ticks
; Out:      -
; Destroys: bc, de, hl
; ------------------------------------------------------------------------------
delay:
    ld      bc, (timer)  ; bc: start = *time
    ex      de, hl      ; de: ms

.loop
    halt
    ld      hl, (timer)
    or      a        ; clear carry flag
    sbc     hl, bc
    or      a        ; clear carry flag

    ; at this point:
    ;   hl = *time - start
    ;   de = ms
    sbc     hl, de      ; c = (hl < de)
    jr      c, .loop

    ret

    .endmodule
