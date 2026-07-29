    .module conv

; ------------------------------------------------------------------------------
; Converts a digit into a hex character (one of "0123456789ABCDEF").
;
; In:       a = digit to convert
; Out:      a = digit as a character in hexadecimal
; Destroys: -
; ------------------------------------------------------------------------------
digit_to_hex:
    add     '0'
    cp      '9'+1
    ret     c
    add     'A'-'0'-10
    ret

; ------------------------------------------------------------------------------
; Converts a 16-bit number into a null-terminated string at a buffer (base 10).
;
; In:       hl = 16-bit number to convert to string
;           bc = pointer to the buffer to use
; Out:      hl = same as value of bc passed into the subroutine
; Destroys: a, bc, de
; ------------------------------------------------------------------------------
num_to_str:
    ; Step 1: stringify in reverse -------------------------
    push    bc

    ; Write null-terminator first
    xor     a
    ld      (bc), a

    ld      d, 10
.loop:
    push    bc
    call    @math.div
    pop     bc

    add     '0'
    inc     bc
    ld      (bc), a

    ld      a, h
    or      l
    jr     nz, .loop

    ; Step 2: reverse the result ---------------------------
    ex      (sp), hl
    ld      d, h
    ld      e, l
    ex      (sp), hl

    ; de = pointer to first char
    ; bc = pointer to last char

    or      a       ; Clear carry flag
.rev_loop:
    ld      h, b
    ld      l, c

    ; It is not necessary to clear the carry flag again
    ; because bc >= de always holds here.
    sbc     hl, de
    jr     z, .rev_loop_end
    jr     c, .rev_loop_end

    ld      a, (de)
    ld      h, a
    ld      a, (bc)
    ld      (de), a
    ld      a, h
    ld      (bc), a

    inc     de
    dec     bc
    jr      .rev_loop
.rev_loop_end:

    pop     hl
    ret

    .endmodule
