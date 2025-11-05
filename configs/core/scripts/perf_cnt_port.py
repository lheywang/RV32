def apply(config: dict) -> dict:
    config["perf_cnt_port"] = 1 if config["xlen"] < 64 else 0
    return config