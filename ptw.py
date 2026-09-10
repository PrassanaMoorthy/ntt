Q, N = 17, 8
LOGN = N.bit_length() - 1

# psi = primitive 2N-th root of unity mod Q (needed for negacyclic NTT)
def find_2Nth_root(Q, N):
    for g in range(2, Q):
        if pow(g, 2*N, Q) == 1 and pow(g, N, Q) == Q - 1:  # psi^N = -1
            return g
    raise ValueError("no primitive 2N-th root found")

psi = find_2Nth_root(Q, N)

def brv(x, bits):
    return int(bin(x)[2:].zfill(bits)[::-1], 2)

# tree-based zeta generation, bit-reversed tree order.
# NOTE: plain bit-reversed exponents (psi^brv(i)), NOT odd powers (psi^(2*brv(i)+1)).
# The odd-power form is only valid for Kyber-style NTTs that stop at quadratic
# factors. Here Q-1 = 2N, so the ring fully splits into linear factors
# (length goes all the way down to 1), which needs the general recursive
# square-root tree: root value psi^N, each split halves the exponent and
# offsets the other child by +N.
zetas = [0] * N
for i in range(1, N):
    zetas[i] = pow(psi, brv(i, LOGN), Q)

def ntt_dif(x, zetas):
    x = x[:]
    k, length = 1, N // 2
    while length >= 1:
        start = 0
        while start < N:
            zeta = zetas[k]; k += 1
            for j in range(start, start + length):
                t = (zeta * x[j+length]) % Q
                x[j+length] = (x[j] - t) % Q
                x[j]        = (x[j] + t) % Q
            start += 2 * length
        length //= 2
    return x

def intt_dit(X, zetas):
    # inverse: reverse layer order AND reverse start-order within each layer
    # (k must be consumed in the exact reverse sequence forward produced it),
    # GS butterfly with correct sign: b = (a' - b') * zeta_inv.
    x = X[:]
    k, length = N - 1, 1
    while length < N:
        start = N - 2*length
        while start >= 0:
            zeta = pow(zetas[k], Q-2, Q); k -= 1
            for j in range(start, start+length):
                t = x[j]
                x[j]        = (t + x[j+length]) % Q
                x[j+length] = ((t - x[j+length]) * zeta) % Q
            start -= 2*length
        length *= 2
    n_inv = pow(N, Q-2, Q)
    return [(v * n_inv) % Q for v in x]

def negacyclic_mult(a, b, Q, N):
    res = [0]*N
    for i in range(N):
        for j in range(N):
            k = i + j
            v = (a[i]*b[j]) % Q
            if k >= N:
                res[k-N] = (res[k-N] - v) % Q
            else:
                res[k] = (res[k] + v) % Q
    return res

a = [1,2,3,4,5,6,7,8]
b = [1,0,1,0,1,0,1,0]

A, B = ntt_dif(a, zetas), ntt_dif(b, zetas)
C_ntt = [(A[i]*B[i]) % Q for i in range(N)]
c_via_ntt = intt_dit(C_ntt, zetas)
c_direct  = negacyclic_mult(a, b, Q, N)

print("psi        =", psi)
print("zetas      =", zetas)
print("via NTT    =", c_via_ntt)
print("direct     =", c_direct)
print("MATCH      =", c_via_ntt == c_direct)