#target rom

#data _SYSVARS, $8000, *

#code _BOOT, $0000, *

reset:
    di
    ld      sp, $FFFF

    ; Clear display
    ld      a, %00000001
    out     ($00), a

    ; Reiniciar el cursor
    ld      a, %00000010
    out     ($00), a

    ; Mostrar el cursor
    ld      a, %00000111
    out     ($00), a

loop:
    jp      loop

    .org $0066

nmi:
    retn

#code _DATA, *, *

hello:
    .asciz "Hello, world!"
