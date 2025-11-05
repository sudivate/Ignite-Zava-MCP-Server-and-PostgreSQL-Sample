import logging
import os
from agent_framework import (
    ChatAgent,
    MCPStreamableHTTPTool,
    MagenticBuilder,
)
from agent_framework.azure import AzureOpenAIChatClient


from zava_shop_agents import MCPStreamableHTTPToolOTEL



logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# Use API key if available, otherwise use DefaultAzureCredential (for workload identity)
api_key = os.environ.get("AZURE_OPENAI_API_KEY_GPT5")
chat_client_kwargs = {
    "endpoint": os.environ.get("AZURE_OPENAI_ENDPOINT_GPT5"),
    "deployment_name": os.environ.get("AZURE_OPENAI_MODEL_DEPLOYMENT_NAME_GPT5"),
    "api_version": os.environ.get("AZURE_OPENAI_ENDPOINT_VERSION_GPT5", "2024-02-15-preview")
}

if api_key:
    chat_client_kwargs["api_key"] = api_key
else:
    # Use DefaultAzureCredential for workload identity
    from azure.identity import DefaultAzureCredential
    credential = DefaultAzureCredential()
    
    # Create a token provider that returns just the token string
    def get_azure_ad_token() -> str:
        token = credential.get_token("https://cognitiveservices.azure.com/.default")
        return token.token
    
    chat_client_kwargs["ad_token_provider"] = get_azure_ad_token

chat_client = AzureOpenAIChatClient(**chat_client_kwargs)


async def get_tool_list(tool: MCPStreamableHTTPTool) -> str:
    tool_suffix = ""
    async with tool as tools:
        await tools.load_tools()
        for func in tools.functions:
             tool_suffix += f"\n### {func.name}\n{func.description}\n------------------------\n"
    return tool_suffix

supplier_mcp_tools = MCPStreamableHTTPToolOTEL(
    name="SupplierMCP",
    url=os.getenv("SUPPLIER_MCP_HTTP", "http://localhost:8001") + "/mcp",
    headers={
         "Authorization": f"Bearer {os.getenv('DEV_GUEST_TOKEN','dev-guest-token')}"
    },
    load_tools=True,
    load_prompts=False,
    request_timeout=30,
)

# Skip for now.
# loop = get_or_create_eventloop()
# supplier_tools = loop.run_until_complete(get_tool_list(supplier_mcp_tools))

supplier_tools = ""

supplier_agent = ChatAgent(
    name="SupplierAgent",
    description=f" Use Defaults. Do not stop to clarify. You are a helpful assistant that integrates with the backend supplier data. \n\nYou have the following capabilities: \n{supplier_tools}",
    instructions="You solve questions using supplier data and the tools provided.",
    chat_client=chat_client,
    tools=supplier_mcp_tools,
)


workflow = (
    MagenticBuilder()
    .participants(supplier=supplier_agent)
    # .with_plan_review()
    .with_standard_manager(
        chat_client=chat_client,
        max_round_count=5,
        max_stall_count=3,
        max_reset_count=1,
    )
    .build()
)
