#pragma once

#include "verilated.h"
#include "verilated_vcd_c.h"

void final_print(int pass, int fail, char name[64]);
void initial_print(char name[64]);

static vluint64_t sim_time = 0;

// Template to work with any Verilated module type
template <typename T>
void stick(T *tb, VerilatedVcdC *tfp, bool trace = true) {

    tb->clk = !tb->clk;
    tb->eval();

    if (trace && tfp) {
        tfp->dump(sim_time);
    }

    sim_time++;
    return;
}

template <typename T>
void tick(T *tb, VerilatedVcdC *tfp, bool trace = true) {

    stick(tb, tfp, trace);
    stick(tb, tfp, trace);
    return;
}