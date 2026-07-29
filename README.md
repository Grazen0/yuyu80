# Z80 Toy

Code for playing around with a homemade Z80 computer.

## Hardware

![A picture of the Z80 computer on a breadboard](.github/breadboard.jpg)

TODO: add circuit schematic

## Memory map

### Memory space

|   Region    | Description |
| :---------: | :---------: |
| `0000-7FFF` |     ROM     |
| `8000-FFFF` |     RAM     |

### I/O space

| Region |  Description  |
| :----: | :-----------: |
|  `00`  |  LCD control  |
|  `01`  |   LCD data    |
|  `40`  |  PIO data A   |
|  `41`  | PIO control A |
|  `42`  |  PIO data B   |
|  `43`  | PIO control B |
|  `80`  | CTC channel 0 |
|  `81`  | CTC channel 1 |
|  `82`  | CTC channel 2 |
|  `83`  | CTC channel 3 |
|  `C0`  |  SIO data A   |
|  `C1`  | SIO control A |
|  `C2`  |  SIO data B   |
|  `C3`  | SIO control B |

Unspecified I/O addressed are mirrors.
