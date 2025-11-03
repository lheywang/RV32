import math

def apply(config: dict) -> dict:
    config["clk_div_max"] = (config["core_clk_freq"] / config["cycle_clk_freq"]) - 1
    config["clk_div_thres"] = (config["clk_div_max"] / 100) + 1
    config["clk_div_width"] = math.log2(config["clk_div_max"]) + 1
    return config