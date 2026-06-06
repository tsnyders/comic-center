allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// isar_flutter_libs 3.x ships with an outdated build.gradle: no `namespace`
// (required by AGP 8+) and compileSdkVersion 30 (dependencies need 34+).
// gradle.afterProject fires after each project finishes evaluating and avoids
// the "already evaluated" error that afterEvaluate throws in this context.
gradle.afterProject {
    if (!plugins.hasPlugin("com.android.library")) return@afterProject
    val android = extensions.findByName("android") ?: return@afterProject

    // 1. Inject missing namespace from AndroidManifest.xml
    val getNs = runCatching {
        android.javaClass.getMethod("getNamespace").invoke(android)
    }.getOrNull()
    if (getNs == null) {
        val manifest = file("src/main/AndroidManifest.xml")
        if (manifest.exists()) {
            val pkg = manifest.readText()
                .substringAfter("package=\"", "")
                .substringBefore("\"", "")
            if (pkg.isNotEmpty()) {
                runCatching {
                    android.javaClass.getMethod("setNamespace", String::class.java)
                        .invoke(android, pkg)
                }
            }
        }
    }

    // 2. Bump compileSdkVersion to 35 if the library is stuck on an old value
    val currentSdk = runCatching {
        (android.javaClass.getMethod("getCompileSdkVersion").invoke(android) as? String)
            ?.removePrefix("android-")?.toIntOrNull() ?: 0
    }.getOrDefault(0)
    if (currentSdk in 1..33) {
        runCatching {
            android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                .invoke(android, 35)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
