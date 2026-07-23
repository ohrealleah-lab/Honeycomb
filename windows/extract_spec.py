import json

with open('/Users/leah/.gemini/antigravity/brain/11c671d6-4405-449b-81ab-b13fbb5457ec/.system_generated/logs/transcript_full.jsonl', 'r') as f:
    for line in f:
        data = json.loads(line)
        if data.get('type') == 'VIEW_FILE' and 'as-you-know-we-mutable-owl' in data.get('content', ''):
            print(f"STEP: {data.get('step_index')}")
            print(data.get('content'))
            print("========================================")
