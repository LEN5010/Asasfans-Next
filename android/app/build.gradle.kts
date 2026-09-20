plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.asasfans"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }

    defaultConfig {
        applicationId = "asasfans.next"
        minSdk = 24
        // Preserve the legacy platform behavior until migration acceptance.
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    buildTypes {
        debug {
            // Scaffold builds must never overwrite a user's Android 2.0 data.
            applicationIdSuffix = ".flutterdev"
            versionNameSuffix = "-debug"
        }
        release {
            // Do not use Flutter's generated debug signing for production.
            // Existing signing continuity is restored only after migration QA.
            signingConfig = null
        }
    }
    buildTypes.configureEach {
        if (name != "release") applicationIdSuffix = ".flutterdev"
    }
}

// Enable production builds only in the migration/release milestone, after
// legacy DB import and signing have been implemented and validated.
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        throw GradleException("Flutter production release is gated on legacy-data migration and signing validation. Use a debug build for the scaffold.")
    }
}

flutter { source = "../.." }
