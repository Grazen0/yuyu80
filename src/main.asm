#target rom

SYS_CLK = 4000000

TIMER_FREQ = 1000
TIMER_TIME_CONST = SYS_CLK / (16 * TIMER_FREQ)

SIO_BAUD_RATE = 1200
SIO_CLK_FREQ = 16 * SIO_BAUD_RATE
SIO_TIME_CONST = SYS_CLK / (16 * SIO_CLK_FREQ)

LCD_CTRL = $00
LCD_DATA = $01

LCD_INSTR_CLEAR = %00000001
LCD_INSTR_HOME = %00000010
LCD_INSTR_SET_DDRAM = %10000000

LCD_INSTR_ENTRY_MODE = %00001000

PIO_DATA_A = $40
PIO_CTRL_A = $41
PIO_DATA_B = $42
PIO_CTRL_B = $43

CTC_CH0 = $80
CTC_CH1 = $81
CTC_CH2 = $82
CTC_CH3 = $83

SIO_DATA_A = $C0
SIO_CTRL_A = $C1
SIO_DATA_B = $C2
SIO_CTRL_B = $C3

#data _SYSVARS, $8000, $8000

time:       .block  2
counter:    .block  2
str_buf:    .block  6 ; TODO: find a more descriptive name


#code _BOOT, $0000, *

reset:
    di
    jp      init

    .org $0008
ctc_int_vec:
    .word irq_ctc_ch0
    .word irq_nop
    .word irq_nop
    .word irq_nop
    .assert (ctc_int_vec & %111) == 0

    .org $0010
sio_int_vec:
    .word irq_nop
    .word irq_nop
    .word irq_nop
    .word irq_nop
    .word irq_nop
    .word irq_nop
    .word irq_rx_char_available
    .word irq_rx_special_condition
    .assert (sio_int_vec & %1111) == 0

    .org $0066
nmi:
    retn



irq_ctc_ch0:
    push    bc
    ld      bc, (time)
    inc     bc
    ld      (time), bc
    pop     bc
    ei
    reti

irq_nop:
    ei
    reti

irq_rx_char_available:
    push    bc
    push    de
    push    hl
    push    af

    call    lcd_reset_cursor
    ld      hl, s_char_available
    call    lcd_print

    pop     af
    pop     hl
    pop     de
    pop     bc
    ei
    reti

irq_rx_special_condition:
    push    bc
    push    de
    push    hl
    push    af

    call    lcd_reset_cursor
    ld      hl, s_special_condition
    call    lcd_print

    pop     af
    pop     hl
    pop     de
    pop     bc
    ei
    reti

init:
    ld      sp, $FFFF

    ; init pio
    ld      a, %00001111        ; Output mode
    out     (PIO_CTRL_A), a

    ld      a, %01011100
    out     (PIO_DATA_A), a

    ; init ctc
    ld      a, lo(ctc_int_vec)
    out     (CTC_CH0), a

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

    ; Channel 1 produces the clock for the SIO
    ld      a, %00000111
    ;           ||||||||
    ;           |||||||+- is control word
    ;           ||||||+-- reset
    ;           |||||+--- time constant follows
    ;           ||||+---- automatic timer trigger
    ;           |||+----- clk/trg reacts to falling edge
    ;           ||+------ prescaler value 16
    ;           |+------- timer mode
    ;           +-------- disable interrupts
    out     (CTC_CH1), a
    ld      a, SIO_TIME_CONST
    out     (CTC_CH1), a

    ; init lcd
    ld      a, LCD_INSTR_CLEAR
    call    lcd_send_instr
    ld      a, %00001111
    call    lcd_send_instr

    ld      hl, s_hello
    call    lcd_print

    ; init sio
    ; channel a
    ld      a, $30              ; select WR0, error reset
    out     (SIO_CTRL_A), a
    ld      a, %00011000        ; channel reset
    out     (SIO_CTRL_A), a

    ld      a, $04              ; select WR4
    out     (SIO_CTRL_A), a
    ld      a, %01000100
    ;           |||||| |
    ;           |||||| +- no parity
    ;           ||||++--- 1-bit stop
    ;           ||++----- 8-bit sync character
    ;           ++------- x16 clock mode
    out     (SIO_CTRL_A), a

    ld      a, $05              ; select WR5
    out     (SIO_CTRL_A), a
    ld      a, %11101000
    ;           ||||||||
    ;           |||||||+- tx crc disable
    ;           ||||||+-- rts inactive
    ;           |||||+--- tx sdlc/crc-16 disable
    ;           ||||+---- tx enable
    ;           |||+----- no break
    ;           |++------ 8 bits per char
    ;           +-------- dtr inactive
    out     (SIO_CTRL_A), a

    ; channel b
    ld      a, $01              ; select WR1
    out     (SIO_CTRL_B), a
    ld      a, %00000100
    ;           ||||||||
    ;           |||||||+- ext int disable
    ;           ||||||+-- tx int disable
    ;           |||||+--- status affects vector
    ;           |||++---- rx int disable
    ;           ||+------ no wait/ready on r/t
    ;           |+------- no wait/ready function
    ;           +-------- wait/ready disable
    out     (SIO_CTRL_B), a

    ld      a, $02              ; select WR2
    out     (SIO_CTRL_B), a
    ld      a, lo(sio_int_vec)  ; interrupt vector
    out     (SIO_CTRL_B), a

    ld      a, $01              ; select WR1
    out     (SIO_CTRL_A), a
    ld      a, %00011000
    ;           ||||||||
    ;           |||||||+- ext int disable
    ;           ||||||+-- tx int disable
    ;           |||||+--- status affects vector
    ;           |||++---- int on all rx characters
    ;           ||+------ no wait/ready on r/t
    ;           |+------- no wait/ready function
    ;           +-------- wait/ready disable
    out     (SIO_CTRL_A), a

    ld      a, $03              ; select WR3
    out     (SIO_CTRL_A), a
    ld      a, %11000001
    ;           ||||||||
    ;           |||||||+- rx enable
    ;           ||||||+-- no sync char load inhibit
    ;           |||||+--- no sdlc (?)
    ;           ||||+---- rx crc disable
    ;           |||+----- no hunt phase
    ;           ||+------ no auto enables
    ;           ++------- rx 8 bits per char
    out     (SIO_CTRL_A), a

    ; init data
    ld      hl, $0000
    ld      (time), hl
    ld      (counter), hl

    ld      a, $00
    ld      i, a
    im      2
    ei

