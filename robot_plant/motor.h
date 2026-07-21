#pragma once

#include <stdint.h>

namespace Motor {
    void setSpeed(int32_t leftSpeed, int32_t rightSpeed);
    void drive();
    void printSpeed(int32_t leftSpeed, int32_t rightSpeed);
} // namespace Motor
