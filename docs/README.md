# 4-Function Calculator: RTL → GDSII

A complete, from-scratch hardware calculator (add / subtract / multiply / divide)
taken all the way from Verilog RTL to a manufacturable GDSII layout, using a
100% open-source toolchain (Icarus Verilog, Yosys, OpenLane/OpenROAD, Magic,
KLayout, SkyWater sky130 PDK).

**Important honesty note:** this project was written in a sandboxed environment
with no EDA tools installed and no internet access, so none of the commands
below have been *executed* here — I could not hand you a simulation log, a gate
count, or an actual `.gds` file from this chat. What you have is a complete,
carefully hand-verified design (I traced every algorithm by hand — see the
comments in each `.v` file) plus every script needed to run and verify it
yourself in ~20 minutes on a machine with the tools installed. Section 7 tells
you exactly how to get those tools.

---

## 1. Architecture

```
                        ┌─────────────────────┐
                        │   calculator_top     │
   clk, rst_n ─────────►│                     │
   start, opcode[1:0] ──►   FSM: IDLE/MUL/DIV   │──► result[2W-1:0]
   a[W-1:0], b[W-1:0] ──►                       │──► remainder[W-1:0]
                        │  ┌────────────────┐   │──► busy, done
                        │  │ adder_subtractor│──┤──► div_by_zero, overflow
                        │  │ (1 cycle)       │   │
                        │  ├────────────────┤   │
                        │  │ multiplier     │   │
                        │  │ (W cycles,     │   │
                        │  │  shift-add)    │   │
                        │  ├────────────────┤   │
                        │  │ divider        │   │
                        │  │ (W cycles,     │   │
                        │  │  restoring)    │   │
                        │  └────────────────┘   │
                        └─────────────────────┘
```

Every arithmetic unit bottoms out on one verified building block:

```
full_adder  ──►  ripple_carry_adder (N-bit, structural, generate-for loop)
                        │
                        ├──► adder_subtractor  (add & sub share the same adder;
                        │                       sub = XOR the b operand + cin=1,
                        │                       i.e. two's-complement subtraction)
                        │
                        ├──► multiplier        (sequential shift-add; each cycle
                        │                        conditionally adds via the same
                        │                        ripple_carry_adder, then shifts)
                        │
                        └──► divider           (sequential restoring division;
                                                 each cycle does a trial subtract
                                                 via adder_subtractor and restores
                                                 on borrow)
```

opcode: `00`=ADD, `01`=SUB, `10`=MUL, `11`=DIV. WIDTH is a Verilog parameter,
default 8 (change `WIDTH` in `calculator_top` to resize — 16/32-bit all work
with zero RTL changes, just more area/cycles).

Files:
```
rtl/
  full_adder.v          1-bit full adder (gate equations)
  ripple_carry_adder.v  N-bit adder, structural, built from full_adder
  adder_subtractor.v    add/sub combo unit (reuses ripple_carry_adder)
  multiplier.v          sequential shift-add multiplier, W cycles
  divider.v             sequential restoring divider, W cycles
  calculator_top.v       top-level FSM + opcode mux
tb/
  tb_addsub.v           self-checking: full_adder + adder_subtractor
  tb_multiplier.v       self-checking, directed + 100 random vectors
  tb_divider.v          self-checking, directed + random, incl. div-by-0
  tb_calculator_top.v    full integration test, all 4 ops, random + directed
synth/
  synth_generic.ys      tech-independent Yosys synth (sanity/gate-count check)
  synth_sky130.ys       Yosys synth targeting sky130_fd_sc_hd standard cells
pd/
  config.json           OpenLane 2 flow config (floorplan → GDSII)
  run_openlane.sh        wrapper to launch the OpenLane flow
  src/calculator_top.sdc timing constraints (clock period, I/O delays)
```

---

## 2. Stage 1 — RTL design

Done: the six files under `rtl/`. Design choices worth knowing:

- **Adder**: plain ripple-carry, structural (not `assign sum = a+b`), so the
  gate structure is explicit and every stage is a `full_adder` instance —
  this is what makes it obvious how it maps to standard cells later.
