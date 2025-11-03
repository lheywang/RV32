# Configs

This folder store all of the configuration files. Most are used by python scripts 
to generate associated SystemVerilog and C Header files.

The used tool (conf2header.py) will look for ANY .toml file in the passed folder,
which will lead to implicit includes, and it will flatten any keys into a single 
level dict.

## Scripts

If you want to generate keys from previous ones, you can use pythons scripts that'll 
compute new values.