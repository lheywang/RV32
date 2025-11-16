def apply(config: dict) -> dict:
    config["mem_data_w"] = config["xlen"]
    config["mem_addr_w"] = config["xlen"]
    return config
