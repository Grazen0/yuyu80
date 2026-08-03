    .ifndef RANDOM_INC
    .define RANDOM_INC

    resb    r_seed, 2
    resb    r_incvalue, 1

    .endif
