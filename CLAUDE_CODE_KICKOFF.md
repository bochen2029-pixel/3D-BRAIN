# Claude Code — Session 0 Kickoff Prompt

> Paste this as your **first message** to Claude Code, opened in `C:\3D-BRAIN`.
> Fill in the one blank (your GPU) before sending.

---

You are my engineering partner on an **existing** CUDA codebase in this directory. We work **contract-first**: the canon is law, changes are small and test-gated, and you never invent scope. **Read before you touch. Do not write or build anything until I confirm Steps 1–2.**

## Step 1 — Absorb the canon (READ ONLY, no edits)
Read these and hold them as the source of truth:
- **`MODULE.md`** — the Phase-0 contract: system intent, glossary, invariants **I1–I5**, kernel boundaries, and the **Gate B acceptance battery** that *defines* "done." This governs all Phase-0 work.
- **`FINAL_BLUEPRINT.md`** (~60 KB) — the full multi-phase north star. **Skim, don't memorize**: extract only (a) the one-sentence architecture, (b) the phase map, and (c) the "deferred to Phase 2+" list. It's context, not the current work order — don't hold it all in working context.
- **`README.md`** — build/run.
- **`include/brain.h`** — the **frozen contract surface** (SoA state, CSR, kernel signatures). If your code and `brain.h` ever disagree, `brain.h` wins.
- **`include/config.h`** — the `[KNOB]` values; Gate B is a *sweep* over these.
- **`src/*.cu`, `tools/analyze.py`** — the implementation.

Then summarize back to me in **≤15 lines**: the one-sentence architecture, the 5 invariants, what Gate B requires to PASS, and what is explicitly **NOT** in Phase 0. **Stop and wait for my confirmation.**

## Step 2 — Establish our working agreement (create persistence)
Create two files at the project root:
- **`CLAUDE.md`** — loaded first every future session. It must state: (a) the canon pointers above + "**`brain.h` and the `MODULE.md` invariants are law**"; (b) the **phase fence** — RT cores, Morton reordering, structural growth, real-time GL render, and dendritic/AdEx/Tensor units are **Phase 2+**; adding any of them now is a scope violation you must **refuse and flag**; (c) the **session protocol** — each session: *state intent → propose a change manifest (files touched, any contract change, the verification, diff budget ≤ ~300 LOC) → implement → verify against Gate B → append to `SESSION_LOG.md` → stop*; (d) **definition of done = the Gate B battery in `MODULE.md`, verified by `tools/analyze.py`, never by vibes.**
- **`SESSION_LOG.md`** — seed it with today's entry (Session 0: orientation + toolchain + first build).

## Step 3 — Verify the toolchain
This code was authored **without a GPU to compile on**, so the first build is a shakedown. Report `nvcc --version` and `cmake --version`, detect my GPU and its compute capability, and set `CMAKE_CUDA_ARCHITECTURES` accordingly. **My card is: __________ (fill in; 4090→89, 5090→120, 3090→86). Do not guess the arch — detect it or ask.**

## Step 4 — Build (Release)
Configure and compile. **Fix only what's needed to compile.** Likely nits: the `curand` link, the CUDA arch, a missing header include, or a signature mismatch against `brain.h`. **Any fix that would change a contract in `brain.h` or an invariant in `MODULE.md`: STOP and show me the diff + rationale before applying.** Show me the first clean build.

## Step 5 — First run = the first Gate B scorecard
Run `brain_phase0`, then `python tools/analyze.py`. Report: steps/sec + real-time factor, mean firing rate, **`m̂`**, the avalanche fit (**τ, KS**), and the pass/fail scorecard. Show me `criticality.png`. Interpret honestly — is it **dead** (`m̂→0`, silent), **seizing** (`m̂>1`, saturated), **soup** (power law fails), or **near-critical**?

## Step 6 — Set up the sweep (never tune blind)
Gate B is a sweep over the `config.h` `[KNOB]`s, so build a small harness: a script that overrides selected knobs (compile-time `-D` defines or a tiny runtime config), runs, parses the `analyze.py` scorecard, and appends one row per run to `sweep_log.csv` (knob values → `m̂`, τ, rate, RT-factor). Based on run 1's failure mode, propose the first 3–5 settings to try (silent → raise excitation/external drive; seizing → raise inhibition/`ISTDP_ETA`) and log each. **Goal: walk `m̂` toward 0.98 with τ≈1.5, KS<0.1, self-sustaining for the full 20 s.**

## Standing rules (apply every session)
Small diffs. Verify every change against the Gate B battery. `brain.h` and `MODULE.md` are law. **Refuse Phase-2+ scope creep and tell me when I ask for it.** When unsure about my hardware or a contract, **ask rather than guess**. Update `SESSION_LOG.md` at the end of every working session. Do not add the real-time renderer or RT/Morton scaling until Gate B has passed — **we do not scale a corpse.**
