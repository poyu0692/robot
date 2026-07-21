#include "motor.h"
#include <Arduino.h>
#include "const.h"

namespace {
    int pendingLeftSpeed;
    int pendingRightSpeed;
    bool hasPendingSpeed = false;

    void writeLeft(int forward, int reverse) {
        analogWrite(Pin::LEFT_MOTOR_FWD, forward);
        analogWrite(Pin::LEFT_MOTOR_REV, reverse);
    }

    void writeRight(int forward, int reverse) {
        analogWrite(Pin::RIGHT_MOTOR_FWD, forward);
        analogWrite(Pin::RIGHT_MOTOR_REV, reverse);
    }
} // namespace

namespace Motor {
    void printSpeed(int left, int right) {
        Serial.print("left: ");
        Serial.print(left);
        Serial.print(", right: ");
        Serial.println(right);
    }

    void setSpeed(int left, int right) {
        pendingLeftSpeed = left;
        pendingRightSpeed = right;
        hasPendingSpeed = true;
    }

    void drive() {
        if (!hasPendingSpeed) {
            return;
        }

        const int left = pendingLeftSpeed;
        const int right = pendingRightSpeed;
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
