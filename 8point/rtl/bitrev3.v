// ---------------------------------------------------------------------------
// bitrev3 - reverses a 3-bit address. The chosen algorithm (standard
// iterative radix-2 DIT: natural-order butterflies, natural-order output)
// requires the INPUT to be loaded in bit-reversed order. Putting that
// reversal here, on the load-address path, means the outside world can
// always present/read coefficients in plain natural index order.
// ---------------------------------------------------------------------------
module bitrev3 (
    input      [2:0] addr_in,
    output     [2:0] addr_out
);
    assign addr_out = {addr_in[0], addr_in[1], addr_in[2]};
endmodule
