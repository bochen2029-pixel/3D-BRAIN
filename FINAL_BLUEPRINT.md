# THE VOLUMETRIC BRAIN ENGINE — Final Crystallized Blueprint

### A truly volumetric 3D spiking-brain simulation engineered onto GPU-native hardware primitives, where the neuron is geometry, the spike rides an edge list, the *field* rides the rays, and computing it and seeing it are the same traversal.

**Author: the CRYSTALLIZER (final synthesis).**
Spine: Gen-1 winner **A1 (RT-Core Maximalist)**, grafted with the best of A2–A7 and the seven specialist deep-dives (S1–S7), and hardened against the completeness critic's gap list. This is the single document the operator should build from.

> **The one-sentence architecture.** Route spikes by **Morton-ordered CSR edge-following on CUDA cores** every step; index **only neuron somata** in a single OptiX BVH and spend the RT cores on the three genuinely-3D per-step-recurring jobs an edge list *cannot* do — the **volume-transmission field**, the **structural-growth trickle**, and the **render** — running them concurrently on a second stream, one step behind, so they free-ride in the shadow of the bandwidth-bound CUDA dynamics sweep. Hold the network at **slightly-subcritical branching ratio m ≈ 0.98** with a five-layer homeostatic stack (cross-homeostasis + iSTDP + short-term depression + slow scaling + a global circuit-breaker), grow the connectome with the **exponential-distance × matching-index** two-factor rule over a hierarchical-modular seed, and default the neuron to a **numerically-guarded Izhikevich/AdEx point unit** with an NMDA-keyed dendritic dial reported as an empirical result. **Honest scale: 1–4 M neurons / 1–4 B synapses at real time on a 24 GB card; ~2× on 32 GB. The binding constraint is synaptic-scatter memory bandwidth, not RT throughput and not BVH rebuild.**

---

## 0. Reader's map and the decisions this document commits to

The brief's Section 7 asks for six deliverables. They are answered in §1 (RT thesis), §2 (end-to-end architecture), §3 (clever techniques + better isomorphisms), §4 (leverage decisions + risks), §5 (phased build), §6 (literature). §7 is the honest scale + acceptance instrument. Before any of that, here are the **contradictions the fleet left open, adjudicated once, with a number and a reason** — because averaging them produces an incoherent machine.

