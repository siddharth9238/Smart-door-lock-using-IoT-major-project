#include <Keypad.h>

// ---------- KEYPAD SETUP ----------
const byte ROWS = 4;
const byte COLS = 3;

char keys[ROWS][COLS] = {
  {'1','2','3'},
  {'4','5','6'},
  {'7','8','9'},
  {'*','0','#'}
};

// ✅ EXACT CONNECTION AS YOU SAID
byte rowPins[ROWS] = {2, 3, 4, 5};   // R1–R4 → D2, D3, D4, D5
byte colPins[COLS] = {6, 7, 8};      // C1–C3 → D6, D7, D8

Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);

// ---------- PASSWORD SETUP ----------
String password = "1234";
String input = "";
String newPassword = "";

bool setMode = false;
const byte PASS_LEN = 4;

void setup() {
  Serial.begin(9600);
  Serial.println("System Ready");
  Serial.println("Press * to SET password");
  Serial.println("Enter Password:");
}

void loop() {
  char key = keypad.getKey();
  if (!key) return;

  // ---------- SET PASSWORD MODE ----------
  if (setMode) {
    if (key == '#') {
      if (newPassword.length() == PASS_LEN) {
        password = newPassword;
        Serial.println("\nPassword SET successfully ✅");
      } else {
        Serial.println("\nPassword must be 4 digits ❌");
      }
      newPassword = "";
      setMode = false;
      Serial.println("Enter Password:");
    }
    else if (key == '*') {
      newPassword = "";
      setMode = false;
      Serial.println("\nSet password cancelled");
    }
    else {
      if (newPassword.length() < PASS_LEN) {
        newPassword += key;
        Serial.print("*");
      }
    }
    return;
  }

  // ---------- NORMAL PASSWORD CHECK ----------
  if (key == '*') {
    setMode = true;
    input = "";
    Serial.println("\nSET PASSWORD MODE");
    Serial.println("Enter NEW password:");
  }
  else if (key == '#') {
    Serial.println();
    if (input == password) {
      Serial.println("ACCESS GRANTED 🔓");
    } else {
      Serial.println("ACCESS DENIED ❌");
    }
    input = "";
    Serial.println("Enter Password:");
  }
  else {
    if (input.length() < PASS_LEN) {
      input += key;
      Serial.print("*");
    }
  }
}
