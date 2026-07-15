#pragma once

#include <Arduino.h>

namespace Sonar {
    // Records echo edges. Registered as the echo pin interrupt callback by Setup.
    void onEchoChange();
    // Reports metres. A negative value means that no echo was received.
    bool poll(float& distanceM);
} // namespace Sonar
