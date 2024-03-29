# htu21d-spin Makefile - requires GNU Make, or compatible
# Variables below can be overridden on the command line
#	e.g. make TARGET=HTU21D_SPIN HTU21D-Demo.binary

# P1, P2 device nodes and baudrates
#P1DEV=
P1BAUD=115200
#P2DEV=
P2BAUD=2000000

# P1, P2 compilers
#P1BUILD=openspin
P1BUILD=flexspin --interp=rom
P2BUILD=flexspin -2

# For P1 only: build using the bytecode or PASM-based I2C engine
# (independent of overall bytecode or PASM build)
#TARGET=HTU21D_SPIN
TARGET=HTU21D_PASM

# Paths to spin-standard-library, and p2-spin-standard-library,
#  if not specified externally
SPIN1_LIB_PATH=-L ../spin-standard-library/library
SPIN2_LIB_PATH=-L ../p2-spin-standard-library/library


# -- Internal --
SPIN1_DRIVER_FN=sensor.temp_rh.htu21d.spin
SPIN2_DRIVER_FN=sensor.temp_rh.htu21d.spin2
CORE_FN=core.con.htu21d.spin
# --

# Build all targets (build only)
all: HTU21D-Demo.binary HTU21D-Demo.bin2

# Load P1 or P2 target (will build first, if necessary)
p1demo: loadp1demo
p2demo: loadp2demo

# Build binaries
HTU21D-Demo.binary: HTU21D-Demo.spin $(SPIN1_DRIVER_FN) $(CORE_FN)
	$(P1BUILD) $(SPIN1_LIB_PATH) -b -D $(TARGET) HTU21D-Demo.spin

HTU21D-Demo.bin2: HTU21D-Demo.spin2 $(SPIN2_DRIVER_FN) $(CORE_FN)
	$(P2BUILD) $(SPIN2_LIB_PATH) -b -2 -D $(TARGET) -o HTU21D-Demo.bin2 HTU21D-Demo.spin2

# Load binaries to RAM (will build first, if necessary)
loadp1demo: HTU21D-Demo.binary
	proploader -t -p $(P1DEV) -Dbaudrate=$(P1BAUD) HTU21D-Demo.binary

loadp2demo: HTU21D-Demo.bin2
	loadp2 -SINGLE -p $(P2DEV) -v -b$(P2BAUD) -l$(P2BAUD) HTU21D-Demo.bin2 -t

# Remove built binaries and assembler outputs
clean:
	rm -fv *.binary *.bin2 *.pasm *.p2asm