| # | Open question | **Committed decision** | Why (one line) |
|---|---|---|---|
| **dt** | 0.1 ms vs 1 ms — silently 10×'s every real-time claim | **dt = 0.1 ms canonical** (10,000 steps/s = real time), exponential-Euler + hard v-clamp; optional multi-rate 1 ms far from active fronts as a *scaling lever*, not the default | 0.1 ms is the community standard (Potjans–Diesmann, GeNN, NEST); 1 ms corrupts sub-ms STDP timing → corrupts the E/I balance the whole stability story rests on (Zenke 2017, S4 §2, S3 §4) |
| **Scale** | 1–5 M (consensus) vs 10–60 M (A1/A5 optimistic) | **1–4 M neurons, 1–4 B synapses real-time on 24 GB; ~2× on 32 GB**, with a *complete* VRAM budget that includes the delay ring buffer (§7). A1's 20–60 M requires K≈30–100 + fp16-everything + the unproven "field-substitutes-for-synapses" claim — quoted only as a caveated stretch | Anchored to the *measured* Potjans–Diesmann datum (77k neurons / 3×10⁸ syn @ 1× real time on a 2080 Ti, 616 GB/s) scaled bandwidth-linearly (S7 §0) |
| **Structural plasticity** | Freeze-after-growth (S1/S6/S7/A2/A4/A7) vs continuous trickle (A1/A5) | **Freeze during the watchable demo; enable a *bounded* per-step growth trickle (~0.01–0.05%/step) as an opt-in Phase-4 module** gated behind a benchmark. The trickle writes into pre-allocated per-row slack; no BVH rebuild is triggered (only somata are in the BVH) | Freeze makes VRAM + BVH trivially cheap and is the safe default; the trickle is what keeps RT per-step-relevant and self-organizes topology, but its interaction with criticality-during-growth is unproven (S3 risk #5) so it is *off* until validated |
| **Neuron model** | Izhikevich (6 candidates + S3/S5/S7) vs AdEx (S4, the specialist) | **Izhikevich as the workhorse for its dynamical-richness-per-FLOP, but shipped with S4's numerical-safety fixes (two 0.5 ms sub-steps + hard v-clamp), OR AdEx where dt-robustness matters.** Both are 2-var, 8-byte-state, warp-uniform — pick per-population at compile time via NVRTC | Synapse traffic dwarfs per-neuron FLOPs (3rd-order, S4 §7, S7 §5), so the tie-breaker is numerical robustness + a homeostatic hook — which is why we adopt AdEx-grade guards even on the Izhikevich path |
| **Volume transmission** | RT query (A1/A6/A7/S2/S3) vs 3D grid stencil (A2/A4) | **Hybrid, pluggable: RT for the sparse anisotropic near-field; a coarse 128³–256³ 3D grid + Jacobi/FFT diffusion for the smooth far-field.** Benchmark RT vs cell-list on your density before committing (the Jan-2026 FRNN paper shows grid wins at large radius / dense clusters) | The field is the *one* per-step operation with no edge-list alternative (so RT has a genuine per-step job), but a smooth diffusing scalar is a stencil, not a query — match the tool to the field's spectrum (A1 §3.5) |
| **STDP reverse-lookup** | Second (post-indexed) CSR vs per-neuron eligibility traces | **Per-neuron eligibility traces (one pre-trace + one post-trace scalar/neuron), forward-only STDP.** Halves plastic-synapse cost; store the transpose CSR only if a specific rule needs the acausal term at the post-spike | Majority + cheaper answer (A2 §5, A3 §6.4, A7 §8.1); saves ~4–8 B/synapse on the dominant array |
| **Delay representation** | Continuous per-synapse vs bucketed | **Bucketed: quantize geometry-derived delays into ~16–64 discrete steps** (uint8 delay), homogeneous-per-bucket ring queues | Enables uint8 delays + cheap queues; the polychrony cost of quantizing is bounded and monitored (heterogeneity across buckets still desynchronizes) |
| **Body/environment loop** | In or out | **OUT.** The network is fully autonomous, self-sustained by internal recurrent dynamics + a small Poisson/spontaneous-release noise floor + the volume-transmission field. No sensorimotor loop | The brief explicitly disclaims usefulness/task-performance; "self-sustaining from internal drive alone" is the stronger, intended (and riskier) claim, stated openly |
| **Dendritic complexity / Tensor cores** | Core vs experiment | **Phase-5 experiment, OFF by default.** The bulk population is point neurons; the dendritic dial (`K` subunits) is a reported empirical result, not a load-bearing pillar | S3/S4/S5 all bet criticality is a *network* property that point neurons capture; dendritic computation buys richer *representations*, not *self-sustenance* |

Everything below is consistent with this table. Where a claim is asserted-but-unbenchmarked, it is marked **[VALIDATE in Phase 0/1]** — those are assumptions, not facts, and the phased plan turns each into a measurement.

---

## 1. Deliverable 7.1 — Candid assessment of the isomorphic / RT-core thesis

The operator asked to be corrected, not flattered. Here is the correction, precisely, with the per-step verdict the whole memory layout and step-rate hinge on.

### 1.1 What is genuinely right (keep all of this)

1. **RT cores *are* a hardware 3D range-search engine, established beyond graphics.** The canonical trick — wrap each point in a sphere of the cutoff radius, launch a degenerate short ray (`tmin=0, tmax≈1e-16`) at each query, report intersected spheres — is exactly **RTNN** (Zhu, PPoPP 2022: neighbor-search-as-ray-tracing, **2.2×–65×** over CUDA baselines). It generalizes: **RT-DBSCAN** (1.3×–4.5×), **RT-BarnesHut** (5.6×–41×), RT-kNNS Unbound, RTIndeX. The operator's premise that "the wiring problem and the RT hardware's strongest capability are the same problem" is **correct — for wiring (growth)**.

2. **The 3D-only constraint being a *feature* is a genuinely sharp and correct observation.** RT cores are hardwired for exactly 3 spatial dimensions; most GPGPU-on-RT papers treat this as a cage. A volumetric `(x,y,z)` brain lives natively in ℝ³. The neuroscience argument for 3D (Cajal wiring economy; conduction-delay-from-distance) and the hardware precondition **coincide** — a legitimate weak/engineered isomorphism. Keep it; it is the reason the whole project is elegant rather than arbitrary.

3. **"Many short rays, event-driven" matches brain statistics.** Cortical connectivity is dominated by short-range local wiring (connection probability falls off over ~150–300 µm; exponential distance rule, λ≈0.188 mm⁻¹ interareal). RT cores favor many short rays over few long ones. Both true.

4. **Sim-render unity is real — but as an *economy*, not a literal single pass.** You are already casting rays through a 3D structure; the render *is* that. The correct, defensible statement (every architect who touched it converged here) is: **one geometry, one VRAM arena, zero-copy CUDA↔Vulkan/OpenGL interop, two separable ray/raster passes — no CPU round-trip.** The BVH you traverse for the field is the BVH you traverse to draw. This alone justifies an OptiX pipeline at the center even if RT did nothing else. **Correct the "same operation" overreach in the brief §3 to "same geometry, same memory, two passes."**

### 1.2 The load-bearing misconception (corrected head-on)

> **"Propagating a spike is a fixed-radius query, so RT cores route spikes every step." — FALSE, and it is the most important 20% to get right.**

Once the connectome is an explicit CSR edge list, delivering a spike is **edge-following**: scatter activation to the K stored post-synaptic targets — a bandwidth-bound gather/scatter that CUDA cores do optimally. Re-deriving those targets with a spatial query every step is strictly, provably wasteful, on **three independent grounds** (S2 §3):

- **Algorithmic:** the target set `{j}` is a *stored constant*. You cannot beat an O(1) array dereference with an O(log N) BVH traversal + O(k) intersection tests. Re-querying pays traversal cost to recompute a constant — the "Minecraft tax" turned against the operator.
- **Hardware:** RT cores exist to *discard space*. Edge-following has no space to discard. Worse, enumerating *all* neighbors in radius requires the **Any-Hit** shader, which the primary sources show is the RT core's *worst* path (RT-DBSCAN disabled AnyHit; the triangle-approx AnyHit path cost **2×–5×**; OptiX **cannot early-terminate** without AnyHit). The one thing you'd need RT to do for routing is the thing RT is worst at.
- **Information:** **weight is not geometric.** Post-STDP, two equidistant neurons have arbitrary weights, and delay is baked at wiring time — so you must materialize a per-edge record regardless. Once that record exists, the spatial query is pure redundancy. A fixed-radius query also returns *geometric* neighbors, not *synaptic* partners: a real connectome is sparse and specific *within* the radius (~0.1–0.25 connection probability for nearby pairs), so the query returns a 5–50× superset you'd then filter.

**The penalty for routing-via-rays is conservatively 1–2 orders of magnitude per delivered spike** (composing RTNN's ~1:15,000 build:query ratio + RT-DBSCAN's AnyHit penalty + the re-derived-constant argument). The operator was right to be suspicious. **Never route spikes with rays.** [VALIDATE in Phase 0: a 1-day CSR-vs-all-hits-RT micro-benchmark at 10⁶ neurons kills the idea definitively — no one has built the RT router because no one has been foolish enough to, so the consensus is *inferred, not measured*; measure it.]

### 1.3 The reconstruction — three per-step jobs that ARE spatial (the maximalist's real, defensible throne)

The thesis does **not** collapse to "growth-only." A brain sim that is *only* an edge list throws away three things a volumetric brain genuinely has, all of which are per-step 3D queries the RT core is built for and that no edge-list design can do without reinventing the BVH:

**(A) Volume transmission / the field — the genuinely irreducible per-step spatial query.**
Real tissue signals through *space*, not only wires: neuromodulators (dopamine, ACh, serotonin) diffuse and act within a radius; extracellular K⁺ accumulates and raises local excitability; ephaptic coupling links nearby membranes without a synapse; astrocytic Ca²⁺ waves. **None has an edge list** — the "connectivity" is defined at runtime by who is physically near whom and how much they are emitting, and it *changes every step because emission changes every step*. This is RTNN, exactly, recurring every timestep, with no cached answer. It is the strongest surviving argument for keeping *any* RT in the runtime loop, and it is arguably *more* important than any single wired detail for the slow metastable dynamics (up/down states, neuromodulatory gain control) that make cortex recognizably brain-like rather than a spiking gas. **Run it hybrid** (§0, §2.6): RT for the sparse anisotropic near-field, a coarse 3D grid for the smooth diffusing far-field — do not RT-ify a stencil.

**(B) Structural-plasticity growth trickle — growth that never fully freezes (opt-in).**
Real brains do lifelong structural plasticity (spines appear/retract over minutes–hours). Model it as: every step, a bounded activity-flagged cohort (B ~ 10³–10⁵ neurons) launches a growth query into the soma-BVH to find candidate partners; a matched budget of weak/silent synapses is pruned. At ~0.01–0.05%/step this is biologically apt, cheap (well under RT throughput), and it self-organizes the connectome toward criticality rather than hand-tuning it. **This makes RT a per-step actor.** *Committed decision:* **off during the watchable demo (freeze), on as a Phase-4 module** once criticality-during-growth is validated (S3 risk #5 is real and unmitigated at scale).

**(C) The render — every displayed frame is a ray cast.** Recurs every frame (~60 Hz, decoupled from the ~10 kHz sim) by definition. §2.7.

**Honest per-operation scorecard (this table *is* the Problem-#2 verdict):**

| Operation | Per step? | Spatial query? | Right engine | RT earns its place? |
|---|---|---|---|---|
| Spike delivery along known synapses | yes | **no** (edge-follow) | CUDA scatter | **No — correctly rejected** |
| Membrane/threshold/adaptation dynamics | yes | no | CUDA | No |
| STDP / homeostatic weight updates | yes | no | CUDA | No |
| **Volume transmission / neuromod / K⁺ / ephaptic** | **yes** | **yes** | **RT (near) + grid (far)** | **YES** |
| **Structural-growth trickle** (opt-in) | yes | **yes** | **RT** | **YES (Phase 4)** |
| Initial connectome growth | once | yes | RT (or CUDA cell-list) | Yes — but benchmark vs cell-list |
| **Rendering** | **every frame** | **yes** | **RT** | **YES** |
| Dense sub-blocks / dendritic MLPs | rare | no | Tensor | rarely (Phase 5) |

**Net verdict.** The RT core is **not** the beating heart of the runtime loop — the CUDA cores are (dynamics + edge-following). But the RT core is not "merely" a developmental convenience either: it is the **beating heart of a concurrent spatial/field/growth/render loop** that runs *in the shadow of* the bandwidth-bound CUDA sweep. Spikes ride the edge list on CUDA; the brain's *space* — its fields, its growing wiring, its visible glow — rides the rays. That is a narrower throne than "RT does everything," but it is a real throne, and it is defensible with numbers.

**The one caveat that governs even the growth win (graft from A2 + Jan-2026 FRNN):** RT-FRNN beats CUDA cell-lists ~1.3–4× at *moderate* radius/sparsity but **inverts to a loss at large radius / dense clusters** — precisely the cortical local-wiring regime. So even for growth, **build a CUDA uniform-grid cell-list baseline first and gate RT growth behind an A/B benchmark on your real neuron density.** This does not touch the volume-transmission *field* case (which has no cell-list alternative that isn't itself a reinvented spatial index), but it disciplines the *growth-FRNN* case. Do not let the field graft quietly promote RT back to a foregone default.

---

## 2. Deliverable 7.2 — The recommended end-to-end architecture

### 2.1 Hardware → layer mapping

| GPU unit | Layer it owns | Specific operations | Cadence |
|---|---|---|---|
| **CUDA cores (SIMT)** | **Dynamics / routing / learning — the beating heart** | neuron state integration; threshold + spike detect; warp-ballot spike compaction; **spike delivery via Morton-ordered CSR edge-list scatter**; delay-ring drain; STDP; the five-layer homeostatic stack; the σ-servo | every step |
| **RT cores (OptiX)** | **Spatial / field / structural / visual — the concurrent shadow loop** | (1) volume-transmission near-field gather; (2) structural-growth queries (opt-in); (3) initial connectome growth (benchmarked vs CUDA cell-list); (4) the render pass | field: every step (decimated OK); growth: every step small budget (opt-in); render: every frame |
| **Tensor cores (WMMA/MMA)** | **Dense blocks only** | batched identical-topology dendritic MLPs (Phase-5 dendritic dial); optional dense readout/relay patch | rare; opt-in per morphotype |

**Design stance on Tensor cores:** do **not** architect around them. A sparse spiking brain has no dense GEMM to feed them in the base design; they sit idle (S7 §5). Their one legitimate high-value use is batching thousands of *identical-topology* dendritic units (Beniaguev's "single neuron ≈ small deep net") into a GEMM — the one place Tensor cores could carry per-step load, and only for the subset of neurons on the high-complexity rung. Keep it as an optional accelerator, not a wall.

### 2.2 Core data structures (SoA throughout; AoSoA only for the dendritic rung)

**The load-bearing framing (S1 §2, quote verbatim as the architectural rule):** *the BVH indexes **somata only, forever** — never synapses, never edges, never weights.* Weights and edges (including structural changes) live in CUDA-side arrays; both weight plasticity and structural plasticity are edge-list operations that touch the BVH zero times. The BVH mutates only on soma birth/death/drift (seconds-to-minutes, or never). This single decision dissolves Problem #1 ("dynamic connectome vs. static BVH") rather than managing it.

**Neuron arrays (pure SoA — AoSoA buys nothing for a 2-var point neuron; adopt AoSoA only if the dendritic rung activates):**
```
// Geometry (feeds BVH primitives; cold in dynamics, read by growth/render/delay-calc)
float3  pos[N];            // (x,y,z) in sim units                 12 B
// Dynamics state (hot, read+write every step)
float   V[N];              // membrane potential                   4 B
float   u_or_w[N];         // Izhikevich recovery u / AdEx adapt w 4 B
float   I_syn[N];          // scatter accumulator (fp32 atomics)   4 B
half    g_nmda[N];         // slow NMDA conductance (complexity knob) 2 B
half    theta[N];          // adaptive threshold (homeostatic)     2 B
half    neuromod[N];       // local field value (RT output)        2 B
uint    last_spike_t[N];   // STDP + refractory                    4 B
half    pre_trace[N], post_trace[N]; // per-NEURON STDP traces     4 B
uint16  pop_id[N];         // -> tiny per-population param table    2 B  (a,b,c,d live in __constant__)
uint8   refrac[N], flags[N]; // E/I type, alive/dead, rung id      2 B
```
≈ **~42–48 B/neuron** including position, with parameters kept **per-population** in a 32-entry `__constant__` table indexed by `pop_id` (A4's type-table trick — removes 16–20 B/neuron of per-neuron params). At 24 GB, neuron state alone would hold ~430 M neurons — **neurons are never the constraint; synapses are.**

**Synapses — the memory hog (this is where the design lives). CSR / GeNN-style ragged matrix, indexed by presynaptic neuron:**
```
uint   row_start[N+1];     // CSR offsets (or row_length[N] for ragged/mutable)
uint   post_idx[E];        // target neuron index                  4 B
half   weight[E];          // fp16 plastic weight                  2 B
uint8  delay[E];           // BUCKETED delay = round(dist/v_cond)   1 B
uint8  syn_type[E];        // AMPA/GABA/NMDA + plastic flags        1 B
```
= **~8 B/synapse** static, **~8–10 B plastic** (STDP traces are per-*neuron*, not per-synapse — this is the single biggest byte-saving lever after fp16 weights). Budget **~8–12 B/synapse**. Reject the alternatives: a **global edge list** has no coalescing on the scatter (correct only as a build-time staging format); **per-neuron pointer adjacency** is pointer-chasing death on-device. CSR/ragged is what GeNN and Brian2CUDA independently converged on — the strongest empirical signal available.

**Dynamic connectivity (if the trickle is on):** GeNN-style ragged matrix + per-row slack (allocate ~1.3–2× current degree) + **swap-with-end O(1) add/remove** (Knight et al. 2025). Do *not* build a general slab allocator first. Periodic (every ~10⁴ steps) async CUB `DeviceSelect` stream-compaction defragments. [The 2× slack is a real VRAM multiplier — the biggest reason to keep the trickle off during the watchable demo and reclaim it via freeze.]

**The BVH (RT structure):** custom-AABB primitives, one per soma; single **GAS** (no instancing needed). Budget **~64–90 B/neuron** for the compacted AS + the 24 B/neuron input AABB array kept for refit. At 4 M neurons ≈ **~0.26–0.36 GB** — a rounding error; at 10⁷ ≈ ~0.9 GB, a real line item only at the high end. [VALIDATE: exact compacted-GAS bytes/prim on Ada/Blackwell via `optixAccelComputeMemoryUsage` + compaction before any >10⁷-neuron budget — literature spans 32–90 B/prim.]

**Delay ring buffer (a first-class multi-GB line item nobody should omit):** because delays come from geometry, spikes deliver in the future. Ring buffer of D bins (D = max_delay/dt). **Budget it explicitly** (§7) — it is 80 MB to 3.2 GB depending on D and N, and A1/A5's optimistic scaling omitted it. Mitigation: **delay-binning** — coarse bins for long-range edges, fine for local — and uint8 delays.

**Spike plumbing:** warp-ballot compaction (§3) produces the fired-neuron list in registers; that list is both the CUDA scatter set and the RT growth-ray-launch set.

### 2.3 The per-timestep pipeline, step by step (the heart)

**Two concurrent loops on separate CUDA streams, synchronized once per step.** Stream **S1 = CUDA dynamics**; stream **S2 = RT spatial/field/growth/render**. They overlap because the field a neuron feels *this* step is a function of *last* step's emissions — a **one-step biological lag** both ways removes the dependency stall and lets the two silicon units run simultaneously. **This one-step-lag decoupling is the single highest-leverage systems trick in the whole design: it is *why* RT is "free."**

Fuse the elementwise CUDA stages into **one persistent megakernel / CUDA-graph replay** to delete the ~5–10% launch-overhead tax of ~10k launches/s (the host-side "Minecraft tax," graft from A6).

**Per step t:**

**— Stream S1 (CUDA cores): dynamics —**
1. **Drain delay-ring bin `t mod D`:** scatter-add pending `weight` into `I_syn[post]` (warp-aggregated `atomicAdd`, fp32). *This is the dominant memory op of the whole sim — random scatter, bandwidth-bound.*
2. **Integrate neuron state** (one thread/neuron, coalesced SoA):
   `I = g_exc·(E_exc−V) + g_inh·(E_inh−V) + g_nmda·mg_block(V)·(E_nmda−V) + I_field`, where `I_field` is *last* step's neuromod/K⁺ (RT output) and `mg_block(V)` is the NMDA voltage-gate (the supralinearity Beniaguev identifies as *the* source of single-neuron complexity).
   - **Izhikevich (numerically guarded):** two 0.5 ms sub-steps of `V += dt·(0.04V²+5V+140 − u + I)`, `u += dt·a(bV−u)`, with a hard `V`-clamp; **or AdEx** `C dV/dt = gL(EL−V) + gL·ΔT·exp((V−VT)/ΔT) + I − w`, `τw dw/dt = a(V−EL) − w` via exponential-Euler (`__expf` intrinsic). Decay conductances `g *= exp(−dt/τ)`.
   - *Dendritic rung (flagged neurons only, Phase 5):* integrate `K` sub-compartments each with a local NMDA/bump nonlinearity, sum to soma (or Tensor-batch identical-K morphotypes).
3. **Threshold & spike-detect:** if `V ≥ V_peak` → spike, reset (`V=c; u+=d` or AdEx reset), `last_spike_t=t`, raise `theta`. Set the warp's spike bit.
4. **Warp-ballot compaction** (`__ballot_sync` + `__popc` + warp-scan) → `fired[]` list in registers, no atomics/shared-mem.
5. **Deliver spikes via edge list (THE ROUTING STEP — CUDA, not RT):** for each fired i, walk `post_idx[row_start[i]:row_start[i+1]]`; append `(post_idx, ±weight)` to ring bin `(t+delay) mod D`. **Edge-following. No ray. This is the corrected insight, implemented.**
6. **STDP + fast plasticity:** forward-only pair-based STDP via per-neuron traces (pre-before-post potentiates on delivery; acausal term folded at the next post-spike). Net-depression-biased window (A⁻τ⁻ > A⁺τ⁺) for weak homeostatic pressure. Short-term depression per *presynaptic* neuron (one scalar/neuron).
7. **Homeostatic + σ-servo (every ~100–1000 steps):** the five-layer stack (§2.5).

**— Stream S2 (RT cores, OptiX): spatial / field / growth / render —**
8. **BVH refit** (cheap, only if somata drift) or **freeze** (default: build once at end-of-growth, never rebuild). Async double-buffered rebuild only on birth/death, seconds-to-minutes cadence. *This is the answer to Problem #1: the spatial structure changes glacially; only weights change fast.*
9. **Volume-transmission near-field gather (RT FRNN):** short ray per receptor region; any-hit accumulates modulator/K⁺/ephaptic contributions from recently-fired emitter spheres → `neuromod[]`, consumed next step by S1. Smooth far-field runs on the coarse grid (splat emitters → few Jacobi steps → trilinear sample).
10. **Structural-growth trickle (opt-in, Phase 4):** bounded activity-flagged cohort launches growth rays; hits form new synapses ∝ `exp(−d/d0)·(matching_index)^γ·activity_correlation` into edge-list slack (delay from hit distance); prune a matched budget of weakest synapses.
11. **Render pass (per displayed frame, ~60 Hz):** camera rays traverse the *same* GAS; shade each hit sphere by `V`/spike state (emissive when firing); zero-copy via CUDA↔Vulkan interop. §2.7.

**— Barrier / handoff —**
12. **Cross-stream sync:** S1 publishes emission for S2's next gather; S2 publishes `neuromod`/`I_field` for S1's next integration. One-step lag both ways → loops overlap, no stall. **RT free-rides in the shadow of the bandwidth-bound CUDA sweep.**

### 2.4 Neuron & synapse models

**Neuron: point unit default, dendritic dial as a reported result.**
- **Reject LIF as default** (dynamically impoverished — no bursting/adaptation/rebound; you'll fight for interesting dynamics and reinvent AdEx worse). **Reject full HH** (~1200 FLOP, 240× an AdEx neuron — the Blue-Brain trap the operator rightly rejects).
- **Workhorse: Izhikevich (2 ODEs, 4 params, ~13 FLOP/step, full cortical firing zoo: RS/IB/CH/FS/LTS/TC) — shipped with S4's numerical guards** (two 0.5 ms sub-steps + hard v-clamp; the `0.04V²+5V+140` form blows up in finite time at large dt). **AdEx is the equally-cheap, dt-robust, biophysically-parameterized alternative** whose adaptation variable `w` doubles as the homeostatic hook — prefer it if you want the evolutionary search to have physically-meaningful axes. Both are 8-byte-state, warp-uniform, equally GPU-friendly. RS (exc): a=0.02,b=0.2,c=−65,d=8. FS (inh): a=0.1,b=0.2,c=−65,d=2 — fast, non-adapting, dense-local for ISN stability. Jitter params ±10–20% (heterogeneity is a free desynchronizer).
- **The parameterize-and-evolve stance, made operational (two knobs, not one slider — S4's key correction):** *Knob 1* = somatic richness (AdEx/Izh params, ~free, continuous) — turn this first; it's where E/I-balanced self-sustaining dynamics comes from. *Knob 2* = **`K` = number of nonlinear dendritic subunits (integer 0–8)** — the *real* complexity knob, spanning McCulloch–Pitts (`K=0`) → dendritic-XOR (`K≥2` with a **non-monotone bump** nonlinearity, Gidon 2020) → single-neuron-deep-net (`K=4–8` + slow NMDA conductance, Beniaguev 2021). **Correct the "5–8 layers" framing:** that depth is a proxy for NMDA-dependent supralinearity — strip NMDA and the L5PC collapses to *one* hidden layer. So the load-bearing thing is **one layer of dendritic nonlinearity + slow NMDA-timescale synapses**, not generic depth. The sim evolves the *minimum `K`* that achieves target dynamics and **prints it** — turning the philosophical wager into an empirical number. Implement `K` per-population via NVRTC-specialized branch-free kernels (compile-time, zero runtime divergence). **Strong prior (S3/S4/S5): for self-sustaining criticality, `K=0` suffices; the loop will report `K=0` unless a fitness function rewards specific input→output discriminations.**

**Synapses: conductance-based, event-driven, geometry-timed.**
- **Conductance-based** (`I_syn = g·(E_rev − V)`), giving the E/I reversal structure ISN stability needs and NMDA's voltage dependence for free.
- **Delay from geometry** (`delay = ‖pos_pre − pos_post‖ / v_cond`, v_cond ~0.1–1 m/s local), **bucketed to uint8** — timing falls out of distance (a *write-time* freebie, not a per-step recompute), and the heterogeneous delay distribution is itself a desynchronizer and wave-former (Brunel: delay sets oscillation frequency f≈1/(2·delay)).
- **STDP:** forward-only, per-neuron traces, τ±≈20 ms, soft/multiplicative bounds (→ lognormal not bimodal weights). Weights initialized **lognormal** (Song 2005; ~2 orders of magnitude spread).

### 2.5 Dynamics-stabilization strategy — the five-layer homeostatic stack (neither silence, seizure, nor soup)

This is *the* hard problem and the actual project-killer. The operator named two failure walls (silence, seizure); the specialists name **four**: silence, seizure, **the soup** (self-sustaining + non-seizing but m≈0.7, no avalanches, no metastability — passes every "is it alive?" smoke test and is *still not brain-like*), and **drift off the edge**. All four are defeated by one coherent design.

**The single sharpest correction (S3):** *criticality is not a knob you set — it is a fixed point you self-organize toward.* You do not find a magic global gain and freeze it; you build local homeostatic feedback loops whose fixed point *is* the edge, and let the network fall onto it and stay there as weights drift and the connectome grows. For a *growing, plastic* brain this is not optional — it is the only thing that keeps a growing net alive.

**Target: slightly-subcritical m ≈ 0.98** (Wilting & Priesemann 2018: in-vivo cortex is reverberating/subcritical, m̂≈0.963–0.998), **not** m=1 (a knife-edge that noise or subsampling pushes into seizure), measured with the **subsampling-robust MR estimator** (the renderer only ever sees a subsample — naive regression is severely biased).

**The five controllers, on separated timescales (the grafted core, from A3 + S3):**
1. **ISN + E/I balance (necessary, the coarse control).** Inhibition-stabilized: recurrent excitation strong enough to be self-amplifying alone, held by *fast, local* inhibition (FS cells, τ_I < τ_E). E:I = 4:1, g = J_I/J_E ≈ 4–8 (g=5 default), J_E ≈ (V_th−V_rest)/√K (strong-sparse balance). Signature: CV_ISI≈1, low pairwise correlation, paradoxical-effect-positive. Gives biological irregularity *for free* (no per-neuron RNG needed — van Vreeswijk–Sompolinsky).
2. **Inhibitory STDP (Vogels 2011), from day one.** Local iSTDP drives each neuron to a target rate ρ₀≈3–5 Hz by tuning inhibitory weights → detailed per-neuron E/I balance, the asynchronous-irregular state. Cheaper and arguably more important than E→E STDP for stability. **Ship it in Phase 1, not later.**
3. **Cross-homeostatic plasticity (Mackwood et al., PNAS 2022) — the single most important stabilizer upgrade.** Vanilla synaptic scaling **provably cannot** drive the network into the ISN regime (the paradoxical effect); only cross-homeostatic rules, where E and I neurons regulate *each other's* set-points, reach and hold it. This is the difference between "self-sustaining in theory" and "self-sustaining on run 1." Most candidates omit it; it is load-bearing.
4. **Fast rapid-compensatory process (the temporal-paradox fix, Zenke 2017).** Homeostasis must be *fast* (seconds, not the biological hours) to catch Hebbian runaway before it explodes. Use **short-term synaptic depression** (Tsodyks–Markram, per-*presynaptic*-neuron, ~1 float/neuron, τ_rec≈200–1000 ms — this alone self-organizes criticality à la Levina 2007) + **spike-frequency adaptation** (the Izh `u` / AdEx `w`, τ_w≈100–300 ms). Two levels of negative feedback (synapse + soma), nearly free.
5. **Slow synaptic scaling + a global circuit-breaker.** Multiplicative scaling (weight-preserving in ratio, so it doesn't erase learned structure) sets the long-term operating point every ~10⁴–10⁵ steps. **The circuit-breaker (graft from A3):** a single-scalar feedback — if population rate exceeds a ceiling for K ms, transiently boost global inhibitory gain — so a long watchable run is *never* lost to a seizure. Optionally servo `g ← g + κ·(m̂ − 0.98)` directly on the measured branching ratio.

**Architectural belt-and-suspenders (S5/S3, Moretti–Muñoz):** build the connectome **hierarchical-modular**, which produces a **Griffiths phase** — an *extended* critical-like band (a stretched region, not a knife-edge), so you don't have to hit m=0.98 exactly. Architecture buys a wide target; homeostasis keeps you in it.

**What "brain-like, not soup" looks like:** irregular asynchronous-but-not-independent firing; **power-law avalanches** (size exponent α≈1.5, duration β≈2.0); **propagating waves** across the volume (geometry-derived delays make these spatial); **metastable assembly switching** (Litwin-Kumar–Doiron: clustered E connectivity + adaptation → slow up/down transitions — the most "thinking-looking" phenomenon you can put on screen); nested oscillations (delays + E/I + adaptation → gamma-ish local, slower global).

### 2.6 Connectome-growth model (grow, don't transcribe)

**The single most important equation (S5, graft from A5): the two-factor economical wiring rule.**
> **P(i→j) ∝ exp(−d_ij / d0_type) · (matching_index_ij)^γ · module_bias(i,j)**

- **Distance kernel is exponential, not Gaussian** (Exponential Distance Rule, Ercsey-Ravasz 2013, λ≈0.188 mm⁻¹ interareal; d0 a free scale set so mean out-degree hits your target). Gaussian kills the heavy long-range tail that makes it small-world.
- **The matching-index (homophily) second factor is essential and is where every naive design fails.** Distance *alone* yields a **random geometric graph — provably not brain-like** (Betzel 2016: pure-geometric models have the *highest* energy of all 13 tested). The matching index (`|N(i)∩N(j)| / |N(i)∪N(j)|`, γ≈0.42, η≈−0.98) manufactures the Song–Sporns fingerprint: lognormal weights, ~4× over-represented reciprocity, over-represented transitive triangles, clustering, modules. **This is the tension no candidate fully resolved:** the *brain-like* rule (homophily) is O(k²)-ish per node to compute online and **may be too costly at scale** [VALIDATE], whereas the *cheap* rule (distance-only) is not brain-like. Mitigation: approximate homophily via **module_bias** (a coarse homophily proxy — cheap, and likely yields the same motif statistics) + a small explicit long-range fraction.

**Seed geometry:** N somata in a 3D volume, **hierarchical-modular** (2–4 nested levels, columns within areas), Poisson-disk within modules. **80% excitatory / 20% inhibitory** (Dale's law), inhibitory with shorter reach (d0_I ≈ 0.3–0.5·d0_E; basket-cell-like). ~85:15 intra:inter-module edges (tunes small-worldness and Griffiths width); 1–5% deliberate long-range excitatory edges from the exponential tail (rich-club integration). Verify **Rent exponent p≈0.75** as a sanity check.

**Directional growth (graft from A5):** RT rays have direction, so bias the growth query by **∇(morphogen field)** — a cone-restricted FRNN — to get topographic maps and laminar targeting for free (Sperry/chemoaffinity analog from ~12 morphogen fields + a 4-vector molecular label per neuron, not a wiring table).

**Grow → anneal → freeze (the cadence, S1):** growth uses *rebuilds* (primitive count changes), the mature phase uses *freeze*. **Anneal structural-change-rate to ~0 before enabling the watchable real-time phase** — biologically motivated (critical periods) *and* computationally motivated (the developmental timeline and the BVH-cadence timeline are the same timeline). Delays baked from geometry at wiring time; weights init lognormal, sculpted by STDP + scaling.

**Built-in vs emergent (the genome/phenome discipline, S5/A5):** hard-code the *statistics/geometry* (density field, distance kernel, E/I identity, module seeds, guidance labels — a **KB-sized genome**; if your genome is megabytes, you're transcribing). Let *emerge* the realization (edges, weights, motifs, operating point — a **GB-sized phenome**). Make emergence **falsifiable and monitored:** measure small-world index σ_sw, modularity Q, Rent p, degree/clustering distributions each epoch and *report* them; use **per-pair hash-RNG** so a brain is reproducible from genome+seed and two genomes can be A/B'd.

### 2.7 Visualization (sim-render economy, the honesty instrument)

**One geometry, one memory, two zero-copy passes, no CPU round-trip. Decouple sim rate (~10 kHz) from render rate (~60 Hz) — never couple physics to the camera** (orbiting the camera must never re-simulate; A2/A6 correctly flag this as a coupling *bug* in the naive framing).

**Visualization semantics (graft from A7 — the sharpest Section-5 answer):**
- **Spikes as transient decaying light** (the single highest-value visual — a spike is a flash that fades over a few frames).
- **Membrane potential as steady color; E-warm / I-cool coding** so you can literally *watch inhibition chase excitation* (ISN made visible — doubles as a stability debugger by eye).
- **Activity-dependent bloom = local synchrony.**
- **Edges OFF by default** (10⁹ edges is a hairball; light propagating through the cloud shows connectivity implicitly).
- **Clipping / sectioning planes** to see inside the volume.
- **The LFP "weather layer":** splat a low-pass of population activity into a coarse 3D texture, volume-render it as translucent fog to reveal the slow traveling-wave / oscillatory structure the fast spike flicker hides — the view that most reads as "a brain thinking."
- **The honesty instrument (mandatory):** a **live on-screen branching-ratio m̂ + avalanche-size-histogram overlay.** This is the operator's real acceptance criterion — the **legibility test:** with these encodings, a knowledgeable observer can distinguish *dead / saturated / soup / critical by eye*, corroborated by the on-screen m̂. If you can't tell them apart, you haven't succeeded. Render two paths: **Path A** raster point-splat (ships in week 1), **Path B** RT sphere-trace as the cinematic mode, both reading the same zero-copy arena.

---

## 3. Deliverable 7.3 — Clever / non-obvious techniques + better isomorphisms

**Ranked consolidated techniques list** (the completeness critic asked for one ranked list; here it is, by payoff-to-effort):

1. **Morton/Z-order neuron renumbering — the highest payoff-to-effort item in the whole build (graft from A4).** Assign neuron ids along a 3D space-filling curve so spatially-near (hence connectivity-near) neurons get numerically-near ids → the spike scatter hits compact, **L2-resident** accumulator regions → scatter efficiency lifts from **~15% to ~40–60%**, roughly *doubling* the binding-constraint bandwidth. It doubles as **half the LBVH build** (an LBVH *is* a Morton sort). Pair with target-tile bucketing of deliveries for a second coalescing win. **[VALIDATE the exact gain in Phase 1 — it defines the real-time neuron ceiling.]**
2. **The one-step-lag concurrent-stream decoupling (from A1).** CUDA dynamics on S1, RT field/growth/render on S2, coupled by a one-step biological lag both ways so they run on separate silicon with no dependency stall. This is *why* RT is "free" and the highest-leverage *systems* idea.
3. **Warp-ballot spike compaction + warp-aggregated scatter (from A6).** `__ballot_sync` + `__popc` + warp-scan compact spikes in registers (no atomics, no shared memory); warp-aggregated `atomicAdd` for the scatter. Turns the classic SNN atomics bottleneck into register traffic. A genuinely tight strong-ish isomorphism: 32-wide warp ↔ 32-bit spike mask.
4. **Persistent-megakernel / CUDA-graph step capture (from A6).** Fuse the ~6–10 per-step kernel launches into one graph replay → delete ~5–10% launch overhead. The "Minecraft tax" applied to the host-launch layer.
5. **FP16 / `__half2` weight-and-state packing (from A6).** Halves the dominant gather traffic that dominates the step. SNN weights tolerate fp16 fine.
6. **NVRTC per-morphotype kernel specialization (from A6).** JIT a branch-free specialized kernel per neuron morphotype so "parameterize-and-evolve the neuron" is a *compile-time* fact with zero runtime warp divergence — the correct implementation of the dendritic dial.
7. **Per-neuron STDP eligibility traces, forward-only (from A2/A3/A7).** Two scalars/neuron instead of per-synapse traces + a transpose CSR — halves plastic-synapse cost.
8. **Delays-from-geometry as a desynchronizer/wave-former (from A1/S3).** The geometric delay distribution turns a blob into a medium supporting traveling waves and breaks pathological synchrony — free from the 3D embedding.
9. **Hybrid RT-near-field + coarse-grid-far-field for volume transmission (from A1).** Match the tool to the field's spectrum; don't RT a smooth stencil.
10. **Cone-restricted directional FRNN for axon guidance (from A5).** Bias growth rays by ∇morphogen for topographic maps for free.

**The three "better isomorphism" candidates, adjudicated (the completeness critic flagged that these were answered three incompatible ways):**
- **A2/A6's "dendrite = small dense net on Tensor cores"** is the sharpest *found* isomorphism ("one neuron = 5–8-layer TCN" is *literally* a dense net; Tensor cores are *literally* dense-net hardware — far more literal than spikes-as-rays). **But** it is Phase-5, off by default, because point neurons suffice for criticality.
- **A4's "spike routing = event-driven CSR SpMV"** is the correct statement of the *runtime* isomorphism ("the per-step brain is an event-driven SpMV; the whole game is making that SpMV bandwidth-efficient — not RT").
- **A1/A7's "volume transmission = ray-marched participating medium"** is the correct statement of the *per-step spatial* isomorphism (compute-the-field and render-the-field are the same march).

**Headline verdict:** the operator's spikes-as-rays instinct was *wrong for routing, right for the field and the render*. The **field-as-RT-killer-app** is the isomorphism that most deserves the RT core; the **SpMV-on-CUDA** is the isomorphism that actually runs the brain; the **dendrite-on-Tensor** is the best *found* isomorphism but is optional. All three are real; none is "the spike is the ray, every step."

---

## 4. Deliverable 7.4 — Highest-leverage decisions + biggest risks

**5 highest-leverage design decisions (get these right and the thing runs):**
1. **Spikes on the Morton-ordered edge list, not on rays.** Determines whether it runs at all. Get it wrong and you burn the whole perf budget rediscovering stored neighbors.
2. **Only somata in the BVH + the one-step-lag concurrent streams.** Determines whether RT is free or a bottleneck, and dissolves Problem #1.
3. **The five-layer homeostatic stack with cross-homeostasis + iSTDP + circuit-breaker, servoing m→0.98.** Determines whether it self-sustains or dies/seizes/soups on run 1. This is the autopilot.
4. **Point neuron (numerically-guarded Izh/AdEx) default + NMDA-keyed dendritic dial reported empirically.** Determines whether dynamics are rich enough to be brain-like and whether the neuron-complexity question gets an empirical answer.
5. **Two-factor (EDR × matching-index) hierarchical-modular growth, then freeze.** Determines whether the connectome is brain-like (not a random geometric graph) and whether criticality has a wide Griffiths target.

**5 biggest risks + concrete mitigations:**
1. **Scatter-bandwidth wall (the real bottleneck).** *Mitigation:* Morton renumbering (§3.1) + target-tile bucketing + fp16 weights + modest K (100–250) + per-neuron traces. [VALIDATE the scatter-atomic efficiency + Morton gain in Phase 1 — this number *defines* the real-time neuron count and is currently guessed at 15–60%.]
2. **Dynamics collapse / seizure / soup.** *Mitigation:* the full five-layer stack + circuit-breaker from Phase 1; start subcritical and let homeostasis climb to m=0.98; a noise floor so it can re-ignite. **Guard against soup specifically** with the acceptance battery (§7) — treat "alive but m≈0.7, no avalanches" as a FAIL, not a pass.
3. **RT field/growth being a solution in search of a problem (my own lens's falsification).** *Mitigation:* build the CUDA edge-list core first (Phases 0–2), prove it runs, add RT field/growth as Phase 3 and **A/B measure** whether it improves dynamics realism (avalanches, waves, up/down states). If it doesn't, keep RT *only* for growth+render — still a legitimate, narrower win. The architecture is falsifiable, not faith-based.
4. **Criticality doesn't survive continuous growth (the intersection of the two most aggressive grafts).** *Mitigation:* keep the trickle OFF during the watchable demo (freeze); when enabled, grow slowly relative to the fast homeostat's recovery, enter new neurons at low weight and scale them in via slow scaling, and lean on the Griffiths band. [This is unproven at scale — S3 risk #5 — hence the freeze default.]
5. **Brain-like growth may be unaffordable at scale (homophily is O(k²)/node).** *Mitigation:* use module_bias as a cheap homophily proxy; measure modularity Q / motif spectrum and only escalate to true matching-index if the proxy fails the acceptance stats. [VALIDATE — nobody has fit η/γ at 10⁶–10⁷ point-neuron scale; you'd be first.]

**Structural-plasticity allocator thrash** (secondary): ragged matrix + per-row slack + swap-with-end + periodic async CUB compaction; bound churn per step.

---

## 5. Deliverable 7.5 — Phased build path (every phase independently runnable)

**Canonical Phase-0 (the completeness critic's fork, resolved): dynamics-first WITH a cheap render.** The specialists (S3 especially) imply dynamics-first is the correct de-risking order (the stabilizer is the hard part and the most likely failure), but a cheap splat render + live m̂ readout in Phase 0 costs little and aids debugging (you *see* soup vs criticality). So the canonical path is **"tiny net + cheap splat + live σ readout, THEN make it critical."** Time estimates are deliberately omitted as un-calibrated noise; the *ordering* and the *runnable demo* per phase are what matter.

- **Phase 0 — "First light + first honesty."** N≈10⁴ numerically-guarded Izhikevich neurons, random 3D positions, distance-dependent static edge list built on CPU, CUDA integration + ring-buffer delivery, **a cheap raster point-splat render + a live on-screen m̂ readout**, and the **1-day CSR-vs-RT routing micro-benchmark** [VALIDATE B1]. *Runnable demo: a spike raster + 3D splat that is visibly neither dead nor saturated, with m̂ printed.*
- **Phase 1 — "It sustains, provably."** Add E/I 80/20, conductance synapses, iSTDP + cross-homeostasis + STD + adaptation + slow scaling + circuit-breaker + the **σ-servo**. Add Morton renumbering and **[VALIDATE the scatter efficiency gain]**. Tune to self-sustaining avalanches; run the **full acceptance battery** (§7). *Runnable demo: a network alive for ≥10⁶ steps with power-law avalanches satisfying the crackling relation — not soup.*
- **Phase 2 — "It renders (cinematic)."** OptiX single GAS over neuron spheres (somata only); the **RT sphere-trace render** (spikes as light, V as color, E/I warm/cool, LFP weather layer, sectioning planes) via CUDA↔Vulkan interop. Still CPU/CUDA growth. *Runnable demo: watch it fire in real-time 3D — the emotional-payoff milestone; get here fast.*
- **Phase 3 — "RT earns its keep (falsifiably)."** Build the CUDA cell-list growth baseline; **A/B RT-FRNN vs cell-list** on your density; move growth onto whichever wins. Add the **volume-transmission field** (RT near + grid far). **A/B against the Phase-2 baseline** to measure whether the field enriches dynamics (waves, up/down states). *Runnable demo: a field-coupled brain with measured richness gains — or an honest verdict that RT stays growth+render only.*
- **Phase 4 — "Scale + optional living growth."** Push N to millions; persistent-megakernel + NVRTC specialization + fp16 packing; enable the **bounded structural-growth trickle** (ragged + slack + compaction) *only if* criticality-during-growth validates. *Runnable demo: millions of neurons, real-time, watchable, self-organizing.*
- **Phase 5 — "The dendritic dial."** Add `K`-subunit dendritic rungs + the promote/demote probe; Tensor-batch identical-morphotype MLPs; let the sim **report the minimum `K`** the dynamics require. *Runnable demo: a network that prints its own neuron-complexity distribution — the operator's philosophical wager answered as a number.*

Each phase is a demo, de-risks the next, and the RT bet is *explicitly tested* in Phase 3 against a working non-RT baseline.

---

## 6. Deliverable 7.6 — Literature / algorithms / systems to study

**RT-core repurposing (the isomorphism's evidence base):**
- Zhu, **RTNN**, PPoPP 2022 — FRNN/kNN-as-raytracing, 2.2×–65×; sphere-per-point + short-ray trick; build:query ≈ 1:15,000.
- Nagarajan et al., **RT-DBSCAN** (2023, 1.3×–4.5×); **RT-BarnesHut** (PPoPP 2025, 5.6×–41×); **RT-kNNS Unbound / TrueKNN** (ICS 2023).
- **Advancing RT-Core-Accelerated Fixed-Radius NN Search**, arXiv:2601.15633 (2026, RTX Pro 6000 Blackwell) — the gradient refit-vs-rebuild cost model (`k_u^opt` formula, ~3.4×), and the **honest failure envelope: grid beats RT at large radius / dense clusters.** [Single recent source carrying a lot of weight — treat its specific numbers as to-be-verified.]

**Neuron models & dendritic computation (the complexity dial):**
- Izhikevich 2003 (**Simple Model**) + 2004 (**Which Model to Use?**, the FLOP/feature table); Brette & Gerstner 2005 (**AdEx**); Poirazi/Brannon/Mel 2003 (pyramidal = 2-layer net); **Beniaguev, Segev & London 2021** (L5PC ≈ 5–8-layer TCN, collapses to 1 hidden layer without NMDA — the dial's physical knob); **Gidon et al. 2020** (dendritic XOR via anti-coincidence dCaAPs).

**Criticality / stability (the autopilot — do not lose these):**
- **Beggs & Plenz 2003** (avalanches, α≈1.5, β≈2.0, σ≈1 — the setpoint); van Vreeswijk & Sompolinsky 1996 + **Brunel 2000** (the balanced-state (g, ν_ext) phase diagram — your navigation map); Sanzeni et al. 2020 (ISN widespread); Litwin-Kumar & Doiron 2012 (clustering → metastable assemblies); **Levina, Herrmann & Geisel 2007** (short-term depression → SOC, no tuning); Kinouchi & Copelli 2006 (max dynamic range at criticality); Moretti & Muñoz 2013 (**Griffiths phase** — HMN widens criticality); **Wilting & Priesemann 2018** (m̂≈0.98 + the MR estimator); Friedman et al. 2012 (**crackling-noise scaling relation** — the real criticality certificate); **Vogels et al. 2011** (iSTDP); **Zenke, Gerstner & Ganguli 2017** (the temporal-paradox — homeostasis must be fast); **Mackwood et al. PNAS 2022** (**cross-homeostasis** — the one rule that reaches the ISN regime; easy to lose, load-bearing); Zenke et al. 2015 (diverse plasticity mechanisms for stable memory); Turrigiano 2008 + Hengen et al. 2013 (synaptic scaling to a rate set-point).

**Connectome generation (grow, don't transcribe):**
- **Ercsey-Ravasz/Markov 2013** (EDR, λ≈0.188 mm⁻¹); **Betzel et al. 2016** (two-factor P∝D^η·K^γ, matching-index winner, η≈−0.98/γ≈0.42/E≈0.12); Vértes 2012; Betzel & Bassett 2017; **Akarca et al. 2024** (force-based 3D axon growth, RT-friendly); **Song et al. 2005** (lognormal weights, reciprocity, clustered motifs — the target fingerprint); Bassett et al. 2010 (**Rent's rule p≈0.75**); Kaiser & Hilgetag (spatial growth); Buzsáki & Mizuseki 2014 (the log-dynamic brain); OpenWorm (the cautionary tale — 302-neuron connectome underdetermines dynamics).

**GPU-SNN systems + memory (steal their layouts):**
- **GeNN** (Yavuz/Turner/Nowotny 2016; Knight & Nowotny 2021 — 3.5 M neurons / ~3×10¹² synapse-equiv on one Titan RTX; ragged matrix; procedural connectivity; **synapse storage is the binding constraint**); Knight et al. 2025 (**ragged + per-row slack + swap-with-end** structural plasticity); **Brian2CUDA** (Alevi et al. 2022 — YALE/CSR pre+post-indexed, synapse bundles + circular delay queues, postsynaptic partitions); **NEST-GPU / Golosio et al. 2021** (the **Potjans–Diesmann 77k-neuron / 3×10⁸-synapse @ 1× real time on a 2080 Ti** anchor; measured 25.9–34.4 B/synapse); CARLsim, NeMo, Spice. RTNN's sphere-AABB memory note ("wrapping a point as a primitive ≈ +1 order of magnitude"); OptiX 8/9 Programming Guide (`OptixAabb`, `optixAccelComputeMemoryUsage`, `ALLOW_COMPACTION`); NVIDIA RTX Best Practices (build O(100M)/s, refit O(1B)/s, AS work ≤2 ms, refit-rot warning); CUB `DeviceSelect` (stream compaction).

---

## 7. The honest scale + the acceptance instrument (quantitative bottom line)

### 7.1 Complete VRAM budget (24 GB card, the number that closes)

Per-unit (carry these): neuron state **~44 B** (per-population params); synapse **~8 B static / ~10 B plastic** (per-neuron traces); BVH AS+input **~88 B/neuron**; delay ring **~D·4 B/neuron**; I_syn + spike list + scratch **~16 B/neuron**.

**Worked point (K=1000, plastic, D=40 bins, N to solve):**
`N·(44 + 88 + 40·4 + 16) + N·1000·10 ≤ 22 GB` (2 GB headroom for framebuffers/OptiX scratch/CUB temp)
→ `N·(308 + 10000) ≤ 22×10⁹` → **N ≈ 2.1 M neurons, M ≈ 2.1 B synapses.**
- At **K=250** (more local/brain-like): **N ≈ 8 M, M ≈ 2 B.**
- At **K=100**: **N ≈ 15 M, M ≈ 1.5 B** — but bandwidth (below), not capacity, then binds.

**Delay ring buffer is a first-class line item:** 80 MB (D=20, N=10⁶) to 3.2 GB (D=200, N=4×10⁶). A1/A5 omitted it — do not. Delay-binning (coarse bins for long-range) contains it.

### 7.2 The binding constraint — proven by bandwidth arithmetic

Real time = each step ≤100 µs (dt=0.1 ms). Budget @ ~1 TB/s × 100 µs = 100 MB/step *raw*, ~50–80 MB *useful* (50–80% efficiency).
- **Dense dynamics (rate-free):** ~20 B/neuron/step RW → N=4 M ⇒ **80 MB/step** — this alone caps ~4–8 M Izhikevich neurons.
- **Sparse synaptic events (rate-∝):** at N=4 M, K=1000, r=5 Hz → S = M·r = 2×10¹⁰ events/s; ~40–70 B/event effective (streamed read + **scattered atomic RMW**, 20–40% DRAM efficiency) → ~0.8–1.4 TB/s → **~100 MB/step, the entire budget.**
- Sum at the mid point ≈ 1.8×10¹² B/s vs BW_eff 0.5–1.4×10¹² → **~1.3–3.6× over budget.**

**→ Binding constraint = synaptic-scatter memory bandwidth** (the scattered atomic RMW), NOT RT throughput, NOT BVH rebuild (<1% amortized, async), NOT FLOPs (dynamics use <1% of CUDA FLOPs). Morton renumbering (§3.1) attacks exactly this term. **The deepest point (S7): the correct dynamics ARE the cheap dynamics** — driving the net to sparse criticality (r≈1–5 Hz) is simultaneously the scientific goal and the biggest performance win; a seizing net is ~10× more expensive and self-announces by falling off real time. Stabilization engineering *is* scaling engineering.

### 7.3 The honest headline

> **On a 24 GB RTX 4090 (~1 TB/s): ~1–4 M neurons, ~1–4 B synapses, at genuine real time (1 ms wall ≈ 1 ms bio) with rich dynamics + live render. On a 32 GB RTX 5090 (~1.8 TB/s): ~2× that (~5–12 M neurons, ~3–8 B synapses).** Binding constraint: synaptic-scatter bandwidth for step-rate; synapse VRAM for size. This is far past OpenWorm (302) and competitive with/beyond published GPU-SNN scale — roughly an insect-to-small-mammal-cortical-patch, exactly as the brief anticipated ("less sophisticated than an ant's brain"). A1/A5's 10–60 M requires K≈30–100 + fp16-everything + the unproven claim that the RT field substitutes for wired synapses [not validated — discard the associated headline].

### 7.4 The acceptance battery (the instrument panel — the definition of success)

Elevate S3's battery to a first-class deliverable. "Watchable" is not enough; the bar is "provably brain-like." A network passes **iff** all hold and are *automatically verified*:
- [ ] **Balanced & ISN:** CV_ISI≈1, low pairwise correlation, paradoxical-effect-positive, E:I≈4:1, g≈4–8, fast inhibition. *(kills seizure + gives biological irregularity for free)*
- [ ] **At the edge:** MR-estimator **m̂≈0.98**; avalanche α≈1.5, β≈2.0 fit by max-likelihood + KS (Clauset–Shalizi–Newman, **not eyeballing a log-log line**), **satisfying the crackling-scaling relation (β−1)/(α−1)≈2 and avalanche shape-collapse.** *(kills the soup — a raw power law is necessary but NOT sufficient)*
- [ ] **Self-organized & held there:** ≥2 homeostatic controllers on separated timescales (fast STD/adaptation + slow scaling) + iSTDP + cross-homeostasis, all acting on weights/intrinsic state; the edge survives weight drift and connectome growth. *(kills silence + drift)*
- [ ] **Spatially/modularly structured:** distance-dependent + heavy-tailed + hierarchical-modular connectivity with geometric delays → travelling waves, nested oscillations, metastable assembly switching; measured small-world index, modularity Q, Rent p reported per epoch. *(makes it recognizably brain-like, not a uniform critical gas; buys the Griffiths band)*

**The legibility test (Section-5 bar):** with the §2.7 encodings, a knowledgeable observer distinguishes dead / saturated / soup / critical *by eye*, corroborated by the on-screen m̂ + avalanche-histogram overlay. Each recognizable phenomenon has both a generative mechanism and a visual signature: **traveling wave** = distance-delayed local propagation (light sweeping the cloud); **avalanche** = scale-free cascade (histogram power law + a visible burst); **up/down state** = adaptation + clustered-E metastability (LFP weather layer breathing); **assembly switch** = Litwin-Kumar–Doiron slow transition (a cluster igniting as another fades).

---

## 8. The honest bottom line

The operator's instincts are ~80% right, and the wrong 20% is the *most important* 20%: **spikes do not route by rays** — uncorrected, that misconception sinks the perf budget. Corrected, the maximalist thesis sharpens rather than dies. The RT core's rightful, per-step, load-bearing jobs are **the field (volume transmission), the growth trickle, and the render** — three genuinely-3D, edge-list-impossible operations that run concurrently in the shadow of the bandwidth-bound CUDA dynamics sweep. Spikes ride the Morton-ordered edge list on CUDA; the brain's *space* rides the rays. That is a real throne, defensible with numbers (bandwidth-bound at ~0.3–0.5 ms/step for a few million neurons; VRAM-bound at ~1–4 B synapses on a 4090; RT free-riding underneath). Hold it at slightly-subcritical m≈0.98 with cross-homeostasis + iSTDP + a fast RCP + slow scaling + a circuit-breaker so it self-sustains *on run 1* and never seizes, silences, or soups; grow it with exponential-distance × matching-index over a hierarchical-modular seed so it is a brain and not a random geometric graph; freeze the geometry so the BVH is nearly free; and watch it think because computing its field and seeing its glow are, at last, the same traversal of the same geometry in the same memory. It will be less than an ant — and it will be, provably and visibly, alive.
