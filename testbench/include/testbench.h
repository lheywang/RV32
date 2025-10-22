/**
 * @file    utils/testbench.h
 *
 * @author  l.heywang <leonard.heywang@proton.me>
 * @date    22/10/2025
 *
 * @brief   Provide an abstraction layer over the Verilator interface, to make the testbench existence simpler.
 */

/*
 * ===========================================================================================
 * INCLUDES
 * ===========================================================================================
 */

#pragma once

#include <iostream>
#include <iomanip>
#include <stdint.h>

#include "verilated.h"
#include "verilated_vcd_c.h"

#include "colors.h"

// providing includes for auto generated
#include "generated_commands.h"
#include "generated_csr.h"
#include "generated_decoders.h"
#include "generated_opcodes.h"

/*
 * ===========================================================================================
 * MAIN CLASS
 * ===========================================================================================
 */

/**
 *  @class  Testbench
 *
 *  @brief  Provide an abstraction layer above the standard Verilator one.
 *          Wrap some utility functions and others elements into a more practical way.
 *          Also provide some way to make the output console a bit cleaner.
 *
 *  @tparam MODULE  A verilated module type (Vxxxx...). Enable to share a single class between all of them.
 *
 *  @details
 *          Usage : First, open the class (after calling the argument parser of Verilator)
 *
 *                      Verilated::commandArgs(argc, argv);
 *                      Testbench<Valu2> tb("ALU2");
 *
 *          Then, perform a reset of the DUT to ensure a consistent state :
 *
 *                      tb.reset();
 *
 *          Finally, you can start applying inputs, and checking for outputs !
 *
 *              Applying inputs, both options work the same
 *
 *                      tb.set(&tb.dut->clear, 1);
 *                      tb.dut->clear = 1
 *
 *              Checking outputs :
 *
 *                       tb.check_equality(&tb.dut->busy, 0, "busy");
 *
 *          And, if the testbench need some clocks cycles. Different options to performa single edge (stick),
 *          a whole period (tick) or until a condition is valid (run_until).
 *
 *              tb.stick();
 *              tb.tick();
 *              int count = tb.run_until(&tb.dut->valid, 1);
 *
 *          Read the doc for the full usage !
 */
template <class MODULE>
class Testbench
{
public:
    /*
     * ===========================================================================================
     * CONSTRUCTORS and DESTRUCTORS
     * ===========================================================================================
     */

    /**
     *  @brief  Construct a new testbench class, with the right type passed a template parameter :
     *
     *      Testbench<Vxxx> env;
     *
     *      No parameters are used, the testbench will fetch the name from the Verilog / SystemVerilog
     *      module directly.
     *
     *  @return the class itself.
     */
    Testbench()
    {
        this->name = std::string("default");
        this->verilator_init();
        return;
    }

    /**
     *  @brief  Construct a new testbench class, with the right type passed a template parameter :
     *
     *      Testbench<Vxxx> env(name);
     *
     *  @param  module_name (std::string) A custom name for the module.
     *
     *  @return the class itself.
     */
    Testbench(std::string module_name)
    {
        this->name = module_name;
        this->verilator_init();
        return;
    }

    /**
     *  @brief  Construct a new testbench class, with the right type passed a template parameter :
     *
     *      Testbench<Valu2> env;
     *
     *  No parameters are used, the testbench will fetch the name from the Verilog / SystemVerilog
     *  module directly.
     *
     *  @return None
     */
    ~Testbench()
    {
        final_print();

        this->tfp->close();
        delete this->dut;
        delete this->tfp;
        return;
    }

    /*
     * ===========================================================================================
     * SIMULATION
     * ===========================================================================================
     */

    /**
     *  @brief  Make the testbench sim_time to advance of a single tick (one inversion of the clock).
     *
     *  @arg    trace   Enable the tracing into the VCD file (default = true)
     *
     *  @return None
     */
    void stick(bool trace = true)
    {
        // Toggling the clock and evalutating changes
        this->dut->clk = !this->dut->clk;
        this->dut->eval();

        // If needed, dump into the VCD file
        if (trace)
        {
            this->tfp->dump(this->sim_time);
        }

        // Incrementing the simulation time to get a coherent output
        this->sim_time += 1;

        // Incrementing the performance counters, if some are enabled
        for (int k = 0; k < 15; k++)
        {
            if (this->enabled_counters[k] == 1)
            {
                this->perf_counters[k] += 1;
            }
        }
        return;
    }

