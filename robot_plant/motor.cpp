#include "motor.h"
#include <Arduino.h>
#include "const.h"

namespace {
    int32_t pendingLeftSpeed;
    int32_t pendingRightSpeed;
    bool hasPendingSpeed = false;

    void writeLeft(int32_t forward, int32_t reverse) {
        analogWrite(Pin::LEFT_MOTOR_FWD, forward);
        analogWrite(Pin::LEFT_MOTOR_REV, reverse);
    }

    void writeRight(int32_t forward, int32_t reverse) {
        analogWrite(Pin::RIGHT_MOTOR_FWD, forward);
        analogWrite(Pin::RIGHT_MOTOR_REV, reverse);
    }
} // namespace

namespace Motor {
    void printSpeed(int32_t left, int32_t right) {
        Serial.print("left: ");
        Serial.print(left);
        Serial.print(", right: ");
        Serial.println(right);
    }

    void setSpeed(int32_t left, int32_t right) {
        pendingLeftSpeed = left;
        pendingRightSpeed = right;
        hasPendingSpeed = true;
    }

    void drive() {
        if (!hasPendingSpeed) {
            return;
        }

        const int32_t left = pendingLeftSpeed;
        const int32_t right = pendingRightSpeed;
        pendingLeftSpeed = 0;
        pendingRightSpeed = 0;
        hasPendingSpeed = false;

        if (left > 0) {
            // Forward
            writeLeft(left, 0);
        } else if (left < 0) {
            // Reverse
            writeLeft(0, -left);
        } else {
            // Brake
            writeLeft(255, 255);
        }

        if (right > 0) {
            // Forward
            writeRight(right, 0);
        } else if (right < 0) {
            // Reverse
            writeRight(0, -right);
        } else {
            // Brake
            writeRight(255, 255);
        }
    }
} // namespace Motor
