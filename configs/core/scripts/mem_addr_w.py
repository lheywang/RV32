def apply(config: dict) -> dict:
    config["mem_addr_w"] = config["xlen"]
    return config