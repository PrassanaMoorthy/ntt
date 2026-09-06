#!/usr/bin/env python3
"""
Golden-model generator for ntt_engine_fwd verification.

Implements the two standard forward NTTs the DUT's 8-bit address / 23-bit
data bus strongly suggests it targets:

  algo_sel=0 (KEM)  -> ML-KEM / Kyber:    q=3329,    n=256, INCOMPLETE NTT (7 stages, len 128..2)
  algo_sel=1 (DSA)  -> ML-DSA / Dilithium: q=8380417, n=256, COMPLETE NTT   (8 stages, len 128..1)

Both use the well-known reference merge structure:

    k = 1
    for len in stage_lengths:        # 128,64,...,2 (KEM) or 128,64,...,1 (DSA)
        for start in range(0, 256, 2*len):
            zeta = zetas[k]; k += 1
            for j in range(start, start+len):
                t = (zeta * r[j+len]) % q
                r[j+len] = (r[j] - t) % q
                r[j]     = (r[j] + t) % q

This also generates the (ja, jb, kidx) address-stream that a matching
ntt_addr_gen must produce, and the (kidx -> zeta) table twiddle_rom must
serve, so the stub RTL and the testbench agree on ordering.

Outputs (all hex, one value per line, matching wr_data / expected rd_data widths):
  input_kem.hex, expected_kem.hex
  input_dsa.hex, expected_dsa.hex
  addr_stream_kem.txt, addr_stream_dsa.txt   (ja jb kidx per line, for reference/debug)
"""
import random

random.seed(1234)

N = 256

# ---------------- Kyber / ML-KEM ----------------
Q_KEM = 3329
ZETA_KEM = 17  # primitive 256th root of unity mod 3329 (17^128 = -1 mod 3329)

# ---------------- Dilithium / ML-DSA ----------------
Q_DSA = 8380417
ZETA_DSA = 1753  # primitive 512th root of unity mod 8380417 -> primitive 256th root^... (standard ref value)


def bitrev(x, bits):
    r = 0
    for i in range(bits):
        r |= ((x >> i) & 1) << (bits - 1 - i)
    return r


def build_zetas(q, zeta, n, bits):
    """zetas[i] = zeta^bitrev(i) mod q, i=0..n-1 -- standard ref-code convention."""
    return [pow(zeta, bitrev(i, bits), q) for i in range(n)]


def ntt_forward(r_in, q, zetas, stage_lens):
    r = list(r_in)
    k = 1
    addr_stream = []
    for length in stage_lens:
        start = 0
        while start < N:
            z = zetas[k]
            kidx = k
            k += 1
            for j in range(start, start + length):
                t = (z * r[j + length]) % q
                r[j + length] = (r[j] - t) % q
                r[j] = (r[j] + t) % q
                addr_stream.append((j, j + length, kidx))
            start += 2 * length
    return r, addr_stream


