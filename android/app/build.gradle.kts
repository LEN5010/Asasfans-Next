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
            // Legacy-data migration was cancelled, so it no longer gates this;
            // signing continuity does. Left null deliberately: a missing key
            // must fail the build rather than silently produce an artifact that
            // cannot upgrade the installed asasfans.next.
            signingConfig = null
        }
    }
    buildTypes.configureEach {
        if (name != "release") applicationIdSuffix = ".flutterdev"
    }
}

// Legacy-data migration was cancelled on 2026-09-21, so it is no longer a
// release gate. Signing continuity still is: a production build must be
// signed with the original release key so it can upgrade the installed
// asasfans.next, and must never fall back to the template debug key.
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        throw GradleException("Flutter production release is gated on release signing validation. Use a debug build until the release key is wired.")
    }
}

flutter { source = "../.." }
