# DSP source examples

These files are course-design source examples for the MATLAB/Simulink based robot wireless control design.

- `motor_control.c`: PID voltage command and PWM duty calculation.
- `rf_packet.c`: RF control-frame packing and CRC example.
- `isr_stub.asm`: C/assembly mixed-programming interrupt stub.

The MATLAB simulations in `matlab/run_all_simulations.m` are the source of the reported experimental results. These C/ASM files are not claimed to have been compiled on a target board in this deliverable.
