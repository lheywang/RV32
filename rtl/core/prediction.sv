/*
 *  File :      rtl/core/prediction.sv
 *
 *  Author :    l.heywang <leonard.heywang@proton.me>
 *  Date :      25/10.2025
 *  
 *  Brief :     This file define the BPU, Branch Prediction Unit, which
 *              will try to help to reduce the pipeline stalls, by trying to predict
 *              the next program counter address.
 */

`timescale 1ns / 1ps
