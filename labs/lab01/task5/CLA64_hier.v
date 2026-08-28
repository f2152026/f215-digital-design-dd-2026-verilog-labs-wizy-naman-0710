// cla64_hier.v
// BONUS -- open-ended. No detailed scaffold is provided; this is meant to
// be a genuine design exercise. Not required for lab submission.
//
// You will likely need to modify cla4.v (or add signals alongside it) so
// that block-generate/block-propagate summaries of its own Gi, Pi signals
// are exposed as outputs, since the second-level lookahead unit below
// needs them. As with every module in this lab from Task 2 onward, every
// gate/assign you add should carry an explicit delay.
//
// Starting point (from Tutorial 3, Q4(d)):
//   - Reuse 16 four-bit CLA blocks (your cla4.v) -- their internal logic
//     doesn't change.
//   - For each block k, define:
//       Gblk_k = "this block produces a carry regardless of its incoming
//                 carry" -- a Boolean function of that block's own 4
//                 bit-level Gi, Pi signals.
//       Pblk_k = "an incoming carry sails straight through this whole
//                 block" -- likewise a function of its own Gi, Pi.
//   - Build a second-level lookahead unit -- structurally identical to
//     cla4.v, just one level up -- that computes each block's carry-in
//     directly from Gblk_0..Gblk_15, Pblk_0..Pblk_15, and cin, instead of
//     rippling block to block.
//
// To test this, wire it into dut.v as a fourth option (copy the pattern
// used for the other three) and run it through the same tb.v. Compare
// your final delay to cla64_blocked.v from Task 4.
//
// ---------------------------------------------------------------------
// How this implementation is put together
// ---------------------------------------------------------------------
// Rather than adding Gblk/Pblk output ports to cla4.v (which would mean
// touching a file three earlier tasks depend on), this module recomputes
// the bit-level p and g itself and summarises them per block. The cla4
// blocks below are then instantiated completely unmodified -- their
// carry-outs are simply left dangling, because every block's carry-IN
// now arrives from the second-level lookahead instead of from the block
// beneath it.
//
// Three layers, each with its own comment block below:
//   1. bit-level p[i], g[i]                     -- uniform, generate loop
//   2. block-level Pblk[k], Gblk[k]             -- uniform, generate loop
//   3. second-level carries Cblk[1..16]         -- NOT uniform, generated
//                                                  by helpers.py
// Depth is what matters here: carry-out no longer waits on 15 block hops
// (Task 4(b)) but on one block summary plus one lookahead level, so the
// chain grows with log of the width rather than with the width itself.

