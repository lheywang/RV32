# Uops

Theses micro operations are used when we need to execute longer sequences than a simple instruction.
For example, when handling an halt request or anything related.

In that case, the BPU (branch prediction unit) will simply "predict" the address of the associated
microcode.
