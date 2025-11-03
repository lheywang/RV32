#!/usr/bin/env python3
"""
Generate SystemVerilog and C++ enum definitions from a simple definition file.
"""

import argparse
import importlib.util
import re
import sys
import tomllib
from pathlib import Path

def apply_script(config: dict, script_path: Path) -> dict:
    """Dynamically import and apply a config script."""
    spec = importlib.util.spec_from_file_location(script_path.stem, script_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    if hasattr(module, "apply"):
        return module.apply(config)
    else:
        raise AttributeError(f"{script_path} has no 'apply(config)' function")


def main():
    parser = argparse.ArgumentParser(
        description="Generate SystemVerilog and C++ enum definitions from a simple definition file (toml)",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("config_folder",metavar="FOLDER", help="Location of the config file name and scripts. Any TOML files will be loaded all together")

    parser.add_argument(
        "-o",
        "--output",
        default="build/",
        metavar="FILE",
        help="Output files location",
    )
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")

    args = parser.parse_args()

    # List all sources and scripts files
    p = Path(args.config_folder).glob('**/*.toml')
    configs = [x for x in p if x.is_file()]

    p = Path(args.config_folder).glob('**/*.py')
    scripts = [x for x in p if x.is_file()]

    p = Path(args.config_folder).glob('**/includes.toml')
    includes = [x for x in p if x.is_file()]

    # Removing the includes files from the config files
    configs = list(set(configs) - set(includes))

    # Read all of the elements into the configs files, and flatten the dicts
    keys = dict()
    for config in configs:
        with open(config, "rb") as f:
            tmp = tomllib.load(f)
            for key in tmp.keys() :
                keys = keys | tmp[key]

    # Then, call the different subscripts to generate the new keys
    for script in scripts:
        apply_script(keys, script)

    print(keys)




if __name__ == "__main__":
    main()
