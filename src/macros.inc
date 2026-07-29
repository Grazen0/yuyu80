    .ifndef MACROS_INC
    .define MACROS_INC

    .include "system.inc"

    .macro padorg addr
        .if $ < addr
            .block addr-$
        .endif
        .org addr
    .endm

__ramptr defl RAM_START

    .macro resb name?, size?
name? equ __ramptr
name? _ _len equ size?
__ramptr defl __ramptr + size?
    .endm

    .macro isr_slot label?
        .if exist label?
            .word label?
        .else
            .word @isr_nop
        .endif
    .endm
    
    .endif