    /**
     *  @brief  Make the testbench sim_time to advance of a whole clock period.
     *
     *  @arg    trace   Enable the tracing into the VCD file (default = true)
     *
     *  @return None
     */
    void tick(bool trace = true)
    {
        // We just call twice the stick function, to get a full clock cycle.
        this->stick(trace);
        this->stick(trace);
        return;
    }

    /**
     *  @brief  Perform a reset of the DUT, by playing with the rst_n pin.
     *
     *  @return None
     */
    void reset()
    {
        // Set the reset low (active)
        this->dut->rst_n = 0;
        this->stick();

        // Releasing the reset (inactive)
        this->dut->rst_n = 1;
        this->stick();

        // Waiting for a whole cycle
        this->tick();
        return;
    }

    /**
     *  @brief  Run the testbench until the condition is true. The code simulation is runned at
     *          least for a single cycle.
     *
     *          Can be super-useful with start_cycle_counter / end_cycle_counter to measure the
     *          performance of a module.
     *
     *          Usage example :
     *              tb.run_until(&tb.dut->[sig], 1); will run until the [sig] get the value of '1'.
     *              tb.run_until(&tb.dut->[sig], 0x8); will run until the [sig] get the value of 8.
     *
     *  @tparam *signal     The signal that is used as comparison source
     *  @tparam value       The value that shall be taken by the signal to exit the loop.
     *  @param  max_cycles  A maximal value after which the loop will be exited, regardless of
     *                      the condition.
     *
     *  @retval The number of elapsed cycles to satisfy the condition (or, the max_cycle value).
     */
    template <typename TYPE1, typename TYPE2>
    int run_until(TYPE1 *signal, TYPE2 value, int max_cycles = 1000)
    {
        this->tick();
        int cycles = 0;
        do
        {
            this->tick();
            cycles += 1;
        } while ((cycles < max_cycles) && *signal != (TYPE1)value);
        return cycles;
    }

    /*
     * ===========================================================================================
     * PERFORMANCE COUNTERS
     * ===========================================================================================
     */

    /**
     * @brief   Start a performance counter at the specified ID (up to 15).
     *          Can be used to monitor the cycle difference for a specific part of the test.
     *
     * @param   ID  The ID of the performance counter (0 - 15).
     *
     * @return  int
     * @retval   0 : Counter started.
     * @retval  -1 : Invalid counter.
     * @retval  -2 : Counter already started.
     */
    int start_cycle__counter(int ID)
    {
        if ((0 > ID) || (ID > 15))
        {
            return -1;
        }

        if (this->enabled_counters[ID] == 1)
        {
            return -2;
        }

        this->enabled_counters[ID] = 1;
        return 0;
    }

    /**
     * @brief   Start a performance counter at the specified ID (up to 15).
     *          Can be used to monitor the cycle difference for a specific part of the test.
     *
     * @param   ID  The ID of the performance counter (0 - 15).
     *
     * @retval  int The number of cycles elapsed from the start of this counter. May return -1 if invalid ID.
     */
    int stop_cycle_counter(int ID)
    {
        if ((0 > ID) || (ID > 15))
        {
            return -1;
        }

        // Disable the performance counter
        this->enabled_counters[ID] = 0;

        // Backup the data, and halve it (incremented at each stick, half clock period)
        uint64_t save = this->perf_counters[ID] / 2;
        this->perf_counters[ID] = 0;

        return save;
    }

    /*
     * ===========================================================================================
     * PRINTS
     * ===========================================================================================
     */

