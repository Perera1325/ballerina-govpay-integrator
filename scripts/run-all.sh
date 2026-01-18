#!/usr/bin/env bash

echo "Starting GovPay Integrator services..."

# Go to repo root from scripts folder
cd ..

# ✅ Use "start" through Windows cmd to open Git Bash terminals
cmd.exe //c start "provider-dialog" bash -lc "cd provider-dialog && bal run"
cmd.exe //c start "provider-genie"  bash -lc "cd provider-genie && bal run"
cmd.exe //c start "provider-bank"   bash -lc "cd provider-bank && bal run"
cmd.exe //c start "payment-service" bash -lc "cd payment-service && bal run"

echo "✅ All services started in separate terminals."
echo "Payment service: http://localhost:8080/health"
