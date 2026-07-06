// =============================================================================
//  connectome.cu · HOST connectome construction.
//  Places N neurons in a 3D volume as a HIERARCHICAL-MODULAR structure (columns
//  nested into areas) and wires them by the TWO-FACTOR rule
//        P(i->j) ~ exp(-d/lambda) * module_bias(i,j)
//  emitting a CSR (row = presynaptic).
//
//  Structure IS the prior: this file, not the neuron model, is where "brain-like"
//  begins. Uniform-random + distance-only wiring = a random geometric graph
//  (provably NOT brain-like; no Griffiths phase). Modular placement + a
//  hierarchical wiring bias gives clustered, hierarchical connectivity -> an
//  EXTENDED critical band (Moretti-Munoz), the regime a knife-edge tune cannot
//  reach. Operator-approved amendment to MODULE.md S1's Phase-0 wiring rule.
//  Two-pass build (count, then fill) so it can run in parallel per row.
// =============================================================================
#include "brain.h"
#include <vector>
#include <cmath>
#include <cstdint>
#include <cstdio>

// --- tiny deterministic per-row PRNG (splitmix64 -> uniform float in [0,1)) ---
static inline uint64_t sm64(uint64_t& x) {
    x += 0x9E3779B97F4A7C15ULL;
    uint64_t z = x;
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
    return z ^ (z >> 31);
}
static inline float urand(uint64_t& s) {
    return (float)((sm64(s) >> 40) * (1.0 / 16777216.0)); // 24-bit mantissa
}

// --- hierarchical-modular geometry -------------------------------------------
// A neuron's leaf module (column) is a pure function of its 3D position; areas are
// a coarser grouping of columns. We precompute col_id[] and area_id[] once so the
// hot wiring loops do array lookups + integer compares (no divisions).
static inline int col_index(float x, float y, float z) {
    const float mc = VOL_SIZE_UM / (float)MOD_GRID;   // column side (um)
    int cx = (int)(x / mc), cy = (int)(y / mc), cz = (int)(z / mc);
    if (cx < 0) cx = 0; else if (cx >= MOD_GRID) cx = MOD_GRID - 1;
    if (cy < 0) cy = 0; else if (cy >= MOD_GRID) cy = MOD_GRID - 1;
    if (cz < 0) cz = 0; else if (cz >= MOD_GRID) cz = MOD_GRID - 1;
    return (cz * MOD_GRID + cy) * MOD_GRID + cx;
}
static inline int area_of_col(int col) {
    const int AS = (MOD_GRID + AREA_GRID - 1) / AREA_GRID;  // columns/side per area
    int cx = col % MOD_GRID, cy = (col / MOD_GRID) % MOD_GRID, cz = col / (MOD_GRID * MOD_GRID);
    return ((cz / AS) * AREA_GRID + (cy / AS)) * AREA_GRID + (cx / AS);
}
// the module factor of the two-factor rule (cheap homophily proxy).
static inline float mod_bias(int ci, int ai, int cj, int aj) {
    if (ci == cj) return 1.0f;           // same column  (densest)
    if (ai == aj) return W_SAME_AREA;    // same area, different column
    return W_DIFF_AREA;                  // different area (long-range)
}

