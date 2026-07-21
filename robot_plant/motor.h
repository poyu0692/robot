#pragma once

#include <stdint.h>

namespace Motor {
    void setSpeed(int leftSpeed, int rightSpeed);
    void drive();
    void printSpeed(int leftSpeed, int rightSpeed);
} // namespace Motor
