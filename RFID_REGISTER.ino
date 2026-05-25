/* RFID Lock System with Emoji-like Symbols
 * Based on srituhobby.com example
 */

#include <LiquidCrystal_I2C.h>
#include <SPI.h>
#include <MFRC522.h>

#define RST_PIN 9
#define SS_PIN  10
#define RELAY_PIN 8   // pin to control lock/relay

byte readCard[4];
byte a = 0;

// Authorized UIDs
byte uid1[4] = {0x63, 0x2C, 0x10, 0x05};
byte uid2[4] = {0xD9, 0x24, 0xE5, 0x00};

LiquidCrystal_I2C lcd(0x27, 16, 2);
MFRC522 mfrc522(SS_PIN, RST_PIN);

void setup() {
  Serial.begin(9600);
  lcd.init();
  lcd.backlight();
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW); // lock initially off

  while (!Serial);
  SPI.begin();
  mfrc522.PCD_Init();
  delay(4);
  mfrc522.PCD_DumpVersionToSerial();
  lcd.setCursor(2, 0);
  lcd.print("Put your card 🔒");
}

void loop() {
  if (!mfrc522.PICC_IsNewCardPresent()) {
    return;
  }
  if (!mfrc522.PICC_ReadCardSerial()) {
    return;
  }

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Scanned UID");
  a = 0;
  Serial.println(F("Scanned PICC's UID:"));
  for (uint8_t i = 0; i < 4; i++) {
    readCard[i] = mfrc522.uid.uidByte[i];
    Serial.print(readCard[i], HEX);
    Serial.print(" ");
    lcd.setCursor(a, 1);
    lcd.print(readCard[i], HEX);
    lcd.print(" ");
    a += 3;
  }
  Serial.println("");

  // Compare with authorized UIDs
  if (checkUID(readCard, uid1) || checkUID(readCard, uid2)) {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Access Granted ✅");
    lcd.setCursor(0, 1);
    lcd.print("Door Unlocked 🔓");
    Serial.println("Access Granted");
    digitalWrite(RELAY_PIN, HIGH); // unlock
    delay(3000);                   // keep unlocked for 3s
    digitalWrite(RELAY_PIN, LOW);  // lock again
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Door Locked 🔒");
  } else {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Access Denied ❌");
    lcd.setCursor(0, 1);
    lcd.print("Door Locked 🔒");
    Serial.println("Access Denied");
    digitalWrite(RELAY_PIN, LOW);  // keep locked
    delay(2000);
  }

  mfrc522.PICC_HaltA();
}

// Helper function to compare UIDs
bool checkUID(byte card[], byte validUID[]) {
  for (int i = 0; i < 4; i++) {
    if (card[i] != validUID[i]) return false;
  }
  return true;
}
