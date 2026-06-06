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

// isar_flutter_libs 3.x ships without a `namespace` in its build.gradle,
// which is required by AGP 8+. gradle.afterProject fires after each project
// finishes evaluating and avoids the "already evaluated" error from afterEvaluate.
gradle.afterProject {
    if (!plugins.hasPlugin("com.android.library")) return@afterProject
    val android = extensions.findByName("android") ?: return@afterProject
    val getNs = runCatching {
        android.javaClass.getMethod("getNamespace").invoke(android)
    }.getOrNull()
    if (getNs != null) return@afterProject
    val manifest = file("src/main/AndroidManifest.xml")
    if (!manifest.exists()) return@afterProject
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
