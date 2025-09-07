# ==============================================================================================
# file :                                ghdl.py
#
# usage :       Provide an handler to the GHDL command interface to automate the builds
#               and simulations processes. It can be seen as an automated Makefile, with
#               auto-detection of files and so.
#
# author :      l.heywang <leonard.heywang@proton.me>
# date :        07-09-2025
# ==============================================================================================

# Libs
import pathlib
import subprocess


# ----------------------------------------------------------------------------------------------
# Function definitions
# ----------------------------------------------------------------------------------------------
# List all vhd files. (Does a support for other extensions is required ?)
def list_files(base_folder: pathlib.Path) -> list[pathlib.Path]:
    p = base_folder.glob("**/*.vhd")
    return [x for x in p if x.is_file()]


def set_len():
    default_len = [
        "10ns",
        "100ns",
        "500ns",
        "1us",
        "10us",
        "100us",
        "1ms",
        "custom",
    ]

    # Prints
    print("=" * 100)
    print(" Please select the lenght of the simulation ?")
    print("=" * 100)

    format_len = len(str(len(default_len)))
    for index, file in enumerate(default_len):
        print(
            f"[{(index + 1):0{format_len}}/{len(default_len):0{format_len}}] - {str(file)}"
        )

    while True:
        try:
            len_id = int(input("Which duration ? "))
            if len_id > len(default_len):
                print("Please enter a valid duration !")
                continue
            else:
                break
        except ValueError:
            print("Please enter an integer !")

    global LEN
    if len_id != len(default_len):
        LEN = default_len[len_id - 1]
        return

    LEN = input(
        "Enter the len of the custom simulation ? (no space between number and unit !! -> X : 100 ms; Y = 100ms) "
    )
    return


def set_top(files: list[pathlib.Path]):
    # First, fetch all files and sort them
    available_top = []

    # Fetch file that are located on root folder, or end up with _tb.vhd notation. Make selection easier !
    for file in files:
        if file.name.endswith("_tb.vhd"):
            available_top.append(file)
        if str(file.parent) == BASE_DIR:
            available_top.append(file)

    # Prints
    print("=" * 100)
    print(" Please select a top file to be simulated :")
    print("=" * 100)
    format_len = len(str(len(available_top)))
    for index, file in enumerate(available_top):
        print(
            f"[{(index + 1):0{format_len}}/{len(available_top):0{format_len}}] - {str(file)}"
        )

    while True:
        try:
            file_id = int(input("Which file is the top entity ? "))
            if file_id > len(available_top):
                print("Please enter a valid file !")
                continue
            else:
                break
        except ValueError:
            print("Please enter an integer !")

    global TOP
    TOP = available_top[file_id - 1].name.split(".")[0]
    return


# ----------------------------------------------------------------------------------------------
# Configuration variables
# ----------------------------------------------------------------------------------------------

# Configurations variables
# Theses are fixed and can't be changed
WORKDIR = "build/"
GHDL_CMD = "ghdl "
GTKWAVE_CMD = "gtkwave "
BASE_DIR = "src"
# Theses are fixed, but are prompted for changes. --> This is default values only
LEN = "100ns"  # Default len. Can be changed in the prompt
TOP = "rv32"

# Auto generated variables
WAVEFILE = WORKDIR + "wave.ghw"
PRESENTATION = WORKDIR + "signals.gtkw"

# ----------------------------------------------------------------------------------------------
# Script start
# ----------------------------------------------------------------------------------------------
print("=" * 100)
print(" GHDL Python interface. Here we go !")
print("=" * 100)

# Fetch files on the folder
p = pathlib.Path(BASE_DIR)
u = list_files(p)

# User inputs
set_len()
set_top(u)

# Create the commands arguments
filenames = ""
for file in u:
    filenames = filenames + f" {str(file)}"

# Build some commands
GHDL_COMPILE = GHDL_CMD + "-a " + f"--workdir={WORKDIR} " + filenames

GHDL_ELABORATE = GHDL_CMD + "-m " + f"--workdir={WORKDIR} " + TOP
GHDL_SIMULATE = (
    GHDL_CMD
    + "-r "
    + f"--workdir={WORKDIR} "
    + TOP
    + f" --wave={WAVEFILE} "
    + f"--stop-time={LEN}"
)
GTKWAVE_SHOW = GTKWAVE_CMD + f"-a {PRESENTATION}" + f" {WAVEFILE}"

# Store the different elements into a common list :
commands = [
    GHDL_COMPILE.split(),
    GHDL_ELABORATE.split(),
    GHDL_SIMULATE.split(),
    GTKWAVE_SHOW.split(),
]

# Starting the main loop, until the user exit (ctrl + c)
print("=" * 100)
print(" GHDL Simulations started. Auto-reload when exiting the GTKWAVE tool !")
print(
    f' Hint : Hit file, save on GTKWAVE, and your signals config will be automatically restored ! \n File must be "{PRESENTATION}"'
)
print("=" * 100)

index = 0
# result = None
while True:
    try:
        print(f"Running {commands[index % 4]}")
        result = subprocess.run(
            commands[index % 4],
            capture_output=True,
            text=True,
            check=True,
        )

        # CHeck if prints are needed :
        if result.stdout:
            print(result.stdout)
        if result.stderr:
            print(result.stderr)

        # Incrementing counter
        index += 1

        if (index % 4) == 0:
            print("-" * 100)
            print("Restarting simulator...")
            print("-" * 100)

    except KeyboardInterrupt:
        print()
        print("=" * 100)
        print("Exiting code ghdl handler !")
        print("=" * 100)
        exit(0)

    except subprocess.CalledProcessError as e:
        # The 'e' object is a CalledProcessError and has stdout/stderr attributes.
        # Show here the erro from the CLI
        print(f"\n--- ERROR ---")
        print(f"Command failed: {' '.join(e.cmd)}")
        print(f"Return code: {e.returncode}")
        print(f"Stdout:\n{e.stdout}")
        print(f"Stderr:\n{e.stderr}")
        print("----------------\n")
        input("Press any key to continue...")

        # Set index to 0, to force a recompile
        index = 0

    except Exception as e:
        print()
        print("=" * 100)
        print(f"Unknown error. Check the output of ghdl directly. Python returned {e}")
        print("=" * 100)
        exit(-2)
