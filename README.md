Smart Door Lock IoT Major Project

A comprehensive IoT-based security solution integrating hardware automation, mobile/web access, and machine learning-driven anomaly detection. This project provides a secure, multi-layered entry system for residential and enterprise applications. The system utilizes multi-factor authentication and behavioral modeling to verify identity and detect unauthorized access patterns.

🚀 Key Features

Multi-Factor Authentication: Support for RFID, Fingerprint, Keypad Patterns, and Voice Auth.

Hardware Integration: ESP32/Arduino-based locking mechanism with PIR motion sensors, ultrasonic proximity alerts, and ESP32-CAM support.

Mobile Access: Flutter-based mobile application for on-the-go secure door control.

Web Dashboard: Admin interface (React/Bootstrap/Tailwind) for real-time monitoring, access log management, and system configuration.

AI-Powered Security: Python-based anomaly detection engine and behavioral models to identify irregular access patterns.

Robust Backend: Node.js/Express server providing RESTful APIs, RBAC (Role-Based Access Control), and secure data logging.

🛠️ Technology Stack

Domain

Technologies

Hardware

ESP32, Arduino, ESP32-CAM, RFID Module, Fingerprint Sensor, PIR, LCD, Ultrasonic, Keypad, Buzzer

Backend

Node.js, Express.js, RESTful APIs

Frontend

Flutter (Mobile), React, HTML5, Bootstrap, Tailwind CSS

AI/ML

Python (Jupyter, Pandas, NumPy, Anomaly Detection, Voice Auth)

Tools

Git, VS Code, Postman, Maven, IntelliJ IDEA

🏗️ System Architecture

The system uses an IoT-driven architecture. Hardware modules communicate via Wi-Fi/Serial to a central Node.js backend. The backend manages authentication, logging, and state, while simultaneously serving the Flutter mobile app and the Admin Web Dashboard. The Python ML module analyzes historical log data and behavioral datasets to flag potential security threats.

📂 Project Structure

/
├── ESP32_Integration/    # Arduino Firmware (.ino files for sensors/logic)
├── public/               # Web Dashboard (HTML/Bootstrap/Tailwind)
├── server.js             # Node.js backend API
├── main.dart             # Flutter mobile application
├── anomaly_detector.py   # AI Anomaly detection scripts
├── voice_auth.py         # Voice authentication logic
├── behavioral_model.ipynb# Jupyter Notebook for model training
└── data/                 # Sample datasets for behavioral analysis


⚙️ Getting Started

Clone the Repository:
git clone https://github.com/siddharth9238/Smart-door-lock-using-IoT-major-project.git

Install Backend Dependencies:
npm install express cors

Run the Server:
node server.js

Access the Dashboard:
Open http://localhost:3000 in your browser.

Developed as a Major Project. All rights reserved.
