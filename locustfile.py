<<<<<<< HEAD
# Python
import os
import logging
import random
from locust import HttpUser, task, between
from dotenv import load_dotenv

# Load environment variables from .env file if present
load_dotenv()

# Sample chat messages for realistic load testing
CHAT_MESSAGES = [
    "What products do you have available?",
    "Can you help me find running shoes?",
    "What are your store hours?",
    "Do you have any sales or discounts?",
    "I need help tracking my order",
    "What's your return policy?",
    "Can you recommend a good laptop?",
    "Do you ship internationally?",
    "Tell me about your electronics section",
    "I'm looking for outdoor gear",
    "What brands do you carry?",
    "Can I check my order history?",
    "Do you have gift cards?",
    "What payment methods do you accept?",
    "How can I contact customer support?",
]

# Customer credentials for authentication
# These are demo customers that should exist in the system
CUSTOMER_CREDENTIALS = [
    {"username": "tracey.lopez.4", "password": "tracey123"},
    {"username": "michael.wilson.5", "password": "michael123"},
    {"username": "sarah.davis.6", "password": "sarah123"},
    {"username": "james.brown.7", "password": "james123"},
    {"username": "jennifer.taylor.8", "password": "jennifer123"},
]

class ChatKitUser(HttpUser):
    """
    Locust user simulating customer chat interactions with the Zava Shop ChatKit endpoint.
    Tests authentication, chat message sending, and streaming responses.
    """
    wait_time = between(2, 5)  # Wait 2-5 seconds between tasks (realistic user behavior)
    host = os.getenv('HOST', '')
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
        
        # ChatKit expects the raw request body from the frontend
        # Typically this would be a ChatKit-formatted payload
        # For simplicity, we'll send a JSON payload that the endpoint can process
        payload = {
            "message": message,
            "stream": True
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

    @task(2)
    def health_check(self):
        """
        Perform health check to verify API is responsive.
        Weight: 2 (occasional check)
        """
        url = "/api/health"
        headers = {
            "Accept": "application/json"
        }
        
        with self.client.get(
            url=url,
            headers=headers,
            name="GET /api/health (health check)",
            catch_response=True,
            timeout=self.timeout_duration
        ) as response:
            if response.status_code == 200:
                response.success()
                if self.ENABLE_LOGGING:
                    print("[Locust] Health check passed")
            else:
                response.failure(f"Health check failed with status {response.status_code}")

    def on_stop(self):
        """Cleanup when user session ends."""
        if self.ENABLE_LOGGING:
            print(f"[Locust] User session ended for {self.credentials['username']}")

# To run locally:
# locust -f locustfile.py -u 10 -r 2 --run-time 2m --host {HOST}
# 
# To run with specific configuration:
# locust -f locustfile.py -u 50 -r 5 --run-time 5m --host {HOST} --html report.html
=======
from locust import HttpUser, task, between
import random

TEST_INPUTS = [
    "Where is my order?",
    "Can you tell me the status of my recent order?",
    "I placed an order last week, has it shipped yet?",
    "What's the tracking number for my order?",
    "When will my order arrive?",
    "I haven't received my order yet, can you help?",
    "How can I check my order status?",
    "Is my order on the way?",
    "Can you give me an update on order #12345?",
    "I need to know when my package will be delivered",
    "Did my order ship already?",
    "What's happening with my purchase?",
    "I ordered something 3 days ago, where is it?",
    "Can you track my order for me?",
    "My order hasn't arrived, what's going on?",
    "How long does it usually take for orders to arrive?",
    "I'm waiting for an order, can you check on it?",
    "Is there any delay with my order?",
    "Can I get the delivery status of my order?",
    "When was my order shipped?",
    "I want to know about my recent purchase",
    "Can you look up my order history?",
    "What's the estimated delivery date for my order?",
    "Has my order been processed yet?",
    "I need help tracking my package",
    "Where's the item I ordered last Tuesday?",
    "Can you tell me if my order is still processing?",
    "I'm expecting a delivery, when will it come?",
    "Is my order out for delivery?",
    "Can you confirm my order was received?",
    "I want to check on the status of my shipment",
    "Has my order left the warehouse yet?",
    "When should I expect my order to arrive?",
    "I ordered multiple items, have they all shipped?",
    "Can you give me tracking information?",
    "My order is taking longer than expected, why?",
    "I need to know if my order is on schedule",
    "Has there been any update on my order?",
    "Can you tell me where my package is right now?",
    "I want to track my recent order",
    "Is my order delayed?",
    "When did you ship my order?",
    "I placed an order yesterday, can you confirm it?",
    "What's the current status of my purchase?",
    "Can you help me locate my order?",
    "I'm concerned about my order, it hasn't arrived",
    "How do I find out when my order will be delivered?",
    "Can you check if my order has been dispatched?",
    "I need an update on my order please",
    "Where can I see my order tracking details?",
]

class ChatUser(HttpUser):
    wait_time = between(1, 3)

    @task
    def chat_with_bot(self):
        # Login
        login_response = self.client.post(
            "/api/login", json={"username": "stacey", "password": "stacey123"})
        access_token = login_response.json()['access_token']

        payload = {
            "type": "threads.create",
            "params":
            {"input":
             {"content": [
                 {"type": "input_text", "text": random.choice(TEST_INPUTS)}
             ], "quoted_text": "", "attachments": [], "inference_options": {}}
             }
        }

        result = self.client.post(
            "/api/chatkit", json=payload, headers={"Authorization": f"Bearer {access_token}"}
            )

        # logout
        self.client.post(
            "/api/logout", headers={"Authorization": f"Bearer {access_token}"}
        )
>>>>>>> 2eff61a (Add a load test for the chat endpoint)
