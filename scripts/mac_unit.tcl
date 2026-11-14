#run Genus in Legacy UI if Genus is invoked with Common UI
::legacy::set_attribute common_ui false / ;
if {[file exists /proc/cpuinfo]} {
sh grep "model name" /proc/cpuinfo
sh grep "cpu MHz" /proc/cpuinfo
}
puts "Hostname : [info hostname]"
##############################################################################
### Preset global variables and attributes
##############################################################################
set DESIGN mac_unit

# UPDATED: Effort levels set to high for optimum PPA
set SYN_EFF high
set MAP_EFF high
set OPT_EFF high

# Directory of PDK
set pdk_dir /home/cad/VLSI2Lab/Digital/library/
set_attribute init_lib_search_path $pdk_dir

##Set synthesizing effort for each synthesis stage
set_attribute syn_generic_effort $SYN_EFF
set_attribute syn_map_effort $MAP_EFF
set_attribute syn_opt_effort $OPT_EFF

set_attribute library "\
slow_vdd1v0_basicCells.lib"

set_dont_use [get_lib_cells CLK*]
set_dont_use [get_lib_cells SDFF*]
set_dont_use [get_lib_cells DLY*]
set_dont_use [get_lib_cells HOLD*]

####################################################################
### Load Design
#####################################################################
read_hdl "${DESIGN}.v"
elaborate $DESIGN
puts "Runtime & Memory after 'read_hdl'"
time_info Elaboration
check_design -unresolved
####################################################################
### Constraints Setup
#####################################################################
# This reads your optimum SDC (2ns In, 0.1ns Out, 50% Duty Cycle)
read_sdc mac_unit.sdc

report timing -encounter >> reports/${DESIGN}_pretim.rpt

####################################################################################################
### Synthesizing to generic
####################################################################################################
syn_generic
puts "Runtime & Memory after 'syn_generic'"
time_info GENERIC
report datapath > reports/${DESIGN}_datapath_generic.rpt
generate_reports -outdir reports -tag generic
write_db -to_file ${DESIGN}_generic.db
report timing -encounter >> reports/${DESIGN}_generic.rpt

##This synthesizes your code to technology mapped gates
synthesize -to_mapped

## This writes all your files
write -mapped > mac_unit_synth.v

## THESE FILES ARE NOT REQUIRED, THE SDC FILE IS A TIMING FILE
write_script > script