import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties()
if (hasReleaseKeystore) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

// A release APK signed with the debug key cannot be installed over a
// release-signed copy: Android refuses the signature change and the installer
// only reports "App not installed". Releases therefore fail fast rather than
// producing an APK that silently cannot update anyone. See
// docs/RELEASE_SIGNING.md; pass -PallowDebugSigning=true for a throwaway
// local build.
val allowDebugSigning = (project.findProperty("allowDebugSigning") as String?) == "true"

gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any { task ->
        task.name.contains("Release") && (
            task.name.startsWith("assemble") ||
                task.name.startsWith("bundle") ||
                task.name.startsWith("package")
            )
    }
    if (buildingRelease) {
        if (!hasReleaseKeystore && !allowDebugSigning) {
            throw GradleException(
                "Release build blocked: android/key.properties is missing, so this APK " +
                    "would be signed with the debug key and could not be installed over a " +
                    "release-signed copy of Yomi. See docs/RELEASE_SIGNING.md. To build an " +
                    "install-only-on-this-machine APK anyway, add -PallowDebugSigning=true."
            )
        }
        println(
            "Yomi release signing: " +
                if (hasReleaseKeystore) "release keystore" else "DEBUG KEY (local only)"
        )
    }
}

android {
    namespace = "com.comiccenter.comic_center"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications needs java.time on older Android.
        isCoreLibraryDesugaringEnabled = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String? ?: "yomi"
            keyPassword = keystoreProperties["keyPassword"] as String? ?: ""
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String? ?: ""
        }
    }

    defaultConfig {
        applicationId = "com.comiccenter.comic_center"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")

            // Run R8: shrink + optimize the Android/Kotlin host code and strip
            // unused resources. Without isMinifyEnabled the proguardFiles below
            // were configured but never applied, so release builds shipped the
            // full, un-optimized host code. (Only the JVM/Android side is
            // affected — Dart is AOT-compiled separately.)
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        debug {
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.squareup.picasso:picasso:2.8")
    // webview_flutter already resolves this artifact; expose its document-start
    // API to MainActivity's capture-hook bridge at compile time.
    implementation("androidx.webkit:webkit:1.15.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
