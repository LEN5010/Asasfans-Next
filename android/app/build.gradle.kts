import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// The release key, from a local keystore.properties or from CI environment
// variables. Absent means absent: nothing here falls back to the template
// debug key, because a debug-signed artifact cannot upgrade the installed
// asasfans.next and would have to be found out by a user failing to install.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("../keystore.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun signingValue(property: String, environment: String): String? =
    (keystoreProperties.getProperty(property) ?: System.getenv(environment))
        ?.takeIf { it.isNotBlank() }

// storeFile is resolved against the repository root, which is where both the
// local keystore.properties and the CI-decoded keystore put it.
val repositoryRoot = rootProject.projectDir.parentFile
val releaseStoreFile = signingValue("storeFile", "ANDROID_KEYSTORE_FILE")
    ?.let { path -> File(path).takeIf { it.isAbsolute } ?: File(repositoryRoot, path) }
val releaseStorePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
val releaseSigningReady = releaseStoreFile?.exists() == true &&
    releaseStorePassword != null &&
    releaseKeyAlias != null &&
    releaseKeyPassword != null

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
    signingConfigs {
        if (releaseSigningReady) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        debug {
            // Scaffold builds must never overwrite a user's Android 2.0 data.
            applicationIdSuffix = ".flutterdev"
            versionNameSuffix = "-debug"
        }
        release {
            // The real release key, or nothing. Never Flutter's generated debug
            // signing: that produces an artifact which compiles but cannot
            // upgrade the installed asasfans.next, and the user finds out by
            // failing to install it.
            signingConfig = if (releaseSigningReady) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

// Flutter's own `profile` build type deliberately carries no
// applicationIdSuffix.
//
// The previous `buildTypes.configureEach` set one on every non-release type.
// Flutter creates `profile` with initWith(debug) inside every Android project
// it touches, including plugin libraries, and a library may not carry an
// applicationIdSuffix at all — so that line failed configuration before any
// Android build could start. Debug and release were both unbuildable, which
// is why no Android artifact has ever been produced here.
//
// Only `debug` needs the suffix, and it keeps it above: that is the build a
// developer installs beside the user's real app. A profile build is a timing
// measurement, not something installed alongside production.

// The gate is now the condition itself rather than an unconditional stop:
// a release build without the original key fails, and one with it proceeds.
// Legacy-data migration was cancelled on 2026-09-21 and no longer gates this.
//
// What this does not establish is that the wired key is the same one the
// published APK was signed with. That is a fingerprint comparison against a
// real published artifact, and it stays a release checklist item — an
// installable build is not proof of upgrade continuity.
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        if (!releaseSigningReady) {
            throw GradleException(
                "Release signing is not configured. Provide keystore.properties " +
                    "or the ANDROID_KEYSTORE_* environment variables. A debug key " +
                    "is never an acceptable fallback: it cannot upgrade the " +
                    "installed asasfans.next."
            )
        }
    }
}

flutter { source = "../.." }
