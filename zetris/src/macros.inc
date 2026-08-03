    .ifndef MACROS_INC
    .define MACROS_INC

    .include "system.inc"

    .macro padorg addr
        .if $ < addr
            .block addr-$
        .endif
        .org addr
    .endm

    .macro debug_begin
    push    bc
    push    de
    push    hl
    push    af
    .endm

    .macro debug_end
    pop     af
    pop     hl
    pop     de
    pop     bc
    .endm

__ramptr defl RAM_START

    .macro resb name?, size?
name? equ __ramptr
name? _ _len equ size?
__ramptr defl __ramptr + size?
    .assert __ramptr <= RAM_END
    .endm

    .macro isr_slot label?
        .if exist label?
            .word label?
        .else
            .word @isr_nop
        .endif
    .endm

    .endif
