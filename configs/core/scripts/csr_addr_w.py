import math

def apply(config: dict) -> dict:
    config["csr_addr_w"] = math.ceil(math.log2(config["csr_count"]))
    return config