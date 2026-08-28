"""helpers.py -- small code generators used while writing this task.

Nothing here is compiled or simulated; these are throwaway scripts that
print Verilog to stdout, which then gets pasted into the .v files and
checked by hand. Two things are generated:

  * the 64 flat carry equations for cla64_flat.v, where every carry needs
    one more product term than the one before it, and
  * the 16 chained cla4 instances for cla64_blocked.v, which are uniform
    but tediously long to type out.

Run with e.g.:  python3 helpers.py flat
"""

import sys

WIDTH = 96          # wrap column for the generated assign statements
DELAY = "#(2)"      # same gate delay convention as the rest of the lab
NBITS = 64
BLOCK = 4           # bits per cla4 block


def carry_terms(k):
    """Product terms of carry c[k], k = 1..NBITS, highest g first.

    c[k] = g[k-1]
         + p[k-1].g[k-2]
         + ...
         + p[k-1]...p[0].cin
    """
    terms = []
    for j in range(k - 1, -1, -1):
        factors = [f"p[{i}]" for i in range(k - 1, j, -1)]
        factors.append(f"g[{j}]")
        terms.append(" & ".join(factors))
    tail = [f"p[{i}]" for i in range(k - 1, -1, -1)] + ["cin"]
    terms.append(" & ".join(tail))
    return terms


def flat():
    """Print the 64 carry assigns for cla64_flat.v.

    Long equations are folded onto continuation lines, but never in the
    middle of a product term -- every break lands on a `|`, so the file
    stays checkable against a hand derivation.
    """
    for k in range(1, NBITS + 1):
        head, *rest = carry_terms(k)
        lead = f"  assign {DELAY} c[{k}] = "
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
    print(f"  assign cout = c[{NBITS}];")


def blocked():
    """Print the 16 chained cla4 instances for cla64_blocked.v.

    Instance names and the inter-block carry vector follow the names the
    task asks for (block0..block15, c[1]..c[15]); the columns are padded
    so the carry chain reads straight down the page.
    """
    nblocks = NBITS // BLOCK
    for k in range(nblocks):
        hi, lo = BLOCK * k + BLOCK - 1, BLOCK * k
        rng = f"[{hi}:{lo}]"
        cin = "cin" if k == 0 else f"c[{k}]"
        cout = "cout" if k == nblocks - 1 else f"c[{k + 1}]"
        fields = [f".a(a{rng}),", f".b(b{rng}),", f".cin({cin}),",
                  f".sum(sum{rng}),", f".cout({cout}));"]
        widths = [13, 13, 12, 17, 0]
        row = " ".join(f.ljust(w) for f, w in zip(fields, widths))
        print(f"  cla4 block{k:<2} ({row.rstrip()}")


if __name__ == "__main__":
    {"flat": flat, "blocked": blocked}[sys.argv[1]]()
