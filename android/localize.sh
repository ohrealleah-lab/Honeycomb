#!/bin/bash
find app/src/main/java/com/leah/honeycomb -name "*.kt" -type f -exec sed -i '' 's/Text("New Game")/Text(Strings.get(StringKey.NewGame, AppLanguage.English))/g' {} +
find app/src/main/java/com/leah/honeycomb -name "*.kt" -type f -exec sed -i '' 's/Text("Restart Game")/Text(Strings.get(StringKey.Restart, AppLanguage.English))/g' {} +
find app/src/main/java/com/leah/honeycomb -name "*.kt" -type f -exec sed -i '' 's/Text("Undo")/Text(Strings.get(StringKey.Undo, AppLanguage.English))/g' {} +
find app/src/main/java/com/leah/honeycomb -name "*.kt" -type f -exec sed -i '' 's/Text("Quit")/Text(Strings.get(StringKey.Quit, AppLanguage.English))/g' {} +
find app/src/main/java/com/leah/honeycomb -name "*.kt" -type f -exec sed -i '' 's/Text("Cancel")/Text(Strings.get(StringKey.Cancel, AppLanguage.English))/g' {} +
