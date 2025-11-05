# This small makefile handle the build of this source into the final executable, 
# and it's associated products files.

SOURCE = test.S trap.S
EXE = program.elf
BIN = program.bin
ASM = program.txt 

all : $(SOURCE)
	riscv64-unknown-elf-gcc -march=rv32im_zicsr -mabi=ilp32 -o $(EXE) -T linker.ld -nostdlib $(SOURCE)
	file $(EXE) > $(ASM)
	riscv64-unknown-elf-objdump -d $(EXE) >> $(ASM)
	riscv64-unknown-elf-objcopy -O binary $(EXE) $(BIN)

clean : 
	rm $(EXE)
	rm $(BIN)
	rm $(ASM)