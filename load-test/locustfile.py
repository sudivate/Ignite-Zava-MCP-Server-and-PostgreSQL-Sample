# Python
import os
import logging
import random
from locust import HttpUser, task, between
from dotenv import load_dotenv

# Load environment variables from .env file if present
load_dotenv()

# Sample chat messages for realistic load testing
# Based on actual customer order data - order-specific questions only
CHAT_MESSAGES = [
    # Order history and lookup
    "Can you show me my recent orders?",
    "What orders have I placed?",
    "Show me my order history",
    "Can you list all my past orders?",
    
    # Specific order tracking - Order #43188 (Aug 16, SF Union Square)
    "What's the status of my order #43188?",
    "I placed an order on August 16th, can you help me find it?",
    "Can you check order 43188 for me?",
    "Tell me about my order from August 16th at SF Union Square",
    "I ordered 10 Athletic Performance Tees - can you find that order?",
    "What's the total for order #43188?",
    
    # Specific order tracking - Order #20518 (Jun 13, Portland)
    "Can you check if my order from the Portland Pearl District store has shipped?",
    "What's the status of order #20518?",
    "I placed an order on June 13th - can you find it?",
    "Tell me about my order from Portland in June",
    "I ordered Baseball Caps and Combat Boots - which order was that?",
    "What was the total for my Portland order in June?",
    "How many items were in order #20518?",
    
    # Specific order tracking - Order #10816 (Mar 6, Phoenix)
    "Can you find my order from March 6th?",
    "What's the status of order #10816?",
    "I ordered from the Phoenix Scottsdale store - can you check that order?",
    "Tell me about my March order from Phoenix",
    "I bought a Laptop Commuter Backpack and Brogue Wingtip Shoes - which order?",
    "What was the total for order #10816?",
    
    # Specific order tracking - Order #38461 (Jan 14, Atlanta)
    "I need to find my order from January 14th",
    "What's the status of order #38461?",
    "Can you check my order from the Atlanta Midtown store?",
    "Tell me about my January order",
    "I ordered High-Top Sneakers in January - which order was that?",
    "What items were in order #38461?",
    
    # Specific order tracking - Order #39814 (Nov 17, NYC)
    "Can you find my order from November 17th last year?",
    "What's the status of order #39814?",
    "I placed an order at the NYC Times Square store - can you check it?",
    "Tell me about my order from NYC Times Square",
    "I ordered a Trench Coat and Flannel Button-Down - which order?",
    "What was the total for order #39814?",
    "How many items did I order in November last year?",
    
    # Order details and items
    "What items were in my August order?",
    "Can you show me the products from order #20518?",
    "What did I buy in my last order?",
    "How much did I spend on my Portland order?",
    "What discounts did I get on order #39814?",
    "Show me the items from my most recent order",
    
    # Order modifications and returns
    "Can I return items from order #20518?",
    "I need to return the Combat Boots from my June order",
    "Can I exchange an item from order #43188?",
    "I want to return the Athletic Performance Hoodie from order #10816",
    "Can I get a refund for order #38461?",
    "How do I return items from my January order?",
]

# Customer credentials for authentication
# These are demo users that exist in the authentication system
CUSTOMER_CREDENTIALS = [
    {"username": "stacey", "password": os.getenv("DEMO_PASSWORD", "")},
]

# Store manager credentials (for future testing)
MANAGER_CREDENTIALS = [
    {"username": "manager1", "password": os.getenv("DEMO_PASSWORD", "")},
    {"username": "manager2", "password": os.getenv("DEMO_PASSWORD", "")},
]

# Admin credentials (for future testing)
ADMIN_CREDENTIALS = [
    {"username": "admin", "password": os.getenv("DEMO_PASSWORD", "")},
]

