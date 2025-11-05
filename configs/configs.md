# Configs

This folder store all of the configuration files. Most are used by python scripts 
to generate associated SystemVerilog and C Header files.

The used tool (conf2header.py) will look for ANY .toml file in the passed folder,
which will lead to implicit includes, and it will flatten any keys into a single 
level dict. Then, some scripts could be used for dynamically generated keys !

## Scripts

If you want to generate keys from previous ones, you can use pythons scripts that'll 
compute new values.

Theses scripts will add new keys to a passed dict. Any python function could be used on it, 
even complex scripts that'll dynamically configure the core (even with a GUI ? ).
Since all of theses scripts are called after reading any TOML file, any defined key is 
available by it's name on the passed dict.

The script always contain a function, defined as : 

> def apply(config: dict) -> dict:
>    config["mem_addr_w"] = config["xlen"]
>   return config

The function shall always be named "apply", that's the one who's called.
The function shall always accept a dict, and return a dict.
The function could write / compute / ask the user for anything, until it remains an integer
written to the dict.

The script could be named as we want, and could even create multiple values ! In fact, we don't
really care, they'll all be executed and dynamically loaded into the package.
The decision to use them is took by the compiler rather than python.

## Outputs

The tool will output two files : 
- \[name\]\_config\_pkg.svh, a file containing the SystemVerilog definitions.
- \[name\]\_config\_pkg.h, a file containing C++ definitions.

This is done to tighten the C++ / SV coupling that exists, to ensure in ANY cases
the values used are the exact same.

Two last files are generated in common, and regardless of the existence, or not of config files : 

- generated.sv
- generated.h

This could be safely included from any SV / C++ units, and will contain all of the generated 
sub-files !

