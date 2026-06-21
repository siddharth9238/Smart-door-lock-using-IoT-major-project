/*
 * FINAL INTEGRATED CODE: SEQUENTIAL SMART DOOR LOCK
 * SEQUENCE: 1. Keypad -> 2. Fingerprint -> 3. RFID
 */

#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <Keypad.h>
#include <SPI.h>
#include <MFRC522.h>
#include <Adafruit_Fingerprint.h>
#include <SoftwareSerial.h>

// --- CONFIGURATION ---
#define RELAY_UNLOCK_LEVEL HIGH  
#define RELAY_LOCK_LEVEL   LOW  // Standard Active Low/High adjustment

// --- PIN DEFINITIONS ---
#define SOLENOID_RELAY_PIN 0  // RX (Unplug to upload)
#define BUZZER_PIN 1          // TX (Unplug to upload)
#define WIFI_UNLOCK_PIN A2  
#define PIR_PIN A1
#define SS_PIN 10
#define RST_PIN 9   
#define FP_RX 2
#define FP_TX 3

// Keypad setup
const byte ROWS = 4;
const byte COLS = 3;
char keys[ROWS][COLS] = {
  {'1','2','3'}, {'4','5','6'}, {'7','8','9'}, {'*','0','#'}
};
byte rowPins[ROWS] = {4, 5, 6, 7}; 
byte colPins[COLS] = {8, 9, A0};

Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);
LiquidCrystal_I2C lcd(0x27, 16, 2);
MFRC522 mfrc522(SS_PIN, RST_PIN);
SoftwareSerial mySerial(FP_RX, FP_TX);
Adafruit_Fingerprint finger = Adafruit_Fingerprint(&mySerial);

// --- STATE VARIABLES ---
String password = "1234"; 
String inputCode = "";
int authStage = 1; // 1: PIN, 2: Fingerprint, 3: RFID
bool systemLocked = true;

byte uid1[4] = {0x63, 0x2C, 0x10, 0x05};
byte uid2[4] = {0xD9, 0x24, 0xE5, 0x00};

void setup() {
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(SOLENOID_RELAY_PIN, OUTPUT);
  pinMode(WIFI_UNLOCK_PIN, INPUT);
  
  lockDoor(); // Initial state

  lcd.init();
  lcd.backlight();
  
  SPI.begin();
  mfrc522.PCD_Init();
  finger.begin(57600);
  
  resetSystem();
}

void loop() {
  // Remote unlock bypasses sequence
  if (digitalRead(WIFI_UNLOCK_PIN) == HIGH) {
    processUnlock("Remote Open");
  }

  switch (authStage) {
    case 1: handleKeypad();      break;
    case 2: handleFingerprint(); break;
    case 3: handleRFID();        break;
  }
}

// --- DOOR CONTROL ---
void lockDoor() {
  digitalWrite(SOLENOID_RELAY_PIN, RELAY_LOCK_LEVEL);
  // Audio feedback for locking
  playTone(800, 500); 
}

void processUnlock(String msg) {
  lcd.clear();
  lcd.print("ACCESS GRANTED");
  lcd.setCursor(0, 1);
  lcd.print(msg);
  
  digitalWrite(SOLENOID_RELAY_PIN, RELAY_UNLOCK_LEVEL);
  
  // Audio feedback for unlocking
  playTone(2500, 100); delay(50);
  playTone(2500, 100);
  
  delay(5000); // Door open time
  
  lockDoor();
  resetSystem();
}

// --- STAGE 1: KEYPAD ---
void handleKeypad() {
  char key = keypad.getKey();
  if (key) {
    playTone(2000, 50);
    
    if (key == '#') {
      if (inputCode == password) {
        authStage = 2;
        inputCode = "";
        playTone(3000, 200);
        updateLCD();
      } else {
        lcd.clear();
        lcd.print("WRONG PIN!");
        playTone(300, 800);
        delay(1500);
        inputCode = "";
        updateLCD();
      }
    } else if (key == '*') {
      inputCode = "";
      updateLCD();
    } else {
      inputCode += key;
      lcd.setCursor(0, 1);
      lcd.print("            "); // Clear specific part of line
      lcd.setCursor(0, 1);
      lcd.print(inputCode);
    }
  }
}

// --- STAGE 2: FINGERPRINT ---
void handleFingerprint() {
  uint8_t p = finger.getImage();
  if (p != FINGERPRINT_OK) return;
  p = finger.image2Tz();
  if (p != FINGERPRINT_OK) return;
  p = finger.fingerFastSearch();

  if (p == FINGERPRINT_OK) {
    authStage = 3;
    playTone(3000, 200);
    lcd.clear();
    lcd.print("FINGER OK");
    delay(1000);
    updateLCD();
  } else {
    lcd.setCursor(0,1);
    lcd.print("Unknown Finger");
    playTone(200, 500);
    delay(1000);
    updateLCD();
  }
}

// --- STAGE 3: RFID ---
void handleRFID() {
  if (!mfrc522.PICC_IsNewCardPresent() || !mfrc522.PICC_ReadCardSerial()) return;

  if (checkUID(mfrc522.uid.uidByte, uid1) || checkUID(mfrc522.uid.uidByte, uid2)) {
    processUnlock("Authenticated");
  } else {
    lcd.clear();
    lcd.print("ID: ");
    for (byte i = 0; i < 4; i++) {
      if(mfrc522.uid.uidByte[i] < 0x10) lcd.print("0");
      lcd.print(mfrc522.uid.uidByte[i], HEX);
    }
    playTone(200, 500);
    delay(3000);
    updateLCD();
  }
  mfrc522.PICC_HaltA();
  mfrc522.PCD_StopCrypto1();
}

// --- HELPERS ---
void updateLCD() {
  lcd.clear();
  switch (authStage) {
    case 1:
      lcd.print("STEP 1: KEYPAD");
      lcd.setCursor(0, 1);
      lcd.print("Enter PIN:");
      break;
    case 2:
      lcd.print("STEP 2: BIOMETRIC");
      lcd.setCursor(0, 1);
      lcd.print("Scan Finger...");
      break;
    case 3:
      lcd.print("STEP 3: RFID");
      lcd.setCursor(0, 1);
      lcd.print("Scan Card...");
      break;
  }
}

void resetSystem() {
  authStage = 1;
  inputCode = "";
  updateLCD();
}

void playTone(int freq, int duration) {
  tone(BUZZER_PIN, freq);
  delay(duration);
  noTone(BUZZER_PIN);
}

bool checkUID(byte card[], byte valid[]) {
  for (int i = 0; i < 4; i++) {
    if (card[i] != valid[i]) return false;
  }
  return true;
}
