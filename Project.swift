import ProjectDescription

let project = Project(
    name: "BTA30Volume",
    targets: [
        .target(
            name: "BTA30Volume",
            destinations: .macOS,
            product: .app,
            productName: "BTA30Volume",
            bundleId: "com.aliosmanozturk.bta30volume",
            deploymentTargets: .macOS("13.0"),
            infoPlist: .extendingDefault(with: [
                "LSUIElement": true,
                "LSApplicationCategoryType": "public.app-category.utilities",
                "CFBundleDisplayName": "BTA30 Volume",
                "CFBundleDevelopmentRegion": "en",
                "CFBundleLocalizations": ["en", "tr"],
                "CFBundleShortVersionString": "1.0.0",
                "CFBundleVersion": "1",
                "CFBundleIconFile": "AppIcon",
                "NSBluetoothAlwaysUsageDescription": "Required to control the FiiO BTA30 Pro's volume over Bluetooth.",
                "CFBundleURLTypes": [
                    [
                        "CFBundleURLName": "com.aliosmanozturk.bta30volume.url",
                        "CFBundleURLSchemes": ["bta30"],
                    ],
                ],
            ]),
            sources: ["Sources/BTA30Volume/**"],
            resources: [
                "Sources/BTA30Volume/Resources/**",
                "Resources/**",
            ],
            settings: .settings(base: [
                // Signing happens in build.sh: Xcode builds ad-hoc and the
                // script re-signs with the developer certificate from the
                // keychain if one exists. This keeps the project buildable
                // for contributors without a certificate.
                "CODE_SIGN_STYLE": "Manual",
                "CODE_SIGN_IDENTITY": "-",
                "SWIFT_VERSION": "5.9",
            ])
        ),
        .target(
            name: "BTA30VolumeTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.aliosmanozturk.bta30volume.tests",
            deploymentTargets: .macOS("13.0"),
            infoPlist: .default,
            sources: ["Tests/BTA30VolumeTests/**"],
            dependencies: [
                .target(name: "BTA30Volume")
            ],
            settings: .settings(base: [
                "CODE_SIGN_STYLE": "Manual",
                "CODE_SIGN_IDENTITY": "-",
                "SWIFT_VERSION": "5.9",
            ])
        ),
    ]
)
