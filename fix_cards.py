import json

db_path = '/Users/leah/SoliBee/src/Honeycomb/cards_db.json'
with open(db_path, 'r') as f:
    cards = json.load(f)

changed = 0
for card in cards:
    for i in range(len(card['stats'])):
        if card['stats'][i] <= 0:
            card['stats'][i] = 1
            changed += 1

print(f"Changed {changed} values to 1")

with open(db_path, 'w') as f:
    json.dump(cards, f, indent=2)