// One neuron's outgoing edges, computed identically in the count and fill passes.
// EMIT=false counts only; EMIT=true also writes edges. Returns degree.
template <bool EMIT>
static int build_row(
    int i, int N, uint64_t seed,
    const std::vector<float>& px, const std::vector<float>& py, const std::vector<float>& pz,
    const std::vector<uint8_t>& is_inh,
    const std::vector<int>& col_id, const std::vector<int>& area_id,
    const std::vector<int>& cell_start, const std::vector<int>& cell_items,
    int gdim, float cell_um,
    int* out_col, float* out_w, uint8_t* out_delay)
{
    uint64_t st = seed ^ (0xD1B54A32D192ED03ULL * (uint64_t)(i + 1));
    const float lambda = LAMBDA_UM;
    const float cut2   = CONN_CUTOFF_UM * CONN_CUTOFF_UM;
    const float w0     = is_inh[i] ? W_INH_INIT : W_EXC_INIT;
    const int   ci     = col_id[i];
    const int   ai     = area_id[i];

    float xi = px[i], yi = py[i], zi = pz[i];
    int cx = (int)(xi / cell_um), cy = (int)(yi / cell_um), cz = (int)(zi / cell_um);

    // pass A: sum the two-factor weights over the 27-neighbourhood (RNG-free, so
    // count and fill agree). scale then normalises the row toward TARGET_OUTDEG.
    float wsum = 0.0f;
    for (int dz = -1; dz <= 1; ++dz)
    for (int dy = -1; dy <= 1; ++dy)
    for (int dx = -1; dx <= 1; ++dx) {
        int nx = cx + dx, ny = cy + dy, nz = cz + dz;
        if (nx < 0 || ny < 0 || nz < 0 || nx >= gdim || ny >= gdim || nz >= gdim) continue;
        int cell = (nz * gdim + ny) * gdim + nx;
        for (int p = cell_start[cell]; p < cell_start[cell + 1]; ++p) {
            int j = cell_items[p];
            if (j == i) continue;
            float ddx = px[j]-xi, ddy = py[j]-yi, ddz = pz[j]-zi;
            float d2 = ddx*ddx + ddy*ddy + ddz*ddz;
            if (d2 > cut2) continue;
            wsum += expf(-sqrtf(d2) / lambda) * mod_bias(ci, ai, col_id[j], area_id[j]);
        }
    }
    if (wsum <= 0.0f) return 0;
    float scale = (float)TARGET_OUTDEG / wsum; // per-candidate connect prob = scale*w*bias

    // pass B: sample edges (same deterministic RNG sweep in count and fill).
    int deg = 0;
    for (int dz = -1; dz <= 1; ++dz)
    for (int dy = -1; dy <= 1; ++dy)
    for (int dx = -1; dx <= 1; ++dx) {
        int nx = cx + dx, ny = cy + dy, nz = cz + dz;
        if (nx < 0 || ny < 0 || nz < 0 || nx >= gdim || ny >= gdim || nz >= gdim) continue;
        int cell = (nz * gdim + ny) * gdim + nx;
        for (int p = cell_start[cell]; p < cell_start[cell + 1]; ++p) {
            int j = cell_items[p];
            if (j == i) continue;
            float ddx = px[j]-xi, ddy = py[j]-yi, ddz = pz[j]-zi;
            float d2 = ddx*ddx + ddy*ddy + ddz*ddz;
            if (d2 > cut2) continue;
            float d = sqrtf(d2);
            float prob = scale * expf(-d / lambda) * mod_bias(ci, ai, col_id[j], area_id[j]);
            if (urand(st) < prob) {
                if (EMIT) {
                    out_col[deg]   = j;
                    out_w[deg]     = w0;
                    int db = (int)lroundf(d / (COND_VEL_UM_PER_MS * DT_MS));
                    if (db < MIN_DELAY_STEPS) db = MIN_DELAY_STEPS;
                    if (db > N_DELAY_BINS - 1) db = N_DELAY_BINS - 1;
                    out_delay[deg] = (uint8_t)db;
                }
                ++deg;
            }
        }
    }
    return deg;
}

