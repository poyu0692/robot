#include "sonar.h"
#include "const.h"

namespace Sonar {
    namespace {
        enum class State {
            Idle,
            WaitEcho,
        };

        State state = State::Idle;
        unsigned long triggerUs = 0;
        bool hasTriggered = false;

        volatile unsigned long echoRiseUs = 0;
        volatile unsigned long echoDurationUs = 0;
        volatile bool echoRiseSeen = false;
        volatile bool echoReady = false;
        volatile bool measurementActive = false;

        float echoDistance(unsigned long roundTripUs) {
            float oneWayUs = 0.5f * roundTripUs;
            float speed = 331.4f + 0.6f * SONAR_TEMPERATURE_C;

            return speed * oneWayUs / 1000000.0f;
        }

    } // namespace

    void onEchoChange() {
        if (!measurementActive) {
            return;
        }

        const unsigned long now = micros();
        if (digitalRead(Pin::SONAR_ECHO) == HIGH) {
            echoRiseUs = now;
            echoRiseSeen = true;
        } else if (echoRiseSeen) {
            echoDurationUs = now - echoRiseUs;
            echoReady = true;
            measurementActive = false;
        }
    }

    bool poll(float& distanceM) {
        const unsigned long now = micros();

        switch (state) {
            case State::Idle:
                if (hasTriggered &&
                    now - triggerUs < SONAR_TRIGGER_INTERVAL_US) {
                    return false;
                }

                noInterrupts();
                echoRiseSeen = false;
                echoReady = false;
                measurementActive = true;
                interrupts();

                digitalWrite(Pin::SONAR_TRIG, HIGH);
                delayMicroseconds(10);
                digitalWrite(Pin::SONAR_TRIG, LOW);

                triggerUs = micros();
                hasTriggered = true;
                state = State::WaitEcho;
                return false;

            case State::WaitEcho: {
                const bool timedOut = now - triggerUs >= SONAR_ECHO_TIMEOUT_US;
                bool ready = false;
                unsigned long durationUs = 0;

                noInterrupts();
                if (echoReady) {
                    ready = true;
                    durationUs = echoDurationUs;
                    echoReady = false;
                } else if (timedOut) {
                    measurementActive = false;
                    echoRiseSeen = false;
                }
                interrupts();

                if (ready) {
                    distanceM = echoDistance(durationUs);
                    state = State::Idle;
                    return true;
                }
                if (timedOut) {
                    distanceM = -1.0f;
                    state = State::Idle;
                    return true;
                }
                return false;
            }
        }

        return false;
    }
} // namespace Sonar
