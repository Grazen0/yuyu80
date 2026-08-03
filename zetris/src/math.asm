    .module math

; ------------------------------------------------------------------------------
; Divides a 16-bit number by an 8-bit divisor.
;
; In:       hl = dividend
;           d  = divisor
; Out:      hl = quotient
;           a  = remainder
; Destroys: b
; ------------------------------------------------------------------------------
div:
    xor     a
    ld      b, 16
.loop:
    add     hl, hl
    rla
    cp      d
    jr      c, .skip_add
    sub     d
    inc     l
.skip_add:
    djnz    .loop
    ret

    .endmodule
