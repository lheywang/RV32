def apply(config: dict) -> dict:
    config["mem_data_w"] = config["xlen"]
    return config