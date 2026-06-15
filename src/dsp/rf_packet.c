/*
 * RF packet framing example. The RF module is external to the DSP, but the
 * DSP can prepare control packets and verify received telemetry frames.
 */

#include <stdint.h>
#include <stddef.h>

#define RF_SYNC_WORD 0xA55AU
#define RF_TYPE_MOTOR_CMD 0x01U
#define RF_MAX_PAYLOAD 64U

typedef struct {
    uint16_t sync;
    uint8_t type;
    uint8_t sequence;
    uint8_t length;
    uint8_t payload[RF_MAX_PAYLOAD];
    uint16_t crc;
} RfPacket;

static uint16_t crc16_ccitt(const uint8_t *data, size_t length)
{
    uint16_t crc = 0xFFFFU;
    size_t i;
    for (i = 0; i < length; ++i) {
        uint8_t bit;
        crc ^= (uint16_t)data[i] << 8;
        for (bit = 0; bit < 8; ++bit) {
            if ((crc & 0x8000U) != 0U) {
                crc = (uint16_t)((crc << 1) ^ 0x1021U);
            } else {
                crc <<= 1;
            }
        }
    }
    return crc;
}

uint16_t rf_build_motor_packet(RfPacket *packet, uint8_t sequence, int16_t speed_rpm, uint8_t direction)
{
    packet->sync = RF_SYNC_WORD;
    packet->type = RF_TYPE_MOTOR_CMD;
    packet->sequence = sequence;
    packet->length = 3U;
    packet->payload[0] = (uint8_t)((speed_rpm >> 8) & 0xFF);
    packet->payload[1] = (uint8_t)(speed_rpm & 0xFF);
    packet->payload[2] = direction;
    packet->crc = crc16_ccitt(packet->payload, packet->length);
    return packet->crc;
}