module cla64_hier(
  input  [63:0] a,
  input  [63:0] b,
  input         cin,
  output [63:0] sum,
  output        cout
);

  wire [63:0] p, g;          // bit-level propagate / generate
  wire [15:0] Pblk, Gblk;    // per-block summaries of the above
  wire [16:1] Cblk;          // carry INTO block k; Cblk[16] is the carry-out
  wire [15:0] blk_cout;      // each block's own carry-out -- deliberately unused

  // ---------------------------------------------------------------------
  // Layer 1: bit-level propagate and generate.
  // Identical operation at all 64 positions, so a generate-for loop is
  // the right tool -- same reasoning as cla64_flat.v's worked example.
  // ---------------------------------------------------------------------
  genvar i;
  generate
    for (i = 0; i < 64; i = i + 1) begin : gen_pg
      xor #(2) (p[i], a[i], b[i]);
      and #(2) (g[i], a[i], b[i]);
    end
  endgenerate

  // ---------------------------------------------------------------------
  // Layer 2: block-level propagate and generate, for the four bits of
  // block k (bits 4k .. 4k+3).
  //
  //   Pblk[k] = p[4k+3].p[4k+2].p[4k+1].p[4k]
  //             -- a carry entering this block leaves it again unchanged.
  //
  //   Gblk[k] = g[4k+3] + p[4k+3].g[4k+2] + p[4k+3].p[4k+2].g[4k+1]
  //                     + p[4k+3].p[4k+2].p[4k+1].g[4k]
  //             -- the block emits a carry on its own, whatever came in.
  //             This is just cla4.v's c4 equation with the cin term
  //             dropped, which is exactly what "regardless of the
  //             incoming carry" means.
  //
  // Every block computes these the same way, so this is a generate loop
  // too -- 16 identical copies, four literals wide at worst.
  // ---------------------------------------------------------------------
  genvar k;
  generate
    for (k = 0; k < 16; k = k + 1) begin : gen_blk_pg
      assign #(2) Pblk[k] = p[4*k+3] & p[4*k+2] & p[4*k+1] & p[4*k];
      assign #(2) Gblk[k] = g[4*k+3]
                          | (p[4*k+3] & g[4*k+2])
                          | (p[4*k+3] & p[4*k+2] & g[4*k+1])
                          | (p[4*k+3] & p[4*k+2] & p[4*k+1] & g[4*k]);
    end
  endgenerate

  // ---------------------------------------------------------------------
  // Layer 3: the second-level lookahead unit.
  // Same shape as cla4.v's carry equations, one level up: Pblk/Gblk stand
  // in for p/g, and a "position" is now a whole 4-bit block. Cblk[k] is
  // the carry-in of block k, produced directly from cin and the block
  // summaries -- no block ever waits on the block below it.
  //
  // Not uniform (Cblk[k] needs k+1 terms), so these 16 lines come from
  // helpers.py (`python3 helpers.py carries`). Checked by hand the same
  // way as Task 4: Cblk[1]..Cblk[4] are cla4.v's c1..c4 with p/g renamed,
  // and Cblk[16] was re-derived from Cblk[16] = Gblk[15] + Pblk[15].Cblk[15]
  // expanded down to cin -- 16 Gblk terms plus the all-propagate term.
  // ---------------------------------------------------------------------
  assign #(2) Cblk[1] = Gblk[0] | (Pblk[0] & cin);
  assign #(2) Cblk[2] = Gblk[1] | (Pblk[1] & Gblk[0]) | (Pblk[1] & Pblk[0] & cin);
  assign #(2) Cblk[3] = Gblk[2] | (Pblk[2] & Gblk[1]) | (Pblk[2] & Pblk[1] & Gblk[0])
                        | (Pblk[2] & Pblk[1] & Pblk[0] & cin);
  assign #(2) Cblk[4] = Gblk[3] | (Pblk[3] & Gblk[2]) | (Pblk[3] & Pblk[2] & Gblk[1])
                        | (Pblk[3] & Pblk[2] & Pblk[1] & Gblk[0])
                        | (Pblk[3] & Pblk[2] & Pblk[1] & Pblk[0] & cin);
  assign #(2) Cblk[5] = Gblk[4] | (Pblk[4] & Gblk[3]) | (Pblk[4] & Pblk[3] & Gblk[2])
                        | (Pblk[4] & Pblk[3] & Pblk[2] & Gblk[1])
                        | (Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Gblk[0])
                        | (Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Pblk[0] & cin);
  assign #(2) Cblk[6] = Gblk[5] | (Pblk[5] & Gblk[4]) | (Pblk[5] & Pblk[4] & Gblk[3])
                        | (Pblk[5] & Pblk[4] & Pblk[3] & Gblk[2])
                        | (Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Gblk[1])
                        | (Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Gblk[0])
                        | (Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Pblk[0] & cin);
  assign #(2) Cblk[7] = Gblk[6] | (Pblk[6] & Gblk[5]) | (Pblk[6] & Pblk[5] & Gblk[4])
                        | (Pblk[6] & Pblk[5] & Pblk[4] & Gblk[3])
                        | (Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Gblk[2])
                        | (Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Gblk[1])
                        | (Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Gblk[0])
                        | (Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Pblk[0] & cin);
  assign #(2) Cblk[8] = Gblk[7] | (Pblk[7] & Gblk[6]) | (Pblk[7] & Pblk[6] & Gblk[5])
                        | (Pblk[7] & Pblk[6] & Pblk[5] & Gblk[4])
                        | (Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Gblk[3])
                        | (Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Gblk[2])
                        | (Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Gblk[1])
                        | (Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Gblk[0])
                        | (Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Pblk[0] & cin);
  assign #(2) Cblk[9] = Gblk[8] | (Pblk[8] & Gblk[7]) | (Pblk[8] & Pblk[7] & Gblk[6])
                        | (Pblk[8] & Pblk[7] & Pblk[6] & Gblk[5])
                        | (Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Gblk[4])
                        | (Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Gblk[3])
                        | (Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Gblk[2])
                        | (Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Gblk[1])
                        | (Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Gblk[0])
                        | (Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Pblk[0] & cin);
  assign #(2) Cblk[10] = Gblk[9] | (Pblk[9] & Gblk[8]) | (Pblk[9] & Pblk[8] & Gblk[7])
                         | (Pblk[9] & Pblk[8] & Pblk[7] & Gblk[6])
                         | (Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Gblk[5])
                         | (Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Gblk[4])
                         | (Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Gblk[3])
                         | (Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Gblk[2])
                         | (Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Gblk[1])
                         | (Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Gblk[0])
                         | (Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Pblk[0] & cin);
  assign #(2) Cblk[11] = Gblk[10] | (Pblk[10] & Gblk[9]) | (Pblk[10] & Pblk[9] & Gblk[8])
                         | (Pblk[10] & Pblk[9] & Pblk[8] & Gblk[7])
                         | (Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Gblk[6])
                         | (Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Gblk[5])
                         | (Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Gblk[4])
                         | (Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Gblk[3])
                         | (Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Gblk[2])
                         | (Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Gblk[1])
                         | (Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Gblk[0])
                         | (Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Pblk[0] & cin);
  assign #(2) Cblk[12] = Gblk[11] | (Pblk[11] & Gblk[10]) | (Pblk[11] & Pblk[10] & Gblk[9])
                         | (Pblk[11] & Pblk[10] & Pblk[9] & Gblk[8])
                         | (Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Gblk[7])
                         | (Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Gblk[6])
                         | (Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Gblk[5])
                         | (Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Gblk[4])
                         | (Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Gblk[3])
                         | (Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Gblk[2])
                         | (Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Gblk[1])
                         | (Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Gblk[0])
                         | (Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Pblk[0] & cin);
  assign #(2) Cblk[13] = Gblk[12] | (Pblk[12] & Gblk[11]) | (Pblk[12] & Pblk[11] & Gblk[10])
                         | (Pblk[12] & Pblk[11] & Pblk[10] & Gblk[9])
                         | (Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Gblk[8])
                         | (Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Gblk[7])
                         | (Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Gblk[6])
                         | (Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Gblk[5])
                         | (Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Gblk[4])
                         | (Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Gblk[3])
                         | (Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Gblk[2])
                         | (Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Gblk[1])
                         | (Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Gblk[0])
                         | (Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Pblk[0] & cin);
  assign #(2) Cblk[14] = Gblk[13] | (Pblk[13] & Gblk[12]) | (Pblk[13] & Pblk[12] & Gblk[11])
                         | (Pblk[13] & Pblk[12] & Pblk[11] & Gblk[10])
                         | (Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Gblk[9])
                         | (Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Gblk[8])
                         | (Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Gblk[7])
                         | (Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Gblk[6])
                         | (Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Gblk[5])
                         | (Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Gblk[4])
                         | (Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Gblk[3])
                         | (Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Gblk[2])
                         | (Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Gblk[1])
                         | (Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Gblk[0])
                         | (Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Pblk[0] & cin);
  assign #(2) Cblk[15] = Gblk[14] | (Pblk[14] & Gblk[13]) | (Pblk[14] & Pblk[13] & Gblk[12])
                         | (Pblk[14] & Pblk[13] & Pblk[12] & Gblk[11])
                         | (Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Gblk[10])
                         | (Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Gblk[9])
                         | (Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Gblk[8])
                         | (Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Gblk[7])
                         | (Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Gblk[6])
                         | (Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Gblk[5])
                         | (Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Gblk[4])
                         | (Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Gblk[3])
                         | (Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Gblk[2])
                         | (Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Gblk[1])
                         | (Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Gblk[0])
                         | (Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Pblk[0] & cin);
  assign #(2) Cblk[16] = Gblk[15] | (Pblk[15] & Gblk[14]) | (Pblk[15] & Pblk[14] & Gblk[13])
                         | (Pblk[15] & Pblk[14] & Pblk[13] & Gblk[12])
                         | (Pblk[15] & Pblk[14] & Pblk[13] & Pblk[12] & Gblk[11])
                         | (Pblk[15] & Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Gblk[10])
                         | (Pblk[15] & Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Gblk[9])
                         | (Pblk[15] & Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Gblk[8])
                         | (Pblk[15] & Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Gblk[7])
                         | (Pblk[15] & Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Gblk[6])
                         | (Pblk[15] & Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Gblk[5])
                         | (Pblk[15] & Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Gblk[4])
                         | (Pblk[15] & Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Gblk[3])
                         | (Pblk[15] & Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Gblk[2])
                         | (Pblk[15] & Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Gblk[1])
                         | (Pblk[15] & Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Gblk[0])
                         | (Pblk[15] & Pblk[14] & Pblk[13] & Pblk[12] & Pblk[11] & Pblk[10] & Pblk[9] & Pblk[8] & Pblk[7] & Pblk[6] & Pblk[5] & Pblk[4] & Pblk[3] & Pblk[2] & Pblk[1] & Pblk[0] & cin);

  assign cout = Cblk[16];

  // ---------------------------------------------------------------------
  // The 16 first-level blocks, instantiated straight from Task 4's cla4.v
  // with no changes at all. Each takes its carry-in from layer 3; the
  // .cout connections go to blk_cout and are never read, since the real
  // carry-out of the adder is Cblk[16] above.
  // ---------------------------------------------------------------------
  cla4 block0  (.a(a[3:0]),   .b(b[3:0]),   .cin(cin),       .sum(sum[3:0]),   .cout(blk_cout[0]));
  cla4 block1  (.a(a[7:4]),   .b(b[7:4]),   .cin(Cblk[1]),   .sum(sum[7:4]),   .cout(blk_cout[1]));
  cla4 block2  (.a(a[11:8]),  .b(b[11:8]),  .cin(Cblk[2]),   .sum(sum[11:8]),  .cout(blk_cout[2]));
  cla4 block3  (.a(a[15:12]), .b(b[15:12]), .cin(Cblk[3]),   .sum(sum[15:12]), .cout(blk_cout[3]));
  cla4 block4  (.a(a[19:16]), .b(b[19:16]), .cin(Cblk[4]),   .sum(sum[19:16]), .cout(blk_cout[4]));
  cla4 block5  (.a(a[23:20]), .b(b[23:20]), .cin(Cblk[5]),   .sum(sum[23:20]), .cout(blk_cout[5]));
  cla4 block6  (.a(a[27:24]), .b(b[27:24]), .cin(Cblk[6]),   .sum(sum[27:24]), .cout(blk_cout[6]));
  cla4 block7  (.a(a[31:28]), .b(b[31:28]), .cin(Cblk[7]),   .sum(sum[31:28]), .cout(blk_cout[7]));
  cla4 block8  (.a(a[35:32]), .b(b[35:32]), .cin(Cblk[8]),   .sum(sum[35:32]), .cout(blk_cout[8]));
  cla4 block9  (.a(a[39:36]), .b(b[39:36]), .cin(Cblk[9]),   .sum(sum[39:36]), .cout(blk_cout[9]));
  cla4 block10 (.a(a[43:40]), .b(b[43:40]), .cin(Cblk[10]),  .sum(sum[43:40]), .cout(blk_cout[10]));
  cla4 block11 (.a(a[47:44]), .b(b[47:44]), .cin(Cblk[11]),  .sum(sum[47:44]), .cout(blk_cout[11]));
  cla4 block12 (.a(a[51:48]), .b(b[51:48]), .cin(Cblk[12]),  .sum(sum[51:48]), .cout(blk_cout[12]));
  cla4 block13 (.a(a[55:52]), .b(b[55:52]), .cin(Cblk[13]),  .sum(sum[55:52]), .cout(blk_cout[13]));
  cla4 block14 (.a(a[59:56]), .b(b[59:56]), .cin(Cblk[14]),  .sum(sum[59:56]), .cout(blk_cout[14]));
  cla4 block15 (.a(a[63:60]), .b(b[63:60]), .cin(Cblk[15]),  .sum(sum[63:60]), .cout(blk_cout[15]));

endmodule
