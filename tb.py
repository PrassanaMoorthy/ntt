# Parameters
Q_KEM = 3329
N = 256
ROOT_OF_UNITY = 175  # Primitive 256th root modulo 3329

def ntt_reference(poly, q, psi):
    # Bit-reversed or standard NTT reference calculation
    res = list(poly)
    # Simple DFT matrix approach for reference validation
    out = []
    for k in range(N):
        s = 0
        for n in range(N):
            s = (s + res[n] * pow(psi, n * k, q)) % q
        out.append(s)
    return out

# Generate random input vector
import random
input_poly = [random.randint(0, Q_KEM - 1) for _ in range(N)]
output_poly = ntt_reference(input_poly, Q_KEM, ROOT_OF_UNITY)

# Save to hex files for Verilog $readmemh
with open("ntt_din.hex", "w") as f:
    for val in input_poly:
        f.write(f"{val:06x}\n")

with open("ntt_expected.hex", "w") as f:
    for val in output_poly:
        f.write(f"{val:06x}\n")