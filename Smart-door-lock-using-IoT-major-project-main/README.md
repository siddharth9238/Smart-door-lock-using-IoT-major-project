Project Overview
The system provides a multi-factor authentication approach for secure access control. It combines physical hardware components—such as RFID, fingerprint sensors, and keypads—with software-based behavioral models to verify identity and detect anomalies.

Key Features
Multi-Modal Authentication: Supports entry via RFID, biometric fingerprint scanning, and keypad entry.

Advanced Security: Incorporates voice authentication and anomaly detection to identify unauthorized patterns.

IoT Integration: Utilizes Arduino and ESP32-CAM for hardware control and sensor data processing.

Behavioral Modeling: Implements a machine learning-based behavioral model to monitor and predict security threats.

Mobile & Server Backend: Includes a dedicated mobile interface (Dart) and a Node.js server for managing door lock states and user data.

Technologies Used
Hardware: Arduino, ESP32-CAM, RFID Module, Fingerprint Sensor, Keypad, Buzzer, Ultrasonic Sensor, PIR Sensor.

Backend: Node.js (server.js).

Mobile: Dart (main.dart).

Data & AI: Python (for voice_auth.py and anomaly_detector.py), Jupyter Notebooks (behavioral_model.ipynb), and CSV datasets.

Project Structure
Arduino Firmware: .ino files for specific components (Buzzer, LCD, PIR, RFID, Fingerprint) and integrated system logic.

Analytics & AI: Python scripts for anomaly detection, voice recognition, and model training.

Backend & App: Server-side logic and mobile application code.

Data: Sample datasets for behavioral analysis.

______________________________________________________________________________________________________________________________________________________
This project was developed as a major initiative focusing on the intersection of IoT and intelligent security systems.
