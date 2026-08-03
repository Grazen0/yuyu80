    .ifndef TIME_INC
    .define TIME_INC

    resb    timer, 2

TIMER_FREQ equ 100
TIMER_TIME_CONST equ SYS_CLK / (256 * TIMER_FREQ)
    .assert TIMER_TIME_CONST != 0


    .endif
