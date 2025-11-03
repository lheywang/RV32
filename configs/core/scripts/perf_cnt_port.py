def apply(config: dict) -> dict:
    config["perf_cnt_port"] = 2 if config["xlen"] < 64 else 1
    return config