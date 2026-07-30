from dataclasses import dataclass

freq = 4_000_000
phi = 1 / freq

bauds = [
    1200,
    2400,
    4800,
    9600,
    15625,  # made it the fuck up
    19200,
    38400,
    57600,
    115200,
]

# multiplier of 1 does not work in asynchronous mode
multipliers = [16, 32, 64]


def frac(x: float) -> float:
    return x - int(x)


#    phi * 16 * c = 1 / (m * b)
# => c = 1 / (phi * 16 * m * b)


def c(m: int, b: int):
    return 1 / (phi * 16 * m * b)


def f(c: int, m: int, b: int):
    return phi * 16 * c * m * b


@dataclass
class Combination:
    b: int
    m: int
    c: int

    def error(self):
        return abs(f(round(self.c), self.m, self.b) - 1)


combs = [
    Combination(b, m, round(c(m, b)))
    for b in bauds
    for m in multipliers
    if round(c(m, b)) != 0
]
combs.sort(key=Combination.error)

for comb in combs:
    print(
        f"b = {comb.b:6}, m = {comb.m:2} -> c = {comb.c:3}, b' = {round(1 / (phi * 16 * comb.c* comb.m)):5}, err = {round(100 * comb.error(), 2):5}%"
    )
