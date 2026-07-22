# Quickstart Guide: SoliBee Windows Port Validation

This guide outlines the commands and steps required to build, test, and validate the ported SoliBee application on Windows systems.

## Prerequisites

Ensure the following SDKs and runtimes are installed on your Windows machine:
- [.NET 8.0 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- Visual Studio 2022 (with "Universal Windows Platform development" or ".NET Desktop Development" workloads)

## Building the Solution

To restore dependencies and build the entire solution (Core, Desktop, and Tests) from the command line:

```cmd
# Navigate to the repository root directory on Windows
cd SoliBee

# Restore dependencies
dotnet restore

# Build the solution in Release mode
dotnet build -c Release
```

## Running the Unit Tests

Execute the unit test suites covering the card games logic and rule validation engines:

```cmd
# Run all unit tests in the SoliBee.Tests project
dotnet test tests/SoliBee.Tests/SoliBee.Tests.csproj
```

## Launching the Desktop Client

Launch the desktop UI client for interactive validation:

```cmd
# Start the desktop application
dotnet run --project src/SoliBee.Desktop/SoliBee.Desktop.csproj
```

## Manual Validation Checklist

Verify the following flows work interactively:
1. **DPI Scaling**: Drag the app window between standard and high-DPI monitors; cards should resize cleanly without visual glitches.
2. **Preference Persistence**: Change the felt color to Charcoal, close the app, launch it again, and check that the background remains Charcoal.
3. **Sound Toggle**: Navigate to preferences, turn off Sound Effects, and check that card snapping sounds are muted.
