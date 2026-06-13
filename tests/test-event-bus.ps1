# Feature: Windows Event Bus (event-bus.ps1)
#   Acts as the pub-sub dispatcher. Receives an event name,
#   reads the subscription registry, routes to subscribers.

BeforeAll {
    $projectRoot = Resolve-Path "$PSScriptRoot/.."
}

# Scenario: Valid event dispatches all subscribers
#   Given config.json has subscriptions.Stop with subscribers
#   When event-bus.ps1 -Event Stop is called
#   Then each subscriber's player is invoked
Describe "Event dispatch" {
    It "dispatches all subscribers for a valid event" {
        $result = & "$projectRoot/events/event-bus.ps1" -Event Stop -DryRun
        $result.Count | Should -BeGreaterThan 0
        $result[0].Type | Should -Be "wav"
    }
}

# Scenario: Unknown event is silently ignored
#   Given config.json has no subscription for "UnknownEvent"
#   When event-bus.ps1 -Event UnknownEvent is called
#   Then no player is invoked and exit code is 0
Describe "Unknown events" {
    It "silently handles unknown events without error" {
        { & "$projectRoot/events/event-bus.ps1" -Event NonExistentEvent -DryRun } | Should -Not -Throw
    }
}

# Scenario: Missing config file shows clear error
#   Given config.json does not exist
#   When event-bus.ps1 runs
#   Then a clear error message is written to stderr
Describe "Missing config" {
    It "reports clear error when config.json is missing" {
        # Temporarily rename config to simulate missing
        $configPath = Join-Path $projectRoot "config.json"
        $backup = Join-Path $projectRoot "config.json.bak"
        Rename-Item $configPath $backup
        try {
            { & "$projectRoot/events/event-bus.ps1" -Event Stop -ErrorAction Stop } | Should -Throw
        }
        finally {
            Rename-Item $backup $configPath
        }
    }
}

# Scenario: CLAUDE_PLUGIN_ROOT is resolved in paths
#   Given config.json contains "${CLAUDE_PLUGIN_ROOT}/sounds/pop.wav"
#   When event-bus.ps1 resolves paths
#   Then the path is absolute and points to the plugin directory
Describe "Path resolution" {
    It "resolves CLAUDE_PLUGIN_ROOT to absolute paths" {
        $result = & "$projectRoot/events/event-bus.ps1" -Event Stop -DryRun
        $result[0].File | Should -Not -Match '\$\{CLAUDE_PLUGIN_ROOT\}'
        $result[0].File | Should -Exist
    }
}
