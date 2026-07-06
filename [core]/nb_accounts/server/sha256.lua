-- Pure Lua 5.4 SHA-256 implementáció (natív bitwise operátorokkal)
-- Jelszó hasheléshez használjuk salt-tal együtt (lásd sv_main.lua HashPassword függvény)

local band, bor, bxor, bnot = function(a, b) return a & b end,
    function(a, b) return a | b end,
    function(a, b) return a ~ b end,
    function(a) return ~a & 0xFFFFFFFF end

local function rrotate(x, n)
    x = x & 0xFFFFFFFF
    return ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF
end

local k = {
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
}

local function sha256(msg)
    local h0,h1,h2,h3,h4,h5,h6,h7 =
        0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,
        0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19

    local msgLen = #msg
    local bitLen = msgLen * 8

    msg = msg .. '\128'
    while (#msg % 64) ~= 56 do
        msg = msg .. '\0'
    end

    for i = 7, 0, -1 do
        msg = msg .. string.char((bitLen >> (i * 8)) & 0xFF)
    end

    for chunkStart = 1, #msg, 64 do
        local w = {}
        for i = 0, 15 do
            local o = chunkStart + i * 4
            w[i] = (string.byte(msg, o) << 24) | (string.byte(msg, o + 1) << 16) |
                   (string.byte(msg, o + 2) << 8) | string.byte(msg, o + 3)
        end

        for i = 16, 63 do
            local s0 = bxor(bxor(rrotate(w[i-15], 7), rrotate(w[i-15], 18)), (w[i-15] >> 3))
            local s1 = bxor(bxor(rrotate(w[i-2], 17), rrotate(w[i-2], 19)), (w[i-2] >> 10))
            w[i] = (w[i-16] + s0 + w[i-7] + s1) & 0xFFFFFFFF
        end

        local a,b,c,d,e,f,g,h = h0,h1,h2,h3,h4,h5,h6,h7

        for i = 0, 63 do
            local S1 = bxor(bxor(rrotate(e,6), rrotate(e,11)), rrotate(e,25))
            local ch = bxor(band(e,f), band(bnot(e), g))
            local temp1 = (h + S1 + ch + k[i+1] + w[i]) & 0xFFFFFFFF
            local S0 = bxor(bxor(rrotate(a,2), rrotate(a,13)), rrotate(a,22))
            local maj = bxor(bxor(band(a,b), band(a,c)), band(b,c))
            local temp2 = (S0 + maj) & 0xFFFFFFFF

            h = g
            g = f
            f = e
            e = (d + temp1) & 0xFFFFFFFF
            d = c
            c = b
            b = a
            a = (temp1 + temp2) & 0xFFFFFFFF
        end

        h0 = (h0 + a) & 0xFFFFFFFF
        h1 = (h1 + b) & 0xFFFFFFFF
        h2 = (h2 + c) & 0xFFFFFFFF
        h3 = (h3 + d) & 0xFFFFFFFF
        h4 = (h4 + e) & 0xFFFFFFFF
        h5 = (h5 + f) & 0xFFFFFFFF
        h6 = (h6 + g) & 0xFFFFFFFF
        h7 = (h7 + h) & 0xFFFFFFFF
    end

    return string.format('%08x%08x%08x%08x%08x%08x%08x%08x', h0,h1,h2,h3,h4,h5,h6,h7)
end

SHA256 = sha256
