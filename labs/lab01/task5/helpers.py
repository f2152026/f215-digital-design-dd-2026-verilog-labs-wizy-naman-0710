"""helpers.py -- generators for the bonus hierarchical adder.

Same idea as Task 4's helpers.py: print Verilog to stdout, paste it into
cla64_hier.v, then check it by hand. Only the second-level carry
equations and the 16 block instances are generated here -- the bit-level
p/g and the block-level Pblk/Gblk are uniform across all positions, so
they are written as generate-for loops in the .v file instead.

Run with e.g.:  python3 helpers.py carries
"""

import sys

WIDTH = 96
DELAY = "#(2)"
NBLK = 16


def block_carry_terms(k):
    """Product terms of Cblk[k], the carry INTO block k, k = 1..NBLK.

    Structurally identical to the 4-bit carry equations in cla4.v, one
    level up: Gblk/Pblk replace g/p, and a "bit" is now a whole 4-bit
    block.
    """
    terms = []
    for j in range(k - 1, -1, -1):
        factors = [f"Pblk[{i}]" for i in range(k - 1, j, -1)]
        factors.append(f"Gblk[{j}]")
        terms.append(" & ".join(factors))
    tail = [f"Pblk[{i}]" for i in range(k - 1, -1, -1)] + ["cin"]
    terms.append(" & ".join(tail))
    return terms


def carries():
    """Print the 16 second-level carry assigns."""
    for k in range(1, NBLK + 1):
        head, *rest = block_carry_terms(k)
        lead = f"  assign {DELAY} Cblk[{k}] = "
        pad = " " * len(lead)
        line, out = lead + head, []
        for term in rest:
            piece = f" | ({term})"
            if len(line) + len(piece) > WIDTH:
                out.append(line)
                line = pad + piece.lstrip()
            else:
                line += piece
        out.append(line + ";")
        print("\n".join(out))


def blocks():
    """Print the 16 cla4 instances, each fed directly by the lookahead."""
    for k in range(NBLK):
        hi, lo = 4 * k + 3, 4 * k
        rng = f"[{hi}:{lo}]"
        cin = "cin" if k == 0 else f"Cblk[{k}]"
        fields = [f".a(a{rng}),", f".b(b{rng}),", f".cin({cin}),",
                  f".sum(sum{rng}),", f".cout(blk_cout[{k}]));"]
        widths = [13, 13, 16, 17, 0]
        row = " ".join(f.ljust(w) for f, w in zip(fields, widths))
        print(f"  cla4 block{k:<2} ({row.rstrip()}")


if __name__ == "__main__":
    {"carries": carries, "blocks": blocks}[sys.argv[1]]()