def run(name, q, zeta, stage_lens, bits, data_width_hexdigits, num_random=3):
    zetas = build_zetas(q, zeta, N, bits)

    # multiple independent random regression vectors
    for i in range(num_random):
        r_in = [random.randrange(0, q) for _ in range(N)]
        r_out, addr_stream = ntt_forward(r_in, q, zetas, stage_lens)
        with open(f"input_{name}_r{i}.hex", "w") as f:
            for v in r_in:
                f.write(f"{v:0{data_width_hexdigits}x}\n")
        with open(f"expected_{name}_r{i}.hex", "w") as f:
            for v in r_out:
                f.write(f"{v:0{data_width_hexdigits}x}\n")

    # keep addr_stream from the last random vector for the debug dump below
    with open(f"input_{name}.hex", "w") as f:
        for v in r_in:
            f.write(f"{v:0{data_width_hexdigits}x}\n")
    with open(f"expected_{name}.hex", "w") as f:
        for v in r_out:
            f.write(f"{v:0{data_width_hexdigits}x}\n")

    # explicit zero vector (hardware-checked too, not just golden-model self-check)
    zero = [0] * N
    zero_out, _ = ntt_forward(zero, q, zetas, stage_lens)
    with open(f"input_{name}_zero.hex", "w") as f:
        for v in zero:
            f.write(f"{v:0{data_width_hexdigits}x}\n")
    with open(f"expected_{name}_zero.hex", "w") as f:
        for v in zero_out:
            f.write(f"{v:0{data_width_hexdigits}x}\n")
    with open(f"addr_stream_{name}.txt", "w") as f:
        for ja, jb, kidx in addr_stream:
            f.write(f"{ja} {jb} {kidx}\n")
    with open(f"zetas_{name}.hex", "w") as f:
        for v in zetas:
            f.write(f"{v:0{data_width_hexdigits}x}\n")
    # packed {ja[7:0], jb[7:0], kidx[7:0]} 24-bit words for the ntt_addr_gen stub's table ROM
    with open(f"addrtab_{name}.hex", "w") as f:
        for ja, jb, kidx in addr_stream:
            word = (ja << 16) | (jb << 8) | kidx
            f.write(f"{word:06x}\n")
    with open(f"addrtab_count_{name}.txt", "w") as f:
        f.write(str(len(addr_stream)))

    print(f"[{name}] q={q} stages={len(stage_lens)} butterflies={len(addr_stream)} "
          f"max_kidx={max(a[2] for a in addr_stream)}")

    # extra sanity vectors: impulse and all-zero (order-independent checks)
    impulse = [1] + [0] * (N - 1)
    imp_out, _ = ntt_forward(impulse, q, zetas, stage_lens)
    with open(f"impulse_in_{name}.hex", "w") as f:
        for v in impulse:
            f.write(f"{v:0{data_width_hexdigits}x}\n")
    with open(f"impulse_expected_{name}.hex", "w") as f:
        for v in imp_out:
            f.write(f"{v:0{data_width_hexdigits}x}\n")
    if len(stage_lens) * 2 >= 8:  # complete NTT (goes all the way to len=1): every point is a
        # full evaluation of the constant poly "1" -> all ones.
        pass
    if stage_lens[-1] == 1:
        assert all(v == 1 for v in imp_out), f"[{name}] impulse response not all-ones! got {set(imp_out)}"
    else:
        # incomplete NTT: final stage leaves length-2 (or longer) unreduced blocks, so a
        # constant polynomial "1" reduces to remainder 1 (not a full point evaluation) --
        # all outputs must still be 0/1 only, never anything else.
        assert set(imp_out) <= {0, 1}, f"[{name}] incomplete-NTT impulse response has unexpected values: {set(imp_out)}"

    zero = [0] * N
    zero_out, _ = ntt_forward(zero, q, zetas, stage_lens)
    assert all(v == 0 for v in zero_out), f"[{name}] zero input did not give zero output"

    # linearity check (order-independent, catches modular-arith bugs)
    a = [random.randrange(0, q) for _ in range(N)]
    b = [random.randrange(0, q) for _ in range(N)]
    ab = [(x + y) % q for x, y in zip(a, b)]
    na, _ = ntt_forward(a, q, zetas, stage_lens)
    nb, _ = ntt_forward(b, q, zetas, stage_lens)
    nab, _ = ntt_forward(ab, q, zetas, stage_lens)
    assert all((x + y) % q == z for x, y, z in zip(na, nb, nab)), f"[{name}] linearity failed"

    print(f"[{name}] golden-model self-checks (impulse/zero/linearity) OK")
    return zetas, addr_stream


if __name__ == "__main__":
    # KEM: 23-bit-wide bus shared with DSA, but Kyber values only need 12 bits
    run("kem", Q_KEM, ZETA_KEM, [128, 64, 32, 16, 8, 4, 2], bits=8, data_width_hexdigits=6)
    # DSA: needs full 23 bits (q=8380417 < 2^23)
    run("dsa", Q_DSA, ZETA_DSA, [128, 64, 32, 16, 8, 4, 2, 1], bits=8, data_width_hexdigits=6)