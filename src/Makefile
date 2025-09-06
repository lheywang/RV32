# =====================================================================
# Simple makefile to compile and simulate all of the VHDL designs.
# =====================================================================

# =====================================================================
# VARIABLES
# =====================================================================
# Simulation duration
LEN = 1ms

# VHDL sources (only used for syntax checking and compilation)
VHDLSRC = 	components/alu/alu.vhd
VHDLSRC += 	components/decoder/decoder.vhd
VHDLSRC += 	components/register/register.vhd
VHDLSRC += 	rv32.vhd

VHDLTOP = 	rv32 # Set here the top name. Not the file name !

# Simuluation output file
WAVEFILE = 	../build/wave.ghw
WORKDIR = ../build

# Get the build files
VHDLBUILD = $(foreach FILE, VHDLSRC, build/FILE)

# Syntax and build helpers...
syntax:
	@mkdir -p ${WORKDIR}
	ghdl -s $(VHDLSRC)

compile:
	@mkdir -p ${WORKDIR}
	ghdl -a -v --workdir=${WORKDIR} $(VHDLSRC)
	
# Elaboration and runing
elaborate: compile
	ghdl -m -v --workdir=${WORKDIR} $(VHDLTOP)

simulate: elaborate
	ghdl -r -v --workdir=${WORKDIR} $(VHDLTOP) --wave=$(WAVEFILE) --stop-time=$(LEN)

show: simulate
	gtkwave $(WAVEFILE)

all: elaborate simulate show

clean:
	@rm -f *.o
	@rm -f $(VHDLTOP)
	@rm -f *.cf
	@rm -f *.ghw
	@rm -rf ${WORKDIR}