- **Subtractor**: no separate subtractor hardware. `a - b` reuses the adder by
  computing `a + (~b) + 1` (two's complement), controlled by one `sub` bit.
  `cout` doubles as the *no-borrow* flag when subtracting — the divider
  depends on this.
- **Multiplier**: sequential shift-and-add (not a big combinational array),
  because it (a) is trivially provable correct by hand, (b) reuses the same
  adder module instead of a second untested datapath, and (c) keeps
  combinational depth — and therefore layout timing closure — easy. Cost:
  WIDTH clock cycles instead of 1. If you need a 1-cycle multiplier instead
  (bigger, faster), swap in a Wallace-tree/array multiplier — happy to do
  that as a follow-up once this baseline is verified.
- **Divider**: restoring division, sequential, WIDTH cycles, with a
  `div_by_zero` flag (returns quotient=all-1s and remainder=dividend on
  divide-by-zero rather than looping forever or corrupting state).

---

## 3. Stage 2 — Functional verification (simulation)

Requires **Icarus Verilog** (`iverilog`/`vvp`) — see §7 for install.

```bash
cd calculator_rtl2gds

# 1. Adder / subtractor (exhaustive + 200 random vectors)
iverilog -o sim_addsub tb/tb_addsub.v rtl/full_adder.v \
         rtl/ripple_carry_adder.v rtl/adder_subtractor.v
vvp sim_addsub

# 2. Multiplier (directed + 100 random vectors)
iverilog -o sim_mul tb/tb_multiplier.v rtl/full_adder.v \
         rtl/ripple_carry_adder.v rtl/multiplier.v
vvp sim_mul

# 3. Divider (directed + 100 random vectors, incl. div-by-zero)
iverilog -o sim_div tb/tb_divider.v rtl/full_adder.v \
         rtl/ripple_carry_adder.v rtl/adder_subtractor.v rtl/divider.v
vvp sim_div

# 4. Full integration (all 4 ops through the top-level FSM)
iverilog -o sim_top tb/tb_calculator_top.v rtl/full_adder.v \
         rtl/ripple_carry_adder.v rtl/adder_subtractor.v \
         rtl/multiplier.v rtl/divider.v rtl/calculator_top.v
vvp sim_top
```

Each testbench is self-checking: it computes the expected result in plain
Verilog (`a+b`, `a*b`, `a/b`, `a%b`, ...) and prints `FAIL ...` lines with the
mismatch, ending in `ALL PASS` or `N FAILURES`. `tb_multiplier.v` and
`tb_calculator_top.v` also dump a `.vcd` waveform — open with:
```bash
gtkwave calculator_top.vcd
```
to see the FSM stepping through `S_MUL`/`S_DIV` cycle by cycle.

---

## 4. Stage 3 — Logic synthesis (RTL → gate-level netlist)

**(a) Quick technology-independent check** (no PDK required):
```bash
yosys -s synth/synth_generic.ys
```
Prints a `stat` report — number of cells, flip-flops, wires — a fast way to
catch RTL bugs (latches, unexpected width mismatches) before touching a PDK.

**(b) Real synthesis onto sky130 standard cells:**
```bash
export PDK_ROOT=~/.volare          # wherever your sky130A install lives
export LIBERTY=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
yosys -D LIBERTY=$LIBERTY -s synth/synth_sky130.ys
```
Output: `synth/out/calculator_top_sky130_netlist.v` — the gate-level netlist,
plus a cell-count/area `stat` report right in the terminal.

(OpenLane actually re-runs its own internal synthesis step with the same
Yosys underneath when you do the full flow in §5 — running it standalone
here first is just a fast way to catch problems early.)

---

## 5. Stage 4 — Physical design (floorplan → placement → CTS → routing → GDSII)

This is the "work till its layout" part. Use **OpenLane 2** (wraps Yosys +
OpenROAD + Magic + KLayout into one push-button flow) targeting **sky130**:

```bash
cd pd
./run_openlane.sh
# or directly:
openlane --pdk sky130A ./config.json
```

What happens, stage by stage (all inside OpenLane, all automated):
1. **Synthesis** – RTL → gate-level netlist (Yosys + ABC, same as §4b)
2. **Floorplanning** – die/core area sized from `FP_CORE_UTIL` (40% util
   here — generous, so routing congestion is unlikely at this small size),
   power rings/straps (VDD/VSS) placed
3. **Placement** – global placement (RePLace-based) then detailed placement
   (legalization) of every standard cell onto sites
4. **Clock Tree Synthesis (CTS)** – buffers/inverters inserted so `clk`
   reaches every flip-flop (in `multiplier`, `divider`, `calculator_top`'s
   FSM) within the skew target (`CTS_TARGET_SKEW`)
5. **Global + detailed routing** – OpenROAD's FastRoute + TritonRoute wire
   every net in the metal stack
6. **Parasitics extraction + STA sign-off** – real RC-based timing check
   against `pd/src/calculator_top.sdc` (20 ns / 50 MHz here — very relaxed
   for a design this small, so it should close easily; tighten it once it
   passes to see how far it can go)
7. **DRC** (Magic) – design-rule clean check against the sky130 rule deck
8. **LVS** (Magic/netgen) – layout-vs-schematic, confirms the transistors in
   the GDS match the synthesized netlist
9. **GDSII streamout** – the actual layout file

Final artifacts land under:
```
pd/runs/<timestamp>/results/final/gds/calculator_top.gds   <- the GDSII
pd/runs/<timestamp>/results/final/def/calculator_top.def
pd/runs/<timestamp>/reports/                                 timing/area/DRC/LVS
```

View the layout:
```bash
klayout pd/runs/<timestamp>/results/final/gds/calculator_top.gds
```

---

## 6. What to check when it comes back

- `reports/synthesis/1-synthesis.stat.rpt` — cell count, area
- `reports/placement/.../placement.log` — utilization achieved
- `reports/cts/.../cts.log` — clock skew achieved vs. `CTS_TARGET_SKEW`
- `reports/signoff/.../drc.rpt` — should say 0 violations
- `reports/signoff/.../lvs.rpt` — should say netlists match
- `reports/signoff/.../*.sta.rpt` — should show 0 (or small, tunable) setup
  violations at the 20 ns clock; if it's very slack, shrink `CLOCK_PERIOD`
  in both `config.json` and `calculator_top.sdc` and re-run to push it faster

If DRC/LVS/STA come back clean, `calculator_top.gds` is a legitimate,
tapeout-shaped layout of this exact calculator (modulo the usual final review
any real tapeout needs — antenna rules, IO ring/pads if this were a full
chip rather than a macro, etc.).

---

## 7. Installing the tools (one-time)

- **Icarus Verilog**: `sudo apt install iverilog gtkwave` (Ubuntu/Debian) or
  `brew install icarus-verilog` (macOS)
- **Yosys**: `sudo apt install yosys`, or build from
  https://github.com/YosysHQ/yosys
- **OpenLane 2 + sky130 PDK** (the biggest install): follow
  https://openlane2.readthedocs.io/en/latest/getting_started/index.html —
  it uses **Nix** or **Docker** to pull a pinned, reproducible tool set
  (OpenROAD, Magic, KLayout, Netgen) plus `volare` to fetch the sky130A PDK.
  Typical quick path:
  ```bash
  pip install openlane
  openlane --pdk-root ~/.volare --smoke-test     # sanity-checks the install
  ```
- **Magic / KLayout** standalone (if you want to poke at the GDS manually):
  `sudo apt install magic klayout`

---

## 8. Extending this

- Swap `multiplier.v` for a combinational array/Wallace-tree multiplier if
  you need 1-cycle latency instead of WIDTH cycles (trade-off: more area,
  harder timing closure, more standard cells).
- Swap `divider.v` for a non-restoring or SRT divider for higher throughput.
- Add a register file / instruction decoder in front of `calculator_top` to
  turn this into a tiny ALU inside an actual CPU datapath.
- Change `WIDTH` (single parameter) to retarget 16-bit or 32-bit — everything
  below `calculator_top` is fully parameterized and needs no other edits.
