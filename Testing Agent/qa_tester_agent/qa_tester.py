import json
from openai import OpenAI

# Initialize the OpenAI client to point to the local Ollama instance
# Ollama provides an OpenAI-compatible API on port 11434
client = OpenAI(
    base_url='http://localhost:11434/v1',
    api_key='ollama', # required, but unused
)

# This is the model you mentioned you have installed
MODEL = 'qwen:14b-coder' # You may need to adjust this depending on the exact tag (e.g. qwen2.5-coder:14b)

# Define a tool for our QA Agent to use. 
# This tells the LLM what the tool is, what arguments it takes, and what it does.
tools = [
    {
        "type": "function",
        "function": {
            "name": "run_test_suite",
            "description": "Runs a simulated test suite against a specific component of the Card Suite.",
            "parameters": {
                "type": "object",
                "properties": {
                    "component": {
                        "type": "string",
                        "description": "The component to test (e.g., 'deck_shuffler', 'ui_rendering', 'multiplayer_sync')",
                    }
                },
                "required": ["component"],
            },
        }
    }
]

# The actual Python implementation of the tool
def run_test_suite(component: str) -> str:
    print(f"\n[System] --> Agent is running tests on: {component}...")
    if component == "deck_shuffler":
        return '{"status": "fail", "error": "AssertionError: Duplicate cards found in shuffled deck."}'
    return '{"status": "pass", "details": "All 42 tests passed."}'

def run_qa_agent(user_request: str):
    print(f"\n[User Request]: {user_request}")
    
    # Define the QA Agent's personality and instructions
    messages = [
        {"role": "system", "content": "You are a senior QA Tester Agent. Your job is to test components of a card suite, analyze failures, and provide clear bug reports. Use the tools provided to run tests."},
        {"role": "user", "content": user_request}
    ]

    # Step 1: Send the conversation and tools to the local model
    response = client.chat.completions.create(
        model=MODEL,
        messages=messages,
        tools=tools,
    )

    message = response.choices[0].message
    
    # Step 2: Check if the model wants to call a tool
    if message.tool_calls:
        for tool_call in message.tool_calls:
            if tool_call.function.name == "run_test_suite":
                # Parse the arguments the model provided
                args = json.loads(tool_call.function.arguments)
                
                # Execute the actual Python function
                test_result = run_test_suite(args["component"])
                
                # Add the model's tool call and our tool response to the conversation history
                messages.append(message)
                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": test_result
                })
                
                # Step 3: Let the model analyze the test results
                final_response = client.chat.completions.create(
                    model=MODEL,
                    messages=messages,
                )
                print(f"\n[QA Agent Report]:\n{final_response.choices[0].message.content}")
    else:
        print(f"\n[QA Agent Reply]:\n{message.content}")

if __name__ == "__main__":
    # Simulate a request to our new QA agent
    run_qa_agent("Please test the deck_shuffler and let me know if it's ready for production.")
