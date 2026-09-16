import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // AGP 9 interim mode (android.builtInKotlin=false): legacy KGP, because
    // several Flutter plugins still apply kotlin-android (Flutter 3.44+
    // migrator approach). Revisit when all plugins use built-in Kotlin.
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.dorar.yosriya"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.dorar.yosriya"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Breaking change: minSdk 24 (Android 7.0). Drops API 21-23 so
    // pre-N branches (e.g. the Chronometer fallback) are deleted.
    minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            val storeFilePath = keystoreProperties["storeFile"] as String?
            storeFile = storeFilePath?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")

            // R8 dex shrinking + resource shrinking (release only).
            // No custom rules needed:
            //  * manifest-declared components (activities, services,
            //    receivers) are kept automatically via manifest merging,
            //  * plugin AARs (Media3, WorkManager, play-services, Flutter
            //    engine) ship their own consumer rules,
            //  * app code uses no reflection/serialization — layouts hold
            //    framework widgets only, resource keep/discard lives in
            //    res/raw/keep.xml.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt")
            )
        }
    }
}

flutter {
    source = "../.."
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Native prayer-time calculation (same algorithm as adhan_dart on Dart).
    implementation("com.batoulapps.adhan:adhan2:0.0.5")
}
