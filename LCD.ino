#include <Wire.h>
#include <LiquidCrystal_I2C.h>

// Set the LCD address to 0x27 (common) or 0x3F depending on your module
LiquidCrystal_I2C lcd(0x27, 16, 2);

void setup() {
  // Initialize the LCD
  lcd.init();
  lcd.backlight();  // Turn on the backlight

  // Print text on the LCD
  lcd.setCursor(0, 0);                 // First row, first column
  lcd.print("SIDDHARTH SINGH");        // First line

  lcd.setCursor(0, 1);                 // Second row, first column
  lcd.print("ARPITA NIBEDITA");        // Second line
}

void loop() {
  // Nothing needed here since text is static
}
