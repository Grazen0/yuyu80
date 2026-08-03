    .include "random.inc"

    .module random

; Source: https://www.nesdev.org/wiki/Random_number_generator 
rand_u8_nz:
    ld      ix, r_seed
    ld      b, 8
    ld      a, (ix+0)
.loop:
    sla     a
    rl      (ix+1)
    jr      nc, .skip_xor
    xor     $39
.skip_xor:
    djnz    .loop
    ld      (ix+0), a
    ret

; Source: https://forums.nesdev.org/viewtopic.php?t=6757
rand_7:
    call    rand_u8_nz
    and     %00000111
    cp      7
    ret     c

    ld      a, (r_incvalue)
    dec     a
    jp      p, .wrap_end
    ld      a, 6
.wrap_end:
    ld      (r_incvalue), a
    ret

    .endmodule
