#!/usr/bin/env python3

"""
Generate a testbench report, which count the errors and pass per test,
to make easier the debuging !
"""

import argparse
import sys
from dataclasses import dataclass


@dataclass
class test_case:
    name = str
    data = dict


def print_report(parsed):
    for test in parsed:
        if len(test.data.keys()) > 1:

            print("============================")
            print("CASE : ", test.name)
            print("============================")

            for key in test.data.keys():

                total = sum(test.data[key])
                percent = ((total - test.data[key][1]) / total) * 100

                print(f"    {key:12}")
                print(f"        PASSED : {test.data[key][0]}")
                print(f"        FAILED : {test.data[key][1]}")
                print("       ---------")
                print(f"                 {percent:02.1f}", "%")

                if key != list(test.data.keys())[-1]:
                    print("----------------------------")


def write_report(parsed, file):
    with open(file, "w+") as fout:
        # Writing the header
        fout.write("# Summary\n\n")

        for index, test in enumerate(parsed):
            if len(test.data.keys()) > 1:

                # Initiliaze the markdown array
                fout.write(f"## {test.name}\n\n")
                fout.write("|     Test name    | Passed | Failed | Percents |\n")
                fout.write("| ---------------- | ------ | ------ | -------- |\n")

                for key in test.data.keys():
                    total = sum(test.data[key])
                    percent = ((total - test.data[key][1]) / total) * 100

                    fout.write(
                        f"| {test.name:14} | {test.data[key][0]:6} | {test.data[key][1]:6} | {percent:.3f} |\n"
                    )

                if index != (len(parsed) - 1):
                    fout.write("\n\n")


def sanitize(line):
    to_delete = [
        "\x1b[0m",
        "\x1b[0m",
        "\x1b[31m",
        "\x1b[32m",
        "\x1b[33m",
        "\x1b[34m",
        "\x1b[35m",
        "\x1b[36m",
        "\x1b[37m",
        "\x1b[1m",
        "\x1b[4m",
    ]

    tmp = line.strip()

    for elem in to_delete:
        tmp = tmp.replace(elem, "")

    tmp = tmp.strip()
    return tmp


def extract_name(line):

    tmp = line.split("[")[-1].split("]")
    return tmp[0].strip()


def parse(lines):

    test_cases = []
    case_id = 0

    test_cases.append(test_case())
    test_cases[case_id].name = "Init"
    test_cases[case_id].data = dict()

    sanitized_lines = [sanitize(elem) for elem in lines]

    for line in sanitized_lines:
        if "Case" in line:

            test_cases.append(test_case())
            case_id += 1
            test_cases[case_id].name = line.split(":")[-1].strip()
            test_cases[case_id].data = dict()

        elif "PASS" in line:

            name = extract_name(line)
            if not name in test_cases[case_id].data.keys():
                test_cases[case_id].data[name] = [0, 0]
            test_cases[case_id].data[name][0] += 1

        elif "FAIL" in line:

            name = extract_name(line)
            if not name in test_cases[case_id].data.keys():
                test_cases[case_id].data[name] = [0, 0]
            test_cases[case_id].data[name][1] += 1

    return test_cases


if __name__ == "__main__":

    # Configure the argument parser
    parser = argparse.ArgumentParser(
        description="Parse a testbench output and generate a summary of the output",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument(
        "-m",
        "--mode",
        default="STDIN",
        help="Select the input mode between STDIN or FILE",
    )
    parser.add_argument(
        "-f",
        "--file",
        metavar="FILE",
        help="Select the file used as input (only of FILE mode)",
    )
    parser.add_argument(
        "-o",
        "--output",
        metavar="FILE",
        default="CONSOLE",
        help="Select the file used for output (Default to CONSOLE, which redirect output to the stdio). Set to a file to get a markdown written report !",
    )

    args = parser.parse_args()

    # Source the data from STDIN or FILE
    lines = None
    if args.mode == "FILE":
        print(f"Reading data from file ... ")
        with open(args.file, "r") as f:
            lines = f.readlines

    else:
        print(f"Reading data from stdin ... ")
        lines = sys.stdin.readlines()

    # Call the tool
    parsed = parse(lines)

    if args.output == "CONSOLE":
        print(f"Reporting data to stdout ... ")
        print_report(parsed)

    else:
        print(f"Reporting data to file ... ")
        write_report(parsed, args.output)