long build_connectome_host(
    int N, unsigned seed,
    std::vector<float>& px, std::vector<float>& py, std::vector<float>& pz,
    std::vector<uint8_t>& is_inh,
    std::vector<int>& row_ptr, std::vector<int>& col_idx,
    std::vector<float>& weight, std::vector<uint8_t>& delay_bin)
{
    px.resize(N); py.resize(N); pz.resize(N); is_inh.resize(N);

    // 1) hierarchical-modular placement + E/I identity ---------------------------
    // Each neuron is assigned to a random leaf module (column) and placed in that
    // column's central sub-cube (a MOD_GAP margin keeps columns spatially
    // separable), so neurons cluster by column and BOTH the distance kernel and
    // the module bias see the same modular geometry.
    uint64_t st     = (uint64_t)seed * 0x2545F4914F6CDD1DULL + 1;
    const float mc  = VOL_SIZE_UM / (float)MOD_GRID;
    const int   nmod = MOD_GRID * MOD_GRID * MOD_GRID;
    const float lo  = MOD_GAP, span = 1.0f - 2.0f * MOD_GAP;
    for (int i = 0; i < N; ++i) {
        int m  = (int)(sm64(st) % (uint64_t)nmod);
        int mx = m % MOD_GRID, my = (m / MOD_GRID) % MOD_GRID, mz = m / (MOD_GRID * MOD_GRID);
        px[i] = ((float)mx + lo + span * urand(st)) * mc;
        py[i] = ((float)my + lo + span * urand(st)) * mc;
        pz[i] = ((float)mz + lo + span * urand(st)) * mc;
        is_inh[i] = (urand(st) < FRAC_INHIB) ? 1 : 0;
    }
    // per-neuron module + area (pure function of position; reused for wiring + metrics)
    std::vector<int> col_id(N), area_id(N);
    for (int i = 0; i < N; ++i) { col_id[i] = col_index(px[i], py[i], pz[i]);
                                  area_id[i] = area_of_col(col_id[i]); }

    // 2) uniform spatial-hash grid for candidate search (cell = cutoff) ----------
    const float cell_um = CONN_CUTOFF_UM;
    int gdim = (int)ceilf(VOL_SIZE_UM / cell_um);
    if (gdim < 1) gdim = 1;
    long ncell = (long)gdim * gdim * gdim;
    std::vector<int> cell_count(ncell + 1, 0);
    auto cell_of = [&](int i) {
        int cx = (int)(px[i]/cell_um), cy = (int)(py[i]/cell_um), cz = (int)(pz[i]/cell_um);
        if (cx >= gdim) cx = gdim-1; if (cy >= gdim) cy = gdim-1; if (cz >= gdim) cz = gdim-1;
        return (cz * gdim + cy) * gdim + cx;
    };
    for (int i = 0; i < N; ++i) cell_count[cell_of(i) + 1]++;
    for (long ci = 0; ci < ncell; ++ci) cell_count[ci + 1] += cell_count[ci];
    std::vector<int> cell_start = cell_count;         // prefix-summed offsets
    std::vector<int> cell_items(N);
    std::vector<int> cursor(cell_start);
    for (int i = 0; i < N; ++i) cell_items[cursor[cell_of(i)]++] = i;

    // 3) pass 1: count degree per row -------------------------------------------
    row_ptr.assign(N + 1, 0);
    #ifdef _OPENMP
    #pragma omp parallel for schedule(dynamic, 256)
    #endif
    for (int i = 0; i < N; ++i) {
        row_ptr[i + 1] = build_row<false>(i, N, seed, px, py, pz, is_inh, col_id, area_id,
                                          cell_start, cell_items, gdim, cell_um,
                                          nullptr, nullptr, nullptr);
    }
    for (int i = 0; i < N; ++i) row_ptr[i + 1] += row_ptr[i]; // prefix sum
    long M = row_ptr[N];

    // 4) pass 2: fill (each row writes its own contiguous, non-overlapping range)
    col_idx.resize(M); weight.resize(M); delay_bin.resize(M);
    #ifdef _OPENMP
    #pragma omp parallel for schedule(dynamic, 256)
    #endif
    for (int i = 0; i < N; ++i) {
        int off = row_ptr[i];
        build_row<true>(i, N, seed, px, py, pz, is_inh, col_id, area_id,
                        cell_start, cell_items, gdim, cell_um,
                        &col_idx[off], &weight[off], &delay_bin[off]);
    }

    // 5) structure metrics -- verify it is brain-like, not just asserted ---------
    std::vector<double> Lc(nmod, 0.0), degc(nmod, 0.0);   // intra-col edges / endpoints per col
    long intra = 0, same_area = 0, diff_area = 0;
    for (int i = 0; i < N; ++i) {
        int ci = col_id[i], ai = area_id[i];
        for (int e = row_ptr[i]; e < row_ptr[i + 1]; ++e) {
            int j = col_idx[e], cj = col_id[j];
            degc[ci] += 1.0; degc[cj] += 1.0;
            if (ci == cj)                { Lc[ci] += 1.0; ++intra; }
            else if (ai == area_id[j])   ++same_area;
            else                         ++diff_area;
        }
    }
    double Q = 0.0, twoM = 2.0 * (double)M;
    if (M > 0) for (int c = 0; c < nmod; ++c)
        Q += Lc[c] / (double)M - (degc[c] / twoM) * (degc[c] / twoM);

    printf("[connectome] N=%d  M=%ld  mean_outdeg=%.1f  grid=%d^3\n",
           N, M, (double)M / N, gdim);
    printf("[structure]  %d^3 columns / %d^3 areas  modularity Q=%.3f  |  edges: "
           "intra-col=%.1f%%  same-area=%.1f%%  diff-area=%.1f%%\n",
           MOD_GRID, AREA_GRID, Q,
           M ? 100.0*intra/M : 0.0, M ? 100.0*same_area/M : 0.0, M ? 100.0*diff_area/M : 0.0);
    return M;
}
