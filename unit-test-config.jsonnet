{
    defaultSettings: {},
    configurations:
    {
        "Vanilla (Blocking)":
        {
            "runtime-global": {
                startup: {
                    "fs-non-blocking-search": false,
                },
            },
            mods: [
                "FactorySearch",
            ],
        },
        /*"Vanilla (Non-blocking)":
        {
            "runtime-global": {
                startup: {
                    "fs-non-blocking-search": true,
                },
            },
            mods: [
                "FactorySearch",
            ],
        },
        "Space Age":
        {
            settings: {},
            mods: [
                "FactorySearch",
                "space-age",
                "elevated-rails",
                "quality",
            ],
        },*/
    },
    tests:
    {
        "test-search": {},
    }
}