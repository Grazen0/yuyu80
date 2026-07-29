    .ifndef SERIAL_INC
    .define SERIAL_INC

    .include "macros.inc"

    resb serial_rx_buffer, 64
    resb serial_rx_tail, 1
    resb serial_rx_head, 1

    ; assert that is power of 2
    .assert serial_rx_buffer_len != 0 && (serial_rx_buffer_len & (serial_rx_buffer_len - 1)) == 0

    ; if this condition is true, we don't need to carry index additions over to the high byte
    .assert low(serial_rx_buffer) + (serial_rx_buffer_len - 1) < $100

    .endif
