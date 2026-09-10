// ---------------------------------------------------------------------------
// twiddle_rom - stores w^0..w^3 mod Q, where w = 2580 is a primitive 8th
// root of unity mod Q=3329 (w = 17^32 mod 3329, since 17 is Kyber's
// primitive 256th root of unity: 17^(256/8) has order 8).
//
// A complete radix-2 DIT NTT of size 8 only ever needs w^0..w^3 (every
// butterfly across all 3 stages uses one of these four values), so a 4-entry
// ROM addressed by a 2-bit exponent is all that's required.
// ---------------------------------------------------------------------------
module twiddle_rom #(
    parameter Q  = 3329,
    parameter W  = 12,
    parameter TW = 2         // twiddle ROM address width -> 4 entries
) (
    input      [TW-1:0] addr,   // exponent e, twiddle = w^e
    output reg [W-1:0]  zeta
);
    always @(*) begin
        case (addr)
            2'd0: zeta = 12'd1;      // w^0
            2'd1: zeta = 12'd2580;   // w^1
            2'd2: zeta = 12'd1729;   // w^2
            2'd3: zeta = 12'd3289;   // w^3
        endcase
    end
endmodule
