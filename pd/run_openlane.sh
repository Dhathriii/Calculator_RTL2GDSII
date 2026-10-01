#!/usr/bin/env bash
# =============================================================
# run_openlane.sh
# Runs the full RTL -> GDSII flow (synthesis, floorplan, placement,
# CTS, global+detailed routing, GDS streamout, DRC/LVS signoff)
# for calculator_top using OpenLane 2 (the Docker/Nix-installed,
# python "flow.tcl"-free version). Requires OpenLane + the sky130
# PDK to already be installed - see docs/README.md.
#
# Usage:  cd pd && ./run_openlane.sh
# =============================================================
set -e

# Path to your OpenLane checkout / the 'openlane' CLI wrapper.
# With the OpenLane2 pip/nix install, 'openlane' is just on PATH.
openlane --pdk sky130A ./config.json

# Results land in pd/runs/<timestamp>/ :
#   runs/<ts>/results/synthesis/calculator_top.v        (gate-level netlist)
#   runs/<ts>/results/final/gds/calculator_top.gds       <-- the GDSII layout
#   runs/<ts>/results/final/def/calculator_top.def
#   runs/<ts>/reports/                                   (timing/area/DRC/LVS)
echo "Done. Final GDSII (if the run completed clean) is under:"
echo "  pd/runs/<latest_timestamp>/results/final/gds/calculator_top.gds"
