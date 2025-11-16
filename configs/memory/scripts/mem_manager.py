import math


def get_size(input: str) -> int:
    # Return the size in bytes for standard units
    tmp = input
    factor = 1
    if "k" in input or "K" in input:
        factor = 1024
        tmp = tmp.replace("k", "").replace("K", "")
    elif "m" in input or "M" in input:
        factor = 1024 * 1024
        tmp = tmp.replace("m", "").replace("M", "")
    elif "g" in input or "G" in input:
        factor = 1024 * 1024 * 1024
        tmp = tmp.replace("g", "").replace("G", "")

    return int(tmp, 10) * factor


def get_params(config: dict, base: str, size: int) -> dict:
    # First, get the name of the new keys to be added :
    base_name = base.split("_")[0] + "_addr_bits"
    mask_name = base.split("_")[0] + "_addr_mask"

    # Then, compute the addr bits field
    config[base_name] = 32 - size
    config[mask_name] = config[base] >> size

    # Return
    return config


def apply(config: dict) -> dict:

    addr_to_get = [
        ("rom_base", "rom_length"),
        ("ram_base", "ram_length"),
        ("ext_ram_base", "ext_ram_length"),
        ("gpio0_base", "peripheral_length"),
        ("gpio1_base", "peripheral_length"),
        ("gpio2_base", "peripheral_length"),
        ("gpio3_base", "peripheral_length"),
        ("serial0_base", "peripheral_length"),
        ("serial1_base", "peripheral_length"),
        ("serial2_base", "peripheral_length"),
        ("serial3_base", "peripheral_length"),
        ("serial4_base", "peripheral_length"),
        ("serial5_base", "peripheral_length"),
        ("keyboard0_base", "peripheral_length"),
        ("argb0_base", "peripheral_length"),
        ("timer0_base", "peripheral_length"),
        ("timer1_base", "peripheral_length"),
        ("timer2_base", "peripheral_length"),
        ("timer3_base", "peripheral_length"),
        ("timer4_base", "peripheral_length"),
        ("timer5_base", "peripheral_length"),
        ("int0_base", "peripheral_length"),
    ]

    # Computing the parameters needed
    for base, length in addr_to_get:
        size = (get_size(config[length]) - 1).bit_length()
        config = get_params(config, base, size)

    # Removing unavailable keys
    for base, length in addr_to_get:
        config.pop(base, None)
        config.pop(length, None)

    # Exiting...
    return config
