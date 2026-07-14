#pragma once

#include <Arduino.h>

namespace Sonar {
    // Reports metres. A negative value means that no echo was received.
    bool poll(float& distanceM);
} // namespace Sonar