_loop:
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
    call    delay

    jr      _loop

; hl: u16 lhs
; bc: u16 rhs
; returns:
;   c: lhs < rhs
;   z: lhs == rhs
u16_cmp:
    ld      a, h
    cp      b       ; c = (h < b), z = (h == b)
    ret     nz
    ld      a, l
    cp      c       ; c = (l < c), z = (l == c)
    ret

; hl: u16 a
; d: u8 d
; returns:
;   hl: quotient
;   a:  remainder
div:
    xor     a
    ld      b, 16
_div_loop:
    add     hl, hl
    rla
    cp      d
    jr      c, _skip_add
    sub     d
    inc     l
_skip_add:
    djnz    _div_loop
    ret


; do NOT use with interrupts disable, will enable them.
; =====================
; hl: u16 ms
; ================ ====
; u16 start = *time:
; u16 end = start + ms;
; if (end < start)
;   while (*time > start) {}
; while (*time < end) {}
delay:
    ld      bc, (time) ; bc: start = *time
    add     hl, bc
    ld      de, hl     ; de: end = start + ms

    ; if (start <= end) goto _skip_wrap_around
    ; if (bc <= de)     goto _skip_wrap_around
    push    bc
    ld      hl, bc
    ld      bc, de
    call    u16_cmp
    pop     bc
    jr      c, _skip_wrap_around
    jr      z, _skip_wrap_around

_wrap_around:
    ld      hl, bc          ; hl: start
_wrap_loop:
    ld      bc, (time)      ; bc: *time

    ; if (start < *time) goto _wrap_loop
    ; if (hl < bc)       goto _wrap_loop
    call    u16_cmp
    jr      c, _wrap_loop
    jr      z, _wrap_loop
_skip_wrap_around:

    ld      hl, de          ; hl: end
_delay_loop:
    ld      bc, (time)

    ; if (end <= *time) ret
    ; if (hl <= bc)     ret
    call    u16_cmp
    ret     c
    ret     z
    jr      _delay_loop

lcd_wait:
    in      a, (LCD_CTRL) 
    and     $80
    ret     z
    jr      lcd_wait

; a: u8 instr
lcd_send_instr:
    ld      b, a
    call    lcd_wait
    ld      a, b
    out     (LCD_CTRL), a
    ret


; a: char c
lcd_print_char:
    ld      b, a
    call    lcd_wait
    ld      a, b
    out     (LCD_DATA), a
    ret

lcd_reset_cursor:
    ld      a, LCD_INSTR_SET_DDRAM | $00
    jp      lcd_send_instr

; hl: char *str
lcd_print:
    ld      a, (hl)
    or      a
    ret     z

    call    lcd_print_char
    inc     hl
    jr      lcd_print

; a: u8 digit
digit_to_hex:
    add     '0'
    cp      '9'+1
    ret     c
    add     'A'-'0'-10
    ret

; hl: num
; returns:
;  hl (char *): beginning of the string
num_to_str_dec:
    push    hl              ; (sp): u16 num
    ld      hl, str_buf+5   ; hl:   char *out = end of str_buf
    ld      (hl), 0

    ex      (sp), hl        ; hl: num, (sp): out
    ld      d, 10
_num_to_str_loop:
    call    div
    ex      (sp), hl        ; hl: out, (sp): num

    add     '0'
    dec     hl
    ld      (hl), a

    ex      (sp), hl        ; hl: num, (sp): out
    ld      a, h
    or      l
    jr     nz, _num_to_str_loop

    pop     hl              ; hl: out
    ret


; a: u8 digit
lcd_print_hex:
    ld      c, a

    srl     a
    srl     a
    srl     a
    srl     a
    call    digit_to_hex
    call    lcd_print_char

    ld      a, c
    and     $0F
    call    digit_to_hex
    call    lcd_print_char
    ret


; hl: u16 num
lcd_print_dec:
    call    num_to_str_dec
    jp      lcd_print

print_counter:
    call    lcd_reset_cursor

    ld      hl, s_clear
    call    lcd_print

    call    lcd_reset_cursor

    ld      hl, s_count
    call    lcd_print

    ld      hl, (counter)
    jp      lcd_print_dec


#code _DATA, *, *

s_hello:
    .asciz "Hello, world!"

s_count:
    .asciz "Count: "

s_special_condition:
    .asciz "Special!"

s_char_available:
    .asciz "Char available!"


s_clear:
    .asciz "                "


