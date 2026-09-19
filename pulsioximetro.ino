int red = 10;
int infrared = 11;
int volt = 12;
int signal = A0;

int brightnessR = 80;
int brightnessIR = 40;


void setup() {
  Serial.begin(9600);

  pinMode(red, OUTPUT);
  pinMode(infrared, OUTPUT);
  pinMode(volt, OUTPUT);   
  pinMode(signal, INPUT);
  digitalWrite(volt, HIGH); 

}

void loop() {
  analogWrite(red, brightnessR);
  analogWrite(infrared, 0);
  Serial.println("red");
  int sensorValue = analogRead(signal);
  Serial.println(sensorValue);
  delay(5000);

  analogWrite(red, 0);
  analogWrite(infrared, brightnessIR);
  Serial.println("infrared");
  sensorValue = analogRead(signal);
  Serial.println(sensorValue);
  delay(5000);

}