    /**
     *  @brief  Print the final message, that contain the end message, and an pass / fail count.
     *
     *  @return None
     */
    void final_print()
    {
        std::cout << KMAG
                  << "Simulation complete."
                  << std::endl
                  << std::dec
                  << KYEL
                  << "========================================================\n"
                  << "Results : (" << this->name << ")"
                  << "\n========================================================"
                  << std::endl
                  << KGRN << "\tPass : "
                  << std::setw(4) << this->pass
                  << KRED << "\n\tFail : "
                  << std::setw(4) << this->fail
                  << RST
                  << std::endl;

        if (this->fail == 0)
        {
            std::cout << KGRN
                      << "Tests passed !"
                      << RST
                      << std::endl;
        }
        else
        {
            std::cout << KRED
                      << "Tests failed !"
                      << RST
                      << std::endl;
        }

        return;
    }

    /**
     *  @brief  Print the initial message, to announce that the sequence will start.
     *
     *  @return None
     */
    void initial_print()
    {
        std::cout << KMAG
                  << "--------------------------------------------------------" << std::endl
                  << "Starting " << this->name << " simulation..." << std::endl
                  << "--------------------------------------------------------" << std::endl
                  << RST;
        return;
    }

    /*
     * ===========================================================================================
     * ASSERTIONS
     * ===========================================================================================
     */

    /**
     *  @brief  Perform an assertion, and print the output into the console, with a nice colored
     *          code.
     *
     *  @tparam *signal A member of the tested unit, to be compared against a value
     *  @tparam value   The value to be compared against
     *  @param  print   Shall we print to the console ?
     */
    template <typename TYPE1, typename TYPE2>
    int check_equality(TYPE1 *signal, TYPE2 reference, std::string testname, bool print = true)
    {
        if (*signal == reference)
        {
            if (print)
                std::cout << KGRN
                          << "[  PASS   ] Cycle "
                          << std::setw(8) << this->cycle_count
                          << "    [ " << testname << " ] @ " << this->sim_time << " ps"
                          << RST
                          << std::dec
                          << std::endl;
            this->pass += 1;
        }
        else
        {
            std::cout << KRED
                      << "[  FAIL   ] Cycle "
                      << std::setw(8) << this->cycle_count
                      << "    [ " << testname << " ] @ " << this->sim_time << " ps | Got : 0x"
                      << std::hex
                      << std::setw(8)
                      << *signal
                      << " waited : 0x"
                      << std::setw(8)
                      << reference
                      << " |"
                      << RST
                      << std::dec
                      << std::endl;
            this->fail += 1;
        }
        return 0;
    }

    /**
     *  @brief  Perform an assertion, and print the output into the console, with a nice colored
     *          code. The difference with check_equality is the fact that this function is used to
     *          add an argument to a previous comparison, and, if pass, won't be printed at all.
     *
     *  @tparam *signal A member of the tested unit, to be compared against a value
     *  @tparam value   The value to be compared against
     *  @param  print   Shall we print to the console ?
     */
    template <typename TYPE1, typename TYPE2>
    int check_equality_arg(TYPE1 *signal, TYPE2 reference, std::string testname, bool print = true)
    {
        if (*signal == reference)
        {
            this->pass += 1;
        }
        else
        {
            std::cout << KRED
                      << std::hex
                      << "    [ " << this->name << " ] @ " << this->sim_time << " ps | Got : 0x"
                      << std::setw(8)
                      << *signal
                      << " waited : 0x"
                      << std::setw(8)
                      << reference
                      << " |"
                      << RST
                      << std::dec
                      << std::endl;
            this->fail += 1;
        }
        return 0;
    }

    /*
     * ===========================================================================================
     * MISC. PRINTS
     * ===========================================================================================
     */

    /**
     *  @brief  Set the current case, and show message in the console to indicate it.
     *          Theses messages are printed in cyan.
     *
     *  @return int 0.
     */
    int set_case(std::string cases)
    {
        std::cout << std::dec
                  << KCYN
                  << "--------------------------------------------------------\n"
                  << "Case : (" << this->name << ") : " << cases
                  << "\n--------------------------------------------------------"
                  << RST
                  << std::endl;

        this->actual_case = cases;
        return 0;
    }

