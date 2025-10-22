#pragma once

#include "verilated.h"
#include "verilated_vcd_c.h"

#include <iostream>

void final_print(char name[64]);
void initial_print(char name[64]);

extern vluint64_t sim_time;
extern uint64_t __pass;
extern uint64_t __fail;

// Template to work with any Verilated module type
template <typename T>
void stick(T *tb, VerilatedVcdC *tfp, bool trace = true)
{

    tb->clk = !tb->clk;
    tb->eval();

    if (trace && tfp)
    {
        tfp->dump(sim_time);
    }

    sim_time++;
    return;
}

template <typename T>
void tick(T *tb, VerilatedVcdC *tfp, bool trace = true)
{

    stick(tb, tfp, trace);
    stick(tb, tfp, trace);
    return;
}

void equality_print_arg(char name[64], int value, int reference);
// void equality_print_arg(char name[64], unsigned int value, unsigned int reference);
void equality_print(char name[64], int cycle, int value, int reference, bool print = true);
// void equality_print(char name[64], int cycle, unsigned int value, unsigned int reference, bool print = true);
void print_case(char name[64], char cases[64]);

void get_counts(uint64_t *passed, uint64_t *failed);
void print_info(char name[64], char cases[64]);
