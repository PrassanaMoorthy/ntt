#!/usr/bin/env python3
"""
Bit-accurate Python model of the KEM (algo_sel=0) forward NTT path,
mirroring addr_gen.v's index sequence and bff_unit.v's arithmetic
exactly. Run this in the same directory as your .hex/.mem files:

    python3 verify_ntt.py

It will tell you whether the *algorithm* (given your actual twiddle
table and input data) produces ntt_expected.hex, ntt_din-derived
"Got"-matching output, or neither -- which pinpoints whether the bug
is in the RTL, or in how the test vectors / twiddle table were
generated.
"""

Q = 3329

def read_hex_file(path, width_hex_digits=None):
    vals = []
    with open(path) as f:
        for line in f:
            line = line.split('//')[0].strip()
            if not line:
                continue
            vals.append(int(line, 16))
    return vals

def addr_gen_sequence(stop=2):
    """Mirrors addr_gen.v exactly: yields (kidx, ja, jb) for every
    butterfly operation, in the order the RTL issues them."""
    length = 128
    kidx = 1
    start_g = 0
    j = 0
    seq = []
    while True:
        ja = j
        jb = j + length
        seq.append((kidx, ja, jb))
        if j + 1 < start_g + length:
            j = j + 1
        else:
            kidx = kidx + 1
            if start_g + (length << 1) < 256:
                # Verilog: both start_g and j are nonblocking (<=) assignments
                # evaluated from the SAME old start_g value in parallel -- NOT
                # sequential. Must compute once and assign to both.
                new_start_g = start_g + (length << 1)
                start_g = new_start_g
                j = new_start_g
            elif (length >> 1) >= stop:
                length = length >> 1
                start_g = 0
                j = 0
            else:
                break  # done
    return seq

def butterfly(a, b, w):
    """Mirrors bff_unit.v exactly (KEM modulus)."""
    t = (w * b) % Q
    sum_a = a + t
    sum_b = a + Q - t
    return sum_a % Q, sum_b % Q

def main():
    din = read_hex_file("ntt_din.hex")
    expected = read_hex_file("ntt_expected.hex")
    zetas = read_hex_file("twiddle_kem.mem")  # 128 entries, index = kidx

    assert len(din) == 256, f"ntt_din.hex has {len(din)} entries, expected 256"
    assert len(expected) == 256, f"ntt_expected.hex has {len(expected)} entries, expected 256"
    print(f"Loaded {len(din)} din, {len(expected)} expected, {len(zetas)} zetas")

    seq = addr_gen_sequence(stop=2)
    n_blocks = len(set(k for k, ja, jb in seq))
    print(f"addr_gen produced {len(seq)} butterfly ops across {n_blocks} distinct kidx blocks")
    print("(expect 896 ops = 7 stages x 128 ops/stage; 127 distinct kidx values)")

    mem = din[:]  # in-place, like the RTL's RAM
    for kidx, ja, jb in seq:
        w = zetas[kidx] if kidx < len(zetas) else 0
        a, b = mem[ja], mem[jb]
        a_out, b_out = butterfly(a, b, w)
        mem[ja], mem[jb] = a_out, b_out

    mismatches_vs_expected = sum(1 for i in range(256) if mem[i] != expected[i])
    print(f"\nModel vs ntt_expected.hex: {256-mismatches_vs_expected}/256 match")

    if mismatches_vs_expected == 0:
        print(">>> Model MATCHES expected output exactly.")
        print(">>> This means the algorithm/twiddle table/input data are all")
        print(">>> self-consistent and correct -- the bug is specifically in")
        print(">>> the RTL's implementation (some signal/timing issue), NOT")
        print(">>> in the test vectors themselves. Compare this script's")
        print(">>> intermediate values against RTL waveforms stage-by-stage.")
    else:
        print(">>> Model does NOT match ntt_expected.hex.")
        print(">>> This means ntt_expected.hex was NOT generated using this")
        print(">>> exact zeta ordering / domain / algorithm from twiddle_kem.mem")
        print(">>> + ntt_din.hex. Check how ntt_expected.hex was produced:")
        print(">>>   - Was it generated with a different zeta table/ordering")
        print(">>>     (e.g. bit-reversed differently, or Montgomery-domain)?")
        print(">>>   - Off-by-one on kidx (0-indexed vs 1-indexed zetas)?")
        print(">>>   - Different q, or output ordering (NTT vs INTT)?")
        print("\nFirst 8 mismatches (model vs expected):")
        shown = 0
        for i in range(256):
            if mem[i] != expected[i] and shown < 8:
                print(f"  addr {i}: model={mem[i]:#05x} expected={expected[i]:#05x}")
                shown += 1

    print("\nFirst 8 model outputs (for comparison with your 'Got' column):")
    for i in range(8):
        print(f"  addr {i}: model={mem[i]:#05x}")

if __name__ == "__main__":
    main()
