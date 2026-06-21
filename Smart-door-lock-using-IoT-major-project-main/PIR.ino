void setup() {
  pinMode(2, INPUT);//define arduino pin
  pinMode(3, OUTPUT);//define arduino pin
  Serial.begin(9600);//enable serial monitor
}
void loop() {
  bool value = digitalRead(2);//get value and save it boolean veriable
  if (value == 1) { //check condition
    Serial.println("ON");//print serial monitor ON
    digitalWrite(3,HIGH);//LED on
  } else {
    Serial.println("OFF");//print serial monitor OFF
    digitalWrite(3,LOW);//LED off
  }
}
