#include <iostream>
#include <iomanip>
#include <stdint.h>

#include "colors.h"
#include "utils.h"

uint64_t __pass = 0;
uint64_t __fail = 0;
vluint64_t sim_time = 0;

void final_print(char name[64])
{
    std::cout << KMAG
              << "Simulation complete."
              << std::endl
              << std::dec
              << KYEL
              << "--------------------------------------------------------\n"
              << "Results : (" << name << ")"
              << "\n--------------------------------------------------------"
              << std::endl
              << KGRN << "\tPass : "
              << std::setw(4) << __pass
              << KRED << "\n\tFail : "
              << std::setw(4) << __fail
              << RST
              << std::endl;

    if (__fail == 0)
        std::cout << KGRN
                  << "Tests passed !"
                  << RST
                  << std::endl;
    else
        std::cout << KRED
                  << "Tests failed !"
                  << RST
                  << std::endl;

    return;
}

void initial_print(char name[64])
{
    std::cout << KMAG
              << "--------------------------------------------------------" << std::endl
              << "Starting " << name << " simulation..." << std::endl
              << "--------------------------------------------------------" << std::endl
              << RST;
}

// void equality_print(char name[64], int cycle, unsigned int value, unsigned int reference, bool print)
// {
//     if (value == reference)
//     {
//         if (print)
//             std::cout << KGRN
//                       << "[ PASS ] Cycle "
//                       << std::setw(8) << cycle
//                       << "    [ " << name << " ] @ " << sim_time << " ps"
//                       << RST
//                       << std::dec
//                       << std::endl;
//         __pass += 1;
//     }
//     else
//     {
//         std::cout << KRED
//                   << "[ FAIL ] Cycle "
//                   << std::setw(8) << cycle
//                   << "    [ " << name << " ] @ " << sim_time << " ps | Got : 0x"
//                   << std::hex
//                   << std::setw(8)
//                   << value
//                   << " waited : 0x"
//                   << std::setw(8)
//                   << reference
//                   << " |"
//                   << RST
//                   << std::dec
//                   << std::endl;
//         __fail += 1;
//     }
//     return;
// }

void equality_print(char name[64], int cycle, int value, int reference, bool print)
{
    if (value == reference)
    {
        if (print)
            std::cout << KGRN
                      << "[ PASS ] Cycle "
                      << std::setw(8) << cycle
                      << "    [ " << name << " ] @ " << sim_time << " ps"
                      << RST
                      << std::dec
                      << std::endl;
        __pass += 1;
    }
    else
    {
        std::cout << KRED
                  << "[ FAIL ] Cycle "
                  << std::setw(8) << cycle
                  << "    [ " << name << " ] @ " << sim_time << " ps | Got : 0x"
                  << std::hex
                  << std::setw(8)
                  << value
                  << " waited : 0x"
                  << std::setw(8)
                  << reference
                  << " |"
                  << RST
                  << std::dec
                  << std::endl;
        __fail += 1;
    }
    return;
}

void equality_print_arg(char name[64], int value, int reference)
{
    if (value == reference)
    {
        __pass += 1;
    }
    else
    {
        std::cout << KRED
                  << std::hex
                  << "    [ " << name << " ] @ " << sim_time << " ps | Got : 0x"
                  << std::setw(8)
                  << value
                  << " waited : 0x"
                  << std::setw(8)
                  << reference
                  << " |"
                  << RST
                  << std::dec
                  << std::endl;
        __fail += 1;
    }
    return;
}

// void equality_print_arg(char name[64], unsigned int value, unsigned int reference)
// {
//     if (value == reference)
//     {
//         __pass += 1;
//     }
//     else
//     {
//         std::cout << KRED
//                   << std::hex
//                   << "    [ " << name << " ] @ " << sim_time << " ps | Got : 0x"
//                   << std::setw(8)
//                   << value
//                   << " waited : 0x"
//                   << std::setw(8)
//                   << reference
//                   << " |"
//                   << RST
//                   << std::dec
//                   << std::endl;
//         __fail += 1;
//     }
//     return;
// }

void get_counts(uint64_t *passed, uint64_t *failed)
{
    *passed = __pass;
    *failed = __fail;
    return;
}

void print_case(char name[64], char cases[64])
{
    std::cout << std::dec
              << KYEL
              << "--------------------------------------------------------\n"
              << "Mid point : (" << name << ") : " << cases
              << "\n--------------------------------------------------------"
              << RST
              << std::endl;

    return;
}