#include <iostream>
#include "colors.h"
#include <iomanip>

void final_print(int pass, int fail, char name[64])
{
    std::cout << KMAG
              << "Simulation complete."
              << std::endl
              << std::dec
              << KYEL << "--------------------------------------------------------\n"
              << "Results : (" << name << ")"
              << "\n--------------------------------------------------------"
              << std::endl
              << KGRN << "\tPass : "
              << std::setw(4) << pass
              << KRED << "\n\tFail : "
              << std::setw(4) << fail
              << RST
              << std::endl;

    if (fail == 0)
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
    std::cout   << KMAG
                << "--------------------------------------------------------" << std::endl
                << "Starting " << name << " simulation..." << std::endl
                << "--------------------------------------------------------" << std::endl
                << RST;
}