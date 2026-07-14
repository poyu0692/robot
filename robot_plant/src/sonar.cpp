#include "sonar.h"
#include "const.h"

namespace Sonar {
    namespace {
        enum class State {
            Idle,
            WaitEchoRise,
            WaitEchoFall,
        };

        State state = State::Idle;
        unsigned long triggerUs = 0;
        unsigned long echoStartUs = 0;

        float echoDistance(unsigned long roundTripUs) {
            float oneWayUs = 0.5f * roundTripUs;
            float speed = 331.4f + 0.6f * SONAR_TEMPERATURE_C;

            return speed * oneWayUs / 1000000.0f;
        }
    } // namespace

    bool poll(float& distanceM) {
        unsigned long now = micros();

        switch (state) {
            case State::Idle:
                digitalWrite(Pin::SONAR_TRIG, HIGH);
                delayMicroseconds(10);
                digitalWrite(Pin::SONAR_TRIG, LOW);

                triggerUs = micros();
                state = State::WaitEchoRise;
                return false;

            case State::WaitEchoRise:
                if (digitalRead(Pin::SONAR_ECHO) == HIGH) {
                    echoStartUs = now;
                    state = State::WaitEchoFall;
                } else if (now - triggerUs >= SONAR_ECHO_TIMEOUT_US) {
                    distanceM = -1.0f;
                    state = State::Idle;
                    return true;
                }
                return false;

            case State::WaitEchoFall:
                if (digitalRead(Pin::SONAR_ECHO) == LOW) {
                    distanceM = echoDistance(now - echoStartUs);
                    state = State::Idle;
                    return true;
                }

                if (now - echoStartUs >= SONAR_ECHO_TIMEOUT_US) {
                    distanceM = -1.0f;
                    state = State::Idle;
                    return true;
                }
                return false;
        }

        return false;
    }
} // namespace Sonar
