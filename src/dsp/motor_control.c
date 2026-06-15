/*
 * Motor control example for TI TMS320F28379D style DSP firmware.
 * This file is provided as source material for the course design report.
 */

#include <stdint.h>

typedef struct {
    float target_rpm;
    float actual_rpm;
    float kp;
    float ki;
    float kd;
    float integral;
    float previous_error;
    float current_limit_a;
    float dc_bus_v;
} MotorPid;

typedef struct {
    float pwm_duty;
    float voltage_cmd_v;
    uint16_t direction;
    uint16_t fault;
} MotorOutput;

static float clampf(float value, float lower, float upper)
{
    if (value < lower) {
        return lower;
    }
    if (value > upper) {
        return upper;
    }
    return value;
}

MotorOutput motor_control_step(MotorPid *pid, float measured_current_a, float sample_time_s)
{
    MotorOutput out;
    float error = pid->target_rpm - pid->actual_rpm;
    float derivative = (error - pid->previous_error) / sample_time_s;
    float voltage;

    pid->integral += error * sample_time_s;
    voltage = pid->kp * error + pid->ki * pid->integral + pid->kd * derivative;
    voltage = clampf(voltage, -pid->dc_bus_v, pid->dc_bus_v);

    out.fault = 0U;
    if (measured_current_a > pid->current_limit_a || measured_current_a < -pid->current_limit_a) {
        voltage *= 0.6f;
        pid->integral *= 0.8f;
        out.fault = 1U;
    }

    out.direction = (voltage >= 0.0f) ? 1U : 0U;
    out.voltage_cmd_v = voltage;
    out.pwm_duty = clampf((voltage >= 0.0f ? voltage : -voltage) / pid->dc_bus_v, 0.0f, 1.0f);
    pid->previous_error = error;
    return out;
}
