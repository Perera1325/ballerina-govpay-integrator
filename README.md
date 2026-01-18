<img width="1536" height="1024" alt="banner png" src="https://github.com/user-attachments/assets/0fa94f12-60f8-4652-ab6c-b28e3dac750b" /># 🇱🇰 GovPay Integrator — Ballerina + WSO2 API Manager (OAuth2/JWT)

A real-world Sri Lankan government payment integration simulation built using **Ballerina microservices** and published through **WSO2 API Manager** with **OAuth2/JWT security, throttling, and API subscription**.

<p align="center">
  <img src="assets/banner.png" alt="GovPay Banner" width="100%">
</p>



This project demonstrates the exact skills required for **WSO2 Integration Engineer / API Engineer roles**:  
✅ API orchestration • ✅ API Gateway security • ✅ Microservices • ✅ Rate limiting • ✅ Persistence • ✅ DevPortal publishing

---

## ⭐ Why this project?
In Sri Lanka, many bill payments (CEB/Water/Mobile) go through multiple providers (Dialog/Genie/Bank).  
GovPay Integrator simulates a central government payment gateway that routes payments to the right provider system with a clean API.

---

## 🚀 Tech Stack
- **Ballerina** (Microservices + Integration logic)
- **WSO2 API Manager 4.3.0** (API Publishing, OAuth2/JWT, Throttling, DevPortal)
- Docker (WSO2 API Manager)
- Git Bash automation scripts
- JSON file persistence

---

## ✅ Architecture Overview
Client → **WSO2 API Gateway (OAuth2/JWT)** → Payment Orchestrator → Provider services

- `payment-service` (Port **8080**) — Orchestrator + persistence
- `provider-dialog` (Port **9001**) — Dialog simulation
- `provider-genie`  (Port **9002**) — Genie simulation
- `provider-bank`   (Port **9003**) — Bank simulation
- `WSO2 API Manager` Gateway (Port **8280/8243**) — OAuth2 security & policies

---

## 📌 Folder Structure
```bash
ballerina-govpay-integrator/
 ├── payment-service/
 ├── provider-dialog/
 ├── provider-genie/
 ├── provider-bank/
 ├── scripts/
 │    ├── run-all.sh
 │    ├── stop-all.sh
 │    └── test.sh
 ├── wso2/
 │    └── docker-compose.yml
 └── README.md



⚡ Quick Start (Run Everything)
✅ Start provider + payment services (Day 6 automation)
cd scripts
bash run-all.sh

✅ Stop all services
bash stop-all.sh

✅ Run tests
bash test.sh

✅ Payment Service Endpoints (Direct Access — Day 5)

Base URL:

http://localhost:8080

Health
curl http://localhost:8080/health

Create Payment
curl -X POST http://localhost:8080/pay \
-H "x-api-key: govpay-secret-123" \
-H "Content-Type: application/json" \
-d "{\"amount\":2500,\"currency\":\"LKR\",\"provider\":\"dialog\",\"reference\":\"BILL_CEB_10023\"}"

Get Payment by ID
curl -H "x-api-key: govpay-secret-123" \
http://localhost:8080/payments/<PAYMENT_ID>

List Payments
curl -H "x-api-key: govpay-secret-123" \
http://localhost:8080/payments


🔐 WSO2 API Manager Deployment (Day 7)

GovPay Integrator is published as an API in WSO2 API Manager with:
✅ OAuth2/JWT Security
✅ Subscription + token generation in Dev Portal
✅ Policies (Header injection for backend auth)
✅ Gateway routing & analytics-ready design

✅ Run WSO2 API Manager (Docker)
cd wso2
docker compose up -d
docker ps


Publisher:

https://localhost:9443/publisher


Dev Portal:

https://localhost:9443/devportal


Default login:

admin / admin

✅ Call API Through WSO2 Gateway (OAuth2)

Base Gateway:

http://localhost:8280/govpay/1.0.0

Health
curl http://localhost:8280/govpay/1.0.0/health

Create Payment via WSO2 Gateway (OAuth2/JWT)
curl -X POST http://localhost:8280/govpay/1.0.0/pay \
-H "Authorization: Bearer <ACCESS_TOKEN>" \
-H "Content-Type: application/json" \
-d "{\"amount\":2500,\"currency\":\"LKR\",\"provider\":\"dialog\",\"reference\":\"BILL_CEB_7788\"}"

✅ Persistence (Day 5)

Payments are stored inside:

payment-service/payments.json


After restart:
✅ old payments remain available via /payments

📅 7-Day Development Progress

✅ Day 1: Repo setup + project plan + folders
✅ Day 2: Payment Service API (POST /pay, GET /payments/{id})
✅ Day 3: Added 3 provider microservices + routing
✅ Day 4: API Security (x-api-key) + basic rate limiting
✅ Day 5: File persistence (payments.json) + payment history API
✅ Day 6: Automation scripts (run-all / stop-all / test)
✅ Day 7: WSO2 API Manager publishing (OAuth2/JWT + Gateway policies)

🧠 Skills Demonstrated (WSO2-ready)

✅ Microservice design
✅ API Orchestration + Routing
✅ Gateway-level security (OAuth2/JWT)
✅ Backend security policy injection
✅ API versioning & context management
✅ Throttling / SLA plans
✅ DevPortal subscription workflow
✅ Automation & professional documentation

👤 Author

Vinod Perera
Dual Degree Undergraduate: Computer Science + Electrical & Electronic Engineering
GitHub: https://github.com/Perera1325


⭐ If you found this useful, give the repo a star!


