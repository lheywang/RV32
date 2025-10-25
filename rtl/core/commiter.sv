/*
 *  File :      rtl/core/commiter.sv
 *
 *  Author :    l.heywang <leonard.heywang@proton.me>
 *  Date :      25/10.2025
 *  
 *  Brief :     This file define the commit module, the one who's
 *              charged to handle the ALU outputs and the registers write-back.
 *              It also expose an address load bus, in case a branch instruction
 *              was mispredicted, and we need to flush the pipeline.
 */