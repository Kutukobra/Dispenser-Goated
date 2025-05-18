const int trigPin = 2;  // PD2
const int echoPin = 3;  // PD3

long duration;
int distance;

void setup() {
  pinMode(trigPin, OUTPUT); // Set trigPin sebagai OUTPUT
  pinMode(echoPin, INPUT);  // Set echoPin sebagai INPUT
  Serial.begin(9600);       // Mulai komunikasi serial
}

void loop() {
  // Bersihkan trigPin
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);

  // Kirim pulsa trigger 10 mikrodetik
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  // Baca durasi pulsa echo
  duration = pulseIn(echoPin, HIGH);

  // Hitung jarak (dalam cm)
  distance = duration * 0.034 / 2;

  // Tampilkan hasil di Serial Monitor
  Serial.print("Distance: ");
  Serial.print(distance);
  Serial.println(" cm");

  delay(500); // Tambahkan sedikit jeda untuk stabilitas
}
