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

// Performance-measurement identity. Release/profile AOT builds are the only
// valid basis for size and frame-time numbers, but the production gate above
// (rightly) refuses to build without the original key. A perf build is a
// separate app: `asasfans.next.perf`, its own test signature, installable
// beside the real app and unable to touch its data.
//
//   flutter build apk --release -Pasasfans.perf=true -Pasasfans.perfSigning=debug
//
// Test signing is never implied. It is either a dedicated perf keystore
// (ASASFANS_PERF_KEYSTORE_* variables), or the SDK debug key when the caller
// says so explicitly with asasfans.perfSigning=debug. Neither can reach the
// production identity: without asasfans.perf there is no .perf suffix and no
// perf signing, and the production gate is unchanged.
val perfBuild = providers.gradleProperty("asasfans.perf").orNull == "true"
val perfUsesDebugKey = providers.gradleProperty("asasfans.perfSigning").orNull == "debug"
val perfStoreFile = System.getenv("ASASFANS_PERF_KEYSTORE_FILE")
    ?.takeIf { it.isNotBlank() }
    ?.let { path -> File(path).takeIf { it.isAbsolute } ?: File(repositoryRoot, path) }
val perfStorePassword = System.getenv("ASASFANS_PERF_KEYSTORE_PASSWORD")?.takeIf { it.isNotBlank() }
val perfKeyAlias = System.getenv("ASASFANS_PERF_KEY_ALIAS")?.takeIf { it.isNotBlank() }
val perfKeyPassword = System.getenv("ASASFANS_PERF_KEY_PASSWORD")?.takeIf { it.isNotBlank() }
val perfKeystoreReady = perfStoreFile?.exists() == true &&
    perfStorePassword != null &&
    perfKeyAlias != null &&
    perfKeyPassword != null
val perfSigningReady = perfKeystoreReady || perfUsesDebugKey
val perfSigningMissing =
    "Perf builds need a test signature: set the ASASFANS_PERF_KEYSTORE_* " +
        "variables, or pass -Pasasfans.perfSigning=debug to sign the isolated " +
        "asasfans.next.perf package with the SDK debug key. The production " +
        "key is never used for perf builds."

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
        // Target-platform behavior changes belong to a separate release task.
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        if (perfBuild) {
            // defaultConfig belongs to this app module only; plugin libraries
            // never see it, unlike a suffix set on every build type.
            applicationIdSuffix = ".perf"
            versionNameSuffix = "-perf"
        }
    }
    signingConfigs {
        if (releaseSigningReady && !perfBuild) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
        if (perfBuild && perfKeystoreReady) {
            create("perf") {
                storeFile = perfStoreFile
                storePassword = perfStorePassword
                keyAlias = perfKeyAlias
                keyPassword = perfKeyPassword
            }
        }
    }

    // The perf signature: the dedicated keystore, else the explicitly
    // requested SDK debug key, else none (and the pre-build gate stops).
    val perfSigning = when {
        !perfBuild -> null
        perfKeystoreReady -> signingConfigs.getByName("perf")
        perfUsesDebugKey -> signingConfigs.getByName("debug")
        else -> null
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
            signingConfig = when {
                perfBuild -> perfSigning
                releaseSigningReady -> signingConfigs.getByName("release")
                else -> null
            }
        }
        // Created by the Flutter plugin as initWith(debug), so it would carry
        // the debug key under whatever identity is current. In a perf build it
        // takes the perf signature like release does.
        if (perfBuild) {
            getByName("profile") { signingConfig = perfSigning }
        }
    }
}

// Debug uses a development suffix; perf builds use `.perf` above. Do not set
// applicationIdSuffix on plugin libraries through buildTypes.configureEach.
// Release requires the original signing configuration. Upgrade continuity
// still needs separate fingerprint/install verification; legacy migration is
// cancelled and is not a release prerequisite.
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        if (perfBuild) {
            if (!perfSigningReady) throw GradleException(perfSigningMissing)
            return@doFirst
        }
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

// A profile build is only ever the isolated perf identity with a test key.
tasks.matching { it.name == "preProfileBuild" }.configureEach {
    doFirst {
        if (perfBuild && !perfSigningReady) throw GradleException(perfSigningMissing)
        // Without the perf identity a profile build is asasfans.next signed
        // with the debug key: the artifact the release gate exists to stop.
        if (!perfBuild) {
            throw GradleException(
                "Android profile builds are measurement builds. Add " +
                    "-Pasasfans.perf=true (and a perf signature) so they install as " +
                    "asasfans.next.perf, never as asasfans.next."
            )
        }
    }
}

flutter { source = "../.." }
