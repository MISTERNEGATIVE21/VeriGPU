# Metrics

We measure the following:
- combinatorial propagation delay: how long does it take for combinatorial logic to settle between clock ticks
    - this strongly influences the maximum clock speed possible
- cycle count: how many clock ticks does it take for some sample programs
- area: how much die area will be used, which relates to tape-out cost, and yield

## Continuous Integration (CI)

[![CircleCI](https://circleci.com/gh/hughperkins/VeriGPU/tree/main.svg?style=svg)](https://circleci.com/gh/hughperkins/VeriGPU/tree/main)

The CI server runs the following metrics scripts:
- timing: [/cicd/run-timing.sh](/cicd/run-timing.sh).

## Combinatorial propagation delay

We run timing metrics based on the gate-level netlist that we obtain by running synthesis down to cell level using [yosys](https://yosyshq.net/yosys/). This netlist has converted the various behavioral notation, such as `always` and `if` into combinatorial gates and flip-flops. We then assign a weight to each cell, according to the delay it represents, and find the longest path between flip-flop outpus and inputs, and also between module inputs and flip-flops, flip-flops and module outputs, and module inputs and outputs. The combinatorial propagation delay is the sum of the cell delays along this longest path. We measure the propagation delay in `nand gate units`: the propagation delay for a single `nand` gate.

### Latest results

You can see the current clock cycle propagation delay by opening the most recent build at [verigpu circleci](https://app.circleci.com/pipelines/github/hughperkins/verigpu?branch=main&filter=all), opening the `run-timing` job, going to 'artifacts', and clicking on 'build/timing-proc.txt'. As of writing this, it was 110 nand gate units, i.e. equivalent to passing through about 110 nand units.
- at 90nm, one nand gate unit is about 50ps, giving a cycle time of about 5.5ns, and a frequency of about 200MHz
- at 5nm, one nand gate unit is about 5ps, giving a cycle time of about 0.55ns, and a frequency of about 2GHz
(Note: this analysis totally neglects layout, i.e. wire delay over distance, so it's just to give an idea).

### Details

- we first use [yosys](https://yosyshq.net/yosys/) to synthesize our verilog file to a gate-level netlist
    - a gate-level netlist is also a verilog file, but with the behavioral bits (`always`, etc.) removed, and operations such as `+`, `-` etc all replaced by calls to standard cells, such as `NOR2X1`, `NAND2X1`, etc
- then we use a custom script [verigpu/timing.py](/verigpu/timing.py) to walk the graph of the resulting netlist, and find the longest propagation delay from the inputs to the outputs
    - the delay units are in `nand` propagation units, where a `nand` propagation unit is defined as the time to propagate through a single nand gate
    - a NOT gate is 0.6
    - an AND gate is 1.6 (it's a NAND followed by a NOT)
    - we assume that all cells only have a single output currently
- the cell propagation delays are loosely based on those in Synopsys Educational Design Kit 90nm, which used to be available at web.engr.oregonstate.edu/~traylor/ece474/reading/SAED_Cell_Lib_Rev1_4_20_1.pdf , but seems to be no longer available. It is/was a 90nm spec sheet, but could be representative of relative timings, which are likely architecture-independent. Note: if you can find an alternative open cell design kit, please let me know
- you can see the relative cell times we use at the top of [verigpu/timing.py](/verigpu/timing.py), in the global dict `g_cell_times`

### Prerequities

- python3
- [yosys](https://yosyshq.net/yosys/)

### Procedure

e.g. for the module at [prot/int/add/add_one_2chunks.sv](/prot/int/add/add_one_2chunks.sv), run:

```
python verigpu/timing.py --in-verilog prot/add_one_2chunks.sv
# optionally can use --cell-lib to specify path to cell library. By default will use osu018 cell library in `tech/osu018` folder
```

### Example outputs

```
# pure combinatorial models:
$ python verigpu/timing.py --in-verilog prot/add_one.sv 
output max delay: 37.4 nand units
$ python verigpu/timing.py --in-verilog prot/add_one_chunked.sv 
output max delay: 27.2 nand units
$ python verigpu/timing.py --in-verilog prot/add_one_2chunks.sv 
output max delay: 24.6 nand units
$ python verigpu/timing.py --in-verilog prot/mul.sv 
output max delay: 82.8 nand units
$ python verigpu/timing.py --in-verilog prot/div.sv 
output max delay: 1215.8 nand units

# flip-flop modules:
$ python verigpu/timing.py --in-verilog prot/clocked_counter.sv 
max propagation delay: 37.4 nand units

# the processor module itself :)
$ python verigpu/timing.py --in-verilog src/proc.sv
max propagation delay: 101.6 nand units
```

## Cycle count

We run example programs, using behavioral-level simulation, and measure how many clock cycles are taken from the time that reset turns off, until `HALT` is called.

### Results

- you can see the latest results by going to [CircleCI main branch builds](https://app.circleci.com/pipelines/github/hughperkins/verigpu?branch=main&filter=all), opening the latest build, openng the `run-timing` job, going to 'artifacts', and opening `build/clock-cycles.txt`. At the time of writing this looks like:

```
prog2 cycle_count 658
prog3 cycle_count 1384
prog4 cycle_count 196
prog5 cycle_count 658
prog6 cycle_count 592
prog7 cycle_count 1120
prog8 cycle_count 493
prog9 cycle_count 295
prog10 cycle_count 625
prog11 cycle_count 1450
prog12 cycle_count 856
prog13 cycle_count 1021
prog14 cycle_count 823
prog15 cycle_count 1021
prog16 cycle_count 1153
prog17 cycle_count 361
prog18 cycle_count 592
prog19 cycle_count 955
prog20 cycle_count 1978
prog21 cycle_count 592
prog22 cycle_count 761
cycle count is number of clock cycles from reset going low, to halt received.

total 17584
avg 837.3
```

`progxx` refers to one of the example programs in [examples/direct](/examples/direct). These cycle counts are currently long because:
- we don't have data memory caching
- we don't have instruction memory caching
- we don't have parallel execution, either for memory feteches, or for maths operations such as division

### Pre-requisites

- have `python3` installed, and in the `PATH`
- have `iverilog` installed, and in the `PATH`
- have cloned this repository, and be in the root directory of this repo

### Procedure

```
python test/timing/get_prog_cycles.py
```

## Area

We measure area by synthesizing to a gate-level netlist, using yosys, counting the number of each cell type, and converting the cell types into an approximate number of nand gate area units. For example 4 nand gate cells would be 4 nand gate units. 3 flip flops is around 18 nand gate units. The approximate nand gate area equivalent of each cell is in the variable `g_cell_areas` at the top of [verigpu/timing.py](/verigpu/timing.py).

We use the same script as for delay propagation measurements. In order to obtain delay propagation measurements, we already need to synthesize down to a gate-level netlist, so we add some additional scripting to the end to output the nand gate area units. The script is [verigpu/timing.py](/verigpu/timing.py). See the section on propagation delay above for prerequisites and procedure.
