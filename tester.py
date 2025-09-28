#!/usr/bin/env python3
# ================================================================================
#                                   tester.py
#
#                                   l.heywang
#                                   23/09/2025
#
#       Assemble assembly files, simulate HDL core with the program
#       in memory and run the simulation.
# =================================================================================

import pathlib
import re
import tomllib
import subprocess
import shutil

# ---------------------------------------------------------------------------------
# Scripts parameters
# ---------------------------------------------------------------------------------

# Paths
BASE_PATH = "tests"
WORKIR = "build"
HEX_DEST = "src/memory/rom/rom.mif"

# Tools
COMPILER = "riscv32-unknown-elf-gcc "
OBJCOPY = "riscv32-unknown-elf-objcopy "
BIN2MIF = "./utils/bin2mif.py "

CCFLAGS = "-march=rv32i -mabi=ilp32 "
OBJFLAGS = "-O binary "

# ---------------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------------


# First, get all availables tests
def list_tests(base_folder: pathlib.Path) -> list[pathlib.Path]:
    return sort_test_dirs(
        [d for d in base_folder.iterdir() if d.is_dir() and d.name.startswith("test")]
    )


# Sort all the tests to preset a more use friendly interface
def sort_test_dirs(dirs: list[pathlib.Path]) -> list[pathlib.Path]:
    # Extract number from folder name like "test12" -> 12
    def extract_number(p: pathlib.Path):
        match = re.search(r"\d+", p.name)
        return int(match.group()) if match else 0

    return sorted(dirs, key=extract_number)


# Ask the user to set the test
def set_test(tests: list[pathlib.Path]):
    # Prints
    print("=" * 100)
    print(" Please select the test to be runned / simulated :")
    print("=" * 100)

    format_len = len(str(len(tests)))
    for index, dir in enumerate(tests):
        print(f"[{(index + 1):0{format_len}}/{len(tests):0{format_len}}] - {str(dir)}")

    while True:
        try:
            file_id = int(input("Which test ? "))
            if file_id > len(tests):
                print("Please enter a valid test !")
                continue
            else:
                break
        except ValueError:
            print("Please enter an integer !")

    return pathlib.Path(tests[file_id - 1])

def call(cmd: str):

    try : 
        print(f"Running {cmd}")
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
            shell=True,
            cwd=".",
        )

        # Check if prints are needed :
        if result.stdout:
            print("------ STDOUT ------")
            print(result.stdout)
        if result.stderr:
            print("------ STDERR ------")
            print(result.stderr)

        return

    except subprocess.CalledProcessError as e:
        # The 'e' object is a CalledProcessError and has stdout/stderr attributes.
        # Show here the erro from the CLI
        print(f"\n--- ERROR ---")
        print(f"Command failed: {''.join(e.cmd)}")
        print(f"Return code: {e.returncode}")
        print(f"Stdout:\n{e.stdout}")
        print(f"Stderr:\n{e.stderr}")
        print("----------------\n")
        return

# ---------------------------------------------------------------------------------
# Main script
# ---------------------------------------------------------------------------------

# First inputs
path = pathlib.Path(BASE_PATH)
tests = list_tests(path)
test_dir = set_test(tests)

# Getting config file path
config_path = test_dir / "test.toml"
config = None

# Then, load config
with open(config_path, "rb") as file:
    config = tomllib.load(file)

# Compute some files paths
source = test_dir / pathlib.Path(config["config"]["source"])
linker_script = (
    (test_dir / pathlib.Path(config["config"]["linker_script"]))
    if config["config"]["linker_script"] != ""
    else ""
)

linker_args = f"-T {linker_script} " if linker_script else ""


# Now, we can compile the needed files into the intel hex format
cmd1 = (
    COMPILER
    + CCFLAGS
    + f"{config["config"]["flags"]} "  # Custom passed flags
    + f"{linker_args}"
    + f"-o {WORKIR}/program.elf "
    + f"{str(source)} "
)

cmd2 = OBJCOPY + OBJFLAGS + f"{WORKIR}/program.elf " + f"{WORKIR}/program.bin "

cmd3 = BIN2MIF + f"{WORKIR}/program.bin " + f"{WORKIR}/program.mif "


print("=" * 100)
print(f" Compiling the program and building the hex init file to {HEX_DEST} ! ")
print("=" * 100)

call(cmd1)
call(cmd2)
call(cmd3)
    
# Finally, copy files into the right folder, for the simulator to find it
hex_source = pathlib.Path(f"{WORKIR}/program.mif")
hex_dest = pathlib.Path(HEX_DEST)
print(f"Running cp {WORKIR}/program.mif {HEX_DEST}")

# We use the low level Python interface rather than calling another shell...
shutil.copy(hex_source, hex_dest)

# Now, running the simulation :
# Todo tomorrow...
