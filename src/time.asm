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
    ; Channel 0 is set to trigger an interrupt every ms
    ld      a, %10000111
    ;           ||||||||
    ;           |||||||+- is control word
    ;           ||||||+-- reset
    ;           |||||+--- time constant follows
    ;           ||||+---- automatic timer trigger
    ;           |||+----- clk/trg reacts to falling edge
    ;           ||+------ prescaler value 16
    ;           |+------- timer mode
    ;           +-------- enable interrupts
    out     (CTC_CH0), a
    ld      a, TIMER_TIME_CONST
    out     (CTC_CH0), a

    ; we don't care what value time is initialized to

    ret

@isr_ctc_ch0:
    push    bc
    ld      bc, (timer)
    inc     bc
    ld      (timer), bc
    pop     bc
    ei
    reti

; ------------------------------------------------------------------------------
; Waits for the given time (in milliseconds).
;
; In:       hl = time in milliseconds
; Out:      -
; Destroys: bc, de, hl
; ------------------------------------------------------------------------------
delay:
    ld      bc, (timer)  ; bc: start = *time
    ex      de, hl      ; de: ms

.loop
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
