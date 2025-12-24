#!/bin/bash

PASS=0
FAIL=0

test_ping() {
    SRC=$1
    DST=$2
    DESC=$3
    EXPECT=${4:-PASS}

    printf "%-60s" "$DESC"
    if docker-compose exec "$SRC" ping -c 1 -W 1 "$DST" >/dev/null 2>&1; then
        RESULT="PASS"
    else
        RESULT="FAIL"
    fi

    if [ "$RESULT" == "$EXPECT" ]; then
        echo "✓ $RESULT"
        ((PASS++))
    else
        echo "✗ $RESULT (expected $EXPECT)"
        ((FAIL++))
    fi
}

echo "============================================"
echo " Docker Network Lab – Professional Test Suite"
echo "============================================"
echo ""

echo "[1] Internal Network Tests"
test_ping client1 192.168.100.2   "Client1 → Internal Gateway"
test_ping client1 192.168.100.11  "Client1 → Client2 (same subnet)"

echo ""
echo "[2] Inter-Zone Routing Tests"
test_ping client1 10.10.10.5      "Client1 → DMZ App Server"
test_ping client1 172.20.0.10     "Client1 → External Web Server"

echo ""
echo "[3] DMZ Zone Tests"
test_ping app_server 10.10.10.2   "DMZ App → DMZ Gateway"
test_ping app_server 8.8.8.8      "DMZ App → Internet"

echo ""
echo "[4] External Zone Tests"
test_ping web_server 172.20.0.1   "Web Server → Router External IP"

echo ""
echo "[5] Security Expectation Tests"
test_ping app_server 192.168.100.10 "DMZ → Internal (should be blocked)" FAIL

echo ""
echo "============================================"
echo " Test Summary"
echo "============================================"
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
    echo "✅ Lab is fully operational and policy-compliant"
else
    echo "⚠️  Lab has connectivity or policy issues"
fi
