import math


def apply(config: dict) -> dict:
    config["if_boot_ucode"] = config["if_base_addr"]
    return config