class ChatKitUser(HttpUser):
    """
    Locust user simulating customer chat interactions with the Zava Shop ChatKit endpoint.
    Tests authentication, chat message sending, and streaming responses.
    """
    wait_time = between(2, 5)  # Wait 2-5 seconds between tasks (realistic user behavior)
    host = os.getenv('HOST')  # Load from .env file (e.g., https://{Host}.com)
    timeout_duration = 90  # seconds

    def on_start(self):
        """Initialize user session and authenticate."""
        # Set debug mode from environment variable
        self.ENABLE_LOGGING = os.getenv('ENABLE_LOGGING', 'True') == 'True'
        
        # Set up logging
        if self.ENABLE_LOGGING:
            logging.basicConfig(level=logging.DEBUG)
        else:
            logging.basicConfig(level=logging.WARNING)
        
        # Select random customer credentials
        self.credentials = random.choice(CUSTOMER_CREDENTIALS)
        self.access_token = None
        
        # Authenticate to get access token
        self.authenticate()

    def authenticate(self):
        """Authenticate user and obtain JWT token."""
        url = "/api/login"
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json"
        }
        payload = {
            "username": self.credentials["username"],
            "password": self.credentials["password"]
        }
        
        if self.ENABLE_LOGGING:
            print(f"[Locust] Authenticating user: {self.credentials['username']}")

        with self.client.post(
            url=url,
            headers=headers,
            json=payload,
            name="POST /api/login (auth)",
            catch_response=True,
            timeout=self.timeout_duration
        ) as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    self.access_token = data.get("access_token")
                    response.success()
                    if self.ENABLE_LOGGING:
                        print(f"[Locust] Authentication succeeded for {self.credentials['username']}")
                except Exception as e:
                    response.failure(f"Failed to parse login response: {e}")
                    if self.ENABLE_LOGGING:
                        logging.error(f"Authentication parsing error: {e}")
            else:
                response.failure(f"Authentication failed with status {response.status_code}")
                if self.ENABLE_LOGGING:
                    logging.error(f"Authentication failed: {response.text}")

    @task(10)
    def send_chat_message(self):
        """
        Send a chat message to the ChatKit endpoint.
        This simulates the primary user interaction - asking questions via chat.
        Weight: 10 (most common action)
        """
        if not self.access_token:
            if self.ENABLE_LOGGING:
                logging.warning("[Locust] No access token, skipping chat message")
            return

        url = "/api/chatkit"
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
            "Accept": "text/event-stream, application/json"
        }
        
        # Select random message
        message = random.choice(CHAT_MESSAGES)
        
        # ChatKit expects this specific format for creating threads
        # Format: {"type":"threads.create","params":{"input":{...}}}
        payload = {
            "type": "threads.create",
            "params": {
                "input": {
                    "content": [
                        {
                            "type": "input_text",
                            "text": message
                        }
                    ],
                    "quoted_text": "",
                    "attachments": [],
                    "inference_options": {}
                }
            }
        }
        
        if self.ENABLE_LOGGING:
            print(f"[Locust] Sending chat message: {message[:50]}...")

        with self.client.post(
            url=url,
            headers=headers,
            json=payload,
            name="POST /api/chatkit (send message)",
            catch_response=True,
            timeout=self.timeout_duration,
            stream=True  # Enable streaming to handle SSE responses
        ) as response:
            if response.status_code == 200:
                # For streaming responses, try to read some chunks
                try:
                    chunk_count = 0
                    for chunk in response.iter_content(chunk_size=1024):
                        if chunk:
                            chunk_count += 1
                            # Read up to 10 chunks to simulate realistic user behavior
                            if chunk_count >= 10:
                                break
                    
                    response.success()
                    if self.ENABLE_LOGGING:
                        print(f"[Locust] Chat message succeeded, received {chunk_count} chunks")
                except Exception as e:
                    # Still count as success if we got 200, even if streaming had issues
                    response.success()
                    if self.ENABLE_LOGGING:
                        logging.warning(f"[Locust] Streaming read warning: {e}")
            elif response.status_code == 401:
                # Token expired, re-authenticate
                if self.ENABLE_LOGGING:
                    logging.info("[Locust] Token expired, re-authenticating")
                self.authenticate()
                response.failure("Token expired, re-authenticated")
            elif response.status_code == 403:
                response.failure("Access denied (403) - user may not have customer role")
                if self.ENABLE_LOGGING:
                    logging.error(f"Access denied for user {self.credentials['username']}")
            else:
                msg = f"Chat message failed with status {response.status_code}"
                response.failure(msg)
                if self.ENABLE_LOGGING:
                    logging.error(f"{msg}, response: {response.text[:200]}")

    # @task(2)
    # def health_check(self):
    #     """
    #     Perform health check to verify API is responsive.
    #     Weight: 2 (occasional check)
    #     """
    #     url = "/health"  # Note: health endpoint is at /health, not /api/health
    #     headers = {
    #         "Accept": "application/json"
    #     }
    #     
    #     with self.client.get(
    #         url=url,
    #         headers=headers,
    #         name="GET /health (health check)",
    #         catch_response=True,
    #         timeout=self.timeout_duration
    #     ) as response:
    #         if response.status_code == 200:
    #             response.success()
    #             if self.ENABLE_LOGGING:
    #                 print("[Locust] Health check passed")
    #         else:
    #             response.failure(f"Health check failed with status {response.status_code}")

    def on_stop(self):
        """Cleanup when user session ends."""
        if self.ENABLE_LOGGING:
            print(f"[Locust] User session ended for {self.credentials['username']}")

# To run locally (set HOST in .env file):
# locust -f locustfile.py -u 10 -r 2 --run-time 2m
# 
# To run with specific configuration:
# locust -f locustfile.py -u 50 -r 5 --run-time 5m --html report.html

# To run locally:
# locust -f locustfile.py -u 10 -r 2 --run-time 2m --host https://{Host}.com
# 
# To run with specific configuration:
# locust -f locustfile.py -u 50 -r 5 --run-time 5m --host https://{Host}.com --html report.html