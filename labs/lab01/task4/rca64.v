// rca64.v
// A plain 64-bit ripple-carry adder, chaining 64 FA_Gate instances (the
// delay-annotated version carried forward from Task 2).
//
// TODO: instantiate 64 FA_Gate modules, chained exactly like Task 2/3's
// 4-bit ripple adder, just 64 bits wide. This is very repetitive -- a
// generate-for loop is a reasonable way to write this one, since every
// stage is structurally identical, e.g.:
//
//   wire [64:0] c;
//   assign c[0] = cin;
//   genvar i;
//   generate
//     for (i = 0; i < 64; i = i + 1) begin : gen_fa
//       FA_Gate FA (.a(a[i]), .b(b[i]), .cin(c[i]), .sum(sum[i]), .cout(c[i+1]));
//     end
//   endgenerate
//   assign cout = c[64];

module rca64(
  input  [63:0] a,
  input  [63:0] b,
  input         cin,
  output [63:0] sum,
  output        cout
);

  // carry[k] is the carry going INTO bit k, so carry[0] is the external
  // carry-in and carry[64] is the carry-out of the whole adder.
  wire [64:0] carry;

  assign carry[0] = cin;

  // Every stage is structurally identical here -- unlike the flat CLA's
  // carry equations -- so one generate-for loop covers all 64 of them.
  // k is a genvar: it only exists at elaboration time, and leaves no
  // signal of its own behind in the circuit.
  genvar k;
  generate
    for (k = 0; k < 64; k = k + 1) begin : fa_chain
      FA_Gate FA (
        .a    (a[k]),
        .b    (b[k]),
        .cin  (carry[k]),
        .sum  (sum[k]),
        .cout (carry[k+1])
      );
    end
  endgenerate

  assign cout = carry[64];

endmodule
