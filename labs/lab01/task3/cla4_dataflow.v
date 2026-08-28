// cla4_dataflow.v
// The same 4-bit CLA as cla4.v, rewritten using dataflow modeling
// (continuous `assign` statements) instead of gate primitives. Compare
// the line count and readability of this file to cla4.v.
//
// TODO: add a delay to every assign statement (e.g. assign #(2) ...) --
// same default-delay expectation as everywhere else from Task 2 onward.
//   assign #(2) p = a ^ b;
//   assign #(2) g = a & b;
//   assign #(2) c1   = g[0] | (p[0] & cin);
//   assign #(2) c2   = g[1] | (p[1] & g[0]) | (p[1] & p[0] & cin);
//   assign #(2) c3   = ... (same pattern, one more term)
//   assign #(2) cout = ... (same pattern, one more term)
//   assign #(2) sum  = p ^ {c3, c2, c1, cin};

module cla4_dataflow(
  input  [3:0] a,
  input  [3:0] b,
  input        cin,
  output [3:0] sum,
  output       cout
);

  wire [3:0] p, g;
  wire c1, c2, c3;

  // Step 1 -- both four-bit p/g vectors in two lines, where the gate-level
  // version needed eight separate primitives.
  assign #(2) p = a ^ b;
  assign #(2) g = a & b;

  // Step 2 -- the same four carry equations as cla4.v, one assign each.
  // Every product term below corresponds one-for-one with a multi-input
  // AND gate in cla4.v, and every `|` with one input of that carry's OR.
  assign #(2) c1 = g[0]
                 | (p[0] & cin);

  assign #(2) c2 = g[1]
                 | (p[1] & g[0])
                 | (p[1] & p[0] & cin);

  assign #(2) c3 = g[2]
                 | (p[2] & g[1])
                 | (p[2] & p[1] & g[0])
                 | (p[2] & p[1] & p[0] & cin);

  assign #(2) cout = g[3]
                   | (p[3] & g[2])
                   | (p[3] & p[2] & g[1])
                   | (p[3] & p[2] & p[1] & g[0])
                   | (p[3] & p[2] & p[1] & p[0] & cin);

  // Step 3 -- all four sum bits at once: {c3,c2,c1,cin} is the carry
  // INTO each bit position, so this single line replaces four xor gates.
  assign #(2) sum = p ^ {c3, c2, c1, cin};

endmodule
