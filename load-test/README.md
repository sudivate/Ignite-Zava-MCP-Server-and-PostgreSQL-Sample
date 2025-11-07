# Zava Shop Load Testing

This folder contains load testing scripts for the Zava Shop application, specifically targeting the Customer Chat (ChatKit) endpoint.

## Overview

The load test simulates realistic customer chat interactions including:
- User authentication with JWT tokens
- Sending various chat messages
- Handling streaming SSE responses
- Periodic health checks

## Files

- **locustfile.py** - Main Locust load test script
- **requirements.txt** - Python dependencies
- **config.yaml** - Azure Load Testing configuration
- **.env.example** - Example environment variables

## Running Locally

### Prerequisites

```bash
pip install -r requirements.txt
```

### Create .env file

```bash
cp .env.example .env
# Edit .env with your settings
```

### Run with Locust UI

```bash
locust -f locustfile.py --host https://zavalife.com
```

Then open http://localhost:8089 in your browser.

### Run Headless

```bash
# Run with 50 users, spawn rate of 5 users/sec, for 5 minutes
locust -f locustfile.py \
  --host https://zavalife.com \
  -u 50 \
  -r 5 \
  --run-time 5m \
  --html report.html
```

### Example Commands

**Quick test (10 users, 1 minute):**
```bash
locust -f locustfile.py --host https://zavalife.com -u 10 -r 2 --run-time 1m
```

**Stress test (100 users, 10 minutes):**
```bash
locust -f locustfile.py --host https://zavalife.com -u 100 -r 10 --run-time 10m --html stress-report.html
```

**With detailed logging:**
```bash
ENABLE_LOGGING=True locust -f locustfile.py --host https://zavalife.com -u 10 -r 2 --run-time 2m
```

## Running in Azure Load Testing

### Prerequisites

1. Azure Load Testing resource created
2. Azure CLI installed and logged in

### Deploy and Run

Using the Azure Load Testing VS Code extension or CLI:

```bash
# Using Azure CLI (if available)
az load test create \
  --name chatkit-load-test \
  --resource-group zava-shop-rg \
  --load-test-resource <your-load-test-resource> \
  --load-test-config-file config.yaml \
  --test-plan locustfile.py
```

Or use the VS Code Azure Load Testing extension to:
1. Right-click on `config.yaml`
2. Select "Upload test"
3. Monitor results in the Azure portal

## Test Scenarios

The load test includes the following tasks:

### 1. Authentication (on_start)
- ✅ Authenticates as customer
- ✅ Obtains JWT access token
- ✅ Reuses token for subsequent requests

### 2. Send Chat Message (Weight: 10)
- ⚠️ **Note:** The ChatKit endpoint requires a specific request format that the ChatKit React component generates
- The endpoint expects requests formatted by the `@openai/chatkit-react` library
- Direct HTTP calls need to match ChatKit's internal protocol with proper discriminators
- For now, this test demonstrates the authentication flow; actual chat testing requires the ChatKit client library

### 3. Health Check (Weight: 2)
- ✅ Periodic health endpoint checks
- ✅ Ensures API availability

## Current Test Status

**Working:**
- ✅ User authentication with JWT tokens
- ✅ Token management and reuse
- ✅ Health check endpoint
- ✅ API responsiveness testing

**Limitations:**
- ⚠️ ChatKit message sending requires ChatKit protocol format
- ⚠️ ChatKit uses a tagged-union discriminator system that's not easily replicated without the ChatKit client library
- For complete chat testing, consider using the frontend E2E tests with Playwright/Cypress

To test the actual chat functionality, use the frontend application at https://zavalife.com and log in as a customer.

## Customer Credentials

The test uses the following demo customer accounts (defined in `app/api/src/zava_shop_api/auth.py`):
- `stacey` / Password from DEMO_PASSWORD env var (default: `stacey123`)

**Note:** To add more customer accounts for more realistic load testing, update the USERS dictionary in `app/api/src/zava_shop_api/auth.py` and add them to the CUSTOMER_CREDENTIALS list in `locustfile.py`.

For production systems, you would typically have a proper user database with hashed passwords.

## Sample Chat Messages

The test cycles through realistic questions:
- Product inquiries
- Order tracking
- Store information
- Sales and discounts
- Return policy questions
- Recommendations
- Customer support requests

## Metrics

The test tracks:
- **Response Time**: Time to receive first response chunk
- **Success Rate**: Percentage of successful requests
- **Failures**: Authentication failures, permission errors, timeouts
- **Request Rate**: Requests per second
- **User Count**: Concurrent simulated users

## Failure Criteria (Azure Load Testing)

Tests fail if:
- Average response time > 5000ms
- Error rate > 10%
- Error rate > 90% for 60 seconds (auto-stop)

## Troubleshooting

### Authentication Failures
- Verify customer credentials exist in database
- Check if demo password is correct (default: tracey123, etc.)
- Ensure `/api/login` endpoint is accessible

### Permission Errors (403)
- Verify users have "customer" role
- Check workload identity permissions for AI Foundry

### Timeout Issues
- Increase `timeout_duration` in locustfile.py
- Check if ChatKit agents are responding
- Verify Azure AI Foundry permissions

### Streaming Response Issues
- The test reads up to 10 chunks per request
- Adjust chunk reading logic if needed
- Check SSE format in API responses

## Performance Baselines

Expected performance (based on infrastructure):
- **Response Time**: < 2000ms average
- **Success Rate**: > 95%
- **Concurrent Users**: Up to 100 users supported
- **Throughput**: ~20-30 requests/second

## Notes

- The test simulates realistic user think time (2-5 seconds between requests)
- Each virtual user maintains their own authenticated session
- Streaming responses are partially read to simulate realistic client behavior
- Health checks ensure the API remains responsive during load

## Future Enhancements

- [ ] Add order creation scenarios
- [ ] Test product search endpoints
- [ ] Include cart operations
- [ ] Add management dashboard load tests
- [ ] Test MCP server endpoints
- [ ] Implement custom load patterns (spike, ramp-up/down)