    /**
     *  @brief  Show to the user an info. Shown in blue.
     *
     *  @return int 0.
     */
    int set_info(std::string message)
    {
        std::cout << std::dec
                  << KBLU
                  << "[  INFO   ] : (" << this->name << ") : " << message
                  << RST
                  << std::endl;

        return 0;
    }

    /**
     *  @brief  Show the user a warning. Show in yellow.
     *
     *  @return int 0.
     */
    int set_warn(std::string message)
    {
        std::cout << std::dec
                  << KYEL
                  << "[ WARNING ] : (" << this->name << ") : " << message
                  << RST
                  << std::endl;

        return 0;
    }

    /**
     *  @brief  Show the user an error. Show in red.
     *
     *  @return int 0.
     */
    int set_error(std::string message)
    {
        std::cout << std::dec
                  << KRED
                  << "[  ERROR  ] : (" << this->name << ") : " << message
                  << RST
                  << std::endl;

        return 0;
    }

    /*
     * ===========================================================================================
     * GETTING AND SETTING VALUES
     * ===========================================================================================
     */

    /**
     *  @brief  Fill the passed pointers with the pass and fail values, and return 0 if none are
     *          failed, else -1.
     *
     *  @return int 0 or -1
     */
    template <typename TYPE1, typename TYPE2>
    int get_return(TYPE1 *passed, TYPE2 *failed)
    {
        // Update the values
        *passed = (TYPE1)this->pass;
        *failed = (TYPE2)this->fail;

        return (this->fail != 0) ? -1 : 0;
    }

    /**
     *  @brief  Return 0 if non tests failed, else -1.
     *
     *  @return int 0 or -1
     */
    int get_return()
    {
        return (this->fail != 0) ? -1 : 0;
    }

    /**
     *  @brief  Increment the cycle counter by a defined value.
     *
     *  @param  int     The value to be added.
     *
     *  @return int
     *  @retval The value of the cycles after being incremented.
     */
    int increment_cycles(int value = 1)
    {
        this->cycle_count += value;
        return this->cycle_count;
    }

    /*
     * ===========================================================================================
     * SETTER AND GETTERS
     * ===========================================================================================
     */

    /**
     *  @brief  Enable to set a signal on the DUT.
     *
     *  @tparam *signal The signal to be configured.
     *  @tparam value   The value to be written.
     *
     *  @return 0
     */
    template <typename TYPE1, typename TYPE2>
    int set(TYPE1 *signal, TYPE2 value)
    {
        *signal = (TYPE1)value;
        return 0;
    }

    /**
     *  @brief  Enable to read a value from the DUT.
     *
     *  @tparam *signal The signal to be read.
     *
     *  @return Tparam the value readen.
     */
    template <typename TYPE>
    TYPE set(TYPE *signal)
    {
        return (TYPE)*signal;
    }

    // Public DUT to be accessed by the user.
    MODULE *dut;

private:
    /*
     *  Variables
     */

    // Class "name" for console
    std::string name;

    // Verilated modules
    VerilatedVcdC *tfp;

    // Simulation time
    vluint64_t sim_time;
    uint64_t cycle_count;

    // Counters
    uint64_t pass;
    uint64_t fail;
    std::string actual_case;

    uint64_t enabled_counters[16];
    uint64_t perf_counters[16];

    /*
     *  Functions
     */
    void
    verilator_init()
    {
        // Initializing variables
        this->sim_time = 0;
        this->cycle_count = 0;
        this->pass = 0;
        this->fail = 0;
        this->actual_case = std::string("default");

        // Initializing performance counters
        for (int k = 0; k < 16; k++)
        {
            this->enabled_counters[k] = 0;
            this->perf_counters[k] = 0;
        }

        // Openning the class for verilator
        this->dut = new MODULE;
        this->tfp = new VerilatedVcdC;

        // Enabling traces
        Verilated::traceEverOn(true);

        // Configuring some elements
        this->dut->trace(this->tfp, 99);

        // Creating the simulation output
        char str[64];
        snprintf(str, sizeof(str), "simout/%s.vcd", this->name.c_str());
        tfp->open(str);

        // Logging to console the first elements
        this->initial_print();
        return;
    }
};