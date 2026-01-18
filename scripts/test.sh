#!/usr/bin/env bash

echo "=============================="
echo " GovPay Integrator - TEST"
echo "=============================="

echo ""
echo "1) Health Check:"
curl http://localhost:8080/health
echo ""

echo ""
echo "2) Create Payment (Dialog):"
curl -X POST http://localhost:8080/pay \
  -H "x-api-key: govpay-secret-123" \
  -H "Content-Type: application/json" \
  -d "{\"amount\":2500,\"currency\":\"LKR\",\"provider\":\"dialog\",\"reference\":\"BILL_CEB_10023\"}"
echo ""

echo ""
echo "3) List Payments:"
curl -H "x-api-key: govpay-secret-123" http://localhost:8080/payments
echo ""

echo ""
echo "✅ Test completed!"
