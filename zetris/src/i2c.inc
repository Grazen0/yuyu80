    .ifndef I2C_INC
    .define I2C_INC

    .include "macros.inc"

    resb i2c_pio_mode, 1
    resb i2c_pio_io_conf, 1

    .endif
