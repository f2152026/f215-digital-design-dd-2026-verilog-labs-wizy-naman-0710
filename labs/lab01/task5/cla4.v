// cla4.v
// (Carried forward from Task 4 -- unchanged. Here it is the first-level
// block of the hierarchical adder: its internal lookahead stays exactly
// as it was, only its carry-IN now comes from a second-level unit
// instead of from the block below it.)
//
// Gate-level 4-bit carry-lookahead adder, matching the lecture circuit.
// Every gate needs an explicit delay (constant is fine here, e.g. #(2)) --
// this is the default from Task 2 onward, not a special step.
//
// TODO -- Step 1: generate/propagate signals (one xor + one and per bit)
//   p[i] = a[i] ^ b[i]
//   g[i] = a[i] & b[i]
//
// TODO -- Step 2: direct (non-recursive) carry equations. Verilog's and/or
// primitives accept more than 2 inputs directly, e.g.:
//   and #(2) (t2, p1, p0, g0);
// so you do not need to manually chain 2-input gates.
//   c1 = g0 + p0.cin
//   c2 = g1 + p1.g0 + p1.p0.cin
//   c3 = g2 + p2.g1 + p2.p1.g0 + p2.p1.p0.cin
//   c4 = g3 + p3.g2 + p3.p2.g1 + p3.p2.p1.g0 + p3.p2.p1.p0.cin
//
// TODO -- Step 3: sum bits
//   sum[i] = p[i] ^ c[i]     (c0 = cin)

module cla4(
  input  [3:0] a,
  input  [3:0] b,
  input        cin,
  output [3:0] sum,
  output       cout
);

  wire [3:0] p, g;
  wire       c1, c2, c3;

  // Product terms feeding each carry. m<k>_<j> is the term of carry k
  // that picks up g[j], and m<k>_x is that carry's all-propagate term,
  // the one that lets cin travel the whole way. Each is a SINGLE
  // multi-input AND, not a chain of 2-input ANDs -- that is exactly what
  // makes the lookahead two levels deep no matter which carry you look at.
  wire m1_x;
  wire m2_0, m2_x;
  wire m3_1, m3_0, m3_x;
  wire m4_2, m4_1, m4_0, m4_x;

  // ---- Step 1: propagate / generate, one pair per bit ----
  xor #(2) (p[0], a[0], b[0]);
  xor #(2) (p[1], a[1], b[1]);
  xor #(2) (p[2], a[2], b[2]);
  xor #(2) (p[3], a[3], b[3]);

  and #(2) (g[0], a[0], b[0]);
  and #(2) (g[1], a[1], b[1]);
  and #(2) (g[2], a[2], b[2]);
  and #(2) (g[3], a[3], b[3]);

  // ---- Step 2: the four carries, each straight from its equation ----
  // c1 = g0 + p0.cin
  and #(2) (m1_x, p[0], cin);
  or  #(2) (c1,   g[0], m1_x);

  // c2 = g1 + p1.g0 + p1.p0.cin
  and #(2) (m2_0, p[1], g[0]);
  and #(2) (m2_x, p[1], p[0], cin);
  or  #(2) (c2,   g[1], m2_0, m2_x);

  // c3 = g2 + p2.g1 + p2.p1.g0 + p2.p1.p0.cin
  and #(2) (m3_1, p[2], g[1]);
  and #(2) (m3_0, p[2], p[1], g[0]);
  and #(2) (m3_x, p[2], p[1], p[0], cin);
  or  #(2) (c3,   g[2], m3_1, m3_0, m3_x);

  // c4 = g3 + p3.g2 + p3.p2.g1 + p3.p2.p1.g0 + p3.p2.p1.p0.cin
  and #(2) (m4_2, p[3], g[2]);
  and #(2) (m4_1, p[3], p[2], g[1]);
  and #(2) (m4_0, p[3], p[2], p[1], g[0]);
  and #(2) (m4_x, p[3], p[2], p[1], p[0], cin);
  or  #(2) (cout, g[3], m4_2, m4_1, m4_0, m4_x);

  // ---- Step 3: sum bits (c0 is cin) ----
  xor #(2) (sum[0], p[0], cin);
  xor #(2) (sum[1], p[1], c1);
  xor #(2) (sum[2], p[2], c2);
  xor #(2) (sum[3], p[3], c3);

endmodule
