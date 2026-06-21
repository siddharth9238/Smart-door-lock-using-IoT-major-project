long duration;
int distance;

const int trigPin = 10;
const int echoPin = 11;  // ✅ corrected name (camelCase)

void setup() {
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);
  Serial.begin(115200);
}

void loop() {
  // Clear the trigger pin
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);

  // Send a 10µs pulse
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  // Read echo response
  duration = pulseIn(echoPin, HIGH);

  // Calculate distance (speed of sound = 0.034 cm/µs, divide by 2 for round trip)
  distance = duration * 0.034 / 2;

  // Print result
  Serial.print("Distance: ");
  Serial.print(distance);
  Serial.println(" cm");

  delay(500); // small delay for readability
}
