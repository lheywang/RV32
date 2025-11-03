import math

def apply(config: dict) -> dict:
    config["csr_addr_w"] = config["if_base_addr"]
    return config