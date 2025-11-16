import math


def apply(config: dict) -> dict:
    config["reg_addr_w"] = math.ceil(math.log2(config["reg_count"]))
    return config
