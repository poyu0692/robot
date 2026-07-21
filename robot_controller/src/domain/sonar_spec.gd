class_name SonarSpec extends RefCounted

const MAX_RANGE := 4.0
# A distance return can originate anywhere in the ultrasonic beam, not only
# directly ahead.  Keep the map conservative by modelling that beam as ±15°.
const HALF_FOV := deg_to_rad(15.0)
