#!/usr/bin/env python3
import argparse


def bin_to_mif(bin_file, mif_file, width=32, depth=None, byte_swap=False):
    with open(bin_file, "rb") as f:
        data = f.read()

    bytes_per_word = width // 8
    if len(data) % bytes_per_word != 0:
        data += b"\x00" * (bytes_per_word - (len(data) % bytes_per_word))

    nwords = len(data) // bytes_per_word
    if depth is None:
        depth = nwords

    with open(mif_file, "w") as f:
        f.write(f"WIDTH={width};\n")
        f.write(f"DEPTH={depth};\n\n")
        f.write("ADDRESS_RADIX=HEX;\n")
        f.write("DATA_RADIX=HEX;\n\n")
        f.write("CONTENT BEGIN\n")

        for i in range(nwords):
            word_bytes = data[i * bytes_per_word : (i + 1) * bytes_per_word]

            if byte_swap:
                word_bytes = word_bytes[::-1]

            word_hex = word_bytes.hex().upper()
            f.write(f"    {i:04X} : {word_hex};\n")

        if nwords < depth:
            f.write(
                f"    [{nwords:04X}..{depth-1:04X}] : " + "0" * (width // 4) + ";\n"
            )

        f.write("END;\n")
        return


def main():
    parser = argparse.ArgumentParser(
        description="Convert a binary file to Intel/Altera .mif format"
    )
    parser.add_argument("input", help="Input .bin file")
    parser.add_argument("output", help="Output .mif file")
    parser.add_argument(
        "--width", type=int, default=32, help="Word width in bits (default: 32)"
    )
    parser.add_argument(
        "--depth", type=int, default=None, help="Memory depth in words (default: auto)"
    )
    parser.add_argument(
        "--byte-swap",
        action="store_true",
        help="Swap byte order inside each word (for endianness control)",
    )

    args = parser.parse_args()
    bin_to_mif(args.input, args.output, args.width, args.depth, args.byte_swap)
    return


if __name__ == "__main__":
    main()
