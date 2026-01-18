#!/usr/bin/env bash

echo "Stopping all running java processes used by Ballerina..."

taskkill /F /IM java.exe > /dev/null 2>&1

echo "✅ All services stopped."
