; Interrupt service routine sketch for a C28x-style DSP workflow.
; It illustrates mixed C/assembly design intent for the report appendix.

        .sect   ".text"
        .global _motor_pwm_isr_entry

_motor_pwm_isr_entry:
        PUSH    ACC
        PUSH    P
        ; ADC result registers would be read here on target hardware.
        ; The C routine motor_control_step() computes the next PWM duty.
        LCR     _motor_control_isr_c
        POP     P
        POP     ACC
        LRETR
